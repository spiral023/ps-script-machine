#Requires -Version 7.4

<#
.SYNOPSIS
    Liest die gespeicherte vCenter-Liste (vcenters.json).

.DESCRIPTION
    Get-VIServerInventory liest die JSON-Datei mit den gespeicherten
    vCenter-Servern und liefert sie als strukturierte Objekte zurück.

    Robustheit für den interaktiven Einsatz:
    - Fehlende Datei ist kein Fehler (leere Liste, nur Verbose-Meldung),
      denn beim allerersten Start existiert noch keine Konfiguration.
    - Defektes JSON führt zu einer Warnung und einer leeren Liste,
      damit das Menü trotzdem benutzbar bleibt (freie FQDN-Eingabe).
    - Einträge ohne 'fqdn' werden mit Warnung übersprungen.

.PARAMETER Path
    Vollständiger Pfad zur vcenters.json.

.EXAMPLE
    $inventory = Get-VIServerInventory -Path 'C:\repo\config\vcenters.json'

.OUTPUTS
    PSCustomObject[] mit PSTypeName 'ps-script-machine.VIServerInventoryEntry'
    und den Properties Name, Fqdn, Description.

.NOTES
    Private Funktion; Dateiformat siehe config/vcenters.example.json.
#>
function Get-VIServerInventory {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Verbose "vCenter-Liste nicht gefunden (erster Start?): $Path"
        return @()
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Warning ((
                "Die vCenter-Liste '{0}' konnte nicht gelesen werden (vermutlich defektes JSON). " +
                'Sie wird ignoriert - vCenter können weiterhin frei eingegeben werden. ' +
                'Zum Beheben: Datei löschen oder reparieren. Details: {1}'
            ) -f $Path, $_.Exception.Message)
        return @()
    }

    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @($parsed)) {
        if ([string]::IsNullOrWhiteSpace($item.fqdn)) {
            Write-Warning "Eintrag ohne 'fqdn' in '$Path' wird übersprungen."
            continue
        }
        $name = if ([string]::IsNullOrWhiteSpace($item.name)) {
            [string]$item.fqdn
        }
        else {
            [string]$item.name
        }
        $entries.Add([PSCustomObject]@{
                PSTypeName  = 'ps-script-machine.VIServerInventoryEntry'
                Name        = $name
                Fqdn        = [string]$item.fqdn
                Description = [string]$item.description
            })
    }

    return $entries.ToArray()
}
