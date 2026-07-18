#Requires -Version 7.4

<#
.SYNOPSIS
    Verbindet zu einem oder mehreren vCenter-Servern mit gemeinsamen Zugangsdaten.

.DESCRIPTION
    Connect-MultiVIServer fragt (falls nicht übergeben) einmal per
    Get-Credential nach Zugangsdaten und verbindet damit nacheinander zu
    allen angegebenen vCenter-Servern. Häufigster Fall: derselbe
    SSO-Account gilt überall.

    Schlägt die Anmeldung an einem Server fehl, wird im interaktiven Modus
    gezielt nur für diesen Server nachgefragt (neue Zugangsdaten eingeben
    oder überspringen). Ein nicht erreichbarer oder übersprungener Server
    bricht niemals den Gesamtlauf ab - er erscheint in der Skipped-Liste
    des Ergebnisobjekts.

    Im NonInteractive-Modus (Scheduled Tasks) führt ein Fehlschlag zu einer
    Warnung und dem Überspringen des Servers; -Credential ist dann Pflicht.

.PARAMETER Server
    Ein oder mehrere vCenter-FQDNs. Duplikate werden entfernt.

.PARAMETER Credential
    Zugangsdaten für alle Server. Wenn nicht angegeben, wird interaktiv
    per Get-Credential gefragt (außer bei -NonInteractive: dann Pflicht).

.PARAMETER NonInteractive
    Unterdrückt jede Rückfrage. Fehlgeschlagene Verbindungen werden mit
    Warnung übersprungen.

.EXAMPLE
    $connection = Connect-MultiVIServer -Server 'vc01.example.local', 'vc02.example.local'
    foreach ($session in $connection.Sessions) {
        Get-CdpNetworkInfo -VIServer $session
    }

    Fragt einmal nach Zugangsdaten, verbindet zu beiden vCentern und
    verarbeitet anschließend jede Session.

.EXAMPLE
    $connection = Connect-MultiVIServer -Server $targets -Credential $cred -NonInteractive

    Nicht-interaktiver Lauf für Automatisierung.

.INPUTS
    None. Server werden als Parameter übergeben.

.OUTPUTS
    PSCustomObject mit PSTypeName 'ps-script-machine.MultiVIServerConnection':
    Sessions (object[]), Connected (string[]), Skipped (string[]),
    Timestamp (string, ISO 8601), RunId (string).

.NOTES
    Die zurückgegebenen Sessions müssen vom Aufrufer getrennt werden
    (Disconnect-VIServer -Server $connection.Sessions -Confirm:$false),
    idealerweise in einem finally-Block.
    Zugangsdaten werden niemals gespeichert oder geloggt.

.LINK
    https://github.com/spiral023/ps-script-machine
#>
function Connect-MultiVIServer {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interaktive Verbindungsfunktion: Statusausgabe an den Bediener gehört zum Menü-Framework.')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Server,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter(Mandatory = $false)]
        [switch]
        $NonInteractive
    )

    $uniqueServers = @($Server | Select-Object -Unique)

    if (-not $Credential) {
        if ($NonInteractive) {
            throw 'Im nicht-interaktiven Modus muss -Credential angegeben werden (z. B. aus SecretManagement).'
        }
        $serverText = if ($uniqueServers.Count -eq 1) {
            $uniqueServers[0]
        }
        else {
            "$($uniqueServers.Count) vCenter-Server"
        }
        $Credential = Get-Credential -Message "Anmeldung für $serverText (z. B. user@vsphere.local)"
        if (-not $Credential) {
            throw 'Es wurden keine Zugangsdaten eingegeben - Abbruch.'
        }
    }

    $sessions = [System.Collections.Generic.List[object]]::new()
    $connected = [System.Collections.Generic.List[string]]::new()
    $skipped = [System.Collections.Generic.List[string]]::new()

    foreach ($fqdn in $uniqueServers) {
        $currentCredential = $Credential
        $resolved = $false

        while (-not $resolved) {
            Write-Host ("Verbinde mit {0} ..." -f $fqdn)
            $session = Connect-VIServerSession -Server $fqdn -Credential $currentCredential -ErrorAction SilentlyContinue

            if ($session) {
                $sessions.Add($session)
                $connected.Add($fqdn)
                Write-Host ("  Verbunden: {0}" -f $fqdn) -ForegroundColor Green
                $resolved = $true
                continue
            }

            $warningTemplate = "Anmeldung an '{0}' fehlgeschlagen. " +
            'Mögliche Ursachen: Server nicht erreichbar (Netzwerk/DNS) oder Zugangsdaten falsch. ' +
            'Prüfe den Servernamen oder versuche es mit anderen Zugangsdaten.'
            Write-Warning ($warningTemplate -f $fqdn)

            if ($NonInteractive) {
                $skipped.Add($fqdn)
                $resolved = $true
                continue
            }

            $choice = Read-MenuChoice `
                -Prompt ("Wie soll es mit '{0}' weitergehen? (n = neue Zugangsdaten, u = überspringen)" -f $fqdn) `
                -Default 'u' `
                -ValidAnswer 'n', 'u'

            if ($choice -ieq 'u') {
                $skipped.Add($fqdn)
                $resolved = $true
                continue
            }

            $currentCredential = Get-Credential -Message "Neue Anmeldung für $fqdn"
            if (-not $currentCredential) {
                $skipped.Add($fqdn)
                $resolved = $true
            }
        }
    }

    return [PSCustomObject]@{
        PSTypeName = 'ps-script-machine.MultiVIServerConnection'
        Sessions   = $sessions.ToArray()
        Connected  = $connected.ToArray()
        Skipped    = $skipped.ToArray()
        Timestamp  = (Get-Date).ToString('o')
        RunId      = $script:LogRunId
    }
}
