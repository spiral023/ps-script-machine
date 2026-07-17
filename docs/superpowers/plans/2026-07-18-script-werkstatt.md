# Skript-Werkstatt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** VMware-Admins ohne Programmierkenntnisse können per deutscher Beschreibung in Claude Code neue PowerCLI-Skripte erhalten, die per interaktivem Menü durch Multi-vCenter-Auswahl, Anmeldung und Export führen — zusätzlich als verteilbare Single-File-Skripte.

**Architecture:** Drei Bausteine gemäß Spec `docs/superpowers/specs/2026-07-18-script-werkstatt-design.md`: (1) ein Skill, der den Interview-/Generierungsworkflow für Claude Code definiert; (2) ein wiederverwendbares Menü-Framework als Modul-Funktionen (`Select-VIServerTarget`, `Connect-MultiVIServer`, private Helfer) plus Wrapper-Template; (3) ein Bundle-Build (`Export-StandaloneScript.ps1`), der Wrapper + Modul-Funktionen zu Single-File-Skripten in `build/standalone/` zusammensetzt.

**Tech Stack:** PowerShell 7.4+, VMware PowerCLI 13.2+ (extern, gemockt in Tests), Pester 5, PSScriptAnalyzer.

## Global Constraints

- `#Requires -Version 7.4` in jeder neuen `.ps1`-Datei.
- Pester 5 (nicht 6), Code-Coverage ≥ 80 % (Build-Gate).
- Kein `Invoke-Expression`, keine fest codierten Zugangsdaten, Credentials nur als `PSCredential`.
- Explizite `-Server`-Übergabe an alle PowerCLI-Cmdlets.
- Eine Funktion pro Datei; Dateiname = Funktionsname.
- Public-Funktionen: `[CmdletBinding()]`, vollständige Comment-Based Help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.INPUTS`, `.OUTPUTS`, `.NOTES`, `.LINK`), Eintrag in `FunctionsToExport` im Manifest, Doku-Datei `docs/<FunctionName>.md`, Testdatei `tests/Unit/<FunctionName>.Tests.ps1` (beides erzwingt `scripts/Test-AgentCompliance.ps1`).
- **PSScriptAnalyzer läuft streng (Warnungen in CI fatal) NUR gegen `src/`** — `PSAvoidUsingWriteHost` ist dort aktiv. Interaktive Modul-Funktionen brauchen deshalb pro Funktion ein dokumentiertes `[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = '...')]`. `scripts/`, `templates/`, `tests/` sind bewusst NICHT im strengen Scope (siehe Kommentar in `PSScriptAnalyzerSettings.psd1`) — dort ist `Write-Host` erlaubt.
- Keine `Format-Table`/`Format-List` in Modul-Fachlogik (Compliance-Check) — in `scripts/`-Wrappern erlaubt.
- Alle Benutzertexte (Menüs, Fehlermeldungen) auf Deutsch; Fehlermeldungen dreiteilig: Was ist passiert / warum vermutlich / was tun.
- Test-Muster des Repos: `tests/Unit/TestHelpers.ps1` VOR `Import-Module` dot-sourcen; Mocks mit `-ModuleName 'ps-script-machine'`; Aufrufe privater Funktionen via `InModuleScope`.
- Commits auf Deutsch im Stil der Historie (`feat: …`, `build: …`, `docs: …`), jeweils mit `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Verifikation pro Task: `pwsh -NoProfile -Command "& .\scripts\Invoke-Build.ps1 -Task <T>"`; am Ende jedes Tasks muss mindestens der Pester-Lauf der neuen Testdatei grün sein.

---

### Task 1: Private Funktion `Read-MenuChoice`

Konsistente nummerierte/validierte Konsolen-Abfrage mit Standardwert — der Grundbaustein aller Menüs.

**Files:**
- Create: `src/ps-script-machine/Private/Read-MenuChoice.ps1`
- Create: `tests/Unit/Read-MenuChoice.Tests.ps1`

**Interfaces:**
- Consumes: nichts (nur `Read-Host`, `Write-Host`).
- Produces: `Read-MenuChoice -Prompt <string> [-Default <string>] [-ValidAnswer <string[]>]` → `[string]`. Enter bei gesetztem `-Default` liefert den Default. Bei `-ValidAnswer` wird case-insensitiv validiert und der **kanonische Wert aus `-ValidAnswer`** zurückgegeben (Eingabe `n` bei `-ValidAnswer 'J','N'` liefert `'N'`). Ungültige/leere Eingaben führen zu erneuter Abfrage (Schleife).

- [ ] **Step 1: Fehlschlagenden Test schreiben**

Datei `tests/Unit/Read-MenuChoice.Tests.ps1`:

```powershell
#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for the private Read-MenuChoice function.
#>

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
}

Describe 'Read-MenuChoice' {
    BeforeAll {
        # Menu output is irrelevant for assertions - silence it.
        Mock Write-Host { } -ModuleName 'ps-script-machine'
    }

    AfterEach {
        Remove-Variable -Name 'PsmTestAnswers' -Scope Global -ErrorAction SilentlyContinue
    }

    Context 'Default handling' {
        It 'returns the default when input is empty' {
            Mock Read-Host { '' } -ModuleName 'ps-script-machine'
            $result = InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'Frage' -Default 'J'
            }
            $result | Should -Be 'J'
        }

        It 'shows the default inside the prompt' {
            Mock Read-Host { '' } -ModuleName 'ps-script-machine'
            InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'Frage' -Default 'CSV'
            }
            Should -Invoke Read-Host -ModuleName 'ps-script-machine' -Times 1 -ParameterFilter {
                $Prompt -like '*Frage*[[]CSV[]]*'
            }
        }

        It 're-prompts on empty input when no default is set' {
            $global:PsmTestAnswers = [System.Collections.Queue]::new()
            $global:PsmTestAnswers.Enqueue('')
            $global:PsmTestAnswers.Enqueue('wert')
            Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

            $result = InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'Frage'
            }
            $result | Should -Be 'wert'
            Should -Invoke Read-Host -ModuleName 'ps-script-machine' -Times 2
        }
    }

    Context 'Validation against -ValidAnswer' {
        It 'returns the canonical value regardless of input casing' {
            Mock Read-Host { 'n' } -ModuleName 'ps-script-machine'
            $result = InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'Frage' -ValidAnswer 'J', 'N'
            }
            $result | Should -BeExactly 'N'
        }

        It 're-prompts until the answer is valid' {
            $global:PsmTestAnswers = [System.Collections.Queue]::new()
            $global:PsmTestAnswers.Enqueue('x')
            $global:PsmTestAnswers.Enqueue('quatsch')
            $global:PsmTestAnswers.Enqueue('j')
            Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

            $result = InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'Frage' -ValidAnswer 'J', 'N'
            }
            $result | Should -BeExactly 'J'
            Should -Invoke Read-Host -ModuleName 'ps-script-machine' -Times 3
        }

        It 'trims surrounding whitespace before validating' {
            Mock Read-Host { '  J  ' } -ModuleName 'ps-script-machine'
            $result = InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'Frage' -ValidAnswer 'J', 'N'
            }
            $result | Should -BeExactly 'J'
        }
    }

    Context 'Free-text input' {
        It 'returns trimmed free text when no ValidAnswer is given' {
            Mock Read-Host { '  vc01.example.local  ' } -ModuleName 'ps-script-machine'
            $result = InModuleScope 'ps-script-machine' {
                Read-MenuChoice -Prompt 'vCenter'
            }
            $result | Should -Be 'vc01.example.local'
        }
    }
}
```

- [ ] **Step 2: Test ausführen — er muss fehlschlagen**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Unit/Read-MenuChoice.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Read-MenuChoice` ist im Modul nicht definiert (CommandNotFound in InModuleScope).

- [ ] **Step 3: Implementierung schreiben**

Datei `src/ps-script-machine/Private/Read-MenuChoice.ps1`:

```powershell
#Requires -Version 7.4

<#
.SYNOPSIS
    Stellt eine konsistente interaktive Konsolen-Abfrage mit Standardwert.

.DESCRIPTION
    Read-MenuChoice ist der Grundbaustein aller interaktiven Menüs der
    generierten Wrapper-Skripte. Die Funktion zeigt einen Prompt (optional
    mit Standardwert in eckigen Klammern), liest die Eingabe, und wiederholt
    die Abfrage bei leerer (ohne Default) oder ungültiger Eingabe.

    Bei -ValidAnswer wird case-insensitiv validiert und immer der kanonische
    Wert aus der ValidAnswer-Liste zurückgegeben (Eingabe 'n' bei
    -ValidAnswer 'J','N' liefert 'N').

.PARAMETER Prompt
    Der anzuzeigende Text (ohne Doppelpunkt, den ergänzt Read-Host).

.PARAMETER Default
    Optionaler Standardwert. Enter ohne Eingabe liefert diesen Wert.

.PARAMETER ValidAnswer
    Optionale Liste erlaubter Antworten (case-insensitiv geprüft).

.EXAMPLE
    $format = Read-MenuChoice -Prompt 'Ausgabeformat' -Default 'CSV' -ValidAnswer 'CSV', 'JSON', 'beide'

.OUTPUTS
    System.String

.NOTES
    Private Funktion; wird nicht exportiert, ist aber via InModuleScope testbar.
#>
function Read-MenuChoice {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interaktive Menü-Funktion: Konsolenausgabe an den Bediener ist der Zweck dieser Funktion, keine Fachlogik-Ausgabe.')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Prompt,

        [Parameter(Mandatory = $false)]
        [string]
        $Default,

        [Parameter(Mandatory = $false)]
        [string[]]
        $ValidAnswer
    )

    while ($true) {
        $displayPrompt = if ($Default) { "$Prompt [$Default]" } else { $Prompt }
        $answer = Read-Host -Prompt $displayPrompt

        if ([string]::IsNullOrWhiteSpace($answer)) {
            if ($Default) {
                return $Default
            }
            Write-Host 'Bitte einen Wert eingeben.' -ForegroundColor Yellow
            continue
        }

        $answer = $answer.Trim()

        if ($ValidAnswer -and $ValidAnswer.Count -gt 0) {
            $matched = $ValidAnswer | Where-Object { $_ -ieq $answer } | Select-Object -First 1
            if ($null -eq $matched) {
                Write-Host ('Ungültige Eingabe. Erlaubt: {0}' -f ($ValidAnswer -join ', ')) -ForegroundColor Yellow
                continue
            }
            return $matched
        }

        return $answer
    }
}
```

- [ ] **Step 4: Test ausführen — er muss bestehen**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Unit/Read-MenuChoice.Tests.ps1 -Output Detailed"`
Expected: PASS (7 Tests).

- [ ] **Step 5: Analyzer gegen src/ laufen lassen**

Run: `pwsh -NoProfile -Command "& .\scripts\Invoke-Build.ps1 -Task Analyze"`
Expected: PASSED, keine Warnungen (Suppression wirkt).

- [ ] **Step 6: Commit**

