#Requires -Version 7.4

<#
.SYNOPSIS
    Establishes a PowerCLI connection to a vCenter Server or ESXi host.

.DESCRIPTION
    The Connect-VIServerSession function creates a managed PowerCLI connection
    to a vCenter Server or ESXi host using PSCredential. It returns the VIServer
    object which can be passed to other module functions via the -Server parameter.

    This function does NOT modify the global $global:DefaultVIServer state in a
    way that other functions depend on. All module functions explicitly accept
    and use the -Server parameter.

    Sessions opened by this function are tracked in the module-level
    $script:ModuleSessions set.  Disconnect-VIServerSession only disconnects
    sessions that were opened by this function, leaving externally-created
    sessions untouched.

    Certificate validation is NOT disabled. If the server uses self-signed
    certificates, set the PowerCLI configuration in the process or session scope
    before calling this function:
    Set-PowerCLIConfiguration -InvalidCertificateAction 'Ignore' -Scope Session

.PARAMETER Server
    The FQDN or IP address of the vCenter Server or ESXi host.

.PARAMETER Credential
    A PSCredential object containing the username and password.
    Use Get-Credential or Microsoft.PowerShell.SecretManagement to obtain this.

.PARAMETER Port
    The port to connect to. Default is 443.

.PARAMETER Protocol
    The protocol to use. Default is 'https'.

.EXAMPLE
    $cred = Get-Credential
    $session = Connect-VIServerSession -Server 'vcenter.example.com' -Credential $cred

    Connects to vcenter.example.com using the provided credentials.

.EXAMPLE
    # Using SecretManagement
    $cred = Get-Secret -Name 'vcenter-prod' -Vault 'MyVault' -ErrorAction Stop
    $session = Connect-VIServerSession -Server 'vcenter.example.com' -Credential $cred

    Connects using credentials from a SecretManagement vault.

.OUTPUTS
    VMware.VimAutomation.ViCore.Types.V1.VIServer.VIServer

.NOTES
    This is a private function. It is not exported to the module user but is
    available for testing purposes via InModuleScope.

    Security notes:
    - Credentials are never stored in plain text.
    - Credentials are never logged.
    - The connection string is not logged with credentials.
    - Certificate validation is never silently disabled.
    - Sessions opened here are tracked for safe cleanup.
#>
function Connect-VIServerSession {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $Server,

        [Parameter(
            Mandatory = $true,
            Position = 1,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateRange(1, 65535)]
        [int]
        $Port = 443,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateSet('https', 'http')]
        [string]
        $Protocol = 'https'
    )

    begin {
        Write-Verbose "Connecting to VIServer: $Server on port $Port via $Protocol"
    }

    process {
        try {
            $connectParams = @{
                Server       = $Server
                Credential   = $Credential
                Port         = $Port
                Protocol     = $Protocol
                ErrorAction  = 'Stop'
            }

            $session = Connect-VIServer @connectParams

            if (-not $session) {
                throw "Failed to connect to $Server. No session object returned."
            }

            # Track this session as module-opened for safe cleanup
            $sessionKey = "${Server}:$($session.SessionId)"
            $null = $script:ModuleSessions.Add($sessionKey)

            Write-Verbose "Successfully connected to $Server. Session ID: $($session.SessionId)"

            # Return the session object without logging credentials
            return $session
        }
        catch {
            $errorMessage = "Failed to connect to VIServer '$Server': $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Exception $_.Exception -Category ConnectionError
            return $null
        }
    }

    end {
        # Nothing to clean up here; the session is returned for the caller to manage
    }
}