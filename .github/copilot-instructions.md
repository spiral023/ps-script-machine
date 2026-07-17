# GitHub Copilot Instructions – ps-script-machine

> **This file references the central rule base in `AGENTS.md`.**
> All rules, standards, and procedures are defined in `AGENTS.md`.

## Reference

**Read and follow `AGENTS.md`** – this is the central rule base for all coding agents.

## Quick Reference

- **PowerShell**: 7.4+
- **PowerCLI**: 13.2.0+
- **Module**: `src/ps-script-machine/ps-script-machine.psd1`
- **Tests**: `tests/Unit/` (Pester 5)
- **Build**: `.\scripts\Invoke-Build.ps1`
- **Templates**: `templates/`
- **Generator**: `.\scripts\New-PowerCLITool.ps1`

## Key Rules

1. **No hardcoded credentials** – use `PSCredential` and `SecretManagement`
2. **No `Invoke-Expression`** – forbidden
3. **Explicit `-Server` parameter** to all PowerCLI cmdlets
4. **`[CmdletBinding()]`** for all public functions
5. **Complete comment-based help** for all public functions
6. **Pester 5 tests** for all functions
7. **Code coverage ≥ 80%**
8. **Read-only vs. modifying** clearly separated

## Creating a New Function

```powershell
# Automatic
.\scripts\New-PowerCLITool.ps1 -FunctionName 'Get-VMHostDetail' -Type ReadOnly

# Manual
# 1. Copy templates/PublicFunction.ps1
# 2. Place in src/ps-script-machine/Public/
# 3. Create test in tests/Unit/
# 4. Run .\scripts\Invoke-Build.ps1
```

See `AGENTS.md` for the complete Definition of Done.