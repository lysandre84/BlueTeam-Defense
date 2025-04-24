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
# Script     : firewall_auto_block.sh
# Auteur     : Lysius
# Date       : 28/11/2021
# Description: Moniteur SSH fail2ban-like en bash.  
#              Analyse /var/log/auth.log et bloque via iptables les IP dépassant un seuil  
#              de tentatives en fenêtre glissante, puis les débloque après durée configurable.
# =====================================================================================================================================================

# --- Configuration (modifiable dans /etc/firewall_auto_block.conf) ---
CONF_FILE="/etc/firewall_auto_block.conf"
LOG_FILE="/var/log/firewall_auto_block.log"

# Valeurs par défaut
THRESHOLD=5          # nombre d'échecs avant blocage
WINDOW_SEC=600       # fenêtre glissante (10 minutes)
BAN_DURATION=3600    # durée du ban (1 heure)
AUTH_LOG="/var/log/auth.log"
IPTABLES="/sbin/iptables"

# Charger la config si présente
if [[ -r "$CONF_FILE" ]]; then
    source "$CONF_FILE"
fi

# Initialisation
declare -A attempts
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log() {
    echo "$(date -Is) $1" >> "$LOG_FILE"
}

block_ip() {
    local ip=$1
    $IPTABLES -I INPUT -s "$ip" -j DROP
    log "Banni IP: $ip"
    # Planifier débannissement
    ( sleep "$BAN_DURATION"
      $IPTABLES -D INPUT -s "$ip" -j DROP
      log "Débanni IP: $ip"
    ) &
}

process_line() {
    local line=$1
    if [[ $line =~ Failed\ password.*\ from\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
        local ip=${BASH_REMATCH[1]}
        local now=$(date +%s)
        # Nettoyer les anciennes entrées
        attempts["$ip"]=$(echo "${attempts[$ip]}" | awk -v t="$now" -v w="$WINDOW_SEC" '
            { for(i=1;i<=NF;i++) if($i > t-w) printf "%s ", $i }
        ')
        # Ajouter la tentative actuelle
        attempts["$ip"]+="$now "
        # Compter les tentatives dans la fenêtre
        local count=$(echo "${attempts[$ip]}" | wc -w)
        log "IP $ip a $count échec(s)"
        if (( count >= THRESHOLD )); then
            block_ip "$ip"
            unset attempts["$ip"]
        fi
    fi
}

# Lancer la surveillance
log "Démarrage surveillance SSH : seuil $THRESHOLD, fenêtre $WINDOW_SEC s, ban $BAN_DURATION s"
tail -F "$AUTH_LOG" 2>/dev/null | while read -r line; do
    process_line "$line"
done
