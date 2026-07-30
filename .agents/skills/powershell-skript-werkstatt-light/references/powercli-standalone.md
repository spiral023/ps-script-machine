# PowerCLI für Standalone-Skripte

Zusätzlich den Skill `vmware-powercli-scripts` und dessen relevante Regeln
anwenden.

- PowerCLI-Verfügbarkeit und vereinbarte Mindestversion vor der Fachlogik
  prüfen.
- `Connect-VIServer` einmal aufrufen, Session wiederverwenden und im
  `finally` mit `Disconnect-VIServer -Server $session -Confirm:$false`
  schließen.
- Jedes PowerCLI-Cmdlet mit explizitem `-Server` aufrufen.
- Bei mehreren vCentern über alle Sessions iterieren und `VIServer` in
  jedes Ergebnisobjekt aufnehmen.
- Massenabrufe und In-Memory-Lookups statt Remote-Aufrufen pro Ziel nutzen.
- `ConnectionState` vor hostbezogenen Abfragen prüfen und nicht erreichbare
  Ziele als Teilfehler ausweisen.
- Für nicht über Cmdlets verfügbare Daten gezielt `Get-View` oder
  `.ExtensionData` verwenden.
- Unbeaufsichtigte Läufe ohne interaktive CEIP-/Konfigurationsprompts
  vorbereiten. Temporäre Process-/Session-Konfiguration dokumentieren und
  im `finally` wiederherstellen, sofern sie nicht mit dem Prozess endet.
- Zertifikatsprüfung niemals stillschweigend oder dauerhaft deaktivieren.

```powershell
foreach ($viConnection in $viConnections) {
    $vmHosts = Get-VMHost -Server $viConnection
    foreach ($vmHost in $vmHosts) {
        if ($vmHost.ConnectionState -ne 'Connected') {
            Write-Warning "$($vmHost.Name) ist nicht verbunden und wird übersprungen."
            continue
        }

        [PSCustomObject]@{
            PSTypeName = 'Custom.Verb-Noun.Result'
            VIServer   = $viConnection.Name
            VMHost     = $vmHost.Name
        }
    }
}
```
