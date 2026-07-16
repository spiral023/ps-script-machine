<#
.SYNOPSIS
    Wrapper-Skript: Exportiert CDP-Informationen aller ESXi-Hosts als CSV/JSON.

.DESCRIPTION
    Dieses Skript ist ein dünner Wrapper um die Modul-Funktion Get-VMHostNetworkInfo.
    Es fragt interaktiv vCenter, Benutzername und Passwort ab und exportiert
    die Ergebnisse als CSV (Windows-1252) und optional JSON.

    Für Automatisierung kann stattdessen die Funktion direkt verwendet werden:
    Get-VMHostNetworkInfo -Server $vCenter -Credential $cred

.PARAMETER VCenter
    FQDN oder IP-Adresse des vCenter-Servers. Wenn nicht angegeben, interaktiv abgefragt.

.PARAMETER OutputPath
    Ausgabeordner. Standard: Desktop.

.PARAMETER Format
    Ausgabeformat: CSV, JSON oder beide. Standard: CSV.

.EXAMPLE
    .\scripts\Export-CdpInformation.ps1
    Startet das Skript im interaktiven Modus.

.EXAMPLE
    .\scripts\Export-CdpInformation.ps1 -VCenter vcenter.local -Format beide
    Exportiert als CSV und JSON.

.NOTES
    Author: VMware Admin Team
    Requirements: ps-script-machine Modul, VMware PowerCLI 12+
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$VCenter,

    [Parameter()]
    [string]$OutputPath = [Environment]::GetFolderPath("Desktop"),

    [Parameter()]
    [ValidateSet('CSV', 'JSON', 'beide')]
    [string]$Format = 'CSV'
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Modul laden
# ============================================================================
$modulePath = Join-Path $PSScriptRoot "..\src\ps-script-machine\ps-script-machine.psd1"
$modulePath = (Resolve-Path -Path $modulePath).Path

try {
    Import-Module $modulePath -ErrorAction Stop
}
catch {
    Write-Error "Modul konnte nicht geladen werden: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# Interaktive Eingaben (nur wenn Parameter nicht gesetzt)
# ============================================================================
if ([string]::IsNullOrWhiteSpace($VCenter)) {
    $VCenter = Read-Host "vCenter-Server eingeben"
    if ([string]::IsNullOrWhiteSpace($VCenter)) {
        Write-Error "Es wurde kein vCenter-Server angegeben."
        exit 1
    }
}

$username = Read-Host "Benutzername eingeben, z. B. user@vsphere.local"
if ([string]::IsNullOrWhiteSpace($username)) {
    Write-Error "Es wurde kein Benutzername angegeben."
    exit 1
}

$credential = Get-Credential `
    -UserName $username `
    -Message "Passwort für $username am vCenter $VCenter eingeben"

# Ausgabeordner validieren
if (-not (Test-Path -LiteralPath $OutputPath)) {
    $null = New-Item -Path $OutputPath -ItemType Directory -Force
}
$OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$vCenterShort = ($VCenter -split "\.")[0]

# ============================================================================
# Modul-Funktion aufrufen
# ============================================================================
try {
    $results = Get-VMHostNetworkInfo `
        -Server $VCenter `
        -Credential $credential

    # ============================================================================
    # Export
    # ============================================================================
    if ($Format -eq 'CSV' -or $Format -eq 'beide') {
        $csvPath = Join-Path $OutputPath "${vCenterShort}_ESXi_CDP_Information_$timestamp.csv"
        $results | Export-ReportCsv -Path $csvPath
        Write-ScriptLog -Message "CSV exportiert: $csvPath" -Level INFO
    }

    if ($Format -eq 'JSON' -or $Format -eq 'beide') {
        $jsonPath = Join-Path $OutputPath "${vCenterShort}_ESXi_CDP_Information_$timestamp.json"
        $results | Export-ReportJson -Path $jsonPath
        Write-ScriptLog -Message "JSON exportiert: $jsonPath" -Level INFO
    }

    # ============================================================================
    # Vorschau
    # ============================================================================
    Write-Host ""
    Write-Host "Vorschau:" -ForegroundColor Cyan
    $results |
        Select-Object VMHost, PhysicalAdapter, LinkStatus, CDPDeviceID, CDPPortID, CDPManagementIP, QueryStatus |
        Format-Table -AutoSize
}
catch {
    Write-Error "Skript fehlgeschlagen: $($_.Exception.Message)"
    exit 1
}