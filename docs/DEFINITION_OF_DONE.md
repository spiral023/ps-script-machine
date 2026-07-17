# Definition of Done – ps-script-machine

## Function Level

A function is only complete when ALL of the following criteria are met:

### Code Quality

- [ ] `#Requires -Version 7.4` present
- [ ] `[CmdletBinding()]` present
- [ ] Approved verb-noun name (verify with `Get-Verb`)
- [ ] No `Invoke-Expression` or `iex`
- [ ] No `Format-Table`/`Format-List` in business logic
- [ ] No global state variables (`$global:...`)
- [ ] No hardcoded credentials, server names, or environment values
- [ ] No `$ErrorActionPreference = 'SilentlyContinue'` without local scope

### Documentation

- [ ] Complete comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.INPUTS`, `.OUTPUTS`, `.NOTES`, `.LINK`)
- [ ] Required vSphere permissions documented in `.NOTES`
- [ ] At least one `.EXAMPLE`

### Parameters

- [ ] Parameters validated (`[ValidateNotNullOrEmpty()]`, `[ValidateRange()]`, `[ValidateSet()]`, etc.)
- [ ] `PSCredential` used for credentials (not plaintext)
- [ ] External paths validated

### Result Objects

- [ ] Structured `PSCustomObject` with `PSTypeName`
- [ ] `VIServer` property in result object
- [ ] `Timestamp` property in result object
- [ ] `RunId` property in result object

### VMware / PowerCLI

- [ ] Explicit `-Server` parameter to all PowerCLI cmdlets
- [ ] No reliance on `$global:DefaultVIServer`
- [ ] Certificate validation not silently disabled
- [ ] Multiple vCenter connections handled
- [ ] Unreachable hosts handled gracefully
- [ ] Partial failures don't break all operations

### Read-only vs. Modifying

#### Read-only (Get-*)

- [ ] No `SupportsShouldProcess` (not needed)

#### Modifying (Set-, New-, Remove-)

- [ ] `SupportsShouldProcess` enabled
- [ ] `ConfirmImpact = 'High'`
- [ ] Prechecks performed
- [ ] Target validation (unique or explicit multi-target)
- [ ] `-WhatIf` and `-Confirm` support
- [ ] Postchecks performed
- [ ] Before/after values in result object
- [ ] Idempotent behavior where possible

### Error Handling

- [ ] `try`/`catch`/`finally` used
- [ ] Errors are traceable
- [ ] Partial failures handled gracefully

### Testing

- [ ] Pester 5 tests created
- [ ] Regular success cases tested
- [ ] Invalid parameters tested
- [ ] Empty results tested
- [ ] Unreachable vCenter/hosts tested
- [ ] Multiple vCenter connections tested
- [ ] Missing data tested
- [ ] Partial failures tested
- [ ] `-WhatIf` tested (for modifying functions)
- [ ] Idempotent behavior tested
- [ ] Correct result object structure tested
- [ ] PowerCLI cmdlets mocked in unit tests
- [ ] Code coverage ≥ 80%

### Build

- [ ] PSScriptAnalyzer passes without unjustified errors
- [ ] All tests pass
- [ ] Build succeeds (`.\scripts\Invoke-Build.ps1`)
- [ ] No secrets detected in secret scan

## Repository Level

- [ ] README updated
- [ ] CHANGELOG updated
- [ ] Documentation updated
- [ ] PR template checklist completed