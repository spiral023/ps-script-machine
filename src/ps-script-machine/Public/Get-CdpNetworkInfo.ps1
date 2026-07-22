#Requires -Version 7.4

<#
.SYNOPSIS
    Retrieves CDP (Cisco Discovery Protocol) network information from VMware ESXi hosts.

.DESCRIPTION
    The Get-CdpNetworkInfo function connects to a vCenter Server or ESXi host and
    retrieves CDP network information for all or specified hosts. CDP data includes
    connected switch name, port, system name, and other network topology details.

    This is a read-only function that does not modify any vSphere configuration.
    It does not require SupportsShouldProcess because it makes no changes.

    The function explicitly passes the -Server parameter to all PowerCLI cmdlets
    to avoid relying on the global $global:DefaultVIServer connection. This ensures
    correct behavior when multiple vCenter connections are active.

.PARAMETER VIServer
    The vCenter Server or ESXi host connection (VIServer object) to query.
    This can be obtained via Connect-VIServerSession or directly via Connect-VIServer.
    The connection must already be established before calling this function.

.PARAMETER VMHost
    Optional: One or more VMHost objects or names to filter the query.
    If not specified, all hosts connected to the VIServer are queried.

.PARAMETER IncludeDetail
    Switch: If set, detailed CDP information is included for each physical network adapter.

.EXAMPLE
    $session = Connect-VIServerSession -Server 'vcenter.example.com' -Credential $cred
    Get-CdpNetworkInfo -VIServer $session

    Retrieves CDP network information for all hosts connected to the specified vCenter.

.EXAMPLE
    $session = Connect-VIServerSession -Server 'vcenter.example.com' -Credential $cred
    Get-CdpNetworkInfo -VIServer $session -VMHost 'esxi01.example.com','esxi02.example.com'

    Retrieves CDP network information for the specified hosts only.

.EXAMPLE
    $session = Connect-VIServerSession -Server 'vcenter.example.com' -Credential $cred
    Get-CdpNetworkInfo -VIServer $session -IncludeDetail

    Retrieves detailed CDP network information including all available properties.

.INPUTS
    VMware.VimAutomation.ViCore.Types.V1.VIServer.VIServer[]
    A VIServer object representing an established vCenter/ESXi connection.

.OUTPUTS
    ps-script-machine.CdpNetworkInfo
    A structured object containing CDP network information per host and adapter.

.NOTES
    Required vSphere permissions:
    - System.Read (on the vCenter Server)
    - Host.Config.Network (on the ESXi hosts or host folder)

    This function is read-only and does not modify any vSphere configuration.

.LINK
    https://github.com/spiral023/ps-script-machine
#>
function Get-CdpNetworkInfo {
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

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $VMHost,

        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeDetail
    )

    begin {
        $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Progress -Activity "Retrieving CDP network information" -Status "Initializing" -PercentComplete 0

        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        foreach ($server in $VIServer) {
            Write-Progress -Activity "Retrieving CDP network information" -Status "Processing server: $server" -PercentComplete 50

            try {
                $hostParams = @{
                    Server = $server
                    ErrorAction = 'Stop'
                }
                if ($PSBoundParameters.ContainsKey('VMHost') -and $VMHost) {
                    $hostParams['Name'] = $VMHost
                }

                $esxiHosts = Get-VMHost @hostParams

                if (-not $esxiHosts -or $esxiHosts.Count -eq 0) {
                    Write-Warning "No hosts found for server: $server"
                    continue
                }

                foreach ($esxiHost in $esxiHosts) {
                    try {
                        $hostName = $esxiHost.Name
                        Write-Verbose "Processing host: $hostName"

                        $esxCli = Get-EsxCli -Server $server -VMHost $esxiHost -ErrorAction Stop

                        # Get network adapters via EsxCli
                        $netAdapters = $esxCli.network.nic.list() | Where-Object { $_.Driver -ne '' }

                        if (-not $netAdapters -or $netAdapters.Count -eq 0) {
                            Write-Warning "No network adapters found for host: $hostName"
                            continue
                        }

                        foreach ($adapter in $netAdapters) {
                            try {
                                $cdpInfo = $null
                                $cdpInfo = $esxCli.network.nic.cdp.get($adapter.Name) | Select-Object -First 1 -ErrorAction SilentlyContinue

                                # Extract the VIServer name - if it's a VIServer object, use .Name
                                $viserverName = if ($server -is [string]) {
                                    $server
                                }
                                elseif ($server.Name) {
                                    $server.Name
                                }
                                else {
                                    [string]$server
                                }

                                $result = [PSCustomObject]@{
                                    PSTypeName     = 'ps-script-machine.CdpNetworkInfo'
                                    VIServer       = $viserverName
                                    VMHost         = $hostName
                                    AdapterName    = $adapter.Name
                                    Driver         = $adapter.Driver
                                    LinkStatus     = $adapter.LinkStatus
                                    CDPDevice      = $cdpInfo.Device
                                    CDPAddress     = $cdpInfo.Address
                                    CDPPort        = $cdpInfo.Port
                                    CDPSystemName  = $cdpInfo.SystemName
                                    CDPSystemOID   = $cdpInfo.SystemOID
                                    CDPVersion     = $cdpInfo.Version
                                    CDPTimeout     = $cdpInfo.Timeout
                                    CDPMtu         = $cdpInfo.Mtu
                                    CDPVlan        = $cdpInfo.Vlan
                                    CDPVtpMgmtDomain = $cdpInfo.VtpMgmtDomain
                                    CDPDuplex      = $cdpInfo.Duplex
                                    CDPConfDuplex  = $cdpInfo.ConfDuplex
                                    CDPSpeed       = $cdpInfo.Speed
                                    CDPConfSpeed   = $cdpInfo.ConfSpeed
                                    Timestamp      = (Get-Date)
                                    RunId          = $script:LogRunId
                                }

                                if ($IncludeDetail) {
                                    $result | Add-Member -MemberType NoteProperty -Name 'Detail' -Value $cdpInfo
                                }

                                $results.Add($result)
                            }
                            catch {
                                Write-Warning "Failed to retrieve CDP info for adapter $($adapter.Name) on host $hostName`: $_"
                            }
                        }
                    }
                    catch {
                        Write-Warning "Failed to process host $hostName`: $_"
                    }
                }
            }
            catch {
                Write-Error "Failed to query hosts for server $server`: $_"
            }
        }
    }

    end {
        $stopWatch.Stop()
        Write-Progress -Activity "Retrieving CDP network information" -Completed

        Write-Verbose "CDP network information retrieval completed in $($stopWatch.Elapsed.TotalSeconds) seconds."
        Write-Verbose "Total results: $($results.Count)"

        foreach ($result in $results) {
            Write-Output $result
        }
    }
}