<#
.SYNOPSIS
    Exportiert Objekte als JSON-Datei.

.DESCRIPTION
    - Verwendet UTF-8 ohne BOM.
    - Strukturierte Ausgabe mit Tiefe 10.

.PARAMETER InputObject
    Die zu exportierenden Objekte.

.PARAMETER Path
    Pfad der Ausgabedatei.

.EXAMPLE
    Export-ReportJson -InputObject $results -Path "C:\Reports\cdp.json"
#>
function Export-ReportJson {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,

        [Parameter(Mandatory)]
        [string]$Path
    )

    begin {
        $allItems = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($item in $InputObject) {
            $allItems.Add($item)
        }
    }

    end {
        $jsonContent = $allItems |
            ConvertTo-Json -Depth 10

        [System.IO.File]::WriteAllText($Path, $jsonContent, [System.Text.UTF8Encoding]::new($false))
    }
}