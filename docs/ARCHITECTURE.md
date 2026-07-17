# Architecture Overview – ps-script-machine

## Purpose

ps-script-machine is a professional development platform and template for coding agents that create high-quality PowerShell and PowerCLI scripts for VMware vSphere administrators.

## Design Principles

1. **Security by default** – No hardcoded credentials, no unsafe constructs
2. **Modularity** – Public/Private separation, reusable components
3. **Testability** – Pester 5 tests with mocked PowerCLI cmdlets
4. **Auditability** – Structured result objects with RunId and timestamps
5. **Pipeline-friendly** – Pipeline input/output where appropriate
6. **Explicit over implicit** – Explicit `-Server` parameter, no global state

## Module Structure

```
src/ps-script-machine/
├── ps-script-machine.psd1   # Module manifest
├── ps-script-machine.psm1   # Root module (loads Public/Private)
├── Public/                   # Exported functions
│   ├── Get-CdpNetworkInfo.ps1
│   └── Export-ModuleData.ps1
├── Private/                  # Internal helpers (exported for testing)
│   ├── Connect-VIServerSession.ps1
│   └── Write-ModuleLog.ps1
└── Classes/                  # PowerShell classes (optional)
```

## Data Flow

```
User Script
    │
    ▼
Connect-VIServerSession (Private)
    │
    ▼
Get-* / Set-* Function (Public)
    │   ├── Uses -Server explicitly
    │   ├── Returns structured PSCustomObject
    │   │   ├── PSTypeName
    │   │   ├── VIServer
    │   │   ├── Timestamp
    │   │   └── RunId
    │   └── Uses Write-ModuleLog for logging
    │
    ▼
Export-ModuleData (Public)
    │   ├── CSV / JSON export
    │   └── Returns full file path
    │
    ▼
Disconnect-VIServer
```

## Separation of Concerns

| Layer | Purpose | Tool |
|-------|---------|------|
| Result objects | Structured data return | `PSCustomObject` with `PSTypeName` |
| Console output | Diagnostic messages | `Write-Verbose`, `Write-Warning`, `Write-Error` |
| Logs | Structured JSON logs | `Write-ModuleLog` |
| Exports | File output | `Export-ModuleData` |

## Read-only vs. Modifying Operations

### Read-only (Get-*)

- No `SupportsShouldProcess`
- No `ConfirmImpact`
- Returns data without side effects
- Example: `Get-CdpNetworkInfo`

### Modifying (Set-, New-, Remove-)

- `SupportsShouldProcess` required
- `ConfirmImpact = 'High'` required
- Prechecks before modification
- Postchecks after modification
- Before/after values in result object
- Idempotent behavior where possible
- Controlled partial failure handling

## Testing Strategy

### Unit Tests (Pester 5)

- All PowerCLI cmdlets are mocked
- Tests cover: success, invalid params, empty results, unreachable vCenter, multiple vCenters, partial failures, result object structure
- Code coverage ≥ 80%

### Integration Tests

- Disabled by default (`$env:PS_SCRIPT_MACHINE_INTEGRATION_TESTS = 'true'`)
- Connect to real vCenter (test/lab only)
- Never run against production accidentally

### Acceptance Tests

- Module manifest validation
- Import verification
- Security checks (no hardcoded secrets, no Invoke-Expression)

## Build Process

```
1. Manifest validation  → Test-ModuleManifest
2. PSScriptAnalyzer     → Invoke-ScriptAnalyzer
3. Pester unit tests    → Invoke-Pester
4. Code coverage        → JaCoCo output
5. Documentation check  → SYNOPSIS, DESCRIPTION, EXAMPLE, OUTPUTS, NOTES
6. Module build         → Copy to build/output
7. Secret scan          → Pattern-based scan
```

Any failure causes the build to fail.

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on push and pull requests:
- Installs Pester and PSScriptAnalyzer
- Validates manifest
- Runs PSScriptAnalyzer
- Runs Pester tests with coverage
- Checks documentation
- Scans for secrets
- Uploads coverage report

## Agent Integration

Coding agents use the following files for guidance:
- `AGENTS.md` – Central rule base
- `CLAUDE.md` – Claude Code specific
- `.github/copilot-instructions.md` – GitHub Copilot specific

All agent-specific files reference `AGENTS.md` to avoid duplication.

## Versioning

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)