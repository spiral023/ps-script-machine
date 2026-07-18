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
    7. Standalone script bundling
    8. Secret scan (check for accidentally committed secrets)
    9. Agent compliance check

    Tasks run in the order above. If a task fails, no further tasks are
    attempted - but a full summary is always printed at the end, showing
    every requested task as Passed, Failed, or Not Run. This makes it
    immediately clear (in CI logs and to coding agents) which gate failed
    and which later gates were never reached, rather than ending on a bare
    exception with no summary at all.

.PARAMETER Task
    The build task to run. If not specified, all tasks are run.
    Valid values: Manifest, Analyze, Test, Coverage, Docs, Build, Standalone, Secrets, Compliance, All

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
    [ValidateSet('Manifest', 'Analyze', 'Test', 'Coverage', 'Docs', 'Build', 'Standalone', 'Secrets', 'Compliance', 'All')]
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

# Canonical task order. A task's position here also defines its place in
# the fail-fast sequence below: once any task fails, every task after it
# in this list is skipped and reported as 'Not Run'.
$taskOrder = @('Manifest', 'Analyze', 'Test', 'Coverage', 'Docs', 'Build', 'Standalone', 'Secrets', 'Compliance')

$taskActions = [ordered]@{
    Manifest = {
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

    Analyze = {
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

    Test = {
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

    Coverage = {
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

    Docs = {
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

    Build = {
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

    Standalone = {
        Write-Host "Building standalone scripts..."
        $standaloneScript = Join-Path $repoRoot 'scripts\Export-StandaloneScript.ps1'
        if (-not (Test-Path $standaloneScript)) {
            throw "Standalone bundler not found: $standaloneScript"
        }
        $created = & $standaloneScript -ErrorAction Stop
        foreach ($file in @($created)) {
            Write-Host "  Created: $file"
        }
    }

    Secrets = {
        Write-Host "Scanning for accidentally committed secrets..."
        # Scan the entire repository, including tests/, docs/, AGENTS.md and
        # CLAUDE.md - a real secret pasted into a test fixture or into agent
        # instructions is exactly as dangerous as one in src/. Only the
        # generated build/output/ directory is excluded, because it is a
        # verbatim copy of src/ (already scanned) recreated on every build.
        #
        # Intentional, non-secret example values (documented anti-pattern
        # code samples, redaction-test fixtures) are allowlisted ONLY via an
        # explicit, narrow, per-line marker comment: `secret-scan:ignore`.
        # This replaces a previous loose heuristic (skip any line containing
        # the word "example", "Get-Credential", or "ConvertTo-SecureString"
        # anywhere) that could both hide a real secret sitting next to one of
        # those words and was not auditable - the marker makes every allowed
        # exception explicit, greppable, and reviewable in a diff.
        $allowlistMarker = 'secret-scan:ignore'
        $allFiles = Get-ChildItem -Path $repoRoot -Recurse -Include '*.ps1', '*.psm1', '*.psd1', '*.json', '*.md' -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '\\\.git\\' -and
                $_.FullName -notmatch 'node_modules' -and
                $_.FullName -notmatch '\\build\\'
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
                $patternMatches = [regex]::Matches($content, $pattern)
                if ($patternMatches.Count -gt 0) {
                    $lines = $content -split "`n"
                    $lineNum = 0
                    foreach ($line in $lines) {
                        $lineNum++
                        if ($line -match $pattern -and $line -notmatch '^\s*#' -and $line -notmatch [regex]::Escape($allowlistMarker)) {
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

    Compliance = {
        Write-Host "Running agent compliance check..."
        $complianceScript = Join-Path $repoRoot 'scripts\Test-AgentCompliance.ps1'
        if (-not (Test-Path $complianceScript)) {
            throw "Compliance script not found: $complianceScript"
        }
        & $complianceScript -ErrorAction Stop
    }
}

# Only the tasks actually requested (in canonical order) are attempted and
# reported. Everything else in $taskOrder is irrelevant to this run.
$requestedTasks = if ($runAll) { $taskOrder } else { $taskOrder | Where-Object { $Task -contains $_ } }

$results = [ordered]@{}
foreach ($name in $requestedTasks) {
    $results[$name] = [ordered]@{ Status = 'Not Run'; Duration = 0.0; Error = $null }
}

$buildFailed = $false

try {
    foreach ($name in $requestedTasks) {
        if ($buildFailed) {
            # A prior task already failed: skip remaining tasks rather than
            # run further gates against a build that is already known bad.
            # The task stays 'Not Run' in $results and shows up as such in
            # the summary below.
            continue
        }

        Write-Host "`n=== Running: $name ===" -ForegroundColor Cyan
        $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            & $taskActions[$name]
            $stopWatch.Stop()
            $results[$name] = [ordered]@{ Status = 'Passed'; Duration = $stopWatch.Elapsed.TotalSeconds; Error = $null }
            Write-Host "PASSED: $name ($($stopWatch.Elapsed.TotalSeconds)s)`n" -ForegroundColor Green
        }
        catch {
            $stopWatch.Stop()
            $results[$name] = [ordered]@{ Status = 'Failed'; Duration = $stopWatch.Elapsed.TotalSeconds; Error = $_.Exception.Message }
            Write-Host "FAILED: $name ($($stopWatch.Elapsed.TotalSeconds)s)" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            $buildFailed = $true
        }
    }
}
finally {
    # This summary always runs - even if a task above throws in a way that
    # was not expected to be caught - so a coding agent or a human reading
    # CI output can always see the full picture: what passed, what failed,
    # and what was never reached because of that failure.
    Write-Host "`n=== Build Summary ===" -ForegroundColor Cyan
    foreach ($name in $requestedTasks) {
        $status = $results[$name].Status
        $color = switch ($status) {
            'Passed' { 'Green' }
            'Failed' { 'Red' }
            default { 'DarkGray' }
        }
        $durationText = if ($results[$name].Duration -gt 0) {
            " ($([math]::Round($results[$name].Duration, 2))s)"
        }
        else {
            ''
        }
        Write-Host ("  {0,-14}{1}{2}" -f $name, $status.ToUpper(), $durationText) -ForegroundColor $color
    }
    Write-Host ""
}

if ($buildFailed) {
    Write-Host "Build failed with exit code 1." -ForegroundColor Red
    exit 1
}

Write-Host "Build succeeded." -ForegroundColor Green
exit 0
