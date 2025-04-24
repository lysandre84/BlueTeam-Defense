// =====================================================================================================================================================
//   
//  /$$$$$$$  /$$                  /$$$$$$$$                                        /$$$$$$$             /$$$$$$                                       
// | $$__  $$| $$                 |__  $$__/                                       | $$__  $$           /$$__  $$                                       
// | $$  \ $$| $$ /$$   /$$  /$$$$$$ | $$  /$$$$$$   /$$$$$$  /$$$$$$/$$$$         | $$  \ $$  /$$$$$$ | $$  \__//$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$ 
// | $$$$$$$ | $$| $$  | $$ /$$__  $$| $$ /$$__  $$ |____  $$| $$_  $$_  $$ /$$$$$$| $$  | $$ /$$__  $$| $$$$   /$$__  $$| $$__  $$ /$$_____/ /$$__  $$ 
// | $$__  $$| $$| $$  | $$| $$$$$$$$| $$| $$$$$$$$  /$$$$$$$| $$ \ $$ \ $$|______/| $$  | $$| $$$$$$$$| $$_/  | $$$$$$$$| $$  \ $$|  $$$$$$ | $$$$$$$$ 
// | $$  \ $$| $$| $$  | $$| $$_____/| $$| $$_____/ /$$__  $$| $$ | $$ | $$        | $$  | $$| $$_____/| $$    | $$_____/| $$  | $$ \____  $$| $$_____/ 
// | $$$$$$$/| $$|  $$$$$$/|  $$$$$$$| $$|  $$$$$$$|  $$$$$$$| $$ | $$ | $$        | $$$$$$$/|  $$$$$$$| $$    |  $$$$$$$| $$  | $$ /$$$$$$$/|  $$$$$$$ 
// |_______/ |__/ \______/  \_______/|__/ \_______/ \_______/|__/ |__/ |__/        |_______/  \_______/|__/     \_______/|__/  |__/|_______/  \_______/  
//   
// =====================================================================================================================================================
// =====================================================================================================================================================
// Script     : prometheus_exporter.go
// Auteur     : Lysius
// Date       : 30/10/2022
// Description: Expose des métriques SSH failed attempts pour Prometheus.
//              • Charge les paramètres (log path, listen address, interval) depuis JSON ou flags.
//              • Analyse périodiquement le log pour compter les échecs par IP.
//              • Serve les métriques à /metrics via HTTP.
// =====================================================================================================================================================

package main

import (
    "bufio"
    "encoding/json"
    "flag"
    "io/ioutil"
    "log"
    "net/http"
    "os"
    "regexp"
    "time"

    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

type Config struct {
    LogPath        string        `json:"log_path"`
    ListenAddress  string        `json:"listen_address"`
    ScrapeInterval time.Duration `json:"scrape_interval"`
    LogFile        string        `json:"log_file"`
}

var DefaultConfig = Config{
    LogPath:        "/var/log/auth.log",
    ListenAddress:  ":9100",
    ScrapeInterval: 30 * time.Second,
    LogFile:        "/var/log/prometheus_exporter.log",
}

func loadConfig(path string) Config {
    cfg := DefaultConfig
    if path != "" {
        if data, err := ioutil.ReadFile(path); err == nil {
            var fileCfg Config
            if err := json.Unmarshal(data, &fileCfg); err != nil {
                log.Printf("Warning: impossible de parser le JSON %s: %v", path, err)
            } else {
                if fileCfg.LogPath != "" {
                    cfg.LogPath = fileCfg.LogPath
                }
                if fileCfg.ListenAddress != "" {
                    cfg.ListenAddress = fileCfg.ListenAddress
                }
                if fileCfg.ScrapeInterval != 0 {
                    cfg.ScrapeInterval = fileCfg.ScrapeInterval
                }
                if fileCfg.LogFile != "" {
                    cfg.LogFile = fileCfg.LogFile
                }
            }
        }
    }
    return cfg
}

func setupLogger(path string) {
    f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
    if err != nil {
        log.Fatalf("Erreur création du fichier de log: %v", err)
    }
    log.SetOutput(f)
    log.SetFlags(log.LstdFlags)
    log.Println("Prometheus exporter démarré")
}

var sshFailCounter = prometheus.NewGaugeVec(
    prometheus.GaugeOpts{
        Name: "ssh_failed_attempts",
        Help: "Nombre d'échecs SSH par IP",
    },
    []string{"ip"},
)

func init() {
    prometheus.MustRegister(sshFailCounter)
}

func parseLog(path string) {
    file, err := os.Open(path)
    if err != nil {
        log.Printf("Erreur ouverture log: %v", err)
        return
    }
    defer file.Close()

    scanner := bufio.NewScanner(file)
    re := regexp.MustCompile(`Failed password.* from (\d+\.\d+\.\d+\.\d+)`)
    counts := make(map[string]int)

    for scanner.Scan() {
        if matches := re.FindStringSubmatch(scanner.Text()); matches != nil {
            counts[matches[1]]++
        }
    }

    for ip, cnt := range counts {
        sshFailCounter.WithLabelValues(ip).Set(float64(cnt))
    }
}

func main() {
    cfgPath := flag.String("config", "", "Chemin vers le fichier JSON de configuration")
    flag.Parse()

    cfg := loadConfig(*cfgPath)
    setupLogger(cfg.LogFile)
    log.Printf("Lecture du log: %s, écoute HTTP: %s, intervalle: %v",
        cfg.LogPath, cfg.ListenAddress, cfg.ScrapeInterval)

    go func() {
        ticker := time.NewTicker(cfg.ScrapeInterval)
        defer ticker.Stop()
        for {
            parseLog(cfg.LogPath)
            <-ticker.C
        }
    }()

    http.Handle("/metrics", promhttp.Handler())
    log.Printf("Serveur HTTP en écoute sur %s", cfg.ListenAddress)
    if err := http.ListenAndServe(cfg.ListenAddress, nil); err != nil {
        log.Fatalf("Erreur serveur HTTP: %v", err)
    }
}
