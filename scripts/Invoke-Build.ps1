#Requires -Version 7.4

<#
.SYNOPSIS
    Unified build process for ps-script-machine module.

.DESCRIPTION
    The Invoke-Build function runs the complete quality assurance and build
    process for the ps-script-machine module. It works identically locally
    and in CI.

    The build process consists of:
    1. Module manifest validation
    2. PSScriptAnalyzer (fails on warnings in CI mode)
    3. Pester unit tests
    4. Code coverage (fails if below threshold or 0%)
    5. Documentation check
    6. Module build
    7. Secret scan (check for accidentally committed secrets)
    8. Agent compliance check

    Any failure in steps 1-8 causes the build to fail.

.PARAMETER Task
    The build task to run. If not specified, all tasks are run.
    Valid values: Manifest, Analyze, Test, Coverage, Docs, Build, Secrets, Compliance, All

.PARAMETER CodeCoverageThreshold
    The minimum code coverage percentage. Default: 80.
    A value of 0% will cause the build to fail.

.PARAMETER OutputPath
    The path for build output. Default: build/output

.PARAMETER CI
    If specified, PSScriptAnalyzer warnings cause the build to fail (CI mode).

.EXAMPLE
    .\scripts\Invoke-Build.ps1

    Runs all build tasks with default settings.

.EXAMPLE
    .\scripts\Invoke-Build.ps1 -Task Analyze

    Runs only the PSScriptAnalyzer task.

.EXAMPLE
    .\scripts\Invoke-Build.ps1 -CodeCoverageThreshold 90

    Runs all tasks with a 90% code coverage threshold.

.EXAMPLE
    .\scripts\Invoke-Build.ps1 -CI

    Runs all tasks in CI mode (analyzer warnings are fatal).

.NOTES
    This script is designed to work identically locally and in CI.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Manifest', 'Analyze', 'Test', 'Coverage', 'Docs', 'Build', 'Secrets', 'Compliance', 'All')]
    [string[]]
    $Task = @('All'),

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 100)]
    [int]
    $CodeCoverageThreshold = 80,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $OutputPath = (Join-Path $PSScriptRoot '..\build\output'),

    [Parameter(Mandatory = $false)]
    [switch]
    $CI
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$modulePath = Join-Path $repoRoot 'src\ps-script-machine\ps-script-machine.psd1'
$srcPath = Join-Path $repoRoot 'src'
$testsPath = Join-Path $repoRoot 'tests'
$analyzerSettings = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'

$runAll = $Task -contains 'All'
$results = [ordered]@{}

