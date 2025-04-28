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
// Script     : threat_intel_blocker.go
// Auteur     : Lysius
// Date       : 04/12/2024
// Description: Récupère un feed JSON d’IP malveillantes et les bloque via iptables.
//              • Lit l’URL du feed et les paramètres depuis un fichier JSON ou flags.
//              • Journalise chaque action dans un log dédié.
//              • Programme infini avec intervalle configurable.
// =====================================================================================================================================================

package main

import (
    "encoding/json"
    "flag"
    "fmt"
    "io/ioutil"
    "log"
    "net/http"
    "os"
    "os/exec"
    "path/filepath"
    "time"
)

// Config contient les paramètres pour le bloqueur
type Config struct {
    FeedURL      string        `json:"feed_url"`
    Interval     time.Duration `json:"interval_sec"`
    IPTablesPath string        `json:"iptables_path"`
    Chain        string        `json:"chain"`
    LogFile      string        `json:"log_file"`
}

// DefaultConfig fournit des valeurs de secours
var DefaultConfig = Config{
    FeedURL:      "https://example.com/badips.json",
    Interval:     3600 * time.Second,
    IPTablesPath: "/sbin/iptables",
    Chain:        "THREAT_BLOCK",
    LogFile:      "/var/log/threat_intel_blocker.log",
}

// loadConfig lit un fichier de configuration JSON ou renvoie les valeurs par défaut
func loadConfig(path string) Config {
    cfg := DefaultConfig
    data, err := ioutil.ReadFile(path)
    if err != nil {
        return cfg
    }
    var userCfg Config
    if err := json.Unmarshal(data, &userCfg); err != nil {
        log.Printf("Warning: impossible de parser config %s: %v", path, err)
        return cfg
    }
    // Fusionner les paramètres par défaut et utilisateur
    if userCfg.FeedURL != "" {
        cfg.FeedURL = userCfg.FeedURL
    }
    if userCfg.Interval != 0 {
        cfg.Interval = userCfg.Interval
    }
    if userCfg.IPTablesPath != "" {
        cfg.IPTablesPath = userCfg.IPTablesPath
    }
    if userCfg.Chain != "" {
        cfg.Chain = userCfg.Chain
    }
    if userCfg.LogFile != "" {
        cfg.LogFile = userCfg.LogFile
    }
    return cfg
}

// setupLogger configure l’enregistrement dans un fichier
func setupLogger(logFile string) {
    dir := filepath.Dir(logFile)
    if err := os.MkdirAll(dir, 0755); err != nil {
        log.Fatalf("Échec création dossier log: %v", err)
    }
    f, err := os.OpenFile(logFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
    if err != nil {
        log.Fatalf("Impossible d'ouvrir le fichier de log: %v", err)
    }
    log.SetOutput(f)
    log.SetFlags(log.LstdFlags)
    log.Println("=== threat_intel_blocker démarré ===")
}

// fetchFeed récupère la liste des mauvais IP de l’URL configurée
func fetchFeed(url string) ([]string, error) {
    resp, err := http.Get(url)
    if err != nil {
        return nil, fmt.Errorf("erreur HTTP: %w", err)
    }
    defer resp.Body.Close()
    body, err := ioutil.ReadAll(resp.Body)
    if err != nil {
        return nil, fmt.Errorf("erreur lecture réponse: %w", err)
    }
    var ips []string
    if err := json.Unmarshal(body, &ips); err != nil {
        return nil, fmt.Errorf("erreur JSON: %w", err)
    }
    return ips, nil
}

// ensureChain crée la chaîne iptables si elle n’existe pas
func ensureChain(ipt, chain string) {
    exec.Command(ipt, "-N", chain).Run() // ignorer l’erreur si elle existe
    exec.Command(ipt, "-C", "INPUT", "-j", chain).Run() // check
    exec.Command(ipt, "-I", "INPUT", "1", "-j", chain).Run()
    log.Printf("Chaîne iptables prête: %s", chain)
}

// blockIPs ajoute des règles DROP pour chaque IP non déjà bloquée
func blockIPs(ipt, chain string, ips []string) {
    for _, ip := range ips {
        cmdCheck := exec.Command(ipt, "-C", "INPUT", "-s", ip, "-j", "DROP")
        if err := cmdCheck.Run(); err != nil {
            cmd := exec.Command(ipt, "-I", "INPUT", "-s", ip, "-j", "DROP")
            if err := cmd.Run(); err != nil {
                log.Printf("Erreur blocage %s: %v", ip, err)
            } else {
                log.Printf("Bloqué %s", ip)
            }
        }
    }
}

func main() {
    cfgPath := flag.String("config", "/etc/threat_intel_blocker/config.json", "Chemin vers le config JSON")
    flag.Parse()

    cfg := loadConfig(*cfgPath)
    setupLogger(cfg.LogFile
