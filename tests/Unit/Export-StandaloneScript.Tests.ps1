#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for the standalone bundler script Export-StandaloneScript.ps1.
#>

BeforeAll {
    $script:bundlerPath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\scripts\Export-StandaloneScript.ps1'

    # Minimal but structurally complete wrapper following the template contract.
    $script:wrapperContent = @'
#Requires -Version 7.4

<#
.SYNOPSIS
    Testwrapper.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]
    $VCenter
)

$ErrorActionPreference = 'Stop'

#region module-import
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
Import-Module -Name (Resolve-Path -Path $modulePath).Path -Force -ErrorAction Stop
#endregion module-import

Write-Host "Wrapper läuft mit $(@($VCenter).Count) vCentern."
'@
}

Describe 'Export-StandaloneScript' {
    BeforeEach {
        $script:toolsDir = Join-Path $TestDrive "tools-$([guid]::NewGuid())"
        $script:outDir = Join-Path $TestDrive "out-$([guid]::NewGuid())"
        $null = New-Item -Path $script:toolsDir -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $script:toolsDir 'Test-Wrapper.ps1') -Value $script:wrapperContent -Encoding utf8
    }

    It 'creates a standalone file per wrapper' {
        & $script:bundlerPath -ToolsPath $script:toolsDir -OutputPath $script:outDir | Out-Null
        Test-Path -LiteralPath (Join-Path $script:outDir 'Test-Wrapper.ps1') | Should -BeTrue
    }

    It 'produces a syntactically valid script' {
        & $script:bundlerPath -ToolsPath $script:toolsDir -OutputPath $script:outDir | Out-Null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $script:outDir 'Test-Wrapper.ps1'), [ref]$null, [ref]$errors) | Out-Null
        @($errors).Count | Should -Be 0
    }

    It 'embeds every module function (private and public)' {
        & $script:bundlerPath -ToolsPath $script:toolsDir -OutputPath $script:outDir | Out-Null
        $content = Get-Content -LiteralPath (Join-Path $script:outDir 'Test-Wrapper.ps1') -Raw

        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $sourceFiles = Get-ChildItem -Path (Join-Path $repoRoot 'src\ps-script-machine\Private\*.ps1'), (Join-Path $repoRoot 'src\ps-script-machine\Public\*.ps1')
        foreach ($file in $sourceFiles) {
            $content | Should -Match ('function\s+' + [regex]::Escape($file.BaseName))
        }
    }

    It 'removes the module-import region' {
        & $script:bundlerPath -ToolsPath $script:toolsDir -OutputPath $script:outDir | Out-Null
        $content = Get-Content -LiteralPath (Join-Path $script:outDir 'Test-Wrapper.ps1') -Raw
        $content | Should -Not -Match 'ps-script-machine\.psd1'
        $content | Should -Not -Match '#region module-import'
    }

    It 'keeps the param block before the embedded functions' {
        & $script:bundlerPath -ToolsPath $script:toolsDir -OutputPath $script:outDir | Out-Null
        $content = Get-Content -LiteralPath (Join-Path $script:outDir 'Test-Wrapper.ps1') -Raw
        $paramIndex = $content.IndexOf('param(')
        $functionIndex = $content.IndexOf('function ')
        $paramIndex | Should -BeGreaterThan -1
        $functionIndex | Should -BeGreaterThan $paramIndex
    }

    It 'stamps the module version into the header' {
        & $script:bundlerPath -ToolsPath $script:toolsDir -OutputPath $script:outDir | Out-Null
        $content = Get-Content -LiteralPath (Join-Path $script:outDir 'Test-Wrapper.ps1') -Raw
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $manifest = Import-PowerShellDataFile (Join-Path $repoRoot 'src\ps-script-machine\ps-script-machine.psd1')
        $content | Should -Match ([regex]::Escape("ps-script-machine v$($manifest.ModuleVersion)"))
    }

    It 'honors the -Name filter' {
        Set-Content -LiteralPath (Join-Path $script:toolsDir 'Zweiter-Wrapper.ps1') -Value $script:wrapperContent -Encoding utf8
        & $script:bundlerPath -ToolsPath $script:toolsDir -OutputPath $script:outDir -Name 'Test-Wrapper' | Out-Null
        Test-Path -LiteralPath (Join-Path $script:outDir 'Test-Wrapper.ps1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:outDir 'Zweiter-Wrapper.ps1') | Should -BeFalse
    }

    It 'throws for a wrapper without a param block' {
        Set-Content -LiteralPath (Join-Path $script:toolsDir 'Kaputt-Wrapper.ps1') -Value 'Write-Host "kein param"' -Encoding utf8
        { & $script:bundlerPath -ToolsPath $script:toolsDir -OutputPath $script:outDir } |
            Should -Throw '*param*'
    }
}
