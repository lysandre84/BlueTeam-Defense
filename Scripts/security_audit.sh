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
# Script     : security_audit.sh
# Auteur     : Lysius
# Date       : 02/01/2025
# Description: Réalise un audit de sécurité basique :
#              • Liste utilisateurs sudo
#              • Inventaire des ports ouverts
#              • Permissions des fichiers critiques sous /etc
#              • Configurable via /etc/security_audit.conf
# =====================================================================================================================================================

# --- Configuration et valeurs par défaut ---
CONF_FILE="/etc/security_audit.conf"
LOG_DIR="/var/log"
DATE_FMT="%F"
TIMESTAMP=$(date +"$DATE_FMT")
LOG_FILE="$LOG_DIR/security_audit_$TIMESTAMP.log"

# Charger la config si présente
if [[ -r "$CONF_FILE" ]]; then
    source "$CONF_FILE"
fi

# Fonction d'initialisation du rapport
init_report() {
    mkdir -p "$LOG_DIR"
    echo "## Sécurité Audit démarré à $(date -Is)" > "$LOG_FILE"
}

# Audit des utilisateurs sudo
audit_sudo_users() {
    echo -e "\n### Utilisateurs sudo" >> "$LOG_FILE"
    if getent group sudo &>/dev/null; then
        getent group sudo | awk -F: '{print $4}' >> "$LOG_FILE"
    else
        echo "Groupe sudo absent ou non lisible" >> "$LOG_FILE"
    fi
}

# Audit des ports ouverts
audit_open_ports() {
    echo -e "\n### Ports ouverts (TCP/UDP)" >> "$LOG_FILE"
    ss -tuln 2>/dev/null >> "$LOG_FILE" || echo "Impossible d'exécuter ss" >> "$LOG_FILE"
}

# Audit des permissions dans /etc
audit_etc_permissions() {
    echo -e "\n### Permissions /etc (20 premiers)" >> "$LOG_FILE"
    ls -l /etc 2>/dev/null | head -n 20 >> "$LOG_FILE" || echo "Impossible de lister /etc" >> "$LOG_FILE"
}

# Fonction principale
main() {
    init_report
    audit_sudo_users
    audit_open_ports
    audit_etc_permissions
    echo -e "\n## Audit terminé à $(date -Is)" >> "$LOG_FILE"
    echo "Audit complet. Rapport : $LOG_FILE"
}

main "$@"
