#Requires -Version 7.4

<#
.SYNOPSIS
    Exportiert CDP-Informationen aller ESXi-Netzwerkinterfaces als CSV/JSON.

.DESCRIPTION
    Liest über die Modul-Funktion Get-CdpNetworkInfo die CDP-Daten
    (Cisco Discovery Protocol) aller physischen Netzwerkadapter aller
    ESXi-Hosts aus einem oder mehreren vCentern aus und exportiert sie
    als CSV und/oder JSON.

    Dieses Skript führt interaktiv durch alle Schritte:
    1. vCenter auswählen (gespeicherte Liste oder neue FQDNs)
    2. Anmeldung (einmal für alle vCenter, Nachfrage nur bei Fehlschlag)
    3. Toolspezifische Fragen
    4. Ausführung mit Fortschrittsanzeige
    5. Export und Zusammenfassung

    Für Automatisierung (Scheduled Tasks) können alle Eingaben als
    Parameter übergeben werden; mit -NonInteractive wird nie gefragt.

.PARAMETER VCenter
    Ein oder mehrere vCenter-FQDNs. Ohne Angabe erscheint das Auswahlmenü.

.PARAMETER Credential
    Zugangsdaten für alle vCenter. Ohne Angabe wird interaktiv gefragt.

.PARAMETER OutputPath
    Ausgabeordner für die Export-Dateien. Standard: Desktop.

.PARAMETER Format
    Ausgabeformat: CSV, JSON oder beide. Standard: CSV.

.PARAMETER NonInteractive
    Keine Rückfragen; erfordert -VCenter und -Credential.

.EXAMPLE
    .\Export-CdpInformation.ps1

    Startet das Skript im interaktiven Modus mit Menüführung.

.EXAMPLE
    .\Export-CdpInformation.ps1 -VCenter vc01.example.local, vc02.example.local -Credential $cred -NonInteractive

    Nicht-interaktiver Lauf für Automatisierung.

.NOTES
    Erstellt mit ps-script-machine (Skript-Werkstatt).
    Read-only: Dieses Skript verändert keine vSphere-Konfiguration.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]
    $VCenter,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.CredentialAttribute()]
    $Credential,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $OutputPath = [Environment]::GetFolderPath('Desktop'),

    [Parameter(Mandatory = $false)]
    [ValidateSet('CSV', 'JSON', 'beide')]
    [string]
    $Format = 'CSV',

    [Parameter(Mandatory = $false)]
    [switch]
    $NonInteractive
)

$ErrorActionPreference = 'Stop'

#region module-import
# Dieser Block wird beim Standalone-Build entfernt - im Standalone-Skript
# sind alle Modul-Funktionen direkt eingebettet.
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
Import-Module -Name (Resolve-Path -Path $modulePath).Path -Force -ErrorAction Stop
#endregion module-import

# ============================================================================
# PowerCLI-Verfügbarkeit prüfen (verständliche Anleitung statt kryptischem Fehler)
# ============================================================================
$powerCliAvailable = Get-Module -ListAvailable -Name 'VMware.VimAutomation.Core', 'VMware.PowerCLI' -ErrorAction SilentlyContinue
if (-not $powerCliAvailable) {
    Write-Host ''
    Write-Host 'VMware PowerCLI ist auf diesem Computer nicht installiert.' -ForegroundColor Red
    Write-Host 'Ohne PowerCLI kann keine Verbindung zu vCenter aufgebaut werden.'
    Write-Host ''
    Write-Host 'So installierst du PowerCLI (einmalig, ohne Adminrechte):' -ForegroundColor Cyan
    Write-Host '  Install-Module VMware.PowerCLI -Scope CurrentUser'
    Write-Host ''
    Write-Host 'Danach dieses Skript einfach erneut starten.'
    exit 1
}

# ============================================================================
# Begrüßung
# ============================================================================
Write-Host ''
Write-Host '=== Export-CdpInformation ===' -ForegroundColor Cyan
Write-Host 'Exportiert CDP-Informationen aller ESXi-Netzwerkinterfaces als CSV/JSON.'

# ============================================================================
# Protokoll je Lauf (Spec §6: kann bei Problemen dem Team geschickt werden)
# ============================================================================
$logDir = Join-Path -Path $OutputPath -ChildPath 'logs'
if (-not (Test-Path -LiteralPath $logDir)) {
    $null = New-Item -Path $logDir -ItemType Directory -Force
}
$logFile = Join-Path -Path $logDir -ChildPath ('Export-CdpInformation_{0:yyyy-MM-dd_HH-mm-ss}.log' -f (Get-Date))
Start-Transcript -Path $logFile | Out-Null
Write-Host ("Protokoll dieses Laufs: {0}" -f $logFile) -ForegroundColor DarkGray

