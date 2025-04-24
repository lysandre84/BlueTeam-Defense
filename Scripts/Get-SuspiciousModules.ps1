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
# Script     : Get-SuspiciousModules.ps1
# Auteur     : Lysius
# Date       : 12/10/2023
# Description: Inspecte les modules chargés par chaque processus et signale ceux qui ne figurent 
#              pas dans la liste blanche (configurable). Journalise les résultats et gère 
#              les erreurs d’accès aux processus.
# =====================================================================================================================================================

param(
    [Parameter(Mandatory=$false, HelpMessage="Chemin vers le fichier JSON de liste blanche")]
    [string]$WhitelistPath = "$PSScriptRoot\trusted_modules.json",

    [Parameter(Mandatory=$false, HelpMessage="Chemin du fichier de log")]
    [string]$LogPath = "$PSScriptRoot\Logs\suspicious_modules.log"
)

function Setup-Logger {
    param([string]$Path)
    try {
        $dir = Split-Path $Path -Parent
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory | Out-Null }
        Start-Transcript -Path $Path -Append -NoClobber | Out-Null
    } catch {
        Write-Warning "Impossible de démarrer le transcript : $_"
    }
}

function Stop-Logger {
    try { Stop-Transcript } catch {}
}

function Load-Whitelist {
    param([string]$Path)
    if (Test-Path $Path) {
        try {
            $data = Get-Content $Path -Raw | ConvertFrom-Json
            return @($data | ForEach-Object { $_.ToLower() })
        } catch {
            Write-Warning "Échec lecture JSON de la whitelist : $_"
        }
    }
    # Valeur par défaut si pas de fichier
    return @("kernel32.dll","user32.dll","advapi32.dll")
}

function Get-SuspiciousModules {
    param(
        [string[]]$Whitelist
    )
    try {
        $processes = Get-Process
    } catch {
        Write-Error "Impossible de lister les processus : $_"
        return
    }
    foreach ($proc in $processes) {
        try {
            $modules = (Get-Process -Id $proc.Id -ErrorAction Stop).Modules
            foreach ($mod in $modules) {
                $name = $mod.ModuleName.ToLower()
                if ($Whitelist -notcontains $name) {
                    $msg = "Processus suspect: $($proc.ProcessName) charge module inconnu: $($mod.ModuleName)"
                    Write-Output $msg
                    Write-Verbose $msg
                }
            }
        } catch {
            Write-Warning "Accès refusé ou erreur sur processus $($proc.Id): $_"
        }
    }
}

# --- Exécution principale ---
Setup-Logger -Path $LogPath

$whitelist = Load-Whitelist -Path $WhitelistPath
Write-Host "Whitelist chargée ($($whitelist.Count) modules)."

Get-SuspiciousModules -Whitelist $whitelist

Stop-Logger
