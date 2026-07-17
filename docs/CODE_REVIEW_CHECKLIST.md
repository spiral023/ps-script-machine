# Code Review Checklist – ps-script-machine

## Pre-Review

- [ ] PR description is clear and descriptive
- [ ] Related issue is linked
- [ ] Branch is up to date with target branch
- [ ] CI pipeline passes

## Code Quality

- [ ] `#Requires -Version 7.4` present
- [ ] `[CmdletBinding()]` present
- [ ] Approved verb-noun name
- [ ] No `Invoke-Expression` or `iex`
- [ ] No `Format-Table`/`Format-List` in business logic
- [ ] No global state variables
- [ ] No hardcoded credentials, server names, or environment values
- [ ] No plaintext passwords
- [ ] No sensitive data in logs

## Documentation

- [ ] Complete comment-based help
- [ ] `.SYNOPSIS` present
- [ ] `.DESCRIPTION` present
- [ ] `.PARAMETER` for each parameter
- [ ] At least one `.EXAMPLE`
- [ ] `.INPUTS` and `.OUTPUTS` present
- [ ] `.NOTES` with required vSphere permissions
- [ ] `.LINK` to repository

## Parameters

- [ ] Parameters validated appropriately
- [ ] `PSCredential` used for credentials
- [ ] External paths validated
- [ ] Mandatory parameters marked correctly

## Result Objects

- [ ] `PSCustomObject` with `PSTypeName`
- [ ] `VIServer` property present
- [ ] `Timestamp` property present
- [ ] `RunId` property present

## VMware / PowerCLI

- [ ] Explicit `-Server` to all PowerCLI cmdlets
- [ ] No reliance on `$global:DefaultVIServer`
- [ ] Certificate validation not disabled
- [ ] Multiple vCenter connections handled
- [ ] Unreachable hosts handled gracefully
- [ ] Partial failures handled

## Read-only vs. Modifying

- [ ] Read-only functions don't have `SupportsShouldProcess`
- [ ] Modifying functions have `SupportsShouldProcess` and `ConfirmImpact='High'`
- [ ] Modifying functions have prechecks
- [ ] Modifying functions have postchecks
- [ ] Modifying functions have before/after values
- [ ] Modifying functions are idempotent where possible

## Error Handling

- [ ] `try`/`catch`/`finally` used appropriately
- [ ] Errors are traceable and meaningful
- [ ] Partial failures don't break all operations

## Testing

- [ ] Pester 5 tests created
- [ ] Success cases tested
- [ ] Invalid parameters tested
- [ ] Empty results tested
- [ ] Unreachable vCenter/hosts tested
- [ ] Multiple vCenter connections tested
- [ ] Partial failures tested
- [ ] Result object structure tested
- [ ] `-WhatIf` tested (modifying functions)
- [ ] Idempotent behavior tested
- [ ] PowerCLI cmdlets mocked
- [ ] Code coverage ≥ 80%

## Build

- [ ] PSScriptAnalyzer passes
- [ ] All tests pass
- [ ] Build succeeds
- [ ] No secrets detected