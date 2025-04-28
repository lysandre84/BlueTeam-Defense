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
// Script     : port_scanner.go
// Auteur     : Lysius
// Date       : 23/04/2024
// Description: Scanne des ports TCP sur un hôte donné et affiche leur état.
//              • Flags pour hôte, liste de ports et timeout.
//              • Exécution parallèle via goroutines et WaitGroup.
//              • Gestion d’erreurs et affichage clair.
// =====================================================================================================================================================

package main

import (
    "flag"
    "fmt"
    "net"
    "strings"
    "sync"
    "time"
)

// result retient le résultat de l’analyse pour un port
type result struct {
    port   string
    open   bool
    err    error
}

// scanPort tente d’ouvrir une connexion TCP avec un délai d’attente
func scanPort(host, port string, timeout time.Duration, wg *sync.WaitGroup, ch chan<- result) {
    defer wg.Done()
    addr := net.JoinHostPort(host, port)
    conn, err := net.DialTimeout("tcp", addr, timeout)
    if err != nil {
        ch <- result{port: port, open: false, err: nil}
        return
    }
    conn.Close()
    ch <- result{port: port, open: true, err: nil}
}

func main() {
    // Flags
    hostFlag   := flag.String("host", "127.0.0.1", "Hôte à scanner")
    portsFlag  := flag.String("ports", "22,80", "Liste de ports séparés par des virgules")
    timeoutFlag:= flag.Duration("timeout", 1*time.Second, "Timeout pour chaque test de port")
    flag.Parse()

    host := *hostFlag
    ports := strings.Split(*portsFlag, ",")
    timeout := *timeoutFlag

    fmt.Printf("Scanning host %s on ports: %s (timeout %s)\n", host, *portsFlag, timeout)

    var wg sync.WaitGroup
    results := make(chan result, len(ports))

    // Lancer les analyses en parallèle
    for _, port := range ports {
        wg.Add(1)
        go scanPort(host, strings.TrimSpace(port), timeout, &wg, results)
    }

    // Fermer le canal de résultats une fois terminé
    go func() {
        wg.Wait()
        close(results)
    }()

    // Recueillir et imprimer les résultats
    for res := range results {
        state := "closed"
        if res.open {
            state = "open"
        }
        fmt.Printf("Port %s: %s\n", res.port, state)
    }
}
