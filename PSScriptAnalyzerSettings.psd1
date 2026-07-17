@{
    # PSScriptAnalyzer configuration for high-quality PowerShell scripts
    # Documentation: https://github.com/PowerShell/PSScriptAnalyzer

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