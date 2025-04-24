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
 Script     : ml_anomaly_detector.py
 Auteur     : Lysius
 Date       : 10/11/2024
 Description: IsolationForest sur métriques réseau, détection et export des anomalies.
              • Lit la config (features, contamination, export) depuis JSON.
              • Journalise chaque étape et les anomalies détectées.
              • Exporte le résultat en CSV ou JSON.
=====================================================================================================================================================
"""

import argparse
import json
import logging
import os
import sys
import pandas as pd
from sklearn.ensemble import IsolationForest

# --- Chemins et valeurs par défaut ---
CONFIG_FILE = "/etc/ml_detector/config.json"
DEFAULTS = {
    "features": ["bytes_sent", "bytes_received", "duration"],
    "contamination": 0.01,
    "export": {
        "format": "csv",       # "csv" ou "json"
        "path": "/var/log/anomalies.csv"
    },
    "log_path": "/var/log/ml_anomaly_detector.log"
}


def load_config(path):
    """Charge la configuration utilisateur ou retourne les valeurs par défaut."""
    cfg = DEFAULTS.copy()
    try:
        with open(path) as f:
            user = json.load(f)
        # Fusion simple
        for key, val in user.items():
            if isinstance(val, dict) and key in cfg:
                cfg[key].update(val)
            else:
                cfg[key] = val
    except FileNotFoundError:
        pass  # on garde les DEFAULTS
    except json.JSONDecodeError as e:
        print(f"⚠️ Erreur JSON config: {e}", file=sys.stderr)
    return cfg


def init_logger(log_file):
    """Configure le logger."""
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    logger = logging.getLogger("ml_detector")
    handler = logging.FileHandler(log_file)
    fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    handler.setFormatter(fmt)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.info("Démarrage ml_anomaly_detector")
    return logger


def parse_args():
    p = argparse.ArgumentParser(description="Détecteur d'anomalies réseau")
    p.add_argument("csv_input", help="CSV des métriques réseau")
    p.add_argument("-c", "--config", help="Chemin config JSON", default=CONFIG_FILE)
    return p.parse_args()


def detect_anomalies(df, features, contamination, logger):
    """Entraîne IsolationForest et renvoie les lignes anormales."""
    model = IsolationForest(contamination=contamination, random_state=42)
    model.fit(df[features])
    scores = model.decision_function(df[features])
    preds = model.predict(df[features])
    df_result = df.copy()
    df_result["anomaly_score"] = scores
    df_result["anomaly"] = preds
    anomalies = df_result[df_result["anomaly"] == -1]
    logger.info(f"{len(anomalies)} anomalies détectées sur {len(df)} enregistrements")
    return anomalies


def export_anomalies(anomalies, export_cfg, logger):
    """Exporte les anomalies selon le format choisi."""
    os.makedirs(os.path.dirname(export_cfg["path"]), exist_ok=True)
    if export_cfg["format"] == "json":
        anomalies.to_json(export_cfg["path"], orient="records", date_format="iso")
    else:
        anomalies.to_csv(export_cfg["path"], index=False)
    logger.info(f"Anomalies exportées vers {export_cfg['path']}")


def main():
    args = parse_args()
    cfg = load_config(args.config)
    logger = init_logger(cfg["log_path"])

    try:
        df = pd.read_csv(args.csv_input)
        logger.info(f"Chargé {len(df)} lignes depuis {args.csv_input}")
    except Exception as e:
        logger.critical(f"Impossible de lire CSV: {e}")
        sys.exit(1)

    features = cfg["features"]
    contamination = cfg["contamination"]
    anomalies = detect_anomalies(df, features, contamination, logger)

    export_anomalies(anomalies, cfg["export"], logger)

    # Résumé console
    print("=== Anomalies ===")
    if anomalies.empty:
        print("Aucune anomalie détectée.")
    else:
        print(anomalies.head())


if __name__ == "__main__":
    main()
