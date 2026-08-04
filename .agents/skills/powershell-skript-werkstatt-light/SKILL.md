---
name: powershell-skript-werkstatt-light
description: Erstellt oder überarbeitet ein einzelnes, eigenständig ausführbares PowerShell-Standalone-Skript. Verwenden, wenn der Nutzer ausdrücklich eine `.ps1`-Einzeldatei, einen Light-Workflow oder eine Lösung ohne eigenes Modul, Public/Private-Architektur, Pester-Suite, PSScriptAnalyzer-Gate und Build-Pipeline verlangt. Gilt für Dateisystem, Active Directory, Netzwerk, Cloud, Datenbanken, REST und VMware/PowerCLI; der PowerCLI-Vertrag ist vollständig im Skill enthalten. Nicht für mehrteilige Module oder den vollständigen Repository-Build-Workflow verwenden.
---

# PowerShell-Skript-Werkstatt (Light)

## Ziel und Grenzen

Erzeuge eine handwerklich saubere, sofort nutzbare `.ps1`-Datei. Verwende
keine selbst gebauten Zusatzmodule, `.psd1`-/`.psm1`-Dateien,
Public/Private-Ordner, Pester-Suite, Analyzer-Gates oder Build-Pipeline.
Lege benötigte Hilfsfunktionen in derselben Datei ab und starte das Ergebnis
mit `pwsh -File .\Verb-Noun.ps1 ...`.

Nutze diesen Workflow domänenneutral. Behandle externe, bereits installierte
Module als vereinbarte Laufzeitabhängigkeiten, nicht als Bestandteil eines
neu zu bauenden Moduls.

## Nicht verhandelbar

1. Vor der Generierung ein kurzes Interview führen und die Zusammenfassung
   ausdrücklich freigeben lassen.
2. Genau eine eigenständige `.ps1`-Datei liefern.
3. Read-only und verändernd vorab unterscheiden. Jede Änderung mit
   `SupportsShouldProcess`, `-WhatIf`, eindeutiger Zielvalidierung und
   Idempotenz absichern.
4. Den benötigten PowerShell Language Mode immer klären.
5. Keine fest codierten Secrets, kein `Invoke-Expression`, keine
   stillschweigend deaktivierte Zertifikatsprüfung und keine globalen
   Zustände verwenden.
6. Das Skript vor der Übergabe mit PowerShell-Bordmitteln prüfen.

## Referenzen gezielt laden

Lies nur die für die aktuelle Phase und Variante benötigten Referenzen,
jeweils vollständig. Alle Regeln liegen innerhalb dieses Skills; kein
weiterer Skill ist erforderlich.

| Referenz | Wann vollständig lesen |
|---|---|
| [`references/runtime-contract.md`](references/runtime-contract.md) | Immer vor dem Interview |
| [`references/csv-input.md`](references/csv-input.md) | Sobald CSV-/Datei-Eingaben Ziele oder Fachdaten liefern |
| [`references/language-mode.md`](references/language-mode.md) | Sobald Constrained Language Mode gefordert oder eine per WDAC/AppLocker eingeschränkte Umgebung genannt wird |
| [`references/powercli-standalone.md`](references/powercli-standalone.md) | Bei jeder vCenter-, ESXi- oder PowerCLI-Aufgabe, vor den PowerCLI-spezifischen Interviewfragen |
| [`references/standalone-implementation.md`](references/standalone-implementation.md) | Erst nach der Freigabe aus Phase 3, unmittelbar vor Generierung und Prüfung |

## Phase 1: Einordnen

Bestimme vor dem Interview:

- read-only (Auswertung/Report) oder verändernd (Anlage, Löschung,
  Konfiguration, Zustandsänderung);
- Domäne und Zielobjekte;
- interaktiver Einzelstart oder unbeaufsichtigter Betrieb;
- freie Admin-Umgebung oder eingeschränkter Endpoint/Jump-Server;
- Eingabequelle: Parameter, Pipeline, CSV/Datei, API, Datenbank oder andere
  Quelle;
