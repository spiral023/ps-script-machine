#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for Get-VMHostNetworkInfo function.
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

    $script:mockVMHost = [PSCustomObject]@{
        Name            = 'esxi01.test.local'
        Id              = 'host-123'
        ConnectionState = 'Connected'
        ExtensionData   = [PSCustomObject]@{
            ConfigManager = [PSCustomObject]@{
                NetworkSystem = [PSCustomObject]@{
                    Value = 'network-system-123'
                }
            }
        }
    }

    $script:mockVMHostDisconnected = [PSCustomObject]@{
        Name            = 'esxi02.test.local'
        Id              = 'host-456'
        ConnectionState = 'Disconnected'
        ExtensionData   = [PSCustomObject]@{
            ConfigManager = [PSCustomObject]@{
                NetworkSystem = [PSCustomObject]@{
                    Value = 'network-system-456'
                }
            }
        }
    }

    $script:mockCluster = [PSCustomObject]@{
        Name = 'cluster01'
        ExtensionData = [PSCustomObject]@{
            Host = @([PSCustomObject]@{ Value = 'host-123' })
        }
    }

    $script:mockNetAdapter = [PSCustomObject]@{
        Name           = 'vmnic0'
        Mac            = '00:11:22:33:44:55'
        BitRatePerSec  = 1000
    }

    $script:mockCdpHint = [PSCustomObject]@{
        Device = 'vmnic0'
        ConnectedSwitchPort = [PSCustomObject]@{
            DevId            = 'switch01'
            PortId           = 'GigabitEthernet1/0/1'
            MgmtAddr         = '192.168.1.1'
            Address          = '192.168.1.1'
            HardwarePlatform = 'cisco'
            SoftwareVersion  = '15.0'
            Vlan             = '100'
            Mtu              = '1500'
        }
    }

    $script:mockNetworkSystem = [PSCustomObject]@{}
    $script:mockNetworkSystem | Add-Member -MemberType NoteProperty -Name '_hints' -Value @($script:mockCdpHint)
    $script:mockNetworkSystem | Add-Member -MemberType ScriptMethod -Name 'QueryNetworkHint' -Value { return $this._hints }

    $script:testCredential = [System.Management.Automation.PSCredential]::new(
        'testuser',
        (ConvertTo-SecureString 'testpass' -AsPlainText -Force)
    )
}

