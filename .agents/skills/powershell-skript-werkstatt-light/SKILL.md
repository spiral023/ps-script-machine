---
name: powershell-skript-werkstatt-light
description: Use when - ein Nutzer ein einzelnes, eigenständiges (standalone) PowerShell-Skript in natürlicher Sprache beschreibt und ein schlankes, sofort einsatzbereites Ergebnis erwartet, ohne Pester, PSScriptAnalyzer, vorbereitete Testdaten, Build-Pipeline oder ein Modul zu installieren/bauen. Gilt domänenübergreifend (Dateisystem, Active Directory, Netzwerk, Cloud, Datenbanken, REST-APIs, VMware/PowerCLI usw.), nicht nur für einen Stack. Nicht gedacht für Modul-/Public-Private-Architekturen mit mehreren Dateien.
---

# PowerShell-Skript-Werkstatt (Light)

## Überblick

Liefert handwerklich saubere, produktionsreife PowerShell-Skripte allein
durch Disziplin beim Schreiben - ohne Testframework, Linter oder CI.
Nichts davon muss installiert sein; Qualität entsteht durch Struktur,
Selbstprüfung mit Bordmitteln und ein kurzes Interview vor dem Bauen.
Domänenneutral: Dateisystem, AD, Netzwerk, Cloud, Datenbanken, REST-APIs,
VMware - das Vorgehen ist überall gleich.

**Ergebnis ist immer eine einzelne, eigenständige `.ps1`-Datei
(Standalone-Skript).** Kein Modul, kein `.psd1`/`.psm1`, keine
Public/Private-Ordnerstruktur, kein Import-Zwang - die Datei läuft für
sich mit `pwsh -File .\Skript.ps1 ...` auf jedem Rechner mit passender
PowerShell-Version. Werden mehrere Funktionen gebraucht, leben sie als
interne Hilfsfunktionen in derselben Datei (siehe `Struktur innerhalb
einer Datei`).

Wird bereits ein volles Setup mit Pester/PSScriptAnalyzer/Build-Pipeline
oder einer Modul-Architektur mit mehreren Dateien benötigt: das ist
ausdrücklich nicht der Anwendungsfall dieses Skills.

## Eiserne Regeln

1. **Nie ohne Interview bauen.** Eine Rückfrage kostet Sekunden, ein
   falsch verstandenes Skript kostet den Nutzer den ganzen Tag.
2. **Immer genau eine Standalone-`.ps1`-Datei.** Kein Modul, kein
   `.psd1`/`.psm1`, keine Public/Private-Ordner, kein Dot-Sourcing eigener
   Zusatzdateien - siehe `Struktur innerhalb einer Datei`.
3. **Read-only vs. verändernd sauber trennen** (siehe Phase 1/2) -
   entscheidet über `SupportsShouldProcess`, `-WhatIf`, Bestätigungslogik.
4. **Language Mode ist Pflichtfrage**, nicht optional - siehe
   `Phase 2` und `Language Mode: Constrained vs. Full`.
5. **Sicherheitsregeln** (siehe `Sicherheit`) gelten unverändert, auch ohne
   Analyzer-Gate, das sie sonst erzwingen würde.
6. **Selbst prüfen vor Übergabe** (siehe `Selbstprüfung ohne Zusatzmodule`) -
   der Nutzer soll nie einen Syntaxfehler oder Absturz zu Gesicht bekommen.

### Red Flags - nicht überspringen

| Gedanke                                                                           | Realität                                                                                                                                     |
| --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| "Kein Pester installiert, dann spar ich mir auch die Sorgfalt"                    | Selbstprüfung mit Bordmitteln (`Parser.ParseFile`, `-WhatIf`, manueller Dry-Run) ersetzt das Framework, nicht die Prüfung selbst.            |
| "Language Mode ist Nischenthema, frag ich nicht extra"                            | Auf abgesicherten Endpoints/Jump-Servern bricht ein Full-Language-Mode-Skript sonst erst beim Kunden.                                        |
| "Ich weiß schon, was gemeint ist"                                                 | Geltungsbereich, Ausgabeformat und Fehlerverhalten unterscheiden sich pro Wunsch - trotzdem in Phase 3 zusammenfassen und bestätigen lassen. |
| "Bei einem verändernden Skript reicht diesmal ein Hinweis statt echtem `-WhatIf`" | Vorschau-Lauf ist nicht verhandelbar, unabhängig von Zeitdruck.                                                                              |

## Phase 1: Einordnen

- **Read-only** (Auswertung/Report) oder **verändernd** (Konfiguration,
  Anlage, Löschung, Zustandsänderung)?
