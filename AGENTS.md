# AGENTS.md – Richtlinien für KI-Agenten

Dieses Repository enthält Bash-Skripte für Linux. Alle Agenten und Mitwirkenden
halten sich an die folgenden Regeln.

---

## 1. Rahmenbedingungen (kostenloser Account)

- Nutze ausschließlich kostenlose und Open-Source-Tools (GNU coreutils, bash, shellcheck, git).
- Keine Abhängigkeit von bezahlten Diensten, API-Keys oder Cloud-Services.
- Repository klein halten: keine Binärdateien, Builds oder Artefakte committen.
- Keine Secrets, Tokens oder Passwörter im Code oder in der Commit-History.
- Rate Limits beachten: Änderungen klein und fokussiert halten statt große
  Sammel-Commits zu erstellen.
- CI (falls vorhanden): nur das kostenlose GitHub-Actions-Kontingent nutzen,
  keine Self-Hosted-Runner oder großen Maschinen anfordern.
- Externe Tools nur mit prioritisierter Abfrage (`command -v jq || exit 1`),
  keine unnötigen Abhängigkeiten einführen.
- Erstelle immer eine Task.md im Projekt ordner und trage dort alle änderungen,überlegungen,nicht gespeicherte vortschritte ein.
- Lies die Task.md nach jedem neustart neu ein.
---

## 2. Bash-Grundlagen

- Shebang: `#!/usr/bin/env bash`
- Direkt danach Strict Mode aktivieren:
   set -euo pipefail
- Zielplattform: Linux mit GNU-Tools. Keine macOS-/BSD-spezifischen Flags
  verwenden (z. B. `gsed`, `sed -i ''`).
- Einrückung: 4 Leerzeichen (keine Tabs), konsistent im ganzen Projekt.
- Dateinamen: `kebab-case.sh` oder `snake_case.sh`, keine Leerzeichen.
- Bei mehreren `sed`-Bearbeitungen pro Datei **rückwärts arbeiten**
  (von unten nach oben), damit sich die Zeilennummern der noch
  folgenden Zeilen während der Bearbeitung nicht verschieben.

---

## 3. Variablen & Quoting

- Variablen **immer** quoten: `"$var"`, niemals `$var` ungeschützt.
- Konstanten/Umgebungsvariablen in `GROSSBUCHSTABEN`, lokale Variablen in `snake_case`.
- In Funktionen immer `local` verwenden:
  meine_funktion() {
      local eingabe="$1"
      ...
  }
- `$(befehl)` statt Backticks `` `befehl` ``.
- `printf` statt `echo` bei variablen Inhalten:

  printf '%s\n' "$text"

- In Bash `[[ ... ]]` statt `[ ... ]` verwenden.
- `read -r` verwenden (ohne `-r` werden Backslashes verarbeitet).

---

## 4. Struktur & Lesbarkeit

- Logik in Funktionen kapseln; eine `main()`-Funktion am Ende aufrufen:

  main() {
      # ...
  }

  main "$@"

- Skripte möglichst unter 200–300 Zeilen halten, sonst in Module/Bibliotheken
  aufteilen (`source lib/foo.sh`).
- **Keine Kommentare im Code.** Erläuterungen (Zweck, Verwendung,
  benötigte Tools, Exit-Codes, das Warum einer Entscheidung) gehören in
  die `Task.md` oder die `README.md` – nicht zwingend in beide. Der
  Header eines Skripts besteht nur aus dem Shebang.
- Ausnahme: funktionale Direktiven wie `# shellcheck disable=...` sind
  keine Kommentare im Sinne dieser Regel und bleiben im Code.

---

## 5. Fehlerbehandlung & Sicherheit

- Fehlermeldungen immer auf `stderr`: `echo "Fehler: ..." >&2`
- Exit-Codes prüfen:

  if ! befehl; then
      echo "befehl fehlgeschlagen" >&2
      exit 1
  fi

- Eigene Exit-Codes: `0` = Erfolg, `1–2` für Bash reserviert, ab `3` eigene Codes.
- Aufräumarbeiten mit `trap`:

  tmpfile="$(mktemp)"
  trap 'rm -f "$tmpfile"' EXIT

- Temporäre Dateien **nur** über `mktemp` erstellen, nie nach `/tmp/name` hardcoden.
- `eval` und `source` nur mit vollständig kontrollierten Eingaben verwenden.
- Niemals `rm -rf` mit ungeschützten Variablen – Variablen vorher validieren:

  [[ -n "$ziel" && "$ziel" != "/" ]] || { echo "Ungültiges Ziel" >&2; exit 1; }

