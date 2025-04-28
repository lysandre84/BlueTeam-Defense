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
# =====================================================================================================================================================
# Script     : cpu_monitor.sh
# Auteur     : Lysius
# Date       : 23/04/2021
# Description: Surveille l'utilisation CPU et envoie un email si elle dépasse le seuil configuré.
#              • Lecture des paramètres (seuil, email, log, intervalle) depuis /etc/cpu_monitor.conf.
#              • Calcul précis de l'utilisation CPU via /proc/stat.
#              • Journalisation et gestion des erreurs.
# =====================================================================================================================================================

# Chemins et valeurs par défaut
CONFIG_FILE="/etc/cpu_monitor.conf"
LOG_FILE="/var/log/cpu_monitor.log"

# Valeurs par défaut
DEFAULT_THRESHOLD=80
DEFAULT_EMAIL="toto@example.com"
DEFAULT_INTERVAL=60

# Chargement de la configuration
if [[ -r "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi
THRESHOLD=${THRESHOLD:-$DEFAULT_THRESHOLD}
EMAIL=${EMAIL:-$DEFAULT_EMAIL}
INTERVAL=${INTERVAL:-$DEFAULT_INTERVAL}

# Fonction de journalisation
log() {
    local msg="$1"
    echo "$(date -Is) $msg" >> "$LOG_FILE"
}

# Calcul de l'utilisation CPU sur un intervalle de 1s
get_cpu_usage() {
    read -r _ user1 nice1 sys1 idle1 iowait1 irq1 softirq1 steal1 guest1 guest_nice1 < <(head -n1 /proc/stat)
    total1=$((user1+nice1+sys1+idle1+iowait1+irq1+softirq1+steal1))
    sleep 1
    read -r _ user2 nice2 sys2 idle2 iowait2 irq2 softirq2 steal2 guest2 guest_nice2 < <(head -n1 /proc/stat)
    total2=$((user2+nice2+sys2+idle2+iowait2+irq2+softirq2+steal2))
    idle_delta=$((idle2 - idle1))
    total_delta=$((total2 - total1))
    # utilisation = 100 * (total_delta - idle_delta) / total_delta
    echo $(( ( (total_delta - idle_delta) * 100 ) / total_delta ))
}

# Vérification et action
check_and_alert() {
    local cpu_usage
    cpu_usage=$(get_cpu_usage)
    log "CPU usage: ${cpu_usage}% (threshold: ${THRESHOLD}%)"
    if (( cpu_usage > THRESHOLD )); then
        local subject="ALERTE CPU: ${cpu_usage}%"
        local body="Alerte CPU: utilisation actuelle ${cpu_usage}% dépasse le seuil de ${THRESHOLD}%."
        echo "$body" | mail -s "$subject" "$EMAIL"
        log "Alerte envoyée à ${EMAIL}"
    fi
}

# Création du fichier de log si nécessaire
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Exécution (à lancer en cron ou en boucle)
check_and_alert



# /etc/cpu_monitor.conf 
# Seuil d'alerte CPU en pourcentage
#THRESHOLD=75

# Adresse email de notification
#EMAIL=ops-ToTo@example.com

# Intervalle entre chaque vérification (secondes)
#INTERVAL=120