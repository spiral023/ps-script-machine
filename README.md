# ps-script-machine

> **Professional development platform and template for coding agents that create high-quality PowerShell and PowerCLI scripts for VMware vSphere administrators.**

[![CI](https://github.com/spiral023/ps-script-machine/actions/workflows/ci.yml/badge.svg)](https://github.com/spiral023/ps-script-machine/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell 7.4+](https://img.shields.io/badge/PowerShell-7.4%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![PowerCLI 13.2+](https://img.shields.io/badge/PowerCLI-13.2%2B-blue.svg)](https://developer.vmware.com/powercli)

## Purpose

This repository provides:

- A **PowerShell module** with reusable PowerCLI functions for VMware vSphere
- **Templates** for creating new functions and scripts
- **Quality assurance** via PSScriptAnalyzer, Pester tests, and code coverage
- **Agent instructions** (AGENTS.md, CLAUDE.md, copilot-instructions.md) for coding agents
- **Automated build process** that works identically locally and in CI
- **Security standards** to prevent hardcoded credentials and unsafe constructs

## Target Audience

- **VMware vSphere administrators** automating with PowerCLI
- **DevOps engineers** building PowerShell automation pipelines
- **Coding agents** (Claude, Copilot, etc.) generating PowerShell/PowerCLI code

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full architecture overview.

```
src/ps-script-machine/
├── Public/           # Exported functions (Get-CdpNetworkInfo, Export-ModuleData)
├── Private/          # Internal helpers (Connect-VIServerSession, Write-ModuleLog)
├── Classes/          # PowerShell classes (optional)
├── ps-script-machine.psd1  # Module manifest
└── ps-script-machine.psm1  # Root module

scripts/              # Wrapper scripts and build tools
tests/                # Pester 5 tests (Unit, Integration, Acceptance)
templates/            # Function and script templates
config/               # Example configurations
docs/                 # Architecture documentation
build/                # Build output (gitignored)
.github/              # CI/CD, issue templates, PR template
```

## Prerequisites

| Component | Version |
|-----------|---------|
| PowerShell | 7.4 or newer |
| PowerCLI | 13.2.0 or newer |
| Pester | 5.0 or newer |
| PSScriptAnalyzer | latest |
| vCenter | 7.0, 8.0 |
| ESXi | 7.0, 8.0 |

## Installation

### From source

```powershell
git clone https://github.com/spiral023/ps-script-machine.git
cd ps-script-machine

# Import the module
Import-Module .\src\ps-script-machine\ps-script-machine.psd1

# Verify
Get-Command -Module ps-script-machine
```

### Install dependencies

```powershell
# PowerCLI
Install-Module VMware.PowerCLI -Scope CurrentUser

# Pester
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser

# PSScriptAnalyzer
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

## Creating scripts from a plain-language description (Skript-Werkstatt)

VMware admins without programming knowledge can request new tools in plain
German inside Claude Code (or any coding agent following AGENTS.md):

> „Schreibe ein Script, das die CDP-Daten aller ESXi-Netzwerkinterfaces
> von allen Hosts von einem oder mehreren vCentern ausliest und als CSV
> speichert."

The agent follows `.agents/skills/script-werkstatt/SKILL.md`: it asks
clarifying questions in VMware terms (never code terms), summarizes what
the script will do, generates a tested module function plus an interactive
wrapper in `scripts/tools/`, and runs the full build.

Every generated wrapper guides the user through the same menu flow:
vCenter selection (saved list in `config/vcenters.json` + free input),
one credential prompt for all vCenters (with per-server retry on failure),
tool-specific questions, progress display, and a summary with output paths.
Unreachable vCenters are skipped and reported - they never abort the run.

The build additionally bundles each wrapper into a self-contained
single-file script in `build/standalone/` that runs on any machine with
PowerShell 7.4+ and PowerCLI - no repository required:

```powershell
.\scripts\Invoke-Build.ps1 -Task Standalone
```

## Local Development Workflow

```powershell
# 1. Make changes to functions in src/ps-script-machine/

# 2. Run the full build (manifest, analyzer, tests, coverage, docs, build, secrets)
.\scripts\Invoke-Build.ps1

# 3. Or run individual tasks
.\scripts\Invoke-Build.ps1 -Task Analyze    # PSScriptAnalyzer only
.\scripts\Invoke-Build.ps1 -Task Test       # Pester tests only
.\scripts\Invoke-Build.ps1 -Task Coverage   # Code coverage only

# 4. With custom coverage threshold
.\scripts\Invoke-Build.ps1 -CodeCoverageThreshold 90
```

## Quality Gates

`AGENTS.md` is the authoritative source for all thresholds and standards below — this section only summarizes what the automated build enforces:

- **PSScriptAnalyzer**: `src/ps-script-machine/` (the module's public/private code) must have **zero Error/Warning-level findings** (`PSScriptAnalyzerSettings.psd1`). `scripts/`, `templates/`, and `examples/` are deliberately out of this strict scope (interactive console tooling that legitimately uses `Write-Host`, `Read-Host`, `Format-Table`) — see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- **Code coverage**: minimum **80%**, measured by Pester 5 (`-CodeCoverageThreshold`).
- **Definition of Done**: every public function must satisfy the full checklist in `AGENTS.md` §11 — comment-based help, validated parameters, structured `PSCustomObject` results, `-WhatIf`/`-Confirm` for modifying functions, and more.
- **Secret scan**: the build fails if hardcoded credentials or secrets are detected.
- **Formatting**: `.editorconfig` (4-space indentation, trimmed trailing whitespace) keeps local edits consistent with what external scanners (PSScriptAnalyzer default severity, SonarQube) would otherwise flag.

Run all gates locally before pushing:

```powershell
.\scripts\Invoke-Build.ps1 -CI
```

## Usage by Coding Agents

Coding agents should read `AGENTS.md` for the central rule base.

### Creating a new function

**Automatic (recommended):**

```powershell
.\scripts\New-PowerCLITool.ps1 -FunctionName 'Get-VMHostDetail' -Type ReadOnly -Synopsis 'Retrieves detailed VMHost information'
```

This generates:
- `src/ps-script-machine/Public/Get-VMHostDetail.ps1`
- `tests/Unit/Get-VMHostDetail.Tests.ps1`
- `docs/Get-VMHostDetail.md`

**Manual:**

1. Copy `templates/PublicFunction.ps1`; for modifying functions add
   `SupportsShouldProcess`/`ConfirmImpact = 'High'` as generated by
   `New-PowerCLITool.ps1 -Type Change`
2. Place in `src/ps-script-machine/Public/`
3. Create test in `tests/Unit/` using `templates/PesterTest.Tests.ps1`
4. Run `.\scripts\Invoke-Build.ps1`
5. Update README and CHANGELOG

Interactive or unattended wrapper scripts are created from
`templates/InteractiveWrapper.ps1`. They perform a PowerCLI-version
preflight, use one outer `try`/`catch`/`finally` lifecycle, write a structured
run summary, support optional sensitive transcripts, and expose documented
process exit codes.

### Example: Using the module

```powershell
# Import module
Import-Module .\src\ps-script-machine\ps-script-machine.psd1

# Get credentials (never hardcode!)
$cred = Get-Credential

# Connect to vCenter
$session = Connect-VIServerSession -Server 'vcenter.example.com' -Credential $cred

# Retrieve CDP network information
$cdpInfo = Get-CdpNetworkInfo -VIServer $session

# Export to CSV and JSON
$exportedFiles = Export-ModuleData -Data $cdpInfo -OutputPath 'C:\Exports\cdp-info' -Format CSV, JSON -Force

# Disconnect
Disconnect-VIServer -Server $session -Confirm:$false
```

## Test and Build Commands

```powershell
# Full build
.\scripts\Invoke-Build.ps1

# Individual tasks
.\scripts\Invoke-Build.ps1 -Task Manifest    # Validate manifest
.\scripts\Invoke-Build.ps1 -Task Analyze     # PSScriptAnalyzer
.\scripts\Invoke-Build.ps1 -Task Test        # Pester unit tests
.\scripts\Invoke-Build.ps1 -Task Coverage    # Code coverage
.\scripts\Invoke-Build.ps1 -Task Docs        # Documentation check
.\scripts\Invoke-Build.ps1 -Task Build       # Module build
.\scripts\Invoke-Build.ps1 -Task Secrets     # Secret scan

# Integration tests (requires explicit activation)
$env:PS_SCRIPT_MACHINE_INTEGRATION_TESTS = 'true'
$env:PS_SCRIPT_MACHINE_VCENTER = 'vcenter.test.local'
Invoke-Pester -Path tests/Integration/
```

## Security Model

See [SECURITY.md](SECURITY.md) for the full security policy.

Key principles:
- **No hardcoded credentials** – Use `PSCredential` and `SecretManagement`
- **No `Invoke-Expression`** – Forbidden
- **No plaintext passwords** – Never in code or logs
- **Input validation** – All parameters validated
- **Least privilege** – Minimal vCenter permissions

### Using SecretManagement

```powershell
# Install SecretManagement modules
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser

# Register a vault
Register-SecretVault -Name 'MyVault' -ModuleName 'Microsoft.PowerShell.SecretStore'

# Store a credential
$cred = Get-Credential
Set-Secret -Name 'vcenter-prod' -Secret $cred -Vault 'MyVault'

# Use in scripts
$cred = Get-Secret -Name 'vcenter-prod' -Vault 'MyVault'
$session = Connect-VIServerSession -Server 'vcenter.example.com' -Credential $cred
```

## VMware Permissions

### Get-CdpNetworkInfo

| Permission | Scope |
|-----------|-------|
| System.Read | vCenter Server |
| Host.Config.Network | ESXi hosts or host folder |

### Least Privilege Recommendation

Create a dedicated vCenter role with only the required permissions:
1. Go to vCenter → Administration → Roles
2. Create a new role (e.g., "ps-script-machine-readonly")
3. Add only: `System.Read`, `Host.Config.Network`
4. Assign this role to the service account

## Logging

The module provides structured JSON logging via `Write-ModuleLog`:

```powershell
# Console logging
Write-ModuleLog -Message "Starting operation" -Level Information -VIServer 'vcenter01'

# File logging
Write-ModuleLog -Message "Operation completed" -Level Information -VIServer 'vcenter01' -LogFile 'C:\Logs\module.log'
```

Log entries include:
- Timestamp (UTC ISO 8601)
- Level (Information, Warning, Error, Debug)
- RunId (unique per module import)
- VIServer (target vCenter)
- Resource (affected resource)
- Message
- Optional Data

## Versioning

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

## Release Process

1. Update `CHANGELOG.md` with the new version and changes
2. Update the module version in `src/ps-script-machine/ps-script-machine.psd1`
3. Create a git tag: `git tag -a v1.0.0 -m "Release v1.0.0"`
4. Push the tag: `git push origin v1.0.0`
5. GitHub Actions will create the release automatically

## Known Limitations

- **PowerCLI required**: The module requires VMware.PowerCLI to be installed
- **vCenter 7.0/8.0 only**: Older vCenter versions are not supported
- **Windows-focused**: While PowerShell 7.4 is cross-platform, PowerCLI has Windows-specific features
- **No PS Gallery publication**: The module is installed from source
- **Integration tests require lab environment**: Cannot run against production

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## License

This project is licensed under the MIT License – see [LICENSE](LICENSE) for details.