- Welche Objekte/Domäne? (Dateien/Ordner, AD-Objekte, Netzwerkgeräte,
  Cloud-Ressourcen, DB-Einträge, REST-Endpunkte, VMs, ...)
- Läuft es interaktiv/einmalig oder später automatisiert (Scheduled Task,
  CI-Runner, Remote-Session, Login-Skript)?
- Zielumgebung frei (eigener Admin-Rechner) oder eingeschränkt (Kiosk,
  verwalteter Endpoint, Jump-Server mit AppLocker/WDAC)? Das entscheidet
  mit über die Language-Mode-Frage in Phase 2.
- Woher kommen die Eingabedaten? Interaktive Parameter, eine CSV-/Textdatei
  mit einer Liste von Zielen, oder eine andere Quelle (API, DB)? Bei
  CSV-Eingabe siehe Pflichtfragen in Phase 2.

## Phase 2: Dynamisches Interview

Eine Frage pro Nachricht, immer mit sinnvollem Standardwert. Pflichtfragen:

- **Geltungsbereich:** Alles oder gefiltert (Name, Pfad, OU, Tag, Cluster, ...)?
- **Ausgabe:** Konsole, CSV/JSON-Export, oder Rückgabeobjekt für die
  Pipeline? Ablageort (Standard: Desktop bzw. aktuelles Verzeichnis)?
- **Fehlerverhalten:** Bei einem nicht erreichbaren/fehlerhaften Einzelziel
  weitermachen und am Ende ausweisen (Standard), oder sofort abbrechen?
- **Language Mode (Pflichtfrage):** "Soll das Skript für den Constrained
  Language Mode optimiert sein (z. B. für abgesicherte, per WDAC/AppLocker
  verwaltete Systeme), oder darf es den Full Language Mode voraussetzen
  (eigener Rechner, Admin-Kontext)?" Standardvorschlag: Full Language Mode -
  außer der Nutzer hat in Phase 1 eine eingeschränkte Zielumgebung genannt,
  dann aktiv und konkret nachfragen. Konsequenzen siehe unten.

Bei VERÄNDERNDEN Skripten zusätzlich verpflichtend:

- Vorschau-Lauf (`-WhatIf`) erklären - immer eingebaut, nicht optional.
- Bestätigung pro Objekt oder einmal für den gesamten Lauf (`-Confirm`)?
- Erwarteter Zustand vorher/nachher, um Idempotenz beurteilen zu können.

Bei CSV-/Datei-Eingabe zusätzlich verpflichtend:

- Welche Spalten sind Pflicht, welche optional? Genaue Spaltennamen
  erfragen, nicht raten.
- Trennzeichen: Komma oder Semikolon (deutsches Excel exportiert meist
  Semikolon)? Standard: an einer echten Beispielzeile erkennen lassen,
  sonst nachfragen.
- Umgang mit fehlerhaften/leeren Zeilen: überspringen und am Ende
  ausweisen (Standard, konsistent mit dem allgemeinen Fehlerverhalten
  oben), oder Abbruch beim ersten Fehler?
- Umgang mit einer leeren Datei (0 Datenzeilen): als Warnung ausweisen,
  nicht stillschweigend "erfolgreich, nichts getan" melden.

## Phase 3: Zusammenfassung & Freigabe (Vertragsstelle)

Vor der Generierung in ein bis zwei Sätzen zusammenfassen: Was wird von
welchem Geltungsbereich gelesen/verändert, wohin exportiert, wie bei
Fehlern reagiert, für welchen Language Mode gebaut und getestet. Erst nach
ausdrücklicher Bestätigung weiterarbeiten; Korrekturen einarbeiten und
erneut zusammenfassen.

## Phase 4: Generierung - Grundgerüst der Standalone-Datei

Ein Skript, eine Datei - kein Funktionsimport, kein Modul. Comment-Based
Help, `param()` und `SupportsShouldProcess` sitzen auf Skript-Ebene direkt
am Dateianfang, nicht in einer separaten, zu importierenden Funktion:

