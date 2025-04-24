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
# Script     : failed_login_counter.ps1
# Auteur     : Lysius
# Date       : 23/09/2023
# Description: Compte et rapporte les échecs de connexion dans un fichier de log.
#              • Configure les paramètres (chemin, motif, sortie).
#              • Journalise l’exécution et gère les erreurs d’I/O.
#              • Exporte le résultat en console et en fichier.
# =====================================================================================================================================================

param(
    [Parameter(Mandatory=$true, HelpMessage="Chemin vers le fichier de logs à analyser")]
    [string]$LogPath,

    [Parameter(HelpMessage="Motif regex pour identifier les échecs (ex: 'Failed login')")]
    [string]$Pattern = 'Failed login',

    [Parameter(HelpMessage="Chemin du fichier de rapport de sortie")]
    [string]$OutputPath = "$env:TEMP\failed_login_report.txt"
)

function Setup-Logger {
    param($LogFile)
    try {
        $dir = Split-Path $LogFile
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory | Out-Null }
        Start-Transcript -Path $LogFile -Append -NoClobber
    } catch {
        Write-Warning "Impossible de démarrer le transcript : $_"
    }
}

function Stop-Logger {
    try { Stop-Transcript } catch {}
}

function Count-FailedLogins {
    param($Path, $Regex)
    if (-not (Test-Path $Path)) {
        Write-Error "Le fichier spécifié n'existe pas : $Path"
        exit 1
    }
    try {
        $count = Get-Content $Path -ErrorAction Stop |
            Where-Object { $_ -match $Regex } |
            Measure-Object |
            Select-Object -Expand Count
        return $count
    } catch {
        Write-Error "Erreur lecture du fichier : $_"
        exit 1
    }
}

# --- Exécution principale ---
$logFile = "$env:TEMP\failed_login_counter.log"
Setup-Logger -LogFile $logFile

Write-Host "Analyse du fichier : $LogPath"
Write-Host "Motif utilisé     : $Pattern"

$failedCount = Count-FailedLogins -Path $LogPath -Regex $Pattern

$resultText = "Failed logins count: $failedCount"
Write-Host $resultText

try {
    $outDir = Split-Path $OutputPath
    if (-not (Test-Path $outDir)) { New-Item -Path $outDir -ItemType Directory | Out-Null }
    $resultText | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "Rapport écrit dans : $OutputPath"
} catch {
    Write-Warning "Impossible d'écrire le rapport : $_"
}

Stop-Logger
