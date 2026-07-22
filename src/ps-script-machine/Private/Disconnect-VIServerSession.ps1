#Requires -Version 7.4

<#
.SYNOPSIS
    Safely disconnects a vCenter/ESXi session.

.DESCRIPTION
    The Disconnect-VIServerSession function disconnects a VIServer session that
    was opened by Connect-VIServerSession.  It only disconnects sessions that
    the module itself opened (tracked in $script:ModuleSessions), leaving
    externally-created sessions untouched.

    This prevents accidental disconnection of sessions that the caller opened
    independently and may still need.

    Errors are suppressed (SilentlyContinue) so that this function can be safely
    used in finally blocks without causing secondary failures.

.PARAMETER Connection
    The VIServer connection object returned by Connect-VIServerSession.

.EXAMPLE
    Disconnect-VIServerSession -Connection $viConnection

    Disconnects the session if it was opened by the module.

.OUTPUTS
    None

.NOTES
    This is a private function. It is not exported to the module user.
    Only sessions opened by Connect-VIServerSession are disconnected.
#>
function Disconnect-VIServerSession {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [object]
        $Connection
    )

    if ($null -eq $Connection -or $Connection -eq '') {
        return
    }

    # Determine the session key for tracking lookup
    $serverName = if ($Connection.Name) {
        $Connection.Name
    }
    else {
        [string]$Connection
    }
    $sessionId = if ($Connection.SessionId) {
        $Connection.SessionId
    }
    else {
        ''
    }
    $sessionKey = "${serverName}:${sessionId}"

    # Only disconnect sessions that were opened by this module
    if ($script:ModuleSessions.Contains($sessionKey)) {
        try {
            Disconnect-VIServer -Server $Connection -Confirm:$false -ErrorAction SilentlyContinue
            Write-Verbose "Disconnected module session: $serverName"
        }
        catch {
            # Suppress errors in cleanup - this is called from finally blocks
            Write-Verbose "Error disconnecting $serverName`: $_"
        }
        finally {
            $null = $script:ModuleSessions.Remove($sessionKey)
        }
    }
    else {
        Write-Verbose "Session $serverName was not opened by this module. Skipping disconnect."
    }
}