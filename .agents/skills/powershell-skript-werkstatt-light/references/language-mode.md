# Language Mode

## Auswahl

| Modus | Typische Umgebung | Wesentliche Einschränkungen |
|---|---|---|
| Full Language | Admin-Rechner ohne WDAC/AppLocker | reguläre PowerShell- und .NET-Nutzung |
| Constrained Language | verwalteter Endpoint, Jump-Server, Kiosk | `Add-Type`, COM, Reflection und beliebige .NET-Methoden blockiert |

Für Constrained Language Mode nur eingebaute Cmdlets, freigegebene Module
und erlaubte Kerntypen verwenden. Keine dynamisch aus Strings erzeugten
Scriptblocks, kein `Invoke-Expression`, keine Reflection-Tricks.

Braucht die Aufgabe zwingend COM, `Add-Type` oder nicht erlaubte
.NET-Aufrufe, die Einschränkung transparent nennen und vor der Umsetzung
Full Language Mode vereinbaren.

## Prüfung

In einem separaten Wegwerf-Prozess testen:

```powershell
pwsh -NoProfile -Command '$ExecutionContext.SessionState.LanguageMode = "ConstrainedLanguage"; & "<Pfad-zum-Skript>.ps1" -WhatIf'
```

Zusätzlich Syntaxprüfung und den vereinbarten harmlosen Dry-Run
durchführen.
