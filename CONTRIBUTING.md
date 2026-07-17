# Contributing to ps-script-machine

Thank you for your interest in contributing! This document describes how to contribute to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/<your-username>/ps-script-machine.git`
3. Create a feature branch: `git checkout -b feature/my-new-function`
4. Make your changes
5. Run the build: `.\scripts\Invoke-Build.ps1`
6. Commit and push: `git push origin feature/my-new-function`
7. Create a pull request

## Prerequisites

- PowerShell 7.4 or newer
- PowerCLI 13.2.0 or newer
- Pester 5.0 or newer
- PSScriptAnalyzer

```powershell
Install-Module VMware.PowerCLI -Scope CurrentUser
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

## Coding Standards

All contributions must follow the standards defined in [AGENTS.md](AGENTS.md).

### Key Rules

1. **`#Requires -Version 7.4`** at the top of every `.ps1` file
2. **`[CmdletBinding()]`** for all public functions
3. **Approved verb-noun names** (verify with `Get-Verb`)
4. **Complete comment-based help** (SYNOPSIS, DESCRIPTION, PARAMETER, EXAMPLE, INPUTS, OUTPUTS, NOTES, LINK)
5. **Parameter validation** (`[ValidateNotNullOrEmpty()]`, etc.)
6. **Structured result objects** with `PSTypeName`, `VIServer`, `Timestamp`, `RunId`
7. **Explicit `-Server`** to all PowerCLI cmdlets
8. **No hardcoded credentials** – use `PSCredential` and `SecretManagement`
9. **No `Invoke-Expression`** – forbidden
10. **No `Format-Table`/`Format-List`** in business logic
11. **Pester 5 tests** for all functions
12. **Code coverage ≥ 80%**

### Read-only vs. Modifying

- **Read-only (Get-*)**: No `SupportsShouldProcess`
- **Modifying (Set-, New-, Remove-)**: `SupportsShouldProcess` + `ConfirmImpact='High'` + prechecks + postchecks + before/after values + idempotent

## Creating a New Function

### Automatic (recommended)

```powershell
.\scripts\New-PowerCLITool.ps1 -FunctionName 'Get-VMHostDetail' -Type ReadOnly -Synopsis 'Retrieves detailed VMHost information'
```

### Manual

1. Copy the appropriate template from `templates/`
2. Place the function in `src/ps-script-machine/Public/` or `Private/`
3. Create a test in `tests/Unit/` using `templates/PesterTest.Tests.ps1`
4. Run `.\scripts\Invoke-Build.ps1`
5. Update `README.md` and `CHANGELOG.md`

## Testing

### Unit Tests

All unit tests go in `tests/Unit/` and must:
- Use Pester 5 syntax
- Mock all PowerCLI cmdlets
- Cover: success, invalid params, empty results, unreachable vCenter, multiple vCenters, partial failures, result structure
- Achieve ≥ 80% code coverage

### Integration Tests

Integration tests in `tests/Integration/` are:
- Disabled by default
- Activated via `$env:PS_SCRIPT_MACHINE_INTEGRATION_TESTS = 'true'`
- Only run against test/lab environments
- Never run against production

## Build Process

```powershell
# Full build
.\scripts\Invoke-Build.ps1

# Individual tasks
.\scripts\Invoke-Build.ps1 -Task Analyze
.\scripts\Invoke-Build.ps1 -Task Test
.\scripts\Invoke-Build.ps1 -Task Coverage
```

The build runs:
1. Module manifest validation
2. PSScriptAnalyzer
3. Pester unit tests
4. Code coverage
5. Documentation check
6. Module build
7. Secret scan

Any failure causes the build to fail.

## Pull Request Process

1. Ensure the build passes locally
2. Update `CHANGELOG.md`
3. Update `README.md` if needed
4. Complete the PR template checklist
5. Request review

### PR Checklist

- [ ] Code follows project standards (AGENTS.md)
- [ ] PSScriptAnalyzer passes
- [ ] All tests pass
- [ ] Code coverage ≥ 80%
- [ ] No hardcoded credentials
- [ ] No `Invoke-Expression`
- [ ] Documentation updated
- [ ] CHANGELOG updated

## Code Review

See [docs/CODE_REVIEW_CHECKLIST.md](docs/CODE_REVIEW_CHECKLIST.md) for the complete code review checklist.

## Definition of Done

See [docs/DEFINITION_OF_DONE.md](docs/DEFINITION_OF_DONE.md) for the complete Definition of Done.

## Questions?

Open an issue with the `question` label.