```powershell
#Requires -Version 5.1
# Version an Zielumgebung anpassen; 7.0+ nur fordern, wenn tatsächlich genutzt.

<#
.SYNOPSIS
    Ein Satz, was das Skript tut.
.DESCRIPTION
    Ausführliche Beschreibung inkl. Nebenwirkungen.
.PARAMETER Name
    Beschreibung je Parameter.
.EXAMPLE
    .\Verb-Noun.ps1 -Name 'Beispiel'
.OUTPUTS
    [PSCustomObject] mit PSTypeName 'Custom.Verb-Noun.Result'
.NOTES
    Benötigte Rechte / Voraussetzungen hier dokumentieren.
#>
[CmdletBinding(SupportsShouldProcess)]  # nur bei verändernden Skripten
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter()]
    [guid]$RunId = [guid]::NewGuid()  # ein RunId pro Skriptlauf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-CleanText {
    # Interne Hilfsfunktion(en) bleiben in derselben Datei - kein Dot-Sourcing,
    # kein separates Modul. Nur bei Bedarf, sonst Fachlogik direkt inline.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    return $Value.Trim()
}

try {
    # Precheck: existiert das Ziel, ist es im richtigen Zustand?
    $before = $null  # Vorher-Wert erfassen, falls verändernd

    if ($PSCmdlet.ShouldProcess($Name, 'Aktion beschreiben')) {
        # Fachlogik hier, ruft bei Bedarf interne Hilfsfunktionen auf
        # Postcheck: wurde die Änderung tatsächlich wirksam?
    }

    [PSCustomObject]@{
        PSTypeName = 'Custom.Verb-Noun.Result'
        Name       = $Name
        Before     = $before   # nur bei verändernden Skripten
        After      = $null     # nur bei verändernden Skripten
        Success    = $true
        RunId      = $RunId
        Timestamp  = Get-Date
    }
}
catch {
    Write-Error -ErrorRecord $_
}
```

Für read-only Skripte: kein `SupportsShouldProcess`, kein `ShouldProcess`-Aufruf,
sonst identische Struktur.

## Sicherheit (nicht verhandelbar)

- **Keine fest codierten Zugangsdaten.** `PSCredential`/`Get-Credential`
  verwenden; falls `Microsoft.PowerShell.SecretManagement` bereits
  installiert ist, bevorzugen - sonst `Read-Host -AsSecureString`.
- **Kein `Invoke-Expression`/`iex`.**
- **Externe Eingaben validieren** (`[ValidateScript({Test-Path $_})]`,
  `[ValidateSet()]`, `[ValidateRange()]`).
- **Keine Secrets in Logs/Konsole.**
- **Keine globalen Variablen für Zustand** (`$global:...`).
- **`$ErrorActionPreference = 'SilentlyContinue'`** nie ohne lokalen Scope.
- **Zertifikats-/TLS-Prüfung nie stillschweigend deaktivieren.** Falls für
  eine Testumgebung wirklich nötig, nur explizit im Session-/Process-Scope
  und mit sichtbarem Kommentar warum - niemals als globale Dauerlösung.
- **Keine fest codierten Servernamen, IP-Adressen oder umgebungsspezifischen
  Pfade.** Über Parameter oder Konfiguration übergeben, auch in einem
  Einzelskript - sonst funktioniert es nur auf dem einen Rechner, auf dem
  es entstanden ist.
- **Least Privilege:** Wo Rollen/Berechtigungen für die verwendeten
  Zugangsdaten wählbar sind, die minimal nötigen empfehlen und in
  `.NOTES` dokumentieren.
- **`Set-StrictMode` nie abschalten oder herabstufen**, nachdem es gesetzt
  wurde - auch nicht "nur für diesen einen Codeblock".

## Sprache & Stil

- Genehmigte Verb-Noun-Namen (`Get-Verb` prüfen), keine Fantasienamen.
- PascalCase für Funktionen/Parameter, camelCase für interne Variablen,
  Bool-Präfixe `is`/`has`/`can`/`should`.
- 4 Leerzeichen Einrückung, öffnende `{` in derselben Zeile, immer Klammern
  auch bei Einzeilern.
- Strukturierte Rückgabe als `[PSCustomObject]` mit `PSTypeName`, keine
  `Format-Table`/`Format-List` innerhalb der Fachlogik.
- Sammlungen/Listen: Pluralform, camelCase (`$logEntries`, nicht `$arrLogs`).
- Konstanten: PascalCase oder UPPER_CASE für zentrale, unveränderliche
  Werte (`$DefaultTimeout`, `$MAX_RETRIES`).
- Keine ungarische Notation (`$strName` vermeiden) - stattdessen
  `[string]$name`, falls der Typ betont werden soll.
- Keine kryptischen Kürzel - nur etablierte Akronyme (`ID`, `URL`, `VM`,
  `IP`) verwenden, sonst ausschreiben (`$configPath` statt `$cfgPath`).
- `$_` nur in einfachen, kurzen Pipelines. Bei mehrzeiliger oder
  verschachtelter Logik `foreach ($item in $collection)` verwenden.
- Frühzeitige Rückgabe (`return`) statt tiefer Verschachtelung - lieber
  Vorbedingungen am Anfang mit `return`/`continue` abfangen.
- Der Comment-Based-Help-Header steht direkt vor der Funktion, ohne
  Leerzeile dazwischen.
- Kommentare nur, wo der Code nicht selbsterklärend ist oder ein
  Workaround vorliegt.

