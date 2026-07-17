#Requires -Version 7.4

<#
.SYNOPSIS
    Wrapper script for a modifying PowerCLI operation.

.DESCRIPTION
    This script demonstrates a wrapper that connects to vCenter, performs a
    modifying operation with full safety checks (WhatIf, Confirm, prechecks,
    postchecks), and disconnects cleanly.

    The modifying function must support SupportsShouldProcess and ConfirmImpact='High'.
    It must perform prechecks, validate the target, and provide postchecks.

.PARAMETER Server
    The vCenter Server or ESXi host FQDN.

.PARAMETER Credential
    PSCredential object for authentication.

.PARAMETER TargetName
    The name of the target object to modify.

.PARAMETER NewValue
    The new value to set.

.PARAMETER WhatIf
    If specified, shows what would happen without making changes.

.PARAMETER Confirm
    If specified, prompts for confirmation before executing.

.EXAMPLE
    $cred = Get-Credential
    .\Set-Something.ps1 -Server 'vcenter.example.com' -Credential $cred -TargetName 'obj01' -NewValue 'new'

    Connects to vCenter and modifies the specified object.

.EXAMPLE
    $cred = Get-Credential
    .\Set-Something.ps1 -Server 'vcenter.example.com' -Credential $cred -TargetName 'obj01' -NewValue 'new' -WhatIf

    Shows what would happen without making changes.

.NOTES
    This script performs modifying operations. Always use -WhatIf first to
    verify the intended changes before executing.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $TargetName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $NewValue,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $LogFile
)

$ErrorActionPreference = 'Stop'

try {
    # Import the module
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    # Connect to vCenter
    Write-Verbose "Connecting to $Server..."
    $session = Connect-VIServerSession -Server $Server -Credential $Credential -ErrorAction Stop

    if (-not $session) {
        throw "Failed to connect to $Server"
    }

    # Perform the modifying operation
    # The function must support SupportsShouldProcess and ConfirmImpact='High'
    Write-Verbose "Modifying $TargetName on $Server..."
    $result = Set-Something -VIServer $session -Name $TargetName -Value $NewValue -ErrorAction Stop

    # Output result
    if ($result) {
        $result | Format-Table -AutoSize
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