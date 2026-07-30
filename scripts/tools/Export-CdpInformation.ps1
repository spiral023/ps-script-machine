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

.PARAMETER EnableTranscript
    Erstellt zusätzlich zur strukturierten Laufzusammenfassung einen
    vollständigen Konsolenmitschnitt. Dieser kann sensible Betriebsdaten
    enthalten und muss vor einer Weitergabe geprüft werden.

.PARAMETER LogRetentionDays
    Entfernt ältere Logdateien dieses Tools aus dessen eigenem
    Logverzeichnis. 0 deaktiviert die Bereinigung. Standard: 30 Tage.

.EXAMPLE
    .\Export-CdpInformation.ps1

    Startet das Skript im interaktiven Modus mit Menüführung.

.EXAMPLE
    .\Export-CdpInformation.ps1 -VCenter vc01.example.local, vc02.example.local -Credential $cred -NonInteractive

    Nicht-interaktiver Lauf für Automatisierung.

.NOTES
    Erstellt mit ps-script-machine (Skript-Werkstatt).
    Read-only: Dieses Skript verändert keine vSphere-Konfiguration.
    Exitcodes: 0 = Erfolg/behandelter Teilerfolg, 1 = fataler Fehler.
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
    $NonInteractive,

    [Parameter(Mandatory = $false)]
    [switch]
    $EnableTranscript,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 3650)]
    [int]
    $LogRetentionDays = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-RedactedLogText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]
        $Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }

    $redactedValue = $Value
    $redactedValue = $redactedValue -replace '(?i)(password|passwd|pwd|secret|token|api[_-]?key)\s*=\s*[^\s;]+', '$1=***REDACTED***'
    $redactedValue = $redactedValue -replace '(?i)bearer\s+[A-Za-z0-9._-]+', 'Bearer ***REDACTED***'
    return $redactedValue
}

$minimumPowerCLIVersion = [version]'13.2.0'
$toolName = 'Export-CdpInformation'
$toolVersion = 'development'
$runId = [guid]::NewGuid().ToString()
$startedAt = Get-Date
$exitCode = 0
$runStatus = 'Running'
$fatalErrorMessage = $null
$connection = $null
$transcriptStarted = $false
$transcriptPath = $null
$summaryPath = $null
$requestedCount = 0
$connectedCount = 0
$skippedCount = 0
$files = @()
$allResults = [System.Collections.Generic.List[object]]::new()

