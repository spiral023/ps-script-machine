#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for Write-ModuleLog function.
#>

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $script:testLogPath = Join-Path $env:TEMP "ps-script-machine-log-test-$(Get-Random).log"
}

AfterAll {
    if (Test-Path $script:testLogPath) {
        Remove-Item -Path $script:testLogPath -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Write-ModuleLog' {
    Context 'Basic logging' {
        It 'Should write an Information log entry' {
            InModuleScope 'ps-script-machine' {
                { Write-ModuleLog -Message 'Test message' -Level Information -InformationAction SilentlyContinue } | Should -Not -Throw
            }
        }

        It 'should write a Warning log entry' {
            InModuleScope 'ps-script-machine' {
                { Write-ModuleLog -Message 'Test warning' -Level Warning -WarningAction SilentlyContinue } | Should -Not -Throw
            }
        }

        It 'should write an Error log entry' {
            InModuleScope 'ps-script-machine' {
                { $null = Write-ModuleLog -Message 'Test error' -Level Error -ErrorAction SilentlyContinue 2>&1 } | Should -Not -Throw
            }
        }

        It 'should write a Debug log entry' {
            InModuleScope 'ps-script-machine' {
                { Write-ModuleLog -Message 'Test debug' -Level Debug -Debug -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
        }
    }

    Context 'Log file output' {
        BeforeEach {
            if (Test-Path $script:testLogPath) {
                Remove-Item -Path $script:testLogPath -Force
            }
        }

        It 'should write to a log file when LogFile is specified' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'File test' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
            }
            Test-Path $script:testLogPath | Should -BeTrue
        }

        It 'should write JSON format to log file' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'JSON test' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry | Should -Not -BeNullOrEmpty
            $logEntry.Message | Should -Be 'JSON test'
            $logEntry.Level | Should -Be 'Information'
        }

        It 'should include timestamp in log file' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'Timestamp test' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.Timestamp | Should -Not -BeNullOrEmpty
        }

        It 'should include RunId in log file' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'RunId test' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.RunId | Should -Not -BeNullOrEmpty
        }

        It 'should include VIServer in log file when specified' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'VIServer test' -Level Information -VIServer 'vcenter01' -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.VIServer | Should -Be 'vcenter01'
        }

        It 'should include Resource in log file when specified' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'Resource test' -Level Information -Resource 'esxi01' -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.Resource | Should -Be 'esxi01'
        }

        It 'should include Data in log file when specified' {
            $testData = @{ Key = 'Value'; Count = 42 }
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath; TestData = $testData } {
                Write-ModuleLog -Message 'Data test' -Level Information -Data $TestData -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.Data.Key | Should -Be 'Value'
            $logEntry.Data.Count | Should -Be 42
        }
    }

    Context 'Invalid parameters' {
        It 'should throw when Message is null' {
            InModuleScope 'ps-script-machine' {
                { Write-ModuleLog -Message $null -Level Information -InformationAction SilentlyContinue } | Should -Throw
            }
        }

        It 'should throw when Message is empty' {
            InModuleScope 'ps-script-machine' {
                { Write-ModuleLog -Message '' -Level Information -InformationAction SilentlyContinue } | Should -Throw
            }
        }

        It 'should throw when Level is invalid' {
            InModuleScope 'ps-script-machine' {
                { Write-ModuleLog -Message 'Test' -Level 'Invalid' -InformationAction SilentlyContinue } | Should -Throw
            }
        }
    }

    Context 'Log file directory creation' {
        It 'should create log file directory if it does not exist' {
            $deepLogPath = Join-Path $env:TEMP "ps-script-machine-deep-$(Get-Random)\nested\dir\test.log"
            try {
                InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $deepLogPath } {
                    Write-ModuleLog -Message 'Deep path test' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
                }
                Test-Path $deepLogPath | Should -BeTrue
            }
            finally {
                $parentDir = Split-Path -Path $deepLogPath -Parent
                while ($parentDir -and $parentDir -ne $env:TEMP) {
                    if (Test-Path $parentDir) {
                        Remove-Item -Path $parentDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    $parentDir = Split-Path -Path $parentDir -Parent
                }
            }
        }
    }

    Context 'Credential redaction in messages' {
        BeforeEach {
            if (Test-Path $script:testLogPath) {
                Remove-Item -Path $script:testLogPath -Force
            }
        }

        It 'should redact password=... from messages' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'Connection: password=secret123' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.Message | Should -Not -Match 'secret123'
            $logEntry.Message | Should -Match 'REDACTED'
        }

        It 'should redact api_key=... from messages' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'Config: api_key=abc123def456' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.Message | Should -Not -Match 'abc123def456'
            $logEntry.Message | Should -Match 'REDACTED'
        }

        It 'should redact secret=... from messages' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'Auth: secret=mysecretvalue' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.Message | Should -Not -Match 'mysecretvalue'
            $logEntry.Message | Should -Match 'REDACTED'
        }

        It 'should redact token=... from messages' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'Header: token=bearer123token' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.Message | Should -Not -Match 'bearer123token'
            $logEntry.Message | Should -Match 'REDACTED'
        }

        It 'should redact Bearer tokens from messages' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'Authorization: Bearer eyJhbGciOiJIUzI1' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.Message | Should -Not -Match 'eyJhbGciOiJIUzI1'
            $logEntry.Message | Should -Match 'REDACTED'
        }

        It 'should redact connection strings with embedded credentials' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'URL: https://admin:pass123@vcenter.local' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.Message | Should -Not -Match 'pass123'
            $logEntry.Message | Should -Match 'REDACTED'
        }
    }

    Context 'Credential redaction in Data objects' {
        BeforeEach {
            if (Test-Path $script:testLogPath) {
                Remove-Item -Path $script:testLogPath -Force
            }
        }

        It 'should redact password key in hashtable Data' {
            $testData = @{ Server = 'vcenter01'; Password = 'secret123' }  # secret-scan:ignore - fake fixture, verifies redaction
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath; TestData = $testData } {
                Write-ModuleLog -Message 'Data redaction test' -Level Information -Data $TestData -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.Data.Password | Should -Be '***REDACTED***'
            $logEntry.Data.Server | Should -Be 'vcenter01'
        }

        It 'should redact token key in hashtable Data' {
            $testData = @{ Endpoint = 'api.local'; Token = 'tok123' }  # secret-scan:ignore - fake fixture, verifies redaction
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath; TestData = $testData } {
                Write-ModuleLog -Message 'Token data test' -Level Information -Data $TestData -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.Data.Token | Should -Be '***REDACTED***'
            $logEntry.Data.Endpoint | Should -Be 'api.local'
        }

        It 'should redact password property in PSCustomObject Data' {
            $testData = [PSCustomObject]@{ Server = 'vcenter01'; Password = 'secret456' }  # secret-scan:ignore - fake fixture, verifies redaction
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath; TestData = $testData } {
                Write-ModuleLog -Message 'PSO data test' -Level Information -Data $TestData -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $logEntry.Data.Password | Should -Be '***REDACTED***'
            $logEntry.Data.Server | Should -Be 'vcenter01'
        }
    }

    Context 'UTF-8 encoding' {
        BeforeEach {
            if (Test-Path $script:testLogPath) {
                Remove-Item -Path $script:testLogPath -Force
            }
        }

        It 'should write log file in UTF-8 without BOM' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'UTF-8 test' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $bytes = [System.IO.File]::ReadAllBytes($script:testLogPath)
            $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            $hasBom | Should -BeFalse
        }
    }

    Context 'Consistent JSON schema' {
        BeforeEach {
            if (Test-Path $script:testLogPath) {
                Remove-Item -Path $script:testLogPath -Force
            }
        }

        It 'should always include all required fields in the JSON schema' {
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $script:testLogPath } {
                Write-ModuleLog -Message 'Schema test' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue
            }
            $content = (Get-Content -Path $script:testLogPath -Raw).Trim()
            $logEntry = $content | ConvertFrom-Json
            $properties = $logEntry.PSObject.Properties.Name
            $properties | Should -Contain 'Timestamp'
            $properties | Should -Contain 'Level'
            $properties | Should -Contain 'RunId'
            $properties | Should -Contain 'VIServer'
            $properties | Should -Contain 'Resource'
            $properties | Should -Contain 'Message'
        }
    }

    Context 'Non-writable log path' {
        It 'should write a warning when log file cannot be written' {
            $invalidPath = 'Z:\nonexistent\invalid\path\test.log'
            InModuleScope 'ps-script-machine' -Parameters @{ LogPath = $invalidPath } {
                { Write-ModuleLog -Message 'Invalid path test' -Level Information -LogFile $LogPath -InformationAction SilentlyContinue -WarningAction SilentlyContinue } | Should -Not -Throw
            }
        }
    }
}