function Invoke-BuildTask {
    param([string]$Name, [scriptblock]$Action)
    Write-Host "`n=== Running: $Name ===" -ForegroundColor Cyan
    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $Action
        $stopWatch.Stop()
        $results[$Name] = [ordered]@{ Status = 'Passed'; Duration = $stopWatch.Elapsed.TotalSeconds }
        Write-Host "PASSED: $Name ($($stopWatch.Elapsed.TotalSeconds)s)`n" -ForegroundColor Green
    }
    catch {
        $stopWatch.Stop()
        $results[$Name] = [ordered]@{ Status = 'Failed'; Duration = $stopWatch.Elapsed.TotalSeconds; Error = $_.Exception.Message }
        Write-Host "FAILED: $Name ($($stopWatch.Elapsed.TotalSeconds)s)" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Task 1: Manifest validation
if ($runAll -or $Task -contains 'Manifest') {
    Invoke-BuildTask -Name 'Manifest' -Action {
        Write-Host "Validating module manifest..."
        $manifest = Test-ModuleManifest -Path $modulePath -ErrorAction Stop
        Write-Host "  Module: $($manifest.Name) v$($manifest.Version)"
        Write-Host "  PowerShell: $($manifest.PowerShellVersion)"
        Write-Host "  Required modules: $($manifest.RequiredModules.Name -join ', ')"
        Write-Host "  Exported functions: $($manifest.ExportedFunctions.Keys -join ', ')"

        # Verify that FunctionsToExport is not empty (wildcard exports are not allowed)
        $manifestData = Import-PowerShellDataFile -Path $modulePath
        if ($manifestData.FunctionsToExport -contains '*' -or $manifestData.FunctionsToExport.Count -eq 0) {
            throw "FunctionsToExport must be an explicit list, not empty or wildcard."
        }

        # Verify that private functions are NOT exported
        $privateFuncPath = Join-Path $repoRoot 'src\ps-script-machine\Private'
        $privateFuncs = Get-ChildItem -Path "$privateFuncPath\*.ps1" -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty BaseName
        foreach ($pf in $privateFuncs) {
            if ($manifestData.FunctionsToExport -contains $pf) {
                throw "Private function '$pf' must not be in FunctionsToExport."
            }
        }
    }
}

# Task 2: PSScriptAnalyzer
if ($runAll -or $Task -contains 'Analyze') {
    Invoke-BuildTask -Name 'Analyze' -Action {
        Write-Host "Running PSScriptAnalyzer..."
        if (-not (Get-Module -ListAvailable -Name 'PSScriptAnalyzer' -ErrorAction SilentlyContinue)) {
            Write-Host "  PSScriptAnalyzer not installed. Installing..."
            Install-Module -Name 'PSScriptAnalyzer' -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
        }
        $analyzerResults = Invoke-ScriptAnalyzer -Path $srcPath -Settings $analyzerSettings -Severity Error, Warning -Recurse
        if ($analyzerResults) {
            $errors = $analyzerResults | Where-Object Severity -eq 'Error'
            $warnings = $analyzerResults | Where-Object Severity -eq 'Warning'
            Write-Host "  Errors: $($errors.Count)"
            Write-Host "  Warnings: $($warnings.Count)"
            if ($errors.Count -gt 0) {
                $errors | Format-Table -AutoSize
                throw "PSScriptAnalyzer found $($errors.Count) error(s)"
            }
            if ($warnings.Count -gt 0) {
                Write-Host "  Warnings:"
                $warnings | Format-Table -AutoSize
                # In CI mode, warnings are fatal
                if ($CI) {
                    throw "PSScriptAnalyzer found $($warnings.Count) warning(s). In CI mode, warnings are fatal."
                }
            }
        }
        else {
            Write-Host "  No issues found."
        }
    }
}

# Task 3: Pester unit tests
if ($runAll -or $Task -contains 'Test') {
    Invoke-BuildTask -Name 'Test' -Action {
        Write-Host "Running Pester unit tests..."
        # Ensure Pester 5 is used (not Pester 6 which has breaking changes)
        $pester5 = Get-Module -ListAvailable -Name 'Pester' -ErrorAction SilentlyContinue |
            Where-Object { $_.Version -ge '5.0' -and $_.Version -lt '6.0' } |
            Sort-Object Version -Descending | Select-Object -First 1
        if (-not $pester5) {
            Write-Host "  Pester 5 not installed. Installing..."
            Install-Module -Name 'Pester' -MinimumVersion 5.0 -MaximumVersion 5.99 -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
            $pester5 = Get-Module -ListAvailable -Name 'Pester' -ErrorAction SilentlyContinue |
                Where-Object { $_.Version -ge '5.0' -and $_.Version -lt '6.0' } |
                Sort-Object Version -Descending | Select-Object -First 1
        }
        if (-not $pester5) {
            throw "Pester 5.x is required but not found. Install with: Install-Module Pester -MaximumVersion 5.99 -Force"
        }
        Write-Host "  Using Pester $($pester5.Version)"
        # Remove any loaded Pester module to ensure we use the correct version
        Remove-Module -Name 'Pester' -Force -ErrorAction SilentlyContinue
        Import-Module -Name 'Pester' -RequiredVersion $pester5.Version -Force

        $unitTestPath = Join-Path $testsPath 'Unit'
        $pesterConfig = New-PesterConfiguration -Hashtable @{
            Run = @{
                Path = $unitTestPath
                PassThru = $true
            }
            Output = @{
                Verbosity = 'Normal'
            }
            Should = @{
                ErrorAction = 'Stop'
            }
        }
        $pesterResult = Invoke-Pester -Configuration $pesterConfig
        if ($pesterResult.FailedCount -gt 0) {
            throw "Pester tests failed: $($pesterResult.FailedCount) test(s) failed"
        }
        Write-Host "  Passed: $($pesterResult.PassedCount)"
        Write-Host "  Failed: $($pesterResult.FailedCount)"
        Write-Host "  Skipped: $($pesterResult.SkippedCount)"
    }
}

# Task 4: Code coverage
if ($runAll -or $Task -contains 'Coverage') {
    Invoke-BuildTask -Name 'Coverage' -Action {
        Write-Host "Running code coverage analysis..."
        $unitTestPath = Join-Path $testsPath 'Unit'
        $coveragePaths = @(
            (Join-Path $srcPath 'ps-script-machine\Public\*.ps1')
            (Join-Path $srcPath 'ps-script-machine\Private\*.ps1')
        )

        # Ensure output directory exists
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }

        $pesterConfig = New-PesterConfiguration -Hashtable @{
            Run = @{
                Path = $unitTestPath
                PassThru = $true
            }
            CodeCoverage = @{
                Enabled = $true
                Path = $coveragePaths
                OutputFormat = 'JaCoCo'
                OutputPath = Join-Path $OutputPath 'coverage.xml'
                UseBreakpoints = $false
            }
            Output = @{
                Verbosity = 'Normal'
            }
        }
        $pesterResult = Invoke-Pester -Configuration $pesterConfig

        # Check if coverage measurement worked at all
        if ($null -eq $pesterResult.CodeCoverage) {
            throw "Code coverage measurement failed: no CodeCoverage object returned."
        }

        $coveragePercent = [math]::Round($pesterResult.CodeCoverage.CoveragePercent, 2)

        # Report per-file coverage
        Write-Host "  Per-file coverage:"
        if ($pesterResult.CodeCoverage.FilesCovered) {
            foreach ($file in $pesterResult.CodeCoverage.FilesCovered) {
                $fileCoverage = [math]::Round($file.CoveragePercent, 2)
                $fileName = Split-Path -Leaf $file.Path
                Write-Host "    $fileName`: $fileCoverage%"
            }
        }

        Write-Host "  Overall coverage: $coveragePercent%"
        Write-Host "  Threshold: $CodeCoverageThreshold%"

        # 0% coverage is always a failure - it means coverage measurement is broken
        if ($coveragePercent -eq 0) {
            throw "Code coverage is 0%. This means coverage measurement is broken or no code was executed. Build fails."
        }

        # Below threshold is a failure
        if ($coveragePercent -lt $CodeCoverageThreshold) {
            throw "Code coverage $coveragePercent% is below threshold $CodeCoverageThreshold%. Build fails."
        }

        Write-Host "  Coverage check passed."
    }
}

