# ps-script-machine

PowerShell-Modul und Skripte für die VMware-Administration mit PowerCLI.

## Übersicht

Dieses Repository enthält ein strukturiertes PowerShell-Modul mit Public/Private Functions für die VMware vSphere-Automatisierung. Die Skripte nutzen **VMware PowerCLI** (bzw. **VCF PowerCLI**).

## Architektur

```
ps-script-machine/
├── .agents/skills/vmware-powercli-scripts/  # Agent Skill (Best Practices)
├── .github/workflows/ci.yml                 # CI Pipeline
├── .vscode/                                  # Editor-Konfiguration
├── config/                                   # Konfigurations-Beispiele
├── scripts/                                  # Wrapper-Skripte
│   ├── Export-CdpInformation.ps1             # CDP-Export (Wrapper)
│   └── Invoke-Build.ps1                      # Build & Test
├── src/ps-script-machine/                    # PowerShell-Modul
│   ├── Public/                               # Exportierte Cmdlets
│   │   └── Get-VMHostNetworkInfo.ps1
│   ├── Private/                              # Interne Hilfsfunktionen
│   │   ├── Connect-VIServerSession.ps1
│   │   ├── Disconnect-VIServerSession.ps1
│   │   ├── ConvertTo-CleanText.ps1
│   │   ├── Write-ScriptLog.ps1
│   │   ├── Export-ReportCsv.ps1
│   │   └── Export-ReportJson.ps1
│   ├── ps-script-machine.psd1                # Modul-Manifest
│   └── ps-script-machine.psm1                # Modul-Loader
├── tests/                                    # Pester-Tests
├── PSScriptAnalyzerSettings.psd1             # Analyzer-Konfiguration
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

## Verwendung

### Modul importieren

```powershell
Import-Module .\src\ps-script-machine\ps-script-machine.psd1
```

### CDP-Informationen abfragen

```powershell
# Interaktiv (Wrapper-Skript):
.\scripts\Export-CdpInformation.ps1

# Parametrisiert (Funktion direkt):
$cred = Get-Credential -Message "vCenter-Anmeldung"
$results = Get-VMHostNetworkInfo -Server "vcenter.local" -Credential $cred

# Ergebnisse weiterverarbeiten:
$results | Export-ReportCsv -Path "C:\Reports\cdp.csv"
$results | Export-ReportJson -Path "C:\Reports\cdp.json"
$results | Format-Table
```

### Build & Tests

```powershell
./scripts/Invoke-Build.ps1              # Analyse + Tests
./scripts/Invoke-Build.ps1 -Coverage    # Mit Code-Coverage
./scripts/Invoke-Build.ps1 -SkipAnalysis # Nur Tests
```

## Qualitätssicherung

- **PSScriptAnalyzer** – Statische Code-Analyse (`PSScriptAnalyzerSettings.psd1`)
- **Pester** – Unit-Tests mit Mocking (`tests/`)
- **GitHub Actions CI** – Automatische Pipeline bei Push/PR
- **Agent Skill** – Best Practices Guide (`.agents/skills/`)

## Voraussetzungen

- **PowerShell 7.4+** (`pwsh`)
- **VMware PowerCLI** / **VCF PowerCLI 9.1+**:
  ```powershell
  Install-Module VMware.PowerCLI -Scope CurrentUser
  ```
- **PSScriptAnalyzer**:
  ```powershell
  Install-Module PSScriptAnalyzer -Scope CurrentUser
  ```
- **Pester 5+**:
  ```powershell
  Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0
  ```

## Agent Skill

Der Skill `vmware-powercli-scripts` im Ordner `.agents/skills/` enthält 30+ Best-Practice-Regeln in 11 Kategorien:

1. **Security & Credentials** (CRITICAL)
2. **Error Handling & Robustness** (CRITICAL)
3. **PowerCLI Connection Management** (HIGH)
4. **vSphere API & Data Retrieval** (HIGH)
5. **PowerShell Code Quality** (MEDIUM-HIGH)
6. **Testing with Pester** (MEDIUM)
7. **Output & Formatting** (MEDIUM)
8. **Documentation & Help** (LOW-MEDIUM)
9. **State-Changing Operations** (CRITICAL) – `-WhatIf`, Read-Only by Default, Test-Get-Invoke
10. **Secret Management** (HIGH) – Microsoft.SecretManagement
11. **Modular Architecture** (MEDIUM-HIGH) – Public/Private, Scripts as Wrappers

## Lizenz

MIT – siehe [LICENSE](LICENSE).