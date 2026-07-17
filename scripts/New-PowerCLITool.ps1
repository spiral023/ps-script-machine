#Requires -Version 7.4

<#
.SYNOPSIS
    Generates a new PowerCLI function from templates.

.DESCRIPTION
    The New-PowerCLITool function creates a new PowerCLI function from the
    repository templates. It generates:
    - The function file in src/ps-script-machine/Public/ or Private/
    - A Pester 5 test file in tests/Unit/
    - A README stub in docs/

    The generated function follows all standards defined in AGENTS.md.

    Safety features:
    - Validates function name against approved verbs
    - Validates function name format (Verb-Noun)
    - Prevents path traversal attacks
    - Does not overwrite existing files by default
    - Supports -WhatIf and -Confirm
    - Uses atomic file creation (temp file + rename)
    - Rolls back on partial failures

.PARAMETER FunctionName
    The name of the function to create. Must follow approved verb-noun convention.
    Use Get-Verb to verify the verb is approved.

.PARAMETER Type
    The type of function to create.
    - ReadOnly: A Get-* function that does not modify vSphere configuration.
    - Change: A modifying function (Set-, New-, Remove-, etc.) with SupportsShouldProcess.
    - Private: A private helper function.

.PARAMETER Synopsis
    A brief one-line description for the function's .SYNOPSIS.

.PARAMETER Description
    A detailed description for the function's .DESCRIPTION.

.PARAMETER Force
    If specified, overwrites existing files.

.EXAMPLE
    .\scripts\New-PowerCLITool.ps1 -FunctionName 'Get-VMHostDetail' -Type ReadOnly -Synopsis 'Retrieves detailed VMHost information'

    Creates a new read-only function Get-VMHostDetail with test and docs.

.EXAMPLE
    .\scripts\New-PowerCLITool.ps1 -FunctionName 'Set-VMHostNetwork' -Type Change -Synopsis 'Configures VMHost network settings'

    Creates a new modifying function Set-VMHostNetwork with test and docs.

.NOTES
    The generated files follow all standards defined in AGENTS.md.
    After generation, run .\scripts\Invoke-Build.ps1 to validate.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]
    $FunctionName,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateSet('ReadOnly', 'Change', 'Private')]
    [string]
    $Type,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Synopsis = 'Brief one-line description of what the function does.',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Description = 'Detailed description of the function, its purpose, and behavior.',

    [Parameter(Mandatory = $false)]
    [switch]
    $Force
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$templatePath = Join-Path $repoRoot 'templates'
$srcPath = Join-Path $repoRoot 'src\ps-script-machine'
$testsPath = Join-Path $repoRoot 'tests\Unit'
$docsPath = Join-Path $repoRoot 'docs'

# Validate function name format (must be Verb-Noun)
if ($FunctionName -notmatch '^[A-Z][a-zA-Z0-9]*-[A-Z][a-zA-Z0-9]*$') {
    Write-Error "Function name '$FunctionName' does not follow the Verb-Noun convention (e.g., Get-VMHostDetail)."
    exit 1
}

# Validate function name against approved verbs
$verb = ($FunctionName -split '-')[0]
$approvedVerbs = (Get-Verb).Verb
if ($verb -notin $approvedVerbs) {
    Write-Error "Verb '$verb' is not an approved verb. Use Get-Verb to see approved verbs."
    exit 1
}

# Prevent path traversal: ensure function name doesn't contain path separators
if ($FunctionName -match '[\\/]' -or $FunctionName -match '\.\.') {
    Write-Error "Function name contains invalid characters (path separators or traversal sequences)."
    exit 1
}

# Determine target directory and template
switch ($Type) {
    'ReadOnly' {
        $targetDir = Join-Path $srcPath 'Public'
        $templateFile = Join-Path $templatePath 'PublicFunction.ps1'
        $testTemplate = Join-Path $templatePath 'PesterTest.Tests.ps1'
    }
    'Change' {
        $targetDir = Join-Path $srcPath 'Public'
        $templateFile = Join-Path $templatePath 'PublicFunction.ps1'
        $testTemplate = Join-Path $templatePath 'PesterTest.Tests.ps1'
    }
    'Private' {
        $targetDir = Join-Path $srcPath 'Private'
        $templateFile = Join-Path $templatePath 'PrivateFunction.ps1'
        $testTemplate = Join-Path $templatePath 'PesterTest.Tests.ps1'
    }
}

# Ensure directories exist
if (-not (Test-Path $targetDir)) {
    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $testsPath)) {
    New-Item -Path $testsPath -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $docsPath)) {
    New-Item -Path $docsPath -ItemType Directory -Force | Out-Null
}

# Define output file paths
$functionFile = Join-Path $targetDir "$FunctionName.ps1"
$testFile = Join-Path $testsPath "$FunctionName.Tests.ps1"
$docsFile = Join-Path $docsPath "$FunctionName.md"

# Check for existing files (unless -Force)
if (-not $Force) {
    if (Test-Path $functionFile) {
        Write-Error "Function file already exists: $functionFile. Use -Force to overwrite."
        exit 1
    }
    if (Test-Path $testFile) {
        Write-Error "Test file already exists: $testFile. Use -Force to overwrite."
        exit 1
    }
    if (Test-Path $docsFile) {
        Write-Error "Docs file already exists: $docsFile. Use -Force to overwrite."
        exit 1
    }
}

