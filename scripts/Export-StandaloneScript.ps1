<#
.SYNOPSIS
    Baut eigenständige Single-File-Skripte aus den Wrappern in scripts/tools/.

.DESCRIPTION
    Mechanik V1: Es werden ALLE Modul-Funktionen (Private zuerst, dann Public)
    eingebettet - es gibt kein Dependency-Walking, das nur die tatsächlich
    benötigten Funktionen ermitteln würde. Das hält den Bundler einfach und
    robust; der Nachteil ist ein etwas größeres Ergebnis-Skript.

    Der Bundler steht in einem Vertrag mit dem Wrapper-Template
    (templates/InteractiveWrapper.ps1, siehe Task 5): jeder Wrapper in
    scripts/tools/ muss einen `param`-Block besitzen (Einbettungspunkt) und
    seinen Modul-Import in einer Region `#region module-import` …
    `#endregion module-import` kapseln. Diese Region wird beim Bündeln
    ersatzlos entfernt, weil die Modul-Funktionen direkt in das Ergebnis-
    Skript eingebettet werden.

    Für jeden Wrapper wird der Kopf (Comment-Based Help + param-Block) vom
    Rumpf (Skriptlogik) getrennt. Zwischen beiden wird die Skript-Scope-
    Initialisierung (`$script:ModuleVersion`, `$script:LogRunId`,
    `$script:ModuleSessions`) sowie der Quellcode aller Modul-Funktionen
    eingefügt.

    Verifikation in zwei Stufen je erzeugtem Skript:
    1. Der PowerShell-Parser prüft die Syntax (Parse-Fehler sind fatal).
    2. PSScriptAnalyzer prüft ausschließlich auf Severity "Error" (Warnungen
       sind für Konsolen-Tools zulässig, siehe scripts/ Scope-Ausnahme in
       PSScriptAnalyzerSettings.psd1).

.PARAMETER ToolsPath
    Ordner mit den Wrapper-Skripten. Standard: scripts/tools (relativ zu
    diesem Skript).

.PARAMETER OutputPath
    Zielordner für die gebündelten Standalone-Skripte. Standard:
    build/standalone (relativ zu diesem Skript).

.PARAMETER Name
    Optionaler Filter: nur Wrapper mit diesen Basisnamen (ohne .ps1) werden
    gebündelt. Ohne Angabe werden alle Wrapper in -ToolsPath verarbeitet.

.EXAMPLE
    .\scripts\Export-StandaloneScript.ps1

    Bündelt alle Wrapper aus scripts/tools/ nach build/standalone/.

.EXAMPLE
    .\scripts\Export-StandaloneScript.ps1 -Name 'Export-CdpInformation' -OutputPath C:\Release

    Bündelt nur den Wrapper Export-CdpInformation.ps1 nach C:\Release.

.NOTES
    Wird als Build-Task `Standalone` über scripts/Invoke-Build.ps1 aufgerufen.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ToolsPath = (Join-Path $PSScriptRoot 'tools'),

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $OutputPath = (Join-Path $PSScriptRoot '..\build\standalone'),

    [Parameter(Mandatory = $false)]
    [string[]]
    $Name
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$moduleDir = Join-Path $repoRoot 'src\ps-script-machine'
$manifest = Import-PowerShellDataFile -Path (Join-Path $moduleDir 'ps-script-machine.psd1')
$moduleVersion = $manifest.ModuleVersion

if (-not (Test-Path -LiteralPath $ToolsPath)) {
    Write-Host "Kein Wrapper-Ordner gefunden ($ToolsPath) - nichts zu bündeln."
    return
}

$wrappers = @(Get-ChildItem -Path (Join-Path $ToolsPath '*.ps1') -ErrorAction SilentlyContinue)
if ($Name) {
    $wrappers = @($wrappers | Where-Object { $_.BaseName -in $Name })
}
if ($wrappers.Count -eq 0) {
    Write-Host "Keine Wrapper in $ToolsPath gefunden - nichts zu bündeln."
    return
}

# Modul-Funktionen einsammeln: Private zuerst, damit Public-Funktionen ihre
# Helfer beim Aufruf bereits definiert vorfinden.
function Get-EmbeddableContent {
    param([Parameter(Mandatory = $true)][string]$Path)
    $lines = Get-Content -LiteralPath $Path
    # #Requires-Zeilen entfernen - das Standalone-Skript hat genau eine am Anfang.
    return (($lines | Where-Object { $_ -notmatch '^\s*#Requires' }) -join "`n").Trim()
}

