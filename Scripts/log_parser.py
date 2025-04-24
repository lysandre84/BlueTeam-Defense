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
 Script     : log_parser.py
 Auteur     : Lysius
 Date       : 14/03/2025
 Description: Analyse d'un CSV de logs pour extraire des statistiques et générer un rapport.
              • Charge les options (colonnes, seuils, export) depuis un JSON.
              • Calcule taux d'erreur, IP uniques, etc.
              • Exporte vers JSON ou CSV et affiche un résumé en console.
=====================================================================================================================================================
"""

import argparse
import json
import logging
import os
import sys

import pandas as pd
from datetime import datetime

# --- Valeurs par défaut ---
DEFAULT_CONFIG = {
    "columns": None,            # liste de colonnes à charger (None = tout)
    "error_column": "status",   # colonne contenant le code/texte d'erreur
    "error_values": [],         # valeurs considérées comme "erreur"
    "ip_column": "source_ip",   # colonne des adresses IP
    "export": {
        "format": "json",       # "json" ou "csv"
        "path": "/var/log/log_parser_report.json"
    },
    "log_path": "/var/log/log_parser.log"
}
CONFIG_FILE = "/etc/log_parser/config.json"


def load_config(path):
    """Lit la config utilisateur et la fusionne avec les valeurs par défaut."""
    cfg = DEFAULT_CONFIG.copy()
    if os.path.isfile(path):
        try:
            with open(path) as f:
                user_cfg = json.load(f)
            # fusion récursive simplifiée
            for k, v in user_cfg.items():
                if isinstance(v, dict) and k in cfg:
                    cfg[k].update(v)
                else:
                    cfg[k] = v
        except Exception as err:
            print(f"⚠️ Erreur lecture config {path}: {err}", file=sys.stderr)
    return cfg


def setup_logger(logfile):
    """Configure le journal."""
    os.makedirs(os.path.dirname(logfile), exist_ok=True)
    logging.basicConfig(
        filename=logfile,
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s"
    )
    logging.info("log_parser démarré")


def parse_args():
    p = argparse.ArgumentParser(description="Analyse CSV de logs et génère un rapport")
    p.add_argument("csv_file", help="Chemin vers le fichier CSV de logs")
    p.add_argument("-c", "--config", help="Chemin vers config JSON", default=CONFIG_FILE)
    return p.parse_args()


def calculate_stats(df, cfg):
    """Retourne un dict de statistiques à partir du DataFrame."""
    total = len(df)
    errs = 0
    if cfg["error_values"]:
        errs = df[cfg["error_column"]].isin(cfg["error_values"]).sum()
    unique_ips = df[cfg["ip_column"]].nunique() if cfg["ip_column"] in df else 0
    rate = round((errs / total * 100), 2) if total else 0
    return {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "total_records": total,
        "error_records": int(errs),
        "error_rate_pct": rate,
        "unique_ips": int(unique_ips)
    }


def export_report(stats, cfg):
    """Exporte les stats vers le format et chemin désirés."""
    out_cfg = cfg["export"]
    path = out_cfg["path"]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if out_cfg["format"] == "csv":
        pd.DataFrame([stats]).to_csv(path, index=False)
    else:
        with open(path, "w") as f:
            json.dump(stats, f, indent=2)
    logging.info(f"Rapport exporté vers {path}")


def main():
    args = parse_args()
    cfg = load_config(args.config)
    setup_logger(cfg["log_path"])

    # Lecture du CSV
    try:
        df = pd.read_csv(args.csv_file, usecols=cfg["columns"])
        logging.info(f"Chargé {len(df)} lignes depuis {args.csv_file}")
    except Exception as err:
        logging.critical(f"Impossible de charger le CSV: {err}")
        sys.exit(1)

    stats = calculate_stats(df, cfg)
    logging.info(f"Stats calculées: {stats}")

    try:
        export_report(stats, cfg)
    except Exception as err:
        logging.error(f"Échec export rapport: {err}")

    # Affichage console
    print("\n=== Rapport log_parser ===")
    for key, val in stats.items():
        print(f"{key:20}: {val}")


if __name__ == "__main__":
    main()