## Weitere technische Vorgaben

Zusätzlich zu Struktur und Sicherheit gelten folgende Handwerksregeln -
domänenneutral, ohne dass dafür Zusatzmodule installiert werden müssten.

### Fehlerbehandlung im Detail

- `$ErrorActionPreference = 'Stop'` lokal setzen (Skriptkopf oder im
  jeweiligen `try`-Scope), damit non-terminating Errors von Cmdlets
  überhaupt per `catch` abfangbar werden.
- Jeder Aufruf gegen eine externe Ressource (Datei, Netzwerk, API, DB,
  Remote-Session) steht in `try`/`catch`/`finally` - nie unbehandelt.
- Zustand einer Verbindung/Ressource vor Nutzung prüfen (z. B.
  `ConnectionState`, `IsOpen`, HTTP-Statuscode) statt blind zuzugreifen und
  auf den Fehler zu warten.
- Bei Verarbeitung mehrerer Ziele: ein fehlgeschlagenes Einzelziel wird im
  Ergebnisobjekt als Fehler ausgewiesen und die Verarbeitung läuft weiter
  (Teilfehler stoppen nicht den ganzen Lauf) - außer der Nutzer hat in
  Phase 2 explizit Sofortabbruch gewählt.

### Ressourcen-/Session-Lebenszyklus

Gilt für jede Art von "Verbindung": DB-Connection, PSSession, HTTP-Client/
Token, File-Handle, VIServer-Session, COM-Objekt.

- **Einmal öffnen, wiederverwenden.** Nicht pro Element im Loop neu
  verbinden/authentifizieren.
- **Schließen/Disconnect/Dispose immer im `finally`-Block**, mit
  `-ErrorAction SilentlyContinue` beim Aufräumen selbst, damit ein Fehler
  beim Schließen nicht den eigentlichen Fehler überdeckt:

    ```powershell
    $connection = $null
    try {
        $connection = Open-Resource -Target $Target
        # ... Fachlogik mit $connection ...
    }
    catch {
        Write-Error -ErrorRecord $_
    }
    finally {
        if ($connection) {
            Close-Resource -Connection $connection -ErrorAction SilentlyContinue
        }
    }
    ```

### Datenabruf-Effizienz

- **Massenabruf statt Einzelabruf in Schleifen.** Erst alle Daten einmal
  abrufen (z. B. in eine Hashtable/Lookup), dann in der Schleife nur noch
  im Speicher nachschlagen - keine Remote-/IO-Aufrufe pro Iteration.
- **Erst sammeln, dann verarbeiten.** Kein Schreiben/Exportieren/Aufrufen
  einer externen Ressource innerhalb derselben Schleife, die noch liest.
- **`Write-Progress`** bei absehbar langlaufenden Operationen mit vielen
  Elementen, damit der Nutzer bei einem interaktiven Lauf sieht, dass das
  Skript arbeitet.

### Parameter, Typisierung, Pipeline

- Starke Typisierung für alle Parameter/Variablen (`[string]`, `[int]`,
  `[bool]`, `[datetime]`, konkrete Objekttypen) - kein untypisiertes `$x`.
- `[Parameter()]`-Attribute korrekt einsetzen: `Mandatory`,
  `ValueFromPipeline`, `ValueFromPipelineByPropertyName`, je nachdem ob die
  Funktion einzelne Werte oder Pipeline-Objekte entgegennehmen soll.
- Soll die Funktion Pipeline-Eingaben verarbeiten: `begin`/`process`/`end`
  nutzen, nicht alles in einem Block sammeln.
- `Set-StrictMode -Version Latest` am Skript-/Funktionsanfang - kostenlos
  eingebaut, deckt Tippfehler und nicht initialisierte Variablen früh auf.

### Trennung der vier Ausgabekanäle

Jede Funktion/jedes Skript hält diese vier Kanäle strikt auseinander -
sie dürfen sich nicht gegenseitig ersetzen:

| Kanal             | Zweck                                 | Werkzeug                                                                                                           |
| ----------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Rückgabe/Pipeline | Ergebnis für den Aufrufer             | `[PSCustomObject]` mit `PSTypeName`, `return`/Pipeline-Ausgabe                                                     |
| Diagnose          | Was passiert gerade, für den Bediener | `Write-Verbose`, `Write-Warning`, `Write-Error`                                                                    |
| Export            | Ergebnis in ein Dateiformat           | `ConvertTo-Csv`/`Export-Csv`, `ConvertTo-Json` - vom Aufrufer entschieden, nicht in der Fachlogik erzwungen        |
| Log (optional)    | Nachvollziehbarkeit über die Zeit     | eigener, expliziter Schritt (z. B. strukturierte JSON-Zeile je Lauf), nie vermischt mit Konsolen-/Pipeline-Ausgabe |

