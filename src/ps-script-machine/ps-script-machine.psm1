#Requires -Version 7.4

<#
.SYNOPSIS
    Root module for ps-script-machine.

.DESCRIPTION
    This module provides reusable PowerShell/PowerCLI functions for VMware vSphere
    administrators. It serves as a development platform and template for coding agents
    that create high-quality PowerShell and PowerCLI scripts.

    The module dynamically loads all public functions from the Public folder and all
    private helper functions from the Private folder at import time.

    Only public functions are exported via Export-ModuleMember.  Private functions
    are dot-sourced into the module scope so that they are available to public
    functions, but they are NOT exported.  Unit tests access private functions
    through InModuleScope, not through the module's public surface.

    Duplicate function names are detected and cause an import error to prevent
    silent shadowing of functions.

.NOTES
    PowerCLI is an external dependency.  The module can be imported and unit-tested
    (with mocked PowerCLI cmdlets) without PowerCLI being installed.  PowerCLI is
    only required for actual vSphere operations.
#>

# Module scope variables
$script:ModuleRoot = $PSScriptRoot
$script:ModuleVersion = (Import-PowerShellDataFile -Path "$PSScriptRoot\ps-script-machine.psd1").ModuleVersion
$script:LogRunId = [guid]::NewGuid().ToString()
$script:ModuleSessions = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

# Define stub functions for PowerCLI cmdlets when PowerCLI is not installed.
# This allows the module to be imported and unit-tested (with mocks) even
# without PowerCLI being present.  The stubs are defined in the module scope
# so that Pester can mock them with -ModuleName 'ps-script-machine'.
# Stub functions for PowerCLI cmdlets are defined with matching parameter names
# (but no validation constraints) so that Pester mocks can intercept calls
# and ParameterFilter can access parameter values.
# When PowerCLI is installed, these stubs are not created.
# Note: We check for the PowerCLI module specifically, not just whether a
# command name exists, because some names (e.g. Get-VMHost) collide with
# Hyper-V cmdlets on Windows.
$powerCLILoaded = $null -ne (Get-Module -Name 'VMware.VimAutomation.ViCore' -ErrorAction SilentlyContinue) -or
    $null -ne (Get-Module -Name 'VMware.VimAutomation.Core' -ErrorAction SilentlyContinue)

if (-not $powerCLILoaded) {
    Write-Verbose 'PowerCLI not detected. Defining stub functions for unit testing.'
    function Connect-VIServer {
        [CmdletBinding()]
        param(
            [Parameter()] $Server,
            [Parameter()] $Credential,
            [Parameter()] $Port,
            [Parameter()] $Protocol
        )
    }
    function Disconnect-VIServer {
        [CmdletBinding()]
        param(
            [Parameter()] $Server,
            [Parameter()] $Confirm
        )
    }
    function Get-VMHost {
        [CmdletBinding()]
        param(
            [Parameter()] $Server,
            [Parameter()] $Name,
            [Parameter()] $Location
        )
    }
    function Get-EsxCli {
        [CmdletBinding()]
        param(
            [Parameter()] $Server,
            [Parameter()] $VMHost
        )
    }
    function Get-Cluster {
        [CmdletBinding()]
        param(
            [Parameter()] $Name,
            [Parameter()] $Server
        )
    }
    function Get-VMHostNetworkAdapter {
        [CmdletBinding()]
        param(
            [Parameter()] $VMHost,
            [switch] $Physical
        )
    }
    function Get-View {
        [CmdletBinding()]
        param(
            [Parameter()] $Id
        )
    }
}

# Track which VIServer sessions were opened by this module instance so that
# Disconnect-VIServerSession only disconnects sessions the module created.
# External sessions (opened by the caller) are never disconnected by the module.

#region Private function loading

$privatePath = Join-Path $PSScriptRoot 'Private'
$privateFunctions = @()
if (Test-Path -Path $privatePath) {
    $privateFunctions = Get-ChildItem -Path "$privatePath\*.ps1" -ErrorAction SilentlyContinue
}

$loadedFunctionNames = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($function in $privateFunctions) {
    try {
        # Detect duplicate function definitions before dot-sourcing
        $fileContent = Get-Content -Path $function.FullName -Raw -ErrorAction Stop
        $funcNameMatch = [regex]::Match(
            $fileContent,
            '(?m)^\s*function\s+([A-Za-z][A-Za-z0-9_-]*)\s*\{'
        )
        if ($funcNameMatch.Success) {
            $funcName = $funcNameMatch.Groups[1].Value
            if ($loadedFunctionNames.Contains($funcName)) {
                throw "Duplicate function name '$funcName' detected in $($function.FullName). Function names must be unique."
            }
            $null = $loadedFunctionNames.Add($funcName)
        }
        . $function.FullName
        Write-Verbose "Loaded private function: $($function.BaseName)"
    }
    catch {
        Write-Error "Failed to load private function $($function.FullName): $_"
    }
}

#endregion

#region Public function loading

$publicPath = Join-Path $PSScriptRoot 'Public'
$publicFunctions = @()
if (Test-Path -Path $publicPath) {
    $publicFunctions = Get-ChildItem -Path "$publicPath\*.ps1" -ErrorAction SilentlyContinue
}

$exportedFunctions = @()

foreach ($function in $publicFunctions) {
    try {
        # Detect duplicate function definitions before dot-sourcing
        $fileContent = Get-Content -Path $function.FullName -Raw -ErrorAction Stop
        $funcNameMatch = [regex]::Match(
            $fileContent,
            '(?m)^\s*function\s+([A-Za-z][A-Za-z0-9_-]*)\s*\{'
        )
        if ($funcNameMatch.Success) {
            $funcName = $funcNameMatch.Groups[1].Value
            if ($loadedFunctionNames.Contains($funcName)) {
                throw "Duplicate function name '$funcName' detected in $($function.FullName). Function names must be unique."
            }
            $null = $loadedFunctionNames.Add($funcName)
        }
        . $function.FullName
        $exportedFunctions += $function.BaseName
        Write-Verbose "Loaded public function: $($function.BaseName)"
    }
    catch {
        Write-Error "Failed to load public function $($function.FullName): $_"
    }
}

#endregion

# Export ONLY public functions.
# Private functions are accessible within the module scope and via InModuleScope
# in Pester tests, but are not part of the module's public API.
if ($exportedFunctions.Count -gt 0) {
    Export-ModuleMember -Function $exportedFunctions
}

# Do not export variables or aliases by default.
Export-ModuleMember -Variable @() -Alias @()