#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for Connect-VIServerSession function.
#>

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $script:mockVIServer = [PSCustomObject]@{
        Name      = 'vcenter.test.local'
        SessionId = 'test-session-id'
        Port      = 443
        Protocol  = 'https'
    }

    $script:mockCredential = [System.Management.Automation.PSCredential]::new(
        'user',
        (ConvertTo-SecureString 'password' -AsPlainText -Force)
    )
}

Describe 'Connect-VIServerSession' {
    Context 'Regular success cases' {
        BeforeAll {
            Mock Connect-VIServer {
                return $script:mockVIServer
            } -ModuleName 'ps-script-machine'
        }

        It 'Should return a VIServer object on successful connection' {
            $result = InModuleScope 'ps-script-machine' -Parameters @{ Server = 'vcenter.test.local'; Cred = $script:mockCredential } {
                Connect-VIServerSession -Server $Server -Credential $Cred
            }
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'vcenter.test.local'
        }

        It 'Should use default port 443' {
            InModuleScope 'ps-script-machine' -Parameters @{ Cred = $script:mockCredential } {
                Connect-VIServerSession -Server 'vcenter.test.local' -Credential $Cred
            }
            Should -Invoke Connect-VIServer -ModuleName 'ps-script-machine' -Times 1 -ParameterFilter {
                $Port -eq 443
            }
        }

        It 'Should use default protocol https' {
            InModuleScope 'ps-script-machine' -Parameters @{ Cred = $script:mockCredential } {
                Connect-VIServerSession -Server 'vcenter.test.local' -Credential $Cred
            }
            Should -Invoke Connect-VIServer -ModuleName 'ps-script-machine' -Times 1 -ParameterFilter {
                $Protocol -eq 'https'
            }
        }
    }

    Context 'Custom port and protocol' {
        BeforeAll {
            Mock Connect-VIServer {
                return $script:mockVIServer
            } -ModuleName 'ps-script-machine'
        }

        It 'Should accept custom port' {
            InModuleScope 'ps-script-machine' -Parameters @{ Cred = $script:mockCredential } {
                Connect-VIServerSession -Server 'vcenter.test.local' -Credential $Cred -Port 8443
            }
            Should -Invoke Connect-VIServer -ModuleName 'ps-script-machine' -Times 1 -ParameterFilter {
                $Port -eq 8443
            }
        }

        It 'Should accept custom protocol' {
            InModuleScope 'ps-script-machine' -Parameters @{ Cred = $script:mockCredential } {
                Connect-VIServerSession -Server 'vcenter.test.local' -Credential $Cred -Protocol 'http'
            }
            Should -Invoke Connect-VIServer -ModuleName 'ps-script-machine' -Times 1 -ParameterFilter {
                $Protocol -eq 'http'
            }
        }
    }

    Context 'Invalid parameters' {
        It 'Should throw when Server is null' {
            InModuleScope 'ps-script-machine' -Parameters @{ Cred = $script:mockCredential } {
                { Connect-VIServerSession -Server $null -Credential $Cred } | Should -Throw
            }
        }

        It 'Should throw when Server is empty' {
            InModuleScope 'ps-script-machine' -Parameters @{ Cred = $script:mockCredential } {
                { Connect-VIServerSession -Server '' -Credential $Cred } | Should -Throw
            }
        }

        It 'Should throw when Credential is null' {
            # When passing $null to a mandatory PSCredential parameter,
            # PowerShell prompts. We test the validation by checking that
            # the parameter is mandatory.
            $cmd = InModuleScope 'ps-script-machine' {
                Get-Command -Name 'Connect-VIServerSession'
            }
            $param = $cmd.Parameters['Credential']
            $param.Attributes.Mandatory | Should -BeTrue
        }

        It 'Should throw when Port is out of range' {
            InModuleScope 'ps-script-machine' -Parameters @{ Cred = $script:mockCredential } {
                { Connect-VIServerSession -Server 'vcenter.test.local' -Credential $Cred -Port 0 } | Should -Throw
            }
            InModuleScope 'ps-script-machine' -Parameters @{ Cred = $script:mockCredential } {
                { Connect-VIServerSession -Server 'vcenter.test.local' -Credential $Cred -Port 70000 } | Should -Throw
            }
        }

        It 'Should throw when Protocol is invalid' {
            InModuleScope 'ps-script-machine' -Parameters @{ Cred = $script:mockCredential } {
                { Connect-VIServerSession -Server 'vcenter.test.local' -Credential $Cred -Protocol 'ftp' } | Should -Throw
            }
        }
    }

    Context 'Connection failure' {
        BeforeAll {
            Mock Connect-VIServer {
                throw [System.Net.Sockets.SocketException]::new('No connection could be made')
            } -ModuleName 'ps-script-machine'
        }

        It 'Should return null on connection failure' {
            $result = InModuleScope 'ps-script-machine' -Parameters @{ Cred = $script:mockCredential } {
                Connect-VIServerSession -Server 'vcenter.test.local' -Credential $Cred -ErrorAction SilentlyContinue
            }
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'No session returned' {
        BeforeAll {
            Mock Connect-VIServer {
                return $null
            } -ModuleName 'ps-script-machine'
        }

        It 'Should return null when no session is returned' {
            $result = InModuleScope 'ps-script-machine' -Parameters @{ Cred = $script:mockCredential } {
                Connect-VIServerSession -Server 'vcenter.test.local' -Credential $Cred -ErrorAction SilentlyContinue
            }
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Session tracking' {
        BeforeAll {
            Mock Connect-VIServer {
                return $script:mockVIServer
            } -ModuleName 'ps-script-machine'
        }

        It 'Should track the session in ModuleSessions after successful connect' {
            InModuleScope 'ps-script-machine' {
                $script:ModuleSessions.Clear()
            }

            InModuleScope 'ps-script-machine' -Parameters @{ Cred = $script:mockCredential } {
                Connect-VIServerSession -Server 'vcenter.test.local' -Credential $Cred
            }

            $tracked = InModuleScope 'ps-script-machine' {
                $script:ModuleSessions.Contains('vcenter.test.local:test-session-id')
            }
            $tracked | Should -BeTrue
        }
    }
}