```bash
git add src/ps-script-machine/Private/Read-MenuChoice.ps1 tests/Unit/Read-MenuChoice.Tests.ps1
git commit -m "feat: private Menü-Abfragefunktion Read-MenuChoice

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Private Inventar-Funktionen + Beispiel-Konfig

vCenter-Liste (`vcenters.json`) lesen und schreiben; robuste Behandlung fehlender/defekter Dateien.

**Files:**
- Create: `src/ps-script-machine/Private/Get-VIServerInventory.ps1`
- Create: `src/ps-script-machine/Private/Save-VIServerInventory.ps1`
- Create: `config/vcenters.example.json`
- Modify: `.gitignore` (Eintrag `config/vcenters.json` im Block "Configuration files with real values")
- Create: `tests/Unit/VIServerInventory.Tests.ps1`

**Interfaces:**
- Consumes: nichts aus früheren Tasks.
- Produces:
  - `Get-VIServerInventory -Path <string>` → `[object[]]` von `PSCustomObject` mit `PSTypeName 'ps-script-machine.VIServerInventoryEntry'` und Properties `Name` (string), `Fqdn` (string), `Description` (string). Fehlende Datei → `@()` (nur Verbose). Defektes JSON → `Write-Warning` + `@()`. Einträge ohne `fqdn` → `Write-Warning`, werden übersprungen.
  - `Save-VIServerInventory -Path <string> -Inventory <object[]>` → void. Legt den Zielordner an, schreibt JSON-Array (`ConvertTo-Json -AsArray`) mit den Keys `name`, `fqdn`, `description` in UTF-8.
- JSON-Dateiformat (von beiden Funktionen geteilt, identisch zur Example-Datei):

```json
[
  { "name": "Produktion RZ1", "fqdn": "vc01.example.local", "description": "Produktions-vCenter Rechenzentrum 1" }
]
```

- [ ] **Step 1: Fehlschlagende Tests schreiben**

Datei `tests/Unit/VIServerInventory.Tests.ps1`:

```powershell
#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for the private Get-VIServerInventory and Save-VIServerInventory functions.
#>

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
}

Describe 'Get-VIServerInventory' {
    It 'returns an empty array when the file does not exist' {
        $result = InModuleScope 'ps-script-machine' -Parameters @{ Path = (Join-Path $TestDrive 'gibtsnicht.json') } {
            Get-VIServerInventory -Path $Path
        }
        @($result).Count | Should -Be 0
    }

    It 'reads entries with name, fqdn and description' {
        $file = Join-Path $TestDrive 'vcenters.json'
        Set-Content -LiteralPath $file -Value '[{"name":"Prod","fqdn":"vc01.test.local","description":"RZ1"}]' -Encoding utf8

        $result = InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            Get-VIServerInventory -Path $Path
        }
        @($result).Count | Should -Be 1
        $result[0].Name | Should -Be 'Prod'
        $result[0].Fqdn | Should -Be 'vc01.test.local'
        $result[0].Description | Should -Be 'RZ1'
        $result[0].PSObject.TypeNames | Should -Contain 'ps-script-machine.VIServerInventoryEntry'
    }

    It 'falls back to the fqdn when name is missing' {
        $file = Join-Path $TestDrive 'vcenters-noname.json'
        Set-Content -LiteralPath $file -Value '[{"fqdn":"vc02.test.local"}]' -Encoding utf8

        $result = InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            Get-VIServerInventory -Path $Path
        }
        $result[0].Name | Should -Be 'vc02.test.local'
    }

    It 'warns and returns an empty array for broken JSON' {
        $file = Join-Path $TestDrive 'kaputt.json'
        Set-Content -LiteralPath $file -Value '{ das ist kein json' -Encoding utf8

        $result = InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            Get-VIServerInventory -Path $Path -WarningAction SilentlyContinue
        }
        @($result).Count | Should -Be 0
    }

    It 'skips entries without fqdn' {
        $file = Join-Path $TestDrive 'vcenters-mixed.json'
        Set-Content -LiteralPath $file -Value '[{"name":"ohne"},{"fqdn":"vc03.test.local"}]' -Encoding utf8

        $result = InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            Get-VIServerInventory -Path $Path -WarningAction SilentlyContinue
        }
        @($result).Count | Should -Be 1
        $result[0].Fqdn | Should -Be 'vc03.test.local'
    }
}

Describe 'Save-VIServerInventory' {
    It 'creates the target directory and writes a JSON array' {
        $file = Join-Path $TestDrive 'neu\ordner\vcenters.json'
        InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            $entry = [PSCustomObject]@{
                PSTypeName  = 'ps-script-machine.VIServerInventoryEntry'
                Name        = 'Prod'
                Fqdn        = 'vc01.test.local'
                Description = 'RZ1'
            }
            Save-VIServerInventory -Path $Path -Inventory @($entry)
        }

        Test-Path -LiteralPath $file | Should -BeTrue
        $parsed = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        @($parsed).Count | Should -Be 1
        $parsed[0].fqdn | Should -Be 'vc01.test.local'
        $parsed[0].name | Should -Be 'Prod'
        $parsed[0].description | Should -Be 'RZ1'
    }

    It 'round-trips through Get-VIServerInventory' {
        $file = Join-Path $TestDrive 'roundtrip.json'
        $result = InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            $entries = @(
                [PSCustomObject]@{ PSTypeName = 'ps-script-machine.VIServerInventoryEntry'; Name = 'A'; Fqdn = 'a.test.local'; Description = '' }
                [PSCustomObject]@{ PSTypeName = 'ps-script-machine.VIServerInventoryEntry'; Name = 'B'; Fqdn = 'b.test.local'; Description = 'zwei' }
            )
            Save-VIServerInventory -Path $Path -Inventory $entries
            Get-VIServerInventory -Path $Path
        }
        @($result).Count | Should -Be 2
        $result[1].Fqdn | Should -Be 'b.test.local'
    }

    It 'writes an empty JSON array for an empty inventory' {
        $file = Join-Path $TestDrive 'leer.json'
        InModuleScope 'ps-script-machine' -Parameters @{ Path = $file } {
            Save-VIServerInventory -Path $Path -Inventory @()
        }
        $parsed = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        @($parsed).Count | Should -Be 0
    }
}
```

- [ ] **Step 2: Tests ausführen — sie müssen fehlschlagen**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Unit/VIServerInventory.Tests.ps1 -Output Detailed"`
Expected: FAIL — beide Funktionen nicht definiert.

- [ ] **Step 3: `Get-VIServerInventory` implementieren**

Datei `src/ps-script-machine/Private/Get-VIServerInventory.ps1`:

```powershell
#Requires -Version 7.4

<#
.SYNOPSIS
    Liest die gespeicherte vCenter-Liste (vcenters.json).

.DESCRIPTION
    Get-VIServerInventory liest die JSON-Datei mit den gespeicherten
    vCenter-Servern und liefert sie als strukturierte Objekte zurück.

    Robustheit für den interaktiven Einsatz:
    - Fehlende Datei ist kein Fehler (leere Liste, nur Verbose-Meldung),
      denn beim allerersten Start existiert noch keine Konfiguration.
    - Defektes JSON führt zu einer Warnung und einer leeren Liste,
      damit das Menü trotzdem benutzbar bleibt (freie FQDN-Eingabe).
    - Einträge ohne 'fqdn' werden mit Warnung übersprungen.

.PARAMETER Path
    Vollständiger Pfad zur vcenters.json.

.EXAMPLE
    $inventory = Get-VIServerInventory -Path 'C:\repo\config\vcenters.json'

.OUTPUTS
    PSCustomObject[] mit PSTypeName 'ps-script-machine.VIServerInventoryEntry'
    und den Properties Name, Fqdn, Description.

.NOTES
    Private Funktion; Dateiformat siehe config/vcenters.example.json.
#>
function Get-VIServerInventory {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Verbose "vCenter-Liste nicht gefunden (erster Start?): $Path"
        return @()
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Warning ("Die vCenter-Liste '{0}' konnte nicht gelesen werden (vermutlich defektes JSON). " +
            'Sie wird ignoriert - vCenter können weiterhin frei eingegeben werden. ' +
            'Zum Beheben: Datei löschen oder reparieren. Details: {1}' -f $Path, $_.Exception.Message)
        return @()
    }

    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @($parsed)) {
        if ([string]::IsNullOrWhiteSpace($item.fqdn)) {
            Write-Warning "Eintrag ohne 'fqdn' in '$Path' wird übersprungen."
            continue
        }
        $name = if ([string]::IsNullOrWhiteSpace($item.name)) { [string]$item.fqdn } else { [string]$item.name }
        $entries.Add([PSCustomObject]@{
                PSTypeName  = 'ps-script-machine.VIServerInventoryEntry'
                Name        = $name
                Fqdn        = [string]$item.fqdn
                Description = [string]$item.description
            })
    }

    return $entries.ToArray()
}
```

- [ ] **Step 4: `Save-VIServerInventory` implementieren**

Datei `src/ps-script-machine/Private/Save-VIServerInventory.ps1`:

```powershell
#Requires -Version 7.4

<#
.SYNOPSIS
    Schreibt die vCenter-Liste (vcenters.json).

.DESCRIPTION
    Save-VIServerInventory persistiert die übergebenen Inventar-Einträge als
    JSON-Array. Der Zielordner wird bei Bedarf angelegt. Es werden nur die
    Felder name, fqdn und description geschrieben - niemals Zugangsdaten.

.PARAMETER Path
    Vollständiger Pfad zur vcenters.json.

.PARAMETER Inventory
    Die Einträge (Objekte mit Name, Fqdn, Description), typischerweise von
    Get-VIServerInventory geliefert und ergänzt.

.EXAMPLE
    Save-VIServerInventory -Path $path -Inventory $entries

.OUTPUTS
    None.

.NOTES
    Private Funktion; Dateiformat siehe config/vcenters.example.json.
#>
function Save-VIServerInventory {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]
        $Inventory
    )

    $directory = Split-Path -Path $Path -Parent
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        $null = New-Item -Path $directory -ItemType Directory -Force
    }

    $plain = @($Inventory | ForEach-Object {
            [ordered]@{
                name        = [string]$_.Name
                fqdn        = [string]$_.Fqdn
                description = [string]$_.Description
            }
        })

    $json = $plain | ConvertTo-Json -Depth 3 -AsArray
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8
}
```

- [ ] **Step 5: Beispiel-Konfig und .gitignore**

Datei `config/vcenters.example.json`:

```json
[
  { "name": "Produktion RZ1", "fqdn": "vc01.example.local", "description": "Produktions-vCenter Rechenzentrum 1" },
  { "name": "Produktion RZ2", "fqdn": "vc02.example.local", "description": "Produktions-vCenter Rechenzentrum 2" },
  { "name": "Test", "fqdn": "vc-test.example.local", "description": "Testumgebung" }
]
```

In `.gitignore` im Block `# Configuration files with real values (only examples are committed)` ergänzen:

```
config/vcenters.json
```

- [ ] **Step 6: Tests ausführen — sie müssen bestehen**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Unit/VIServerInventory.Tests.ps1 -Output Detailed"`
Expected: PASS (8 Tests).

- [ ] **Step 7: Analyzer laufen lassen**

Run: `pwsh -NoProfile -Command "& .\scripts\Invoke-Build.ps1 -Task Analyze"`
Expected: PASSED.

- [ ] **Step 8: Commit**

