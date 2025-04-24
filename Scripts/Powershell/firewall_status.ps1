#!/usr/bin/env pwsh
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
# Script     : firewall_status.ps1
# Auteur     : Lysius
# Date       : 29/09/2023
# Description: Vérifie l’état des profils du pare-feu Windows et écrit un journal d’état horodaté.
#              • Paramètre : chemin du fichier log
#              • Journalisation via Transcript
#              • Gère la création de répertoire et les erreurs d’écriture.
# =====================================================================================================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "$PSScriptRoot\Logs\firewall_status.log"
)

function Setup-Logger {
    param([string]$Path)
    try {
        $dir = Split-Path $Path -Parent
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory | Out-Null }
        if (Get-Command Start-Transcript -ErrorAction SilentlyContinue) {
            Start-Transcript -Path $Path -Append -NoClobber
        }
    } catch {
        Write-Warning "Impossible de démarrer le transcript : $_"
    }
}

function Stop-Logger {
    if (Get-Command Stop-Transcript -ErrorAction SilentlyContinue) {
        Stop-Transcript
    }
}

function Get-FirewallStatus {
    param([string]$OutputFile)
    try {
        $profiles = Get-NetFirewallProfile
        foreach ($p in $profiles) {
            $line = "{0} - Profil: {1}, État: {2}" -f (Get-Date -Format o), $p.Name, ($p.Enabled ? 'Activé' : 'Désactivé')
            Add-Content -Path $OutputFile -Value $line
        }
        Write-Host "Statut pare-feu écrit dans : $OutputFile"
    } catch {
        Write-Error "Erreur lors de la récupération du statut pare-feu : $_"
        exit 1
    }
}

# --- Exécution principale ---
Setup-Logger -Path $LogPath
Get-FirewallStatus -OutputFile $LogPath
Stop-Logger
