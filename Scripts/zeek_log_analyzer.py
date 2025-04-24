#!/usr/bin/env python3
"""
====================================================================================================================================================
   
 /$$$$$$$  /$$                  /$$$$$$$$                                        /$$$$$$$             /$$$$$$                                       
| $$__  $$| $$                 |__  $$__/                                       | $$__  $$           /$$__  $$                                       
| $$  \ $$| $$ /$$   /$$  /$$$$$$ | $$  /$$$$$$   /$$$$$$  /$$$$$$/$$$$         | $$  \ $$  /$$$$$$ | $$  \__//$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$ 
| $$$$$$$ | $$| $$  | $$ /$$__  $$| $$ /$$__  $$ |____  $$| $$_  $$_  $$ /$$$$$$| $$  | $$ /$$__  $$| $$$$   /$$__  $$| $$__  $$ /$$_____/ /$$__  $$ 
| $$__  $$| $$| $$  | $$| $$$$$$$$| $$| $$$$$$$$  /$$$$$$$| $$ \ $$ \ $$|______/| $$  | $$| $$$$$$$$| $$_/  | $$$$$$$$| $$  \ $$|  $$$$$$ | $$$$$$$$ 
| $$  \ $$| $$| $$  | $$| $$_____/| $$| $$_____/ /$$__  $$| $$ | $$ | $$        | $$  | $$| $$_____/| $$    | $$_____/| $$  | $$ \____  $$| $$_____/ 
| $$$$$$$/| $$|  $$$$$$/|  $$$$$$$| $$|  $$$$$$$|  $$$$$$$| $$ | $$ | $$        | $$$$$$$/|  $$$$$$$| $$    |  $$$$$$$| $$  | $$ /$$$$$$$/|  $$$$$$$ 
|_______/ |__/ \______/  \_______/|__/ \_______/ \_______/|__/ |__/ |__/        |_______/  \_______/|__/     \_______/|__/  |__/|_______/  \_______/ 

====================================================================================================================================================
 Script     : zeek_log_analyzer.py
 Auteur     : Lysius
 Date       : 30/07/2024
 Description: Parse un fichier de logs Zeek (TSV) et détecte les connexions de longue durée
              et les volumes d'upload anormalement élevés.
====================================================================================================================================================
"""

import argparse
import csv
import logging
import os
import sys
from collections import Counter

# Seuils par défaut
DEFAULT_DURATION_THRESHOLD = 3600     # secondes
DEFAULT_BYTE_THRESHOLD     = 1_000_000  # octets

def setup_logger(log_file):
    """Configure la journalisation dans un fichier."""
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    logging.basicConfig(
        filename=log_file,
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s"
    )
    logging.info("=== Démarrage de Zeek Log Analyzer ===")

def parse_zeek_log(input_path, duration_thresh, byte_thresh):
    """Parcourt un TSV Zeek et compte événements anormaux."""
    counters = Counter(long_conn=0, large_upload=0)
    try:
        with open(input_path, newline='') as csvfile:
            reader = csv.DictReader(csvfile, delimiter='\t')
            for row in reader:
                # Connexion trop longue
                dur = row.get('duration')
                if dur and dur.isdigit() and int(dur) > duration_thresh:
                    counters['long_conn'] += 1
                # Upload trop volumineux
                size = row.get('orig_bytes')
                if size and size.isdigit() and int(size) > byte_thresh:
                    counters['large_upload'] += 1
    except FileNotFoundError:
        logging.error(f"Fichier introuvable : {input_path}")
        print(f"Erreur : le fichier '{input_path}' n'existe pas.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        logging.error(f"Erreur lecture/parsing : {e}")
        print(f"Erreur lors de l'analyse : {e}", file=sys.stderr)
        sys.exit(1)
    return counters

def main():
    parser = argparse.ArgumentParser(description="Analyse un log Zeek TSV pour anomalies.")
    parser.add_argument("input", 
                        help="Chemin vers le fichier Zeek (.tsv)")
    parser.add_argument("--duration", "-d", type=int, default=DEFAULT_DURATION_THRESHOLD,
                        help="Seuil durée (s) pour identifier les connexions longues")
    parser.add_argument("--bytes", "-b", type=int, default=DEFAULT_BYTE_THRESHOLD,
                        help="Seuil octets pour détecter l'upload volumineux")
    parser.add_argument("--log", "-l", default="/var/log/zeek_log_analyzer.log",
                        help="Fichier de log pour les informations")
    args = parser.parse_args()

    setup_logger(args.log)
    logging.info(f"Fichier analysé : {args.input}")
    logging.info(f"Seuils - durée : {args.duration}s, octets : {args.bytes}")

    results = parse_zeek_log(args.input, args.duration, args.bytes)

    print(f"Connexions longues  (> {args.duration}s) : {results['long_conn']}")
    print(f"Upload volumineux   (> {args.bytes} octets) : {results['large_upload']}")

    logging.info(f"Connexions longues: {results['long_conn']}, Upload volumineux: {results['large_upload']}")

if __name__ == "__main__":
    main()
