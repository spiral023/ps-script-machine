#Requires - Version 7.4

<#
.SYNOPSIS
    Acceptance tests for the ps-script-machine module.

.DESCRIPTION
    These tests verify that the module meets the acceptance criteria:
    - Module can be imported
    - All expected public functions are exported
    - Private functions are NOT exported
    - Module manifest is valid
    - No hardcoded credentials or environment values
    - No Invoke-Expression
    - No Format-Table/Format-List in function logic
    - No global variables
#>

BeforeAll {
    $script:modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
}

Describe 'Module Acceptance Tests' -Tag 'Acceptance' {
    Context 'Module manifest' {
        It 'Module manifest file should exist' {
            Test-Path $script:modulePath | Should -BeTrue
        }

        It 'Module manifest should be valid' {
            { Test-ModuleManifest -Path $script:modulePath -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Module should require PowerShell 7.4 or newer' {
            $manifest = Test-ModuleManifest -Path $script:modulePath -ErrorAction SilentlyContinue
            $manifest.PowerShellVersion | Should -BeGreaterOrEqual '7.4'
        }

        It 'Module should declare VMware.PowerCLI as external dependency' {
            $manifestData = Import-PowerShellDataFile -Path $script:modulePath
            $manifestData.PrivateData.PSData.ExternalModuleDependencies | Should -Contain 'VMware.PowerCLI'
        }

        It 'Module should NOT have VMware.PowerCLI in RequiredModules' {
            $manifestData = Import-PowerShellDataFile -Path $script:modulePath
            $manifestData.RequiredModules | Should -BeNullOrEmpty
        }

        It 'FunctionsToExport should be an explicit list (not wildcard)' {
            $manifestData = Import-PowerShellDataFile -Path $script:modulePath
            $manifestData.FunctionsToExport | Should -Not -Contain '*'
            $manifestData.FunctionsToExport.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Module import' {
        BeforeAll {
            Import-Module -Name $script:modulePath -Force -ErrorAction Stop
        }

        It 'Module should import without errors' {
            { Import-Module -Name $script:modulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Module should export Get-CdpNetworkInfo function' {
            $commands = Get-Command -Module 'ps-script-machine' -ErrorAction SilentlyContinue
            $commands.Name | Should -Contain 'Get-CdpNetworkInfo'
        }

        It 'Module should export Export-ModuleData function' {
            $commands = Get-Command -Module 'ps-script-machine' -ErrorAction SilentlyContinue
            $commands.Name | Should -Contain 'Export-ModuleData'
        }

        It 'Module should export Get-VMHostNetworkInfo function' {
            $commands = Get-Command -Module 'ps-script-machine' -ErrorAction SilentlyContinue
            $commands.Name | Should -Contain 'Get-VMHostNetworkInfo'
        }

        It 'Module should NOT export private functions' {
            $commands = Get-Command -Module 'ps-script-machine' -ErrorAction SilentlyContinue
            $commands.Name | Should -Not -Contain 'Connect-VIServerSession'
            $commands.Name | Should -Not -Contain 'Disconnect-VIServerSession'
            $commands.Name | Should -Not -Contain 'Write-ModuleLog'
            $commands.Name | Should -Not -Contain 'Write-ScriptLog'
            $commands.Name | Should -Not -Contain 'ConvertTo-CleanText'
            $commands.Name | Should -Not -Contain 'Export-ReportCsv'
            $commands.Name | Should -Not -Contain 'Export-ReportJson'
        }
    }

    Context 'Security checks' {
        It 'No hardcoded passwords in source files' {
            $sourceFiles = Get-ChildItem -Path "$PSScriptRoot\..\..\src" -Recurse -Include '*.ps1','*.psm1' -ErrorAction SilentlyContinue
            foreach ($file in $sourceFiles) {
                $content = Get-Content -Path $file.FullName -Raw
                # Check for common password patterns (not in comments)
                $lines = $content -split "`n" | Where-Object { $_ -notmatch '^\s*#' }
                foreach ($line in $lines) {
                    $line | Should -Not -Match '(?i)password\s*=\s*[''"][^''"]+[''"]'
                }
            }
        }

        It 'No hardcoded server names in source files' {
            $sourceFiles = Get-ChildItem -Path "$PSScriptRoot\..\..\src" -Recurse -Include '*.ps1','*.psm1' -ErrorAction SilentlyContinue
            foreach ($file in $sourceFiles) {
                $content = Get-Content -Path $file.FullName -Raw
                # Check for common hardcoded server patterns (not in comments or examples)
                $lines = $content -split "`n" | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch 'example\.com' -and $_ -notmatch 'test\.local' }
                foreach ($line in $lines) {
                    $line | Should -Not -Match '(?i)Connect-VIServer\s+.*-Server\s+[''"][^''"]+[''"]'
                }
            }
        }

        It 'No Invoke-Expression in source files' {
            $sourceFiles = Get-ChildItem -Path "$PSScriptRoot\..\..\src" -Recurse -Include '*.ps1','*.psm1' -ErrorAction SilentlyContinue
            foreach ($file in $sourceFiles) {
                $content = Get-Content -Path $file.FullName -Raw
                # Check for Invoke-Expression usage (not in comments)
                $lines = $content -split "`n" | Where-Object { $_ -notmatch '^\s*#' }
                foreach ($line in $lines) {
                    $line | Should -Not -Match '(?i)\bInvoke-Expression\b'
                }
            }
        }

        It 'No Format-Table/Format-List in public function logic' {
            $publicFiles = Get-ChildItem -Path "$PSScriptRoot\..\..\src\ps-script-machine\Public\*.ps1" -ErrorAction SilentlyContinue
            foreach ($file in $publicFiles) {
                $content = Get-Content -Path $file.FullName -Raw
                $lines = $content -split "`n"
                $inComment = $false
                $lineNum = 0
                foreach ($line in $lines) {
                    $lineNum++
                    if ($line -match '<#') { $inComment = $true }
                    if ($line -match '#>') { $inComment = $false; continue }
                    if ($inComment) { continue }
                    if ($line -match '^\s*#') { continue }
                    $line | Should -Not -Match '\bFormat-Table\b'
                    $line | Should -Not -Match '\bFormat-List\b'
                }
            }
        }

        It 'No global variables in source files' {
            $sourceFiles = Get-ChildItem -Path "$PSScriptRoot\..\..\src" -Recurse -Include '*.ps1','*.psm1' -ErrorAction SilentlyContinue
            foreach ($file in $sourceFiles) {
                $content = Get-Content -Path $file.FullName -Raw
                $lines = $content -split "`n" | Where-Object { $_ -notmatch '^\s*#' }
                foreach ($line in $lines) {
                    $line | Should -Not -Match '\$global:'
                }
            }
        }
    }

    Context 'Module session tracking' {
        It 'Should have ModuleSessions set initialized on import' {
            $hasSessions = InModuleScope 'ps-script-machine' {
                $null -ne $script:ModuleSessions
            }
            $hasSessions | Should -BeTrue
        }

        It 'Should have LogRunId initialized on import' {
            $hasRunId = InModuleScope 'ps-script-machine' {
                $null -ne $script:LogRunId -and $script:LogRunId -ne ''
            }
            $hasRunId | Should -BeTrue
        }
    }
}