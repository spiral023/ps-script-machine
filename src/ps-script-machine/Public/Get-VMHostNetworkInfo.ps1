#Requires -Version 7.4

<#
.SYNOPSIS
    Retrieves CDP information for the physical network adapters of ESXi hosts.

.DESCRIPTION
    Queries all ESXi hosts, or a filtered subset, on one or more existing vCenter
    sessions. The function does not create or close VIServer sessions. It retrieves
    network hints (CDP/LLDP) for physical adapters and returns structured results.

    This function is read-only and explicitly passes each VIServer session to every
    PowerCLI cmdlet, so it does not rely on a global default connection.

.PARAMETER VIServer
    One or more already connected VMware VIServer sessions. Create sessions outside
    this function, for example with Connect-MultiVIServer.

.PARAMETER VMHost
    Optional. Restricts the query to these ESXi host names.

.PARAMETER Cluster
    Optional. Restricts the query to hosts in these cluster names.

.EXAMPLE
    $connection = Connect-MultiVIServer -Server 'vcenter.example.com' -Credential $credential
    Get-VMHostNetworkInfo -VIServer $connection.Sessions

    Retrieves physical adapter CDP information from all hosts on the supplied
    vCenter session.

.EXAMPLE
    Get-VMHostNetworkInfo -VIServer $connection.Sessions -Cluster 'Production'

    Retrieves physical adapter CDP information for the hosts in the Production
    cluster.

.INPUTS
    VMware.VimAutomation.ViCore.Types.V1.VIServer.VIServer[]

.OUTPUTS
    ps-script-machine.VMHostNetworkInfo
    A structured result for each physical adapter, skipped host, or host query error.

.NOTES
    Required vSphere permissions:
    - System.Read
    - Host.Config.Network

    The function is read-only and does not modify or disconnect caller-owned sessions.

.LINK
    https://github.com/spiral023/ps-script-machine
