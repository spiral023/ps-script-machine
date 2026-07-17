# Design: Skript-Werkstatt – natürlichsprachliche Skript-Erstellung mit interaktivem Menü-Framework

**Datum:** 2026-07-18
**Status:** Freigegeben (Brainstorming abgeschlossen)

## 1. Ziel und Problem

VMware-Administratoren ohne Programmierkenntnisse sollen neue PowerCLI-Skripte
erhalten können, indem sie ihren Wunsch auf Deutsch beschreiben, z. B.:

> „Schreibe ein Script, das die CDP-Daten aller ESXi-Netzwerkinterfaces von
> allen Hosts von einem oder mehreren vCentern ausliest und als CSV speichert."

Die erzeugten Skripte führen den Admin über ein einfaches interaktives Menü
durch den gesamten Ablauf (vCenter-Auswahl, Anmeldung, toolspezifische Fragen,
Export) und unterstützen mehrere vCenter in einem Lauf.

**Lücken im Ist-Zustand:**

1. Kein definierter Prozess von natürlicher Sprache zu fertigem Skript
   (der Generator `New-PowerCLITool.ps1` erzeugt nur leere Gerüste).
2. Kein wiederverwendbares Menü-Framework; das bestehende Wrapper-Skript
   `Export-CdpInformation.ps1` unterstützt nur ein vCenter und dupliziert
   Interaktionslogik.
3. Keine Möglichkeit, Skripte als eigenständige Single-File-Dateien an
   Admin-Maschinen ohne das Repo zu verteilen.

## 2. Getroffene Grundsatzentscheidungen

| Frage | Entscheidung |
|---|---|
| NL-Verarbeitung | Claude Code im Repo ist der Motor; ein Skill definiert den Workflow. Keine eigene LLM-API-Anbindung. |
| Artefakt der Generierung | Modul-Funktion + interaktiver Wrapper **und** zusätzlich gebündeltes Single-File-Skript (Bundle-Build). |
| Multi-vCenter-Angabe | Gespeicherte Liste (`config/vcenters.json`) als nummerierte Auswahl mit Mehrfachauswahl, plus freie FQDN-Eingabe mit optionalem Speichern. |
| Credentials | Einmal per `Get-Credential` abfragen, für alle vCenter verwenden; bei Login-Fehlschlag gezielte Nachfrage nur für das betroffene vCenter. Keine Passwort-Speicherung in V1. |
| Interview-Stil | Claude entscheidet dynamisch, wie viele und welche Rückfragen nötig sind, um gemeinsames Verständnis zu erreichen. Fragen ausschließlich in VMware-Fachsprache. |
| Architektur | Ansatz A „Drei Bausteine": Skill + Menü-Framework im Modul + Bundle-Build. |

## 3. Baustein 1: Skill „Skript-Werkstatt"

**Ort:** `.agents/skills/script-werkstatt/SKILL.md`, plus Verweise in
`CLAUDE.md` und `AGENTS.md`, damit Claude Code den Skill automatisch lädt,
sobald ein Admin einen Skript-Wunsch formuliert.

**Definierter Ablauf:**

1. **Verstehen** – Wunsch einordnen: lesend oder verändernd? Welche
   vSphere-Objekte (Hosts, VMs, Netzwerk, Storage)? Existiert bereits eine
   (teilweise) passende Modul-Funktion?
2. **Dynamisches Interview** – so viele Rückfragen wie nötig, ausschließlich
   in VMware-Fachsprache, nie in Code-Sprache. Der Skill enthält einen
   Fragenkatalog als Inspiration (Geltungsbereich, Ausgabeformat/-ort,
   Fehlerverhalten, Nutzungshäufigkeit); Claude wählt situativ und ergänzt
   eigene Fragen. Bei verändernden Skripten sind Sicherheitsfragen
   verpflichtend (WhatIf-Vorschau, Bestätigung pro Objekt).
