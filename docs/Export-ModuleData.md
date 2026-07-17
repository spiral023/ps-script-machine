# Export-ModuleData

## Synopsis

Exports module data to CSV and/or JSON format.

## Description

The Export-ModuleData function exports structured data to CSV and/or JSON
files. It ensures the output directory exists and returns the full path
of the created file(s).

This function separates result objects from exports, ensuring that the
caller always receives the file path(s) as output.

## Type

ReadOnly

## Parameters

| Parameter | Type | Mandatory | Description |
|-----------|------|-----------|-------------|
| Data | object[] | Yes | Data to export |
| OutputPath | string | Yes | Base path (without extension) |
| Format | string[] | Yes | Output format: CSV, JSON |
| Force | switch | No | Overwrite existing files |

## Examples

```powershell
$data = Get-CdpNetworkInfo -VIServer $session
Export-ModuleData -Data $data -OutputPath 'C:\Exports\cdp-info' -Format CSV, JSON
```

## Required vSphere Permissions

None. This function does not connect to vCenter.

## Notes

The output directory is created automatically if it does not exist.
The full output path is always returned and written to the verbose stream.
See AGENTS.md for the complete Definition of Done.