- Keine hartcodierten Pfade – stattdessen Variablen am Skriptanfang definieren.

---

## 6. Benutzerschnittstelle

- Jedes interaktive Skript bietet `-h` / `--help` mit Usage-Text.
- Bei falschen Argumenten: Usage ausgeben und mit Exit-Code `2` beenden.
- Ausgaben strukturieren: Infos nach `stdout`, Fehler/Warnungen nach `stderr`.

---

## 7. Qualitätssicherung

Vor jedem Commit müssen bestehen:


shellcheck skript.sh     # Linting, 0 Fehler
bash -n skript.sh        # Syntaxprüfung


- Befunde von `shellcheck` beheben, nicht per `# shellcheck disable` umgehen
  (Ausnahmen nur mit Begründung im Kommentar).
- Smoke-Test per Hand ausführen (mindestens der `--help`-Pfad).
- Optional: Tests mit `bats` im Ordner `tests/`.

### Keine Wiederholung bereits bestandener Tests (Kostenregel)

- **Grundregel:** Wenn Tests gemacht werden, dann **nur Tests für die
  Funktionen, die geändert wurden**. Tests, die vorher schon **grün**
  waren, werden **nicht** jedes Mal neu ausgeführt – **nur bei Änderung
  der betreffenden Funktion**. Auch nicht "zur Sicherheit", aus
  Gewohnheit oder weil eine Übergabe-/Checkliste sie noch einmal
  aufzählt.
- Vor jedem Testlauf prüfen: Was wurde seit dem letzten grünen Lauf
  tatsächlich geändert? Genau diese Teile – und nur diese – testen,
  nicht die ganze Suite.
- Begründung: Wiederholungsläufe kosten unnötig Geld (Agent-Tokens) und
  sind unnötiger Aufwand, der nicht entstehen muss.
- Der Agent muss das **selbstständig erkennen und einhalten**, BEVOR er
  einen Testlauf startet.

### Absolutes Verbot: Token-Verbrennung für Testskripte & Testschleifen

- **Kein Umschreiben, Erweitern, Härtung oder Reparatur von
  Testskripten** (tests/, Harness, Diagnose-Skripte, Workarounds für die
  Testumgebung) ohne **ausdrückliche Benutzeranweisung**. Harness-Arbeit
  verbessert das Produkt nicht und verbrennt Tokens – grundsätzlich
  unterlassen. Die Testumgebung wird akzeptiert, wie sie ist.
- **Absolutes Verbot von Testschleifen:** Ein Test, der **2-mal
  fehlgeschlagen** ist, wird **verworfen** (aus der Suite entfernt bzw.
  als VERWORFEN markiert) und **niemals wieder ausgeführt**. Kein
  dritter Lauf, keine "Härtung" des Tests, keine erneute Diagnose,
  kein Reproduktionsversuch.
- Ein harness-seitiger FAIL begründet **niemals** weitere Analyse- oder
  Korrekturläufe: Ist der Hauptcode isoliert als korrekt nachgewiesen,
  gilt er als verifiziert – Punkt. Der verworfene Test wird nur noch in
  der Task.md vermerkt, fertig.

---

## 8. Git & Commits

