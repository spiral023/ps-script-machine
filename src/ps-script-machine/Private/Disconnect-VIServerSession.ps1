<#
.SYNOPSIS
    Trennt eine vCenter-Verbindung sicher.

.DESCRIPTION
    - Verwendet Disconnect-VIServer mit -Confirm:$false.
    - Fehler werden mit SilentlyContinue unterdrückt (für finally-Blöcke).

.PARAMETER Connection
    Das Connection-Objekt aus Connect-VIServerSession.

.EXAMPLE
    Disconnect-VIServerSession -Connection $viConnection
#>
function Disconnect-VIServerSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Connection
    )

    if ($null -ne $Connection) {
        Disconnect-VIServer `
            -Server $Connection `
            -Confirm:$false `
            -ErrorAction SilentlyContinue
    }
}