```bash
git add src/ps-script-machine/Private/Get-VIServerInventory.ps1 src/ps-script-machine/Private/Save-VIServerInventory.ps1 config/vcenters.example.json .gitignore tests/Unit/VIServerInventory.Tests.ps1
git commit -m "feat: vCenter-Inventar lesen/schreiben (vcenters.json) mit Beispielkonfig

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Public Funktion `Select-VIServerTarget`

Interaktive Multi-vCenter-Auswahl: nummerierte Liste aus dem Inventar, `alle`, oder freie FQDN-Eingabe mit optionalem Speichern.

**Files:**
- Create: `src/ps-script-machine/Public/Select-VIServerTarget.ps1`
- Create: `tests/Unit/Select-VIServerTarget.Tests.ps1`
- Create: `docs/Select-VIServerTarget.md`
- Modify: `src/ps-script-machine/ps-script-machine.psd1` (FunctionsToExport)

**Interfaces:**
- Consumes: `Get-VIServerInventory -Path` / `Save-VIServerInventory -Path -Inventory` (Task 2), `Read-MenuChoice -Prompt [-Default] [-ValidAnswer]` (Task 1).
- Produces: `Select-VIServerTarget -InventoryPath <string>` → `[string[]]` (deduplizierte FQDN-Liste, nie leer — die Funktion fragt so lange, bis eine gültige Auswahl vorliegt).
- Eingabe-Grammatik (im Menü angezeigt): Nummern kommagetrennt (`1,3`), `alle`, oder FQDN(s) kommagetrennt. Neue (nicht im Inventar vorhandene) FQDNs lösen die Frage `Neue vCenter für später speichern? [J]` aus (J/N, Default J).

- [ ] **Step 1: Fehlschlagende Tests schreiben**

Datei `tests/Unit/Select-VIServerTarget.Tests.ps1`:

```powershell
#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for the public Select-VIServerTarget function.
#>

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $script:inventoryJson = '[' +
    '{"name":"Prod RZ1","fqdn":"vc01.test.local","description":"RZ1"},' +
    '{"name":"Prod RZ2","fqdn":"vc02.test.local","description":"RZ2"},' +
    '{"name":"Test","fqdn":"vc-test.test.local","description":""}' +
    ']'
}

Describe 'Select-VIServerTarget' {
    BeforeAll {
        Mock Write-Host { } -ModuleName 'ps-script-machine'
    }

    BeforeEach {
        $script:inventoryPath = Join-Path $TestDrive "vcenters-$([guid]::NewGuid()).json"
        Set-Content -LiteralPath $script:inventoryPath -Value $script:inventoryJson -Encoding utf8
    }

    AfterEach {
        Remove-Variable -Name 'PsmTestAnswers' -Scope Global -ErrorAction SilentlyContinue
    }

    It 'returns the FQDNs for a comma-separated number selection' {
        Mock Read-Host { '1,3' } -ModuleName 'ps-script-machine'
        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        $result | Should -Be @('vc01.test.local', 'vc-test.test.local')
    }

    It 'returns all inventory FQDNs for input "alle"' {
        Mock Read-Host { 'alle' } -ModuleName 'ps-script-machine'
        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        $result | Should -Be @('vc01.test.local', 'vc02.test.local', 'vc-test.test.local')
    }

    It 're-prompts when a number is out of range' {
        $global:PsmTestAnswers = [System.Collections.Queue]::new()
        $global:PsmTestAnswers.Enqueue('7')
        $global:PsmTestAnswers.Enqueue('2')
        Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        $result | Should -Be @('vc02.test.local')
    }

    It 'accepts a new FQDN and saves it when confirmed' {
        $global:PsmTestAnswers = [System.Collections.Queue]::new()
        $global:PsmTestAnswers.Enqueue('vc-neu.test.local')
        $global:PsmTestAnswers.Enqueue('J')
        Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        $result | Should -Be @('vc-neu.test.local')

        $saved = Get-Content -LiteralPath $script:inventoryPath -Raw | ConvertFrom-Json
        @($saved).Count | Should -Be 4
        $saved.fqdn | Should -Contain 'vc-neu.test.local'
    }

    It 'accepts a new FQDN without saving when declined' {
        $global:PsmTestAnswers = [System.Collections.Queue]::new()
        $global:PsmTestAnswers.Enqueue('vc-fluechtig.test.local')
        $global:PsmTestAnswers.Enqueue('n')
        Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        $result | Should -Be @('vc-fluechtig.test.local')

        $saved = Get-Content -LiteralPath $script:inventoryPath -Raw | ConvertFrom-Json
        @($saved).Count | Should -Be 3
    }

    It 'does not ask to save when the typed FQDN is already in the inventory' {
        Mock Read-Host { 'vc01.test.local' } -ModuleName 'ps-script-machine'
        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        $result | Should -Be @('vc01.test.local')
        Should -Invoke Read-Host -ModuleName 'ps-script-machine' -Times 1 -Exactly
    }

    It 'works with an empty inventory (missing file) via free input' {
        $emptyPath = Join-Path $TestDrive 'gibtsnicht.json'
        $global:PsmTestAnswers = [System.Collections.Queue]::new()
        $global:PsmTestAnswers.Enqueue('vc-solo.test.local')
        $global:PsmTestAnswers.Enqueue('J')
        Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

        $result = Select-VIServerTarget -InventoryPath $emptyPath
        $result | Should -Be @('vc-solo.test.local')
        Test-Path -LiteralPath $emptyPath | Should -BeTrue
    }

    It 'deduplicates the selection' {
        Mock Read-Host { '1,1,1' } -ModuleName 'ps-script-machine'
        $result = Select-VIServerTarget -InventoryPath $script:inventoryPath
        @($result).Count | Should -Be 1
    }

    It 're-prompts for "alle" when the inventory is empty' {
        $emptyPath = Join-Path $TestDrive 'leer2.json'
        $global:PsmTestAnswers = [System.Collections.Queue]::new()
        $global:PsmTestAnswers.Enqueue('alle')
        $global:PsmTestAnswers.Enqueue('vc-x.test.local')
        $global:PsmTestAnswers.Enqueue('n')
        Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'

        $result = Select-VIServerTarget -InventoryPath $emptyPath
        $result | Should -Be @('vc-x.test.local')
    }
}
```

- [ ] **Step 2: Tests ausführen — sie müssen fehlschlagen**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Unit/Select-VIServerTarget.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Select-VIServerTarget` nicht gefunden.

- [ ] **Step 3: Implementierung schreiben**

Datei `src/ps-script-machine/Public/Select-VIServerTarget.ps1`:

```powershell
#Requires -Version 7.4

<#
.SYNOPSIS
    Interaktive Auswahl eines oder mehrerer vCenter-Server.

.DESCRIPTION
    Select-VIServerTarget zeigt die in vcenters.json gespeicherten
    vCenter-Server als nummerierte Liste an und liest die Auswahl des
    Bedieners. Erlaubte Eingaben:

    - Nummern, kommagetrennt (z. B. "1,3")
    - "alle" für alle gespeicherten vCenter
    - ein oder mehrere FQDNs, kommagetrennt (neue vCenter)

    Neue, noch nicht gespeicherte FQDNs können auf Nachfrage in die
    vcenters.json übernommen werden, damit sie beim nächsten Start als
    Auswahlpunkt erscheinen. Die Funktion fragt so lange, bis eine gültige
    Auswahl vorliegt, und liefert nie eine leere Liste.

    Diese Funktion ist für interaktive Wrapper-Skripte gedacht. In
    Automatisierungen (Scheduled Tasks) wird sie nicht aufgerufen -
    dort übergibt man die vCenter direkt als Parameter an das Skript.

.PARAMETER InventoryPath
    Vollständiger Pfad zur vcenters.json. Interaktive Wrapper verwenden
    im Repo config/vcenters.json und außerhalb (Standalone-Skript)
    $HOME/.ps-script-machine/vcenters.json.

.EXAMPLE
    $targets = Select-VIServerTarget -InventoryPath 'C:\repo\config\vcenters.json'

    Zeigt das Auswahlmenü und liefert z. B. @('vc01.example.local', 'vc02.example.local').

.INPUTS
    None. Diese Funktion liest ausschließlich von der Konsole.

.OUTPUTS
    System.String[] - deduplizierte Liste der gewählten FQDNs.

.NOTES
    Interaktive Funktion: nicht für unbeaufsichtigte Ausführung geeignet.
    Es werden ausschließlich Servernamen gespeichert, niemals Zugangsdaten.

.LINK
    https://github.com/spiral023/ps-script-machine
#>
function Select-VIServerTarget {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interaktive Menü-Funktion: Konsolenausgabe an den Bediener ist der Zweck dieser Funktion, keine Fachlogik-Ausgabe.')]
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InventoryPath
    )

    $inventory = @(Get-VIServerInventory -Path $InventoryPath)

    while ($true) {
        Write-Host ''
        Write-Host 'vCenter-Auswahl' -ForegroundColor Cyan
        if ($inventory.Count -gt 0) {
            for ($i = 0; $i -lt $inventory.Count; $i++) {
                $entry = $inventory[$i]
                $description = if ($entry.Description) { " - $($entry.Description)" } else { '' }
                Write-Host ('  [{0}] {1} ({2}){3}' -f ($i + 1), $entry.Name, $entry.Fqdn, $description)
            }
            Write-Host '  Eingabe: Nummern kommagetrennt (z. B. 1,3), "alle", oder FQDN eines neuen vCenters.'
        }
        else {
            Write-Host '  Noch keine vCenter gespeichert. Bitte FQDN eingeben (mehrere kommagetrennt).'
        }

        $userInput = Read-MenuChoice -Prompt 'vCenter'
        $tokens = @($userInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

        if ($tokens.Count -eq 1 -and $tokens[0] -ieq 'alle') {
            if ($inventory.Count -eq 0) {
                Write-Host 'Es sind keine vCenter gespeichert - bitte einen FQDN eingeben.' -ForegroundColor Yellow
                continue
            }
            return [string[]]@($inventory.Fqdn | Select-Object -Unique)
        }

        $isNumberSelection = @($tokens | Where-Object { $_ -match '^\d+$' }).Count -eq $tokens.Count
        if ($isNumberSelection) {
            $selected = [System.Collections.Generic.List[string]]::new()
            $selectionValid = $true
            foreach ($token in $tokens) {
                $index = [int]$token
                if ($index -lt 1 -or $index -gt $inventory.Count) {
                    Write-Host ('Die Nummer {0} gibt es nicht - bitte 1 bis {1} verwenden.' -f $index, $inventory.Count) -ForegroundColor Yellow
                    $selectionValid = $false
                    break
                }
                $selected.Add($inventory[$index - 1].Fqdn)
            }
            if (-not $selectionValid) { continue }
            return [string[]]@($selected | Select-Object -Unique)
        }

        # Freie FQDN-Eingabe: nur Hostname-taugliche Zeichen zulassen.
        $fqdnPattern = '^[a-zA-Z0-9][a-zA-Z0-9\.\-]*$'
        $allTokensAreFqdns = @($tokens | Where-Object { $_ -match $fqdnPattern }).Count -eq $tokens.Count
        if (-not $allTokensAreFqdns) {
            Write-Host 'Eingabe nicht erkannt: bitte Nummern, "alle" oder gültige Servernamen (FQDN) eingeben.' -ForegroundColor Yellow
            continue
        }

        $knownFqdns = @($inventory.Fqdn)
        $newFqdns = @($tokens | Where-Object { $_ -notin $knownFqdns })
        if ($newFqdns.Count -gt 0) {
            $saveAnswer = Read-MenuChoice `
                -Prompt ('Neue vCenter für später speichern? ({0})' -f ($newFqdns -join ', ')) `
                -Default 'J' `
                -ValidAnswer 'J', 'N'
            if ($saveAnswer -ieq 'J') {
                $updated = [System.Collections.Generic.List[object]]::new()
                foreach ($entry in $inventory) { $updated.Add($entry) }
                foreach ($fqdn in $newFqdns) {
                    $updated.Add([PSCustomObject]@{
                            PSTypeName  = 'ps-script-machine.VIServerInventoryEntry'
                            Name        = $fqdn
                            Fqdn        = $fqdn
                            Description = ''
                        })
                }
                Save-VIServerInventory -Path $InventoryPath -Inventory $updated.ToArray()
                Write-Host ('Gespeichert in: {0}' -f $InventoryPath) -ForegroundColor Green
            }
        }

        return [string[]]@($tokens | Select-Object -Unique)
    }
}
```

- [ ] **Step 4: Manifest erweitern**

In `src/ps-script-machine/ps-script-machine.psd1` den Export ergänzen:

```powershell
    FunctionsToExport    = @(
        'Get-CdpNetworkInfo',
        'Get-VMHostNetworkInfo',
        'Export-ModuleData',
        'Select-VIServerTarget'
    )
