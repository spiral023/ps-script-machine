#Requires -Version 7.4

<#
.SYNOPSIS
    Writes structured log entries for module operations.

.DESCRIPTION
    The Write-ModuleLog function provides a reusable logging component that
    writes structured log entries in JSON format. It supports Information,
    Warning, Error, and Debug log levels.

    Each log entry includes:
    - Timestamp (UTC ISO 8601)
    - Run ID (unique per module import)
    - Target vCenter (if applicable)
    - Affected resource (if applicable)
    - Message
    - Log level
    - Optional additional data

    Logs can optionally be written to a log file in addition to the console.

    Sensitive data is automatically redacted from log messages and data fields.
    The following patterns are redacted:
    - Passwords (password=..., passwd=..., ...)
    - API keys (apikey=..., api_key=..., ...)
    - Secrets (secret=..., ...)
    - Tokens (token=..., ...)
    - Bearer tokens (Bearer ...)
    - Connection strings with embedded credentials

    Log files are written with UTF-8 encoding (no BOM) for maximum compatibility.

.PARAMETER Message
    The log message.

.PARAMETER Level
    The log level. Valid values: Information, Warning, Error, Debug.
    Default: Information.

.PARAMETER VIServer
    The target vCenter Server name or object (optional).

.PARAMETER Resource
    The affected resource name (optional).

.PARAMETER Data
    Additional data to include in the log entry (optional).
    This should be a hashtable or object that can be converted to JSON.

.PARAMETER LogFile
    The path to a log file. If specified, the log entry is appended to this file.
    The directory must exist and be writable.

.PARAMETER RunId
    The run ID. If not specified, the module-level $script:LogRunId is used.

.EXAMPLE
    Write-ModuleLog -Message "Starting CDP retrieval" -Level Information -VIServer 'vcenter01'

    Writes an information log entry to the console.

.EXAMPLE
    Write-ModuleLog -Message "Host not reachable" -Level Warning -VIServer 'vcenter01' -Resource 'esxi01' -LogFile 'C:\Logs\module.log'

    Writes a warning log entry to the console and appends it to the log file.

.OUTPUTS
    None. This function writes to the console and optionally to a log file.

.NOTES
    This is a private function used internally by the module.
    Logs are written in JSON format for machine readability.
    Sensitive data is automatically redacted before logging.
    Log files use UTF-8 encoding (no BOM).
