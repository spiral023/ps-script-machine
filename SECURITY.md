# Security Policy – ps-script-machine

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅        |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT open a public GitHub issue.**
2. Email the maintainers directly or use GitHub's private vulnerability reporting.
3. Include a description of the vulnerability and steps to reproduce.
4. You will receive a response within 48 hours.

## Security Standards

This repository enforces strict security standards:

### Credentials

- **No hardcoded credentials**: Passwords, server names, and environment values must never be hardcoded.
- **PSCredential**: Always use `[System.Management.Automation.PSCredential]` for authentication.
- **SecretManagement**: `Microsoft.PowerShell.SecretManagement` is the recommended way to manage secrets.
- **No plaintext passwords**: Passwords are never stored in plaintext in code or logs.

### Code Safety

- **No `Invoke-Expression`**: This cmdlet is forbidden. Use safe alternatives.
- **Input validation**: All external paths and inputs are validated.
- **Path validation**: Use `[ValidateScript({Test-Path $_})]` or manual validation.

### VMware / PowerCLI

- **Least Privilege**: vCenter roles must use minimal required permissions.
- **Certificate validation**: Never silently disabled. Only in session scope with documentation.
- **No global state**: Do not rely on `$global:DefaultVIServer`.
- **Explicit `-Server`**: All PowerCLI cmdlets must receive an explicit `-Server` parameter.

### Logging

- **No sensitive data in logs**: Logs must never contain passwords or credentials.
- **Structured JSON logs**: Use `Write-ModuleLog` for structured logging.
- **Separation of concerns**: Result objects, console output, logs, and exports are separated.

### Secret Scanning

The build process includes an automated secret scan that checks for:
- Hardcoded passwords
- API keys
- Tokens
- Other sensitive patterns

Any detected secrets will cause the build to fail.

## Security Checklist for New Functions

- [ ] No hardcoded credentials
- [ ] Uses `PSCredential` for authentication
- [ ] No `Invoke-Expression`
- [ ] Input validation on all parameters
- [ ] No sensitive data in logs
- [ ] Explicit `-Server` to PowerCLI cmdlets
- [ ] Certificate validation not disabled
- [ ] Least privilege permissions documented