Bei CSV-Export für deutsches Excel: Encoding beachten
(`[System.Text.Encoding]::GetEncoding(1252)` statt UTF-8, sonst
Umlaute/Sonderzeichen kaputt).

### CSV-Eingabe verarbeiten

Gilt, sobald das Skript eine Liste von Zielen aus einer Datei liest
(z. B. Hostnamen, VM-Namen, Benutzer) statt sie interaktiv zu erfragen:

- **Pfad validieren**, bevor gelesen wird:
  `[ValidateScript({ Test-Path $_ -PathType Leaf })]` auf dem
  Parameter, nicht erst beim `Import-Csv`-Aufruf scheitern lassen.
- **Trennzeichen und Encoding explizit setzen**, nie dem Zufall
  überlassen: `-Delimiter ';'` für aus deutschem Excel exportierte
  Dateien, `-Delimiter ','` für Standard-CSV; `-Encoding utf8` bei
  UTF-8-Dateien mit BOM, sonst werden Umlaute in Kopfzeile und Werten
  stillschweigend falsch gelesen.
- **Pflichtspalten sofort nach dem Import prüfen**, bevor verarbeitet
  wird - eine fehlende Spalte soll eine klare, sprechende Fehlermeldung
  geben, nicht später einen kryptischen "Eigenschaft nicht gefunden"-Fehler
  mitten in der Verarbeitung.
- **Leere Datei (0 Datenzeilen) explizit behandeln**: Warnung ausgeben,
  nicht als stillschweigenden Erfolg mit leerem Ergebnis durchlaufen
  lassen.
- **Jede Zeile wie ein Einzelziel behandeln**: gleiche Teilfehler-Logik
  wie bei mehreren Zielen (siehe `Fehlerbehandlung im Detail`) - eine
  fehlerhafte oder unvollständige Zeile wird übersprungen und im
  Ergebnis als Fehler ausgewiesen, der Rest der Datei läuft weiter.

```powershell
$requiredColumns = @('Name', 'Cluster')

if (-not (Test-Path -LiteralPath $InputCsvPath -PathType Leaf)) {
    throw "CSV-Datei nicht gefunden: $InputCsvPath"
}

$rows = Import-Csv -LiteralPath $InputCsvPath -Delimiter ';' -Encoding utf8

if (-not $rows) {
    Write-Warning "CSV-Datei enthält keine Datenzeilen: $InputCsvPath"
    return
}

$missingColumns = $requiredColumns | Where-Object { $_ -notin $rows[0].PSObject.Properties.Name }
if ($missingColumns) {
    throw "Pflichtspalten fehlen in der CSV-Datei: $($missingColumns -join ', ')"
}

foreach ($row in $rows) {
    try {
        # Fachlogik pro Zeile, z. B. $row.Name / $row.Cluster verwenden
    }
    catch {
        Write-Warning "Zeile fehlerhaft ($($row.Name)): $($_.Exception.Message)"
        # als Fehler-Ergebnisobjekt ausweisen, weiter zur nächsten Zeile
        continue
    }
}
```

### Auditierbarkeit: was in jedes Ergebnisobjekt gehört

Jedes zurückgegebene `[PSCustomObject]` bekommt zusätzlich zu den
Fachdaten:

- `PSTypeName` nach Konvention `<Bereich>.<Verb-Noun>.Result`.
- `Timestamp` (`Get-Date`) - wann ist das passiert.
- `RunId` (z. B. `[guid]::NewGuid()`, einmal pro Skriptlauf erzeugt und an
  alle Ergebnisobjekte desselben Laufs durchgereicht) - damit mehrere
  Zeilen/Exporte eindeutig demselben Lauf zuordenbar sind, auch ohne
  zentrales Logging.

### Verändernde Funktionen: Vorher/Nachher, Precheck, Postcheck, Zielvalidierung

Zusätzlich zu `SupportsShouldProcess`/`-WhatIf` (siehe Grundgerüst) gilt
für jede verändernde Funktion:

- **Precheck:** Ziel existiert, ist erreichbar, ist im erwarteten
  Ausgangszustand - sonst kontrolliert abbrechen/überspringen statt blind
  zu ändern.
- **Eindeutige Zielvalidierung:** entweder genau ein Ziel adressieren oder
  Mehrfachverarbeitung explizit vorsehen (z. B. Array-Parameter mit
  `foreach` und Einzel-Ergebnisobjekt pro Ziel) - nie implizit "irgendein
  passendes Objekt" treffen.