#>
function Get-VMHostNetworkInfo {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [object[]]
        $VIServer,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $VMHost,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Cluster
    )

    begin {
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        foreach ($server in $VIServer) {
            $serverName = if ($server.Name) {
                [string]$server.Name
            }
            else {
                [string]$server
            }

            try {
                Write-ModuleLog -Message 'Retrieving VMHost network information.' -Level Information -VIServer $serverName

                $vmHostParams = @{
                    Server      = $server
                    ErrorAction = 'Stop'
                }
                if ($VMHost) {
                    $vmHostParams['Name'] = $VMHost
                }
                if ($Cluster) {
                    $vmHostParams['Location'] = Get-Cluster -Name $Cluster -Server $server -ErrorAction Stop
                }

                $vmHosts = @(Get-VMHost @vmHostParams | Sort-Object -Property Name)
                if ($vmHosts.Count -eq 0) {
                    Write-ModuleLog -Message 'No ESXi hosts were found.' -Level Warning -VIServer $serverName
                    continue
                }

                $allClusters = @(Get-Cluster -Server $server -ErrorAction Stop)
                $clusterLookup = @{}
                foreach ($currentCluster in $allClusters) {
                    foreach ($hostReference in $currentCluster.ExtensionData.Host) {
                        $clusterLookup[$hostReference.Value] = $currentCluster.Name
                    }
                }

                $hostNumber = 0
                foreach ($currentHost in $vmHosts) {
                    $hostNumber++
                    Write-Progress `
                        -Activity 'Retrieving VMHost network information' `
                        -Status "Host $hostNumber of $($vmHosts.Count): $($currentHost.Name)" `
                        -PercentComplete (($hostNumber / $vmHosts.Count) * 100)

                    $clusterName = ''
                    if ($clusterLookup.ContainsKey($currentHost.Id)) {
                        $clusterName = $clusterLookup[$currentHost.Id]
                    }

                    if ($currentHost.ConnectionState -ne 'Connected') {
                        $results.Add([PSCustomObject]@{
                                PSTypeName         = 'ps-script-machine.VMHostNetworkInfo'
                                VIServer           = $serverName
                                Cluster            = $clusterName
                                VMHost             = $currentHost.Name
                                HostConnectionState = $currentHost.ConnectionState
                                PhysicalAdapter     = ''
                                LinkStatus          = ''
                                MACAddress          = ''
                                CDPDeviceID         = ''
                                CDPPortID           = ''
                                CDPManagementIP     = ''
                                CDPSwitchAddress    = ''
                                CDPHardwarePlatform = ''
                                CDPSoftwareVersion  = ''
                                CDPNativeVLAN       = ''
                                CDPMTU              = ''
                                CDPAvailable        = $false
                                QueryStatus         = 'Übersprungen'
                                ErrorMessage        = 'ESXi host is not connected.'
                                Timestamp           = Get-Date
                                RunId               = $script:LogRunId
                            })
                        Write-ModuleLog -Message 'ESXi host is not connected; query skipped.' -Level Warning -VIServer $serverName -Resource $currentHost.Name
                        continue
                    }

                    try {
                        $networkSystem = Get-View `
                            -Id $currentHost.ExtensionData.ConfigManager.NetworkSystem `
                            -Server $server `
                            -ErrorAction Stop
                        $networkHints = $networkSystem.QueryNetworkHint([string[]]@())
                        $physicalAdapters = @(Get-VMHostNetworkAdapter `
                                -VMHost $currentHost `
                                -Physical `
                                -Server $server `
                                -ErrorAction Stop)

                        foreach ($adapter in $physicalAdapters) {
                            $hint = $networkHints |
                                Where-Object { $_.Device -eq $adapter.Name } |
                                Select-Object -First 1
                            $cdp = if ($hint) {
                                $hint.ConnectedSwitchPort
                            }
                            else {
                                $null
                            }
                            $cdpAvailable = $null -ne $cdp
                            $linkStatus = if ($adapter.BitRatePerSec -gt 0) {
                                'Up'
                            }
                            else {
                                'Down'
                            }
                            $cdpDeviceId = if ($cdpAvailable) {
                                ConvertTo-CleanText $cdp.DevId
                            }
                            else {
                                ''
                            }
                            $cdpPortId = if ($cdpAvailable) {
                                ConvertTo-CleanText $cdp.PortId
                            }
                            else {
                                ''
                            }
                            $cdpManagementIp = if ($cdpAvailable) {
                                ConvertTo-CleanText $cdp.MgmtAddr
                            }
                            else {
                                ''
                            }
                            $cdpSwitchAddress = if ($cdpAvailable) {
                                ConvertTo-CleanText $cdp.Address
                            }
                            else {
                                ''
                            }
                            $cdpHardwarePlatform = if ($cdpAvailable) {
                                ConvertTo-CleanText $cdp.HardwarePlatform
                            }
                            else {
                                ''
                            }
                            $cdpSoftwareVersion = if ($cdpAvailable) {
                                ConvertTo-CleanText $cdp.SoftwareVersion
                            }
                            else {
                                ''
                            }
                            $cdpNativeVlan = if ($cdpAvailable) {
                                ConvertTo-CleanText $cdp.Vlan
                            }
                            else {
                                ''
                            }
                            $cdpMtu = if ($cdpAvailable) {
                                ConvertTo-CleanText $cdp.Mtu
                            }
                            else {
                                ''
                            }
                            $queryStatus = if ($cdpAvailable) {
                                'CDP data found'
                            }
                            else {
                                'No CDP data'
                            }

                            $results.Add([PSCustomObject]@{
                                    PSTypeName         = 'ps-script-machine.VMHostNetworkInfo'
                                    VIServer           = $serverName
                                    Cluster            = $clusterName
                                    VMHost             = $currentHost.Name
                                    HostConnectionState = $currentHost.ConnectionState
                                    PhysicalAdapter     = $adapter.Name
                                    LinkStatus          = $linkStatus
                                    MACAddress          = $adapter.Mac
                                    CDPDeviceID         = $cdpDeviceId
                                    CDPPortID           = $cdpPortId
                                    CDPManagementIP     = $cdpManagementIp
                                    CDPSwitchAddress    = $cdpSwitchAddress
                                    CDPHardwarePlatform = $cdpHardwarePlatform
                                    CDPSoftwareVersion  = $cdpSoftwareVersion
                                    CDPNativeVLAN       = $cdpNativeVlan
                                    CDPMTU              = $cdpMtu
                                    CDPAvailable        = $cdpAvailable
                                    QueryStatus         = $queryStatus
                                    ErrorMessage        = ''
                                    Timestamp           = Get-Date
                                    RunId               = $script:LogRunId
                                })
                        }

                        Write-ModuleLog -Message 'Physical network adapters retrieved.' -Level Information -VIServer $serverName -Resource $currentHost.Name -Data @{ AdapterCount = $physicalAdapters.Count }
                    }
                    catch {
                        $errorMessage = $_.Exception.Message
                        $results.Add([PSCustomObject]@{
                                PSTypeName         = 'ps-script-machine.VMHostNetworkInfo'
                                VIServer           = $serverName
                                Cluster            = $clusterName
                                VMHost             = $currentHost.Name
                                HostConnectionState = $currentHost.ConnectionState
                                PhysicalAdapter     = ''
                                LinkStatus          = ''
                                MACAddress          = ''
                                CDPDeviceID         = ''
                                CDPPortID           = ''
                                CDPManagementIP     = ''
                                CDPSwitchAddress    = ''
                                CDPHardwarePlatform = ''
                                CDPSoftwareVersion  = ''
                                CDPNativeVLAN       = ''
                                CDPMTU              = ''
                                CDPAvailable        = $false
                                QueryStatus         = 'Fehler'
                                ErrorMessage        = $errorMessage
                                Timestamp           = Get-Date
                                RunId               = $script:LogRunId
                            })
                        Write-ModuleLog -Message 'VMHost network query failed.' -Level Warning -VIServer $serverName -Resource $currentHost.Name -Data @{ Error = $errorMessage }
                    }
                }
            }
            catch {
                Write-ModuleLog -Message 'VIServer query failed.' -Level Error -VIServer $serverName -Data @{ Error = $_.Exception.Message }
            }
        }
    }

    end {
        Write-Progress -Activity 'Retrieving VMHost network information' -Completed
        foreach ($result in $results) {
            Write-Output $result
        }
    }
}
