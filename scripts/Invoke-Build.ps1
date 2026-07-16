<#
.SYNOPSIS
    Build-Skript: Führt PSScriptAnalyzer und Pester-Tests aus.

.DESCRIPTION
    Dieses Skript ist der zentrale Einstiegspunkt für die lokale Qualitätssicherung.
    Es führt nacheinander aus:
    1. PSScriptAnalyzer über alle .ps1/.psm1-Dateien
    2. Pester-Tests im tests/-Verzeichnis
    3. Optional: Code-Coverage-Report

.PARAMETER SkipAnalysis
    Überspringt PSScriptAnalyzer.

.PARAMETER SkipTests
    Überspringt Pester-Tests.

.PARAMETER Coverage
    Aktiviert Code-Coverage in Pester.

.EXAMPLE
    ./scripts/Invoke-Build.ps1
    Führt Analyse und Tests aus.

.EXAMPLE
    ./scripts/Invoke-Build.ps1 -Coverage
    Führt Analyse und Tests mit Code-Coverage aus.
#>

[CmdletBinding()]
param(
    [switch]$SkipAnalysis,
    [switch]$SkipTests,
    [switch]$Coverage
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent -Path $PSScriptRoot

Write-Host "=== PowerShell Build & Quality Check ===" -ForegroundColor Cyan
Write-Host "Repository: $repoRoot"
Write-Host ""

# ---------------------------------------------------------------------------
# 1. PSScriptAnalyzer
# ---------------------------------------------------------------------------
if (-not $SkipAnalysis) {
    Write-Host "--- [1/2] PSScriptAnalyzer ---" -ForegroundColor Yellow

    $analyzerModule = Get-Module -ListAvailable -Name PSScriptAnalyzer | Select-Object -First 1

    if (-not $analyzerModule) {
        Write-Warning "PSScriptAnalyzer ist nicht installiert. Installation wird versucht..."
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck
    }

    $settingsPath = Join-Path -Path $repoRoot -ChildPath "PSScriptAnalyzerSettings.psd1"

    $analysisResults = Invoke-ScriptAnalyzer `
        -Path $repoRoot `
        -Recurse `
        -Settings $settingsPath `
        -Severity Error, Warning, Information

    if ($analysisResults) {
        $errors = $analysisResults | Where-Object Severity -eq 'Error'
        $warnings = $analysisResults | Where-Object Severity -eq 'Warning'
        $infos = $analysisResults | Where-Object Severity -eq 'Information'

        Write-Host "  Errors:       $($errors.Count)" -ForegroundColor Red
        Write-Host "  Warnings:     $($warnings.Count)" -ForegroundColor Yellow
        Write-Host "  Information:  $($infos.Count)" -ForegroundColor Gray

        if ($errors.Count -gt 0) {
            Write-Host ""
            Write-Host "=== ERRORS ===" -ForegroundColor Red
            $errors | Format-Table -AutoSize
        }

        if ($errors.Count -gt 0) {
            Write-Error "PSScriptAnalyzer hat $($errors.Count) Error(s) gefunden."
            exit 1
        }
    }
    else {
        Write-Host "  Keine Probleme gefunden." -ForegroundColor Green
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# 2. Pester Tests
# ---------------------------------------------------------------------------
if (-not $SkipTests) {
    Write-Host "--- [2/2] Pester Tests ---" -ForegroundColor Yellow

    $pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object Version -ge '5.0' | Select-Object -First 1

    if (-not $pesterModule) {
        Write-Warning "Pester 5+ ist nicht installiert. Installation wird versucht..."
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck -MinimumVersion 5.0
    }

    $testsPath = Join-Path -Path $repoRoot -ChildPath "tests"
    $testResultsPath = Join-Path -Path $repoRoot -ChildPath "TestResults"

    if (-not (Test-Path -LiteralPath $testResultsPath)) {
        $null = New-Item -ItemType Directory -Path $testResultsPath -Force
    }

    $configuration = [PesterConfiguration]@{
        Run    = @{
            Path     = $testsPath
            PassThru = $true
        }
        Output = @{
            Verbosity = 'Detailed'
        }
        TestResult = @{
            Enabled      = $true
            OutputFormat = 'NUnitXml'
            OutputPath   = Join-Path -Path $testResultsPath -ChildPath 'test-results.xml'
        }
    }

    if ($Coverage) {
        $configuration.CodeCoverage.Enabled = $true
        $configuration.CodeCoverage.Path = Join-Path -Path $repoRoot -ChildPath '*.ps1'
        $configuration.CodeCoverage.OutputPath = Join-Path -Path $testResultsPath -ChildPath 'coverage.xml'
    }

    $result = Invoke-Pester -Configuration $configuration

    Write-Host ""
    Write-Host "  Passed:  $($result.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed:  $($result.FailedCount)" -ForegroundColor Red
    Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "  Total:   $($result.TotalCount)"

    if ($result.FailedCount -gt 0) {
        Write-Error "$($result.FailedCount) Pester-Test(s) fehlgeschlagen."
        exit 1
    }
    Write-Host ""
}

Write-Host "=== Build erfolgreich abgeschlossen ===" -ForegroundColor Green