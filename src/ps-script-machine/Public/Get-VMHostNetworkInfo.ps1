<#
.SYNOPSIS
    Liest CDP-Informationen aller physischen Netzwerkadapter von ESXi-Hosten aus.

.DESCRIPTION
    - Verbindet sich per PowerCLI mit einem vCenter.
    - Liest alle ESXi-Hosts (oder eine Teilmenge) aus.
    - Ruft Network-Hints (CDP/LLDP) für alle physischen Adapter ab.
    - Gibt strukturierte PSCustomObject-Ergebnisse zurück.
    - Führt ausschließlich Leseoperationen durch (read-only).

.PARAMETER Server
    FQDN oder IP-Adresse des vCenter-Servers.

.PARAMETER Credential
    PSCredential-Objekt für die vCenter-Anmeldung.

.PARAMETER VMHost
    Optional: Nur diese Hosts abfragen (Standard: alle).

.PARAMETER Cluster
    Optional: Nur Hosts aus diesen Clustern abfragen.

.EXAMPLE
    $cred = Get-Credential -Message "vCenter-Anmeldung"
    Get-VMHostNetworkInfo -Server "vcenter.local" -Credential $cred

.EXAMPLE
    Get-VMHostNetworkInfo -Server "vcenter.local" -Credential $cred -Cluster "Prod"

.EXAMPLE
    $results = Get-VMHostNetworkInfo -Server "vcenter.local" -Credential $cred
    $results | Export-ReportCsv -Path "C:\Reports\cdp.csv"
    $results | Export-ReportJson -Path "C:\Reports\cdp.json"

.NOTES
    Author: VMware Admin Team
    Requirements: VMware PowerCLI 12+ / VCF PowerCLI 9+
    Die Funktion führt ausschließlich Leseoperationen durch.
