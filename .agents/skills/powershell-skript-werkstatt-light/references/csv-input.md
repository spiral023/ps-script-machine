# CSV-/Datei-Eingaben

Diese Referenz lesen, sobald eine Datei eine Liste von Zielen liefert.

## Pflichtfragen

- Welche Spalten sind Pflicht, welche optional? Exakte Namen erfragen.
- Welches Trennzeichen und Encoding liefert das Quellsystem?
- Fehlerhafte oder leere Zeilen überspringen und ausweisen oder abbrechen?
- Wie soll eine Datei ohne Datenzeilen behandelt werden?

## Umsetzung

- Pfad mit `Test-Path -LiteralPath ... -PathType Leaf` validieren.
- Trennzeichen und Encoding explizit setzen und an einer Beispieldatei
  verifizieren; nicht pauschal von deutschem Excel auf eine Codepage
  schließen.
- Pflichtspalten unmittelbar nach dem Import prüfen.
- Eine leere Datei als Warnung oder vereinbarten Fehler behandeln.
- Jede Zeile wie ein Einzelziel verarbeiten und Teilfehler strukturiert
  zurückgeben.

```powershell
$requiredColumns = @('Name', 'Cluster')

if (-not (Test-Path -LiteralPath $InputCsvPath -PathType Leaf)) {
    throw "CSV-Datei nicht gefunden: $InputCsvPath"
}

$rows = @(Import-Csv -LiteralPath $InputCsvPath -Delimiter ';' -Encoding utf8)
if ($rows.Count -eq 0) {
    Write-Warning "CSV-Datei enthält keine Datenzeilen: $InputCsvPath"
    return
}

$missingColumns = @(
    $requiredColumns |
        Where-Object { $_ -notin $rows[0].PSObject.Properties.Name }
)
if ($missingColumns.Count -gt 0) {
    throw "Pflichtspalten fehlen: $($missingColumns -join ', ')"
}
```
