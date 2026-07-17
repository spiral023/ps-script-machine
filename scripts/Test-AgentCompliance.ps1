#Requires -Version 7.4

<#
.SYNOPSIS
    Automated compliance check for public module functions.

.DESCRIPTION
    The Test-AgentCompliance script verifies that all public functions in the
    ps-script-machine module comply with the standards defined in AGENTS.md.

    The following rules are checked for each public function:
    1.  Advanced Function ([CmdletBinding()] present)
    2.  Comment-Based Help (.SYNOPSIS, .DESCRIPTION, .EXAMPLE, .OUTPUTS, .NOTES)
    3.  Approved verb in function name
    4.  Pester test file exists in tests/Unit/
    5.  Documentation file exists in docs/
    6.  No Format-Table/Format-List in the function logic
    7.  No global variables ($global:...) in the function
    8.  No Invoke-Expression in the function
    9.  Modifying functions must have SupportsShouldProcess
    10. Read-only Get-* functions must NOT have SupportsShouldProcess

    Any violation causes the script to throw, failing the build.

.EXAMPLE
    .\scripts\Test-AgentCompliance.ps1

    Runs the compliance check against all public functions.

.OUTPUTS
    None. Throws on any compliance violation.

.NOTES
    This script is called by Invoke-Build.ps1 as part of the build process.
    It ensures that coding agents produce compliant code.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$publicPath = Join-Path $repoRoot 'src\ps-script-machine\Public'
$testsPath = Join-Path $repoRoot 'tests\Unit'
$docsPath = Join-Path $repoRoot 'docs'

$violations = [System.Collections.Generic.List[string]]::new()

# Get all approved verbs
$approvedVerbs = (Get-Verb).Verb

# Get all public function files
$publicFiles = Get-ChildItem -Path "$publicPath\*.ps1" -ErrorAction SilentlyContinue

if ($publicFiles.Count -eq 0) {
    throw "No public function files found in $publicPath"
}

foreach ($file in $publicFiles) {
    $functionName = $file.BaseName
    $content = Get-Content -Path $file.FullName -Raw
    $lines = $content -split "`n"

    Write-Host "  Checking: $functionName" -NoNewline

    # 1. Check for [CmdletBinding()]
    if ($content -notmatch '\[CmdletBinding') {
        $violations.Add("$functionName`: Missing [CmdletBinding()] attribute (not an advanced function)")
    }

    # 2. Check for Comment-Based Help sections
    $helpSections = @('.SYNOPSIS', '.DESCRIPTION', '.EXAMPLE', '.OUTPUTS', '.NOTES')
    foreach ($section in $helpSections) {
        if ($content -notmatch [regex]::Escape($section)) {
            $violations.Add("$functionName`: Missing $section in comment-based help")
        }
    }

    # 3. Check for approved verb
    $verb = ($functionName -split '-')[0]
    if ($verb -notin $approvedVerbs) {
        $violations.Add("$functionName`: Verb '$verb' is not an approved verb. Use Get-Verb to see approved verbs.")
    }

    # 4. Check for Pester test file
    $testFile = Join-Path $testsPath "$functionName.Tests.ps1"
    if (-not (Test-Path $testFile)) {
        $violations.Add("$functionName`: No Pester test file found at $testFile")
    }

    # 5. Check for documentation file
    $docsFile = Join-Path $docsPath "$functionName.md"
    if (-not (Test-Path $docsFile)) {
        $violations.Add("$functionName`: No documentation file found at $docsFile")
    }

    # Helper: Extract only the function code (excluding comment-based help blocks)
    # This prevents false positives from comments mentioning patterns like $global: or SupportsShouldProcess
    $inCommentBlock = $false
    $codeLines = [System.Collections.Generic.List[string]]::new()
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        # Track comment block state (<# ... #>)
        if ($line -match '<#') { $inCommentBlock = $true }
        if ($line -match '#>') { $inCommentBlock = $false; continue }
        if ($inCommentBlock) { continue }
        # Skip single-line comments
        if ($line -match '^\s*#') { continue }
        $codeLines.Add($line)
    }
    $codeContent = $codeLines -join "`n"

    # 6. Check for Format-Table/Format-List in function logic (not in comments)
    $lineNum = 0
    foreach ($line in $codeLines) {
        $lineNum++
        if ($line -match '\bFormat-Table\b' -or $line -match '\bFormat-List\b') {
            $violations.Add("$functionName`: Format-Table/Format-List found in code. Formatting cmdlets must not be used in function logic.")
        }
    }

    # 7. Check for global variables (in code only, not comments)
    $lineNum = 0
    foreach ($line in $codeLines) {
        $lineNum++
        if ($line -match '\$global:') {
            $violations.Add("$functionName`: Global variable found in code. Global variables are not allowed.")
        }
    }

    # 8. Check for Invoke-Expression (in code only, not comments)
    $lineNum = 0
    foreach ($line in $codeLines) {
        $lineNum++
        if ($line -match '\bInvoke-Expression\b' -or $line -match '\biex\b') {
            $violations.Add("$functionName`: Invoke-Expression found in code. This is prohibited.")
        }
    }

    # 9. & 10. SupportsShouldProcess checks (in code only, not comments)
    $isModifying = $verb -in @('Set-', 'New-', 'Remove-', 'Start-', 'Stop-', 'Restart-', 'Import-', 'Export-')
    $hasShouldProcess = $codeContent -match 'SupportsShouldProcess'

    if ($isModifying -and -not $hasShouldProcess) {
        $violations.Add("$functionName`: Modifying function (verb '$verb') must have SupportsShouldProcess.")
    }

    if (-not $isModifying -and $verb -eq 'Get' -and $hasShouldProcess) {
        $violations.Add("$functionName`: Read-only Get-* function should not have SupportsShouldProcess.")
    }

    Write-Host " - OK" -ForegroundColor Green
}

# Report violations
if ($violations.Count -gt 0) {
    Write-Host ""
    Write-Host "Compliance violations found:" -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host "  - $v" -ForegroundColor Red
    }
    throw "$($violations.Count) compliance violation(s) found. See above for details."
}

Write-Host "  All public functions are compliant." -ForegroundColor Green