- Kleine, atomare Commits mit aussagekräftigen Messages (Conventional Commits
  empfohlen: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`).
- Nur `.sh`-Dateien und Doku committen – keine Backups (`*.bak`, `*.orig`),
  Editor-Dateien oder Logs. `.gitignore` pflegen.
- Skripte werden mit `chmod +x` und Zeilenenden `LF` (nicht `CRLF`) committed.

### Veröffentlichungsverbot (GitHub / öffentliche Repos)

- **`Task.md` und `.gitignore` dürfen NICHT im git-Repo veröffentlicht
  werden.** `Task.md` enthält interne Arbeits- und Sitzungsnotizen und
  bleibt lokal; `.gitignore` wird ebenfalls nicht veröffentlicht.
- Vor jedem Commit/Upload prüfen, dass beide Dateien nicht gestaged
  sind; die lokale `.gitignore` listet sie selbst (dann kann nichts
  versehentlich committet werden, solange sie lokal vorhanden ist).

---

## 9. Verboten (für Agenten)

- Secrets, Credentials oder private Daten einfügen oder loggen.
- Bezahlte Services oder nicht-freie Abhängigkeiten vorschlagen.
- `sudo`-Befehle ohne explizite Kennzeichnung im Code einbauen.
- Bestehende Dateien umbenennen, verschieben oder löschen, wenn es nicht zur
  Aufgabe gehört.
- Umfangreiche Refaktorings ohne Aufforderung.
- Code-Blöcke ausgeben, statt sie direkt in die Dateien zu schreiben.
- **README.md nur auf ausdrückliche Anweisung des Benutzers
  aktualisieren.** Keine automatischen, "beiläufigen" oder
  mitgelaufenden README-Änderungen (auch nicht nach Funktions-
  oder Versionsänderungen am Skript) – die README ist
  benutzergesteuert, nicht agentengesteuert.

---

## 10. Bei Unsicherheit

Wenn eine Anforderung mehrdeutig ist oder Sicherheitsrisiken birgt:
1. Nachfragen statt raten.
2. Den konservativsten, portabelsten Ansatz wählen.
3. Die Entscheidung im Commit bzw. in der Antwort begründen.

---

## 11. Docker-Tests (Container-Klone statt Neu-Download)

- Docker steht zum Testen zur Verfügung. Test-Images nur **einmal**
  herunterladen und danach stets wiederverwenden.
- Vor jedem Pull prüfen, ob das Image lokal existiert (`docker images`).
  Neu herunterladen nur, wenn Updates dafür vorhanden sind (bei
  unverändertem Digest lädt `docker pull` nichts herunter) oder ein Test
  ausdrücklich ein jungfräuliches Basis-Image verlangt.
- Das einmalige Grund-Setup (Test-Werkzeuge installieren) in einem
  Container erledigen und den Zustand per `docker commit` als **Klon**
  sichern (z. B. `clonie-test-ubuntu`, `clonie-test-arch`,
  `clonie-test-alpine`). Weitere Tests laufen gegen diese Klone, nicht
  gegen frisch heruntergeladene Basis-Images.
- Test-Container nach Gebrauch entfernen (`docker rm -f`); die
  Klon-Images bleiben für Folgetests erhalten. Bei Platzmangel dürfen
  Klone per `docker rmi` gelöscht und aus dem Basis-Image neu aufgebaut
  werden – ohne erneuten Basis-Download, solange das Basis-Image lokal
  liegt.
- Es gilt zusätzlich die Kostenregel aus §7: Distributionen/Checks, die
  beim letzten Lauf bereits grün waren, **nicht** erneut laufen lassen
  (siehe §7 "Keine Wiederholung bereits bestandener Tests").

---

## 12. Versionierung

- Jedes Haupt-Skript (z. B. `clonie`) trägt eine Versionsnummer im
  Format `HAUPT.NEBEN` (z. B. `1.1`, `3.2`) in einer Variablen
  `VERSION` und zeigt sie per `-V` / `--version`.
- **JEDE Bearbeitung des Haupt-Codes** erhöht die Nebenversion um 0,1:
  `1.1 -> 1.2 -> ... -> 1.9 -> 2.0 -> 2.1 ...`
- Nach `.9` geht es mit der nächsten Hauptversion weiter (`1.9 -> 2.0`,
  `3.9 -> 4.0`) – nie `1.10`.
- **Nicht** gezählt werden Änderungen nur an Dokumentation (`Task.md`,
  `AGENTS.md`, `DESIGN.md`) oder nur am Test-Harness (`tests/`) – nur
  geänderter Haupt-Code zählt.
- Die jeweils aktuelle Version in der `Task.md` festhalten (Stände der
  Dateien).

---

## 13. Backup vor jeder Bearbeitung

- **Vor JEDER Bearbeitung des Haupt-Skripts** (z. B. `clonie`) ist zuerst
  eine Sicherungskopie der aktuellen Fassung im Ordner `old/` anzulegen –
  mit der Versionsnummer, die die Datei **vor** der Bearbeitung trägt:

      mkdir -p old && cp -p clonie old/clonie-<VERSION>

  Beispiel: Vor der Änderung von Version `5.0` auf `5.1` liegt danach
  `old/clonie-5.0` (unveränderte Vorversion).
- Der Backup ist der **erste** Arbeitsschritt, bevor die Skriptdatei
  selbst angetastet wird.
- `old/` gehört nicht in Commits (in `.gitignore` aufnehmen, sobald ein
  Repository existiert); der Ordner selbst bleibt im Projekt erhalten.
- Alte Sicherungen werden nur nach ausdrücklicher Benutzeranweisung
  gelöscht.
