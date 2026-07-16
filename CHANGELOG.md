# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt hält sich an [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

### Added
- Modul-Architektur mit Public/Private Functions
- `Get-VMHostNetworkInfo` als parametrisierte Funktion
- `Connect-VIServerSession` / `Disconnect-VIServerSession` für sichere Verbindungsverwaltung
- `Write-ScriptLog` für einheitliches Logging
- `Export-ReportCsv` (Windows-1252) und `Export-ReportJson` (UTF-8)
- `ConvertTo-CleanText` als wiederverwendbare Hilfsfunktion
- Config-Beispiele (`environments.example.psd1`, `settings.example.json`)
- CONTRIBUTING.md und LICENSE

### Changed
- `Get-CdpNetworkInfo.ps1` ist nun ein Wrapper um das Modul
- PSScriptAnalyzer-Konfiguration vereinfacht (kompatibilitätsprüfungen deaktiviert)

## [1.0.0] - 2026-07-17

### Added
- Initiale Projektstruktur
- `Get-CdpNetworkInfo.ps1` – CDP-Informationen von ESXi-Hosts auslesen
- PSScriptAnalyzer-Konfiguration (`PSScriptAnalyzerSettings.psd1`)
- Pester-Tests für Hilfsfunktionen
- GitHub Actions CI-Pipeline
- VSCode-Integration (Settings, Extensions)
- Agent Skill `vmware-powercli-scripts` mit Best Practices
- README.md mit vollständiger Dokumentation