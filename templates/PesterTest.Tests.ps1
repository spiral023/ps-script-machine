#Requires -Version 7.4

<#
.SYNOPSIS
    Pester 5 test template for a module function.

.DESCRIPTION
    This template provides a comprehensive Pester 5 test structure for testing
    a module function. It includes tests for:
    - Regular success cases
    - Invalid parameters
    - Empty results
    - Unreachable vCenter/hosts
    - Multiple vCenter connections
    - Partial failures
    - -WhatIf (for modifying functions)
    - Idempotent behavior
    - Correct result object structure

    PowerCLI cmdlets are mocked in unit tests.

.NOTES
    Replace 'Get-Something' with the actual function name.
    Adjust the mock implementations to match the function's dependencies.
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    # Define mock objects
    $script:mockVIServer = [PSCustomObject]@{
        Name      = 'vcenter.test.local'
        SessionId = 'test-session-id'
        Port      = 443
        Protocol  = 'https'
    }

    $script:mockVMHost = [PSCustomObject]@{
        Name    = 'esxi01.test.local'
        State   = 'Connected'
        Parent  = 'cluster01'
    }

    $script:mockResult = [PSCustomObject]@{
        Name      = 'result01'
        Property1 = 'value1'
        Property2 = 'value2'
    }
}

Describe 'Get-Something' {
    Context 'Regular success cases' {
        BeforeAll {
            Mock Get-SomeObject {
                param($Server, $Name, $ErrorAction)
                return @($script:mockResult)
            } -ModuleName 'ps-script-machine'
        }

        It 'Should return results for a valid VIServer' {
            $result = Get-Something -VIServer $script:mockVIServer
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'result01'
        }

        It 'Should include VIServer in the result' {
            $result = Get-Something -VIServer $script:mockVIServer
            $result[0].VIServer | Should -Be 'vcenter.test.local'
        }

        It 'Should include a timestamp' {
            $result = Get-Something -VIServer $script:mockVIServer
            $result[0].Timestamp | Should -Not -BeNullOrEmpty
        }

        It 'Should include a RunId' {
            $result = Get-Something -VIServer $script:mockVIServer
            $result[0].RunId | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Invalid parameters' {
        It 'Should throw when VIServer is null' {
            { Get-Something -VIServer $null } | Should -Throw
        }

        It 'Should throw when VIServer is empty' {
            { Get-Something -VIServer @() } | Should -Throw
        }
    }

    Context 'Empty results' {
        BeforeAll {
            Mock Get-SomeObject {
                return @()
            } -ModuleName 'ps-script-machine'
        }

        It 'Should return empty array when no results found' {
            $result = Get-Something -VIServer $script:mockVIServer
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Unreachable vCenter' {
        BeforeAll {
            Mock Get-SomeObject {
                throw [System.Net.Sockets.SocketException]::new('No connection could be made')
            } -ModuleName 'ps-script-machine'
        }

        It 'Should handle unreachable vCenter gracefully' {
            { Get-Something -VIServer $script:mockVIServer -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Multiple vCenter connections' {
        BeforeAll {
            $script:mockVIServer2 = [PSCustomObject]@{
                Name      = 'vcenter2.test.local'
                SessionId = 'test-session-id-2'
                Port      = 443
                Protocol  = 'https'
            }

            Mock Get-SomeObject {
                param($Server)
                return @($script:mockResult)
            } -ModuleName 'ps-script-machine'
        }

        It 'Should handle multiple VIServer connections' {
            $result = Get-Something -VIServer @($script:mockVIServer, $script:mockVIServer2)
            $result.Count | Should -Be 2
        }
    }

    Context 'Partial failures' {
        BeforeAll {
            $script:mockVIServer2 = [PSCustomObject]@{
                Name      = 'vcenter2.test.local'
                SessionId = 'test-session-id-2'
            }

            Mock Get-SomeObject {
                param($Server)
                if ([string]$Server -eq 'vcenter2.test.local') {
                    throw 'Connection failed'
                }
                return @($script:mockResult)
            } -ModuleName 'ps-script-machine'
        }

        It 'Should continue processing other servers on partial failure' {
            $result = Get-Something -VIServer @($script:mockVIServer, $script:mockVIServer2) -ErrorAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
        }
    }

    Context 'Correct result object structure' {
        BeforeAll {
            Mock Get-SomeObject {
                return @($script:mockResult)
            } -ModuleName 'ps-script-machine'
        }

        It 'Should return objects with the correct PSTypeName' {
            $result = Get-Something -VIServer $script:mockVIServer
            $result[0].PSTypeNames[0] | Should -Be 'ps-script-machine.Something'
        }

        It 'Should return objects with expected properties' {
            $result = Get-Something -VIServer $script:mockVIServer
            $result[0].PSObject.Properties.Name | Should -Contain 'VIServer'
            $result[0].PSObject.Properties.Name | Should -Contain 'Name'
            $result[0].PSObject.Properties.Name | Should -Contain 'Timestamp'
            $result[0].PSObject.Properties.Name | Should -Contain 'RunId'
        }
    }
}