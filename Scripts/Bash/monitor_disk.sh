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
# Script     : disk_usage_alert.sh
# Auteur     : Lysius
# Date       : 23/04/2024
# Description: Surveille l’utilisation disque et alerte si elle dépasse un seuil configuré.
#              • Seuil, partition, email et log configurables via /etc/disk_usage_alert.conf.
#              • Journalise chaque contrôle avec timestamp et valeur mesurée.
#              • Envoie un email d’alerte si nécessaire.
# =====================================================================================================================================================

CONFIG_FILE="/etc/disk_usage_alert.conf"
LOG_FILE="/var/log/disk_usage_alert.log"

# Valeurs par défaut
DEFAULT_THRESHOLD=80
DEFAULT_PARTITION="/"
DEFAULT_EMAIL="admin@example.com"

# Charger la configuration
if [[ -r "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi
THRESHOLD=${THRESHOLD:-$DEFAULT_THRESHOLD}
PARTITION=${PARTITION:-$DEFAULT_PARTITION}
EMAIL=${EMAIL:-$DEFAULT_EMAIL}

# Fonction de journalisation
log() {
    echo "$(date -Is) $1" >> "$LOG_FILE"
}

# Vérifier l’espace disque
check_disk() {
    local usage
    usage=$(df "$PARTITION" --output=pcent | tail -1 | tr -dc '0-9')
    log "Usage disque sur $PARTITION : ${usage}% (seuil ${THRESHOLD}%)"
    if (( usage > THRESHOLD )); then
        local subject="ALERTE DISK: ${PARTITION} à ${usage}%"
        local body="Alerte : la partition $PARTITION est à ${usage}% d’utilisation, seuil fixé à ${THRESHOLD}%."
        echo "$body" | mail -s "$subject" "$EMAIL"
        log "Email d’alerte envoyé à $EMAIL"
    fi
}

# Initialisation
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Exécution
check_disk
