#Requires -Version 7.4

<#
.SYNOPSIS
    Example script showing how to use ps-script-machine module.

.DESCRIPTION
    This example demonstrates:
    - Importing the module
    - Connecting to vCenter using PSCredential
    - Retrieving CDP network information
    - Exporting data to CSV and JSON
    - Proper cleanup (disconnect)

.NOTES
    This is an example script. Adjust the server name and credentials as needed.
    Never hardcode credentials - use Get-Credential or SecretManagement.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]
    $VCenterServer,

    [Parameter(Mandatory = $false)]
    [string]
    $ExportPath
)

$ErrorActionPreference = 'Stop'

try {
    # Import the module
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    # Get credentials - never hardcode!
    $cred = Get-Credential -Message "Enter credentials for $VCenterServer"

    # Connect to vCenter
    Write-Host "Connecting to $VCenterServer..." -ForegroundColor Cyan
    $connection = Connect-MultiVIServer -Server $VCenterServer -Credential $cred -NonInteractive

    if ($connection.Sessions.Count -eq 0) {
        throw "Failed to connect to $VCenterServer"
    }
    $session = $connection.Sessions[0]
    Write-Host "Connected successfully." -ForegroundColor Green

    # Retrieve CDP network information
    Write-Host "Retrieving CDP network information..." -ForegroundColor Cyan
    $cdpInfo = Get-CdpNetworkInfo -VIServer $session -ErrorAction Stop

    if ($cdpInfo) {
        # Display summary
        Write-Host "`nFound $($cdpInfo.Count) CDP entries:" -ForegroundColor Green
        $cdpInfo | Format-Table VIServer, VMHost, AdapterName, CDPDevice, CDPPort -AutoSize

        # Export if path provided
        if ($ExportPath) {
            Write-Host "Exporting to $ExportPath..." -ForegroundColor Cyan
            $exportedFiles = Export-ModuleData -Data $cdpInfo -OutputPath $ExportPath -Format CSV, JSON -Force -ErrorAction Stop
            Write-Host "Exported to:" -ForegroundColor Green
            foreach ($file in $exportedFiles) {
                Write-Host "  $file" -ForegroundColor White
            }
        }
    }
    else {
        Write-Warning "No CDP information found."
    }
}
catch {
    Write-Error "Script failed: $_"
    exit 1
}
finally {
    # Always disconnect
    if ($connection -and $connection.Sessions.Count -gt 0) {
        try {
            Disconnect-VIServer -Server $connection.Sessions -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "Disconnected from $VCenterServer" -ForegroundColor Cyan
        }
        catch {
            Write-Warning "Failed to disconnect: $_"
        }
    }
}