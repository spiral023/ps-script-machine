# ============================================================================
# Modul-Manifest für ps-script-machine
# ============================================================================

@{
    RootModule        = 'ps-script-machine.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'VMware Admin Team'
    CompanyName       = 'Internal'
    Copyright         = '(c) 2026 VMware Admin Team. Alle Rechte vorbehalten.'
    Description       = 'PowerShell-Modul für VMware PowerCLI Automatisierung - hochwertige, getestete Funktionen für vSphere-Administration.'

    # PowerShell-Version
    PowerShellVersion = '7.0'

    # Abhängige Module
    RequiredModules   = @(
        @{ ModuleName = 'VMware.VimAutomation.Core'; ModuleVersion = '12.0.0' }
    )

    # Exportierte Funktionen
    FunctionsToExport = @(
        'Get-VMHostNetworkInfo',
        'Connect-VIServerSession',
        'Disconnect-VIServerSession',
        'Write-ScriptLog',
        'Export-ReportCsv',
        'Export-ReportJson',
        'ConvertTo-CleanText'
    )

    # Exportierte Cmdlets (keine)
    CmdletsToExport   = @()

    # Exportierte Variablen (keine)
    VariablesToExport = @()

    # Exportierte Aliase (keine)
    AliasesToExport   = @()

    # Private Daten
    PrivateData       = @{
        PSData = @{
            Tags       = @('VMware', 'PowerCLI', 'vSphere', 'ESXi', 'vCenter', 'CDP')
            ProjectUri = ''
            LicenseUri = ''
            ReleaseNotes = 'Initial release mit Get-VMHostNetworkInfo, Connection-Management, Logging und Export-Funktionen.'
        }
    }
}