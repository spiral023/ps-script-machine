---
name: vmware-powercli-scripts
description: PowerShell & VMware PowerCLI scripting best practices for vSphere administrators. Use when writing, reviewing, or refactoring PowerShell scripts for VMware vCenter/ESXi automation. Triggers on tasks involving PowerCLI, vSphere, ESXi, vCenter, Get-VMHost, Connect-VIServer, Pester tests, PSScriptAnalyzer, or VMware administration scripts.
license: MIT
metadata:
  author: custom
  version: "1.1.0"
---

# VMware PowerCLI Script Best Practices

Comprehensive guide for creating high-quality PowerShell scripts with VMware PowerCLI. Contains 30+ rules across 11 categories, prioritized by impact to guide automated code generation, refactoring, and quality assurance.

> **Scope:** general PowerCLI craft (the *why* and *how*, with examples).
> Project-specific mandates for this repository — required versions,
> directory layout, Definition of Done, coverage gate, and build process —
> live in the repository-root `AGENTS.md` and take precedence on conflict.

## When to Apply

Reference these guidelines when:
- Writing new PowerShell scripts for VMware vSphere automation
- Using VMware PowerCLI cmdlets (Get-VMHost, Connect-VIServer, Get-View, etc.)
- Creating Pester tests for PowerShell scripts
- Configuring PSScriptAnalyzer rules
- Reviewing or refactoring existing PowerCLI scripts
- Handling vCenter credentials securely
- Exporting data (CSV, JSON, XLSX) from vSphere environments
- Building modular PowerShell modules with Public/Private functions

## Rule Categories by Priority

| Priority | Category | Impact | Prefix |
|----------|----------|--------|--------|
| 1 | Security & Credentials | CRITICAL | `security-` |
| 2 | Error Handling & Robustness | CRITICAL | `error-` |
| 3 | PowerCLI Connection Management | HIGH | `connection-` |
| 4 | vSphere API & Data Retrieval | HIGH | `vsphere-` |
| 5 | PowerShell Code Quality | MEDIUM-HIGH | `quality-` |
| 6 | Testing with Pester | MEDIUM | `testing-` |
| 7 | Output & Formatting | MEDIUM | `output-` |
| 8 | Documentation & Help | LOW-MEDIUM | `docs-` |
| 9 | State-Changing Operations | CRITICAL | `state-` |
| 10 | Secret Management | HIGH | `secret-` |
| 11 | Modular Architecture | MEDIUM-HIGH | `module-` |

## Quick Reference

### 1. Security & Credentials (CRITICAL)

- `security-credential-handling` - Use Get-Credential, never hardcode passwords
- `security-plaintext-password` - Avoid [string] parameters for passwords
- `security-credential-disconnect` - Always disconnect and clean up sessions

### 2. Error Handling & Robustness (CRITICAL)

- `error-action-preference` - Set $ErrorActionPreference appropriately
- `error-try-catch-finally` - Use try/catch/finally for all vCenter operations
- `error-connection-state-check` - Verify host connection state before queries

### 3. PowerCLI Connection Management (HIGH)

- `connection-single-connect` - Connect once, reuse the session
- `connection-always-disconnect` - Always disconnect in finally block
- `connection-configuration` - Set PowerCLI configuration for automation

### 4. vSphere API & Data Retrieval (HIGH)

- `vsphere-get-view-advanced` - Use Get-View for advanced API access
- `vsphere-bulk-queries` - Query all hosts at once, not one-by-one
- `vsphere-extension-data` - Use ExtensionData for properties not in cmdlets

### 5. PowerShell Code Quality (MEDIUM-HIGH)

- `quality-approved-verbs` - Use approved verbs in function names
- `quality-parameter-attributes` - Use [Parameter()] attributes properly
- `quality-pipeline-support` - Support pipeline input where appropriate
- `quality-strong-typing` - Use strong typing for parameters and variables

### 6. Testing with Pester (MEDIUM)

- `testing-isolate-functions` - Test helper functions in isolation
- `testing-mock-external` - Mock PowerCLI cmdlets, never call real vCenter
- `testing-edge-cases` - Test null, empty, and error scenarios

### 7. Output & Formatting (MEDIUM)

- `output-csv-encoding` - Use correct encoding for German Excel compatibility
- `output-pscustomobject` - Use [PSCustomObject] for structured output
- `output-progress` - Use Write-Progress for long-running operations

### 8. Documentation & Help (LOW-MEDIUM)

- `docs-comment-based-help` - Always include comment-based help
- `docs-synopsis-description` - Include .SYNOPSIS and .DESCRIPTION
- `docs-examples` - Provide .EXAMPLE blocks

### 9. State-Changing Operations (CRITICAL)

- `state-supports-should-process` - Use SupportsShouldProcess for all modifying functions
- `state-read-only-default` - Default to read-only, separate analysis from remediation
- `state-test-get-invoke` - Follow Test-Get-Invoke pattern for remediation

### 10. Secret Management (HIGH)

- `secret-management-module` - Use Microsoft.PowerShell.SecretManagement
- `secret-no-hardcoded` - Never hardcode passwords, API keys, or tokens

### 11. Modular Architecture (MEDIUM-HIGH)

- `module-public-private` - Separate Public (cmdlets) from Private (helpers) functions
- `module-scripts-as-wrappers` - Scripts should be thin wrappers around module functions
- `module-structured-output` - Functions return structured objects, never formatted output

## How to Use

Every rule listed above is documented in full in the compiled guide
`AGENTS.md` (in this skill directory). Look a rule up there by its prefix
(e.g. `security-`, `error-`, `state-`) when you need the detailed
explanation and code samples.

Each rule entry contains:
- Brief explanation of why it matters
- Incorrect code example with explanation
- Correct code example with explanation
- Additional context and references