#>
function Write-ModuleLog {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Information', 'Warning', 'Error', 'Debug')]
        [string]
        $Level = 'Information',

        [Parameter(Mandatory = $false)]
        [string]
        $VIServer,

        [Parameter(Mandatory = $false)]
        [string]
        $Resource,

        [Parameter(Mandatory = $false)]
        [object]
        $Data,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LogFile,

        [Parameter(Mandatory = $false)]
        [string]
        $RunId
    )

    # Use module-level RunId if not specified
    if (-not $RunId) {
        $RunId = $script:LogRunId
    }

    # Redact sensitive data from the message
    $redactedMessage = Invoke-LogRedaction -Value $Message

    # Redact sensitive data from VIServer (in case it contains credentials)
    $redactedVIServer = Invoke-LogRedaction -Value $VIServer

    # Redact sensitive data from Resource
    $redactedResource = Invoke-LogRedaction -Value $Resource

    # Build the log entry
    $logEntry = [ordered]@{
        Timestamp = (Get-Date).ToUniversalTime().ToString('o')
        Level     = $Level
        RunId     = $RunId
        VIServer  = $redactedVIServer
        Resource  = $redactedResource
        Message   = $redactedMessage
    }

    # Add optional data (with redaction)
    if ($Data) {
        $redactedData = Invoke-LogDataRedaction -Data $Data
        $logEntry['Data'] = $redactedData
    }

    # Convert to JSON
    $jsonLog = $logEntry | ConvertTo-Json -Compress -Depth 10

    # Write to console based on level
    switch ($Level) {
        'Information' {
            Write-Information $jsonLog -InformationAction Continue
        }
        'Warning' {
            Write-Warning $jsonLog
        }
        'Error' {
            # Use Write-Error with ErrorAction to allow caller control
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new($jsonLog),
                'ModuleLogError',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $null
            )
            $PSCmdlet.WriteError($errorRecord)
        }
        'Debug' {
            Write-Debug $jsonLog
        }
    }

    # Write to log file if specified (UTF-8, no BOM, thread-safe)
    if ($LogFile) {
        try {
            $logDir = Split-Path -Path $LogFile -Parent
            if ($logDir -and -not (Test-Path -Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            # Use UTF-8 encoding without BOM for maximum compatibility
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            # Use a Mutex for thread-safe file writes
            $mutexName = 'ps-script-machine-log-' + ($LogFile -replace '[^A-Za-z0-9]', '')
            $mutex = [System.Threading.Mutex]::new($false, $mutexName)
            try {
                $null = $mutex.WaitOne(5000)
                [System.IO.File]::AppendAllText($LogFile, "$jsonLog`n", $utf8NoBom)
            }
            finally {
                $mutex.ReleaseMutex()
                $mutex.Dispose()
            }
        }
        catch {
            Write-Warning "Failed to write to log file '$LogFile': $_"
        }
    }
}

# Internal helper: Redact sensitive patterns from a string value
function script:Invoke-LogRedaction {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }

    $redacted = $Value

    # Redact password=..., passwd=..., pwd=...
    $redacted = $redacted -replace '(?i)(password|passwd|pwd)\s*=\s*[''"][^''"]*[''"]', '$1=***REDACTED***'
    $redacted = $redacted -replace '(?i)(password|passwd|pwd)\s*=\s*[^\s;]+', '$1=***REDACTED***'

    # Redact apikey=..., api_key=...
    $redacted = $redacted -replace '(?i)(api[_-]?key)\s*=\s*[''"][^''"]*[''"]', '$1=***REDACTED***'
    $redacted = $redacted -replace '(?i)(api[_-]?key)\s*=\s*[^\s;]+', '$1=***REDACTED***'

    # Redact secret=...
    $redacted = $redacted -replace '(?i)secret\s*=\s*[''"][^''"]*[''"]', 'secret=***REDACTED***'
    $redacted = $redacted -replace '(?i)secret\s*=\s*[^\s;]+', 'secret=***REDACTED***'

    # Redact token=...
    $redacted = $redacted -replace '(?i)token\s*=\s*[''"][^''"]*[''"]', 'token=***REDACTED***'
    $redacted = $redacted -replace '(?i)token\s*=\s*[^\s;]+', 'token=***REDACTED***'

    # Redact Bearer tokens
    $redacted = $redacted -replace '(?i)bearer\s+[A-Za-z0-9._-]+', 'Bearer ***REDACTED***'

    # Redact connection strings with embedded credentials
    # e.g., https://user:pass@host
    $redacted = $redacted -replace '(?i)(https?|ftp)://[^:]+:[^@]+@', '$1://***REDACTED***@'

    return $redacted
}

# Internal helper: Redact sensitive data from structured Data objects
function script:Invoke-LogDataRedaction {
    param([object]$Data)

    if ($null -eq $Data) {
        return $null
    }

    if ($Data -is [string]) {
        return (Invoke-LogRedaction -Value $Data)
    }

    if ($Data -is [hashtable] -or $Data -is [System.Collections.IDictionary]) {
        $redacted = @{}
        foreach ($key in $Data.Keys) {
            $keyStr = [string]$key
            $value = $Data[$key]
            if ($keyStr -match '(?i)^(password|passwd|pwd|secret|api[_-]?key|token|credential)$') {
                $redacted[$key] = '***REDACTED***'
            }
            elseif ($value -is [string]) {
                $redacted[$key] = (Invoke-LogRedaction -Value $value)
            }
            else {
                $redacted[$key] = $value
            }
        }
        return $redacted
    }

    if ($Data -is [PSCustomObject]) {
        $redacted = [PSCustomObject]@{}
        foreach ($prop in $Data.PSObject.Properties) {
            $name = $prop.Name
            $value = $prop.Value
            if ($name -match '(?i)^(password|passwd|pwd|secret|api[_-]?key|token|credential)$') {
                $redacted | Add-Member -MemberType NoteProperty -Name $name -Value '***REDACTED***'
            }
            elseif ($value -is [string]) {
                $redacted | Add-Member -MemberType NoteProperty -Name $name -Value (Invoke-LogRedaction -Value $value)
            }
            else {
                $redacted | Add-Member -MemberType NoteProperty -Name $name -Value $value
            }
        }
        return $redacted
    }

    return $Data
}