# Read template
if (-not (Test-Path $templateFile)) {
    Write-Error "Template file not found: $templateFile"
    exit 1
}

$templateContent = Get-Content -Path $templateFile -Raw

# Replace placeholders in template
$functionContent = $templateContent -replace 'Get-Something', $FunctionName
$functionContent = $functionContent -replace 'Brief one-line description of what the function does\.', $Synopsis
$functionContent = $functionContent -replace 'Detailed description of the function, its purpose, and behavior\.', $Description

# For Change type, add SupportsShouldProcess
if ($Type -eq 'Change') {
    $functionContent = $functionContent -replace '\[CmdletBinding\(\)\]', '[CmdletBinding(SupportsShouldProcess, ConfirmImpact = ''High'')]'
    $functionContent = $functionContent -replace 'ps-script-machine\.Something', "ps-script-machine.$FunctionName"
}

# Update PSTypeName
$functionContent = $functionContent -replace 'ps-script-machine\.Something', "ps-script-machine.$FunctionName"

# Read test template and create test content
$testContent = $null
if (Test-Path $testTemplate) {
    $testContent = Get-Content -Path $testTemplate -Raw
    $testContent = $testContent -replace 'Get-Something', $FunctionName
    $testContent = $testContent -replace 'ps-script-machine\.Something', "ps-script-machine.$FunctionName"
}

# Create docs content
$docsContent = @"
# $FunctionName

## Synopsis

$Synopsis

## Description

$Description

## Type

$Type

## Parameters

| Parameter | Type | Mandatory | Description |
|-----------|------|-----------|-------------|
| VIServer | VIServer[] | Yes | vCenter connection |
| Name | string[] | No | Filter by name |

## Examples

``````powershell
`$session = Connect-VIServerSession -Server 'vcenter.example.com' -Credential `$cred
$FunctionName -VIServer `$session
``````

## Required vSphere Permissions

- System.Read

## Notes

See AGENTS.md for the complete Definition of Done.
"@

# Track created files for rollback
$createdFiles = [System.Collections.Generic.List[string]]::new()
$rollbackOnError = $true

try {
    # Write function file (atomic: temp file + rename)
    if ($PSCmdlet.ShouldProcess($functionFile, 'Create function file')) {
        $tempFile = "$functionFile.tmp"
        Set-Content -Path $tempFile -Value $functionContent -Encoding UTF8 -ErrorAction Stop
        if (Test-Path $functionFile) {
            Remove-Item -Path $functionFile -Force -ErrorAction Stop
        }
        Rename-Item -Path $tempFile -NewName $functionFile -ErrorAction Stop
        $createdFiles.Add($functionFile)
        Write-Host "Created function: $functionFile" -ForegroundColor Green
    }

    # Write test file (atomic)
    if ($testContent -and $PSCmdlet.ShouldProcess($testFile, 'Create test file')) {
        $tempFile = "$testFile.tmp"
        Set-Content -Path $tempFile -Value $testContent -Encoding UTF8 -ErrorAction Stop
        if (Test-Path $testFile) {
            Remove-Item -Path $testFile -Force -ErrorAction Stop
        }
        Rename-Item -Path $tempFile -NewName $testFile -ErrorAction Stop
        $createdFiles.Add($testFile)
        Write-Host "Created test: $testFile" -ForegroundColor Green
    }

    # Write docs file (atomic)
    if ($PSCmdlet.ShouldProcess($docsFile, 'Create docs file')) {
        $tempFile = "$docsFile.tmp"
        Set-Content -Path $tempFile -Value $docsContent -Encoding UTF8 -ErrorAction Stop
        if (Test-Path $docsFile) {
            Remove-Item -Path $docsFile -Force -ErrorAction Stop
        }
        Rename-Item -Path $tempFile -NewName $docsFile -ErrorAction Stop
        $createdFiles.Add($docsFile)
        Write-Host "Created docs: $docsFile" -ForegroundColor Green
    }
}
catch {
    Write-Error "Generation failed: $_"

    # Rollback: remove all created files
    if ($rollbackOnError -and -not $Force) {
        Write-Host "Rolling back: removing created files..." -ForegroundColor Yellow
        foreach ($file in $createdFiles) {
            try {
                Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
                Write-Host "  Removed: $file" -ForegroundColor Yellow
            }
            catch {
                Write-Warning "Could not remove $file during rollback: $_"
            }
        }
    }
    exit 1
}

# Summary
Write-Host "`n=== Generation Summary ===" -ForegroundColor Cyan
Write-Host "Function: $FunctionName" -ForegroundColor White
Write-Host "Type: $Type" -ForegroundColor White
Write-Host "Function file: $functionFile" -ForegroundColor White
Write-Host "Test file: $testFile" -ForegroundColor White
Write-Host "Docs file: $docsFile" -ForegroundColor White
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Edit the function to implement your logic" -ForegroundColor Yellow
Write-Host "2. Edit the test to mock PowerCLI cmdlets and add test cases" -ForegroundColor Yellow
Write-Host "3. Run: .\scripts\Invoke-Build.ps1" -ForegroundColor Yellow
Write-Host "4. Update README and CHANGELOG" -ForegroundColor Yellow