- **Postcheck:** nach der Änderung verifizieren, dass sie tatsächlich wie
  erwartet eingetreten ist (nicht nur, dass der Aufruf keinen Fehler
  geworfen hat).
- **Vorher-/Nachher-Werte im Ergebnisobjekt** (`Before`/`After`
  oder passende Fachnamen), damit der Nutzer ohne Logdatei sieht, was sich
  geändert hat.
- **Möglichst idempotent:** ein zweiter Lauf mit denselben Parametern
  ändert nichts mehr und meldet das auch so (`Success = $true`,
  `Changed = $false`).

### Verändernde Skripte: Test-Get-Invoke-Muster

Bei Remediation-artigen Aufgaben (Ist-Zustand → Soll-Zustand herstellen)
in Phasen trennen, statt Lesen und Ändern zu vermischen:

1. **Analyse** (read-only): Ist-Zustand einlesen.
2. **Plan** (read-only): Ist mit Soll vergleichen, Änderungsplan bauen.
3. **Invoke** (verändernd): Plan ausführen, immer zuerst mit `-WhatIf`
   testbar, `SupportsShouldProcess` + `ConfirmImpact` passend zur Tragweite.

### Struktur innerhalb einer Datei (kein Modul)

Dieser Skill erzeugt ausschließlich einzelne Standalone-Skripte - kein
`.psd1`/`.psm1`, keine Public/Private-Ordner, kein Dot-Sourcing anderer
Dateien, kein `Import-Module` eines selbst gebauten Moduls. Braucht der
Nutzer eine echte Mehrdatei-Modularchitektur, ist das ausdrücklich nicht
der Anwendungsfall (siehe Überblick).

Innerhalb der einen Datei trotzdem sauber trennen:

- Reihenfolge im Skript: `#Requires` → Comment-Based Help → `param()` →
  `Set-StrictMode`/`$ErrorActionPreference` → interne Hilfsfunktionen →
  Hauptlogik (`try`/`catch`) ganz unten.
- Interne Hilfsfunktionen (z. B. eine Formatierungs- oder
  Validierungsfunktion) klar von der Hauptlogik abgegrenzt, mit eigenem
  aussagekräftigem Namen - aber alle in derselben Datei definiert.
- Keine 200-Zeilen-Blöcke ohne jede Funktionsgrenze: auch innerhalb einer
  einzelnen Datei wird sich wiederholende oder in sich geschlossene Logik
  in eine benannte Hilfsfunktion ausgelagert, nicht linear aneinandergereiht.
- Externe Abhängigkeiten (andere Skripte, Module) nur über bereits
  installierte, im Interview genannte Module - nie über eigene, separat zu
  pflegende Zusatzdateien.

### Ergänzung für VMware/PowerCLI-Ziele

Zusätzlich zu den obigen, domänenneutralen Regeln gilt bei
PowerCLI-Skripten (vCenter/ESXi-Automatisierung):

- **Explizite `-Server`-Übergabe an jedes PowerCLI-Cmdlet**, statt auf
  einen impliziten globalen Default-Server zu vertrauen - sonst
  arbeitet das Skript bei mehreren gleichzeitig verbundenen vCentern
  unbemerkt gegen das falsche.
- **Einmal verbinden (`Connect-VIServer`), Session wiederverwenden**,
  Trennen (`Disconnect-VIServer -Confirm:$false`) im `finally`-Block -
  folgt 1:1 dem `Ressourcen-/Session-Lebenszyklus` oben.
- **Für unbeaufsichtigte Läufe konfigurieren**, damit kein interaktiver
  Prompt den Lauf blockiert:
  `Set-PowerCLIConfiguration -Scope Session -ParticipateInCEIP $false -Confirm:$false`
  (Zertifikatsverhalten dabei gemäß der Sicherheitsregel oben behandeln,
  nicht stillschweigend global auf "ignorieren" stellen).
- **Massenabruf statt Einzelabruf pro CSV-Zeile/Ziel**: z. B. einmal
  `Get-VMHost`/`Get-VM` für alle Objekte holen und in einer Hashtable
  nach Namen nachschlagen, statt pro Zeile erneut gegen vCenter zu
  fragen - folgt der `Datenabruf-Effizienz`-Regel oben.
- **Nicht gefundene Namen** (Tippfehler in der CSV, zwischenzeitlich
  gelöschtes Objekt) als Teilfehler im Ergebnisobjekt ausweisen, nicht
  das ganze Skript abbrechen.
