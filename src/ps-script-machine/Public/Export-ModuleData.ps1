#Requires -Version 7.4

<#
.SYNOPSIS
    Exports module data to CSV and/or JSON format.

.DESCRIPTION
    The Export-ModuleData function exports structured data to CSV and/or JSON
    files. It ensures the output directory exists and returns the full path
    of the created file(s).

    This function separates result objects from exports, ensuring that the
    caller always receives the file path(s) as output.

.PARAMETER Data
    The data to export. This should be an array of objects or a single object.

.PARAMETER OutputPath
    The base path for the output file (without extension).
    The function will append .csv or .json based on the format.

.PARAMETER Format
    The output format(s). Valid values: CSV, JSON.
    Can specify both to export to both formats.

.PARAMETER Force
    If specified, overwrites existing files without prompting.

.EXAMPLE
    $data = Get-CdpNetworkInfo -VIServer $session
    Export-ModuleData -Data $data -OutputPath 'C:\Exports\cdp-info' -Format CSV, JSON

    Exports the CDP data to both CSV and JSON files.

.EXAMPLE
    $data = Get-CdpNetworkInfo -VIServer $session
    $paths = Export-ModuleData -Data $data -OutputPath 'C:\Exports\cdp-info' -Format JSON -Force

    Exports the CDP data to JSON, overwriting any existing file.

.OUTPUTS
    System.String[]
    The full paths of the created file(s).

.NOTES
    The output directory is created automatically if it does not exist.
    The full output path is always returned and written to the verbose stream.
#>
function Export-ModuleData {
    [CmdletBinding(SupportsShouldProcess = $false)]
    [OutputType([string[]])]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true
        )]
        [AllowEmptyCollection()]
        [object[]]
        $Data,

        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $OutputPath,

        [Parameter(
            Mandatory = $true,
            Position = 2
        )]
        [ValidateSet('CSV', 'JSON', IgnoreCase = $false)]
        [string[]]
        $Format,

        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )

    begin {
        $createdFiles = [System.Collections.Generic.List[string]]::new()
        $collectedData = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($item in $Data) {
            $collectedData.Add($item)
        }
    }

    end {
        if ($collectedData.Count -eq 0) {
            Write-Warning "No data to export."
            return
        }

        foreach ($fmt in $Format) {
            $extension = $fmt.ToLower()
            $filePath = "$OutputPath.$extension"
            $fileDir = Split-Path -Path $filePath -Parent

            # Create directory if needed
            if ($fileDir -and -not (Test-Path -Path $fileDir)) {
                try {
                    New-Item -Path $fileDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    Write-Verbose "Created directory: $fileDir"
                }
                catch {
                    Write-Error "Failed to create directory '$fileDir': $_"
                    continue
                }
            }

            # Check for existing file
            if ((Test-Path -Path $filePath) -and -not $Force) {
                Write-Warning "File already exists: $filePath. Use -Force to overwrite."
                continue
            }

            try {
                switch ($fmt) {
                    'CSV' {
                        $collectedData | Export-Csv -Path $filePath -NoTypeInformation -Force:$Force -ErrorAction Stop
                    }
                    'JSON' {
                        $collectedData | ConvertTo-Json -Depth 10 -ErrorAction Stop | Set-Content -Path $filePath -Force:$Force -ErrorAction Stop
                    }
                }

                $createdFiles.Add($filePath)
                Write-Verbose "Exported $fmt data to: $filePath"
            }
            catch {
                Write-Error "Failed to export $fmt data to '$filePath': $_"
            }
        }

        # Output the created file paths
        if ($createdFiles.Count -gt 0) {
            Write-Output $createdFiles.ToArray()
        }
    }
}