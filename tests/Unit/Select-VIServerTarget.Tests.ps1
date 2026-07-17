#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for the public Select-VIServerTarget function.
#>

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $script:inventoryJson = '[' +
    '{"name":"Prod RZ1","fqdn":"vc01.test.local","description":"RZ1"},' +
    '{"name":"Prod RZ2","fqdn":"vc02.test.local","description":"RZ2"},' +
    '{"name":"Test","fqdn":"vc-test.test.local","description":""}' +
    ']'
}

Describe 'Select-VIServerTarget' {
    BeforeAll {
        Mock Write-Host { } -ModuleName 'ps-script-machine'
    }

    BeforeEach {
        $script:inventoryPath = Join-Path $TestDrive "vcenters-$([guid]::NewGuid()).json"
        Set-Content -LiteralPath $script:inventoryPath -Value $script:inventoryJson -Encoding utf8
    }

    AfterEach {
        Remove-Variable -Name 'PsmTestAnswers' -Scope Global -ErrorAction SilentlyContinue
    }

    It 'returns the FQDNs for a comma-separated number selection' {
        Mock Read-Host { '1,3' } -ModuleName 'ps-script-machine'
        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        $result | Should -Be @('vc01.test.local', 'vc-test.test.local')
    }

    It 'returns all inventory FQDNs for input "alle"' {
        Mock Read-Host { 'alle' } -ModuleName 'ps-script-machine'
        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        $result | Should -Be @('vc01.test.local', 'vc02.test.local', 'vc-test.test.local')
    }

    It 're-prompts when a number is out of range' {
        $global:PsmTestAnswers = [System.Collections.Queue]::new()
        $global:PsmTestAnswers.Enqueue('7')
        $global:PsmTestAnswers.Enqueue('2')
        Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        $result | Should -Be @('vc02.test.local')
    }

    It 'accepts a new FQDN and saves it when confirmed' {
        $global:PsmTestAnswers = [System.Collections.Queue]::new()
        $global:PsmTestAnswers.Enqueue('vc-neu.test.local')
        $global:PsmTestAnswers.Enqueue('J')
        Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        $result | Should -Be @('vc-neu.test.local')

        $saved = Get-Content -LiteralPath $script:inventoryPath -Raw | ConvertFrom-Json
        @($saved).Count | Should -Be 4
        $saved.fqdn | Should -Contain 'vc-neu.test.local'
    }

    It 'accepts a new FQDN without saving when declined' {
        $global:PsmTestAnswers = [System.Collections.Queue]::new()
        $global:PsmTestAnswers.Enqueue('vc-fluechtig.test.local')
        $global:PsmTestAnswers.Enqueue('n')
        Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        $result | Should -Be @('vc-fluechtig.test.local')

        $saved = Get-Content -LiteralPath $script:inventoryPath -Raw | ConvertFrom-Json
        @($saved).Count | Should -Be 3
    }

    It 'does not ask to save when the typed FQDN is already in the inventory' {
        Mock Read-Host { 'vc01.test.local' } -ModuleName 'ps-script-machine'
        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        $result | Should -Be @('vc01.test.local')
        Should -Invoke Read-Host -ModuleName 'ps-script-machine' -Times 1 -Exactly
    }

    It 'works with an empty inventory (missing file) via free input' {
        $emptyPath = Join-Path $TestDrive 'gibtsnicht.json'
        $global:PsmTestAnswers = [System.Collections.Queue]::new()
        $global:PsmTestAnswers.Enqueue('vc-solo.test.local')
        $global:PsmTestAnswers.Enqueue('J')
        Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

        $result = Select-VIServerTarget -InventoryPath $emptyPath
        $result | Should -Be @('vc-solo.test.local')
        Test-Path -LiteralPath $emptyPath | Should -BeTrue
    }

    It 'deduplicates the selection' {
        Mock Read-Host { '1,1,1' } -ModuleName 'ps-script-machine'
        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        @($result).Count | Should -Be 1
    }

    It 're-prompts for "alle" when the inventory is empty' {
        $emptyPath = Join-Path $TestDrive 'leer2.json'
        $global:PsmTestAnswers = [System.Collections.Queue]::new()
        $global:PsmTestAnswers.Enqueue('alle')
        $global:PsmTestAnswers.Enqueue('vc-x.test.local')
        $global:PsmTestAnswers.Enqueue('n')
        Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

        $result = Select-VIServerTarget -InventoryPath $emptyPath
        $result | Should -Be @('vc-x.test.local')
    }
}
