# Agent Instructions – ps-script-machine

> **Zentrale Regelbasis für alle Coding Agents.**
> Agent-spezifische Dateien (`CLAUDE.md`, `.github/copilot-instructions.md`) verweisen auf diese Datei.

## Verhältnis zu den Skills (eine Quelle je Thema)

Damit Regeln nicht doppelt und widersprüchlich gepflegt werden, gilt eine
klare Arbeitsteilung:

- **Diese Datei (`AGENTS.md`)** ist die *maßgebliche* Quelle für die
  **projektspezifischen Mandate**: Versionen, Verzeichnisstruktur,
  Namenskonventionen, Definition of Done, Code-Coverage-Schwelle,
  Build-Prozess und Vorgehen. Bei Konflikten gewinnt diese Datei.
- Der Skill **`vmware-powercli-scripts`**
  (`.agents/skills/vmware-powercli-scripts/`) ist die *Vertiefung*:
  allgemeines PowerCLI-Handwerk mit Falsch/Richtig-Codebeispielen und
  Begründungen zu Security, Fehlerbehandlung, Verbindungsverwaltung, Tests,
  State-Change und modularer Architektur. Für das *Warum* und *Wie* der
  Standards in §5–§10 dort nachschlagen.
- Der Skill **`script-werkstatt`** (`.agents/skills/script-werkstatt/`) ist
  der *Prozess*, um aus einer natürlichsprachlichen Beschreibung ein
  fertiges Skript zu erzeugen (siehe unten).

## 1. Ziel

Dieses Repository ist eine professionelle Entwicklungsplattform und Vorlage für Coding Agents, die hochwertige PowerShell- und PowerCLI-Skripte für VMware-Administratoren erstellen.

Neue Skripte müssen standardmäßig sein:

- **sicher** – keine fest codierten Zugangsdaten, keine `Invoke-Expression`
- **modular** – Public/Private-Trennung, Wiederverwendbarkeit
- **verständlich** – vollständige Comment-Based Help, klare Namen
- **testbar** – Pester-5-Tests für alle Funktionen
- **dokumentiert** – SYNOPSIS, DESCRIPTION, EXAMPLES, OUTPUTS, NOTES
- **pipelinefähig** – Pipeline-Eingabe/Ausgabe wo fachlich sinnvoll
- **auditierbar** – strukturierte Ergebnisobjekte, Run-ID, Zeitstempel
- **PowerShell-7.4-kompatibel** – `#Requires -Version 7.4`
- **für VMware-Umgebungen geeignet** – explizite `-Server`-Übergabe

### Skript-Werkstatt (natürlichsprachliche Erstellung)

Für Skript-Wünsche in natürlicher Sprache gilt der Workflow in
`.agents/skills/script-werkstatt/SKILL.md` (Interview → Freigabe →
Generierung → Build → Übergabe). Interaktive Wrapper entstehen aus
`templates/InteractiveWrapper.ps1` in `scripts/tools/` und werden vom
Build-Task `Standalone` zusätzlich als Einzeldatei nach `build/standalone/`
gebündelt.

## 2. Voraussetzungen

| Komponente | Version |
|---|---|
| PowerShell | 7.4 oder neuer |
| PowerCLI | 13.2.0 oder neuer |
| Pester | 5.0 oder neuer |
| PSScriptAnalyzer | aktuell |
| vCenter | 7.0, 8.0 |
| ESXi | 7.0, 8.0 |

## 3. Verzeichnisstruktur

```text
src/ps-script-machine/
  Public/          – Öffentliche Funktionen (exportiert)
  Private/         – Private Hilfsfunktionen (nicht exportiert, aber für Tests sichtbar)
  Classes/         – PowerShell-Klassen (optional)
  ps-script-machine.psd1 – Modulmanifest
  ps-script-machine.psm1 – Root-Modul

scripts/           – Wrapper-Skripte und Build-Skripte
tests/
  Unit/            – Pester-5-Unit-Tests (PowerCLI gemockt)
  Integration/     – Integrationstests (nur bei expliziter Aktivierung)
  Acceptance/      – Abnahmetests (Manifest, Sicherheit, Import)

templates/         – Vorlagen für neue Funktionen und Skripte
config/            – Beispielkonfigurationen
docs/              – Architekturdokumentation
examples/          – Anwendungsbeispiele
build/             – Build-Output (gitignored)
.github/           – CI/CD, Issue-Templates, PR-Template
```

## 4. Namenskonventionen

