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
 Script     : vuln_report_generator.py
 Auteur     : Lysius
 Date       : 15/12/2024
 Description: Extrait les erreurs et warnings d’un fichier de log texte et génère un rapport CSV.
              • Lit la configuration (niveaux, motif, chemins) depuis config.json.
              • Compile dynamiquement le regex et filtre les lignes correspondantes.
              • Journalise l’extraction et gère les exceptions I/O.
=====================================================================================================================================================
"""

import argparse
import csv
import json
import logging
import os
import re
import sys

# --- Chemins et valeurs par défaut ---
CONFIG_PATH = "/etc/log_error_parser/config.json"
DEFAULTS = {
    "levels": ["ERROR", "WARN"],
    "pattern": r"\[(?P<date>[^]]+)\] (?P<level>LEVEL) (?P<msg>.+)",
    "output_csv": "/var/log/vuln_report.csv",
    "log_path": "/var/log/log_error_parser.log"
}


def load_config(path):
    """Charge la configuration depuis un JSON ou renvoie DEFAULTS."""
    cfg = DEFAULTS.copy()
    if os.path.isfile(path):
        try:
            with open(path) as f:
                user_cfg = json.load(f)
            cfg.update(user_cfg)
        except Exception as e:
            print(f"⚠️ Échec chargement config {path}: {e}", file=sys.stderr)
    return cfg


def init_logger(log_path):
    """Configure le logger vers un fichier."""
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    logger = logging.getLogger("vuln_report")
    handler = logging.FileHandler(log_path)
    handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.info("Démarrage vuln_report_generator")
    return logger


def compile_regex(raw_pattern, levels):
    """Remplace placeholder LEVEL par la classe regex et compile."""
    levels_re = "|".join(re.escape(lvl) for lvl in levels)
    pattern = raw_pattern.replace("LEVEL", levels_re)
    return re.compile(pattern)


def parse_and_write(infile, outfile, regex, logger):
    """Parcourt infile, extrait les matches et écrit dans outfile."""
    try:
        with open(infile, errors="ignore") as fin, \
             open(outfile, "w", newline="") as fout:
            writer = csv.DictWriter(fout, fieldnames=["date", "level", "message"])
            writer.writeheader()
            count = 0
            for line in fin:
                match = regex.search(line)
                if match:
                    writer.writerow(match.groupdict())
                    count += 1
            logger.info(f"{count} entrées extraites vers {outfile}")
            print(f"[+] {count} entrées extraites vers {outfile}")
    except FileNotFoundError:
        logger.error(f"Fichier introuvable : {infile}")
        print(f"Erreur : fichier introuvable {infile}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        logger.error(f"Erreur traitement {infile}: {e}")
        print(f"Erreur lors du parsing: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Génère un rapport CSV d'erreurs depuis un log texte")
    parser.add_argument("-i", "--input",  required=True, help="Fichier log en entrée")
    parser.add_argument("-o", "--output", help="Chemin CSV de sortie")
    parser.add_argument("-c", "--config", help="Chemin config JSON", default=CONFIG_PATH)
    args = parser.parse_args()

    cfg = load_config(args.config)
    logger = init_logger(cfg["log_path"])

    infile = args.input
    outfile = args.output or cfg["output_csv"]
    os.makedirs(os.path.dirname(outfile), exist_ok=True)

    regex = compile_regex(cfg["pattern"], cfg["levels"])
    logger.info(f"Pattern compilé: {regex.pattern}")
    logger.info(f"Niveaux ciblés: {cfg['levels']}")

    parse_and_write(infile, outfile, regex, logger)


if __name__ == "__main__":
    main()
