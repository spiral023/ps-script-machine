#Requires -Version 7.4

<#
.SYNOPSIS
    Brief one-line description of what the function does.

.DESCRIPTION
    Detailed description of the function, its purpose, and behavior.
    This is a read-only (Get-*) function template. It does not modify any
    vSphere configuration and therefore does not use SupportsShouldProcess.

    The function explicitly passes -Server to all PowerCLI cmdlets to avoid
    relying on the global $global:DefaultVIServer connection.

.PARAMETER VIServer
    The vCenter Server or ESXi host connection (VIServer object) to query.
    This must be an established connection obtained via Connect-VIServer.

.PARAMETER Name
    Optional: Filter by name. Supports wildcards.

.EXAMPLE
    $session = Connect-VIServerSession -Server 'vcenter.example.com' -Credential $cred
    Get-Something -VIServer $session

    Retrieves something for all objects on the specified vCenter.

.INPUTS
    VMware.VimAutomation.ViCore.Types.V1.VIServer.VIServer[]

.OUTPUTS
    PSCustomObject
    Structured object containing the retrieved information.

.NOTES
    Required vSphere permissions:
    - System.Read

    This function is read-only and does not modify any vSphere configuration.

.LINK
    https://github.com/spiral023/ps-script-machine
#>
function Get-Something {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [object[]]
        $VIServer,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name
    )

    begin {
        $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        foreach ($server in $VIServer) {
            try {
                $params = @{
                    Server = $server
                    ErrorAction = 'Stop'
                }
                if ($PSBoundParameters.ContainsKey('Name') -and $Name) {
                    $params['Name'] = $Name
                }

                $objects = Get-SomeObject @params

                foreach ($obj in $objects) {
                    $result = [PSCustomObject]@{
                        PSTypeName = 'ps-script-machine.Something'
                        VIServer   = [string]$server
                        Name       = $obj.Name
                        Property1  = $obj.Property1
                        Property2  = $obj.Property2
                        Timestamp  = (Get-Date)
                        RunId      = $script:LogRunId
                    }
                    $results.Add($result)
                }
            }
            catch {
                Write-Error "Failed to query objects for server $server`: $_"
            }
        }
    }

    end {
        $stopWatch.Stop()
        Write-Verbose "Operation completed in $($stopWatch.Elapsed.TotalSeconds) seconds."
        Write-Verbose "Total results: $($results.Count)"

        foreach ($result in $results) {
            Write-Output $result
        }
    }
}