```

- [ ] **Step 5: Doku-Datei anlegen**

Datei `docs/Select-VIServerTarget.md`:

```markdown
# Select-VIServerTarget

Interaktive Auswahl eines oder mehrerer vCenter-Server aus der gespeicherten
Liste (`vcenters.json`), mit freier FQDN-Eingabe und optionalem Speichern
neuer Einträge.

## Syntax

```powershell
Select-VIServerTarget -InventoryPath <string>
```

## Beschreibung

Zeigt die gespeicherten vCenter als nummerierte Liste. Erlaubte Eingaben:
Nummern kommagetrennt (`1,3`), `alle`, oder ein/mehrere FQDNs. Neue FQDNs
werden auf Nachfrage in die `vcenters.json` übernommen. Rückgabe ist eine
deduplizierte FQDN-Liste (`string[]`), nie leer.

## Parameter

| Parameter | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `InventoryPath` | string | ja | Pfad zur `vcenters.json` (Format: siehe `config/vcenters.example.json`) |

## Beispiel

```powershell
$targets = Select-VIServerTarget -InventoryPath (Join-Path $repoRoot 'config\vcenters.json')
```

## Hinweise

- Interaktive Funktion — nicht in Scheduled Tasks verwenden; dort die
  vCenter direkt als Skript-Parameter übergeben.
- Es werden nur Servernamen gespeichert, niemals Zugangsdaten.
```

- [ ] **Step 6: Tests ausführen — sie müssen bestehen**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Unit/Select-VIServerTarget.Tests.ps1 -Output Detailed"`
Expected: PASS (9 Tests).

- [ ] **Step 7: Manifest-, Analyzer-, Compliance-Gates prüfen**

Run: `pwsh -NoProfile -Command "& .\scripts\Invoke-Build.ps1 -Task Manifest, Analyze, Compliance"`
Expected: alle drei PASSED (Compliance findet Testdatei und docs/Select-VIServerTarget.md).

- [ ] **Step 8: Commit**

```bash
git add src/ps-script-machine/Public/Select-VIServerTarget.ps1 src/ps-script-machine/ps-script-machine.psd1 tests/Unit/Select-VIServerTarget.Tests.ps1 docs/Select-VIServerTarget.md
git commit -m "feat: interaktive Multi-vCenter-Auswahl Select-VIServerTarget

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Public Funktion `Connect-MultiVIServer`

Verbindet zu mehreren vCentern mit einem Credential; bei Fehlschlag gezielte Nachfrage pro Server; Teilfehler brechen nie den Gesamtlauf ab.

**Files:**
- Create: `src/ps-script-machine/Public/Connect-MultiVIServer.ps1`
- Create: `tests/Unit/Connect-MultiVIServer.Tests.ps1`
- Create: `docs/Connect-MultiVIServer.md`
- Modify: `src/ps-script-machine/ps-script-machine.psd1` (FunctionsToExport)

**Interfaces:**
- Consumes: `Connect-VIServerSession -Server <string> -Credential <PSCredential>` (bestehend, private; gibt Session oder `$null` + `Write-Error`), `Read-MenuChoice` (Task 1).
- Produces: `Connect-MultiVIServer -Server <string[]> [-Credential <PSCredential>] [-NonInteractive]` → ein `PSCustomObject` mit `PSTypeName 'ps-script-machine.MultiVIServerConnection'` und Properties:
  - `Sessions` (`object[]` — die verbundenen VIServer-Session-Objekte, für `-VIServer`/`-Server`-Parameter und `Disconnect-VIServer`)
  - `Connected` (`string[]` — FQDNs erfolgreicher Verbindungen)
  - `Skipped` (`string[]` — FQDNs übersprungener/fehlgeschlagener Server)
  - `Timestamp` (ISO-8601-String), `RunId` (string)
- Verhalten: ohne `-Credential` interaktiv `Get-Credential` (bei `-NonInteractive` stattdessen `throw`). Login-Fehlschlag interaktiv → Frage `n = neue Zugangsdaten, u = überspringen` (Default `u`), Schleife bis Erfolg oder Überspringen. `-NonInteractive`: Fehlschlag → Warnung + Skip.

- [ ] **Step 1: Fehlschlagende Tests schreiben**

Datei `tests/Unit/Connect-MultiVIServer.Tests.ps1`:

```powershell
#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for the public Connect-MultiVIServer function.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Disposable mock PSCredential for unit testing only - never a real secret, never persisted or logged.')]
param()

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $script:mockCredential = [System.Management.Automation.PSCredential]::new(
        'user@vsphere.local',
        (ConvertTo-SecureString 'password' -AsPlainText -Force)
    )

    function script:New-MockSession {
        param([string]$Name)
        [PSCustomObject]@{
            Name      = $Name
            SessionId = "session-$Name"
            Port      = 443
            Protocol  = 'https'
        }
    }
}

Describe 'Connect-MultiVIServer' {
    BeforeAll {
        Mock Write-Host { } -ModuleName 'ps-script-machine'
    }

    AfterEach {
        Remove-Variable -Name 'PsmTestAnswers' -Scope Global -ErrorAction SilentlyContinue
    }

    Context 'All connections succeed' {
        BeforeAll {
            Mock Connect-VIServer {
                param($Server)
                [PSCustomObject]@{ Name = $Server; SessionId = "session-$Server"; Port = 443; Protocol = 'https' }
            } -ModuleName 'ps-script-machine'
        }

        It 'connects to every server with the given credential' {
            $result = Connect-MultiVIServer -Server 'vc01.test.local', 'vc02.test.local' -Credential $script:mockCredential
            $result.Connected | Should -Be @('vc01.test.local', 'vc02.test.local')
            $result.Skipped | Should -BeNullOrEmpty
            @($result.Sessions).Count | Should -Be 2
            Should -Invoke Connect-VIServer -ModuleName 'ps-script-machine' -Times 2 -Exactly
        }

        It 'returns the documented result object shape' {
            $result = Connect-MultiVIServer -Server 'vc01.test.local' -Credential $script:mockCredential
            $result.PSObject.TypeNames | Should -Contain 'ps-script-machine.MultiVIServerConnection'
            $result.Timestamp | Should -Not -BeNullOrEmpty
            $result.RunId | Should -Not -BeNullOrEmpty
        }

        It 'deduplicates the server list' {
            $result = Connect-MultiVIServer -Server 'vc01.test.local', 'vc01.test.local' -Credential $script:mockCredential
            @($result.Sessions).Count | Should -Be 1
            Should -Invoke Connect-VIServer -ModuleName 'ps-script-machine' -Times 1 -Exactly
        }

        It 'asks for a credential when none is given' {
            Mock Get-Credential { $script:mockCredential } -ModuleName 'ps-script-machine'
            $result = Connect-MultiVIServer -Server 'vc01.test.local'
            $result.Connected | Should -Be @('vc01.test.local')
            Should -Invoke Get-Credential -ModuleName 'ps-script-machine' -Times 1 -Exactly
        }
    }

    Context 'A connection fails' {
        BeforeAll {
            Mock Connect-VIServer {
                param($Server)
                if ($Server -eq 'vc-kaputt.test.local') {
                    throw 'Cannot complete login due to an incorrect user name or password.'
                }
                [PSCustomObject]@{ Name = $Server; SessionId = "session-$Server"; Port = 443; Protocol = 'https' }
            } -ModuleName 'ps-script-machine'
        }

        It 'skips the failing server in NonInteractive mode and continues' {
            $result = Connect-MultiVIServer `
                -Server 'vc01.test.local', 'vc-kaputt.test.local', 'vc02.test.local' `
                -Credential $script:mockCredential -NonInteractive -WarningAction SilentlyContinue
            $result.Connected | Should -Be @('vc01.test.local', 'vc02.test.local')
            $result.Skipped | Should -Be @('vc-kaputt.test.local')
        }

        It 'skips the failing server when the user chooses u' {
            Mock Read-Host { 'u' } -ModuleName 'ps-script-machine'
            $result = Connect-MultiVIServer `
                -Server 'vc-kaputt.test.local', 'vc01.test.local' `
                -Credential $script:mockCredential -WarningAction SilentlyContinue
            $result.Skipped | Should -Be @('vc-kaputt.test.local')
            $result.Connected | Should -Be @('vc01.test.local')
        }

        It 'retries with new credentials when the user chooses n' {
            $global:PsmTestAnswers = [System.Collections.Queue]::new()
            $global:PsmTestAnswers.Enqueue('n')
            Mock Read-Host { $global:PsmTestAnswers.Dequeue() } -ModuleName 'ps-script-machine'
            Mock Get-Credential { $script:mockCredential } -ModuleName 'ps-script-machine'
            Mock Connect-VIServer {
                param($Server, $Credential)
                # First attempt fails, the retry (same mock, second call) succeeds.
                if ((Get-Variable -Name 'PsmRetryDone' -Scope Global -ErrorAction SilentlyContinue) -eq $null) {
                    $global:PsmRetryDone = $true
                    throw 'Cannot complete login.'
                }
                [PSCustomObject]@{ Name = $Server; SessionId = "session-$Server"; Port = 443; Protocol = 'https' }
            } -ModuleName 'ps-script-machine'

            $result = Connect-MultiVIServer -Server 'vc01.test.local' -Credential $script:mockCredential -WarningAction SilentlyContinue
            $result.Connected | Should -Be @('vc01.test.local')
            $result.Skipped | Should -BeNullOrEmpty
            Should -Invoke Get-Credential -ModuleName 'ps-script-machine' -Times 1 -Exactly
            Remove-Variable -Name 'PsmRetryDone' -Scope Global -ErrorAction SilentlyContinue
        }
    }

    Context 'Parameter validation' {
        It 'throws in NonInteractive mode when no credential is given' {
            { Connect-MultiVIServer -Server 'vc01.test.local' -NonInteractive } |
                Should -Throw '*Credential*'
        }
    }
}
```

- [ ] **Step 2: Tests ausführen — sie müssen fehlschlagen**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Unit/Connect-MultiVIServer.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Connect-MultiVIServer` nicht gefunden.

- [ ] **Step 3: Implementierung schreiben**

