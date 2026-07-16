# ============================================================================
# ps-script-machine - PowerShell Modul für VMware PowerCLI Automatisierung
# ============================================================================

# Setze Strict Mode für gesamte Modul-Sitzung
Set-StrictMode -Version Latest

# ============================================================================
# Private Funktionen laden
# ============================================================================
$privateFunctions = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)
foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
    }
    catch {
        Write-Error "Fehler beim Laden von $($function.FullName): $($_.Exception.Message)"
    }
}

# ============================================================================
# Public Funktionen laden
# ============================================================================
$publicFunctions = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
    }
    catch {
        Write-Error "Fehler beim Laden von $($function.FullName): $($_.Exception.Message)"
    }
}

# ============================================================================
# Exportierte Funktionen
# ============================================================================
$exports = @(
    'Get-VMHostNetworkInfo',
    'Connect-VIServerSession',
    'Disconnect-VIServerSession',
    'Write-ScriptLog',
    'Export-ReportCsv',
    'Export-ReportJson',
    'ConvertTo-CleanText'
)

Export-ModuleMember -Function $exports