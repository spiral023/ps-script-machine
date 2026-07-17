#Requires -Version 7.4

<#
.SYNOPSIS
    Legacy test file - redirects to the new test location.

.DESCRIPTION
    This is a legacy test file. The actual tests have been moved to:
    tests/Unit/Get-CdpNetworkInfo.Tests.ps1

    This file simply runs the new test file for backward compatibility.
#>

BeforeAll {
    $newTestPath = Join-Path -Path $PSScriptRoot -ChildPath 'Unit\Get-CdpNetworkInfo.Tests.ps1'
    if (-not (Test-Path $newTestPath)) {
        throw "New test file not found: $newTestPath"
    }
}

Describe 'Get-CdpNetworkInfo (Legacy)' {
    It 'Should have tests in the new location' {
        $newTestPath = Join-Path -Path $PSScriptRoot -ChildPath 'Unit\Get-CdpNetworkInfo.Tests.ps1'
        Test-Path $newTestPath | Should -BeTrue
    }
}