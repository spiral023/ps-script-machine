#Requires -Version 7.4

<#
.SYNOPSIS
    Stellt eine konsistente interaktive Konsolen-Abfrage mit Standardwert.

.DESCRIPTION
    Read-MenuChoice ist der Grundbaustein aller interaktiven Menüs der
    generierten Wrapper-Skripte. Die Funktion zeigt einen Prompt (optional
    mit Standardwert in eckigen Klammern), liest die Eingabe, und wiederholt
    die Abfrage bei leerer (ohne Default) oder ungültiger Eingabe.

    Bei -ValidAnswer wird case-insensitiv validiert und immer der kanonische
    Wert aus der ValidAnswer-Liste zurückgegeben (Eingabe 'n' bei
    -ValidAnswer 'J','N' liefert 'N').

.PARAMETER Prompt
    Der anzuzeigende Text (ohne Doppelpunkt, den ergänzt Read-Host).

.PARAMETER Default
    Optionaler Standardwert. Enter ohne Eingabe liefert diesen Wert.

.PARAMETER ValidAnswer
    Optionale Liste erlaubter Antworten (case-insensitiv geprüft).

.EXAMPLE
    $format = Read-MenuChoice -Prompt 'Ausgabeformat' -Default 'CSV' -ValidAnswer 'CSV', 'JSON', 'beide'

.OUTPUTS
    System.String

.NOTES
    Private Funktion; wird nicht exportiert, ist aber via InModuleScope testbar.
#>
function Read-MenuChoice {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interaktive Menü-Funktion: Konsolenausgabe an den Bediener ist der Zweck dieser Funktion, keine Fachlogik-Ausgabe.')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Prompt,

        [Parameter(Mandatory = $false)]
        [string]
        $Default,

        [Parameter(Mandatory = $false)]
        [string[]]
        $ValidAnswer
    )

    while ($true) {
        $displayPrompt = if ($Default) {
            "$Prompt [$Default]"
        }
        else {
            $Prompt
        }
        $answer = Read-Host -Prompt $displayPrompt

        if ([string]::IsNullOrWhiteSpace($answer)) {
            if ($Default) {
                return $Default
            }
            Write-Host 'Bitte einen Wert eingeben.' -ForegroundColor Yellow
            continue
        }

        $answer = $answer.Trim()

        if ($ValidAnswer -and $ValidAnswer.Count -gt 0) {
            $matched = $ValidAnswer | Where-Object { $_ -ieq $answer } | Select-Object -First 1
            if ($null -eq $matched) {
                Write-Host ('Ungültige Eingabe. Erlaubt: {0}' -f ($ValidAnswer -join ', ')) -ForegroundColor Yellow
                continue
            }
            return $matched
        }

        return $answer
    }
}
