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
# =====================================================================================================================================================
# Script     : Invoke-HashComparison.ps1
# Auteur     : Lysius
# Date       : 10/11/2023
# Description: Compare les hachages SHA256 des fichiers d'un répertoire à une baseline JSON, 
#              journalise les différences dans un rapport horodaté.
# =====================================================================================================================================================

param(
    [Parameter(Mandatory, HelpMessage="Chemin vers le fichier JSON de baseline")]
    [string]$BaselineFile = "C:\baseline\hashes.json",

    [Parameter(Mandatory, HelpMessage="Répertoire à scanner")]
    [string]$ScanDir = "C:\Windows\System32",

    [Parameter(HelpMessage="Chemin du rapport de comparaison")]
    [string]$ReportPath = "C:\baseline\compare_{0}.txt"
)

function Setup-Logger {
    param([string]$LogFile)
    try {
        $dir = Split-Path $LogFile -Parent
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory | Out-Null }
        Start-Transcript -Path $LogFile -Append -NoClobber | Out-Null
    } catch {
        Write-Warning "Impossible de démarrer le transcript : $_"
    }
}

function Stop-Logger {
    try { Stop-Transcript } catch {}
}

function Load-Baseline {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Error "Baseline introuvable : $Path"
        exit 1
    }
    try {
        return Get-Content $Path -Raw | ConvertFrom-Json
    } catch {
        Write-Error "Erreur lecture JSON baseline : $_"
        exit 1
    }
}

function Scan-Directory {
    param([string]$Dir)
    $hashTable = @{}
    if (-not (Test-Path $Dir)) {
        Write-Error "Répertoire introuvable : $Dir"
        exit 1
    }
    Get-ChildItem -Path $Dir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $hash = Get-FileHash $_.FullName -Algorithm SHA256
            $hashTable[$_.FullName] = $hash.Hash
        } catch {
            Write-Warning "Impossible de hasher $_.FullName : $_"
        }
    }
    return $hashTable
}

function Compare-Hashes {
    param($Baseline, $Current, $OutPath)
    $time = Get-Date -Format "yyyyMMdd_HHmmss"
    $outFile = $OutPath -f $time
    Compare-Object -ReferenceObject $Baseline.Values `
                   -DifferenceObject $Current.Values `
                   -PassThru | Out-File $outFile
    Write-Host "Rapport généré : $outFile"
}

# — Exécution principale —
$logFile    = "C:\baseline\hash_compare.log"
Setup-Logger -LogFile $logFile

Write-Host "Chargement baseline depuis $BaselineFile"
$baseline   = Load-Baseline -Path $BaselineFile

Write-Host "Scan du répertoire $ScanDir"
$current    = Scan-Directory -Dir $ScanDir

Write-Host "Comparaison des hachages et génération de rapport"
Compare-Hashes -Baseline $baseline -Current $current -OutPath $ReportPath

Stop-Logger
