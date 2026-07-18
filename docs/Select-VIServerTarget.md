# Select-VIServerTarget

Interaktive Auswahl eines oder mehrerer vCenter-Server aus der gespeicherten
Liste (`vcenters.json`), mit freier FQDN-Eingabe und optionalem Speichern
neuer Einträge.

## Syntax

```powershell
Select-VIServerTarget -InventoryPath <string>
```

## Beschreibung

Zeigt die gespeicherten vCenter als nummerierte Liste. Erlaubte Eingaben:
Nummern kommagetrennt (`1,3`), `alle`, oder ein/mehrere FQDNs. Neue FQDNs
werden auf Nachfrage in die `vcenters.json` übernommen. Rückgabe ist eine
deduplizierte FQDN-Liste (`string[]`), nie leer.

## Parameter

| Parameter | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `InventoryPath` | string | ja | Pfad zur `vcenters.json` (Format: siehe `config/vcenters.example.json`) |

## Beispiel

```powershell
$targets = Select-VIServerTarget -InventoryPath (Join-Path $repoRoot 'config\vcenters.json')
```

## Hinweise

- Interaktive Funktion — nicht in Scheduled Tasks verwenden; dort die
  vCenter direkt als Skript-Parameter übergeben.
- Es werden nur Servernamen gespeichert, niemals Zugangsdaten.