3. **Zusammenfassung & Freigabe** – vor der Generierung fasst Claude auf
   Deutsch zusammen, was das Skript tun wird; der Admin bestätigt oder
   korrigiert („Vertragsstelle" des Prozesses).
4. **Generierung** – Modul-Funktion über `New-PowerCLITool.ps1` + Templates,
   interaktiver Wrapper aus dem neuen Template `InteractiveWrapper.ps1`,
   Pester-Tests.
5. **Qualitätssicherung** – `Invoke-Build.ps1` läuft automatisch
   (PSScriptAnalyzer, Pester, Coverage ≥ 80 %). Fehler behebt Claude selbst.
6. **Übergabe** – kurze deutsche Anleitung: Ablageort, Startbefehl, was das
   Skript fragt, wo die Ausgabe landet, Hinweis auf die Standalone-Variante
   in `build/standalone/`.

**Prinzip:** Der Admin muss zu keinem Zeitpunkt Code lesen. Alle Interaktion
läuft über Fachsprache und die Zusammenfassung.

## 4. Baustein 2: Menü-Framework im Modul

### Konfigdatei

- `config/vcenters.json` (gitignored) + eingecheckte `vcenters.example.json`.
- Eintrag: Anzeigename, FQDN, optionale Beschreibung (z. B. „Produktion RZ1").
- Datei entsteht automatisch beim ersten Speichern eines neuen vCenters.

### Neue Modul-Funktionen

| Funktion | Sichtbarkeit | Aufgabe |
|---|---|---|
| `Select-VIServerTarget` | Public | Nummerierte Auswahl gespeicherter vCenter; Eingaben `1,3`, `alle` oder direkter FQDN (mit Rückfrage „Für später speichern? (J/n)"). Rückgabe: FQDN-Liste. |
| `Connect-MultiVIServer` | Public | Einmalige `Get-Credential`-Abfrage; verbindet nacheinander zu allen gewählten vCentern mit explizitem `-Server`. Bei Login-Fehlschlag gezielte Nachfrage nur für das betroffene vCenter (neue Credentials oder überspringen). Rückgabe: verbundene Sessions + übersprungene Server. Ein nicht erreichbares vCenter bricht nie den Gesamtlauf ab. |
| `Read-MenuChoice` | Private | Konsistente nummerierte Abfragen mit Standardwert (Enter = Vorgabe, Vorgabe in Klammern). |

### Template `templates/InteractiveWrapper.ps1`

Fester Ablauf, den jedes generierte Skript erbt:

1. Begrüßung (eine Zeile, was das Skript tut)
2. vCenter-Auswahl (`Select-VIServerTarget`)
3. Anmeldung (`Connect-MultiVIServer`)
4. Toolspezifische Fragen (Platzhalter-Block, den Claude bei der Generierung
   füllt, über `Read-MenuChoice`)
5. Ausführung mit Fortschrittsanzeige (`Write-Progress` pro vCenter/Host)
6. Abschluss: Anzahl Ergebnisse, vollständiger Ausgabepfad, übersprungene Server
7. Sauberes Disconnect in `finally` – auch bei Strg+C oder Fehlern

### Doppelnutzung

Jeder Wrapper akzeptiert alle Eingaben auch als Parameter
(`-VCenter vc01,vc02 -OutputPath …`). Ohne Parameter erscheint das Menü;
mit Parametern (z. B. Scheduled Task) läuft das Skript nicht-interaktiv.

## 5. Baustein 3: Bundle-Build (Single-File-Verteilung)

- Neues Skript `scripts/Export-StandaloneScript.ps1`, integriert als Schritt
  in `Invoke-Build.ps1`.
- **Quellordner der Wrapper:** Generierte interaktive Wrapper liegen in
  `scripts/tools/` (neuer Ordner); das bestehende `Export-CdpInformation.ps1`
  wird bei der Modernisierung dorthin verschoben. Build-, Generator- und
  Prüf-Skripte bleiben direkt in `scripts/` und werden nie gebündelt.
- Erzeugt aus jedem Wrapper in `scripts/tools/` ein eigenständiges Skript in
  `build/standalone/<Name>.ps1`.
- **Mechanik V1 (bewusst einfach):** Alle Modul-Funktionen (Private zuerst,
  dann Public) werden als Funktionsdefinitionen eingebettet, danach folgt der
  Wrapper-Code ohne `Import-Module`-Block. Keine Abhängigkeitsanalyse –
  robust, keine vergessenen Abhängigkeiten. Bekannte Ausbaustufe: AST-basierte
  Auflösung, falls das Modul auf 50+ Funktionen wächst.
- **Standalone-Skript enthält:**
  - Kopfkommentar „Automatisch generiert aus ps-script-machine vX.Y am
    <Datum> – nicht manuell bearbeiten"
  - PowerCLI-Check beim Start: fehlt `VMware.PowerCLI`, erscheint eine
    deutsche Installationsanleitung statt eines kryptischen Fehlers
  - PowerCLI selbst wird nicht eingebettet
- **Verifikation im Build:** Syntax-Check per PowerShell-Parser und
  PSScriptAnalyzer über das erzeugte Standalone-Skript.

## 6. Fehlerbehandlung (Admin-gerecht)

- Fehlermeldungen auf Deutsch, dreiteilig: Was ist passiert / warum
  vermutlich / was tun. Keine rohen .NET-Exceptions im Normalfall.
- Teilfehler-Prinzip aus AGENTS.md: Ein Host ohne Daten oder ein nicht
  erreichbares vCenter erzeugt eine Warnung, bricht aber nie den Gesamtlauf
  ab. Abschluss-Zusammenfassung, z. B.: „3 von 4 vCentern abgefragt,
  87 Interfaces exportiert, 1 vCenter übersprungen".
- Log-Datei je Lauf über vorhandenes `Write-ScriptLog`.

## 7. Tests

- Pester 5, Coverage ≥ 80 % bleibt Pflicht.
- `Select-VIServerTarget` / `Connect-MultiVIServer`: gemockte `Read-Host`,
  `Get-Credential`, `Connect-VIServer`; Fälle „ein Login schlägt fehl",
  „vcenters.json fehlt/defekt".
- Bundle-Build: erzeugtes Standalone-Skript ist syntaktisch valide und
  enthält alle Funktionsnamen.
- `ResultObjectContract.Tests.ps1` prüft neue Funktionen automatisch mit.

## 8. Pilot und Abnahmekriterium

Das CDP-Beispiel ist der Referenz-Durchlauf. Erfolg heißt: Ein Admin tippt in
Claude Code den CDP-Wunsch, beantwortet die Rückfragen und erhält ein
lauffähiges, getestetes Skript samt Standalone-Variante, das per Menü durch
vCenter-Auswahl, Anmeldung und Export führt.

Das bestehende `Export-CdpInformation.ps1` wird dabei auf das neue Framework
modernisiert (Multi-vCenter) statt ein Duplikat zu erzeugen.

## 9. Dokumentation

- `README.md` und `AGENTS.md`: neuer Abschnitt „Skript per Beschreibung
  erstellen".
- Das Skill-File ist die maßgebliche Prozessdefinition.

## 10. Bewusst ausgeklammert (YAGNI)

- SecretManagement-Integration für gespeicherte Credentials (Ausbaustufe).
- Zentraler Launcher (`Start-ScriptMachine.ps1`) als einheitlicher
  Einstiegspunkt (Ausbaustufe, verträgt sich mit dieser Architektur).
- AST-basierte Abhängigkeitsauflösung im Bundle-Build.
- Eigenständiges Tool mit LLM-API-Anbindung.
