#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for Get-VMHostNetworkInfo.
#>
BeforeAll {
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
        Name          = 'cluster01'
        ExtensionData = [PSCustomObject]@{
            Host = @([PSCustomObject]@{ Value = 'host-123' })
        }
    }

    $script:mockNetAdapter = [PSCustomObject]@{
        Name          = 'vmnic0'
        Mac           = '00:11:22:33:44:55'
        BitRatePerSec = 1000
    }

    $script:mockCdpHint = [PSCustomObject]@{
        Device              = 'vmnic0'
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

    $script:mockNetworkSystem = [PSCustomObject]@{
        _hints = @($script:mockCdpHint)
    }
    $script:mockNetworkSystem | Add-Member -MemberType ScriptMethod -Name 'QueryNetworkHint' -Value { $this._hints }
}

Describe 'Get-VMHostNetworkInfo' {
    BeforeEach {
        Mock Connect-VIServerSession { $script:mockVIServer } -ModuleName 'ps-script-machine'
        Mock Disconnect-VIServerSession { } -ModuleName 'ps-script-machine'
        Mock Write-ModuleLog { } -ModuleName 'ps-script-machine'
        Mock Get-VMHost { @($script:mockVMHost) } -ModuleName 'ps-script-machine'
        Mock Get-Cluster { @($script:mockCluster) } -ModuleName 'ps-script-machine'
        Mock Get-View { $script:mockNetworkSystem } -ModuleName 'ps-script-machine'
        Mock Get-VMHostNetworkAdapter { @($script:mockNetAdapter) } -ModuleName 'ps-script-machine'
    }

    It 'accepts an externally connected VIServer and does not manage its session' {
        $result = @(Get-VMHostNetworkInfo -VIServer $script:mockVIServer)

        $result | Should -HaveCount 1
        Should -Invoke Connect-VIServerSession -ModuleName 'ps-script-machine' -Times 0 -Exactly
        Should -Invoke Disconnect-VIServerSession -ModuleName 'ps-script-machine' -Times 0 -Exactly
    }

    It 'returns the standard result identity and audit fields' {
        $result = @(Get-VMHostNetworkInfo -VIServer $script:mockVIServer)[0]

        $result.PSTypeNames[0] | Should -Be 'ps-script-machine.VMHostNetworkInfo'
        $result.VIServer | Should -Be 'vcenter.test.local'
        $result.Timestamp | Should -Not -BeNullOrEmpty
        $result.RunId | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Not -Contain 'vCenter'
        $result.PSObject.Properties.Name | Should -Not -Contain 'CollectionTime'
    }

    It 'passes the supplied session explicitly to every PowerCLI query' {
        $null = Get-VMHostNetworkInfo -VIServer $script:mockVIServer -Cluster 'cluster01'

        Should -Invoke Get-Cluster -ModuleName 'ps-script-machine' -ParameterFilter { $Server -eq $script:mockVIServer } -Times 2 -Exactly
        Should -Invoke Get-VMHost -ModuleName 'ps-script-machine' -ParameterFilter { $Server -eq $script:mockVIServer } -Times 1 -Exactly
        Should -Invoke Get-View -ModuleName 'ps-script-machine' -ParameterFilter { $Server -eq $script:mockVIServer } -Times 1 -Exactly
        Should -Invoke Get-VMHostNetworkAdapter -ModuleName 'ps-script-machine' -ParameterFilter { $Server -eq $script:mockVIServer } -Times 1 -Exactly
    }

    It 'processes each supplied VIServer separately' {
        $result = @(Get-VMHostNetworkInfo -VIServer @($script:mockVIServer, $script:mockVIServer2))

        $result | Should -HaveCount 2
        $result.VIServer | Should -Be @('vcenter.test.local', 'vcenter2.test.local')
        Should -Invoke Get-VMHost -ModuleName 'ps-script-machine' -Times 2 -Exactly
    }

    It 'returns a structured skipped result for a disconnected host' {
        Mock Get-VMHost { @($script:mockVMHostDisconnected) } -ModuleName 'ps-script-machine'

        $result = @(Get-VMHostNetworkInfo -VIServer $script:mockVIServer)[0]

        $result.HostConnectionState | Should -Be 'Disconnected'
        $result.QueryStatus | Should -Be 'Übersprungen'
        $result.CDPAvailable | Should -BeFalse
        $result.PSTypeNames[0] | Should -Be 'ps-script-machine.VMHostNetworkInfo'
    }

    It 'continues with a structured failure result when an individual host query fails' {
        Mock Get-View { throw 'Failed to get view' } -ModuleName 'ps-script-machine'

        $result = @(Get-VMHostNetworkInfo -VIServer $script:mockVIServer)[0]

        $result.QueryStatus | Should -Be 'Fehler'
        $result.ErrorMessage | Should -Be 'Failed to get view'
        $result.PSTypeNames[0] | Should -Be 'ps-script-machine.VMHostNetworkInfo'
    }

    It 'rejects a missing VIServer' {
        { Get-VMHostNetworkInfo -VIServer $null } | Should -Throw
    }
}