- benötigte bedingte Referenzen aus der Tabelle oben.

Lies danach mindestens den Laufzeitvertrag und alle bereits erkennbar
bedingten Referenzen, bevor du Fragen stellst.

## Phase 2: Dynamisches Interview

Stelle eine Frage pro Nachricht und schlage einen sinnvollen Standard vor.
Kläre mindestens:

- **Geltungsbereich:** alle oder gefilterte Ziele; eindeutige Filter;
- **Eingabe:** Quelle, erwartetes Schema und Umgang mit fehlenden Daten;
- **Ausgabe:** Pipelineobjekte, Konsole, CSV/JSON und Ablageort;
- **Fehlerverhalten:** standardmäßig Einzelziele weiterverarbeiten und
  Teilfehler am Ende ausweisen oder ausdrücklich sofort abbrechen;
- **Betriebsprofil:** interaktiv/unbeaufsichtigt, Start-/Verteilweg,
  ausführendes Konto, Arbeitsverzeichnis, Netzwerk/Proxy, Rechte, Exitcodes
  und Reboot-Verhalten;
- **Protokollierung:** strukturierte Laufzusammenfassung und nur auf Wunsch
  zusätzlich ein als sensibel gekennzeichnetes Transcript;
- **Language Mode:** Full Language als Standard für freie Admin-Umgebungen
  oder Constrained Language für entsprechend verwaltete Systeme.

Bei verändernden Skripten zusätzlich erklären und klären:

- `-WhatIf` ist immer eingebaut;
- Bestätigung pro Objekt oder für den gesamten Lauf;
- erwarteter Vorher-/Nachher-Zustand und Idempotenz;
- Verhalten bei teilweise erfolgreichen Änderungen.

Stelle die Zusatzfragen aus den geladenen CSV-, Language-Mode- und
PowerCLI-Referenzen ebenfalls einzeln.

## Phase 3: Zusammenfassung und Freigabe

Fasse in ein bis zwei Sätzen verbindlich zusammen:

- was in welchem Geltungsbereich gelesen oder verändert wird;
- Eingabe, Ausgabe und Fehlerverhalten;
- Language Mode und Betriebsprofil;
- Protokollierung, Cleanup und Exitcode-Vertrag;
- bei Änderungen Vorschau-, Bestätigungs- und Idempotenzverhalten.

Generiere erst nach ausdrücklicher Bestätigung. Arbeite Korrekturen ein und
hole für die korrigierte Zusammenfassung erneut die Freigabe ein.

## Phase 4: Generieren

Lies jetzt
[`references/standalone-implementation.md`](references/standalone-implementation.md)
vollständig. Wende zusätzlich den bereits geladenen Laufzeitvertrag und alle
bedingten Referenzen an.

Erzeuge genau eine `.ps1`-Datei. Halte Fachlogik, Diagnose, Export und Log
getrennt. Erfülle jede Zusage aus Phase 3; erfinde keine Umgebungswerte,
Credentials, Server, Pfade oder Berechtigungen.

## Phase 5: Prüfen

Führe die Selbstprüfung und Definition of Done aus der
Implementierungsreferenz vollständig durch. Ergänze die variantenspezifischen
Prüfungen aus den geladenen Referenzen. Behebe gefundene Fehler vor der
Übergabe.

Teste verändernde Skripte zuerst mit `-WhatIf`. Verwende nur ausdrücklich
autorisierte, harmlose reale Ziele; führe keine produktive Zustandsänderung
allein zur Prüfung aus.

## Phase 6: Übergeben

Nenne knapp:

- den Pfad zur einzelnen `.ps1`-Datei;
- einen passenden `pwsh -File`-Beispielaufruf;
- erwartete Eingaben, Rückfragen und Ausgaben;
- unterstützten Language Mode und das Betriebsprofil;
- Laufzusammenfassung, optionales Transcript, Aufbewahrung und Exitcodes;
- welche Prüfungen tatsächlich durchgeführt wurden und welche mangels
  Zielsystem nur manuell beurteilt werden konnten.
