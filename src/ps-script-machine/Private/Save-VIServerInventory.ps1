#Requires -Version 7.4

<#
.SYNOPSIS
    Schreibt die vCenter-Liste (vcenters.json).

.DESCRIPTION
    Save-VIServerInventory persistiert die übergebenen Inventar-Einträge als
    JSON-Array. Der Zielordner wird bei Bedarf angelegt. Es werden nur die
    Felder name, fqdn und description geschrieben - niemals Zugangsdaten.

.PARAMETER Path
    Vollständiger Pfad zur vcenters.json.

.PARAMETER Inventory
    Die Einträge (Objekte mit Name, Fqdn, Description), typischerweise von
    Get-VIServerInventory geliefert und ergänzt.

.EXAMPLE
    Save-VIServerInventory -Path $path -Inventory $entries

.OUTPUTS
    None.

.NOTES
    Private Funktion; Dateiformat siehe config/vcenters.example.json.
#>
function Save-VIServerInventory {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]
        $Inventory
    )

    $directory = Split-Path -Path $Path -Parent
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        $null = New-Item -Path $directory -ItemType Directory -Force
    }

    $plain = @($Inventory | ForEach-Object {
            [ordered]@{
                name        = [string]$_.Name
                fqdn        = [string]$_.Fqdn
                description = [string]$_.Description
            }
        })

    $json = $plain | ConvertTo-Json -Depth 3 -AsArray
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8
}
