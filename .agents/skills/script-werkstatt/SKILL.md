---
name: script-werkstatt
description: Erstellt aus einer deutschen Beschreibung eines VMware-Administrators ein fertiges, getestetes PowerCLI-Skript mit interaktivem Multi-vCenter-Menü. Trigger - ein Nutzer beschreibt ein gewünschtes Skript in natürlicher Sprache ("Schreibe ein Script, das ...", "Ich brauche eine Auswertung ...", "Erstelle mir ein Tool ...") für vSphere/vCenter/ESXi-Aufgaben.
license: MIT
metadata:
  author: custom
  version: "1.0.0"
---

# Skript-Werkstatt: Von der Beschreibung zum fertigen Skript

Du führst einen VMware-Administrator OHNE Programmierkenntnisse von seiner
deutschen Beschreibung zu einem fertigen, getesteten PowerCLI-Skript.

## Eiserne Regeln

1. **Fachsprache, nie Code-Sprache.** Alle Fragen und Erklärungen in
   VMware-Begriffen (Hosts, Cluster, VMs, Portgroups, Datastores).
   Niemals nach Parametertypen, Funktionen oder Code-Details fragen.
   Der Admin muss zu keinem Zeitpunkt Code lesen.
2. **Alle Standards aus AGENTS.md gelten unverändert** (Tests, Coverage,
   Sicherheit, Comment-Based Help, Definition of Done).
3. **Read-only vs. verändernd sauber trennen.** Bei verändernden Skripten
   sind die Sicherheitsfragen (Phase 2) verpflichtend und das Skript
   bekommt SupportsShouldProcess gemäß templates/ChangeScript.ps1.
4. **Build-Fehler behebst du selbst.** Der Admin sieht davon nichts.

## Phase 1: Verstehen

Ordne den Wunsch ein, bevor du fragst:

- Lesend (Auswertung/Report) oder verändernd (Konfiguration/Aktion)?
- Welche vSphere-Objekte? (Hosts, VMs, Netzwerk, Storage, Cluster, ...)
- Gibt es schon eine passende Modul-Funktion? Prüfe
  `Get-Command -Module ps-script-machine` bzw. `src/ps-script-machine/Public/`.
  Falls ja: nur neuen Wrapper bauen, keine neue Funktion.

## Phase 2: Dynamisches Interview

Stelle so viele Fragen wie nötig, um ein gemeinsames Verständnis zu
erreichen - nicht mehr. Eine Frage pro Nachricht, immer mit sinnvollem
Standardwert. Fragenkatalog als Inspiration (situativ auswählen/ergänzen):

- **Geltungsbereich:** Alle Hosts/VMs oder gefiltert (Cluster, Name)?
  Auch Objekte im Wartungsmodus / ausgeschaltete VMs?
- **Ausgabe:** CSV, JSON oder beides? Ablageort (Standard: Desktop)?
  Welche Spalten sind wichtig?
- **Fehlerverhalten:** Wenn ein Host/vCenter nicht antwortet - weitermachen
  und am Ende ausweisen (Standard) oder abbrechen?
- **Nutzung:** Einmalig/gelegentlich interaktiv oder regelmäßig automatisch
  (dann Parameter-Betrieb mit -NonInteractive erwähnen)?

Bei VERÄNDERNDEN Skripten zusätzlich verpflichtend:

- Vorschau-Lauf (-WhatIf) erklären und anbieten - immer eingebaut.
- Bestätigung pro Objekt oder einmal pro Lauf?
- Was ist der erwartete Zustand vorher/nachher?

## Phase 3: Zusammenfassung und Freigabe (Vertragsstelle)

Fasse VOR der Generierung auf Deutsch zusammen:

> Das Skript wird: [was] von [Geltungsbereich] aus [vCentern] auslesen,
> als [Format] nach [Ort] exportieren. Bei nicht erreichbaren Servern:
> [Verhalten]. Es verändert nichts / Es verändert [was] mit Vorschau und
> Bestätigung.

Erst nach ausdrücklicher Bestätigung weiterarbeiten. Korrekturen einarbeiten
und erneut zusammenfassen.

## Phase 4: Generierung

1. **Modul-Funktion** (nur falls keine passende existiert):
   `.\scripts\New-PowerCLITool.ps1 -FunctionName '<Verb-Noun>' -Type <ReadOnly|Change> -Synopsis '<Kurzbeschreibung>'`
   Dann Fachlogik implementieren; Ergebnisobjekte als PSCustomObject mit
   PSTypeName, VIServer-, Timestamp-, RunId-Property (Contract-Test!).
   Die Funktion nimmt Sessions über `-VIServer` entgegen (wie
   Get-CdpNetworkInfo), NICHT Server-String + Credential.
2. **Wrapper**: `templates/InteractiveWrapper.ps1` nach
   `scripts/tools/<Export|Get>-<Name>.ps1` kopieren und die Platzhalter
   füllen (`__TOOL_NAME__`, `__TOOL_SYNOPSIS__`, `__TOOL_DESCRIPTION__`,
   `tool-questions`-Region, `__RESULT_CALL__`).
   Referenz-Beispiel: `scripts/tools/Export-CdpInformation.ps1`.
   Die Marker `#region module-import`/`#endregion module-import` und den
   param-Block NIEMALS entfernen (Vertrag mit dem Standalone-Build).
   Toolspezifische Fragen in der `tool-questions`-Region nutzen einfaches
   `Read-Host` mit Standardwert (Enter = Standard) - NICHT `Read-MenuChoice`,
   das ist eine private, modul-interne Funktion und im Wrapper nicht aufrufbar.
   Für ein VERÄNDERNDES Tool außerdem den `.NOTES`-Hinweis
   "Read-only: ..." aus `templates/InteractiveWrapper.ps1` entfernen bzw.
   passend umformulieren - solche Tools folgen `templates/ChangeScript.ps1`
   mit SupportsShouldProcess.
3. **Pester-Tests** für neue Modul-Funktionen nach dem Muster der
   bestehenden Tests in `tests/Unit/` (TestHelpers.ps1 dot-sourcen,
   Mocks mit -ModuleName).

## Phase 5: Qualitätssicherung

`.\scripts\Invoke-Build.ps1` ausführen. ALLE Tasks müssen PASSED sein
(inkl. Coverage >= 80 % und Standalone-Bundling). Fehler selbst beheben
und erneut bauen - den Admin damit nicht behelligen.

## Phase 6: Übergabe

Kurze deutsche Anleitung an den Admin:

- Wo liegt das Skript (`scripts/tools/<Name>.ps1`) und wie startet man es
  (`pwsh -File .\scripts\tools\<Name>.ps1`).
- Was wird es fragen (vCenter-Auswahl, Anmeldung, toolspezifische Fragen).
- Wo landet die Ausgabe.
- Hinweis: Die verteilbare Einzeldatei liegt in
  `build/standalone/<Name>.ps1` und läuft auf jedem Rechner mit
  PowerShell 7.4+ und PowerCLI - ohne dieses Repository.