# Task 5: Documentation check
if ($runAll -or $Task -contains 'Docs') {
    Invoke-BuildTask -Name 'Docs' -Action {
        Write-Host "Checking documentation..."
        $publicFunctions = Get-ChildItem -Path (Join-Path $srcPath 'ps-script-machine\Public\*.ps1') -ErrorAction SilentlyContinue
        foreach ($file in $publicFunctions) {
            $content = Get-Content -Path $file.FullName -Raw
            # Check for SYNOPSIS
            if ($content -notmatch '\.SYNOPSIS') {
                throw "Missing .SYNOPSIS in $($file.Name)"
            }
            # Check for DESCRIPTION
            if ($content -notmatch '\.DESCRIPTION') {
                throw "Missing .DESCRIPTION in $($file.Name)"
            }
            # Check for at least one EXAMPLE
            if ($content -notmatch '\.EXAMPLE') {
                throw "Missing .EXAMPLE in $($file.Name)"
            }
            # Check for OUTPUTS
            if ($content -notmatch '\.OUTPUTS') {
                throw "Missing .OUTPUTS in $($file.Name)"
            }
            # Check for NOTES
            if ($content -notmatch '\.NOTES') {
                throw "Missing .NOTES in $($file.Name)"
            }
            Write-Host "  $($file.Name): OK"
        }
    }
}

