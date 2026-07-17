#Requires -Version 7.4

<#
.SYNOPSIS
    Brief one-line description of the private helper function.

.DESCRIPTION
    Detailed description of the private helper function.
    This function is not exported to module users but is available for testing.

.PARAMETER VIServer
    The vCenter Server or ESXi host connection (VIServer object).

.PARAMETER Name
    The name of the object to process.

.EXAMPLE
    $result = Get-SomethingInternal -VIServer $session -Name 'obj01'

    Retrieves internal data for the specified object.

.OUTPUTS
    PSCustomObject

.NOTES
    This is a private function. It is not exported to module users.
#>
function Get-SomethingInternal {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [object]
        $VIServer,

        [Parameter(
            Mandatory = $true,
            Position = 1,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    process {
        try {
            $params = @{
                Server = $VIServer
                Name = $Name
                ErrorAction = 'Stop'
            }

            $obj = Get-SomeObject @params

            $result = [PSCustomObject]@{
                PSTypeName = 'ps-script-machine.SomethingInternal'
                VIServer   = [string]$VIServer
                Name       = $obj.Name
                Property1  = $obj.Property1
                Timestamp  = (Get-Date)
                RunId      = $script:LogRunId
            }

            Write-Output $result
        }
        catch {
            Write-Error "Failed to retrieve internal data for '$Name' on server $VIServer`: $_"
        }
    }
}