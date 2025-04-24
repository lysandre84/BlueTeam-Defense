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
# Script     : Start-DefenseMetrics.ps1
# Auteur     : Lysius
# Date       : 20/12/2023
# Description: Recueille périodiquement les métriques système (CPU, mémoire dispo, connexions TCP)
#              et les enregistre dans un CSV horodaté pour analyse historique.
# =====================================================================================================================================================

param(
    [Parameter(Mandatory=$false, HelpMessage="Chemin du fichier CSV de sortie")]
    [string]$LogFile     = "C:\Logs\defense_metrics.csv",

    [Parameter(Mandatory=$false, HelpMessage="Intervalle en secondes entre deux relevés")]
    [int]   $IntervalSec = 60
)

function Initialize-Log {
    param([string]$Path)
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory | Out-Null
    }
    if (-not (Test-Path $Path)) {
        "Timestamp,CPU_pct,Memory_MB,Active_TCP_Connections" | Out-File $Path -Encoding UTF8
    }
}

function Get-SystemMetrics {
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $mem = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue
    $conn = (Get-NetTCPConnection -ErrorAction SilentlyContinue | Measure-Object).Count
    return @{
        Timestamp    = (Get-Date).ToString("o")
        CPU_pct      = [math]::Round($cpu,2)
        Memory_MB    = [math]::Round($mem,2)
        Connections  = $conn
    }
}

function Write-Metrics {
    param($Metrics, [string]$Path)
    $line = "{0},{1},{2},{3}" -f $Metrics.Timestamp, $Metrics.CPU_pct, $Metrics.Memory_MB, $Metrics.Connections
    $line | Out-File -FilePath $Path -Append -Encoding UTF8
}

# --- Programme principal ---
Initialize-Log -Path $LogFile
Write-Host "Démarrage collecte métriques. Intervalle : $IntervalSec sec. Fichier : $LogFile"

while ($true) {
    try {
        $metrics = Get-SystemMetrics
        Write-Metrics -Metrics $metrics -Path $LogFile
    } catch {
        Write-Warning "Erreur collecte métriques : $_"
    }
    Start-Sleep -Seconds $IntervalSec
}
