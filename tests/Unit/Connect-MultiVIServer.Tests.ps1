#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for the public Connect-MultiVIServer function.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Disposable mock PSCredential for unit testing only - never a real secret, never persisted or logged.')]
param()

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $script:mockCredential = [System.Management.Automation.PSCredential]::new(
        'user@vsphere.local',
        (ConvertTo-SecureString 'password' -AsPlainText -Force)
    )

    function script:New-MockSession {
        param([string]$Name)
        [PSCustomObject]@{
            Name      = $Name
            SessionId = "session-$Name"
            Port      = 443
            Protocol  = 'https'
        }
    }
}

Describe 'Connect-MultiVIServer' {
    BeforeAll {
        Mock Write-Host { } -ModuleName 'ps-script-machine'
    }

    AfterEach {
        Remove-Variable -Name 'PsmTestAnswers' -Scope Global -ErrorAction SilentlyContinue
    }

    Context 'All connections succeed' {
        BeforeAll {
            Mock Connect-VIServer {
                param($Server)
                [PSCustomObject]@{ Name = $Server; SessionId = "session-$Server"; Port = 443; Protocol = 'https' }
            } -ModuleName 'ps-script-machine'
        }

        It 'connects to every server with the given credential' {
            $result = Connect-MultiVIServer -Server 'vc01.test.local', 'vc02.test.local' -Credential $script:mockCredential
            $result.Connected | Should -Be @('vc01.test.local', 'vc02.test.local')
            $result.Skipped | Should -BeNullOrEmpty
            @($result.Sessions).Count | Should -Be 2
            Should -Invoke Connect-VIServer -ModuleName 'ps-script-machine' -Times 2 -Exactly
        }

        It 'returns the documented result object shape' {
            $result = Connect-MultiVIServer -Server 'vc01.test.local' -Credential $script:mockCredential
            $result.PSObject.TypeNames | Should -Contain 'ps-script-machine.MultiVIServerConnection'
            $result.Timestamp | Should -Not -BeNullOrEmpty
            $result.RunId | Should -Not -BeNullOrEmpty
        }

        It 'deduplicates the server list' {
            $result = Connect-MultiVIServer -Server 'vc01.test.local', 'vc01.test.local' -Credential $script:mockCredential
            @($result.Sessions).Count | Should -Be 1
            Should -Invoke Connect-VIServer -ModuleName 'ps-script-machine' -Times 1 -Exactly
        }

        It 'asks for a credential when none is given' {
            Mock Get-Credential { $script:mockCredential } -ModuleName 'ps-script-machine'
            $result = Connect-MultiVIServer -Server 'vc01.test.local'
            $result.Connected | Should -Be @('vc01.test.local')
            Should -Invoke Get-Credential -ModuleName 'ps-script-machine' -Times 1 -Exactly
        }
    }

    Context 'A connection fails' {
        BeforeAll {
            Mock Connect-VIServer {
                param($Server)
                if ($Server -eq 'vc-kaputt.test.local') {
                    throw 'Cannot complete login due to an incorrect user name or password.'
                }
                [PSCustomObject]@{ Name = $Server; SessionId = "session-$Server"; Port = 443; Protocol = 'https' }
            } -ModuleName 'ps-script-machine'
        }

        It 'skips the failing server in NonInteractive mode and continues' {
            $result = Connect-MultiVIServer `
                -Server 'vc01.test.local', 'vc-kaputt.test.local', 'vc02.test.local' `
                -Credential $script:mockCredential -NonInteractive -WarningAction SilentlyContinue
            $result.Connected | Should -Be @('vc01.test.local', 'vc02.test.local')
            $result.Skipped | Should -Be @('vc-kaputt.test.local')
        }

        It 'skips the failing server when the user chooses u' {
            Mock Read-Host { 'u' } -ModuleName 'ps-script-machine'
            $result = Connect-MultiVIServer `
                -Server 'vc-kaputt.test.local', 'vc01.test.local' `
                -Credential $script:mockCredential -WarningAction SilentlyContinue
            $result.Skipped | Should -Be @('vc-kaputt.test.local')
            $result.Connected | Should -Be @('vc01.test.local')
        }
    }

    Context 'A connection fails once and succeeds on retry' {
        # Robust replacement for the fragile "global flag + Get-Variable -eq $null"
        # pattern: a global counter that the Connect-VIServer mock increments on
        # every call. The first call (count -eq 1) fails, every subsequent call
        # succeeds. The counter lives in $global: scope (not $script:) because
        # Pester's Mock -ModuleName scriptblock executes against the target
        # module's session state, not this test file's script scope - the
        # established pattern in this test suite (see Select-VIServerTarget.Tests.ps1)
        # already relies on $global: for exactly this reason. Resetting in
        # BeforeEach/AfterEach keeps it from leaking into other tests/contexts.
        BeforeEach {
            $global:PsmConnectCallCount = 0
        }

        AfterEach {
            Remove-Variable -Name 'PsmConnectCallCount' -Scope Global -ErrorAction SilentlyContinue
        }

        It 'retries with new credentials when the user chooses n' {
            $global:PsmTestAnswers = [System.Collections.Queue]::new()
            $global:PsmTestAnswers.Enqueue('n')
            Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'
            Mock Get-Credential { $script:mockCredential } -ModuleName 'ps-script-machine'
            Mock Connect-VIServer {
                param($Server, $Credential)
                $global:PsmConnectCallCount++
                if ($global:PsmConnectCallCount -eq 1) {
                    # First attempt always fails; the retry (any later call) succeeds.
                    throw 'Cannot complete login.'
                }
                [PSCustomObject]@{ Name = $Server; SessionId = "session-$Server"; Port = 443; Protocol = 'https' }
            } -ModuleName 'ps-script-machine'

            $result = Connect-MultiVIServer -Server 'vc01.test.local' -Credential $script:mockCredential -WarningAction SilentlyContinue

            $result.Connected | Should -Be @('vc01.test.local')
            $result.Skipped | Should -BeNullOrEmpty
            $global:PsmConnectCallCount | Should -Be 2
            Should -Invoke Get-Credential -ModuleName 'ps-script-machine' -Times 1 -Exactly
        }
    }

    Context 'Parameter validation' {
        It 'throws in NonInteractive mode when no credential is given' {
            { Connect-MultiVIServer -Server 'vc01.test.local' -NonInteractive } |
                Should -Throw '*Credential*'
        }
    }
}
