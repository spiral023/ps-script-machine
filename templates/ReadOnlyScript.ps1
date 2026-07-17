#Requires -Version 7.4

<#
.SYNOPSIS
    Wrapper script for read-only PowerCLI operations.

.DESCRIPTION
    This script demonstrates a read-only wrapper that connects to vCenter,
    retrieves data, optionally exports it, and disconnects cleanly.
    It does not modify any vSphere configuration.

    Usage:
    .\Get-Something.ps1 -Server 'vcenter.example.com' -Credential $cred

    Credentials should be obtained via Get-Credential or SecretManagement.
    Never hardcode credentials in scripts.

.PARAMETER Server
    The vCenter Server or ESXi host FQDN.

.PARAMETER Credential
    PSCredential object for authentication.

.PARAMETER OutputPath
    Optional: If specified, exports results to CSV and JSON at this path.

.PARAMETER LogFile
    Optional: If specified, logs are written to this file.

.EXAMPLE
    $cred = Get-Credential
    .\Get-Something.ps1 -Server 'vcenter.example.com' -Credential $cred

    Connects to vCenter, retrieves data, and outputs to console.

.EXAMPLE
    $cred = Get-Credential
    .\Get-Something.ps1 -Server 'vcenter.example.com' -Credential $cred -OutputPath 'C:\Exports\data'

    Connects to vCenter, retrieves data, and exports to CSV and JSON.

.NOTES
    This is a read-only script. It does not modify any vSphere configuration.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Server,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.CredentialAttribute()]
    $Credential,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $OutputPath,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $LogFile
)

$ErrorActionPreference = 'Stop'

try {
    # Import the module (adjust path as needed)
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    # Connect to vCenter
    Write-Verbose "Connecting to $Server..."
    $session = Connect-VIServerSession -Server $Server -Credential $Credential -ErrorAction Stop

    if (-not $session) {
        throw "Failed to connect to $Server"
    }

    # Retrieve data
    Write-Verbose "Retrieving data..."
    $data = Get-CdpNetworkInfo -VIServer $session -ErrorAction Stop

    # Output results
    if ($data) {
        $data | Format-Table -AutoSize

        # Export if requested
        if ($OutputPath) {
            $exportedFiles = Export-ModuleData -Data $data -OutputPath $OutputPath -Format CSV, JSON -Force -ErrorAction Stop
            Write-Verbose "Exported to: $($exportedFiles -join ', ')"
        }
    }
    else {
        Write-Warning "No data retrieved."
    }
}
catch {
    Write-Error "Script failed: $_"
    exit 1
}
finally {
    # Clean up: disconnect from vCenter
    if ($session) {
        try {
            Disconnect-VIServer -Server $session -Confirm:$false -ErrorAction SilentlyContinue
            Write-Verbose "Disconnected from $Server"
        }
        catch {
            Write-Warning "Failed to disconnect from $Server`: $_"
        }
    }
}