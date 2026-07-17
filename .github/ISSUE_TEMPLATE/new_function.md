---
name: New function request
about: Request a new PowerCLI function for the module
title: '[FUNCTION] '
labels: enhancement, function
assignees: ''
---

## Function name

Follow approved verb-noun convention (e.g., `Get-VMHostDetail`, `Set-VMHostNetwork`).

## Type

- [ ] Read-only (Get-*)
- [ ] Modifying (Set-, New-, Remove-, etc.)

## Description

What should the function do?

## Parameters

List the required and optional parameters.

## Required vSphere permissions

List the vSphere permissions required for this function.

## Test cases

- [ ] Regular success case
- [ ] Invalid parameters
- [ ] Empty results
- [ ] Unreachable vCenter/hosts
- [ ] Multiple vCenter connections
- [ ] Partial failures
- [ ] Correct result object structure
- [ ] -WhatIf (if modifying)
- [ ] Idempotent behavior (if applicable)

## Additional context

Any other context.