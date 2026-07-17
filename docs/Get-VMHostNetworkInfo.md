# Get-VMHostNetworkInfo

## Synopsis

Liest CDP-Informationen aller physischen Netzwerkadapter von ESXi-Hosten aus.

## Description

Verbindet sich per PowerCLI mit einem vCenter, liest alle ESXi-Hosts (oder eine
Teilmenge) aus, ruft Network-Hints (CDP/LLDP) für alle physischen Adapter ab
und gibt strukturierte PSCustomObject-Ergebnisse zurück.

Die Funktion führt ausschließlich Leseoperationen durch (read-only).

## Type

ReadOnly

## Parameters

| Parameter | Type | Mandatory | Description |
|-----------|------|-----------|-------------|
| Server | string | Yes | vCenter FQDN |
| Credential | PSCredential | Yes | vCenter credentials |
| VMHost | string[] | No | Filter by host name |
| Cluster | string[] | No | Filter by cluster name |

## Examples

```powershell
$cred = Get-Credential -Message "vCenter-Anmeldung"
Get-VMHostNetworkInfo -Server "vcenter.local" -Credential $cred
```

## Required vSphere Permissions

- System.Read
- Host.Config.Network

## Notes

Die Funktion führt ausschließlich Leseoperationen durch.
See AGENTS.md for the complete Definition of Done.