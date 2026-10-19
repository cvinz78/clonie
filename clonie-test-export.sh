#!/usr/bin/env bash
#
# clonie-test-export.sh – Docker-Testklone sichern und wiederherstellen
#
# Zweck:
#   Packt die lokalen Docker-Test-Images (Klone nach AGENTS.md §11,
#   Standard: clonie-test-ubuntu + clonie-test-alpine) in EIN
#   komprimiertes Archiv inkl. SHA-256-Prüfsumme und lädt es auf einem
#   anderen Rechner wieder. Der Kollege braucht danach weder die
#   Basis-Images noch einen Neu-Aufbau der Klone; tests/container-test.sh
#   läuft sofort gegen die geladenen Klone (§7-Kostenregel bleibt
#   erhalten, da dieselben Klone weiterverwendet werden).
#
# Verwendung:
#   ./clonie-test-export.sh save [-o VERZEICHNIS] [IMAGE ...]
#       Images in ein Archiv sichern (Standard: beide Klone,
#       Standardverzeichnis: aktuelles Verzeichnis). Fehlende Images
#       werden mit Warnung übersprungen; ohne irgendein Image bricht
#       der Lauf ab.
#   ./clonie-test-export.sh load [ARCHIV]
#       Archiv zurückladen (Standard: clonie-test-images.tar.gz im
#       aktuellen Verzeichnis).
#   ./clonie-test-export.sh -h|--help      Diese Hilfe
#   ./clonie-test-export.sh -V|--version   Version anzeigen
#
# Benötigte Tools: bash, docker (laufender Daemon), gzip, sha256sum,
#   mktemp, du
#
# Exit-Codes:
#   0  Erfolg
#   2  Falsche Argumente (Usage ausgegeben)
#   3  docker/gzip/sha256sum fehlt oder Daemon nicht erreichbar
#   4  Kein zu sicherndes Image lokal vorhanden
#   5  Archiv fehlt oder ist nicht lesbar
#   6  docker save / docker load fehlgeschlagen
#

set -euo pipefail

VERSION="1.0"
PROGRAM_NAME="clonie-test-export.sh"
DEFAULT_IMAGES=(clonie-test-ubuntu clonie-test-alpine)
DEFAULT_ARCHIVE="clonie-test-images.tar.gz"

# vom trap aufgeräumt, sobald nichts mehr nötig (nach mv geleert)
TMP_FILE=""

die() {
    local code="$1"
    shift
    printf 'Fehler: %s\n' "$*" >&2
    exit "$code"
}

usage() {
    printf '%s – Docker-Testklone sichern und wiederherstellen\n\n' "$PROGRAM_NAME $VERSION"
    printf 'Verwendung:\n'
    printf '  ./%s save [-o VERZEICHNIS] [IMAGE ...]  Images in ein Archiv sichern\n' "$PROGRAM_NAME"
    printf '  ./%s load [ARCHIV]                      Archiv zurückladen\n' "$PROGRAM_NAME"
    printf '  ./%s -h|--help | -V|--version\n\n' "$PROGRAM_NAME"
    printf 'Standard-Images: %s\n' "${DEFAULT_IMAGES[*]}"
    printf 'Standard-Archiv: %s (im aktuellen Verzeichnis)\n\n' "$DEFAULT_ARCHIVE"
    printf 'Exit-Codes: 0 Erfolg, 2 falsche Argumente, 3 docker/Tools fehlen,\n'
    printf '  4 kein Image vorhanden, 5 Archiv fehlt, 6 save/load fehlgeschlagen\n'
}

usage_err() {
    printf 'Fehler: %s\n' "$1" >&2
    usage >&2
    exit 2
}

need_docker() {
    local tool
    for tool in docker gzip sha256sum; do
        command -v "$tool" >/dev/null 2>&1 ||
            die 3 "Benötigtes Werkzeug fehlt: $tool"
    done
    docker info >/dev/null 2>&1 ||
        die 3 "Docker-Daemon nicht erreichbar (läuft docker?)."
}

cleanup() {
    if [[ -n "$TMP_FILE" ]]; then
        rm -f -- "$TMP_FILE"
    fi
}
trap cleanup EXIT