Describe 'Get-VMHostNetworkInfo' {
    Context 'Regular success cases' {
        BeforeAll {
            Mock Connect-VIServerSession { return $script:mockVIServer } -ModuleName 'ps-script-machine'
            Mock Disconnect-VIServerSession { } -ModuleName 'ps-script-machine'
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-Cluster { return @($script:mockCluster) } -ModuleName 'ps-script-machine'
            Mock Get-View { return $script:mockNetworkSystem } -ModuleName 'ps-script-machine'
            Mock Get-VMHostNetworkAdapter { return @($script:mockNetAdapter) } -ModuleName 'ps-script-machine'
        }

        It 'Should return results for a valid server' {
            $result = Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 1
        }

        It 'should include vCenter in the result' {
            $result = @(Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential)
            $result[0].vCenter | Should -Be 'vcenter.test.local'
        }

        It 'should include VMHost name in the result' {
            $result = @(Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential)
            $result[0].VMHost | Should -Be 'esxi01.test.local'
        }

        It 'should include adapter name in the result' {
            $result = @(Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential)
            $result[0].PhysicalAdapter | Should -Be 'vmnic0'
        }

        It 'should include CDP device ID in the result' {
            $result = @(Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential)
            $result[0].CDPDeviceID | Should -Be 'switch01'
        }

        It 'should include CDP available flag' {
            $result = @(Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential)
            $result[0].CDPAvailable | Should -BeTrue
        }

        It 'should include collection time' {
            $result = @(Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential)
            $result[0].CollectionTime | Should -Not -BeNullOrEmpty
        }

        It 'should disconnect the session in finally' {
            Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential
            Should -Invoke Disconnect-VIServerSession -ModuleName 'ps-script-machine' -Times 1
        }
    }

    Context 'Invalid parameters' {
        It 'should throw when Server is null' {
            { Get-VMHostNetworkInfo -Server $null -Credential $script:testCredential } | Should -Throw
        }

        It 'should throw when Server is empty' {
            { Get-VMHostNetworkInfo -Server '' -Credential $script:testCredential } | Should -Throw
        }
    }

    Context 'No hosts found' {
        BeforeAll {
            Mock Connect-VIServerSession { return $script:mockVIServer } -ModuleName 'ps-script-machine'
            Mock Disconnect-VIServerSession { } -ModuleName 'ps-script-machine'
            Mock Get-VMHost { return @() } -ModuleName 'ps-script-machine'
            Mock Get-Cluster { return @() } -ModuleName 'ps-script-machine'
        }

        It 'should throw when no hosts found' {
            { Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Disconnected host' {
        BeforeAll {
            Mock Connect-VIServerSession { return $script:mockVIServer } -ModuleName 'ps-script-machine'
            Mock Disconnect-VIServerSession { } -ModuleName 'ps-script-machine'
            Mock Get-VMHost { return @($script:mockVMHostDisconnected) } -ModuleName 'ps-script-machine'
            Mock Get-Cluster { return @() } -ModuleName 'ps-script-machine'
            Mock Get-View { return $script:mockNetworkSystem } -ModuleName 'ps-script-machine'
            Mock Get-VMHostNetworkAdapter { return @($script:mockNetAdapter) } -ModuleName 'ps-script-machine'
        }

        It 'should handle disconnected host gracefully' {
            $result = @(Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential)
            $result | Should -Not -BeNullOrEmpty
            $result[0].HostConnectionState | Should -Be 'Disconnected'
            $result[0].QueryStatus | Should -Be 'Übersprungen'
            $result[0].CDPAvailable | Should -BeFalse
        }
    }

    Context 'Partial failure - Get-View fails' {
        BeforeAll {
            Mock Connect-VIServerSession { return $script:mockVIServer } -ModuleName 'ps-script-machine'
            Mock Disconnect-VIServerSession { } -ModuleName 'ps-script-machine'
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-Cluster { return @($script:mockCluster) } -ModuleName 'ps-script-machine'
            Mock Get-View { throw 'Failed to get view' } -ModuleName 'ps-script-machine'
            Mock Get-VMHostNetworkAdapter { return @($script:mockNetAdapter) } -ModuleName 'ps-script-machine'
        }

        It 'should handle partial failure gracefully' {
            $result = @(Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential)
            $result | Should -Not -BeNullOrEmpty
            $result[0].QueryStatus | Should -Be 'Fehler'
            $result[0].ErrorMessage | Should -Not -BeNullOrEmpty
        }
    }

    Context 'No CDP data' {
        BeforeAll {
            $script:mockNetworkSystemNoCdp = [PSCustomObject]@{}
            $script:mockNetworkSystemNoCdp | Add-Member -MemberType NoteProperty -Name '_hints' -Value @()
            $script:mockNetworkSystemNoCdp | Add-Member -MemberType ScriptMethod -Name 'QueryNetworkHint' -Value { return $this._hints }

            Mock Connect-VIServerSession { return $script:mockVIServer } -ModuleName 'ps-script-machine'
            Mock Disconnect-VIServerSession { } -ModuleName 'ps-script-machine'
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-Cluster { return @($script:mockCluster) } -ModuleName 'ps-script-machine'
            Mock Get-View { return $script:mockNetworkSystemNoCdp } -ModuleName 'ps-script-machine'
            Mock Get-VMHostNetworkAdapter { return @($script:mockNetAdapter) } -ModuleName 'ps-script-machine'
        }

        It 'should handle missing CDP data gracefully' {
            $result = @(Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential)
            $result | Should -Not -BeNullOrEmpty
            $result[0].CDPAvailable | Should -BeFalse
            $result[0].QueryStatus | Should -Be 'Keine CDP-Daten'
        }
    }

    Context 'Cluster filter' {
        BeforeAll {
            Mock Connect-VIServerSession { return $script:mockVIServer } -ModuleName 'ps-script-machine'
            Mock Disconnect-VIServerSession { } -ModuleName 'ps-script-machine'
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-Cluster { return @($script:mockCluster) } -ModuleName 'ps-script-machine'
            Mock Get-View { return $script:mockNetworkSystem } -ModuleName 'ps-script-machine'
            Mock Get-VMHostNetworkAdapter { return @($script:mockNetAdapter) } -ModuleName 'ps-script-machine'
        }

        It 'should pass cluster filter to Get-Cluster' {
            $result = @(Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential -Cluster 'cluster01')
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Get-Cluster -ModuleName 'ps-script-machine' -Times 1
        }
    }

    Context 'VMHost filter' {
        BeforeAll {
            Mock Connect-VIServerSession { return $script:mockVIServer } -ModuleName 'ps-script-machine'
            Mock Disconnect-VIServerSession { } -ModuleName 'ps-script-machine'
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-Cluster { return @($script:mockCluster) } -ModuleName 'ps-script-machine'
            Mock Get-View { return $script:mockNetworkSystem } -ModuleName 'ps-script-machine'
            Mock Get-VMHostNetworkAdapter { return @($script:mockNetAdapter) } -ModuleName 'ps-script-machine'
        }

        It 'should pass VMHost filter to Get-VMHost' {
            $result = @(Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential -VMHost 'esxi01.test.local')
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Get-VMHost -ModuleName 'ps-script-machine' -Times 1
        }
    }

    Context 'Connection failure' {
        BeforeAll {
            Mock Connect-VIServerSession { throw 'Connection failed' } -ModuleName 'ps-script-machine'
            Mock Disconnect-VIServerSession { } -ModuleName 'ps-script-machine'
        }

        It 'should throw on connection failure' {
            { Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Correct result object structure' {
        BeforeAll {
            Mock Connect-VIServerSession { return $script:mockVIServer } -ModuleName 'ps-script-machine'
            Mock Disconnect-VIServerSession { } -ModuleName 'ps-script-machine'
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-Cluster { return @($script:mockCluster) } -ModuleName 'ps-script-machine'
            Mock Get-View { return $script:mockNetworkSystem } -ModuleName 'ps-script-machine'
            Mock Get-VMHostNetworkAdapter { return @($script:mockNetAdapter) } -ModuleName 'ps-script-machine'
        }

        It 'should return objects with expected properties' {
            $result = @(Get-VMHostNetworkInfo -Server 'vcenter.test.local' -Credential $script:testCredential)
            $properties = $result[0].PSObject.Properties.Name
            $properties | Should -Contain 'vCenter'
            $properties | Should -Contain 'Cluster'
            $properties | Should -Contain 'VMHost'
            $properties | Should -Contain 'HostConnectionState'
            $properties | Should -Contain 'PhysicalAdapter'
            $properties | Should -Contain 'LinkStatus'
            $properties | Should -Contain 'MACAddress'
            $properties | Should -Contain 'CDPDeviceID'
            $properties | Should -Contain 'CDPPortID'
            $properties | Should -Contain 'CDPAvailable'
            $properties | Should -Contain 'QueryStatus'
            $properties | Should -Contain 'CollectionTime'
        }
    }
}