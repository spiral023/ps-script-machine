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

# PowerCLI is an external dependency (see ExternalModuleDependencies in the
# manifest) and is intentionally NOT required to import this module: unit
# tests mock every PowerCLI cmdlet the module calls. Test-only stand-ins for
# those cmdlets live exclusively in tests/Unit/TestHelpers.ps1 (dot-sourced
# by test files before Import-Module) — the production module itself no
# longer defines stub commands, so a missing PowerCLI installation cannot be
# silently masked at runtime. Real usage is gated by Connect-VIServerSession,
# which fails fast with an actionable error if PowerCLI is not installed.
$script:PowerCLILoaded = $null -ne (Get-Module -Name 'VMware.VimAutomation.ViCore' -ErrorAction SilentlyContinue) -or
$null -ne (Get-Module -Name 'VMware.VimAutomation.Core' -ErrorAction SilentlyContinue)

if (-not $script:PowerCLILoaded) {
    Write-Verbose 'PowerCLI not detected in the current session. PowerCLI cmdlets must be provided by a real installation or mocked in tests.'
}

# Track which VIServer sessions were opened by this module instance so that
# Disconnect-VIServerSession only disconnects sessions the module created.
# External sessions (opened by the caller) are never disconnected by the module.

#region Function loading helpers

# Returns the names of every function declared in a script file (including
# nested/inner helper functions), using the PowerShell language parser
# instead of a line-anchored regex. Unlike a regex match on
# '^\s*function\s+Name\s*\{', this reliably finds ALL declarations in a
# file regardless of attributes, multi-line signatures, or multiple
# functions per file (e.g. a public function plus private script: helpers
# defined alongside it).
function script:Get-DeclaredFunctionName {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $errorMessages = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
        throw "Failed to parse '$Path': $errorMessages"
    }

    $functionAsts = $ast.FindAll(
        { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
        $true
    )

    return @($functionAsts | ForEach-Object { $_.Name })
}

#endregion

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
        # Detect duplicate function definitions (AST-based) before dot-sourcing
        $declaredNames = Get-DeclaredFunctionName -Path $function.FullName
        foreach ($funcName in $declaredNames) {
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
        # Detect duplicate function definitions (AST-based) before dot-sourcing
        $declaredNames = Get-DeclaredFunctionName -Path $function.FullName
        foreach ($funcName in $declaredNames) {
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