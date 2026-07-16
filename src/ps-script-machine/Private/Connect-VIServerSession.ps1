<#
.SYNOPSIS
    Stellt eine sichere vCenter-Verbindung her.

.DESCRIPTION
    - Verwendet PSCredential (nie Plaintext-Passwörter).
    - Setzt PowerCLI-Konfiguration für Automatisierung (CEIP off, Zertifikate ignorieren).
    - Gibt das Connection-Objekt zurück.

.PARAMETER Server
    FQDN oder IP-Adresse des vCenter-Servers.

.PARAMETER Credential
    PSCredential-Objekt für die Anmeldung.

.PARAMETER Port
    Port des vCenter-Servers (Standard: 443).

.PARAMETER IgnoreCert
    Ignoriert Zertifikatswarnungen (Standard: true für Automatisierung).

.EXAMPLE
    $conn = Connect-VIServerSession -Server "vcenter.local" -Credential $cred

.NOTES
    Die Verbindung MUSS mit Disconnect-VIServerSession getrennt werden.
#>
function Connect-VIServerSession {
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter(Mandatory)]
        [PSCredential]$Credential,

        [Parameter()]
        [int]$Port = 443,

        [Parameter()]
        [bool]$IgnoreCert = $true
    )

    # PowerCLI-Konfiguration für Automatisierung
    if ($IgnoreCert) {
        Set-PowerCLIConfiguration `
            -Scope Session `
            -InvalidCertificateAction Ignore `
            -ParticipateInCEIP $false `
            -Confirm:$false `
            -ErrorAction SilentlyContinue | Out-Null
    }

    $connection = Connect-VIServer `
        -Server $Server `
        -Port $Port `
        -Credential $Credential `
        -ErrorAction Stop

    return $connection
}