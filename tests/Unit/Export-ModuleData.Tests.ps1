#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for Export-ModuleData function.
#>

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $script:mockData = @(
        [PSCustomObject]@{
            Name  = 'item01'
            Value = 'value01'
        },
        [PSCustomObject]@{
            Name  = 'item02'
            Value = 'value02'
        }
    )

    $script:testOutputPath = Join-Path $env:TEMP "ps-script-machine-test-$(Get-Random)"
}

AfterAll {
    if (Test-Path $script:testOutputPath) {
        Remove-Item -Path $script:testOutputPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Export-ModuleData' {
    Context 'CSV export' {
        It 'Should export data to CSV' {
            $result = Export-ModuleData -Data $script:mockData -OutputPath "$script:testOutputPath\test" -Format CSV -Force
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match '\.csv$'
            Test-Path $result | Should -BeTrue
        }

        It 'Should create CSV file with correct content' {
            $result = Export-ModuleData -Data $script:mockData -OutputPath "$script:testOutputPath\test2" -Format CSV -Force
            $csvContent = Get-Content -Path $result
            $csvContent | Should -Contain '"Name","Value"'
        }
    }

    Context 'JSON export' {
        It 'Should export data to JSON' {
            $result = Export-ModuleData -Data $script:mockData -OutputPath "$script:testOutputPath\test3" -Format JSON -Force
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match '\.json$'
            Test-Path $result | Should -BeTrue
        }

        It 'Should create JSON file with correct content' {
            $result = Export-ModuleData -Data $script:mockData -OutputPath "$script:testOutputPath\test4" -Format JSON -Force
            $jsonContent = Get-Content -Path $result -Raw | ConvertFrom-Json
            $jsonContent.Count | Should -Be 2
            $jsonContent[0].Name | Should -Be 'item01'
        }
    }

    Context 'Multiple formats' {
        It 'Should export to both CSV and JSON' {
            $result = Export-ModuleData -Data $script:mockData -OutputPath "$script:testOutputPath\test5" -Format CSV, JSON -Force
            $result.Count | Should -Be 2
            $result | Should -Contain "$script:testOutputPath\test5.csv"
            $result | Should -Contain "$script:testOutputPath\test5.json"
        }
    }

    Context 'Directory creation' {
        It 'Should create output directory if it does not exist' {
            $deepPath = "$script:testOutputPath\deep\nested\path\test6"
            $result = Export-ModuleData -Data $script:mockData -OutputPath $deepPath -Format JSON -Force
            $result | Should -Not -BeNullOrEmpty
            Test-Path $result | Should -BeTrue
        }
    }

    Context 'Invalid parameters' {
        It 'Should throw when OutputPath is null' {
            { Export-ModuleData -Data $script:mockData -OutputPath $null -Format CSV } | Should -Throw
        }

        It 'Should throw when OutputPath is empty' {
            { Export-ModuleData -Data $script:mockData -OutputPath '' -Format CSV } | Should -Throw
        }

        It 'Should throw when Format is invalid' {
            { Export-ModuleData -Data $script:mockData -OutputPath 'test' -Format 'XML' } | Should -Throw
        }
    }

    Context 'Empty data' {
        It 'Should return null and write warning when data is empty' {
            $result = Export-ModuleData -Data @() -OutputPath "$script:testOutputPath\empty" -Format CSV -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Existing file without Force' {
        BeforeAll {
            $existingPath = "$script:testOutputPath\existing"
            Export-ModuleData -Data $script:mockData -OutputPath $existingPath -Format CSV -Force | Out-Null
        }

        It 'Should not overwrite existing file without -Force' {
            $result = Export-ModuleData -Data $script:mockData -OutputPath $existingPath -Format CSV -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }
}