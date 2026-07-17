#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for the private Get-VIServerInventory and Save-VIServerInventory functions.
#>

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
}

Describe 'Get-VIServerInventory' {
    It 'returns an empty array when the file does not exist' {
        $result = InModuleScope 'ps-script-machine' -Parameters @{ Path = (Join-Path $TestDrive 'gibtsnicht.json') } {
            Get-VIServerInventory -Path $Path
        }
        @($result).Count | Should -Be 0
    }

    It 'reads entries with name, fqdn and description' {
        $file = Join-Path $TestDrive 'vcenters.json'
        Set-Content -LiteralPath $file -Value '[{"name":"Prod","fqdn":"vc01.test.local","description":"RZ1"}]' -Encoding utf8

        $result = InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            Get-VIServerInventory -Path $Path
        }
        @($result).Count | Should -Be 1
        $result[0].Name | Should -Be 'Prod'
        $result[0].Fqdn | Should -Be 'vc01.test.local'
        $result[0].Description | Should -Be 'RZ1'
        $result[0].PSObject.TypeNames | Should -Contain 'ps-script-machine.VIServerInventoryEntry'
    }

    It 'falls back to the fqdn when name is missing' {
        $file = Join-Path $TestDrive 'vcenters-noname.json'
        Set-Content -LiteralPath $file -Value '[{"fqdn":"vc02.test.local"}]' -Encoding utf8

        $result = InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            Get-VIServerInventory -Path $Path
        }
        $result[0].Name | Should -Be 'vc02.test.local'
    }

    It 'warns and returns an empty array for broken JSON' {
        $file = Join-Path $TestDrive 'kaputt.json'
        Set-Content -LiteralPath $file -Value '{ das ist kein json' -Encoding utf8

        $result = InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            Get-VIServerInventory -Path $Path -WarningAction SilentlyContinue
        }
        @($result).Count | Should -Be 0
    }

    It 'skips entries without fqdn' {
        $file = Join-Path $TestDrive 'vcenters-mixed.json'
        Set-Content -LiteralPath $file -Value '[{"name":"ohne"},{"fqdn":"vc03.test.local"}]' -Encoding utf8

        $result = InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            Get-VIServerInventory -Path $Path -WarningAction SilentlyContinue
        }
        @($result).Count | Should -Be 1
        $result[0].Fqdn | Should -Be 'vc03.test.local'
    }
}

Describe 'Save-VIServerInventory' {
    It 'creates the target directory and writes a JSON array' {
        $file = Join-Path $TestDrive 'neu\ordner\vcenters.json'
        InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            $entry = [PSCustomObject]@{
                PSTypeName  = 'ps-script-machine.VIServerInventoryEntry'
                Name        = 'Prod'
                Fqdn        = 'vc01.test.local'
                Description = 'RZ1'
            }
            Save-VIServerInventory -Path $Path -Inventory @($entry)
        }

        Test-Path -LiteralPath $file | Should -BeTrue
        $parsed = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        @($parsed).Count | Should -Be 1
        $parsed[0].fqdn | Should -Be 'vc01.test.local'
        $parsed[0].name | Should -Be 'Prod'
        $parsed[0].description | Should -Be 'RZ1'
    }

    It 'round-trips through Get-VIServerInventory' {
        $file = Join-Path $TestDrive 'roundtrip.json'
        $result = InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            $entries = @(
                [PSCustomObject]@{ PSTypeName = 'ps-script-machine.VIServerInventoryEntry'; Name = 'A'; Fqdn = 'a.test.local'; Description = '' }
                [PSCustomObject]@{ PSTypeName = 'ps-script-machine.VIServerInventoryEntry'; Name = 'B'; Fqdn = 'b.test.local'; Description = 'zwei' }
            )
            Save-VIServerInventory -Path $Path -Inventory $entries
            Get-VIServerInventory -Path $Path
        }
        @($result).Count | Should -Be 2
        $result[1].Fqdn | Should -Be 'b.test.local'
    }

    It 'writes an empty JSON array for an empty inventory' {
        $file = Join-Path $TestDrive 'leer.json'
        InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            Save-VIServerInventory -Path $Path -Inventory @()
        }
        $parsed = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        @($parsed).Count | Should -Be 0
    }
}
