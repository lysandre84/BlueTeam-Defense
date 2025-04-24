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
# Script     : Watch-EventLogThreats.ps1
# Auteur     : Lysius
# Date       : 05/02/2024
# Description: Surveille les événements de sécurité Windows (ID 4625 & 4688) via WMI et envoie 
#              des alertes détaillées sur Slack. Journalise les actions et gère les erreurs.
# =====================================================================================================================================================

param(
    [Parameter(Mandatory=$true, HelpMessage="URL du webhook Slack")]
    [string]$WebhookUrl,

    [Parameter(Mandatory=$false, HelpMessage="Chemin du fichier de log")]
    [string]$LogPath = "$PSScriptRoot\Logs\event_watch.log",

    [Parameter(Mandatory=$false, HelpMessage="Intervalle de vérification en secondes")]
    [int]$IntervalSec = 60
)

function Setup-Logger {
    param([string]$Path)
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory | Out-Null
    }
    Start-Transcript -Path $Path -Append -NoClobber | Out-Null
}

function Stop-Logger {
    Stop-Transcript | Out-Null
}

function Send-SlackAlert {
    param([string]$Message)
    try {
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body (@{ text = $Message } | ConvertTo-Json)
        Write-Verbose "Alert sent to Slack: $Message"
    } catch {
        Write-Warning "Échec envoi Slack: $_"
    }
}

function Register-SecurityEvents {
    $query = "Select * From __InstanceCreationEvent Within 5 Where TargetInstance ISA 'Win32_NTLogEvent' AND TargetInstance.EventCode IN ('4625','4688')"
    Register-WmiEvent -Query $query -Action {
        $e = $Event.SourceEventArgs.NewEvent.TargetInstance
        $user = $e.InsertionStrings[5]
        $path = $e.InsertionStrings[8]
        $msg  = "EventID: $($e.EventCode) | Utilisateur: $user | Processus: $path"
        Send-SlackAlert -Message $msg
        Write-Host "[Alert] $msg"
    } | Out-Null
}

# --- Exécution principale ---
Setup-Logger -Path $LogPath
Write-Host "Démarrage surveillance événements de sécurité..."
Send-SlackAlert -Message "🔔 Watch-EventLogThreats démarré"

Register-SecurityEvents

# Boucle de maintien en vie
while ($true) {
    Start-Sleep -Seconds $IntervalSec
}

Stop-Logger
