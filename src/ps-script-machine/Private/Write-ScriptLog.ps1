#Requires -Version 7.4

<#
.SYNOPSIS
    Einheitliche Logging-Funktion für alle Skripte.

.DESCRIPTION
    Schreibt strukturierte Log-Einträge mit Zeitstempel, Level und Nachricht.
    Unterstützt Console, File und beides gleichzeitig.

    Verwendet Write-Information für die Konsolenausgabe anstelle von Write-Host,
    um den PowerShell-Stream-Standard zu erfüllen.

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

.OUTPUTS
    None. This function writes to the information stream and optionally to a log file.

.NOTES
    This is a private function. It uses Write-Information for console output
    to comply with PowerShell stream standards (no Write-Host).
#>
function Write-ScriptLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',

        [Parameter()]
        [string]$LogPath,

        [Parameter()]
        [switch]$ConsoleOnly
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logLine = "[$timestamp] [$Level] $Message"

    # Console output using Write-Information (not Write-Host)
    # to comply with PowerShell stream standards
    switch ($Level) {
        'ERROR' {
            Write-Information -MessageData $logLine -Tags 'Error' -InformationAction Continue
        }
        'WARNING' {
            Write-Information -MessageData $logLine -Tags 'Warning' -InformationAction Continue
        }
        'INFO' {
            Write-Information -MessageData $logLine -Tags 'Info' -InformationAction Continue
        }
        'DEBUG' {
            Write-Information -MessageData $logLine -Tags 'Debug' -InformationAction Continue
        }
    }

    # File output
    if (-not $ConsoleOnly -and -not [string]::IsNullOrWhiteSpace($LogPath)) {
        try {
            $logDir = Split-Path -Path $LogPath -Parent
            if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
                $null = New-Item -ItemType Directory -Path $logDir -Force
            }
            # Use UTF-8 encoding without BOM for log files
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::AppendAllText($LogPath, "$logLine`n", $utf8NoBom)
        }
        catch {
            # Logging errors should never stop the script
            Write-Debug "Konnte nicht in Log-Datei schreiben: $($_.Exception.Message)"
        }
    }
}