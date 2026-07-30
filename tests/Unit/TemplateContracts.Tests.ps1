#Requires -Version 7.4

<#
.SYNOPSIS
    Verifies the runtime and safety contracts of script templates and wrappers.
#>

BeforeDiscovery {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    $script:interactiveTemplatePath = Join-Path $script:repoRoot 'templates\InteractiveWrapper.ps1'
    $script:readOnlyTemplatePath = Join-Path $script:repoRoot 'templates\ReadOnlyScript.ps1'
    $script:changeTemplatePath = Join-Path $script:repoRoot 'templates\ChangeScript.ps1'
    $script:exampleWrapperPath = Join-Path $script:repoRoot 'scripts\tools\Export-CdpInformation.ps1'
    $script:lightSkillPath = Join-Path $script:repoRoot '.agents\skills\powershell-skript-werkstatt-light\SKILL.md'

    $script:runtimeWrappers = @(
        $script:interactiveTemplatePath
        $script:exampleWrapperPath
    )
    $script:allTemplates = @(
        $script:interactiveTemplatePath
        $script:readOnlyTemplatePath
        $script:changeTemplatePath
        $script:exampleWrapperPath
    )
}

BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    $script:interactiveTemplatePath = Join-Path $script:repoRoot 'templates\InteractiveWrapper.ps1'
    $script:readOnlyTemplatePath = Join-Path $script:repoRoot 'templates\ReadOnlyScript.ps1'
    $script:changeTemplatePath = Join-Path $script:repoRoot 'templates\ChangeScript.ps1'
    $script:exampleWrapperPath = Join-Path $script:repoRoot 'scripts\tools\Export-CdpInformation.ps1'
    $script:lightSkillPath = Join-Path $script:repoRoot '.agents\skills\powershell-skript-werkstatt-light\SKILL.md'
    $script:allTemplates = @(
        $script:interactiveTemplatePath
        $script:readOnlyTemplatePath
        $script:changeTemplatePath
        $script:exampleWrapperPath
    )
}

Describe 'PowerShell template syntax' {
    It '<Path> parses without errors' -ForEach @(
        @{ Path = $script:interactiveTemplatePath }
        @{ Path = $script:readOnlyTemplatePath }
        @{ Path = $script:changeTemplatePath }
        @{ Path = $script:exampleWrapperPath }
    ) {
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $Path,
            [ref]$null,
            [ref]$parseErrors
        ) | Out-Null

        @($parseErrors).Count | Should -Be 0
    }
}

