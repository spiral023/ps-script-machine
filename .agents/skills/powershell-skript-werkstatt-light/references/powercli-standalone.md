# PowerCLI für Standalone-Skripte

Diese Referenz bei jeder vCenter-, ESXi- oder PowerCLI-Aufgabe vollständig
lesen und anwenden. Sie enthält den vollständigen PowerCLI-Vertrag des
Light-Skills und setzt keinen weiteren Skill voraus.

## Inhalt

1. [Interview und Geltungsbereich](#interview-und-geltungsbereich)
2. [Abhängigkeits-Preflight](#abhängigkeits-preflight)
3. [Credentials und Secrets](#credentials-und-secrets)
4. [Verbindungen und Session-Eigentum](#verbindungen-und-session-eigentum)
5. [PowerCLI-Konfiguration und Zertifikate](#powercli-konfiguration-und-zertifikate)
6. [Mehrere vCenter](#mehrere-vcenter)
7. [Datenabruf und vSphere API](#datenabruf-und-vsphere-api)
8. [Fehler und Teilfehler](#fehler-und-teilfehler)
9. [Verändernde Operationen](#verändernde-operationen)
10. [Ergebnisse, Hilfe und Berechtigungen](#ergebnisse-hilfe-und-berechtigungen)
11. [Eigenprüfung vor der Übergabe](#eigenprüfung-vor-der-übergabe)

## Interview und Geltungsbereich

Zusätzlich zum allgemeinen Interview des Light-Skills klären:

- vCenter-/ESXi-Versionen und vereinbarte PowerCLI-Mindestversion;
- ein oder mehrere vCenter und Verhalten, wenn nur ein Teil erreichbar ist;
- Authentifizierungsquelle: interaktives `PSCredential`, sicherer Vault oder
  bereits autorisiert bereitgestelltes `PSCredential`;
- DNS-, Firewall-, Proxy- und Zertifikatsvertrauen des ausführenden Kontos;
- benötigte vSphere-Berechtigungen nach Least Privilege;
- Zielobjekte und Filter so eindeutig, dass keine gleichnamigen Objekte eines
  anderen vCenters getroffen werden;
- bei Änderungen den erwarteten Vorher-/Nachher-Zustand sowie Bestätigungs-
  und Teilerfolgsverhalten.

Ein unbeaufsichtigter Lauf darf weder `Get-Credential` noch Zertifikats-,
CEIP- oder sonstige Dialoge öffnen. Alle Eingaben müssen vorher sicher
bereitgestellt sein.

## Abhängigkeits-Preflight

Vor Import, Verbindung und Fachlogik die vereinbarte Mindestversion von
`VMware.VimAutomation.Core` prüfen. Die höchste gefundene Version mit der
benötigten Version vergleichen und bei Nichterfüllung mit einer konkreten,
sicheren Meldung abbrechen. Module nicht stillschweigend installieren und
`PSModulePath` weder global noch mit fest codierten Unternehmenspfaden ändern.

```powershell
$MinimumPowerCLIVersion = [version]'13.2.0'
$powerCliModule = Get-Module -ListAvailable -Name 'VMware.VimAutomation.Core' |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $powerCliModule) {
    throw "VMware PowerCLI fehlt. Benötigt wird mindestens $MinimumPowerCLIVersion."
}
if ($powerCliModule.Version -lt $MinimumPowerCLIVersion) {
    throw "VMware PowerCLI $($powerCliModule.Version) gefunden; benötigt wird mindestens $MinimumPowerCLIVersion."
}

Import-Module 'VMware.VimAutomation.Core' -MinimumVersion $MinimumPowerCLIVersion -ErrorAction Stop
```

Die Mindestversion nicht blind aus diesem Beispiel übernehmen, sondern im
Interview vereinbaren und in `.NOTES` dokumentieren. Zusätzlich PowerShell-
Version, Erreichbarkeit, Schreibziele und benötigte Dateien gemäß
`runtime-contract.md` prüfen.

## Credentials und Secrets

- Niemals Benutzername/Passwort, Token, Servernamen oder IP-Adressen fest
  codieren.
- Kennwörter niemals als `[string]` entgegennehmen. Für interaktive oder
  bereitgestellte Anmeldung ausschließlich `[PSCredential]` verwenden.
- `Microsoft.PowerShell.SecretManagement` empfehlen, wenn es im Zielbetrieb
  vorhanden und eingerichtet ist; keine zusätzliche Modulinstallation als
  versteckte Laufzeitnebenwirkung durchführen.
- In unbeaufsichtigten Läufen müssen Credentials vorab über einen für das
  ausführende Konto zugänglichen Vault oder eine gleichwertige sichere
  Übergabe bereitstehen. Kein Fallback auf einen Prompt.
- Credential-Objekte, Benutzernamen, Tokens und Verbindungszeichenfolgen
  weder ausgeben noch protokollieren.
- Secrets nicht in Fehlertexte, Transcripts, Exporte oder Ergebnisobjekte
  kopieren. Fehlermeldungen vor der Protokollierung bereinigen.

```powershell
[Parameter(Mandatory)]
[ValidateNotNull()]
[System.Management.Automation.PSCredential]$Credential
```

Soll ein interaktives Skript ein optionales `$null`-Credential akzeptieren,
darf es erst nach Feststellung des interaktiven Betriebsprofils gezielt mit
`Get-Credential` nachfragen. Im unbeaufsichtigten Profil ist `$null` ein
fataler Preflight-Fehler.

## Verbindungen und Session-Eigentum

- Pro vCenter genau einmal mit `Connect-VIServer -Server ... -Credential ...
  -ErrorAction Stop` verbinden und die zurückgegebene Session wiederverwenden.
- Niemals `$global:DefaultVIServer`, `$DefaultVIServers` oder implizite
  Standardverbindungen als fachliche Abhängigkeit verwenden.
- Jedes PowerCLI-Cmdlet explizit an die zugehörige Session binden. Das gilt
  auch für `Get-View`, `Get-VIObjectByVIView`, verändernde Cmdlets und
  Postchecks: immer `-Server $viConnection`, soweit das Cmdlet den Parameter
  unterstützt.
- Keine Objekte oder Managed Object References zwischen vCenter-Sessions
  mischen. Lookups und IDs immer innerhalb derselben Session auflösen.
- Nur Sessions im `finally` trennen, die das Skript selbst erfolgreich
  geöffnet hat. Vom Aufrufer übergebene Sessions gehören dem Aufrufer und
  dürfen nicht ungefragt geschlossen werden.
- Alle eigenen Sessions im `finally` einzeln mit
  `Disconnect-VIServer -Server $viConnection -Confirm:$false
  -ErrorAction SilentlyContinue` schließen.
- Verbindungsaufbau, Fachlogik und Cleanup bleiben innerhalb des einen äußeren
  Laufzeit-Lebenszyklus. Hilfsfunktionen rufen niemals `exit` auf.

```powershell
$ownedViConnections = [System.Collections.Generic.List[object]]::new()
try {
    foreach ($vCenterName in $VCenterNames) {
        $viConnection = Connect-VIServer `
            -Server $vCenterName `
            -Credential $Credential `
            -ErrorAction Stop
        $ownedViConnections.Add($viConnection)
    }

    foreach ($viConnection in $ownedViConnections) {
        $vmHosts = @(Get-VMHost -Server $viConnection -ErrorAction Stop)
        # Fachlogik für genau diese Session
    }
}
finally {
    foreach ($viConnection in $ownedViConnections) {
        Disconnect-VIServer `
            -Server $viConnection `
            -Confirm:$false `
            -ErrorAction SilentlyContinue
    }
}
```

## PowerCLI-Konfiguration und Zertifikate

- Zertifikatsprüfung niemals stillschweigend deaktivieren. Für produktive und
  unbeaufsichtigte Läufe eine vertrauenswürdige Zertifikatskette herstellen.
- `InvalidCertificateAction Ignore` nicht als Standard, Reparatur oder
  Komfortoption einsetzen.
- Eine ausdrücklich vereinbarte Ausnahme für ein isoliertes Testsystem muss
  als opt-in Parameter sichtbar sein, in `.NOTES` stehen, auf Process/Session
  begrenzt werden und nach Möglichkeit im `finally` auf den vorherigen Wert
  zurückgesetzt werden.
- PowerCLI-Konfiguration niemals unbemerkt im User- oder AllUsers-Scope
  verändern. Temporäre Änderungen nur im Session-/Process-Scope vornehmen,
  vorherigen Zustand erfassen und im `finally` wiederherstellen.
- CEIP- und Konfigurationsprompts vor unbeaufsichtigten Läufen kontrolliert
  vermeiden. Die dafür gewählte Session-Konfiguration und ihre Rücksetzung
  dokumentieren; keine dauerhafte Benutzerkonfiguration als Nebenwirkung.

## Mehrere vCenter

- Servernamen als validiertes Array entgegennehmen oder einen einzelnen Namen
  intern in ein Array normalisieren.
- Verbindungen getrennt aufbauen und einen Verbindungsfehler als Teilfehler
  erfassen, wenn im Interview Weiterverarbeitung vereinbart wurde.
- Fachlogik pro Session ausführen und jedem Ergebnis die Eigenschaft
  `VIServer` mit dem Namen der tatsächlich verwendeten Session hinzufügen.
- Gleichnamige Cluster, Hosts oder VMs nie ohne Session-Kontext
  zusammenführen. Für Schlüssel mindestens `VIServer` plus Objekt-ID oder
  einen anderen vCenter-eindeutigen Wert verwenden.
- Ist keine der erforderlichen Sessions nutzbar, ist der Lauf fatal. Sind nur
  einzelne Sessions oder Ziele betroffen, Status und Zählwerte als
  Teilerfolg ausweisen und gemäß vereinbartem Exitcode-Vertrag behandeln.

## Datenabruf und vSphere API

- Massenabrufe pro Session verwenden, etwa einmal `Get-VMHost -Server
  $viConnection`, statt Cmdlets pro Objekt in einer Schleife aufzurufen.
- Erst alle benötigten Daten sammeln, dann In-Memory-Lookups aufbauen und
  anschließend verarbeiten. Remote-Aufrufe nicht mit Exporten vermischen.
- `Get-View -Server $viConnection` gezielt für Eigenschaften oder Methoden
  nutzen, die reguläre Cmdlets nicht bereitstellen. Mit `-Property` nur die
  benötigten Eigenschaften abrufen und mehrere IDs nach Möglichkeit bündeln.
- `.ExtensionData` nur verwenden, wenn die benötigte Information nicht sauber
  über ein Cmdlet verfügbar ist. Fehlende optionale Eigenschaften als
  fehlende Daten behandeln, nicht als ungefangenen Nullfehler.
- Ist ein API-Methodenaufruf technisch nur pro Objekt möglich, zuerst alle
  vorbereitenden Daten gebündelt abrufen, den unvermeidbaren Aufruf begründen,
  pro Ziel isoliert abfangen und keine zusätzlichen Remote-Lookups in dieselbe
  Schleife einbauen.
- Vor hostbezogenen Remote-Abfragen den fachlich zulässigen
  `ConnectionState` prüfen. Nicht nutzbare Hosts warnend überspringen und als
  strukturierten Teilfehler bzw. `Skipped`-Datensatz ausweisen.

```powershell
foreach ($viConnection in $viConnections) {
    $vmHosts = @(Get-VMHost -Server $viConnection -ErrorAction Stop)
    $usableVmHosts = @($vmHosts | Where-Object ConnectionState -eq 'Connected')

    $viewIds = @($usableVmHosts.ExtensionData.ConfigManager.NetworkSystem)
    $networkSystems = if ($viewIds.Count -gt 0) {
        @(Get-View -Id $viewIds -Server $viConnection -ErrorAction Stop)
    }
    else {
        @()
    }

    # Ab hier möglichst ausschließlich im Speicher verarbeiten.
}
```

## Fehler und Teilfehler

- `$ErrorActionPreference = 'Stop'` im Skript setzen und bei externen
  PowerCLI-Aufrufen zusätzlich `-ErrorAction Stop` verwenden.
- Ein äußerer `try`/`catch`/`finally` schützt Preflight, Verbindung,
  Fachlogik, Export und Cleanup.
- Bei mehreren vCentern oder Zielen inneres `try`/`catch` pro unabhängigem
  Ziel einsetzen. Ein Einzelfehler beendet nicht alle übrigen Ziele, sofern
  das Interview keinen Sofortabbruch festgelegt hat.
- Leere Abfragen bewusst behandeln: je nach fachlichem Vertrag als gültiges
  leeres Ergebnis, `Skipped` oder Fehler – niemals durch einen späteren
  Nullzugriff zufällig scheitern lassen.
- Keine rohen Credential-, Session- oder Serverobjekte in Fehlermeldungen
  serialisieren.
- Fehlerobjekte enthalten mindestens `VIServer`, Ziel, Status,
  bereinigte Fehlermeldung, `RunId` und UTC-Zeitstempel.

## Verändernde Operationen

Für jede Änderung an VM, Host, Datastore, Netzwerk oder vSphere-Konfiguration:

- `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]` auf
  Skriptebene verwenden.
- Ziel vor der Änderung eindeutig innerhalb des zugehörigen vCenters
  auflösen. Null oder mehrere unerwartete Treffer kontrolliert ablehnen.
- Vorher-Zustand erfassen und den Sollzustand vergleichen. Ist er bereits
  erreicht, keine Änderung ausführen und `Changed = $false` zurückgeben.
- `ShouldProcess` mit einem eindeutigen Ziel wie
  `vcenter.example/VirtualMachine:vm01` aufrufen.
- Erst innerhalb des freigegebenen `ShouldProcess`-Blocks das verändernde
  PowerCLI-Cmdlet aufrufen. Dessen eigene Rückfrage mit `-Confirm:$false`
  unterdrücken, weil die Bestätigung bereits am äußeren Skript erfolgt ist;
  `-Server $viConnection` weiterhin explizit übergeben.
- Bei `-WhatIf` keinerlei Änderung oder verändernden Postcheck ausführen.
  Ein strukturiertes Plan-/Vorschauergebnis mit `Changed = $false` liefern.
- Nach einer echten Änderung den Zustand über dieselbe Session neu abrufen
  und verifizieren. Nur ein erfolgreich zurückgekehrtes Cmdlet genügt nicht.
- Vorher-/Nachher-Werte, `Changed`, Erfolg und Fehler je Ziel zurückgeben.
- Analyse, Plan und Ausführung bei Remediation logisch trennen, auch wenn alle
  Hilfsfunktionen in derselben `.ps1`-Datei liegen.

## Ergebnisse, Hilfe und Berechtigungen

Jedes PowerCLI-Ergebnisobjekt enthält mindestens:

- `PSTypeName` nach der im Light-Skill festgelegten Konvention;
- `VIServer` als Name der tatsächlich verwendeten Session;
- einen eindeutigen Zielbezeichner;
- `Status` oder `Success`, bei Änderungen zusätzlich `Changed` sowie
  passende Vorher-/Nachher-Werte;
- bereinigte Fehlerdaten, falls zutreffend;
- denselben `RunId` für den gesamten Lauf;
- einen UTC-Zeitstempel.

Fachlogik gibt strukturierte Objekte zurück und verwendet keine
`Format-Table`-/`Format-List`-Cmdlets. Diagnose läuft über `Write-Verbose`,
`Write-Warning` und `Write-Error`; Export und Logs bleiben getrennt.

In Comment-Based Help und besonders `.NOTES` dokumentieren:

- benötigte PowerShell- und PowerCLI-Mindestversion;
- unterstützte bzw. getestete vCenter-/ESXi-Versionen;
- minimal benötigte vSphere-Privileges;
- Authentifizierungs- und Zertifikatsvoraussetzungen;
- interaktives oder unbeaufsichtigtes Betriebsprofil;
- Cleanup-, Logging-, Transcript- und Exitcode-Verhalten.

Die Laufzusammenfassung aus `runtime-contract.md` ergänzt PowerCLI-spezifisch
die Anzahl angeforderter, verbundener, übersprungener und fehlgeschlagener
vCenter sowie die Anzahl übersprungener/nicht erreichbarer vSphere-Ziele.

## Eigenprüfung vor der Übergabe

Zusätzlich zur allgemeinen Light-Selbstprüfung kontrollieren:

- PowerCLI fehlt vollständig, ist zu alt und erfüllt genau die
  Mindestversion;
- interaktiver und unbeaufsichtigter Credential-Pfad verhalten sich wie
  vereinbart und erzeugen im unbeaufsichtigten Modus keinen Prompt;
- ein vCenter erfolgreich, ein vCenter nicht erreichbar und kein vCenter
  erreichbar;
- leere Objektmenge, nicht verbundener Host, fehlende `.ExtensionData` und
  ein fehlerhaftes Einzelziel bei ansonsten erfolgreichem Lauf;
- jedes PowerCLI-Cmdlet besitzt die korrekte explizite `-Server`-Bindung;
- es gibt keine Abhängigkeit von `DefaultVIServer(s)`;
- nur selbst geöffnete Sessions werden auch bei Fehlern getrennt;
- temporäre PowerCLI-Konfiguration wird zurückgesetzt und Zertifikatsprüfung
  nicht stillschweigend deaktiviert;
- `VIServer`, `RunId` und UTC-Zeitstempel stehen in jedem Ergebnisobjekt;
- verändernde Skripte ändern unter `-WhatIf` nichts, sind idempotent und
  bestätigen den Postcheck nach einer echten Änderung;
- genau ein Prozess-Exit am Skriptende und eine vollständige,
  geheimnisbereinigte Laufzusammenfassung sind vorhanden.
