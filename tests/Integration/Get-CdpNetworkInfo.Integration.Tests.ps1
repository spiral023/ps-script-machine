#Requires -Version 7.4

<#
.SYNOPSIS
    Integration tests for Get-CdpNetworkInfo function.

.DESCRIPTION
    These tests connect to a real vCenter Server and verify the function
    works against a live environment.

    Integration tests are DISABLED by default and must be explicitly enabled
    via multiple environment variables:
    - PS_SCRIPT_MACHINE_INTEGRATION_TESTS = 'true' (master switch)
    - PS_SCRIPT_MACHINE_VCENTER = vCenter FQDN (must be in the allowed lab list)

    Additional safety measures:
    - The vCenter FQDN must match the allowed lab vCenter list
    - Known production vCenter names are explicitly blocked
    - A read-only test account is recommended
    - A clear warning is displayed and confirmation is required
    - These tests must run in a separate CI environment

    VMware version support:
    - vCenter 7.0 and 8.0: vorgesehen (intended), nicht verifiziert (not verified)
    - ESXi 7.0 and 8.0: vorgesehen (intended), nicht verifiziert (not verified)
    These versions have not been tested against a live environment in this CI.
    They are declared as "intended" support targets, not as "verified" support.

    To enable:
    $env:PS_SCRIPT_MACHINE_INTEGRATION_TESTS = 'true'
    $env:PS_SCRIPT_MACHINE_VCENTER = 'vcenter.lab.example.com'

    Credentials must be provided via SecretManagement or interactive prompt.

.NOTES
    WARNING: These tests connect to a real vCenter Server.
    Ensure you are using a test/lab environment.
    These tests are read-only and do not modify any configuration.

    VMware version support status:
    - vCenter 7.0: vorgesehen (not verified)
    - vCenter 8.0: vorgesehen (not verified)
    - ESXi 7.0: vorgesehen (not verified)
    - ESXi 8.0: vorgesehen (not verified)
#>

BeforeAll {
    # Check if integration tests are enabled
    $integrationEnabled = $env:PS_SCRIPT_MACHINE_INTEGRATION_TESTS -eq 'true'
    $vcenter = $env:PS_SCRIPT_MACHINE_VCENTER

    # Allowed lab vCenter list (must be explicitly set by the user)
    # These are example patterns - real lab vCenters should be configured here
    $script:allowedLabVcenters = @(
        'vcenter.lab.example.com'
        'vcenter.test.example.com'
        'vcenter-lab.local'
        'vcenter-test.local'
    )

    # Known production vCenter patterns that are ALWAYS blocked
    $script:blockedProductionPatterns = @(
        'prod'
        'production'
        'vcenter01.'
        'vcenter02.'
        'vc01.'
        'vc02.'
    )

    # Check if the vCenter is in the allowed lab list
    $isAllowedLab = $false
    if ($vcenter) {
        foreach ($allowed in $script:allowedLabVcenters) {
            if ($vcenter -ieq $allowed) {
                $isAllowedLab = $true
                break
            }
        }
    }

    # Check if the vCenter matches any blocked production pattern
    $isBlockedProduction = $false
    if ($vcenter) {
        foreach ($pattern in $script:blockedProductionPatterns) {
            if ($vcenter -imatch $pattern) {
                $isBlockedProduction = $true
                break
            }
        }
    }

    if (-not $integrationEnabled) {
        Write-Host "Integration tests are disabled. Set PS_SCRIPT_MACHINE_INTEGRATION_TESTS='true' to enable." -ForegroundColor Yellow
        $script:skipped = $true
    }
    elseif (-not $vcenter) {
        Write-Host "PS_SCRIPT_MACHINE_VCENTER environment variable not set. Skipping integration tests." -ForegroundColor Yellow
        $script:skipped = $true
    }
    elseif ($isBlockedProduction) {
        Write-Host "BLOCKED: The vCenter '$vcenter' matches a known production pattern. Integration tests are refused." -ForegroundColor Red
        Write-Host "Integration tests must only run against lab/test environments." -ForegroundColor Red
        $script:skipped = $true
    }
    elseif (-not $isAllowedLab) {
        Write-Host "BLOCKED: The vCenter '$vcenter' is not in the allowed lab vCenter list." -ForegroundColor Red
        Write-Host "Allowed lab vCenters: $($script:allowedLabVcenters -join ', ')" -ForegroundColor Yellow
        Write-Host "Add your lab vCenter to the allowed list in the integration test file." -ForegroundColor Yellow
        $script:skipped = $true
    }
    else {
        # Display a clear warning and require confirmation
        Write-Host ""
        Write-Host "=========================================================" -ForegroundColor Yellow
        Write-Host "  INTEGRATION TEST WARNING" -ForegroundColor Yellow
        Write-Host "=========================================================" -ForegroundColor Yellow
        Write-Host "  You are about to run integration tests against:" -ForegroundColor Yellow
        Write-Host "  vCenter: $vcenter" -ForegroundColor White
        Write-Host ""
        Write-Host "  VMware version support status:" -ForegroundColor Yellow
        Write-Host "    vCenter 7.0: vorgesehen (not verified)" -ForegroundColor Gray
        Write-Host "    vCenter 8.0: vorgesehen (not verified)" -ForegroundColor Gray
        Write-Host "    ESXi 7.0: vorgesehen (not verified)" -ForegroundColor Gray
        Write-Host "    ESXi 8.0: vorgesehen (not verified)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  These tests are READ-ONLY and do not modify configuration." -ForegroundColor Green
        Write-Host "  A read-only test account is recommended." -ForegroundColor Green
        Write-Host "=========================================================" -ForegroundColor Yellow
        Write-Host ""

        # In CI mode, skip the interactive confirmation
        $inCI = $env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true'
        if (-not $inCI) {
            $confirmation = Read-Host "Type 'YES' to confirm and proceed with integration tests"
            if ($confirmation -ne 'YES') {
                Write-Host "Integration tests cancelled by user." -ForegroundColor Yellow
                $script:skipped = $true
            }
            else {
                $script:skipped = $false
            }
        }
        else {
            $script:skipped = $false
        }

        if (-not $script:skipped) {
            $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
            Import-Module -Name $modulePath -Force -ErrorAction Stop

            # Get credentials - prefer SecretManagement
            $cred = $null
            try {
                $cred = Get-Secret -Name "vcenter-integration" -Vault 'ps-script-machine' -ErrorAction Stop
            }
            catch {
                $cred = Get-Credential -Message "Enter credentials for $vcenter (read-only account recommended)"
            }

            $script:session = Connect-VIServerSession -Server $vcenter -Credential $cred
        }
    }
}

AfterAll {
    if ($script:session) {
        Disconnect-VIServerSession -Connection $script:session
    }
}

Describe 'Get-CdpNetworkInfo - Integration' -Tag 'Integration' {
    Context 'Live vCenter connection' {
        It "Should connect to vCenter and return CDP info" -Skip:$script:skipped {
            $result = Get-CdpNetworkInfo -VIServer $script:session
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should include VIServer in results" -Skip:$script:skipped {
            $result = Get-CdpNetworkInfo -VIServer $script:session
            $result[0].VIServer | Should -Not -BeNullOrEmpty
        }

        It "Should include RunId in results" -Skip:$script:skipped {
            $result = Get-CdpNetworkInfo -VIServer $script:session
            $result[0].RunId | Should -Not -BeNullOrEmpty
        }

        It "Should include Timestamp in results" -Skip:$script:skipped {
            $result = Get-CdpNetworkInfo -VIServer $script:session
            $result[0].Timestamp | Should -Not -BeNullOrEmpty
        }
    }
}