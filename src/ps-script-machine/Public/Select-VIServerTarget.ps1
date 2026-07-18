#Requires -Version 7.4

<#
.SYNOPSIS
    Interaktive Auswahl eines oder mehrerer vCenter-Server.

.DESCRIPTION
    Select-VIServerTarget zeigt die in vcenters.json gespeicherten
    vCenter-Server als nummerierte Liste an und liest die Auswahl des
    Bedieners. Erlaubte Eingaben:

    - Nummern, kommagetrennt (z. B. "1,3")
    - "alle" für alle gespeicherten vCenter
    - ein oder mehrere FQDNs, kommagetrennt (neue vCenter)

    Neue, noch nicht gespeicherte FQDNs können auf Nachfrage in die
    vcenters.json übernommen werden, damit sie beim nächsten Start als
    Auswahlpunkt erscheinen. Die Funktion fragt so lange, bis eine gültige
    Auswahl vorliegt, und liefert nie eine leere Liste.

    Diese Funktion ist für interaktive Wrapper-Skripte gedacht. In
    Automatisierungen (Scheduled Tasks) wird sie nicht aufgerufen -
    dort übergibt man die vCenter direkt als Parameter an das Skript.

.PARAMETER InventoryPath
    Vollständiger Pfad zur vcenters.json. Interaktive Wrapper verwenden
    im Repo config/vcenters.json und außerhalb (Standalone-Skript)
    $HOME/.ps-script-machine/vcenters.json.

.EXAMPLE
    $targets = Select-VIServerTarget -InventoryPath 'C:\repo\config\vcenters.json'

    Zeigt das Auswahlmenü und liefert z. B. @('vc01.example.local', 'vc02.example.local').

.INPUTS
    None. Diese Funktion liest ausschließlich von der Konsole.

.OUTPUTS
    System.String[] - deduplizierte Liste der gewählten FQDNs.

.NOTES
    Interaktive Funktion: nicht für unbeaufsichtigte Ausführung geeignet.
    Es werden ausschließlich Servernamen gespeichert, niemals Zugangsdaten.

.LINK
    https://github.com/spiral023/ps-script-machine
#>
function Select-VIServerTarget {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interaktive Menü-Funktion: Konsolenausgabe an den Bediener ist der Zweck dieser Funktion, keine Fachlogik-Ausgabe.')]
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InventoryPath
    )

    $inventory = @(Get-VIServerInventory -Path $InventoryPath)

    while ($true) {
        Write-Host ''
        Write-Host 'vCenter-Auswahl' -ForegroundColor Cyan
        if ($inventory.Count -gt 0) {
            for ($i = 0; $i -lt $inventory.Count; $i++) {
                $entry = $inventory[$i]
                $description = if ($entry.Description) {
                    " - $($entry.Description)"
                }
                else {
                    ''
                }
                Write-Host ('  [{0}] {1} ({2}){3}' -f ($i + 1), $entry.Name, $entry.Fqdn, $description)
            }
            Write-Host '  Eingabe: Nummern kommagetrennt (z. B. 1,3), "alle", oder FQDN eines neuen vCenters.'
        }
        else {
            Write-Host '  Noch keine vCenter gespeichert. Bitte FQDN eingeben (mehrere kommagetrennt).'
        }

        $userInput = Read-MenuChoice -Prompt 'vCenter'
        $tokens = @($userInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

        if ($tokens.Count -eq 0) {
            Write-Host 'Bitte eine Auswahl treffen.' -ForegroundColor Yellow
            continue
        }

        if ($tokens.Count -eq 1 -and $tokens[0] -ieq 'alle') {
            if ($inventory.Count -eq 0) {
                Write-Host 'Es sind keine vCenter gespeichert - bitte einen FQDN eingeben.' -ForegroundColor Yellow
                continue
            }
            return [string[]]@($inventory.Fqdn | Select-Object -Unique)
        }

        $isNumberSelection = @($tokens | Where-Object { $_ -match '^\d+$' }).Count -eq $tokens.Count
        if ($isNumberSelection) {
            $selected = [System.Collections.Generic.List[string]]::new()
            $selectionValid = $true
            foreach ($token in $tokens) {
                $index = [int]$token
                if ($index -lt 1 -or $index -gt $inventory.Count) {
                    Write-Host ('Die Nummer {0} gibt es nicht - bitte 1 bis {1} verwenden.' -f $index, $inventory.Count) -ForegroundColor Yellow
                    $selectionValid = $false
                    break
                }
                $selected.Add($inventory[$index - 1].Fqdn)
            }
            if (-not $selectionValid) {
                continue
            }
            return [string[]]@($selected | Select-Object -Unique)
        }

        # Freie FQDN-Eingabe: nur Hostname-taugliche Zeichen zulassen, reine
        # Zifferfolgen zählen nicht als FQDN (sonst würden gemischte
        # Nummer/FQDN-Eingaben wie "1,vc.local" fälschlich akzeptiert).
        $fqdnPattern = '^[a-zA-Z0-9][a-zA-Z0-9\.\-]*$'
        $allTokensAreFqdns = @($tokens | Where-Object { $_ -match $fqdnPattern -and $_ -notmatch '^\d+$' }).Count -eq $tokens.Count
        if (-not $allTokensAreFqdns) {
            Write-Host 'Eingabe nicht erkannt: bitte Nummern, "alle" oder gültige Servernamen (FQDN) eingeben.' -ForegroundColor Yellow
            continue
        }

        $knownFqdns = @($inventory.Fqdn)
        $newFqdns = @($tokens | Where-Object { $_ -notin $knownFqdns } | Select-Object -Unique)
        if ($newFqdns.Count -gt 0) {
            $saveAnswer = Read-MenuChoice `
                -Prompt ('Neue vCenter für später speichern? ({0})' -f ($newFqdns -join ', ')) `
                -Default 'J' `
                -ValidAnswer 'J', 'N'
            if ($saveAnswer -ieq 'J') {
                $updated = [System.Collections.Generic.List[object]]::new()
                foreach ($entry in $inventory) {
                    $updated.Add($entry)
                }
                foreach ($fqdn in $newFqdns) {
                    $updated.Add([PSCustomObject]@{
                            PSTypeName  = 'ps-script-machine.VIServerInventoryEntry'
                            Name        = $fqdn
                            Fqdn        = $fqdn
                            Description = ''
                        })
                }
                Save-VIServerInventory -Path $InventoryPath -Inventory $updated.ToArray()
                Write-Host ('Gespeichert in: {0}' -f $InventoryPath) -ForegroundColor Green
            }
        }

        return [string[]]@($tokens | Select-Object -Unique)
    }
}
