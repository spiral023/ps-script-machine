<#
.SYNOPSIS
    Exportiert Objekte als CSV mit Windows-1252-Kodierung.

.DESCRIPTION
    - Verwendet Semikolon als Trennzeichen (für deutsches Excel).
    - Kodierung: Windows-1252 (für korrekte Umlaut-Darstellung in Excel).
    - Registriert den Codepage-Provider für PowerShell Core.

.PARAMETER InputObject
    Die zu exportierenden Objekte.

.PARAMETER Path
    Pfad der Ausgabedatei.

.EXAMPLE
    Export-ReportCsv -InputObject $results -Path "C:\Reports\cdp.csv"
#>
function Export-ReportCsv {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,

        [Parameter(Mandatory)]
        [string]$Path
    )

    begin {
        # Für PowerShell Core die Codepage-Unterstützung registrieren
        if ($PSVersionTable.PSEdition -eq "Core") {
            try {
                [System.Text.Encoding]::RegisterProvider(
                    [System.Text.CodePagesEncodingProvider]::Instance
                )
            }
            catch {
                Write-Verbose "Windows-1252-Codepage-Provider war bereits registriert."
            }
        }
        $encoding = [System.Text.Encoding]::GetEncoding(1252)
        $allItems = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($item in $InputObject) {
            $allItems.Add($item)
        }
    }

    end {
        $csvContent = $allItems |
            ConvertTo-Csv -Delimiter ";" -NoTypeInformation

        [System.IO.File]::WriteAllLines($Path, $csvContent, $encoding)
    }
}