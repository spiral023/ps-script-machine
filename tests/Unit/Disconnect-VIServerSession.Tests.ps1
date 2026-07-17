#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for Disconnect-VIServerSession function.
#>

BeforeAll {
    # Load PowerCLI test stand-ins (global scope) before the module is imported.
    # The production module no longer defines its own PowerCLI stubs, so these
    # global functions are what Pester mocks against via -ModuleName.
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $script:mockVIServer = [PSCustomObject]@{
        Name      = 'vcenter.test.local'
        SessionId = 'test-session-id'
        Port      = 443
        Protocol  = 'https'
    }

    $script:mockExternalVIServer = [PSCustomObject]@{
        Name      = 'vcenter.external.local'
        SessionId = 'external-session-id'
        Port      = 443
        Protocol  = 'https'
    }
}

Describe 'Disconnect-VIServerSession' {
    Context 'Module-opened session' {
        BeforeAll {
            Mock Disconnect-VIServer { } -ModuleName 'ps-script-machine'

            InModuleScope 'ps-script-machine' {
                $script:ModuleSessions.Clear()
                $null = $script:ModuleSessions.Add('vcenter.test.local:test-session-id')
            }
        }

        It 'Should disconnect a module-opened session' {
            InModuleScope 'ps-script-machine' -Parameters @{ Conn = $script:mockVIServer } {
                Disconnect-VIServerSession -Connection $Conn
            }
            Should -Invoke Disconnect-VIServer -ModuleName 'ps-script-machine' -Times 1
        }

        It 'Should remove the session from ModuleSessions after disconnect' {
            InModuleScope 'ps-script-machine' {
                $null = $script:ModuleSessions.Add('vcenter.test.local:test-session-id')
            }

            InModuleScope 'ps-script-machine' -Parameters @{ Conn = $script:mockVIServer } {
                Disconnect-VIServerSession -Connection $Conn
            }

            $stillTracked = InModuleScope 'ps-script-machine' {
                $script:ModuleSessions.Contains('vcenter.test.local:test-session-id')
            }
            $stillTracked | Should -BeFalse
        }
    }

    Context 'External session (not opened by module)' {
        BeforeAll {
            Mock Disconnect-VIServer { } -ModuleName 'ps-script-machine'

            InModuleScope 'ps-script-machine' {
                $script:ModuleSessions.Clear()
            }
        }

        It 'Should NOT disconnect an external session' {
            InModuleScope 'ps-script-machine' -Parameters @{ Conn = $script:mockExternalVIServer } {
                Disconnect-VIServerSession -Connection $Conn
            }
            Should -Invoke Disconnect-VIServer -ModuleName 'ps-script-machine' -Times 0
        }
    }

    Context 'Null and empty connection' {
        BeforeAll {
            Mock Disconnect-VIServer { } -ModuleName 'ps-script-machine'
        }

        It 'Should not throw when Connection is null' {
            InModuleScope 'ps-script-machine' {
                { Disconnect-VIServerSession -Connection $null } | Should -Not -Throw
            }
        }

        It 'Should not throw when Connection is empty string' {
            InModuleScope 'ps-script-machine' {
                { Disconnect-VIServerSession -Connection '' } | Should -Not -Throw
            }
        }

        It 'Should not call Disconnect-VIServer when Connection is null' {
            InModuleScope 'ps-script-machine' {
                Disconnect-VIServerSession -Connection $null
            }
            Should -Invoke Disconnect-VIServer -ModuleName 'ps-script-machine' -Times 0
        }
    }
}