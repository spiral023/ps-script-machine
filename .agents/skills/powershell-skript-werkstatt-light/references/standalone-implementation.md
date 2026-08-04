# Standalone-Implementierung und Prüfung

Diese Referenz erst nach der ausdrücklichen Freigabe des vereinbarten
Skriptvertrags lesen. Sie enthält die gemeinsamen Implementierungs-,
Sicherheits- und Prüfvorgaben für jede Domäne.

## Inhalt

1. [Dateiaufbau](#dateiaufbau)
2. [Hilfe, Parameter und Stil](#hilfe-parameter-und-stil)
3. [Sicherheit](#sicherheit)
4. [Fehler- und Ressourcenbehandlung](#fehler--und-ressourcenbehandlung)
5. [Datenabruf, Pipeline und Ausgabekanäle](#datenabruf-pipeline-und-ausgabekanäle)
6. [Auditierbare Ergebnisobjekte](#auditierbare-ergebnisobjekte)
7. [Verändernde Skripte](#verändernde-skripte)
8. [Selbstprüfung ohne Zusatzmodule](#selbstprüfung-ohne-zusatzmodule)
9. [Definition of Done](#definition-of-done)

## Dateiaufbau

Erzeuge genau eine `.ps1`-Datei. Verwende diese Reihenfolge:

1. `#Requires -Version` passend zur vereinbarten Zielumgebung;
2. vollständige Comment-Based Help;
3. skriptweites `[CmdletBinding()]` und `param()`;
4. `Set-StrictMode -Version Latest` und
   `$ErrorActionPreference = 'Stop'`;
5. interne Hilfsfunktionen;
6. Initialisierung von `RunId`, UTC-Startzeit, Status, Zählwerten und
   Exitcode;
7. genau ein äußerer `try`/`catch`/`finally`-Lebenszyklus für Preflight,
   Ressourcen, Fachlogik, Export, Cleanup und Laufzusammenfassung;
8. genau ein `exit $exitCode` am äußersten Dateiende.

Verwende kein selbst gebautes Modul, Dot-Sourcing eigener Zusatzdateien oder
eine Public/Private-Struktur. Teile wiederholte oder abgeschlossene Logik in
aussagekräftige interne Hilfsfunktionen derselben Datei; vermeide große
lineare Codeblöcke.

Read-only-Skripte verwenden kein `SupportsShouldProcess`. Verändernde
Skripte verwenden
`[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]`.

## Hilfe, Parameter und Stil

Dokumentiere mindestens `.SYNOPSIS`, `.DESCRIPTION`, jeden `.PARAMETER`,
realistische `.EXAMPLE`-Blöcke, `.OUTPUTS` und `.NOTES`. Nenne in `.NOTES`
Versionen, externe Abhängigkeiten, Rechte, Betriebsprofil, Language Mode,
Logging/Transcript, Cleanup und Exitcodes.

- Verwende einen genehmigten Verb-Noun-Namen und prüfe das Verb mit
  `Get-Verb`.
- Typisiere Parameter und validiere externe Eingaben mit passenden
  Attributen oder eindeutigen manuellen Prüfungen.
- Verwende PascalCase für Funktionen und Parameter, camelCase für interne
  Variablen, Bool-Präfixe `is`/`has`/`can`/`should` und Pluralformen für
  Sammlungen.
- Verwende keine ungarische Notation oder kryptischen Abkürzungen; etablierte
  Akronyme wie `ID`, `URL`, `VM` und `IP` sind zulässig.
- Rücke mit vier Leerzeichen ein, setze öffnende `{` in dieselbe Zeile und
  verwende auch bei Einzeilern Klammern.
- Nutze `$_` nur in kurzen, einfachen Pipelines; verwende bei mehrzeiliger
  oder verschachtelter Logik benannte `foreach`-Variablen.
- Bevorzuge frühe Rückgabe bzw. `continue` gegenüber tiefer Verschachtelung.
- Kommentiere nur nicht offensichtliche Logik und Workarounds.

## Sicherheit

- Verwende niemals fest codierte Credentials, Tokens, Servernamen,
  IP-Adressen oder umgebungsspezifische Pfade.
- Verwende `PSCredential`/`Get-Credential` für interaktive Credentials und
  einen bereits eingerichteten SecretManagement-Vault für unbeaufsichtigte
  Läufe, wenn verfügbar. Installiere nichts stillschweigend.
- Nimm Kennwörter nicht als Klartext-String entgegen und schreibe keine
  Secrets in Pipeline, Konsole, Logs, Transcripts oder Fehlerobjekte.
- Verwende weder `Invoke-Expression` noch `iex`.
- Validiere Pfade mit `Test-Path -LiteralPath` und den benötigten `PathType`;
  validiere Werte mit `ValidateSet`, `ValidateRange`,
  `ValidateNotNullOrEmpty` oder gleichwertiger Logik.
- Verwende keine globalen Variablen für Zustand und ändere
  `$ErrorActionPreference` nicht global oder dauerhaft auf
  `SilentlyContinue`.
- Deaktiviere TLS-/Zertifikatsprüfung niemals stillschweigend. Begrenze eine
  ausdrücklich vereinbarte Testausnahme auf Session/Process, dokumentiere sie
  sichtbar und stelle den vorherigen Zustand im `finally` wieder her.
- Arbeite nach Least Privilege und dokumentiere die minimal benötigten
  Rechte.
- Schalte `Set-StrictMode` nach Aktivierung nicht ab oder herunter.

## Fehler- und Ressourcenbehandlung

- Setze `$ErrorActionPreference = 'Stop'`, damit `try`/`catch` auch
  non-terminating Errors kontrolliert behandelt. Verwende bei kritischen
  externen Aufrufen zusätzlich `-ErrorAction Stop`.
- Prüfe Existenz, Erreichbarkeit und Zustand externer Ziele vor der Nutzung.
- Öffne Verbindungen, Sessions, Clients und Handles einmal und verwende sie
  wieder. Öffne sie nicht pro Schleifendurchlauf neu.
- Schließe bzw. dispose jede selbst geöffnete Ressource im `finally`.
  Unterdrücke nur Cleanup-Fehler lokal mit `-ErrorAction SilentlyContinue`,
  damit sie den ursprünglichen Fehler nicht verdecken.
- Lass einen fehlerhaften Einzeltarget-Lauf standardmäßig weiterlaufen und
  erfasse den Teilfehler strukturiert. Brich nur ab, wenn dies im Interview
  vereinbart wurde oder der gesamte Lauf nicht sinnvoll fortsetzbar ist.
- Verwende in Hilfsfunktionen `throw` oder strukturierte Fehlerobjekte,
  niemals `exit`.

## Datenabruf, Pipeline und Ausgabekanäle

- Rufe Daten möglichst gebündelt ab, baue In-Memory-Lookups auf und vermeide
  Remote-/IO-Aufrufe pro Element. Trenne Sammeln, Verarbeiten und Exportieren.
- Nutze `Write-Progress` bei langen interaktiven Operationen mit vielen
  Zielen; beende die Anzeige mit `-Completed`.
- Unterstütze Pipeline-Eingabe nur, wenn sie fachlich sinnvoll ist. Verwende
  dann `ValueFromPipeline` bzw. `ValueFromPipelineByPropertyName` und
  `begin`/`process`/`end` korrekt.
- Erzwinge kein Darstellungs- oder Exportformat in der Fachlogik.

Halte vier Kanäle getrennt:

| Kanal | Zweck | Mittel |
|---|---|---|
| Pipeline | maschinenlesbare Ergebnisse | strukturierte `PSCustomObject`-Objekte |
| Diagnose | Bedienerinformationen | `Write-Verbose`, `Write-Warning`, `Write-Error` |
| Export | vereinbarte Dateien | `Export-Csv`, `ConvertTo-Json` oder passende Writer |
| Log | zeitliche Nachvollziehbarkeit | eigener, strukturierter und geheimnisbereinigter Schritt |

Verwende `Format-Table` und `Format-List` nur außerhalb der Fachlogik. Lege
CSV-Trennzeichen und Encoding nach Quellsystem und Zielanwendung fest; nutze
Windows-1252 für deutsches Legacy-Excel nur, wenn dieser Vertrag tatsächlich
vereinbart wurde.

## Auditierbare Ergebnisobjekte

Gib pro Ziel ein `PSCustomObject` zurück mit:

- `PSTypeName` nach `<Bereich>.<Verb-Noun>.Result`;
- eindeutigem Zielbezeichner und Fachdaten;
- `Success` oder eindeutigem `Status`;
- bereinigter Fehlermeldung bei Fehlern;
- einem `RunId`, der für den gesamten Skriptlauf gleich bleibt;
- UTC-`Timestamp`.

Ergänze bei Änderungen `Changed` und fachlich benannte Vorher-/Nachher-Werte.
Ergänze domänenspezifische Pflichtfelder aus den bedingten Referenzen.

Schreibe zusätzlich die Laufzusammenfassung aus dem Laufzeitvertrag mit
UTC-Start/Ende, Dauer, Status, Exitcode, Ziel-/Ergebnis-/Fehlerzahlen und
erzeugten Dateien. Vermische die Zusammenfassung nicht versehentlich mit dem
fachlichen Ergebnisschema; verwende den vereinbarten Log-/Exportweg oder einen
eigenen eindeutigen `PSTypeName`.

## Verändernde Skripte

- Führe einen Precheck durch: Ziel existiert, ist erreichbar und im
  erwarteten Ausgangszustand.
- Validiere genau ein Ziel oder kennzeichne Mehrfachverarbeitung ausdrücklich.
- Erfasse den Vorher-Zustand und vergleiche ihn mit dem Sollzustand. Ist der
  Sollzustand bereits erreicht, gib `Success = $true` und `Changed = $false`
  zurück, ohne zu ändern.
- Rufe die Änderung ausschließlich innerhalb von
  `$PSCmdlet.ShouldProcess(<eindeutiges Ziel>, <Aktion>)` auf.
- Führe unter `-WhatIf` weder Änderung noch verändernden Postcheck aus; gib
  ein strukturiertes Vorschauergebnis zurück.
- Verifiziere nach einer echten Änderung den Zustand erneut und gib
  Vorher-/Nachher-Werte zurück.
- Isoliere Teilfehler pro Ziel und lasse andere Ziele gemäß Vertrag
  weiterlaufen.
- Trenne Remediation logisch in Analyse (Ist), Plan (Sollvergleich) und
  Ausführung. Führe den Plan zuerst mit `-WhatIf` aus.

## Selbstprüfung ohne Zusatzmodule

Führe mindestens eine Parser-Prüfung aus:

```powershell
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    '<Pfad>.ps1',
    [ref]$null,
    [ref]$parseErrors
) | Out-Null
$parseErrors
```

Behebe jeden Parserfehler. Prüfe anschließend mit einem harmlosen Kleinstfall
oder durch nachvollziehbare manuelle Analyse:

- regulärer Erfolg;
- ungültiger oder fehlender Parameter;
- leeres Ergebnis;
- nicht erreichbares/nicht vorhandenes Ziel;
- mehrere Ziele mit einem Teilfehler;
- fehlende/unvollständige optionale Daten;
- Cleanup nach Erfolg und Fehler;
- zweiter Lauf mit identischen Parametern;
- bei Änderungen `-WhatIf`, echte Bestätigung und Postcheck;
- vereinbarter Language Mode und unbeaufsichtigter Lauf ohne Prompt;
- Exitcodes, Laufzusammenfassung und erzeugte Dateien.

Führe einen echten Zustandswechsel nur mit ausdrücklicher Autorisierung aus.
Kennzeichne in der Übergabe, welche Prüfungen mangels Zielsystem nur statisch
oder gedanklich möglich waren.

## Definition of Done

- [ ] Genau eine `.ps1`-Datei ohne eigene Zusatzmodule oder Dot-Sourcing
- [ ] Passendes `#Requires -Version`, `[CmdletBinding()]`, StrictMode und
      vollständige Comment-Based Help
- [ ] Parameter typisiert/validiert; genehmigter Verb-Noun-Name und
      vereinbarter Language Mode
- [ ] Keine Secrets, festen Umgebungswerte, `Invoke-Expression`, globalen
      Zustände oder stillschweigend deaktivierte Zertifikatsprüfung
- [ ] Ein äußerer Lebenszyklus, genau ein Exitpunkt und Cleanup im `finally`
- [ ] Abhängigkeiten samt Mindestversionen vor der Fachlogik geprüft
- [ ] Strukturierte Ergebnisobjekte mit `PSTypeName`, `RunId`, UTC-Zeitstempel
      und domänenspezifischen Pflichtfeldern
- [ ] Pipeline, Diagnose, Export und Log getrennt; Laufzusammenfassung und
      Transcript-/Aufbewahrungsvertrag umgesetzt
- [ ] Teilfehler, leere Ergebnisse und fehlende Daten kontrolliert behandelt
- [ ] Bei Änderungen: `SupportsShouldProcess`, `-WhatIf`, eindeutiges Ziel,
      Pre-/Postcheck, Vorher/Nachher und Idempotenz
- [ ] Parserprüfung, harmloser Dry-Run bzw. dokumentierte manuelle Prüfung und
      relevante Edge Cases abgeschlossen
- [ ] Alle Zusagen aus Phase 3 sowie alle geladenen bedingten Referenzen erfüllt
