@{
    # PSScriptAnalyzer configuration for high-quality PowerShell scripts
    # Documentation: https://github.com/PowerShell/PSScriptAnalyzer
    #
    # SCOPE (deliberate, see docs/ARCHITECTURE.md "PSScriptAnalyzer Scope"):
    # scripts/Invoke-Build.ps1 (and CI) run this settings file ONLY against
    # `src/ps-script-machine` - the module's shipped public/private code.
    # `scripts/` (interactive CLI wrappers that legitimately use Write-Host,
    # Read-Host, Format-Table for console UX), `examples/`, `templates/`,
    # and `tests/` are intentionally NOT covered by this strict, no-warnings
    # ruleset. Rules like PSAvoidUsingWriteHost are correct for a library's
    # public surface and wrong for a script whose entire job is console
    # output. This is a scope decision, not an oversight - do not "fix" it
    # by loosening these rules for src/, and do not assume a full-repo
    # PSScriptAnalyzer run should be zero-warning under this same file.

    Severity = @('Error', 'Warning')

    Rules = @{
        # --- Security ---
        PSAvoidUsingPlainTextForPassword = @{ Enable = $true }
        PSAvoidUsingWMICmdlet             = @{ Enable = $true }
        PSAvoidUsingInvokeExpression      = @{ Enable = $true }
        PSAvoidUsingWriteHost             = @{ Enable = $true }

        # --- Code Quality ---
        PSUseApprovedVerbs     = @{ Enable = $true }
        PSUseSingularNouns      = @{ Enable = $true }
        PSUseOutputTypeCorrectly = @{ Enable = $true }
        PSUseCorrectCasing      = @{ Enable = $true }

        # --- Formatting ---
        PSUseConsistentIndentation = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipelineItem'
            Kind                = 'space'
        }

        PSPlaceOpenBrace = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $false
        }

        PSPlaceCloseBrace = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $false
            NoEmptyLineBefore  = $true
        }

        # --- Best Practices ---
        PSUseDeclaredVarsMoreThanAssignments = @{ Enable = $true }
        PSAvoidUsingPositionalParameters      = @{ Enable = $true }
        PSReviewUnusedParameter              = @{ Enable = $true }
        PSMisleadingBacktick                 = @{ Enable = $true }
    }

    ExcludeRules = @(
        'PSMissingModuleManifestField',
        'PSUseBOMForUnicodeEncodedFile'
    )
}