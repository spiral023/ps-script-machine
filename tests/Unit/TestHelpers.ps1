#Requires -Version 7.4

<#
.SYNOPSIS
    Test helper functions for unit tests.

.DESCRIPTION
    This file provides dummy function definitions for PowerCLI cmdlets that
    are not available when PowerCLI is not installed.  This allows Pester to
    create mocks for these cmdlets.

    This file must be dot-sourced (not imported as a module) so that the
    dummy functions are defined in the global scope, making them visible to
    the ps-script-machine module.

    The dummy functions are empty stubs that do nothing - they exist solely
    so that Pester can mock them.  The actual behavior is defined by the
    Mock definitions in each test file.
#>

# Define dummy functions for PowerCLI cmdlets in the GLOBAL scope
# so they are visible to the ps-script-machine module.

if (-not (Get-Command -Name 'Connect-VIServer' -ErrorAction SilentlyContinue)) {
    function global:Connect-VIServer {
        param(
            [string]$Server,
            [System.Management.Automation.PSCredential]$Credential,
            [int]$Port = 443,
            [string]$Protocol = 'https',
            [string]$ErrorAction
        )
    }
}

if (-not (Get-Command -Name 'Disconnect-VIServer' -ErrorAction SilentlyContinue)) {
    function global:Disconnect-VIServer {
        param(
            [object]$Server,
            [switch]$Confirm,
            [string]$ErrorAction
        )
    }
}

if (-not (Get-Command -Name 'Get-VMHost' -ErrorAction SilentlyContinue)) {
    function global:Get-VMHost {
        param(
            [object]$Server,
            [string[]]$Name,
            [string]$ErrorAction
        )
    }
}

if (-not (Get-Command -Name 'Get-EsxCli' -ErrorAction SilentlyContinue)) {
    function global:Get-EsxCli {
        param(
            [object]$Server,
            [object]$VMHost,
            [string]$ErrorAction
        )
    }
}

if (-not (Get-Command -Name 'Get-Cluster' -ErrorAction SilentlyContinue)) {
    function global:Get-Cluster {
        param(
            [string[]]$Name,
            [object]$Server,
            [string]$ErrorAction
        )
    }
}

if (-not (Get-Command -Name 'Get-VMHostNetworkAdapter' -ErrorAction SilentlyContinue)) {
    function global:Get-VMHostNetworkAdapter {
        param(
            [object]$VMHost,
            [switch]$Physical,
            [string]$ErrorAction
        )
    }
}

if (-not (Get-Command -Name 'Get-View' -ErrorAction SilentlyContinue)) {
    function global:Get-View {
        param(
            [string]$Id,
            [string]$ErrorAction
        )
    }
}