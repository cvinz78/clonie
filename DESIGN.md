# design.md – Bash-Skript-Farbschema

# Überschrift 1 (Hell Grün)
echo -e "\033[1;92m# Überschrift 1 (Hell Grün)\033[0m"

# Überschrift 2 (Hell Grün)
echo -e "\033[1;92m## Überschrift 2 (Hell Grün)\033[0m"

# Normaler Text (Hell Cyan)
echo -e "\033[1;96mDies ist normaler Text in Hell Cyan.\033[0m"

# Geräte-Namen (gefundene Festplatten/Partitionen, Hell Cyan)
echo -e "\033[1;96m/dev/sda\033[0m  500G  [ext4]"

# Warnung / Fehler (Hell Rot)
echo -e "\033[1;91mWARNUNG: Dies ist eine Fehlermeldung in Hell Rot.\033[0m"

# Datei / Befehl (Hell Lila)
echo -e "\033[1;35mDatei: /pfad/zur/datei.sh, Befehl: ls -la\033[0m"

# Alles andere (Hell Grün)
echo -e "\033[1;92mDieser Abschnitt ist Everything Else in Hell Grün.\033[0m"

# Farbschema-Referenzen (nur Beispiele)
# Headers -> Hell Grün: \033[1;92m
# Body Text -> Hell Cyan: \033[1;96m
# Device names (Festplatten/Partitionen) -> Hell Cyan: \033[1;96m
# Warnings -> Hell Rot: \033[1;91m
# File/Command labels -> Hell Lila: \033[1;35m
# Other -> Hell Grün: \033[1;92m
# Reset: \033[0m

# Hinweise zur Implementierung
# Verwende ANSI-ESC-Sequenzen wie \033[1;3Xm oder \033[1;3Xmm, entsprechend dem gewünschten Farbcode.
# Kombiniere mit [0m, um Farbsetzung zurückzusetzen.
# Wenn du Enums oder Variablen bevorzugst, kannst du Farbkonstanten definieren:

GREEN_H="\033[1;92m"     # Hell Grün (Überschriften, "Everything Else")
CYAN_H="\033[1;96m"      # Hell Cyan (Text, Geräte-Namen)
RED_H="\033[1;91m"       # Hell Rot
MAGENTA_L="\033[1;35m"   # Hell Lila
RESET="\033[0m"          # Reset

# Beispiel:
echo -e "${GREEN_H}# Überschrift${RESET}"
echo -e "${CYAN_H}Normaler Text${RESET}"
echo -e "${CYAN_H}/dev/sda${RESET} 500G [ext4]"
echo -e "${RED_H}Warnung: Fehler${RESET}"
echo -e "${MAGENTA_L}Datei: /pfad/zur/datei.sh${RESET}"
echo -e "${GREEN_H}Alles andere${RESET}"
