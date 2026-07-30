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
    Exit codes: 0 = success/handled partial success, 1 = fatal error.
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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$minimumPowerCLIVersion = [version]'13.2.0'
$runId = [guid]::NewGuid().ToString()
$startedAt = Get-Date
$exitCode = 0
$runStatus = 'Running'
$errorMessage = $null
$connection = $null
$data = @()
$exportedFiles = @()

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

    Write-Verbose 'Retrieving data...'
    $data = @(Get-CdpNetworkInfo -VIServer $connection.Sessions[0] -ErrorAction Stop)
    if ($data.Count -eq 0) {
        Write-Warning 'No data retrieved.'
    }
    elseif ($OutputPath) {
        $exportedFiles = @(
            Export-ModuleData -Data $data -OutputPath $OutputPath -Format CSV, JSON -Force -ErrorAction Stop
        )
    }

    $data
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
        ResultCount     = $data.Count
        OutputFiles     = @($exportedFiles)
        ErrorMessage    = $errorMessage
    }

    if ($LogFile) {
        $logDirectory = Split-Path -Path $LogFile -Parent
        if ($logDirectory -and -not (Test-Path -LiteralPath $logDirectory)) {
            $null = New-Item -Path $logDirectory -ItemType Directory -Force
        }
        $runSummary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $LogFile -Encoding utf8
    }
    Write-Information -MessageData ($runSummary | ConvertTo-Json -Compress -Depth 5) -InformationAction Continue
}

exit $exitCode
