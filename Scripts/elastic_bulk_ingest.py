#!/usr/bin/env python3
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
# Script     : elastic_bulk_ingest.py
# Auteur     : Lysius
# Date       : 25/02/2025
# Description: Optimise l'ingestion de logs vers Elasticsearch via l'API Bulk.
#              • Lit la config (ES hosts, index, batch size, log file) depuis JSON.
#              • Journalise chaque lot et gère proprement les erreurs.
# =====================================================================================================================================================

import json
import logging
import os
import sys
from datetime import datetime
from elasticsearch import Elasticsearch, helpers
from elasticsearch.exceptions import ElasticsearchException

CONFIG_FILE = "/etc/elastic_ingest/config.json"
DEFAULTS = {
    "es_hosts": ["http://localhost:9200"],
    "index": "logs",
    "batch_size": 500,
    "log_file": "/var/log/elastic_bulk_ingest.log"
}

def load_config(path):
    cfg = DEFAULTS.copy()
    if os.path.exists(path):
        try:
            with open(path) as f:
                user_cfg = json.load(f)
            cfg.update(user_cfg)
        except Exception as e:
            print(f"⚠️ Échec lecture config {path}: {e}")
    return cfg

def init_logger(log_path):
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    logger = logging.getLogger("elastic_ingest")
    handler = logging.FileHandler(log_path)
    formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.info("Démarrage elastic_bulk_ingest")
    return logger

def connect_es(hosts, logger):
    try:
        es = Elasticsearch(hosts)
        # ping to check
        if not es.ping():
            raise ConnectionError("Pas de réponse d'Elasticsearch")
        logger.info(f"Connecté à ES : {hosts}")
        return es
    except Exception as e:
        logger.critical(f"Impossible de se connecter à ES : {e}")
        sys.exit(1)

def bulk_send(es, index, records, logger):
    actions = [
        {
            "_index": index,
            "_source": {
                "@timestamp": datetime.utcnow().isoformat() + "Z",
                "message": msg.rstrip()
            }
        }
        for msg in records
    ]
    try:
        helpers.bulk(es, actions)
        logger.info(f"Ingesté {len(actions)} doc(s) vers '{index}'")
    except ElasticsearchException as e:
        logger.error(f"Erreur bulk ingest : {e}")

def main():
    cfg = load_config(CONFIG_FILE)
    logger = init_logger(cfg["log_file"])
    es = connect_es(cfg["es_hosts"], logger)

    buffer = []
    for line in sys.stdin:
        buffer.append(line)
        if len(buffer) >= cfg["batch_size"]:
            bulk_send(es, cfg["index"], buffer, logger)
            buffer.clear()
    if buffer:
        bulk_send(es, cfg["index"], buffer, logger)

    logger.info("Traitement terminé")

if __name__ == "__main__":
    main()
