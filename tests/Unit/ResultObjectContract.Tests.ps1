#Requires -Version 7.4

<#
.SYNOPSIS
    Contract tests for the result-object schema required by
    docs/DEFINITION_OF_DONE.md.

.DESCRIPTION
    docs/DEFINITION_OF_DONE.md requires every public Get-* function to
    return PSCustomObject results carrying a PSTypeName, a VIServer
    property, a Timestamp property, and a RunId property. That requirement
    was previously enforced only by prose in AGENTS.md/DEFINITION_OF_DONE.md
    - scripts/Test-AgentCompliance.ps1 never actually inspected the objects
    a function returns, so a function could silently drift away from the
    schema without failing the build.

    This file asserts the contract against the REAL object a function
    returns (not a text search of the source file), for every public
    function that is expected to comply. Functions that are known,
    documented exceptions are called out explicitly via
    Set-ItResult -Skipped -Because, so the gap stays visible instead of
    silently passing or silently failing.
#>

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\ps-script-machine\ps-script-machine.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $script:mockVIServer = [PSCustomObject]@{
        Name      = 'vcenter.test.local'
        SessionId = 'test-session-id'
        Port      = 443
        Protocol  = 'https'
    }

    $script:mockVMHost = [PSCustomObject]@{
        Name   = 'esxi01.test.local'
        State  = 'Connected'
        Parent = 'cluster01'
    }

    $script:mockNetAdapter = [PSCustomObject]@{
        Name       = 'vmnic0'
        Driver     = 'nmlx5_core'
        LinkStatus = 'Up'
    }

    $script:mockCdpInfo = [PSCustomObject]@{
        Device  = 'switch01'
        Address = '192.168.1.1'
        Port    = 'GigabitEthernet1/0/1'
    }

    function New-MockEsxCli {
        param([object]$CdpInfo, [object[]]$Adapters)

        $cdpObj = [PSCustomObject]@{}
        $cdpObj | Add-Member -MemberType NoteProperty -Name '_cdpInfo' -Value $CdpInfo
        $cdpObj | Add-Member -MemberType ScriptMethod -Name 'get' -Value {
            param($name)
            if ($null -ne $this._cdpInfo) { return @($this._cdpInfo) }
            return @()
        }

        $nicObj = [PSCustomObject]@{}
        $nicObj | Add-Member -MemberType NoteProperty -Name '_adapters' -Value $Adapters
        $nicObj | Add-Member -MemberType ScriptMethod -Name 'list' -Value { return $this._adapters }
        $nicObj | Add-Member -MemberType NoteProperty -Name 'cdp' -Value $cdpObj

        $networkObj = [PSCustomObject]@{ nic = $nicObj }
        return [PSCustomObject]@{ network = $networkObj }
    }

    $script:mockEsxCli = New-MockEsxCli -CdpInfo $script:mockCdpInfo -Adapters @($script:mockNetAdapter)
}

Describe 'Result object contract (docs/DEFINITION_OF_DONE.md)' {
    Context 'Get-CdpNetworkInfo' {
        BeforeAll {
            Mock Get-VMHost { return @($script:mockVMHost) } -ModuleName 'ps-script-machine'
            Mock Get-EsxCli { return $script:mockEsxCli } -ModuleName 'ps-script-machine'
        }

        BeforeEach {
            $script:contractResult = @(Get-CdpNetworkInfo -VIServer $script:mockVIServer)[0]
        }

        It 'Should carry the ps-script-machine.CdpNetworkInfo PSTypeName' {
            $script:contractResult.PSObject.TypeNames | Should -Contain 'ps-script-machine.CdpNetworkInfo'
        }

        It 'Should expose a VIServer property' {
            $script:contractResult.PSObject.Properties.Name | Should -Contain 'VIServer'
            $script:contractResult.VIServer | Should -Not -BeNullOrEmpty
        }

        It 'Should expose a non-empty RunId property' {
            $script:contractResult.PSObject.Properties.Name | Should -Contain 'RunId'
            $script:contractResult.RunId | Should -Not -BeNullOrEmpty
        }

        It 'Should expose a Timestamp property' {
            $script:contractResult.PSObject.Properties.Name | Should -Contain 'Timestamp'
            $script:contractResult.Timestamp | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Get-VMHostNetworkInfo (known legacy exception)' {
        It 'Does not yet carry a PSTypeName - migration tracked for v2.0.0, see docs/ARCHITECTURE.md' {
            Set-ItResult -Skipped -Because 'Get-VMHostNetworkInfo predates the current result-object schema. Decision recorded in docs/ARCHITECTURE.md ("Known Deviations") and CHANGELOG.md ("Unreleased" / Planned): migrate to PSTypeName/VIServer/RunId/Timestamp in v2.0.0 (breaking change to the returned object shape only - scripts/tools/Export-CdpInformation.ps1 was modernized to consume Get-CdpNetworkInfo/Export-ModuleData and is no longer affected). This is not an open-ended exception; update this skip (and the two docs above) if the target version changes, and remove it once the migration ships.'
        }
    }
}
