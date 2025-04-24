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
# Script     : log_enrichment.sh
# Auteur     : Lysius
# Date       : 10/04/2022
# Description: Enrichit les logs d'authentification avec la géolocalisation IP.
#              • Lecture des chemins (input, output), commande geoip et log depuis config JSON.
#              • Journalisation des traitements et gestion des erreurs.
#              • Traitement ligne par ligne et export enrichi.
# =====================================================================================================================================================

CONFIG_FILE="/etc/log_enrichment.conf"
LOG_FILE="/var/log/log_enrichment.log"
DEFAULT_INPUT="/var/log/auth.log"
DEFAULT_OUTPUT="/var/log/auth_enriched.log"
DEFAULT_GEOIP_CMD="geoiplookup"

load_config() {
    local cfg="$1"
    if [[ -r "$cfg" ]]; then
        source "$cfg"
    fi
    INPUT_LOG="${INPUT_LOG:-$DEFAULT_INPUT}"
    OUTPUT_LOG="${OUTPUT_LOG:-$DEFAULT_OUTPUT}"
    GEOIP_CMD="${GEOIP_CMD:-$DEFAULT_GEOIP_CMD}"
    LOG_FILE="${LOG_FILE:-$LOG_FILE}"
}

log_info() {
    echo "$(date -Is) [INFO] $1" >> "$LOG_FILE"
}

log_error() {
    echo "$(date -Is) [ERROR] $1" >> "$LOG_FILE"
}

enrich_line() {
    local line="$1"
    local ip
    ip=$(echo "$line" | grep -oP 'from \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    if [[ -n "$ip" && -x "$(command -v $GEOIP_CMD)" ]]; then
        local geo
        geo=$($GEOIP_CMD "$ip" 2>/dev/null | awk -F': ' '{print $2}')
        [[ -z "$geo" ]] && geo="N/A"
    else
        geo="N/A"
    fi
    echo "$line | GEO:$geo"
}

main() {
    load_config "$CONFIG_FILE"
    mkdir -p "$(dirname "$OUTPUT_LOG")" "$(dirname "$LOG_FILE")"
    touch "$OUTPUT_LOG" "$LOG_FILE"
    log_info "Démarrage enrichissement : $INPUT_LOG -> $OUTPUT_LOG"

    if [[ ! -r "$INPUT_LOG" ]]; then
        log_error "Fichier introuvable ou non lisible : $INPUT_LOG"
        exit 1
    fi

    # Traitement
    while IFS= read -r line; do
        if enriched=$(enrich_line "$line"); then
            echo "$enriched" >> "$OUTPUT_LOG"
        else
            log_error "Échec enrichissement ligne : $line"
        fi
    done < "$INPUT_LOG"

    log_info "Enrichissement terminé, ${OUTPUT_LOG} généré"
}

main "$@"
