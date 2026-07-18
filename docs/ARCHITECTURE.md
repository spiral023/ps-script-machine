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

## PSScriptAnalyzer Scope

`Invoke-Build.ps1`'s `Analyze` task (and CI) run `PSScriptAnalyzerSettings.psd1`
only against `src/ps-script-machine` - the module's shipped Public/Private
code - with warnings treated as fatal in `-CI` mode. This is a deliberate
scope, not an oversight:

- **`scripts/`** contains interactive CLI wrapper scripts
  (`Export-CdpInformation.ps1`, `New-PowerCLITool.ps1`, ...) whose entire
  purpose is console interaction. `Write-Host`, `Read-Host`, and
  `Format-Table` are the correct, idiomatic tools there - `PSAvoidUsingWriteHost`
  is a rule for library code, not for a script whose job is to print to a
  human's terminal. Enforcing it here would be wrong, not just strict.
- **`examples/`** and **`templates/`** are illustrative/scaffold code, not
  shipped module code.
- **`tests/`** uses patterns PSScriptAnalyzer is not tuned for by default
  (mock functions with intentionally unused parameters to match a real
  cmdlet's signature for `Mock`/`ParameterFilter`, disposable fake
  credentials built via `ConvertTo-SecureString -AsPlainText`).

A full-repo `Invoke-ScriptAnalyzer -Path .` run will therefore still show
warnings outside `src/` - that is expected and does not indicate the build
is not actually clean. If a rule fires on genuinely unsafe code in one of
these directories (e.g. a real, non-mock secret), fix it; if it fires on
an intentional pattern described above, either accept it as out-of-scope
or suppress it explicitly with `SuppressMessageAttribute` and a
`Justification`, as done for the mock-credential fixtures in
`tests/Unit/Connect-VIServerSession.Tests.ps1` and
`tests/Unit/Get-VMHostNetworkInfo.Tests.ps1`. Silently ignoring a real
`Severity = Error` finding anywhere in the repository is never acceptable,
regardless of this scope.

## Known Deviations

### Get-VMHostNetworkInfo (legacy result schema)

`Get-VMHostNetworkInfo` predates the result-object schema introduced with
the v1.0.0 restructuring (see CHANGELOG.md, v0.1.0 → v1.0.0) and does not
carry `PSTypeName`, `RunId`, or a `VIServer` property (it exposes `vCenter`
instead). It also manages its own `Connect-VIServerSession` /
`Disconnect-VIServerSession` lifecycle internally rather than accepting an
already-connected `-VIServer` session, and logs via `Write-ScriptLog`
instead of `Write-ModuleLog`.

**Decision:** this is tracked as a deliberate, temporary exception, not a
permanent second schema. `Get-VMHostNetworkInfo` is planned to be migrated
to the standard schema (`PSTypeName`, `VIServer`, `RunId`, `Timestamp`,
`Write-ModuleLog`) in **v2.0.0**. Because renaming `vCenter` to `VIServer`
and adding `PSTypeName`/`RunId` changes the shape of the returned objects,
this is a breaking change per the Semantic Versioning policy below and
cannot be done silently in a patch/minor release - it also requires
updating `scripts/tools/Export-CdpInformation.ps1`, which consumes the current
column names for its CSV/JSON export.

Until that migration lands, `tests/Unit/ResultObjectContract.Tests.ps1`
documents this gap with an explicit, skipped contract test rather than
silently passing or silently failing, so the exception stays visible
instead of becoming permanent by default.

## Versioning

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)