- **`ConnectionState` je Host prüfen, bevor abgefragt wird**: Hosts im
  Wartungsmodus oder getrennte Hosts liefern sonst kryptische Fehler
  mitten in der Verarbeitung statt einer sprechenden Zeile im Ergebnis:

  ```powershell
  foreach ($vmHost in $vmHosts) {
      if ($vmHost.ConnectionState -ne 'Connected') {
          Write-Warning "$($vmHost.Name) ist nicht verbunden (Status: $($vmHost.ConnectionState)), wird übersprungen."
          continue
      }
      # ... eigentliche Abfrage nur für verbundene Hosts ...
  }
  ```

- **`Get-View`/`.ExtensionData` für Properties, die keine Cmdlets
  liefern** (z. B. CDP-Nachbarschaftsinformationen, detaillierte
  Hardware-/Konfigurationsdaten):

  ```powershell
  $networkSystem = Get-View -Id $vmHost.ExtensionData.ConfigManager.NetworkSystem -Server $viConnection
  $networkHints = $networkSystem.QueryNetworkHint([string[]]@())
  ```

- **Mehrere vCenter gleichzeitig verbunden:** über das Array der
  Verbindungen iterieren, nie stillschweigend nur die erste/letzte
  verwenden, und **jedes Ergebnisobjekt bekommt eine `VIServer`-Property**
  mit dem Namen des vCenters, aus dem es stammt - sonst sind Ergebnisse
  aus mehreren vCentern in einer gemeinsamen Ausgabe/Export nicht mehr
  eindeutig zuordenbar:

  ```powershell
  foreach ($viConnection in $viConnections) {
      $vmHosts = Get-VMHost -Server $viConnection
      foreach ($vmHost in $vmHosts) {
          [PSCustomObject]@{
              PSTypeName = 'Custom.Verb-Noun.Result'
              VIServer   = $viConnection.Name
              VMHost     = $vmHost.Name
              # ... weitere Fachdaten ...
          }
      }
  }
  ```

## Language Mode: Constrained vs. Full

|                                                                                           | Full Language Mode                                          | Constrained Language Mode                                                                                                 |
| ----------------------------------------------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Wann                                                                                      | Eigener Rechner, Admin-Kontext, keine WDAC/AppLocker-Policy | Abgesicherte/verwaltete Endpoints, Jump-Server, Kiosk-Systeme                                                             |
| `Add-Type`, COM (`New-Object -ComObject`)                                                 | erlaubt                                                     | **blockiert**                                                                                                             |
| `New-Object`/Typumwandlung auf beliebige .NET-Klassen                                     | erlaubt                                                     | nur auf eine kleine Kernliste (`string`, `int`, `bool`, `datetime`, `pscustomobject`, `hashtable`, `array`, `xml`, ...)   |
| Methodenaufrufe auf beliebige .NET-Objekte                                                | erlaubt                                                     | nur auf Objekte der Kernliste; kompilierte Cmdlets/Module funktionieren weiter, da sie außerhalb des Language Mode laufen |
| Dynamisch aus Strings gebaute Scriptblocks (`[scriptblock]::Create`, `Invoke-Expression`) | technisch möglich (aber ohnehin verboten, s. o.)            | **blockiert**                                                                                                             |
| Reflection, `$ExecutionContext`-Tricks                                                    | erlaubt                                                     | **blockiert**                                                                                                             |

Konsequenz beim Schreiben für Constrained Language Mode:

- Nur eingebaute Cmdlets und Module verwenden, keine direkte
  .NET-Instanziierung/-Methodenaufrufe außerhalb der Kernliste.
- Braucht die Aufgabe zwingend `Add-Type`/COM/Reflection: das dem Nutzer
  transparent machen und ggf. auf Full Language Mode zurückfragen, statt
  eine Konstruktion zu bauen, die dort ohnehin nicht laufen wird.
- Kein `Invoke-Expression` und keine dynamisch gebauten Scriptblocks
  (gilt hier ohnehin bereits als Sicherheitsregel).

Testen ohne irgendetwas zu installieren (nur PowerShell selbst nötig):

```powershell
pwsh -NoProfile -Command '$ExecutionContext.SessionState.LanguageMode = "ConstrainedLanguage"; & "<Pfad-zum-Skript>.ps1" -WhatIf'
```

Das erzwingt den Language Mode nur in diesem Wegwerf-Prozess (keine
Gruppenrichtlinie/WDAC-Konfiguration nötig) und lässt jeden nicht
erlaubten Typ-/Methodenaufruf sofort als Laufzeitfehler sichtbar werden.

Wurde Full Language Mode gewählt: keine Einschränkungen über die
allgemeinen Standards hinaus - `Add-Type`/COM trotzdem nur einsetzen, wenn
wirklich nötig, falls das Skript später doch auf einem eingeschränkten
System landet.

## Selbstprüfung ohne Zusatzmodule

Kein Pester, kein PSScriptAnalyzer, keine Testdaten nötig - nur was
PowerShell selbst mitbringt:

