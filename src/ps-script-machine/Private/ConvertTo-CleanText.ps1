<#
.SYNOPSIS
    Wandelt einen Wert in einen bereinigten einzeiligen Text um.

.DESCRIPTION
    - Behandelt null, Arrays und Strings.
    - Ersetzt alle Whitespaces (inkl. Tabs, Newlines) durch einzelne Leerzeichen.
    - Entfernt führende und nachfolgende Leerzeichen.

.PARAMETER Value
    Der zu bereinigende Wert.

.EXAMPLE
    ConvertTo-CleanText -Value "  Hallo   Welt  "
    # Ergebnis: "Hallo Welt"
#>
function ConvertTo-CleanText {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ""
    }

    if ($Value -is [System.Array]) {
        $text = $Value -join ", "
    }
    else {
        $text = [string]$Value
    }

    return ([regex]::Replace($text, "\s+", " ")).Trim()
}