#Requires -Version 7.4

<#
.SYNOPSIS
    Test helper functions for unit tests.

.DESCRIPTION
    This file is the single source of truth for PowerCLI cmdlet stand-ins
    used in unit tests. The ps-script-machine module itself does NOT define
    any PowerCLI stubs - it is a hard requirement that a missing PowerCLI
    installation surface as a real error (see Connect-VIServerSession),
    rather than being silently masked by production stub code.

    This file provides dummy function definitions for PowerCLI cmdlets that
    are not available when PowerCLI is not installed. This allows Pester to
    create mocks for these cmdlets.

    This file must be dot-sourced (not imported as a module) BEFORE
    Import-Module of ps-script-machine, so that the dummy functions are
    defined in the global scope, making them resolvable when the module's
    functions call unqualified PowerCLI cmdlet names, and so that Pester's
    Mock -ModuleName 'ps-script-machine' can find a command to intercept.

    The dummy functions are empty stubs that do nothing - they exist solely
    so that Pester can mock them. The actual behavior is defined by the
    Mock definitions in each test file.
#>

# Define dummy functions for PowerCLI cmdlets in the GLOBAL scope so they
# are visible to the ps-script-machine module.
#
# Guard by whether the real PowerCLI module is loaded - NOT by whether a
# command of the same name already exists. Some of these names (notably
# Get-VMHost) collide with unrelated cmdlets from other Windows features
# (e.g. Hyper-V's Get-VMHost). A `Get-Command -Name 'Get-VMHost'` guard
# would find that unrelated cmdlet, skip defining our stub, and leave
# Pester mocking the Hyper-V cmdlet's incompatible parameter set instead -
# tests would then fail with "parameter cannot be found" errors that have
# nothing to do with this module.
$script:powerCLIModuleLoaded = $null -ne (Get-Module -Name 'VMware.VimAutomation.ViCore' -ErrorAction SilentlyContinue) -or
$null -ne (Get-Module -Name 'VMware.VimAutomation.Core' -ErrorAction SilentlyContinue)

if (-not $script:powerCLIModuleLoaded) {
    function global:Connect-VIServer {
        param(
            [string]$Server,
            [System.Management.Automation.PSCredential]$Credential,
            [int]$Port = 443,
            [string]$Protocol = 'https',
            [string]$ErrorAction
        )
    }

    function global:Disconnect-VIServer {
        param(
            [object]$Server,
            [switch]$Confirm,
            [string]$ErrorAction
        )
    }

    function global:Get-VMHost {
        param(
            [object]$Server,
            [string[]]$Name,
            [object]$Location,
            [string]$ErrorAction
        )
    }

    function global:Get-EsxCli {
        param(
            [object]$Server,
            [object]$VMHost,
            [string]$ErrorAction
        )
    }

    function global:Get-Cluster {
        param(
            [string[]]$Name,
            [object]$Server,
            [string]$ErrorAction
        )
    }

    function global:Get-VMHostNetworkAdapter {
        param(
            [object]$VMHost,
            [switch]$Physical,
            [string]$ErrorAction
        )
    }

    function global:Get-View {
        param(
            [string]$Id,
            [string]$ErrorAction
        )
    }
}