$functionFiles = @(
    Get-ChildItem -Path (Join-Path $moduleDir 'Private\*.ps1') -ErrorAction SilentlyContinue
    Get-ChildItem -Path (Join-Path $moduleDir 'Public\*.ps1') -ErrorAction SilentlyContinue
)

$embeddedBuilder = [System.Text.StringBuilder]::new()
foreach ($file in $functionFiles) {
    $null = $embeddedBuilder.AppendLine("# --- Eingebettet aus: $($file.Directory.Name)/$($file.Name) ---")
    $null = $embeddedBuilder.AppendLine((Get-EmbeddableContent -Path $file.FullName))
    $null = $embeddedBuilder.AppendLine('')
}
$embeddedFunctions = $embeddedBuilder.ToString()

if (-not (Test-Path -LiteralPath $OutputPath)) {
    $null = New-Item -Path $OutputPath -ItemType Directory -Force
}
$OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path

$analyzerAvailable = $null -ne (Get-Module -ListAvailable -Name 'PSScriptAnalyzer' -ErrorAction SilentlyContinue)
$createdFiles = [System.Collections.Generic.List[string]]::new()

foreach ($wrapper in $wrappers) {
    Write-Host "Bündle: $($wrapper.Name)"

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($wrapper.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $messages = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
        throw "Wrapper '$($wrapper.Name)' hat Syntaxfehler: $messages"
    }
    if (-not $ast.ParamBlock) {
        throw "Wrapper '$($wrapper.Name)' hat keinen param-Block. Jeder Wrapper muss dem Template templates/InteractiveWrapper.ps1 folgen (der param-Block ist der Einbettungspunkt)."
    }

    $content = Get-Content -LiteralPath $wrapper.FullName -Raw
    $headEnd = $ast.ParamBlock.Extent.EndOffset
    $head = $content.Substring(0, $headEnd)
    $body = $content.Substring($headEnd)

    # #Requires aus dem Kopf entfernen (wird unten einmalig gesetzt).
    $head = (($head -split "`n") | Where-Object { $_ -notmatch '^\s*#Requires' }) -join "`n"

    # module-import-Region ersatzlos entfernen.
    $body = [regex]::Replace(
        $body,
        '(?s)#region module-import.*?#endregion module-import',
        '# Hinweis: Die Modul-Funktionen von ps-script-machine sind oben in dieses Skript eingebettet.'
    )

    $generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $standalone = @"
#Requires -Version 7.4
# ============================================================================
# AUTOMATISCH GENERIERT aus ps-script-machine v$moduleVersion am $generatedAt
# Quelle: scripts/tools/$($wrapper.Name)
# NICHT MANUELL BEARBEITEN - Änderungen gehören ins Repository und werden
# mit scripts/Export-StandaloneScript.ps1 neu gebündelt.
# ============================================================================
$head

# ============================================================================
#region eingebettete ps-script-machine-Funktionen (v$moduleVersion)
# ============================================================================
`$script:ModuleVersion = '$moduleVersion'
`$script:LogRunId = [guid]::NewGuid().ToString()
`$script:ModuleSessions = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

$embeddedFunctions
#endregion eingebettete ps-script-machine-Funktionen
$body
"@

    $targetPath = Join-Path $OutputPath $wrapper.Name
    Set-Content -LiteralPath $targetPath -Value $standalone -Encoding utf8

    # Verifikation 1: Syntax.
    $verifyErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($targetPath, [ref]$null, [ref]$verifyErrors) | Out-Null
    if ($verifyErrors -and $verifyErrors.Count -gt 0) {
        $messages = ($verifyErrors | ForEach-Object { $_.Message }) -join '; '
        throw "Gebündeltes Skript '$targetPath' hat Syntaxfehler: $messages"
    }

    # Verifikation 2: Analyzer-Errors (Warnungen sind für Konsolen-Tools ok,
    # siehe Scope-Kommentar in PSScriptAnalyzerSettings.psd1).
    if ($analyzerAvailable) {
        $findings = Invoke-ScriptAnalyzer -Path $targetPath -Severity Error
        if ($findings) {
            $findings | Format-Table -AutoSize | Out-String | Write-Host
            throw "Gebündeltes Skript '$targetPath' hat $(@($findings).Count) PSScriptAnalyzer-Error(s)."
        }
    }
    else {
        Write-Warning 'PSScriptAnalyzer ist nicht installiert - Analyzer-Verifikation übersprungen.'
    }

    $createdFiles.Add($targetPath)
    Write-Host "  OK: $targetPath" -ForegroundColor Green
}

return $createdFiles.ToArray()