#>
function Get-VMHostNetworkInfo {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter(Mandatory)]
        [PSCredential]$Credential,

        [Parameter()]
        [string[]]$VMHost,

        [Parameter()]
        [string[]]$Cluster
    )

    $ErrorActionPreference = "Stop"
    Set-StrictMode -Version Latest

    $viConnection = $null
    $results = [System.Collections.Generic.List[object]]::new()

    try {
        Write-ScriptLog -Message "Verbinde mit vCenter $Server ..." -Level INFO

        $viConnection = Connect-VIServerSession `
            -Server $Server `
            -Credential $Credential

        Write-ScriptLog -Message "Verbindung erfolgreich hergestellt." -Level INFO

        # Hosts abfragen (gefiltert nach Cluster oder VMHost-Parameter)
        $vmHostParams = @{}
        if ($VMHost) { $vmHostParams['Name'] = $VMHost }
        if ($Cluster) { $vmHostParams['Location'] = (Get-Cluster -Name $Cluster) }

        $vmHosts = Get-VMHost @vmHostParams | Sort-Object Name

        if (-not $vmHosts -or $vmHosts.Count -eq 0) {
            throw "Im vCenter wurden keine ESXi-Hosts gefunden."
        }

        Write-ScriptLog -Message "$($vmHosts.Count) ESXi-Host(s) gefunden." -Level INFO

        # Cluster-Lookup für effiziente Zuordnung (Bulk-Query)
        $allClusters = Get-Cluster
        $clusterLookup = @{}
        foreach ($c in $allClusters) {
            foreach ($h in $c.ExtensionData.Host) {
                $clusterLookup[$h.Value] = $c.Name
            }
        }

        $hostNumber = 0

        foreach ($currentHost in $vmHosts) {
            $hostNumber++

            Write-Progress `
                -Activity "CDP-Informationen werden ausgelesen" `
                -Status "Host $hostNumber von $($vmHosts.Count): $($currentHost.Name)" `
                -PercentComplete (($hostNumber / $vmHosts.Count) * 100)

            Write-ScriptLog -Message "[$hostNumber/$($vmHosts.Count)] $($currentHost.Name)" -Level INFO

            $clusterName = ""
            if ($clusterLookup.ContainsKey($currentHost.Id)) {
                $clusterName = $clusterLookup[$currentHost.Id]
            }

            # Bei nicht erreichbaren Hosts überspringen
            if ($currentHost.ConnectionState -ne "Connected") {
                $results.Add([PSCustomObject]@{
                    vCenter             = $Server
                    Cluster             = $clusterName
                    VMHost              = $currentHost.Name
                    HostConnectionState = $currentHost.ConnectionState
                    PhysicalAdapter     = ""
                    LinkStatus          = ""
                    MACAddress          = ""
                    CDPDeviceID         = ""
                    CDPPortID           = ""
                    CDPManagementIP     = ""
                    CDPSwitchAddress    = ""
                    CDPHardwarePlatform = ""
                    CDPSoftwareVersion  = ""
                    CDPNativeVLAN       = ""
                    CDPMTU              = ""
                    CDPAvailable        = $false
                    QueryStatus         = "Übersprungen"
                    ErrorMessage        = "ESXi-Host ist nicht verbunden."
                    CollectionTime      = (Get-Date)
                })

                Write-ScriptLog -Message "$($currentHost.Name) ist nicht verbunden, übersprungen." -Level WARNING
                continue
            }

            try {
                $networkSystem = Get-View `
                    -Id $currentHost.ExtensionData.ConfigManager.NetworkSystem `
                    -ErrorAction Stop

                $networkHints = $networkSystem.QueryNetworkHint([string[]]@())

                $physicalAdapters = Get-VMHostNetworkAdapter `
                    -VMHost $currentHost `
                    -Physical `
                    -ErrorAction Stop

                foreach ($adapter in $physicalAdapters) {
                    $hint = $networkHints |
                        Where-Object { $_.Device -eq $adapter.Name } |
                        Select-Object -First 1

                    $cdp = $null
                    if ($hint) {
                        $cdp = $hint.ConnectedSwitchPort
                    }

                    $cdpAvailable = $null -ne $cdp

                    $results.Add([PSCustomObject]@{
                        vCenter             = $Server
                        Cluster             = $clusterName
                        VMHost              = $currentHost.Name
                        HostConnectionState = $currentHost.ConnectionState
                        PhysicalAdapter     = $adapter.Name
                        LinkStatus          = if ($adapter.BitRatePerSec -gt 0) { "Up" } else { "Down" }
                        MACAddress          = $adapter.Mac
                        CDPDeviceID         = ConvertTo-CleanText $cdp.DevId
                        CDPPortID           = ConvertTo-CleanText $cdp.PortId
                        CDPManagementIP     = ConvertTo-CleanText $cdp.MgmtAddr
                        CDPSwitchAddress    = ConvertTo-CleanText $cdp.Address
                        CDPHardwarePlatform = ConvertTo-CleanText $cdp.HardwarePlatform
                        CDPSoftwareVersion  = ConvertTo-CleanText $cdp.SoftwareVersion
                        CDPNativeVLAN       = ConvertTo-CleanText $cdp.Vlan
                        CDPMTU              = ConvertTo-CleanText $cdp.Mtu
                        CDPAvailable        = $cdpAvailable
                        QueryStatus         = if ($cdpAvailable) { "CDP-Daten gefunden" } else { "Keine CDP-Daten" }
                        ErrorMessage        = ""
                        CollectionTime      = (Get-Date)
                    })
                }

                Write-ScriptLog -Message "  $($physicalAdapters.Count) physische Adapter ausgelesen." -Level INFO
            }
            catch {
                $errorMessage = $_.Exception.Message

                $results.Add([PSCustomObject]@{
                    vCenter             = $Server
                    Cluster             = $clusterName
                    VMHost              = $currentHost.Name
                    HostConnectionState = $currentHost.ConnectionState
                    PhysicalAdapter     = ""
                    LinkStatus          = ""
                    MACAddress          = ""
                    CDPDeviceID         = ""
                    CDPPortID           = ""
                    CDPManagementIP     = ""
                    CDPSwitchAddress    = ""
                    CDPHardwarePlatform = ""
                    CDPSoftwareVersion  = ""
                    CDPNativeVLAN       = ""
                    CDPMTU              = ""
                    CDPAvailable        = $false
                    QueryStatus         = "Fehler"
                    ErrorMessage        = $errorMessage
                    CollectionTime      = (Get-Date)
                })

                Write-ScriptLog -Message "Abfrage für $($currentHost.Name) fehlgeschlagen: $errorMessage" -Level WARNING
            }
        }

        Write-Progress -Activity "CDP-Informationen werden ausgelesen" -Completed

        if ($results.Count -eq 0) {
            throw "Es wurden keine Ergebnisse erzeugt."
        }

        Write-ScriptLog -Message "Export erfolgreich. $($results.Count) Ergebnis(se)." -Level INFO

        return $results
    }
    catch {
        Write-ScriptLog -Message "Skript fehlgeschlagen: $($_.Exception.Message)" -Level ERROR
        throw
    }
    finally {
        if ($viConnection) {
            Write-ScriptLog -Message "Trenne vCenter-Verbindung ..." -Level INFO
            Disconnect-VIServerSession -Connection $viConnection
            Write-ScriptLog -Message "vCenter-Verbindung getrennt." -Level INFO
        }
    }
}