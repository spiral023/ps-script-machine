#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for Get-CdpNetworkInfo function.
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

    $script:mockVIServer2 = [PSCustomObject]@{
        Name      = 'vcenter2.test.local'
        SessionId = 'test-session-id-2'
        Port      = 443
        Protocol  = 'https'
    }

    $script:mockVMHost = [PSCustomObject]@{
        Name    = 'esxi01.test.local'
        State   = 'Connected'
        Parent  = 'cluster01'
    }

    $script:mockVMHost2 = [PSCustomObject]@{
        Name    = 'esxi02.test.local'
        State   = 'Connected'
        Parent  = 'cluster01'
    }

    $script:mockNetAdapter = [PSCustomObject]@{
        Name        = 'vmnic0'
        Driver      = 'nmlx5_core'
        LinkStatus  = 'Up'
    }

    $script:mockCdpInfo = [PSCustomObject]@{
        Device          = 'switch01'
        Address         = '192.168.1.1'
        Port            = 'GigabitEthernet1/0/1'
        SystemName      = 'switch01.example.com'
        SystemOID       = '1.3.6.1.4.1.9.1'
        Version         = '2'
        Timeout         = '180'
        Mtu             = '1500'
        Vlan            = '100'
        VtpMgmtDomain   = 'mgmt'
        Duplex          = 'full'
        ConfDuplex      = 'full'
        Speed           = '1000'
        ConfSpeed       = '1000'
    }

    function New-MockEsxCli {
        param([object]$CdpInfo, [object[]]$Adapters)

        $cdpObj = [PSCustomObject]@{}
        $cdpObj | Add-Member -MemberType NoteProperty -Name '_cdpInfo' -Value $CdpInfo
        $cdpObj | Add-Member -MemberType ScriptMethod -Name 'get' -Value {
            param($name)
            if ($null -ne $this._cdpInfo) { return @($this._cdpInfo) }
            return @()
        }

        $nicObj = [PSCustomObject]@{}
        $nicObj | Add-Member -MemberType NoteProperty -Name '_adapters' -Value $Adapters
        $nicObj | Add-Member -MemberType ScriptMethod -Name 'list' -Value { return $this._adapters }
        $nicObj | Add-Member -MemberType NoteProperty -Name 'cdp' -Value $cdpObj

        $networkObj = [PSCustomObject]@{ nic = $nicObj }
        return [PSCustomObject]@{ network = $networkObj }
    }

    $script:mockEsxCli = New-MockEsxCli -CdpInfo $script:mockCdpInfo -Adapters @($script:mockNetAdapter)
    $script:mockEsxCliNoCdp = New-MockEsxCli -CdpInfo $null -Adapters @($script:mockNetAdapter)
}

Describe 'Get-CdpNetworkInfo' {
    Context 'Regular success cases' {
        BeforeAll {
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-EsxCli { return $script:mockEsxCli } -ModuleName 'ps-script-machine'
        }

        It 'Should return results for a valid VIServer' {
            $result = Get-CdpNetworkInfo -VIServer $script:mockVIServer
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 1
        }

        It 'Should include VIServer in the result' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer)
            $result[0].VIServer | Should -Be 'vcenter.test.local'
        }

        It 'Should include VMHost name in the result' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer)
            $result[0].VMHost | Should -Be 'esxi01.test.local'
        }

        It 'Should include adapter name in the result' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer)
            $result[0].AdapterName | Should -Be 'vmnic0'
        }

        It 'Should include CDP device in the result' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer)
            $result[0].CDPDevice | Should -Be 'switch01'
        }

        It 'Should include a timestamp' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer)
            $result[0].Timestamp | Should -Not -BeNullOrEmpty
        }

        It 'Should include a RunId' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer)
            $result[0].RunId | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Invalid parameters' {
        It 'Should throw when VIServer is null' {
            { Get-CdpNetworkInfo -VIServer $null } | Should -Throw
        }

        It 'Should throw when VIServer is empty array' {
            { Get-CdpNetworkInfo -VIServer @() } | Should -Throw
        }
    }

    Context 'Empty results - no hosts found' {
        BeforeAll {
            Mock Get-VMHost { return @() } -ModuleName 'ps-script-machine'
        }

        It 'Should return null when no hosts found' {
            $result = Get-CdpNetworkInfo -VIServer $script:mockVIServer -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Unreachable vCenter' {
        BeforeAll {
            Mock Get-VMHost { throw [System.Net.Sockets.SocketException]::new('No connection') } -ModuleName 'ps-script-machine'
        }

        It 'Should handle unreachable vCenter gracefully' {
            { Get-CdpNetworkInfo -VIServer $script:mockVIServer -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Multiple vCenter connections' {
        BeforeAll {
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-EsxCli { return $script:mockEsxCli } -ModuleName 'ps-script-machine'
        }

        It 'Should handle multiple VIServer connections' {
            $result = Get-CdpNetworkInfo -VIServer @($script:mockVIServer, $script:mockVIServer2)
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 2
        }
    }

    Context 'Missing CDP data' {
        BeforeAll {
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-EsxCli { return $script:mockEsxCliNoCdp } -ModuleName 'ps-script-machine'
        }

        It 'Should handle missing CDP data gracefully' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer -WarningAction SilentlyContinue)
            $result | Should -Not -BeNullOrEmpty
            $result[0].CDPDevice | Should -BeNullOrEmpty
        }
    }

    Context 'Partial failures - one host fails' {
        BeforeAll {
            Mock Get-VMHost { return @($script:mockVMHost, $script:mockVMHost2) } -ModuleName 'ps-script-machine'
            Mock Get-EsxCli {
                if ($VMHost.Name -eq 'esxi02.test.local') { throw 'Failed' }
                return $script:mockEsxCli
            } -ModuleName 'ps-script-machine'
        }

        It 'Should continue processing other hosts on partial failure' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer -WarningAction SilentlyContinue)
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].VMHost | Should -Be 'esxi01.test.local'
        }
    }

    Context 'Correct result object structure' {
        BeforeAll {
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-EsxCli { return $script:mockEsxCli } -ModuleName 'ps-script-machine'
        }

        It 'Should return objects with the correct PSTypeName' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer)
            $result[0].PSTypeNames[0] | Should -Be 'ps-script-machine.CdpNetworkInfo'
        }

        It 'Should return objects with expected properties' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer)
            $properties = $result[0].PSObject.Properties.Name
            $properties | Should -Contain 'VIServer'
            $properties | Should -Contain 'VMHost'
            $properties | Should -Contain 'AdapterName'
            $properties | Should -Contain 'CDPDevice'
            $properties | Should -Contain 'Timestamp'
            $properties | Should -Contain 'RunId'
        }
    }

    Context 'IncludeDetail switch' {
        BeforeAll {
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-EsxCli { return $script:mockEsxCli } -ModuleName 'ps-script-machine'
        }

        It 'Should include Detail property when IncludeDetail is set' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer -IncludeDetail)
            $result[0].PSObject.Properties.Name | Should -Contain 'Detail'
        }

        It 'Should not include Detail property when IncludeDetail is not set' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer)
            $result[0].PSObject.Properties.Name | Should -Not -Contain 'Detail'
        }
    }

    Context 'VMHost filter' {
        BeforeAll {
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-EsxCli { return $script:mockEsxCli } -ModuleName 'ps-script-machine'
        }

        It 'Should pass VMHost filter to Get-VMHost' {
            $result = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer -VMHost 'esxi01.test.local')
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Get-VMHost -ModuleName 'ps-script-machine' -Times 1
        }
    }
}