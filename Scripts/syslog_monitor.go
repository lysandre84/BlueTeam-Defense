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
// Script     : syslog_monitor.go
// Auteur     : Lysius
// Date       : 19/06/2023
// Description: Surveillance en temps réel du syslog, filtrage des erreurs/échecs et envoi d'alertes Slack.
//              • Charge la config (chemin log, webhook, mots-clés) depuis JSON.
//              • Suit le fichier en mode « tail -f » et traite les nouvelles lignes.
//              • Envoie chaque alerte vers Slack et journalise localement.
// =====================================================================================================================================================

package main

import (
    "bufio"
    "encoding/json"
    "flag"
    "fmt"
    "io"
    "log"
    "net/http"
    "os"
    "path/filepath"
    "strings"
    "time"
)

// Config holds monitoring settings
type Config struct {
    SyslogPath string   `json:"syslog_path"`
    WebhookURL string   `json:"webhook_url"`
    Keywords   []string `json:"keywords"`
    LogFile    string   `json:"log_file"`
}

// loadConfig reads configuration from JSON or returns defaults
func loadConfig(path string) Config {
    defaultCfg := Config{
        SyslogPath: "/var/log/syslog",
        WebhookURL: "",
        Keywords:   []string{"error", "fail"},
        LogFile:    "/var/log/syslog_monitor.log",
    }
    data, err := os.ReadFile(path)
    if err != nil {
        return defaultCfg
    }
    var cfg Config
    if err := json.Unmarshal(data, &cfg); err != nil {
        log.Printf("Warning: impossible de parser config %s: %v", path, err)
        return defaultCfg
    }
    if cfg.SyslogPath == "" {
        cfg.SyslogPath = defaultCfg.SyslogPath
    }
    if cfg.LogFile == "" {
        cfg.LogFile = defaultCfg.LogFile
    }
    if len(cfg.Keywords) == 0 {
        cfg.Keywords = defaultCfg.Keywords
    }
    return cfg
}

// setupLogger configures file logging
func setupLogger(logFile string) {
    dir := filepath.Dir(logFile)
    if err := os.MkdirAll(dir, 0755); err != nil {
        log.Fatalf("Échec création répertoire de log: %v", err)
    }
    f, err := os.OpenFile(logFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
    if err != nil {
        log.Fatalf("Échec ouverture fichier de log: %v", err)
    }
    log.SetOutput(f)
    log.SetFlags(log.LstdFlags)
}

// tailFile follows new lines appended to a file
func tailFile(path string) (<-chan string, error) {
    file, err := os.Open(path)
    if err != nil {
        return nil, err
    }
    _, err = file.Seek(0, io.SeekEnd)
    if err != nil {
        return nil, err
    }
    lines := make(chan string)
    go func() {
        reader := bufio.NewReader(file)
        for {
            line, err := reader.ReadString('\n')
            if err != nil {
                if err == io.EOF {
                    time.Sleep(500 * time.Millisecond)
                    continue
                }
                log.Printf("Erreur lecture syslog: %v", err)
                break
            }
            lines <- strings.TrimRight(line, "\n")
        }
        close(lines)
    }()
    return lines, nil
}

// sendSlackAlert posts a message to Slack webhook
func sendSlackAlert(webhook, msg string) {
    payload := fmt.Sprintf(`{"text":"%s"}`, msg)
    resp, err := http.Post(webhook, "application/json", strings.NewReader(payload))
    if err != nil {
        log.Printf("Erreur envoi Slack: %v", err)
        return
    }
    resp.Body.Close()
}

// containsKeyword checks if line contains any keyword
func containsKeyword(line string, keywords []string) bool {
    lower := strings.ToLower(line)
    for _, kw := range keywords {
        if strings.Contains(lower, strings.ToLower(kw)) {
            return true
        }
    }
    return false
}

func main() {
    cfgPath := flag.String("config", "/etc/syslog_monitor/config.json", "Chemin vers le fichier JSON de configuration")
    flag.Parse()

    cfg := loadConfig(*cfgPath)
    setupLogger(cfg.LogFile)
    log.Printf("Démarrage surveillance syslog: %s", cfg.SyslogPath)

    if cfg.WebhookURL == "" {
        log.Fatal("Webhook Slack non configuré")
    }

    lines, err := tailFile(cfg.SyslogPath)
    if err != nil {
        log.Fatalf("Impossible d'ouvrir le syslog: %v", err)
    }

    for line := range lines {
        if containsKeyword(line, cfg.Keywords) {
            log.Printf("Alerte détectée: %s", line)
            sendSlackAlert(cfg.WebhookURL, line)
        }
    }
}
