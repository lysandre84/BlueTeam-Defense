#!/usr/bin/env python3
"""
=====================================================================================================================================================
   
 /$$$$$$$  /$$                  /$$$$$$$$                                        /$$$$$$$             /$$$$$$                                       
| $$__  $$| $$                 |__  $$__/                                       | $$__  $$           /$$__  $$                                       
| $$  \ $$| $$ /$$   /$$  /$$$$$$ | $$  /$$$$$$   /$$$$$$  /$$$$$$/$$$$         | $$  \ $$  /$$$$$$ | $$  \__//$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$ 
| $$$$$$$ | $$| $$  | $$ /$$__  $$| $$ /$$__  $$ |____  $$| $$_  $$_  $$ /$$$$$$| $$  | $$ /$$__  $$| $$$$   /$$__  $$| $$__  $$ /$$_____/ /$$__  $$ 
| $$__  $$| $$| $$  | $$| $$$$$$$$| $$| $$$$$$$$  /$$$$$$$| $$ \ $$ \ $$|______/| $$  | $$| $$$$$$$$| $$_/  | $$$$$$$$| $$  \ $$|  $$$$$$ | $$$$$$$$ 
| $$  \ $$| $$| $$  | $$| $$_____/| $$| $$_____/ /$$__  $$| $$ | $$ | $$        | $$  | $$| $$_____/| $$    | $$_____/| $$  | $$ \____  $$| $$_____/
| $$$$$$$/| $$|  $$$$$$/|  $$$$$$$| $$|  $$$$$$$|  $$$$$$$| $$ | $$ | $$        | $$$$$$$/|  $$$$$$$| $$    |  $$$$$$$| $$  | $$ /$$$$$$$/|  $$$$$$$
|_______/ |__/ \______/  \_______/|__/ \_______/ \_______/|__/ |__/ |__/        |_______/  \_______/|__/     \_______/|__/  |__/|_______/  \_______/
   
=====================================================================================================================================================
=====================================================================================================================================================
 Script     : dns_sinkhole.py
 Auteur     : Lysius
 Date       : 21/01/2025
 Description: DNS “sinkhole” qui intercepte les réponses DNS et applique dynamiquement des règles
              iptables pour bloquer ou rediriger la résolution des domaines malveillants
              listés dans config.json.
=====================================================================================================================================================
"""

import json
import logging
import os
import subprocess
import sys
from scapy.all import DNS, DNSRR, sniff

# --- Chemins et paramètres ---
CONFIG_PATH    = "/etc/dns_sinkhole/config.json"
LOG_PATH       = "/var/log/dns_sinkhole.log"
CHAIN_NAME     = "SINKHOLE"
IPTABLES_CMD   = "/sbin/iptables"  # Chemin complet pour fiabilité

# --- Configuration du logger ---
logger = logging.getLogger("dns_sinkhole")
logger.setLevel(logging.INFO)
handler = logging.FileHandler(LOG_PATH)
formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)


def load_config(path):
    """Charge la liste des domaines malveillants depuis un fichier JSON."""
    if not os.path.isfile(path):
        logger.error(f"Fichier de config introuvable : {path}")
        sys.exit(1)
    try:
        with open(path) as cfg_file:
            data = json.load(cfg_file)
        domains = data.get("bad_domains", [])
        logger.info(f"{len(domains)} domaines malveillants chargés")
        return set(domains)
    except json.JSONDecodeError as err:
        logger.error(f"Erreur JSON dans {path} : {err}")
        sys.exit(1)


def setup_chain(chain):
    """Crée la chaîne iptables si nécessaire et l’insère en OUTPUT."""
    # Tenter de créer la chaîne (ignore si existe)
    subprocess.run([IPTABLES_CMD, "-N", chain], stderr=subprocess.DEVNULL)
    # Vérifier si la chaîne est déjà référencée en OUTPUT
    rc = subprocess.run([IPTABLES_CMD, "-C", "OUTPUT", "-j", chain], stderr=subprocess.DEVNULL)
    if rc.returncode != 0:
        subprocess.run([IPTABLES_CMD, "-I", "OUTPUT", "1", "-j", chain])
        logger.info(f"Chaîne {chain} insérée dans OUTPUT")


def block_domain(chain, domain):
    """Ajoute une règle DROP pour le domaine spécifié."""
    cmd = [
        IPTABLES_CMD, "-A", chain,
        "-p", "udp", "--dport", "53",
        "-m", "string", "--string", domain,
        "--algo", "bm", "-j", "DROP"
    ]
    result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode == 0:
        logger.info(f"Domaine bloqué : {domain}")
    else:
        logger.warning(f"Échec blocage domaine : {domain}")


def packet_handler(pkt):
    """Traite chaque paquet DNS, bloque si domaine malveillant."""
    if pkt.haslayer(DNSRR):
        for i in range(pkt[DNS].ancount):
            answer = pkt[DNSRR][i]
            qname = answer.rrname.decode(errors="ignore").rstrip(".")
            if qname in bad_domains:
                block_domain(CHAIN_NAME, qname)
                print(f"[!] Sinkhole applied: {qname}")


if __name__ == "__main__":
    if os.geteuid() != 0:
        print("Ce script doit être exécuté en root.", file=sys.stderr)
        sys.exit(1)

    bad_domains = load_config(CONFIG_PATH)
    setup_chain(CHAIN_NAME)
    logger.info("Configuration iptables prête, début de la capture DNS")

    try:
        sniff(filter="udp port 53", prn=packet_handler, store=False)
    except Exception as e:
        logger.exception(f"Plantage inattendu : {e}")
        sys.exit(1)
