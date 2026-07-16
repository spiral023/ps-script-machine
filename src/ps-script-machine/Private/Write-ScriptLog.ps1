<#
.SYNOPSIS
    Einheitliche Logging-Funktion für alle Skripte.

.DESCRIPTION
    Schreibt strukturierte Log-Einträge mit Zeitstempel, Level und Nachricht.
    Unterstützt Console, File und beides gleichzeitig.

.PARAMETER Message
    Die zu protokollierende Nachricht.

.PARAMETER Level
    Schweregrad: INFO, WARNING, ERROR, DEBUG.

.PARAMETER LogPath
    Optionaler Pfad zur Log-Datei. Wenn nicht angegeben, wird nur auf der Console ausgegeben.

.PARAMETER ConsoleOnly
    Wenn gesetzt, wird nur auf der Console ausgegeben (kein File-Write).

.EXAMPLE
    Write-ScriptLog -Message "Verbinde mit vCenter..." -Level INFO

.EXAMPLE
    Write-ScriptLog -Message "Host nicht erreichbar" -Level WARNING -LogPath C:\Logs\script.log
#>
function Write-ScriptLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',

        [Parameter()]
        [string]$LogPath,

        [Parameter()]
        [switch]$ConsoleOnly
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    # Console-Ausgabe mit Farbe
    switch ($Level) {
        'ERROR' { Write-Host $logLine -ForegroundColor Red }
        'WARNING' { Write-Host $logLine -ForegroundColor Yellow }
        'INFO' { Write-Host $logLine -ForegroundColor Cyan }
        'DEBUG' { Write-Host $logLine -ForegroundColor Gray }
    }

    # File-Ausgabe
    if (-not $ConsoleOnly -and -not [string]::IsNullOrWhiteSpace($LogPath)) {
        try {
            $logDir = Split-Path -Path $LogPath -Parent
            if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
                $null = New-Item -ItemType Directory -Path $logDir -Force
            }
            Add-Content -LiteralPath $LogPath -Value $logLine -ErrorAction SilentlyContinue
        }
        catch {
            # Logging-Fehler sollen nie das Skript abbrechen
            Write-Debug "Konnte nicht in Log-Datei schreiben: $($_.Exception.Message)"
        }
    }
}