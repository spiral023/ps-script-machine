# Contributing Guidelines

## Übersicht

Vielen Dank für dein Interesse an der Mitwirkung an `ps-script-machine`! Dieses Dokument beschreibt die Regeln und Prozesse für die Entwicklung von PowerShell-Skripten in diesem Repository.

## Entwicklungsprozess

### 1. Branch erstellen

```powershell
git checkout -b feature/neue-funktion
```

### 2. Code schreiben

- Verwende **approved verbs** (`Get-Verb`) für Funktionsnamen
- Alle Funktionen erhalten `[CmdletBinding()]` und `[Parameter()]` Attribute
- Passwörter immer als `[PSCredential]`, nie als `[string]`
- Ändernde Funktionen unterstützen `-WhatIf` und `-Confirm`
- Strukturierte Objekte (`[PSCustomObject]`) als Ausgabe, nie `Format-Table` in Funktionen
- Verbindungen in `finally`-Blöcken trennen
- Comment-Based Help für jede Public-Funktion

### 3. Qualitätssicherung vor Commit

```powershell
# PSScriptAnalyzer ausführen
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1

# Pester-Tests ausführen
./scripts/Invoke-Build.ps1
```

**Es dürfen keine Errors oder Warnings von PSScriptAnalyzer zurückbleiben.**

### 4. Tests schreiben

Für jede neue Funktion:

- Unit-Tests im Ordner `tests/Unit/`
- Mock alle PowerCLI-Cmdlets
- Teste Edge-Cases (null, leer, Fehler)

### 5. Pull Request

- Beschreibe was geändert wurde und warum
- Verlinke relevante Issues
- CI-Pipeline muss grün sein (PSScriptAnalyzer + Pester)

## Qualitätsregeln (verbindlich)

1. Keine fest codierten Zugangsdaten oder Servernamen
2. Ändernde Funktionen unterstützen `-WhatIf` und `-Confirm`
3. Standardmäßig erfolgen nur Leseoperationen
4. Jede Änderung hat Prechecks und eine nachvollziehbare Ergebnisprüfung
5. Alle Funktionen liefern strukturierte Objekte
6. Keine Aliase wie `%`, `?`, `gwmi` oder `select` im produktiven Code
7. PowerCLI-Verbindungen werden in `finally` geschlossen
8. Fehler werden nicht mit `SilentlyContinue` verborgen
9. Jede öffentliche Funktion hat vollständige Hilfe und Beispiele
10. PSScriptAnalyzer darf keine Fehler oder Warnungen melden
11. Kritische Funktionen besitzen Pester-Tests
12. Änderungen durchlaufen Pull Request und Vier-Augen-Prüfung
13. Module und Abhängigkeiten werden auf feste Versionen eingeschränkt
14. Produktions-, Test- und Entwicklungs-vCenter werden getrennt konfiguriert
15. Jeder Lauf erzeugt ein maschinenlesbares Audit-Ergebnis

## Modul-Struktur

```
src/ps-script-machine/
├── Public/          # Öffentliche Funktionen (Cmdlets)
├── Private/         # Interne Hilfsfunktionen
├── ps-script-machine.psd1  # Modul-Manifest
└── ps-script-machine.psm1  # Modul-Loader
```

- **Public-Funktionen** sind die Cmdlets, die Administratoren verwenden
- **Private-Funktionen** enthalten gemeinsame Verbindungs-, Logging-, Export- und Validierungslogik
- Skripte in `scripts/` sollten nur Wrapper um das Modul sein