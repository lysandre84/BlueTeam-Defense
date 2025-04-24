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
// Script     : fs_monitor.go
// Auteur     : Lysius
// Date       : 15/02/2024
// Description: Moniteur de système de fichiers utilisant fsnotify.
//              • Lit le chemin à surveiller depuis les flags ou un fichier JSON.
//              • Journalise les événements de création, modification, suppression.
//              • Gère les erreurs et le redémarrage du watcher.
// =====================================================================================================================================================

package main

import (
    "encoding/json"
    "flag"
    "fmt"
    "github.com/fsnotify/fsnotify"
    "io/ioutil"
    "log"
    "os"
    "path/filepath"
    "time"
)

// Config holds monitoring configuration
type Config struct {
    Path    string `json:"path"`
    LogFile string `json:"log_file"`
}

// loadConfig loads configuration from file or uses defaults
func loadConfig(configPath string) Config {
    defaultCfg := Config{
        Path:    "/etc",
        LogFile: "/var/log/fs_monitor.log",
    }
    data, err := ioutil.ReadFile(configPath)
    if err != nil {
        return defaultCfg
    }
    var cfg Config
    if err := json.Unmarshal(data, &cfg); err != nil {
        log.Printf("Warning: failed to parse config %s: %v", configPath, err)
        return defaultCfg
    }
    if cfg.Path == "" {
        cfg.Path = defaultCfg.Path
    }
    if cfg.LogFile == "" {
        cfg.LogFile = defaultCfg.LogFile
    }
    return cfg
}

func setupLogger(logFile string) {
    dir := filepath.Dir(logFile)
    if err := os.MkdirAll(dir, 0755); err != nil {
        log.Fatalf("Failed to create log dir %s: %v", dir, err)
    }
    f, err := os.OpenFile(logFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
    if err != nil {
        log.Fatalf("Failed to open log file %s: %v", logFile, err)
    }
    log.SetOutput(f)
    log.SetFlags(log.LstdFlags)
    log.Println("fs_monitor started")
}

func watchPath(path string) {
    watcher, err := fsnotify.NewWatcher()
    if err != nil {
        log.Fatalf("Error creating watcher: %v", err)
    }
    defer watcher.Close()

    // recursive watch setup
    filepath.Walk(path, func(p string, info os.FileInfo, err error) error {
        if err == nil && info.IsDir() {
            watcher.Add(p)
        }
        return nil
    })

    done := make(chan bool)
    go func() {
        for {
            select {
            case event := <-watcher.Events:
                log.Printf("Event: %s %s", event.Op, event.Name)
            case err := <-watcher.Errors:
                log.Printf("Error: %v", err)
                // attempt to restart watcher after a pause
                time.Sleep(5 * time.Second)
                watcher.Add(path)
            }
        }
    }()
    <-done
}

func main() {
    // Flags
    cfgPath := flag.String("config", "", "Chemin du fichier JSON de configuration")
    flagPath := flag.String("path", "", "Chemin à surveiller (override config)")
    flag.Parse()

    // Load config
    cfg := loadConfig(*cfgPath)
    if *flagPath != "" {
        cfg.Path = *flagPath
    }

    // Setup logging
    setupLogger(cfg.LogFile)
    log.Printf("Monitoring path: %s", cfg.Path)

    // Start watcher
    watchPath(cfg.Path)
}
