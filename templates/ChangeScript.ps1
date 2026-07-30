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
    Exit codes: 0 = success/handled partial success, 1 = fatal error.
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
    $NewValue
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$minimumPowerCLIVersion = [version]'13.2.0'
$runId = [guid]::NewGuid().ToString()
$startedAt = Get-Date
$exitCode = 0
$runStatus = 'Running'
$errorMessage = $null
$connection = $null
$result = @()

try {
    $powerCliModule = Get-Module -ListAvailable -Name 'VMware.PowerCLI', 'VMware.VimAutomation.Core' -ErrorAction SilentlyContinue |
        Where-Object { $_.Version -ge $minimumPowerCLIVersion } |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if (-not $powerCliModule) {
        throw "VMware PowerCLI $minimumPowerCLIVersion or newer is required."
    }

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name (Resolve-Path -LiteralPath $modulePath).Path -Force -ErrorAction Stop

    Write-Verbose "Connecting to $Server..."
    $connection = Connect-MultiVIServer -Server @($Server) -Credential $Credential -NonInteractive -ErrorAction Stop
    if (@($connection.Sessions).Count -eq 0) {
        throw "Failed to connect to $Server."
    }
    if ($connection.RunId) {
        $runId = [string]$connection.RunId
    }

    $operationParameters = @{
        VIServer   = $connection.Sessions[0]
        Name       = $TargetName
        Value      = $NewValue
        ErrorAction = 'Stop'
    }
    if ($PSBoundParameters.ContainsKey('WhatIf')) {
        $operationParameters['WhatIf'] = $WhatIfPreference
    }
    if ($PSBoundParameters.ContainsKey('Confirm')) {
        $operationParameters['Confirm'] = [bool]$PSBoundParameters['Confirm']
    }

    Write-Verbose "Modifying $TargetName on $Server..."
    $result = @(Set-Something @operationParameters)
    $result
    $runStatus = if (@($connection.Skipped).Count -gt 0) { 'PartialSuccess' } else { 'Success' }
}
catch {
    $exitCode = 1
    $runStatus = 'Failed'
    $errorMessage = $_.Exception.Message
    Write-Error -Message "Script failed: $errorMessage" -ErrorAction Continue
}
finally {
    if ($connection) {
        foreach ($session in @($connection.Sessions)) {
            Disconnect-VIServer -Server $session -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

    $completedAt = Get-Date
    $runSummary = [ordered]@{
        PSTypeName      = 'ps-script-machine.ToolRunSummary'
        ToolName        = $MyInvocation.MyCommand.Name
        RunId           = $runId
        StartedAtUtc    = $startedAt.ToUniversalTime().ToString('o')
        CompletedAtUtc  = $completedAt.ToUniversalTime().ToString('o')
        DurationSeconds = [math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
        Status          = $runStatus
        ExitCode        = $exitCode
        ResultCount     = $result.Count
        ErrorMessage    = $errorMessage
    }
    Write-Information -MessageData ($runSummary | ConvertTo-Json -Compress -Depth 5) -InformationAction Continue
}

exit $exitCode