Datei `src/ps-script-machine/Public/Connect-MultiVIServer.ps1`:

```powershell
#Requires -Version 7.4

<#
.SYNOPSIS
    Verbindet zu einem oder mehreren vCenter-Servern mit gemeinsamen Zugangsdaten.

.DESCRIPTION
    Connect-MultiVIServer fragt (falls nicht übergeben) einmal per
    Get-Credential nach Zugangsdaten und verbindet damit nacheinander zu
    allen angegebenen vCenter-Servern. Häufigster Fall: derselbe
    SSO-Account gilt überall.

    Schlägt die Anmeldung an einem Server fehl, wird im interaktiven Modus
    gezielt nur für diesen Server nachgefragt (neue Zugangsdaten eingeben
    oder überspringen). Ein nicht erreichbarer oder übersprungener Server
    bricht niemals den Gesamtlauf ab - er erscheint in der Skipped-Liste
    des Ergebnisobjekts.

    Im NonInteractive-Modus (Scheduled Tasks) führt ein Fehlschlag zu einer
    Warnung und dem Überspringen des Servers; -Credential ist dann Pflicht.

.PARAMETER Server
    Ein oder mehrere vCenter-FQDNs. Duplikate werden entfernt.

.PARAMETER Credential
    Zugangsdaten für alle Server. Wenn nicht angegeben, wird interaktiv
    per Get-Credential gefragt (außer bei -NonInteractive: dann Pflicht).

.PARAMETER NonInteractive
    Unterdrückt jede Rückfrage. Fehlgeschlagene Verbindungen werden mit
    Warnung übersprungen.

.EXAMPLE
    $connection = Connect-MultiVIServer -Server 'vc01.example.local', 'vc02.example.local'
    foreach ($session in $connection.Sessions) {
        Get-CdpNetworkInfo -VIServer $session
    }

    Fragt einmal nach Zugangsdaten, verbindet zu beiden vCentern und
    verarbeitet anschließend jede Session.

.EXAMPLE
    $connection = Connect-MultiVIServer -Server $targets -Credential $cred -NonInteractive

    Nicht-interaktiver Lauf für Automatisierung.

.INPUTS
    None. Server werden als Parameter übergeben.

.OUTPUTS
    PSCustomObject mit PSTypeName 'ps-script-machine.MultiVIServerConnection':
    Sessions (object[]), Connected (string[]), Skipped (string[]),
    Timestamp (string, ISO 8601), RunId (string).

.NOTES
    Die zurückgegebenen Sessions müssen vom Aufrufer getrennt werden
    (Disconnect-VIServer -Server $connection.Sessions -Confirm:$false),
    idealerweise in einem finally-Block.
    Zugangsdaten werden niemals gespeichert oder geloggt.

.LINK
    https://github.com/spiral023/ps-script-machine
#>
function Connect-MultiVIServer {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interaktive Verbindungsfunktion: Statusausgabe an den Bediener gehört zum Menü-Framework.')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Server,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter(Mandatory = $false)]
        [switch]
        $NonInteractive
    )

    $uniqueServers = @($Server | Select-Object -Unique)

    if (-not $Credential) {
        if ($NonInteractive) {
            throw 'Im nicht-interaktiven Modus muss -Credential angegeben werden (z. B. aus SecretManagement).'
        }
        $serverText = if ($uniqueServers.Count -eq 1) { $uniqueServers[0] } else { "$($uniqueServers.Count) vCenter-Server" }
        $Credential = Get-Credential -Message "Anmeldung für $serverText (z. B. user@vsphere.local)"
        if (-not $Credential) {
            throw 'Es wurden keine Zugangsdaten eingegeben - Abbruch.'
        }
    }

    $sessions = [System.Collections.Generic.List[object]]::new()
    $connected = [System.Collections.Generic.List[string]]::new()
    $skipped = [System.Collections.Generic.List[string]]::new()

    foreach ($fqdn in $uniqueServers) {
        $currentCredential = $Credential
        $resolved = $false

        while (-not $resolved) {
            Write-Host ("Verbinde mit {0} ..." -f $fqdn)
            $session = Connect-VIServerSession -Server $fqdn -Credential $currentCredential -ErrorAction SilentlyContinue

            if ($session) {
                $sessions.Add($session)
                $connected.Add($fqdn)
                Write-Host ("  Verbunden: {0}" -f $fqdn) -ForegroundColor Green
                $resolved = $true
                continue
            }

            Write-Warning ("Anmeldung an '{0}' fehlgeschlagen. " +
                'Mögliche Ursachen: Server nicht erreichbar (Netzwerk/DNS) oder Zugangsdaten falsch. ' +
                'Prüfe den Servernamen oder versuche es mit anderen Zugangsdaten.' -f $fqdn)

            if ($NonInteractive) {
                $skipped.Add($fqdn)
                $resolved = $true
                continue
            }

            $choice = Read-MenuChoice `
                -Prompt ("Wie soll es mit '{0}' weitergehen? (n = neue Zugangsdaten, u = überspringen)" -f $fqdn) `
                -Default 'u' `
                -ValidAnswer 'n', 'u'

            if ($choice -ieq 'u') {
                $skipped.Add($fqdn)
                $resolved = $true
                continue
            }

            $currentCredential = Get-Credential -Message "Neue Anmeldung für $fqdn"
            if (-not $currentCredential) {
                $skipped.Add($fqdn)
                $resolved = $true
            }
        }
    }

    return [PSCustomObject]@{
        PSTypeName = 'ps-script-machine.MultiVIServerConnection'
        Sessions   = $sessions.ToArray()
        Connected  = $connected.ToArray()
        Skipped    = $skipped.ToArray()
        Timestamp  = (Get-Date).ToString('o')
        RunId      = $script:LogRunId
    }
}
```

- [ ] **Step 4: Manifest erweitern**

In `src/ps-script-machine/ps-script-machine.psd1`:

```powershell
    FunctionsToExport    = @(
        'Get-CdpNetworkInfo',
        'Get-VMHostNetworkInfo',
        'Export-ModuleData',
        'Select-VIServerTarget',
        'Connect-MultiVIServer'
    )
```

- [ ] **Step 5: Doku-Datei anlegen**

Datei `docs/Connect-MultiVIServer.md`:

```markdown
# Connect-MultiVIServer

Verbindet mit gemeinsamen Zugangsdaten zu mehreren vCenter-Servern.
Fehlgeschlagene Server werden übersprungen (mit gezielter Nachfrage im
interaktiven Modus) und brechen nie den Gesamtlauf ab.

## Syntax

```powershell
Connect-MultiVIServer -Server <string[]> [-Credential <PSCredential>] [-NonInteractive]
```

## Rückgabeobjekt

`PSCustomObject` mit `PSTypeName 'ps-script-machine.MultiVIServerConnection'`:

| Property | Typ | Bedeutung |
|---|---|---|
| `Sessions` | object[] | Verbundene VIServer-Sessions (für `-VIServer` und `Disconnect-VIServer`) |
| `Connected` | string[] | FQDNs erfolgreicher Verbindungen |
| `Skipped` | string[] | FQDNs übersprungener Server |
| `Timestamp` | string | Zeitstempel (ISO 8601) |
| `RunId` | string | Lauf-ID für Audit/Logs |

## Beispiel

```powershell
$connection = Connect-MultiVIServer -Server 'vc01.example.local', 'vc02.example.local'
try {
    foreach ($session in $connection.Sessions) {
        Get-CdpNetworkInfo -VIServer $session
    }
}
finally {
    if ($connection.Sessions.Count -gt 0) {
        Disconnect-VIServer -Server $connection.Sessions -Confirm:$false -ErrorAction SilentlyContinue
    }
}
```

## Hinweise

- Ohne `-Credential` wird einmal interaktiv gefragt; bei Login-Fehlschlag
  gezielt pro Server (neue Zugangsdaten oder überspringen).
- Mit `-NonInteractive` ist `-Credential` Pflicht; Fehlschläge werden mit
  Warnung übersprungen.
- Der Aufrufer trennt die Sessions (idealerweise im `finally`-Block).
```

- [ ] **Step 6: Tests ausführen — sie müssen bestehen**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Unit/Connect-MultiVIServer.Tests.ps1 -Output Detailed"`
Expected: PASS (9 Tests).

- [ ] **Step 7: Volle Test-Suite + Coverage + Compliance**

Run: `pwsh -NoProfile -Command "& .\scripts\Invoke-Build.ps1 -Task Manifest, Analyze, Test, Coverage, Docs, Compliance"`
Expected: alle PASSED, Coverage ≥ 80 %. Falls Coverage unter 80 % fällt: fehlende Zweige der neuen Funktionen (z. B. Default-Pfade in `Read-MenuChoice`) mit gezielten Zusatz-Tests abdecken — NICHT den Threshold senken.

- [ ] **Step 8: Commit**

```bash
git add src/ps-script-machine/Public/Connect-MultiVIServer.ps1 src/ps-script-machine/ps-script-machine.psd1 tests/Unit/Connect-MultiVIServer.Tests.ps1 docs/Connect-MultiVIServer.md
git commit -m "feat: Multi-vCenter-Verbindungsaufbau Connect-MultiVIServer

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Template `InteractiveWrapper.ps1` + Ordner `scripts/tools/`

Das Wrapper-Template, das der Skill bei jeder Generierung instanziiert. Platzhalter: `__TOOL_NAME__`, `__TOOL_SYNOPSIS__`, `__TOOL_DESCRIPTION__`, `__RESULT_CALL__` sowie die Region `#region tool-questions`.

**Files:**
- Create: `templates/InteractiveWrapper.ps1`
- Create: `scripts/tools/.gitkeep` (Ordner-Anker; ab Task 8 liegt hier der erste echte Wrapper)

**Interfaces:**
- Consumes: `Select-VIServerTarget -InventoryPath` (Task 3), `Connect-MultiVIServer -Server -Credential -NonInteractive` (Task 4), bestehende Public-Funktionen `Export-ModuleData -Data -OutputPath -Format -Force` und fachliche `Get-*`-Funktionen; PowerCLI `Disconnect-VIServer`.
- Produces: die verbindliche Wrapper-Struktur. Die Marker `#region module-import` / `#endregion module-import` sind der Vertrag mit dem Bundle-Build (Task 6): exakt dieser Block wird beim Standalone-Bau entfernt. Der `param`-Block ist Pflicht (der Bundler splittet am `ParamBlock`-AST-Ende).

Hinweis: `templates/` liegt außerhalb des strengen Analyzer-Scopes — `Write-Host`/`Read-Host` sind hier erlaubt und erwünscht. Das Template selbst ist wegen der `__PLATZHALTER__` nur syntaktisch, nicht fachlich lauffähig; sein instanziierter Zwilling (Task 8) wird real getestet.

- [ ] **Step 1: Template schreiben**

Datei `templates/InteractiveWrapper.ps1`:

