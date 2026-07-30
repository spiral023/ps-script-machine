# Betriebs- und Laufzeitvertrag

Diese Referenz für jedes mit dem Light-Skill erzeugte Skript anwenden.

## Betriebsprofil

Vor der Generierung mindestens klären:

- interaktiver Einzelstart oder unbeaufsichtigter Lauf;
- Start-/Verteilmechanismus, z. B. Empirum/Softwareverteilung, Scheduled
  Task, Remote-Session oder CI;
- ausführendes Konto: angemeldeter Benutzer, Dienstkonto oder SYSTEM;
- PowerShell-Version, Edition, Architektur und Language Mode;
- Arbeitsverzeichnis sowie erlaubte Schreib- und Temp-Verzeichnisse;
- Netzwerk-, DNS-, Firewall- und Proxy-Voraussetzungen;
- benötigte Rechte nach Least Privilege;
- erwartete Exitcodes und mögliches Reboot-Verhalten;
- gewünschte Protokollierung und Aufbewahrung.

Keine Annahme aus einer interaktiven Admin-Sitzung ungeprüft auf einen
Paket- oder SYSTEM-Lauf übertragen. Insbesondere Desktop, Benutzerprofil,
gemappte Laufwerke, Proxy und aktuelles Verzeichnis können dort fehlen oder
auf andere Orte zeigen.

## Abhängigkeits-Preflight

Vor der Fachlogik prüfen:

- passende PowerShell-Mindestversion über `#Requires -Version`;
- jedes externe Modul mit Mindestversion über `Get-Module -ListAvailable`;
- benötigte Dateien, Verzeichnisse, Umgebungsvariablen, Netzwerkziele und
  Schreibrechte;
- ausschließlich dokumentierte, sichere Installations- oder
  Behebungshinweise ausgeben.

Weder `$env:PSModulePath` global erweitern noch feste Unternehmenspfade
einbauen. Module regulär installieren/importieren oder den Pfad als
validierten Parameter übergeben.

## Ein äußerer Lebenszyklus

Initialisierung, Preflight, optionales Logging, Verbindungsaufbau,
Fachlogik und Export in genau einen äußeren `try`/`catch`/`finally`-Ablauf
legen:

1. `RunId`, UTC-Startzeit, Status und Exitcode initialisieren.
2. Abhängigkeiten und Zielpfade prüfen.
3. Ressourcen einmal öffnen und wiederverwenden.
4. Fachlogik ausführen und Teilfehler strukturiert sammeln.
5. Im `catch` den fatalen Fehler erfassen und den Exitcode setzen.
6. Im `finally` Ressourcen schließen, temporäre Session-/Process-
   Einstellungen wiederherstellen und die Laufzusammenfassung schreiben.
7. Genau einmal am äußersten Skriptende mit dem festgelegten Code beenden.

Hilfsfunktionen verwenden `throw` oder Fehlerobjekte, niemals `exit`.
`trap` und globale Preference-Änderungen nicht als Lifecycle-Ersatz nutzen.

## Exitcodes

Ohne abweichenden Vertrag:

- `0`: Erfolg oder fachlich behandelter Teilerfolg;
- `1`: fataler Fehler, der den Lauf unvollständig macht.

Teilerfolge zusätzlich im Status und in Zählwerten sichtbar machen.
Weitere Codes, etwa für Neustart oder Paketierungsstatus, nur nach
Abstimmung mit dem aufrufenden System verwenden und in `.NOTES`
dokumentieren.

## Laufzusammenfassung und Logs

Eine strukturierte Zusammenfassung mit folgenden Feldern schreiben:

- Skript-/Toolname und Version;
- `RunId`;
- UTC-Start und UTC-Ende;
- Dauer;
- Status und Exitcode;
- Anzahl angeforderter, erfolgreicher, übersprungener und fehlerhafter
  Ziele;
- Ergebnisanzahl und erzeugte Dateien;
- bereinigte Fehlermeldung ohne Secrets.

Vollständige Transcripts nur auf ausdrücklichen Wunsch aktivieren. Sie
können Benutzernamen, Servernamen, Pfade und andere sensible Konsolendaten
enthalten und sind vor einer Weitergabe zu prüfen.

Aufbewahrung ausschließlich in einem eindeutig werkzeugeigenen
Logverzeichnis durchführen. Nur Dateien dieses Tools und niemals
allgemeine Log-, Temp- oder Benutzerordner löschen. Eine automatische
Bereinigung transparent dokumentieren und begrenzen.

## Versionierung

Keine manuelle Änderungshistorie im Skriptkopf pflegen. Git ist die
Historie. Tool-/Modulversion und, falls verfügbar, Build- oder Commit-ID in
Artefaktkopf und Laufzusammenfassung aufnehmen.
