#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for the private Read-MenuChoice function.
#>

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
}

Describe 'Read-MenuChoice' {
    BeforeAll {
        # Menu output is irrelevant for assertions - silence it.
        Mock Write-Host { } -ModuleName 'ps-script-machine'
    }

    AfterEach {
        Remove-Variable -Name 'PsmTestAnswers' -Scope Global -ErrorAction SilentlyContinue
    }

    Context 'Default handling' {
        It 'returns the default when input is empty' {
            Mock Read-Host { '' } -ModuleName 'ps-script-machine'
            $result = InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'Frage' -Default 'J'
            }
            $result | Should -Be 'J'
        }

        It 'shows the default inside the prompt' {
            Mock Read-Host { '' } -ModuleName 'ps-script-machine'
            InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'Frage' -Default 'CSV'
            }
            Should -Invoke Read-Host -ModuleName 'ps-script-machine' -Times 1 -ParameterFilter {
                $Prompt -like '*Frage*[[]CSV[]]*'
            }
        }

        It 're-prompts on empty input when no default is set' {
            $global:PsmTestAnswers = [System.Collections.Queue]::new()
            $global:PsmTestAnswers.Enqueue('')
            $global:PsmTestAnswers.Enqueue('wert')
            Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

            $result = InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'Frage'
            }
            $result | Should -Be 'wert'
            Should -Invoke Read-Host -ModuleName 'ps-script-machine' -Times 2
        }
    }

    Context 'Validation against -ValidAnswer' {
        It 'returns the canonical value regardless of input casing' {
            Mock Read-Host { 'n' } -ModuleName 'ps-script-machine'
            $result = InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'Frage' -ValidAnswer 'J', 'N'
            }
            $result | Should -BeExactly 'N'
        }

        It 're-prompts until the answer is valid' {
            $global:PsmTestAnswers = [System.Collections.Queue]::new()
            $global:PsmTestAnswers.Enqueue('x')
            $global:PsmTestAnswers.Enqueue('quatsch')
            $global:PsmTestAnswers.Enqueue('j')
            Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

            $result = InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'Frage' -ValidAnswer 'J', 'N'
            }
            $result | Should -BeExactly 'J'
            Should -Invoke Read-Host -ModuleName 'ps-script-machine' -Times 3
        }

        It 'trims surrounding whitespace before validating' {
            Mock Read-Host { '  J  ' } -ModuleName 'ps-script-machine'
            $result = InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'Frage' -ValidAnswer 'J', 'N'
            }
            $result | Should -BeExactly 'J'
        }
    }

    Context 'Free-text input' {
        It 'returns trimmed free text when no ValidAnswer is given' {
            Mock Read-Host { '  vc01.example.local  ' } -ModuleName 'ps-script-machine'
            $result = InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'vCenter'
            }
            $result | Should -Be 'vc01.example.local'
        }
    }
}