- **Funktionen**: Verwende genehmigte Verb-Noun-Namen (`Get-VMHostDetail`, `Set-VMHostNetwork`).
  - Verfügbare Verben: `Get-`, `Set-`, `New-`, `Remove-`, `Start-`, `Stop-`, `Restart-`, `Test-`, `Export-`, `Import-`
  - Verwende `Get-Verb` zur Überprüfung.
- **Dateien**: Eine Funktion pro Datei. Dateiname = Funktionsname.
- **Klassen**: PascalCase, im `Classes/`-Verzeichnis.
- **Variablen**: PascalCase für Parameter und öffentliche Variablen, camelCase für interne.
- **PSTypeName**: `ps-script-machine.<FunctionName>` für Ergebnisobjekte.

## 5. PowerShell-Standards

### Alle öffentlichen Funktionen müssen:

- `[CmdletBinding()]` verwenden
- Genehmigte Verb-Noun-Namen besitzen
- Vollständige Comment-Based Help enthalten (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.INPUTS`, `.OUTPUTS`, `.NOTES`, `.LINK`)
- Parameter validieren (`[ValidateNotNullOrEmpty()]`, `[ValidateRange()]`, `[ValidateSet()]`, etc.)
- Strukturierte Objekte zurückgeben (`[PSCustomObject]` mit `PSTypeName`)
- Pipeline-Nutzung ermöglichen, sofern fachlich sinnvoll
- Keine Formatierungs-Cmdlets (`Format-Table`, `Format-List`) innerhalb der Fachlogik verwenden
- Fehler nachvollziehbar behandeln (`try`/`catch`/`finally`)
- Keine globalen Zustände voraussetzen

### Read-only `Get-*`-Funktionen:

- **Kein** `SupportsShouldProcess` (nicht erforderlich, da keine Änderungen)

### Verändernde Funktionen müssen:

```powershell
[CmdletBinding(
    SupportsShouldProcess,
    ConfirmImpact = 'High'
)]
```

Zusätzlich erforderlich:
- Prechecks (Ziel existiert, ist erreichbar, ist im richtigen Zustand)
- Eindeutige Zielvalidierung (genau ein Ziel oder explizite Mehrfachverarbeitung)
- `-WhatIf` und `-Confirm` Unterstützung
- Postchecks (Veränderung wurde wie erwartet durchgeführt)
- Nachvollziehbare Vorher-/Nachher-Werte im Ergebnisobjekt
- Kontrolliertes Verhalten bei Teilfehlern (ein Fehler bricht nicht alle Operationen ab)
- Möglichst idempotentes Verhalten (zweite Ausführung ändert nichts)

## 6. VMware-/PowerCLI-Standards

- **Explizite `-Server`-Übergabe**: Alle PowerCLI-Cmdlets müssen `-Server` erhalten.
- **Kein globaler Default-VIServer**: Nicht auf `$global:DefaultVIServer` vertrauen.
- **VIServer in Ergebnisobjekten**: Jedes Ergebnisobjekt enthält die `VIServer`-Eigenschaft.
- **Mehrere vCenter-Verbindungen**: Eindeutig behandeln, iterieren über `$VIServer`-Array.
- **Nicht erreichbare Hosts**: Kontrolliert verarbeiten, Warning ausgeben, fortfahren.
- **API-Aufrufe minimieren**: Batch-Operationen wo möglich.
- **Keine Remote-Aufrufe in Schleifen**: Daten sammeln, dann verarbeiten.
- **Berechtigungen dokumentieren**: In `.NOTES` der Funktion angeben.
- **Zertifikate**: Niemals stillschweigend deaktivieren. Nur im Session-Scope mit Dokumentation.
- **PowerCLI-Konfiguration**: Nur im Process- oder Session-Scope verändern.

## 7. Sicherheitsregeln

- **Keine fest codierten Zugangsdaten**: Niemals Passwörter, Servernamen oder Umgebungswerte im Code.
- **PSCredential**: Immer `[System.Management.Automation.PSCredential]` verwenden.
- **SecretManagement**: `Microsoft.PowerShell.SecretManagement` als empfohlene Option.
- **Keine Klartextpasswörter**: Niemals Passwörter in Klartext im Code oder Logs.
- **Keine sensiblen Daten in Logs**: Logs enthalten keine Passwörter oder Credentials.
- **Keine `Invoke-Expression`**: Verboten. Verwende sichere Alternativen.
- **Externe Pfade validieren**: `[ValidateScript({Test-Path $_})]` oder manuelle Validierung.
- **Least Privilege**: vCenter-Rollen mit minimalen Berechtigungen.

## 8. Verbotene Konstrukte

- `Invoke-Expression`
- `iex`
- Fest codierte Passwörter, Servernamen, IP-Adressen
- `Format-Table`/`Format-List` in Fachlogik
- Globale Variablen für Zustände (`$global:...`)
- `Set-StrictMode` deaktivieren
- Zertifikatsprüfung stillschweigend deaktivieren
- `$ErrorActionPreference = 'SilentlyContinue'` ohne lokalen Scope

## 9. Logging und Ausgabe

- **Ergebnisobjekte**: Strukturierte `PSCustomObject`-Objekte mit `PSTypeName`.
- **Konsolenausgabe**: `Write-Verbose`, `Write-Warning`, `Write-Error` für Diagnose.
- **Logs**: `Write-ModuleLog` für strukturierte JSON-Logs (optional mit Logdatei).
- **Exporte**: `Export-ModuleData` für CSV/JSON-Export. Vollständiger Pfad wird zurückgegeben.

Trennung:
- Ergebnisobjekte → Pipeline/Return
- Konsolenausgabe → Write-Verbose/Warning/Error
- Logs → Write-ModuleLog
- Exporte → Export-ModuleData

## 10. Tests

### Unit-Tests (Pester 5)

Erforderlich für:
- Reguläre Erfolgsfälle
- Ungültige Parameter
- Leere Ergebnisse
- Nicht erreichbare vCenter und Hosts
- Mehrere vCenter-Verbindungen
- Fehlende CDP-Daten / fehlende Daten
- Teilfehler
- `-WhatIf` (für verändernde Funktionen)
- Idempotentes Verhalten
- Korrekte Ergebnisobjekte

PowerCLI-Cmdlets müssen in Unit-Tests gemockt werden.

### Integrationstests

- Nur nach expliziter Aktivierung (`$env:PS_SCRIPT_MACHINE_INTEGRATION_TESTS = 'true'`)
- Niemals versehentlich gegen Produktion
- Nur gegen Test-/Lab-Umgebungen

### Code-Coverage

- Mindestwert: 80%
- Kritische Funktionen müssen besonders gut getestet sein

## 11. Definition of Done

Eine Funktion ist erst fertig, wenn:

- [ ] `#Requires -Version 7.4` vorhanden
- [ ] `[CmdletBinding()]` vorhanden
- [ ] Genehmigter Verb-Noun-Name
- [ ] Vollständige Comment-Based Help
- [ ] Parameter validiert
- [ ] Strukturierte Ergebnisobjekte mit `PSTypeName`
- [ ] `VIServer` in Ergebnisobjekten
- [ ] Zeitstempel und `RunId` in Ergebnisobjekten
- [ ] Explizite `-Server`-Übergabe an PowerCLI-Cmdlets
- [ ] Fehlerbehandlung mit `try`/`catch`
- [ ] Keine fest codierten Werte
- [ ] Keine `Invoke-Expression`
- [ ] Pester-5-Tests vorhanden und erfolgreich
- [ ] PSScriptAnalyzer ohne nicht begründete Fehler
- [ ] Code-Coverage ≥ 80%
- [ ] Dokumentation aktualisiert

## 12. Vorgehen bei neuen Funktionen

1. **Vorlage wählen**: `templates/PublicFunction.ps1` (read-only) oder `templates/ChangeScript.ps1` (verändernd)
2. **Funktion erstellen**: In `src/ps-script-machine/Public/` oder `Private/`
3. **Test erstellen**: In `tests/Unit/` mit `templates/PesterTest.Tests.ps1` als Vorlage
4. **PowerCLI-Cmdlets mocken**: In Unit-Tests
5. **Build ausführen**: `.\scripts\Invoke-Build.ps1`
6. **Dokumentation aktualisieren**: README, CHANGELOG
7. **Pull Request**: Mit PR-Template-Checkliste

Alternativ: `.\scripts\New-PowerCLITool.ps1` für automatische Generierung.

## 13. Build-Prozess

```powershell
# Vollständiger Build
.\scripts\Invoke-Build.ps1

# Nur Analyzer
.\scripts\Invoke-Build.ps1 -Task Analyze

# Nur Tests
.\scripts\Invoke-Build.ps1 -Task Test

# Mit Coverage-Schwellwert
.\scripts\Invoke-Build.ps1 -CodeCoverageThreshold 90
```

Der Build-Prozess führt aus:
1. Modulmanifest validieren
2. PSScriptAnalyzer
3. Pester-Unit-Tests
4. Code-Coverage
5. Dokumentationsprüfung
6. Modul-Build
7. Geheimnis-Scan

Ein Fehler in einem Schritt schlägt den gesamten Build fehl.