1. **Syntaxprüfung** (eingebauter Parser, kein Import nötig):

    ```powershell
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile('<Pfad>.ps1', [ref]$null, [ref]$errors)
    $errors
    ```

2. **Manueller Dry-Run:** verändernde Skripte mit `-WhatIf` aufrufen,
   read-only Skripte gegen ein einzelnes, harmloses reales Ziel testen -
   keine vorbereiteten Testdatensätze nötig.
3. **Language-Mode-Test** wie oben, falls Constrained Language Mode
   verlangt wurde.
4. **Edge Cases von Hand durchdenken** (Ersatz für die Pester-Testfälle,
   die es hier nicht gibt) - für das Skript gedanklich oder mit einem
   echten Kleinstfall durchspielen:
   - regulärer Erfolgsfall
   - ungültiger/fehlender Parameter
   - leeres Ergebnis (kein Treffer)
   - nicht erreichbares/nicht vorhandenes Ziel
   - mehrere Ziele, eines davon fehlerhaft (Teilfehler)
   - fehlende/unvollständige Daten am Ziel
   - `-WhatIf` bei verändernden Skripten (siehe oben)
   - zweiter Lauf mit gleichen Parametern (Idempotenz)
5. Definition of Done (unten) Punkt für Punkt durchgehen.

## Definition of Done (Light)

- [ ] Eine einzelne `.ps1`-Datei, kein Modul/`.psd1`/`.psm1`, kein
      Dot-Sourcing/`Import-Module` einer selbst gebauten Zusatzdatei
- [ ] `#Requires -Version` passend zur Zielumgebung gesetzt
- [ ] `[CmdletBinding()]`, bei verändernden Funktionen zusätzlich `SupportsShouldProcess`
- [ ] Genehmigter Verb-Noun-Name
- [ ] Vollständige Comment-Based Help (`SYNOPSIS`, `DESCRIPTION`, `PARAMETER`, `EXAMPLE`, `OUTPUTS`, `NOTES`)
- [ ] Parameter validiert
- [ ] `try`/`catch` vorhanden, strukturiertes `PSCustomObject` mit `PSTypeName` als Rückgabe
- [ ] Keine fest codierten Zugangsdaten, kein `Invoke-Expression`
- [ ] Language-Mode-Anforderung erfragt, umgesetzt und getestet
- [ ] `Parser.ParseFile` fehlerfrei, manueller Dry-Run durchgeführt
- [ ] `$ErrorActionPreference = 'Stop'` und `Set-StrictMode -Version Latest` gesetzt
- [ ] Ressourcen/Sessions werden im `finally`-Block geschlossen
- [ ] Massenabruf statt Einzelabruf in Schleifen, keine Remote-/IO-Aufrufe pro Iteration
- [ ] Vier Ausgabekanäle (Rückgabe, Diagnose, Export, Log) sauber getrennt
- [ ] Bei Remediation-Skripten: Test-Get-Invoke-Phasentrennung eingehalten
- [ ] `RunId` und `Timestamp` in jedem Ergebnisobjekt
- [ ] Bei verändernden Funktionen: Precheck, eindeutige Zielvalidierung,
      Postcheck und Vorher-/Nachher-Werte vorhanden
- [ ] Keine fest codierten Servernamen/IPs/Pfade, keine stillschweigend
      deaktivierte Zertifikatsprüfung
- [ ] Edge Cases von Hand durchgespielt (Erfolg, ungültiger Parameter,
      leeres Ergebnis, nicht erreichbares Ziel, Teilfehler, Idempotenz)
- [ ] Bei CSV-Eingabe: Pfad validiert, Pflichtspalten geprüft, Trennzeichen/
      Encoding explizit gesetzt, leere Datei behandelt, fehlerhafte Zeilen
      als Teilfehler ausgewiesen
- [ ] Bei PowerCLI-Zielen: `-Server` explizit an jedes Cmdlet übergeben,
      `Set-PowerCLIConfiguration` für unbeaufsichtigte Läufe gesetzt
- [ ] Bei PowerCLI-Zielen: `ConnectionState` je Host geprüft, bei mehreren
      vCentern `VIServer`-Property in jedem Ergebnisobjekt vorhanden
- [ ] Abgleich gegen Zusammenfassung aus Phase 3: jede Zusage erfüllt

## Phase 6: Übergabe

Kurze Anleitung an den Nutzer: Wo liegt das Skript (eine einzelne
`.ps1`-Datei, kein Modul, keine weiteren Dateien nötig), wie startet man
es (`pwsh -File .\Skript.ps1 ...`), was wird es fragen/tun, wo landet die
Ausgabe, und für welchen Language Mode wurde es gebaut und getestet.