cmd_save() {
    local out_dir="."
    local img archive
    local -a imgs=()
    local -a present=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--out)
                [[ $# -ge 2 ]] || usage_err "Bei $1 fehlt das Verzeichnis."
                out_dir="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                usage_err "Unbekannte Option: $1"
                ;;
            *)
                imgs+=("$1")
                shift
                ;;
        esac
    done
    if [[ "${#imgs[@]}" -eq 0 ]]; then
        imgs=("${DEFAULT_IMAGES[@]}")
    fi

    [[ -n "$out_dir" && "$out_dir" != "/" ]] ||
        usage_err "Ungültiges Ausgabeverzeichnis: '$out_dir'"
    mkdir -p "$out_dir" ||
        die 2 "Ausgabeverzeichnis nicht anlegbar: $out_dir"

    need_docker

    for img in "${imgs[@]}"; do
        if docker image inspect "$img" >/dev/null 2>&1; then
            present+=("$img")
        else
            printf 'Warnung: Image nicht lokal vorhanden, übersprungen: %s\n' "$img" >&2
        fi
    done
    if [[ "${#present[@]}" -eq 0 ]]; then
        die 4 "Kein zu sicherndes Image lokal vorhanden."
    fi

    archive="$out_dir/$DEFAULT_ARCHIVE"
    TMP_FILE="$(mktemp "$out_dir/.${DEFAULT_ARCHIVE}.XXXXXX")"

    printf 'Sichere: %s\n' "${present[*]}"
    if ! docker save "${present[@]}" | gzip > "$TMP_FILE"; then
        die 6 "docker save fehlgeschlagen."
    fi
    mv -- "$TMP_FILE" "$archive"
    TMP_FILE=""
    chmod 644 -- "$archive"
    sha256sum "$archive" > "$archive.sha256"

    printf 'Archiv:    %s (%s)\n' "$archive" "$(du -h "$archive" | cut -f1)"
    printf 'Prüfsumme: %s\n' "$archive.sha256"
    printf '\nFür den Kollegen nötig:\n  %s\n  %s\n  %s\n' \
        "$archive" "$archive.sha256" "$PROGRAM_NAME"
    printf '\nDort Prüfsumme prüfen und wiederherstellen:\n  sha256sum -c %s\n  ./%s load %s\n' \
        "$archive.sha256" "$PROGRAM_NAME" "$archive"
}

cmd_load() {
    local archive="$DEFAULT_ARCHIVE"
    local img found=0

    if [[ $# -gt 1 ]]; then
        usage_err "Maximal ein Archiv angeben."
    fi
    if [[ $# -eq 1 ]]; then
        archive="$1"
    fi

    [[ -r "$archive" ]] ||
        die 5 "Archiv nicht gefunden oder nicht lesbar: $archive"

    need_docker

    printf 'Lade: %s\n' "$archive"
    if ! docker load -i "$archive"; then
        die 6 "docker load fehlgeschlagen."
    fi

    printf '\nVorhandene Klone:\n'
    for img in "${DEFAULT_IMAGES[@]}"; do
        if docker image inspect "$img" >/dev/null 2>&1; then
            printf '  %s\n' "$img"
            found=1
        fi
    done
    if [[ "$found" -eq 0 ]]; then
        printf '  (kein Standard-Klon im Archiv)\n'
    fi

    cat <<'EOF'

Nächster Schritt (Tests gegen die Klone, im Projektordner):
  docker run -d --privileged --name clonie-t-ubuntu \
      -v "$PWD":/work:ro clonie-test-ubuntu sleep 1800
  docker exec clonie-t-ubuntu bash /work/tests/container-test.sh ubuntu multi
  docker rm -f clonie-t-ubuntu
EOF
}

main() {
    if [[ $# -eq 0 ]]; then
        usage_err "Kein Modus angegeben."
    fi
    case "$1" in
        -h|--help)
            usage
            ;;
        -V|--version)
            printf '%s %s\n' "$PROGRAM_NAME" "$VERSION"
            ;;
        save)
            shift
            cmd_save "$@"
            ;;
        load)
            shift
            cmd_load "$@"
            ;;
        *)
            usage_err "Unbekannter Modus: $1"
            ;;
    esac
}

main "$@"
