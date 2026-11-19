#!/usr/bin/env bash
# gh-sec-check.sh
# Scannt oder aktiviert gh-secure-Features für ein Repository
# oder alle persönlichen Repositories.

set -uo pipefail

LOG_FILE="${LOG_FILE:-./github-security.log}"

scan_repo() {
  local repo="$1"
  local rc

  echo
  echo "==> Sicherheitsstatus: $repo"

  if gh secure status --repo "$repo" 2>&1 | tee -a "$LOG_FILE"; then
    :
  else
    rc=${PIPESTATUS[0]}
    echo "❌ Scan für $repo fehlgeschlagen (Exit-Code $rc)." >&2
    return "$rc"
  fi
}

apply_repo() {
  local repo="$1"
  local mode="$2"
  shift 2

  local features=("$@")
  local rc

  echo
  echo "==> Bearbeite: $repo"

  case "$mode" in
    all)
      if gh secure --repo "$repo" --yes 2>&1 | tee -a "$LOG_FILE"; then
        :
      else
        rc=${PIPESTATUS[0]}
        echo "❌ Aktivierung für $repo fehlgeschlagen (Exit-Code $rc)." >&2
        return "$rc"
      fi
      ;;

    interactive)
      if gh secure --repo "$repo" 2>&1 | tee -a "$LOG_FILE"; then
        :
      else
        rc=${PIPESTATUS[0]}
        echo "❌ Interaktive Auswahl für $repo fehlgeschlagen (Exit-Code $rc)." >&2
        return "$rc"
      fi
      ;;

    selected)
      if gh secure --repo "$repo" "${features[@]}" 2>&1 | tee -a "$LOG_FILE"; then
        :
      else
        rc=${PIPESTATUS[0]}
        echo "❌ Aktivierung für $repo fehlgeschlagen (Exit-Code $rc)." >&2
        return "$rc"
      fi
      ;;

    *)
      echo "❌ Unbekannter Modus: $mode" >&2
      return 2
      ;;
  esac
}

# Voraussetzungen prüfen
if ! command -v gh >/dev/null 2>&1; then
  echo "❌ GitHub CLI (gh) ist nicht installiert."
  echo "   Installation: https://cli.github.com/"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "❌ GitHub CLI ist nicht angemeldet. Bitte gh auth login ausführen."
  exit 1
fi

if ! gh extension list 2>/dev/null | grep -q "GitHubSecurityLab/gh-secure"; then
  echo "ℹ️  Installiere gh-secure ..."
  if ! gh extension install GitHubSecurityLab/gh-secure; then
    echo "❌ Installation von gh-secure fehlgeschlagen."
    exit 1
  fi
fi

# Ein optionales OWNER/REPO-Argument überspringt die Auswahl.
if [[ $# -gt 0 ]]; then
  repos=("$1")
else
  echo "Für welche Repositories?"
  echo "  1) Aktuelles Repository"
  echo "  2) Alle Repositories meines persönlichen Kontos"
  echo "  3) Abbrechen"
  read -r -p "Auswahl [1-3]: " scope

  case "$scope" in
    1)
      current_repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner') || {
        echo "❌ Aktuelles Verzeichnis ist kein GitHub-Repository."
        exit 1
      }
      repos=("$current_repo")
      ;;

    2)
      username=$(gh api user --jq '.login') || {
        echo "❌ GitHub-Benutzerkonto konnte nicht ermittelt werden."
        exit 1
      }

      mapfile -t repos < <(
        gh repo list "$username" --limit 1000 \
          --json nameWithOwner --jq '.[].nameWithOwner'
      )

      if ((${#repos[@]} == 0)); then
        echo "❌ Keine Repositories gefunden."
        exit 1
      fi
      ;;

    3)
      echo "Abgebrochen."
      exit 0
      ;;

    *)
      echo "Ungültige Auswahl."
      exit 1
      ;;
  esac
fi

echo
echo "Ausgewählte Repositories:"
printf '  - %s\n' "${repos[@]}"

echo
echo "Was möchtest du tun?"
echo "  1) Nur scannen und aktive Einstellungen anzeigen"
echo "  2) Alle empfohlenen Features aktivieren"
echo "  3) Features interaktiv auswählen"
echo "  4) Bestimmte Features angeben"
echo "  5) Abbrechen"
read -r -p "Auswahl [1-5]: " action

case "$action" in
  1)
    for repo in "${repos[@]}"; do
      scan_repo "$repo" || true
    done

    echo
    echo "✅ Scan abgeschlossen. Log: $LOG_FILE"
    exit 0
    ;;

  2)
    mode="all"
    ;;

  3)
    mode="interactive"
    ;;

  4)
    read -r -p "Feature-Namen (z. B. branch-protection dependabot): " -a features
    if ((${#features[@]} == 0)); then
      echo "❌ Keine Features angegeben."
      exit 1
    fi
    mode="selected"
    ;;

  5)
    echo "Abgebrochen."
    exit 0
    ;;

  *)
    echo "Ungültige Auswahl."
    exit 1
    ;;
esac

# Sicherheitsabfrage vor jeder Aktivierung
echo
echo "⚠️  Die gewählte Aktion kann Einstellungen ändern."
read -r -p "Für ${#repos[@]} Repository(s) fortfahren? (j/N) " confirm

if [[ ! "$confirm" =~ ^[JjYy]$ ]]; then
  echo "Abgebrochen; es wurden keine Aktivierungsbefehle ausgeführt."
  exit 0
fi

failures=0

for repo in "${repos[@]}"; do
  if [[ "$mode" == "selected" ]]; then
    apply_repo "$repo" "$mode" "${features[@]}" ||
      failures=$((failures + 1))
  else
    apply_repo "$repo" "$mode" ||
      failures=$((failures + 1))
  fi
done

echo
if ((failures == 0)); then
  echo "✅ Fertig. Log: $LOG_FILE"
else
  echo "⚠️  Fertig, aber bei $failures Repository(s) gab es Fehler. Log: $LOG_FILE"
  exit 1
fi