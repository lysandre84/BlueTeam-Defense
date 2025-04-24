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
# Script     : baseline_audit.sh
# Auteur     : Lysius
# Date       : 20/08/2022
# Description: Audit système complet :
#              • Recherche SUID/SGID suspects
#              • Liste ports à l’écoute non standards
#              • Historique des installations récentes
#              • Configurable via /etc/baseline_audit.conf
# =====================================================================================================================================================

CONFIG_FILE="/etc/baseline_audit.conf"
TIMESTAMP=$(date +%F)
REPORT_DIR="/var/log"
REPORT_FILE="$REPORT_DIR/baseline_audit_${TIMESTAMP}.log"

load_config() {
    if [[ -r "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
    PORTS_WHITELIST=${PORTS_WHITELIST:-"22,80,443"}
    DPLOGS=${DPLOGS:-"/var/log/dpkg.log /var/log/yum.log"}
}

init_report() {
    mkdir -p "$REPORT_DIR"
    echo "Audit démarré à $(date -Is)" > "$REPORT_FILE"
}

audit_suid() {
    echo -e "\n== SUID/SGID suspects ==" >> "$REPORT_FILE"
    find / -perm /6000 -type f -printf '%M %u %g %p\n' 2>/dev/null | \
        grep -Ev "^.r.?r.? .+ (root|root) /usr/(bin|sbin)/" >> "$REPORT_FILE"
}

audit_ports() {
    echo -e "\n== Ports à l’écoute non standards ==" >> "$REPORT_FILE"
    IFS=',' read -ra WHITELIST <<< "$PORTS_WHITELIST"
    ss -tuln 2>/dev/null | awk 'NR>1 {print $5}' | \
    while read -r addr; do
        port=${addr##*:}
        skip=false
        for w in "${WHITELIST[@]}"; do
            [[ "$port" == "$w" ]] && skip=true
        done
        $skip || echo "$addr"
    done >> "$REPORT_FILE"
}

audit_install() {
    echo -e "\n== Installations récentes ==" >> "$REPORT_FILE"
    grep " install " $DPLOGS 2>/dev/null | tail -n 20 >> "$REPORT_FILE"
}

main() {
    load_config
    init_report
    audit_suid
    audit_ports
    audit_install
    echo -e "\nAudit terminé à $(date -Is)" >> "$REPORT_FILE"
    echo "Rapport disponible : $REPORT_FILE"
}

main "$@"