# Task 6: Module build
if ($runAll -or $Task -contains 'Build') {
    Invoke-BuildTask -Name 'Build' -Action {
        Write-Host "Building module..."
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
        $buildOutput = Join-Path $OutputPath 'ps-script-machine'
        if (Test-Path $buildOutput) {
            Remove-Item -Path $buildOutput -Recurse -Force
        }
        Copy-Item -Path (Join-Path $srcPath 'ps-script-machine') -Destination $buildOutput -Recurse -Force
        Write-Host "  Built to: $buildOutput"
        # Verify the built module can be imported
        $builtManifest = Join-Path $buildOutput 'ps-script-machine.psd1'
        Test-ModuleManifest -Path $builtManifest -ErrorAction Stop | Out-Null
        Write-Host "  Built module manifest is valid."
    }
}

# Task 7: Secret scan
if ($runAll -or $Task -contains 'Secrets') {
    Invoke-BuildTask -Name 'Secrets' -Action {
        Write-Host "Scanning for accidentally committed secrets..."
        # Exclude test files, build output, and documentation files that contain
        # anti-pattern examples (AGENTS.md, CLAUDE.md) from secret scanning.
        # Test files use mock credentials that are not real secrets.
        $allFiles = Get-ChildItem -Path $repoRoot -Recurse -Include '*.ps1','*.psm1','*.psd1','*.json','*.md' -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '\\\.git\\' -and
                $_.FullName -notmatch 'node_modules' -and
                $_.FullName -notmatch '\\tests\\' -and
                $_.FullName -notmatch '\\build\\' -and
                $_.Name -ne 'AGENTS.md' -and
                $_.Name -ne 'CLAUDE.md'
            }
        $secretPatterns = @(
            '(?i)password\s*=\s*[''"][^''"]{4,}[''"]',
            '(?i)passwd\s*=\s*[''"][^''"]{4,}[''"]',
            '(?i)secret\s*=\s*[''"][^''"]{4,}[''"]',
            '(?i)api[_-]?key\s*=\s*[''"][^''"]{4,}[''"]',
            '(?i)token\s*=\s*[''"][^''"]{4,}[''"]'
        )
        $found = $false
        foreach ($file in $allFiles) {
            $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            foreach ($pattern in $secretPatterns) {
                $matches = [regex]::Matches($content, $pattern)
                if ($matches.Count -gt 0) {
                    # Skip if it's in a comment or example
                    $lines = $content -split "`n"
                    $lineNum = 0
                    foreach ($line in $lines) {
                        $lineNum++
                        if ($line -match $pattern -and $line -notmatch '^\s*#' -and $line -notmatch 'example' -and $line -notmatch 'Get-Credential' -and $line -notmatch 'ConvertTo-SecureString') {
                            Write-Host "  POTENTIAL SECRET in $($file.Name):$lineNum - $line" -ForegroundColor Yellow
                            $found = $true
                        }
                    }
                }
            }
        }
        if ($found) {
            throw "Potential secrets found in source files. Review and remove before committing."
        }
        Write-Host "  No secrets found."
    }
}

# Task 8: Agent compliance check
if ($runAll -or $Task -contains 'Compliance') {
    Invoke-BuildTask -Name 'Compliance' -Action {
        Write-Host "Running agent compliance check..."
        $complianceScript = Join-Path $repoRoot 'scripts\Test-AgentCompliance.ps1'
        if (-not (Test-Path $complianceScript)) {
            throw "Compliance script not found: $complianceScript"
        }
        & $complianceScript -ErrorAction Stop
    }
}

# Summary
Write-Host "`n=== Build Summary ===" -ForegroundColor Cyan
foreach ($key in $results.Keys) {
    $status = $results[$key].Status
    $color = if ($status -eq 'Passed') { 'Green' } else { 'Red' }
    Write-Host "  $key`: $status ($($results[$key].Duration)s)" -ForegroundColor $color
}
Write-Host ""

$failed = $results.Values | Where-Object { $_.Status -eq 'Failed' }
if ($failed) {
    exit 1
}