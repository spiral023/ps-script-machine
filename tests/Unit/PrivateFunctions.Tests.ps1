#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for private helper functions.

.DESCRIPTION
    Comprehensive Pester 5 unit tests for private helper functions:
    - ConvertTo-CleanText
    - Export-ReportCsv
    - Export-ReportJson
    - Write-ScriptLog
    - Disconnect-VIServerSession (additional edge cases)

    These tests use InModuleScope to access private functions directly.
#>

BeforeAll {
    # Import test helpers (dummy PowerCLI cmdlets) before importing the module
    $testHelpersPath = Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1'
    . $testHelpersPath

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $script:testOutputPath = Join-Path $env:TEMP "ps-script-machine-private-test-$(Get-Random)"
    $null = New-Item -Path $script:testOutputPath -ItemType Directory -Force
}

AfterAll {
    if (Test-Path $script:testOutputPath) {
        Remove-Item -Path $script:testOutputPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'ConvertTo-CleanText' {
    Context 'Null and empty values' {
        It 'Should return empty string for null value' {
            InModuleScope 'ps-script-machine' {
                $result = ConvertTo-CleanText -Value $null
                $result | Should -Be ''
            }
        }

        It 'Should return empty string for empty string' {
            InModuleScope 'ps-script-machine' {
                $result = ConvertTo-CleanText -Value ''
                $result | Should -Be ''
            }
        }
    }

    Context 'String values' {
        It 'Should trim leading and trailing whitespace' {
            InModuleScope 'ps-script-machine' {
                $result = ConvertTo-CleanText -Value '  Hallo Welt  '
                $result | Should -Be 'Hallo Welt'
            }
        }

        It 'Should replace multiple whitespaces with single space' {
            InModuleScope 'ps-script-machine' {
                $result = ConvertTo-CleanText -Value 'Hallo    Welt'
                $result | Should -Be 'Hallo Welt'
            }
        }

        It 'Should replace tabs and newlines with single space' {
            InModuleScope 'ps-script-machine' {
                $result = ConvertTo-CleanText -Value "Hallo`t`tWelt`nNeue`rZeile"
                $result | Should -Be 'Hallo Welt Neue Zeile'
            }
        }
    }

    Context 'Array values' {
        It 'Should join array elements with comma' {
            InModuleScope 'ps-script-machine' {
                $result = ConvertTo-CleanText -Value @('a', 'b', 'c')
                $result | Should -Be 'a, b, c'
            }
        }
    }

    Context 'Non-string values' {
        It 'Should convert integer to string' {
            InModuleScope 'ps-script-machine' {
                $result = ConvertTo-CleanText -Value 42
                $result | Should -Be '42'
            }
        }
    }
}

Describe 'Export-ReportCsv' {
    Context 'CSV export' {
        BeforeAll {
            $script:testData = @(
                [PSCustomObject]@{ Name = 'item01'; Value = 'value01' }
                [PSCustomObject]@{ Name = 'item02'; Value = 'value02' }
            )
        }

        It 'Should export data to CSV with semicolon delimiter' {
            $csvPath = Join-Path $script:testOutputPath "test1.csv"
            InModuleScope 'ps-script-machine' -Parameters @{ Data = $script:testData; Path = $csvPath } {
                Export-ReportCsv -InputObject $Data -Path $Path
            }
            Test-Path $csvPath | Should -BeTrue
            $content = Get-Content -Path $csvPath -Raw
            $content | Should -Match ';'
        }

        It 'Should create file with correct content' {
            $csvPath = Join-Path $script:testOutputPath "test2.csv"
            InModuleScope 'ps-script-machine' -Parameters @{ Data = $script:testData; Path = $csvPath } {
                Export-ReportCsv -InputObject $Data -Path $Path
            }
            $content = Get-Content -Path $csvPath
            $content | Should -Contain '"Name";"Value"'
        }
    }

    Context 'Pipeline input' {
        It 'Should accept pipeline input' {
            $csvPath = Join-Path $script:testOutputPath "test3.csv"
            $data = [PSCustomObject]@{ Name = 'pipe01'; Value = 'pipeval' }
            InModuleScope 'ps-script-machine' -Parameters @{ Data = $data; Path = $csvPath } {
                $Data | Export-ReportCsv -Path $Path
            }
            Test-Path $csvPath | Should -BeTrue
        }
    }
}

Describe 'Export-ReportJson' {
    Context 'JSON export' {
        BeforeAll {
            $script:testData = @(
                [PSCustomObject]@{ Name = 'item01'; Value = 'value01' }
                [PSCustomObject]@{ Name = 'item02'; Value = 'value02' }
            )
        }

        It 'Should export data to JSON' {
            $jsonPath = Join-Path $script:testOutputPath "test1.json"
            InModuleScope 'ps-script-machine' -Parameters @{ Data = $script:testData; Path = $jsonPath } {
                Export-ReportJson -InputObject $Data -Path $Path
            }
            Test-Path $jsonPath | Should -BeTrue
            $content = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
            $content.Count | Should -Be 2
        }

        It 'Should write UTF-8 without BOM' {
            $jsonPath = Join-Path $script:testOutputPath "test2.json"
            InModuleScope 'ps-script-machine' -Parameters @{ Data = $script:testData; Path = $jsonPath } {
                Export-ReportJson -InputObject $Data -Path $Path
            }
            $bytes = [System.IO.File]::ReadAllBytes($jsonPath)
            $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            $hasBom | Should -BeFalse
        }
    }

    Context 'Pipeline input' {
        It 'Should accept pipeline input' {
            $jsonPath = Join-Path $script:testOutputPath "test3.json"
            $data = [PSCustomObject]@{ Name = 'pipe01'; Value = 'pipeval' }
            InModuleScope 'ps-script-machine' -Parameters @{ Data = $data; Path = $jsonPath } {
                $Data | Export-ReportJson -Path $Path
            }
            Test-Path $jsonPath | Should -BeTrue
        }
    }
}

Describe 'Write-ScriptLog' {
    Context 'Basic logging' {
        It 'Should write an INFO log entry without throwing' {
            InModuleScope 'ps-script-machine' {
                { Write-ScriptLog -Message 'Test info' -Level INFO -ConsoleOnly } | Should -Not -Throw
            }
        }

        It 'Should write a WARNING log entry without throwing' {
            InModuleScope 'ps-script-machine' {
                { Write-ScriptLog -Message 'Test warning' -Level WARNING -ConsoleOnly } | Should -Not -Throw
            }
        }

        It 'Should write an ERROR log entry without throwing' {
            InModuleScope 'ps-script-machine' {
                { Write-ScriptLog -Message 'Test error' -Level ERROR -ConsoleOnly } | Should -Not -Throw
            }
        }

        It 'Should write a DEBUG log entry without throwing' {
            InModuleScope 'ps-script-machine' {
                { Write-ScriptLog -Message 'Test debug' -Level DEBUG -ConsoleOnly } | Should -Not -Throw
            }
        }
    }

    Context 'File logging' {
        It 'Should write to a log file when LogPath is specified' {
            $logPath = Join-Path $script:testOutputPath "script.log"
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $logPath } {
                Write-ScriptLog -Message 'File test' -Level INFO -LogPath $LogPath
            }
            Test-Path $logPath | Should -BeTrue
            $content = Get-Content -Path $logPath -Raw
            $content | Should -Match 'File test'
        }

        It 'Should create log directory if it does not exist' {
            $deepLogPath = Join-Path $script:testOutputPath "deep\nested\script.log"
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $deepLogPath } {
                Write-ScriptLog -Message 'Deep path' -Level INFO -LogPath $LogPath
            }
            Test-Path $deepLogPath | Should -BeTrue
        }

        It 'Should not throw when log path is invalid' {
            InModuleScope 'ps-script-machine' {
                { Write-ScriptLog -Message 'Invalid path' -Level INFO -LogPath 'Z:\invalid\path\log.log' } | Should -Not -Throw
            }
        }
    }

    Context 'ConsoleOnly switch' {
        It 'Should not write to file when ConsoleOnly is set' {
            $logPath = Join-Path $script:testOutputPath "consoleonly.log"
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $logPath } {
                Write-ScriptLog -Message 'Console only' -Level INFO -LogPath $LogPath -ConsoleOnly
            }
            Test-Path $logPath | Should -BeFalse
        }
    }
}

Describe 'Export-ModuleData error handling' {
    Context 'Export errors' {
        It 'Should handle directory creation failure gracefully' {
            # Use an invalid path that cannot be created
            $result = Export-ModuleData -Data @([PSCustomObject]@{ Name = 'test' }) -OutputPath 'Z:\invalid\path\test' -Format CSV -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It 'Should continue with other formats when one fails' {
            $result = Export-ModuleData -Data @([PSCustomObject]@{ Name = 'test' }) -OutputPath "$script:testOutputPath\multi" -Format CSV, JSON -Force
            $result.Count | Should -Be 2
        }
    }
}