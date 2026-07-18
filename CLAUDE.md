# Claude Code Instructions – ps-script-machine

> **Diese Datei verweist auf die zentrale Regelbasis in `AGENTS.md`.**
> Alle Regeln, Standards und Vorgehensweisen sind in `AGENTS.md` definiert.

## Referenz

**Lies und befolge `AGENTS.md`** – dies ist die zentrale Regelbasis für alle Coding Agents.

## Schnellreferenz

- **PowerShell**: 7.4+
- **PowerCLI**: 13.2.0+
- **Module**: `src/ps-script-machine/ps-script-machine.psd1`
- **Tests**: `tests/Unit/` (Pester 5)
- **Build**: `.\scripts\Invoke-Build.ps1`
- **Vorlagen**: `templates/`
- **Generator**: `.\scripts\New-PowerCLITool.ps1`

## Wichtige Regeln

1. **Keine fest codierten Zugangsdaten** – verwende `PSCredential` und `SecretManagement`
2. **Keine `Invoke-Expression`** – verboten
3. **Explizite `-Server`-Übergabe** an alle PowerCLI-Cmdlets
4. **`[CmdletBinding()]`** für alle öffentlichen Funktionen
5. **Vollständige Comment-Based Help** für alle öffentlichen Funktionen
6. **Pester-5-Tests** für alle Funktionen
7. **Code-Coverage ≥ 80%**
8. **Read-only vs. verändernd** klar trennen

## Neue Funktion erstellen

```powershell
# Automatisch
.\scripts\New-PowerCLITool.ps1 -FunctionName 'Get-VMHostDetail' -Type ReadOnly

# Manuell
# 1. templates/PublicFunction.ps1 kopieren
# 2. In src/ps-script-machine/Public/ einfügen
# 3. tests/Unit/ Test erstellen
# 4. .\scripts\Invoke-Build.ps1 ausführen
```

## Skript per Beschreibung erstellen (Skript-Werkstatt)

Beschreibt ein Nutzer ein gewünschtes Skript in natürlicher Sprache
(z. B. „Schreibe ein Script, das die CDP-Daten aller ESXi-Netzwerkinterfaces
ausliest"), folge dem Workflow in
`.agents/skills/script-werkstatt/SKILL.md`: dynamisches Interview in
VMware-Fachsprache, Zusammenfassung zur Freigabe, dann Generierung über
`templates/InteractiveWrapper.ps1` und `scripts/New-PowerCLITool.ps1`.

Siehe `AGENTS.md` für die vollständige Definition of Done.