```powershell
#Requires -Version 7.4

<#
.SYNOPSIS
    __TOOL_SYNOPSIS__

.DESCRIPTION
    __TOOL_DESCRIPTION__

    Dieses Skript führt interaktiv durch alle Schritte:
    1. vCenter auswählen (gespeicherte Liste oder neue FQDNs)
    2. Anmeldung (einmal für alle vCenter, Nachfrage nur bei Fehlschlag)
    3. Toolspezifische Fragen
    4. Ausführung mit Fortschrittsanzeige
    5. Export und Zusammenfassung

    Für Automatisierung (Scheduled Tasks) können alle Eingaben als
    Parameter übergeben werden; mit -NonInteractive wird nie gefragt.

.PARAMETER VCenter
    Ein oder mehrere vCenter-FQDNs. Ohne Angabe erscheint das Auswahlmenü.

.PARAMETER Credential
    Zugangsdaten für alle vCenter. Ohne Angabe wird interaktiv gefragt.

.PARAMETER OutputPath
    Ausgabeordner für die Export-Dateien. Standard: Desktop.

.PARAMETER Format
    Ausgabeformat: CSV, JSON oder beide. Standard: CSV.

.PARAMETER NonInteractive
    Keine Rückfragen; erfordert -VCenter und -Credential.

.EXAMPLE
    .\__TOOL_NAME__.ps1

    Startet das Skript im interaktiven Modus mit Menüführung.

.EXAMPLE
    .\__TOOL_NAME__.ps1 -VCenter vc01.example.local, vc02.example.local -Credential $cred -NonInteractive

    Nicht-interaktiver Lauf für Automatisierung.

.NOTES
    Erstellt mit ps-script-machine (Skript-Werkstatt).
    Read-only: Dieses Skript verändert keine vSphere-Konfiguration.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]
    $VCenter,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.CredentialAttribute()]
    $Credential,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $OutputPath = [Environment]::GetFolderPath('Desktop'),

    [Parameter(Mandatory = $false)]
    [ValidateSet('CSV', 'JSON', 'beide')]
    [string]
    $Format = 'CSV',

    [Parameter(Mandatory = $false)]
    [switch]
    $NonInteractive
)

$ErrorActionPreference = 'Stop'

#region module-import
# Dieser Block wird beim Standalone-Build entfernt - im Standalone-Skript
# sind alle Modul-Funktionen direkt eingebettet.
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
Import-Module -Name (Resolve-Path -Path $modulePath).Path -Force -ErrorAction Stop
#endregion module-import

# ============================================================================
# PowerCLI-Verfügbarkeit prüfen (verständliche Anleitung statt kryptischem Fehler)
# ============================================================================
$powerCliAvailable = Get-Module -ListAvailable -Name 'VMware.VimAutomation.Core', 'VMware.PowerCLI' -ErrorAction SilentlyContinue
if (-not $powerCliAvailable) {
    Write-Host ''
    Write-Host 'VMware PowerCLI ist auf diesem Computer nicht installiert.' -ForegroundColor Red
    Write-Host 'Ohne PowerCLI kann keine Verbindung zu vCenter aufgebaut werden.'
    Write-Host ''
    Write-Host 'So installierst du PowerCLI (einmalig, ohne Adminrechte):' -ForegroundColor Cyan
    Write-Host '  Install-Module VMware.PowerCLI -Scope CurrentUser'
    Write-Host ''
    Write-Host 'Danach dieses Skript einfach erneut starten.'
    exit 1
}

# ============================================================================
# Begrüßung
# ============================================================================
Write-Host ''
Write-Host '=== __TOOL_NAME__ ===' -ForegroundColor Cyan
Write-Host '__TOOL_SYNOPSIS__'

# ============================================================================
# Protokoll je Lauf (Spec §6: kann bei Problemen dem Team geschickt werden)
# ============================================================================
$logDir = Join-Path -Path $OutputPath -ChildPath 'logs'
if (-not (Test-Path -LiteralPath $logDir)) {
    $null = New-Item -Path $logDir -ItemType Directory -Force
}
$logFile = Join-Path -Path $logDir -ChildPath ('__TOOL_NAME___{0:yyyy-MM-dd_HH-mm-ss}.log' -f (Get-Date))
Start-Transcript -Path $logFile | Out-Null
Write-Host ("Protokoll dieses Laufs: {0}" -f $logFile) -ForegroundColor DarkGray

# ============================================================================
# Schritt 1: vCenter bestimmen
# ============================================================================
if (-not $VCenter -or $VCenter.Count -eq 0) {
    if ($NonInteractive) {
        throw 'Im nicht-interaktiven Modus muss -VCenter angegeben werden.'
    }
    # Im Repo liegt die Liste unter config/vcenters.json, beim verteilten
    # Standalone-Skript im Benutzerprofil.
    $repoConfigDir = Join-Path -Path $PSScriptRoot -ChildPath '..\..\config'
    $inventoryPath = if (Test-Path -Path $repoConfigDir) {
        Join-Path -Path $repoConfigDir -ChildPath 'vcenters.json'
    }
    else {
        Join-Path -Path $HOME -ChildPath '.ps-script-machine\vcenters.json'
    }
    $VCenter = Select-VIServerTarget -InventoryPath $inventoryPath
}

# ============================================================================
# Schritt 2: Anmeldung (einmal für alle vCenter)
# ============================================================================
$connection = Connect-MultiVIServer -Server $VCenter -Credential $Credential -NonInteractive:$NonInteractive
if ($connection.Sessions.Count -eq 0) {
    Write-Host ''
    Write-Host 'Es konnte zu keinem vCenter eine Verbindung aufgebaut werden - Abbruch.' -ForegroundColor Red
    Write-Host 'Prüfe Servernamen und Zugangsdaten und starte das Skript erneut.'
    exit 1
}

# ============================================================================
# Schritt 3: Toolspezifische Fragen
# ============================================================================
#region tool-questions
# __TOOL_QUESTIONS__
# Hier stellt das generierte Skript seine fachlichen Fragen, z. B.:
#   if (-not $NonInteractive -and -not $PSBoundParameters.ContainsKey('Format')) {
#       $Format = Read-Host 'Ausgabeformat (CSV/JSON/beide) [CSV]'
#       if ([string]::IsNullOrWhiteSpace($Format)) { $Format = 'CSV' }
#   }
# Regeln: Jede Frage hat einen Standardwert (Enter = Standard); Fragen nur,
# wenn -not $NonInteractive und der Parameter nicht explizit gesetzt wurde.
#endregion tool-questions

# ============================================================================
# Schritt 4 + 5: Ausführung, Export, Zusammenfassung
# ============================================================================
$allResults = [System.Collections.Generic.List[object]]::new()
try {
    $total = $connection.Sessions.Count
    $current = 0
    foreach ($session in $connection.Sessions) {
        $current++
        Write-Progress -Activity '__TOOL_NAME__' `
            -Status ("vCenter {0} ({1} von {2})" -f $session.Name, $current, $total) `
            -PercentComplete (($current / $total) * 100)

        # __RESULT_CALL__
        # Hier ruft das generierte Skript seine Modul-Funktion auf, z. B.:
        #   $results = Get-CdpNetworkInfo -VIServer $session
        $results = @()

        if ($results) {
            $allResults.AddRange(@($results))
        }
    }
    Write-Progress -Activity '__TOOL_NAME__' -Completed

    if ($allResults.Count -eq 0) {
        Write-Host ''
        Write-Host 'Es wurden keine Daten gefunden.' -ForegroundColor Yellow
        Write-Host 'Mögliche Ursache: keine passenden Objekte in den gewählten vCentern.'
    }
    else {
        if (-not (Test-Path -LiteralPath $OutputPath)) {
            $null = New-Item -Path $OutputPath -ItemType Directory -Force
        }
        $formats = if ($Format -eq 'beide') { @('CSV', 'JSON') } else { @($Format) }
        $files = Export-ModuleData -Data $allResults.ToArray() -OutputPath $OutputPath -Format $formats -Force
    }

    Write-Host ''
    Write-Host 'Fertig!' -ForegroundColor Green
    $totalRequested = $connection.Connected.Count + $connection.Skipped.Count
    Write-Host ("  Abgefragte vCenter : {0} von {1}" -f $connection.Connected.Count, $totalRequested)
    if ($connection.Skipped.Count -gt 0) {
        Write-Host ("  Übersprungen       : {0}" -f ($connection.Skipped -join ', ')) -ForegroundColor Yellow
    }
    Write-Host ("  Ergebnisse         : {0}" -f $allResults.Count)
    if ($allResults.Count -gt 0) {
        foreach ($file in @($files)) {
            Write-Host ("  Datei              : {0}" -f $file)
        }
    }
}
finally {
    foreach ($session in $connection.Sessions) {
        try {
            Disconnect-VIServer -Server $session -Confirm:$false -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning ("Die Verbindung zu '{0}' konnte nicht sauber getrennt werden." -f $session.Name)
        }
    }
    try {
        Stop-Transcript | Out-Null
    }
    catch {
        # Transcript war nicht (mehr) aktiv - unkritisch.
    }
}
```

Hinweis: `Start-Transcript` erfüllt die Spec-Anforderung „Log-Datei je Lauf" ohne Zugriff auf die private Funktion `Write-ScriptLog` (die ein Wrapper nach `Import-Module` gar nicht aufrufen könnte — genau dieser Bug steckte im alten `Export-CdpInformation.ps1`).

- [ ] **Step 2: Ordner-Anker anlegen**

```powershell
New-Item -ItemType Directory -Force scripts/tools | Out-Null
if (-not (Test-Path 'scripts/tools/.gitkeep')) { New-Item -ItemType File 'scripts/tools/.gitkeep' | Out-Null }
```

- [ ] **Step 3: Template-Syntax verifizieren**

Run: `pwsh -NoProfile -Command "$e=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'templates/InteractiveWrapper.ps1'), [ref]$null, [ref]$e) | Out-Null; if ($e.Count) { $e; exit 1 } else { 'Syntax OK' }"`
Expected: `Syntax OK`.

- [ ] **Step 4: Commit**

```bash
git add templates/InteractiveWrapper.ps1 scripts/tools/.gitkeep
git commit -m "feat: interaktives Wrapper-Template mit Multi-vCenter-Menüführung

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Bundle-Build `Export-StandaloneScript.ps1`

Baut aus jedem Wrapper in `scripts/tools/` ein eigenständiges Single-File-Skript in `build/standalone/` (alle Modul-Funktionen eingebettet, `module-import`-Region entfernt).

**Files:**
- Create: `scripts/Export-StandaloneScript.ps1`
- Create: `tests/Unit/Export-StandaloneScript.Tests.ps1`

**Interfaces:**
- Consumes: den Template-Vertrag aus Task 5 (`param`-Block Pflicht, Marker `#region module-import` … `#endregion module-import`), Modulquellen `src/ps-script-machine/Private/*.ps1` + `Public/*.ps1`, Modulversion aus dem Manifest.
- Produces: `Export-StandaloneScript.ps1 [-ToolsPath <string>] [-OutputPath <string>] [-Name <string[]>]` → schreibt pro Wrapper `build/standalone/<Name>.ps1` und gibt die erzeugten Pfade als `[string[]]` zurück. Wirft bei Parse-Fehlern (Quelle oder Ergebnis). Aufbau der Ausgabedatei: `#Requires` → generierter Hinweis-Kommentar → Original-CBH+`param` (ohne eigene `#Requires`-Zeilen) → Skript-Scope-Initialisierung (`$script:ModuleVersion`, `$script:LogRunId`, `$script:ModuleSessions`) + alle Modul-Funktionen (Private zuerst) → Wrapper-Body ohne `module-import`-Region.

- [ ] **Step 1: Fehlschlagenden Test schreiben**

