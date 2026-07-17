# Get-CdpNetworkInfo

## Synopsis

Retrieves CDP (Cisco Discovery Protocol) network information from VMware ESXi hosts.

## Description

The Get-CdpNetworkInfo function connects to a vCenter Server or ESXi host and
retrieves CDP network information for all or specified hosts. CDP data includes
connected switch name, port, system name, and other network topology details.

This is a read-only function that does not modify any vSphere configuration.
It does not require SupportsShouldProcess because it makes no changes.

The function explicitly passes the -Server parameter to all PowerCLI cmdlets
to avoid relying on the global $global:DefaultVIServer connection. This ensures
correct behavior when multiple vCenter connections are active.

## Type

ReadOnly

## Parameters

| Parameter | Type | Mandatory | Description |
|-----------|------|-----------|-------------|
| VIServer | VIServer[] | Yes | vCenter connection |
| VMHost | string[] | No | Filter by host name |
| IncludeDetail | switch | No | Include detailed CDP info |

## Examples

```powershell
$session = Connect-VIServerSession -Server 'vcenter.example.com' -Credential $cred
Get-CdpNetworkInfo -VIServer $session
```

## Required vSphere Permissions

- System.Read (on the vCenter Server)
- Host.Config.Network (on the ESXi hosts or host folder)

## Notes

This function is read-only and does not modify any vSphere configuration.
See AGENTS.md for the complete Definition of Done.