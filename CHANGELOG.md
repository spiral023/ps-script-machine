# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned (Breaking - targeting v2.0.0)

- Migrate `Get-VMHostNetworkInfo` to the standard result-object schema
  (`PSTypeName`, `VIServer` instead of `vCenter`, `RunId`, `Timestamp`,
  `Write-ModuleLog`). This is a breaking change to the returned object
  shape and to `scripts/tools/Export-CdpInformation.ps1`, which consumes the
  current column names. See docs/ARCHITECTURE.md, "Known Deviations".

## [1.0.0] - 2025-01-17

### Added

- Professional module structure with `src/ps-script-machine/` layout
- Module manifest (`ps-script-machine.psd1`) with PowerCLI dependency
- Root module (`ps-script-machine.psm1`) with dynamic function loading
- Public function `Get-CdpNetworkInfo` for CDP network information retrieval
- Public function `Export-ModuleData` for CSV/JSON export
- Private function `Connect-VIServerSession` for vCenter connection management
- Private function `Write-ModuleLog` for structured JSON logging
- Comprehensive Pester 5 unit tests for all functions
- Integration tests (disabled by default, require explicit activation)
- Acceptance tests for module manifest, import, and security checks
- Templates for read-only functions, modifying functions, private functions, wrapper scripts, and Pester tests
- `New-PowerCLITool.ps1` generator script for automatic function scaffolding
- Unified build process (`Invoke-Build.ps1`) with 7 quality gates
- GitHub Actions CI workflow for pushes and pull requests
- GitHub issue templates (bug report, feature request, new function)
- GitHub pull request template with comprehensive checklist
- Central agent instructions (`AGENTS.md`)
- Claude Code instructions (`CLAUDE.md`)
- GitHub Copilot instructions (`.github/copilot-instructions.md`)
- Security policy (`SECURITY.md`)
- Architecture documentation (`docs/ARCHITECTURE.md`)
- Definition of Done (`docs/DEFINITION_OF_DONE.md`)
- Code review checklist (`docs/CODE_REVIEW_CHECKLIST.md`)
- Example configurations (`config/environments.example.psd1`, `config/settings.example.json`)
- Comprehensive README with usage examples
- Contributing guidelines (`CONTRIBUTING.md`)
- PSScriptAnalyzer settings file
- Updated `.gitignore` for build artifacts and sensitive files

### Changed

- Restructured repository from flat layout to proper PowerShell module structure
- Moved `Get-CdpNetworkInfo.ps1` from root to `src/ps-script-machine/Public/`
- Moved `Connect-VIServerSession.ps1` to `src/ps-script-machine/Private/`
- Enhanced `Get-CdpNetworkInfo` with structured result objects, PSTypeName, RunId, Timestamp
- Enhanced `Connect-VIServerSession` with improved error handling and validation
- Enhanced `Invoke-Build.ps1` with 7-stage quality assurance process
- Updated PSScriptAnalyzer settings

### Security

- No hardcoded credentials in any source file
- All functions use `PSCredential` for authentication
- `Invoke-Expression` is forbidden
- Certificate validation is never silently disabled
- Secret scan in build process detects accidentally committed secrets
- Input validation on all parameters
- Least privilege vCenter permissions documented

## [0.1.0] - 2024-12-01

### Added

- Initial repository structure
- Basic `Get-CdpNetworkInfo.ps1` script
- Basic `Connect-VIServerSession.ps1` helper
- Basic `Export-CdpInformation.ps1` wrapper
- Basic Pester tests
- Basic build script