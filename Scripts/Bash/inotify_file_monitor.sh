#!/usr/bin/env bash
# =====================================================================================================================================================
#   
#  /$$$$$$$  /$$                  /$$$$$$$$                                        /$$$$$$$             /$$$$$$                                       
# | $$__  $$| $$                 |__  $$__/                                       | $$__  $$           /$$__  $$                                       
# | $$  \ $$| $$ /$$   /$$  /$$$$$$ | $$  /$$$$$$   /$$$$$$  /$$$$$$/$$$$         | $$  \ $$  /$$$$$$ | $$  \__//$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$ 
# | $$$$$$$ | $$| $$  | $$ /$$__  $$| $$ /$$__  $$ |____  $$| $$_  $$_  $$ /$$$$$$| $$  | $$ /$$__  $$| $$$$   /$$__  $$| $$__  $$ /$$_____/ /$$__  $$ 
# | $$__  $$| $$| $$  | $$| $$$$$$$$| $$| $$$$$$$$  /$$$$$$$| $$ \ $$ \ $$|______/| $$  | $$| $$$$$$$$| $$_/  | $$$$$$$$| $$  \ $$|  $$$$$$ | $$$$$$$$ 
# | $$  \ $$| $$| $$  | $$| $$_____/| $$| $$_____/ /$$__  $$| $$ | $$ | $$        | $$  | $$| $$_____/| $$    | $$_____/| $$  | $$ \____  $$| $$_____/ 
# | $$$$$$$/| $$|  $$$$$$/|  $$$$$$$| $$|  $$$$$$$|  $$$$$$$| $$ | $$ | $$        | $$$$$$$/|  $$$$$$$| $$    |  $$$$$$$| $$  | $$ /$$$$$$$/|  $$$$$$$ 
# |_______/ |__/ \______/  \_______/|__/ \_______/ \_______/|__/ |__/ |__/        |_______/  \_______/|__/     \_______/|__/  |__/|_______/  \_______/ 
#   
# =====================================================================================================================================================
# Script     : inotify_file_monitor.sh
# Auteur     : Lysius
# Date       : 15/07/2022
# Description: Surveillance temps réel de répertoires critiques, journalisation et alertes email pour fichiers sensibles.
#              • Répertoires et emails configurables via /etc/inotify_file_monitor.conf
#              • Fonctions modulaires pour logger, envoyer alertes, traiter événements
# =====================================================================================================================================================

# --- Configuration par défaut et chargement ---
CONF_FILE="/etc/inotify_file_monitor.conf"
LOG_FILE="/var/log/inotify_monitor.log"
WATCH_DIRS=("/etc" "/var/www")
ALERT_EMAIL="secops@example.com"
SENSITIVE_PATTERNS=("/etc/passwd" "/etc/shadow")

# Charger la config si présente
if [[ -r "$CONF_FILE" ]]; then
    source "$CONF_FILE"
fi

# --- Fonctions ---
log_event() {
    local msg="$1"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date -Is)] $msg" >> "$LOG_FILE"
}

send_alert() {
    local file="$1" event="$2" timestamp="$3"
    local subject="ALERTE CRITIQUE : $file modifié"
    local body="Le fichier $file a subi l'événement $event à $timestamp"
    {
        echo "Subject: $subject"
        echo
        echo "$body"
    } | sendmail "$ALERT_EMAIL"
    log_event "Alerte envoyée pour $file"
}

handle_event() {
    local timestamp="$1" dir="$2" event="$3" file="$4"
    local path="${dir%/}/$file"
    log_event "$event sur $path"
    for pattern in "${SENSITIVE_PATTERNS[@]}"; do
        if [[ "$path" == "$pattern" ]]; then
            send_alert "$path" "$event" "$timestamp"
        fi
    done
}

monitor_loop() {
    inotifywait -m -r \
        -e modify,create,delete,move \
        --format '%T %w %e %f' \
        --timefmt '%F %T' \
        "${WATCH_DIRS[@]}" | while read -r timestamp dir event file; do
        handle_event "$timestamp" "$dir" "$event" "$file"
    done
}

# --- Exécution principale ---
log_event "Démarrage du monitor inotify sur ${WATCH_DIRS[*]}"
monitor_loop