Datei `tests/Unit/Export-StandaloneScript.Tests.ps1`:

```powershell
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
```

- [ ] **Step 2: Test ausführen — er muss fehlschlagen**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Unit/Export-StandaloneScript.Tests.ps1 -Output Detailed"`
Expected: FAIL — `scripts/Export-StandaloneScript.ps1` existiert nicht.

- [ ] **Step 3: Bundler implementieren**

Datei `scripts/Export-StandaloneScript.ps1` — Comment-Based Help mit `.SYNOPSIS` („Baut eigenständige Single-File-Skripte aus den Wrappern in scripts/tools/."), `.DESCRIPTION` (Mechanik V1: ALLE Modul-Funktionen einbetten, kein Dependency-Walking; Vertrag mit dem Template; zweistufige Verifikation), `.PARAMETER` für alle drei Parameter, zwei `.EXAMPLE`, `.NOTES` (wird als Build-Task `Standalone` aufgerufen). Danach exakt dieser Code:

```powershell
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
```

- [ ] **Step 4: Tests ausführen — sie müssen bestehen**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Unit/Export-StandaloneScript.Tests.ps1 -Output Detailed"`
Expected: PASS (8 Tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/Export-StandaloneScript.ps1 tests/Unit/Export-StandaloneScript.Tests.ps1
git commit -m "feat: Bundle-Build für eigenständige Single-File-Skripte

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Build-Integration des Standalone-Tasks

`Invoke-Build.ps1` bekommt den Task `Standalone` (nach `Build`), damit lokal und in CI automatisch gebündelt und verifiziert wird.

**Files:**
- Modify: `scripts/Invoke-Build.ps1` (vier Stellen: CBH-Taskliste, `ValidateSet`, `$taskOrder`, `$taskActions`)

**Interfaces:**
- Consumes: `scripts/Export-StandaloneScript.ps1` (Task 6; parameterlos aufrufbar, wirft bei Fehlern, gibt erzeugte Pfade zurück).
- Produces: Build-Task `Standalone`, enthalten in `All` (CI ruft `Invoke-Build.ps1 -CI` = All und deckt ihn damit automatisch ab).

- [ ] **Step 1: `ValidateSet` erweitern**

In `scripts/Invoke-Build.ps1` (param-Block):

```powershell
    [ValidateSet('Manifest', 'Analyze', 'Test', 'Coverage', 'Docs', 'Build', 'Standalone', 'Secrets', 'Compliance', 'All')]
```

- [ ] **Step 2: `$taskOrder` erweitern**

```powershell
$taskOrder = @('Manifest', 'Analyze', 'Test', 'Coverage', 'Docs', 'Build', 'Standalone', 'Secrets', 'Compliance')
```

- [ ] **Step 3: Task-Action ergänzen**

In `$taskActions` direkt nach dem `Build = { … }`-Block einfügen:

```powershell
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
```

Außerdem in der `.DESCRIPTION` von `Invoke-Build.ps1` die nummerierte Taskliste um „Standalone script bundling" (zwischen „6. Module build" und „7. Secret scan") und im `.PARAMETER Task`-Text die gültigen Werte um `Standalone` ergänzen.

- [ ] **Step 4: Build-Task einzeln verifizieren**

Run: `pwsh -NoProfile -Command "& .\scripts\Invoke-Build.ps1 -Task Standalone"`
Expected: PASSED — vor Task 8 mit der Meldung „Keine Wrapper … nichts zu bündeln.", nach Task 8 mit einer `Created:`-Zeile.

- [ ] **Step 5: Commit**

```bash
git add scripts/Invoke-Build.ps1
git commit -m "build: Standalone-Bundling als Build-Task integriert

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---


### Task 8: Migration `Export-CdpInformation.ps1` auf das neue Framework (Pilot)

Der bestehende Single-vCenter-Wrapper wird durch einen Multi-vCenter-Wrapper in `scripts/tools/` ersetzt — er ist zugleich das Referenz-Beispiel, das der Skill (Task 9) zitiert. Wichtig: Der alte Wrapper rief die **privaten** Funktionen `Export-ReportCsv`/`Write-ScriptLog` auf, die nach `Import-Module` gar nicht sichtbar sind — der neue nutzt ausschließlich die Public-API.

**Files:**
- Delete: `scripts/Export-CdpInformation.ps1` (via `git mv` nach `scripts/tools/` + vollständiges Neuschreiben)
- Create: `scripts/tools/Export-CdpInformation.ps1`

**Interfaces:**
- Consumes: das instanziierte Template aus Task 5 mit `Get-CdpNetworkInfo -VIServer <session>` (bestehend, Public) als `__RESULT_CALL__`; toolspezifische Frage: Ausgabeformat.
- Produces: den ersten echten Wrapper in `scripts/tools/` — Eingabe für den Bundle-Build (Task 7 zeigt danach eine `Created:`-Zeile).

- [ ] **Step 1: Datei verschieben**

```bash
git mv scripts/Export-CdpInformation.ps1 scripts/tools/Export-CdpInformation.ps1
```

- [ ] **Step 2: Inhalt vollständig ersetzen**

Neuer Inhalt von `scripts/tools/Export-CdpInformation.ps1` — exakt das Template aus Task 5, mit diesen Ersetzungen (alle weiteren Zeilen identisch zum Template):

1. Alle `__TOOL_NAME__` → `Export-CdpInformation`
2. Alle `__TOOL_SYNOPSIS__` → `Exportiert CDP-Informationen aller ESXi-Netzwerkinterfaces als CSV/JSON.`
3. `__TOOL_DESCRIPTION__` →

```text
    Liest über die Modul-Funktion Get-CdpNetworkInfo die CDP-Daten
    (Cisco Discovery Protocol) aller physischen Netzwerkadapter aller
    ESXi-Hosts aus einem oder mehreren vCentern aus und exportiert sie
    als CSV und/oder JSON.
```

4. Die `#region tool-questions`-Region (inklusive der Beispiel-Kommentare) ersetzen durch:

```powershell
#region tool-questions
if (-not $NonInteractive -and -not $PSBoundParameters.ContainsKey('Format')) {
    $formatAnswer = Read-Host 'Ausgabeformat (CSV/JSON/beide) [CSV]'
    if (-not [string]::IsNullOrWhiteSpace($formatAnswer) -and $formatAnswer.Trim() -in @('CSV', 'JSON', 'beide')) {
        $Format = $formatAnswer.Trim()
    }
}
#endregion tool-questions
```

5. Den `# __RESULT_CALL__`-Block (Kommentare + `$results = @()`) ersetzen durch:

```powershell
        $results = Get-CdpNetworkInfo -VIServer $session
```

- [ ] **Step 3: Syntax verifizieren**

Run: `pwsh -NoProfile -Command "$e=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'scripts/tools/Export-CdpInformation.ps1'), [ref]$null, [ref]$e) | Out-Null; if ($e.Count) { $e; exit 1 } else { 'Syntax OK' }"`
Expected: `Syntax OK`.

- [ ] **Step 4: Standalone-Build gegen den echten Wrapper verifizieren**

Run: `pwsh -NoProfile -Command "& .\scripts\Invoke-Build.ps1 -Task Standalone"`
Expected: PASSED mit `Created: …\build\standalone\Export-CdpInformation.ps1`.

Zusätzlich Stichprobe am Ergebnis:

Run: `pwsh -NoProfile -Command "$c = Get-Content build/standalone/Export-CdpInformation.ps1 -Raw; @('function Get-CdpNetworkInfo', 'function Connect-MultiVIServer', 'function Select-VIServerTarget', 'function Read-MenuChoice') | ForEach-Object { if ($c -notmatch [regex]::Escape($_)) { throw \"fehlt: $_\" } }; 'Stichprobe OK'"`
Expected: `Stichprobe OK`.

- [ ] **Step 5: Referenzen auf den alten Pfad aktualisieren**

Run: `pwsh -NoProfile -Command "Get-ChildItem -Recurse -Include '*.md','*.ps1' -Path . | Where-Object FullName -NotMatch '\\\\(build|\.git)\\\\' | Select-String -Pattern 'scripts[\\\\/]Export-CdpInformation' | Select-Object Path, LineNumber, Line"`

Jede Fundstelle (erwartet u. a. in `README.md`, `docs/ARCHITECTURE.md`, `examples/Get-CdpInfoExample.ps1`) auf `scripts/tools/Export-CdpInformation.ps1` umstellen.

- [ ] **Step 6: Volle Test-Suite**

Run: `pwsh -NoProfile -Command "& .\scripts\Invoke-Build.ps1"`
Expected: alle Tasks PASSED (inkl. Standalone).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: Export-CdpInformation auf Multi-vCenter-Menü-Framework migriert

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Skill „Skript-Werkstatt" (natürlichsprachliche Erstellung)

Die Prozessdefinition für Claude Code: vom deutschen Satz über das dynamische Interview bis zum getesteten Skript samt Standalone-Variante.

**Files:**
- Create: `.agents/skills/script-werkstatt/SKILL.md`
- Create: `.agents/skills/script-werkstatt/metadata.json`
- Modify: `CLAUDE.md` (Verweis im Abschnitt „Neue Funktion erstellen")
- Modify: `AGENTS.md` (kurzer Verweis-Abschnitt am Ende von Abschnitt 1 „Ziel" oder als eigener Abschnitt)

**Interfaces:**
- Consumes: alle vorherigen Tasks — der Skill referenziert `templates/InteractiveWrapper.ps1`, `scripts/New-PowerCLITool.ps1`, `scripts/Invoke-Build.ps1 -Task Standalone`, `scripts/tools/Export-CdpInformation.ps1` (Referenz-Beispiel) und die Framework-Funktionen.
- Produces: den durch Claude Code ausführbaren Workflow. Kein Code — reine Prozessdefinition.

- [ ] **Step 1: SKILL.md schreiben**

Datei `.agents/skills/script-werkstatt/SKILL.md`:

````markdown
---
name: script-werkstatt
description: Erstellt aus einer deutschen Beschreibung eines VMware-Administrators ein fertiges, getestetes PowerCLI-Skript mit interaktivem Multi-vCenter-Menü. Trigger - ein Nutzer beschreibt ein gewünschtes Skript in natürlicher Sprache ("Schreibe ein Script, das ...", "Ich brauche eine Auswertung ...", "Erstelle mir ein Tool ...") für vSphere/vCenter/ESXi-Aufgaben.
license: MIT
metadata:
  author: custom
  version: "1.0.0"
---

# Skript-Werkstatt: Von der Beschreibung zum fertigen Skript

Du führst einen VMware-Administrator OHNE Programmierkenntnisse von seiner
deutschen Beschreibung zu einem fertigen, getesteten PowerCLI-Skript.

## Eiserne Regeln

1. **Fachsprache, nie Code-Sprache.** Alle Fragen und Erklärungen in
   VMware-Begriffen (Hosts, Cluster, VMs, Portgroups, Datastores).
   Niemals nach Parametertypen, Funktionen oder Code-Details fragen.
   Der Admin muss zu keinem Zeitpunkt Code lesen.
2. **Alle Standards aus AGENTS.md gelten unverändert** (Tests, Coverage,
   Sicherheit, Comment-Based Help, Definition of Done).
3. **Read-only vs. verändernd sauber trennen.** Bei verändernden Skripten
   sind die Sicherheitsfragen (Phase 2) verpflichtend und das Skript
   bekommt SupportsShouldProcess gemäß templates/ChangeScript.ps1.
4. **Build-Fehler behebst du selbst.** Der Admin sieht davon nichts.

## Phase 1: Verstehen

Ordne den Wunsch ein, bevor du fragst:

- Lesend (Auswertung/Report) oder verändernd (Konfiguration/Aktion)?
- Welche vSphere-Objekte? (Hosts, VMs, Netzwerk, Storage, Cluster, ...)
- Gibt es schon eine passende Modul-Funktion? Prüfe
  `Get-Command -Module ps-script-machine` bzw. `src/ps-script-machine/Public/`.
  Falls ja: nur neuen Wrapper bauen, keine neue Funktion.

## Phase 2: Dynamisches Interview

Stelle so viele Fragen wie nötig, um ein gemeinsames Verständnis zu
erreichen - nicht mehr. Eine Frage pro Nachricht, immer mit sinnvollem
Standardwert. Fragenkatalog als Inspiration (situativ auswählen/ergänzen):

- **Geltungsbereich:** Alle Hosts/VMs oder gefiltert (Cluster, Name)?
  Auch Objekte im Wartungsmodus / ausgeschaltete VMs?
- **Ausgabe:** CSV, JSON oder beides? Ablageort (Standard: Desktop)?
  Welche Spalten sind wichtig?
- **Fehlerverhalten:** Wenn ein Host/vCenter nicht antwortet - weitermachen
  und am Ende ausweisen (Standard) oder abbrechen?
- **Nutzung:** Einmalig/gelegentlich interaktiv oder regelmäßig automatisch
  (dann Parameter-Betrieb mit -NonInteractive erwähnen)?

Bei VERÄNDERNDEN Skripten zusätzlich verpflichtend:

- Vorschau-Lauf (-WhatIf) erklären und anbieten - immer eingebaut.
- Bestätigung pro Objekt oder einmal pro Lauf?
- Was ist der erwartete Zustand vorher/nachher?

## Phase 3: Zusammenfassung und Freigabe (Vertragsstelle)

Fasse VOR der Generierung auf Deutsch zusammen:

> Das Skript wird: [was] von [Geltungsbereich] aus [vCentern] auslesen,
> als [Format] nach [Ort] exportieren. Bei nicht erreichbaren Servern:
> [Verhalten]. Es verändert nichts / Es verändert [was] mit Vorschau und
> Bestätigung.

Erst nach ausdrücklicher Bestätigung weiterarbeiten. Korrekturen einarbeiten
und erneut zusammenfassen.

## Phase 4: Generierung

1. **Modul-Funktion** (nur falls keine passende existiert):
   `.\scripts\New-PowerCLITool.ps1 -FunctionName '<Verb-Noun>' -Type <ReadOnly|Change> -Synopsis '<Kurzbeschreibung>'`
   Dann Fachlogik implementieren; Ergebnisobjekte als PSCustomObject mit
   PSTypeName, VIServer-, Timestamp-, RunId-Property (Contract-Test!).
   Die Funktion nimmt Sessions über `-VIServer` entgegen (wie
   Get-CdpNetworkInfo), NICHT Server-String + Credential.
2. **Wrapper**: `templates/InteractiveWrapper.ps1` nach
   `scripts/tools/<Export|Get>-<Name>.ps1` kopieren und die Platzhalter
   füllen (`__TOOL_NAME__`, `__TOOL_SYNOPSIS__`, `__TOOL_DESCRIPTION__`,
   `tool-questions`-Region, `__RESULT_CALL__`).
   Referenz-Beispiel: `scripts/tools/Export-CdpInformation.ps1`.
   Die Marker `#region module-import`/`#endregion module-import` und den
   param-Block NIEMALS entfernen (Vertrag mit dem Standalone-Build).
3. **Pester-Tests** für neue Modul-Funktionen nach dem Muster der
   bestehenden Tests in `tests/Unit/` (TestHelpers.ps1 dot-sourcen,
   Mocks mit -ModuleName).

## Phase 5: Qualitätssicherung

`.\scripts\Invoke-Build.ps1` ausführen. ALLE Tasks müssen PASSED sein
(inkl. Coverage >= 80 % und Standalone-Bundling). Fehler selbst beheben
und erneut bauen - den Admin damit nicht behelligen.

## Phase 6: Übergabe

Kurze deutsche Anleitung an den Admin:

- Wo liegt das Skript (`scripts/tools/<Name>.ps1`) und wie startet man es
  (`pwsh -File .\scripts\tools\<Name>.ps1`).
- Was wird es fragen (vCenter-Auswahl, Anmeldung, toolspezifische Fragen).
- Wo landet die Ausgabe.
- Hinweis: Die verteilbare Einzeldatei liegt in
  `build/standalone/<Name>.ps1` und läuft auf jedem Rechner mit
  PowerShell 7.4+ und PowerCLI - ohne dieses Repository.
````

- [ ] **Step 2: metadata.json schreiben**

Datei `.agents/skills/script-werkstatt/metadata.json` (Struktur analog `.agents/skills/vmware-powercli-scripts/metadata.json` — vor dem Schreiben dessen Felder übernehmen und anpassen):

```json
{
  "name": "script-werkstatt",
  "version": "1.0.0",
  "description": "Deutsche Beschreibung -> fertiges PowerCLI-Skript mit interaktivem Multi-vCenter-Menü",
  "author": "custom",
  "license": "MIT"
}
```

- [ ] **Step 3: CLAUDE.md ergänzen**

In `CLAUDE.md` nach dem Abschnitt „## Neue Funktion erstellen" einfügen:

```markdown
## Skript per Beschreibung erstellen (Skript-Werkstatt)

Beschreibt ein Nutzer ein gewünschtes Skript in natürlicher Sprache
(z. B. „Schreibe ein Script, das die CDP-Daten aller ESXi-Netzwerkinterfaces
ausliest"), folge dem Workflow in
`.agents/skills/script-werkstatt/SKILL.md`: dynamisches Interview in
VMware-Fachsprache, Zusammenfassung zur Freigabe, dann Generierung über
`templates/InteractiveWrapper.ps1` und `scripts/New-PowerCLITool.ps1`.
```

- [ ] **Step 4: AGENTS.md ergänzen**

In `AGENTS.md` am Ende von Abschnitt „1. Ziel" einfügen:

```markdown
### Skript-Werkstatt (natürlichsprachliche Erstellung)

Für Skript-Wünsche in natürlicher Sprache gilt der Workflow in
`.agents/skills/script-werkstatt/SKILL.md` (Interview → Freigabe →
Generierung → Build → Übergabe). Interaktive Wrapper entstehen aus
`templates/InteractiveWrapper.ps1` in `scripts/tools/` und werden vom
Build-Task `Standalone` zusätzlich als Einzeldatei nach `build/standalone/`
gebündelt.
```

- [ ] **Step 5: Commit**

```bash
git add .agents/skills/script-werkstatt/ CLAUDE.md AGENTS.md
git commit -m "docs: Skill Skript-Werkstatt für natürlichsprachliche Skript-Erstellung

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Dokumentation + Gesamtabnahme

README-Abschnitt für Menschen, Gesamtbuild als Abnahme, Abgleich gegen die Spec.

**Files:**
- Modify: `README.md` (neuer Abschnitt nach „Installation")
- Modify: `docs/ARCHITECTURE.md` (Ordner `scripts/tools/`, Build-Task `Standalone`, neue Public-Funktionen erwähnen — im Stil der bestehenden Abschnitte)

**Interfaces:**
- Consumes: alles Vorherige.
- Produces: abgeschlossenes Feature.

- [ ] **Step 1: README-Abschnitt schreiben**

In `README.md` nach dem Abschnitt „Installation" einfügen:

````markdown
## Creating scripts from a plain-language description (Skript-Werkstatt)

VMware admins without programming knowledge can request new tools in plain
German inside Claude Code (or any coding agent following AGENTS.md):

> „Schreibe ein Script, das die CDP-Daten aller ESXi-Netzwerkinterfaces
> von allen Hosts von einem oder mehreren vCentern ausliest und als CSV
> speichert."

The agent follows `.agents/skills/script-werkstatt/SKILL.md`: it asks
clarifying questions in VMware terms (never code terms), summarizes what
the script will do, generates a tested module function plus an interactive
wrapper in `scripts/tools/`, and runs the full build.

Every generated wrapper guides the user through the same menu flow:
vCenter selection (saved list in `config/vcenters.json` + free input),
one credential prompt for all vCenters (with per-server retry on failure),
tool-specific questions, progress display, and a summary with output paths.
Unreachable vCenters are skipped and reported - they never abort the run.

The build additionally bundles each wrapper into a self-contained
single-file script in `build/standalone/` that runs on any machine with
PowerShell 7.4+ and PowerCLI - no repository required:

```powershell
.\scripts\Invoke-Build.ps1 -Task Standalone
```
````

- [ ] **Step 2: ARCHITECTURE.md aktualisieren**

`docs/ARCHITECTURE.md` lesen und an den passenden Stellen ergänzen (bestehenden Stil übernehmen):

- Verzeichnisbaum: `scripts/tools/` („Interaktive Wrapper, Quelle für den Standalone-Build") und `build/standalone/` ergänzen.
- Build-Abschnitt: Task `Standalone` zwischen `Build` und `Secrets` dokumentieren.
- Modul-Abschnitt: `Select-VIServerTarget`, `Connect-MultiVIServer` als Public-Funktionen, `Read-MenuChoice`, `Get-VIServerInventory`, `Save-VIServerInventory` als Private-Funktionen aufführen.

- [ ] **Step 3: Gesamtbuild als Abnahme**

Run: `pwsh -NoProfile -Command "& .\scripts\Invoke-Build.ps1 -CI"`
Expected: Build Summary — ALLE Tasks PASSED (Manifest, Analyze, Test, Coverage, Docs, Build, Standalone, Secrets, Compliance). `-CI` stellt sicher, dass auch Analyzer-Warnungen auffallen.

- [ ] **Step 4: Spec-Abgleich**

Jede Anforderung aus `docs/superpowers/specs/2026-07-18-script-werkstatt-design.md` gegen den Ist-Stand prüfen (Abschnitte 3–9). Insbesondere: Menü-Ablauf 7 Schritte, Teilfehler-Prinzip, deutsche dreiteilige Fehlermeldungen, PowerCLI-Check im Standalone, `vcenters.example.json` eingecheckt / `vcenters.json` gitignored. Abweichungen beheben oder (falls bewusst) im Spec-Dokument unter „Bewusst ausgeklammert" nachtragen.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/ARCHITECTURE.md docs/superpowers/specs/2026-07-18-script-werkstatt-design.md
git commit -m "docs: Skript-Werkstatt und Standalone-Build dokumentiert

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Hinweis für die Ausführung

- Tasks strikt in Reihenfolge 1 → 10 (Task 7 vor Task 8 ist wichtig, damit der Standalone-Task beim Pilot-Wrapper schon greift).
- Nach jedem Task muss `Invoke-Build.ps1 -Task Analyze, Test` grün sein; nach Task 4, 8 und 10 der jeweils angegebene größere Lauf.
- Der manuelle End-to-End-Test des Piloten (echtes vCenter) liegt außerhalb dieses Plans — er erfordert eine Live-Umgebung des Admins.