# ============================================================================
# Schritt 1: vCenter bestimmen
# ============================================================================
if (-not $VCenter -or $VCenter.Count -eq 0) {
    if ($NonInteractive) {
        throw 'Im nicht-interaktiven Modus muss -VCenter angegeben werden.'
    }
    # Im Repo liegt die Liste unter config/vcenters.json, beim verteilten
    # Standalone-Skript im Benutzerprofil.
    $repoConfigDir = Join-Path -Path $PSScriptRoot -ChildPath '..\..\config'
    $inventoryPath = if (Test-Path -Path $repoConfigDir) {
        Join-Path -Path $repoConfigDir -ChildPath 'vcenters.json'
    }
    else {
        Join-Path -Path $HOME -ChildPath '.ps-script-machine\vcenters.json'
    }
    $VCenter = Select-VIServerTarget -InventoryPath $inventoryPath
}

# ============================================================================
# Schritt 2: Anmeldung (einmal für alle vCenter)
# ============================================================================
$connection = Connect-MultiVIServer -Server $VCenter -Credential $Credential -NonInteractive:$NonInteractive
if ($connection.Sessions.Count -eq 0) {
    Write-Host ''
    Write-Host 'Es konnte zu keinem vCenter eine Verbindung aufgebaut werden - Abbruch.' -ForegroundColor Red
    Write-Host 'Prüfe Servernamen und Zugangsdaten und starte das Skript erneut.'
    try {
        Stop-Transcript | Out-Null
    }
    catch {
        # Transcript war nicht (mehr) aktiv - unkritisch.
    }
    exit 1
}

# ============================================================================
# Schritt 3: Toolspezifische Fragen
# ============================================================================
#region tool-questions
if (-not $NonInteractive -and -not $PSBoundParameters.ContainsKey('Format')) {
    $formatAnswer = Read-Host 'Ausgabeformat (CSV/JSON/beide) [CSV]'
    if (-not [string]::IsNullOrWhiteSpace($formatAnswer) -and $formatAnswer.Trim() -in @('CSV', 'JSON', 'beide')) {
        $Format = $formatAnswer.Trim()
    }
}
#endregion tool-questions

# ============================================================================
# Schritt 4 + 5: Ausführung, Export, Zusammenfassung
# ============================================================================
$allResults = [System.Collections.Generic.List[object]]::new()
try {
    $total = $connection.Sessions.Count
    $current = 0
    foreach ($session in $connection.Sessions) {
        $current++
        Write-Progress -Activity 'Export-CdpInformation' `
            -Status ("vCenter {0} ({1} von {2})" -f $session.Name, $current, $total) `
            -PercentComplete (($current / $total) * 100)

        $results = Get-CdpNetworkInfo -VIServer $session

        if ($results) {
            $allResults.AddRange(@($results))
        }
    }
    Write-Progress -Activity 'Export-CdpInformation' -Completed

    if ($allResults.Count -eq 0) {
        Write-Host ''
        Write-Host 'Es wurden keine Daten gefunden.' -ForegroundColor Yellow
        Write-Host 'Mögliche Ursache: keine passenden Objekte in den gewählten vCentern.'
    }
    else {
        if (-not (Test-Path -LiteralPath $OutputPath)) {
            $null = New-Item -Path $OutputPath -ItemType Directory -Force
        }
        $formats = if ($Format -eq 'beide') { @('CSV', 'JSON') } else { @($Format) }
        $baseName = 'Export-CdpInformation_{0:yyyy-MM-dd_HH-mm-ss}' -f (Get-Date)
        $exportBase = Join-Path -Path $OutputPath -ChildPath $baseName
        $files = Export-ModuleData -Data $allResults.ToArray() -OutputPath $exportBase -Format $formats -Force
    }

    Write-Host ''
    Write-Host 'Fertig!' -ForegroundColor Green
    $totalRequested = $connection.Connected.Count + $connection.Skipped.Count
    Write-Host ("  Abgefragte vCenter : {0} von {1}" -f $connection.Connected.Count, $totalRequested)
    if ($connection.Skipped.Count -gt 0) {
        Write-Host ("  Übersprungen       : {0}" -f ($connection.Skipped -join ', ')) -ForegroundColor Yellow
    }
    Write-Host ("  Ergebnisse         : {0}" -f $allResults.Count)
    if ($allResults.Count -gt 0) {
        foreach ($file in @($files)) {
            Write-Host ("  Datei              : {0}" -f $file)
        }
    }
}
finally {
    foreach ($session in $connection.Sessions) {
        try {
            Disconnect-VIServer -Server $session -Confirm:$false -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning ("Die Verbindung zu '{0}' konnte nicht sauber getrennt werden." -f $session.Name)
        }
    }
    try {
        Stop-Transcript | Out-Null
    }
    catch {
        # Transcript war nicht (mehr) aktiv - unkritisch.
    }
}
