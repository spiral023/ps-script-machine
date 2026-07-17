#Requires -Version 7.4

<#
.SYNOPSIS
    Wrapper script for Get-CdpNetworkInfo (legacy compatibility).

.DESCRIPTION
    This is a legacy wrapper script that imports the ps-script-machine module
    and calls the Get-CdpNetworkInfo function.

    For new usage, prefer importing the module directly:
    Import-Module .\src\ps-script-machine\ps-script-machine.psd1
    Get-CdpNetworkInfo -VIServer $session

.PARAMETER Server
    The vCenter Server or ESXi host FQDN.

.PARAMETER Credential
    PSCredential object for authentication.

.PARAMETER VMHost
    Optional: One or more host names to filter.

.EXAMPLE
    $cred = Get-Credential
    .\Get-CdpNetworkInfo.ps1 -Server 'vcenter.example.com' -Credential $cred

.NOTES
    This is a legacy wrapper. New scripts should import the module directly.
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
    [string[]]
    $VMHost
)

$ErrorActionPreference = 'Stop'

try {
    # Import the module
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    # Connect to vCenter
    $session = Connect-VIServerSession -Server $Server -Credential $Credential -ErrorAction Stop

    if (-not $session) {
        throw "Failed to connect to $Server"
    }

    # Retrieve CDP network information
    $params = @{
        VIServer = $session
    }
    if ($VMHost) {
        $params['VMHost'] = $VMHost
    }

    $data = Get-CdpNetworkInfo @params -ErrorAction Stop

    if ($data) {
        $data | Format-Table -AutoSize
    }
    else {
        Write-Warning "No CDP data found."
    }
}
catch {
    Write-Error "Script failed: $_"
    exit 1
}
finally {
    if ($session) {
        Disconnect-VIServer -Server $session -Confirm:$false -ErrorAction SilentlyContinue
    }
}