Describe 'RAITEC-derived runtime contract' {
    It '<Path> uses strict mode and the required PowerCLI minimum version' -ForEach @(
        @{ Path = $script:interactiveTemplatePath }
        @{ Path = $script:readOnlyTemplatePath }
        @{ Path = $script:changeTemplatePath }
        @{ Path = $script:exampleWrapperPath }
    ) {
        $content = Get-Content -LiteralPath $Path -Raw

        $content | Should -Match 'Set-StrictMode\s+-Version\s+Latest'
        $content | Should -Match "\[version\]'13\.2\.0'"
    }

    It '<Path> has one final process exit and no legacy global runtime mutation' -ForEach @(
        @{ Path = $script:interactiveTemplatePath }
        @{ Path = $script:readOnlyTemplatePath }
        @{ Path = $script:changeTemplatePath }
        @{ Path = $script:exampleWrapperPath }
    ) {
        $content = Get-Content -LiteralPath $Path -Raw
        $exitMatches = [regex]::Matches($content, '(?m)^\s*exit\s+\$exitCode\s*$')

        $exitMatches.Count | Should -Be 1
        $content.TrimEnd() | Should -Match 'exit\s+\$exitCode$'
        $content | Should -Not -Match '(?i)\$global:'
        $content | Should -Not -Match '(?i)\$env:PSModulePath\s*='
        $content | Should -Not -Match '(?m)^\s*trap\s*\{'
    }

    It '<Path> records a structured run summary' -ForEach @(
        @{ Path = $script:interactiveTemplatePath }
        @{ Path = $script:readOnlyTemplatePath }
        @{ Path = $script:changeTemplatePath }
        @{ Path = $script:exampleWrapperPath }
    ) {
        $content = Get-Content -LiteralPath $Path -Raw

        foreach ($propertyName in @(
                'RunId',
                'StartedAtUtc',
                'CompletedAtUtc',
                'DurationSeconds',
                'Status',
                'ExitCode',
                'ResultCount'
            )) {
            $content | Should -Match ([regex]::Escape($propertyName))
        }
    }

    It '<Path> protects module import and connection with the outer lifecycle' -ForEach @(
        @{ Path = $script:interactiveTemplatePath }
        @{ Path = $script:exampleWrapperPath }
    ) {
        $content = Get-Content -LiteralPath $Path -Raw
        $outerTryIndex = $content.IndexOf("try {")
        $moduleImportIndex = $content.IndexOf('#region module-import')
        $connectionIndex = $content.IndexOf('Connect-MultiVIServer')

        $outerTryIndex | Should -BeGreaterThan -1
        $moduleImportIndex | Should -BeGreaterThan $outerTryIndex
        $connectionIndex | Should -BeGreaterThan $moduleImportIndex
        $content | Should -Match 'finally\s*\{'
    }

    It '<Path> prepares the run summary before dependency preflight' -ForEach @(
        @{ Path = $script:interactiveTemplatePath }
        @{ Path = $script:exampleWrapperPath }
    ) {
        $content = Get-Content -LiteralPath $Path -Raw
        $summaryPathIndex = $content.IndexOf('$summaryPath = Join-Path')
        $powerCliPreflightIndex = $content.IndexOf('$powerCliModules = @(')

        $summaryPathIndex | Should -BeGreaterThan -1
        $powerCliPreflightIndex | Should -BeGreaterThan $summaryPathIndex
    }

    It '<Path> makes transcripts explicit and documents their sensitivity' -ForEach @(
        @{ Path = $script:interactiveTemplatePath }
        @{ Path = $script:exampleWrapperPath }
    ) {
        $content = Get-Content -LiteralPath $Path -Raw

        $content | Should -Match '\[switch\]\s*\r?\n\s*\$EnableTranscript'
        $content | Should -Match 'if\s*\(\$EnableTranscript\)'
        $content | Should -Match '(?i)sensib'
        $content | Should -Match 'LogRetentionDays'
    }
}

Describe 'Connection and change safety contracts' {
    It 'templates use the public multi-vCenter connection function' {
        foreach ($path in $script:allTemplates) {
            $content = Get-Content -LiteralPath $path -Raw
            $content | Should -Not -Match 'Connect-VIServerSession'
            $content | Should -Match 'Connect-MultiVIServer'
        }
    }

    It 'the modifying template forwards WhatIf and Confirm to the operation' {
        $content = Get-Content -LiteralPath $script:changeTemplatePath -Raw

        $content | Should -Match '\$operationParameters\[''WhatIf''\]\s*=\s*\$WhatIfPreference'
        $content | Should -Match '\$operationParameters\[''Confirm''\]'
        $content | Should -Match 'Set-Something\s+@operationParameters'
    }
}

Describe 'Skill progressive disclosure contract' {
    It 'keeps the light skill below 500 lines' {
        (Get-Content -LiteralPath $script:lightSkillPath).Count | Should -BeLessThan 500
    }

    It 'provides all conditional runtime references' {
        $skillDirectory = Split-Path -Path $script:lightSkillPath -Parent
        foreach ($referenceName in @(
                'runtime-contract.md',
                'csv-input.md',
                'language-mode.md',
                'powercli-standalone.md'
            )) {
            Test-Path -LiteralPath (Join-Path $skillDirectory "references\$referenceName") |
                Should -BeTrue
        }
    }
}
