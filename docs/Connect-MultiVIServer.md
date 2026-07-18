# Connect-MultiVIServer

Verbindet mit gemeinsamen Zugangsdaten zu mehreren vCenter-Servern.
Fehlgeschlagene Server werden übersprungen (mit gezielter Nachfrage im
interaktiven Modus) und brechen nie den Gesamtlauf ab.

## Syntax

```powershell
Connect-MultiVIServer -Server <string[]> [-Credential <PSCredential>] [-NonInteractive]
```

## Beschreibung

Fragt (falls nicht übergeben) einmal per `Get-Credential` nach
Zugangsdaten und verbindet damit nacheinander zu allen angegebenen
vCenter-Servern (Duplikate werden entfernt). Häufigster Fall: derselbe
SSO-Account gilt überall.

Schlägt die Anmeldung an einem Server fehl, wird im interaktiven Modus
gezielt nur für diesen Server nachgefragt (`n` = neue Zugangsdaten
eingeben, `u` = überspringen, Default `u`) - solange, bis Erfolg oder
Überspringen. Im `-NonInteractive`-Modus (Scheduled Tasks) führt ein
Fehlschlag stattdessen zu einer Warnung und dem Überspringen des
Servers; `-Credential` ist dort Pflicht.

## Parameter

| Parameter | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `Server` | string[] | ja | Ein oder mehrere vCenter-FQDNs. Duplikate werden entfernt. |
| `Credential` | PSCredential | nein | Zugangsdaten für alle Server. Ohne Angabe: interaktiv per `Get-Credential` (außer bei `-NonInteractive`: dann Pflicht). |
| `NonInteractive` | switch | nein | Unterdrückt jede Rückfrage; Fehlschläge werden mit Warnung übersprungen. |

## Rückgabeobjekt

`PSCustomObject` mit `PSTypeName 'ps-script-machine.MultiVIServerConnection'`:

| Property | Typ | Bedeutung |
|---|---|---|
| `Sessions` | object[] | Verbundene VIServer-Sessions (für `-VIServer` und `Disconnect-VIServer`) |
| `Connected` | string[] | FQDNs erfolgreicher Verbindungen |
| `Skipped` | string[] | FQDNs übersprungener Server |
| `Timestamp` | string | Zeitstempel (ISO 8601) |
| `RunId` | string | Lauf-ID für Audit/Logs |

## Beispiel

```powershell
$connection = Connect-MultiVIServer -Server 'vc01.example.local', 'vc02.example.local'
try {
    foreach ($session in $connection.Sessions) {
        Get-CdpNetworkInfo -VIServer $session
    }
}
finally {
    if ($connection.Sessions.Count -gt 0) {
        Disconnect-VIServer -Server $connection.Sessions -Confirm:$false -ErrorAction SilentlyContinue
    }
}
```

```powershell
# Nicht-interaktiver Lauf für Automatisierung (z. B. Scheduled Task)
$connection = Connect-MultiVIServer -Server $targets -Credential $cred -NonInteractive
```

## Hinweise

- Ohne `-Credential` wird einmal interaktiv gefragt; bei Login-Fehlschlag
  gezielt pro Server (neue Zugangsdaten oder überspringen).
- Mit `-NonInteractive` ist `-Credential` Pflicht; Fehlschläge werden mit
  Warnung übersprungen.
- Ein fehlgeschlagener oder übersprungener Server bricht niemals den
  Gesamtlauf ab - er erscheint lediglich in `Skipped`.
- Der Aufrufer trennt die Sessions (idealerweise im `finally`-Block).
- Zugangsdaten werden niemals gespeichert oder geloggt.