try {
    $logDir = Join-Path -Path $OutputPath -ChildPath 'logs'
    if (-not (Test-Path -LiteralPath $logDir)) {
        $null = New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop
    }

    if ($LogRetentionDays -gt 0) {
        $retentionCutoff = (Get-Date).AddDays(-$LogRetentionDays)
        $expiredLogFiles = @(
            Get-ChildItem -LiteralPath $logDir -File -Filter "$toolName`_*" -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $retentionCutoff }
        )
        foreach ($expiredLogFile in $expiredLogFiles) {
            Remove-Item -LiteralPath $expiredLogFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    $runStamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss-fff'
    $summaryPath = Join-Path -Path $logDir -ChildPath ("{0}_{1}.run.json" -f $toolName, $runStamp)
    if ($EnableTranscript) {
        $transcriptPath = Join-Path -Path $logDir -ChildPath ("{0}_{1}.transcript.log" -f $toolName, $runStamp)
        Start-Transcript -Path $transcriptPath -ErrorAction Stop | Out-Null
        $transcriptStarted = $true
    }

    Write-Host ''
    Write-Host "=== $toolName ===" -ForegroundColor Cyan
    Write-Host 'Exportiert CDP-Informationen aller ESXi-Netzwerkinterfaces als CSV/JSON.'
    Write-Host ("Run-ID: {0}" -f $runId) -ForegroundColor DarkGray
    if ($transcriptStarted) {
        Write-Host ("Transcript (vor Weitergabe prüfen): {0}" -f $transcriptPath) -ForegroundColor DarkGray
    }

    $powerCliModules = @(
        Get-Module -ListAvailable -Name 'VMware.PowerCLI', 'VMware.VimAutomation.Core' -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending
    )
    $powerCliModule = $powerCliModules |
        Where-Object { $_.Version -ge $minimumPowerCLIVersion } |
        Select-Object -First 1

    if (-not $powerCliModule) {
        $foundVersions = if ($powerCliModules.Count -gt 0) {
            ($powerCliModules.Version | Sort-Object -Unique) -join ', '
        }
        else {
            'keine'
        }
        throw "VMware PowerCLI $minimumPowerCLIVersion oder neuer wird benötigt. Gefunden: $foundVersions. Installation/Aktualisierung: Install-Module VMware.PowerCLI -Scope CurrentUser"
    }

    #region module-import
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name (Resolve-Path -LiteralPath $modulePath).Path -Force -ErrorAction Stop
    #endregion module-import

    $moduleVersionVariable = Get-Variable -Name ModuleVersion -Scope Script -ErrorAction SilentlyContinue
    if ($moduleVersionVariable) {
        $toolVersion = [string]$moduleVersionVariable.Value
    }
    else {
        $loadedModule = Get-Module -Name 'ps-script-machine' -ErrorAction SilentlyContinue
        if ($loadedModule) {
            $toolVersion = [string]$loadedModule.Version
        }
    }

    if (-not $VCenter -or $VCenter.Count -eq 0) {
        if ($NonInteractive) {
            throw 'Im nicht-interaktiven Modus muss -VCenter angegeben werden.'
        }
        $repoConfigDir = Join-Path -Path $PSScriptRoot -ChildPath '..\..\config'
        $inventoryPath = if (Test-Path -LiteralPath $repoConfigDir) {
            Join-Path -Path $repoConfigDir -ChildPath 'vcenters.json'
        }
        else {
            $userProfile = [Environment]::GetFolderPath('UserProfile')
            Join-Path -Path $userProfile -ChildPath '.ps-script-machine\vcenters.json'
        }
        $VCenter = Select-VIServerTarget -InventoryPath $inventoryPath
    }
    $requestedCount = @($VCenter).Count

    $connection = Connect-MultiVIServer -Server $VCenter -Credential $Credential -NonInteractive:$NonInteractive
    $connectedCount = @($connection.Connected).Count
    $skippedCount = @($connection.Skipped).Count
    if ($connection.RunId) {
        $runId = [string]$connection.RunId
    }
    if (@($connection.Sessions).Count -eq 0) {
        throw 'Es konnte zu keinem vCenter eine Verbindung aufgebaut werden. Servernamen, Netzwerk und Zugangsdaten prüfen.'
    }

    #region tool-questions
    if (-not $NonInteractive -and -not $PSBoundParameters.ContainsKey('Format')) {
        $formatAnswer = Read-Host 'Ausgabeformat (CSV/JSON/beide) [CSV]'
        if (-not [string]::IsNullOrWhiteSpace($formatAnswer) -and $formatAnswer.Trim() -in @('CSV', 'JSON', 'beide')) {
            $Format = $formatAnswer.Trim()
        }
    }
    #endregion tool-questions

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

    $runStatus = if ($skippedCount -gt 0) { 'PartialSuccess' } else { 'Success' }
}
catch {
    $exitCode = 1
    $runStatus = 'Failed'
    $fatalErrorMessage = ConvertTo-RedactedLogText -Value $_.Exception.Message
    Write-Error -Message ("{0} fehlgeschlagen: {1}" -f $toolName, $fatalErrorMessage) -ErrorAction Continue
}
finally {
    Write-Progress -Activity $toolName -Completed -ErrorAction SilentlyContinue

    if ($connection) {
        foreach ($session in @($connection.Sessions)) {
            try {
                Disconnect-VIServer -Server $session -Confirm:$false -ErrorAction SilentlyContinue
            }
            catch {
                Write-Warning ("Die Verbindung zu '{0}' konnte nicht sauber getrennt werden." -f $session.Name)
            }
        }
    }

    $completedAt = Get-Date
    $durationSeconds = [math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
    $runSummary = [ordered]@{
        PSTypeName       = 'ps-script-machine.ToolRunSummary'
        ToolName         = $toolName
        ToolVersion      = $toolVersion
        RunId            = $runId
        StartedAtUtc     = $startedAt.ToUniversalTime().ToString('o')
        CompletedAtUtc   = $completedAt.ToUniversalTime().ToString('o')
        DurationSeconds  = $durationSeconds
        Status           = $runStatus
        ExitCode         = $exitCode
        RequestedTargets = $requestedCount
        ConnectedTargets = $connectedCount
        SkippedTargets   = $skippedCount
        ResultCount      = $allResults.Count
        OutputFiles      = @($files)
        ErrorMessage     = $fatalErrorMessage
        TranscriptPath   = $transcriptPath
    }

    if ($summaryPath) {
        try {
            $runSummary |
                ConvertTo-Json -Depth 5 |
                Set-Content -LiteralPath $summaryPath -Encoding utf8 -ErrorAction Stop
        }
        catch {
            Write-Warning ("Laufzusammenfassung konnte nicht geschrieben werden: {0}" -f $_.Exception.Message)
        }
    }

    Write-Host ''
    Write-Host ("Laufstatus          : {0}" -f $runStatus)
    Write-Host ("Exitcode            : {0}" -f $exitCode)
    Write-Host ("Dauer               : {0:N3} Sekunden" -f $durationSeconds)
    if ($summaryPath) {
        Write-Host ("Laufzusammenfassung : {0}" -f $summaryPath)
    }

    if ($transcriptStarted) {
        try {
            Stop-Transcript -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Warning ("Transcript konnte nicht sauber beendet werden: {0}" -f $_.Exception.Message)
        }
    }
}

exit $exitCode
