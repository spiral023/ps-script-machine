# VMware PowerCLI Script Best Practices

**Version 1.0.0**
Custom - VMware Administrator
July 2026

> **Note:**
> This document is for AI agents and LLMs to follow when creating,
> generating, or refactoring PowerShell scripts for VMware vSphere
> automation. It is optimized for consistency and quality by AI-assisted
> workflows.

---

## Abstract

Comprehensive PowerShell scripting guide for VMware PowerCLI and vSphere automation. Contains 20+ rules across 8 categories, prioritized by impact from critical (credential handling, error management) to incremental (documentation). Each rule includes detailed explanations, real-world examples comparing incorrect vs. correct implementations, and specific guidance for automated code generation and refactoring.

---

## Table of Contents

1. [Security & Credentials](#1-security--credentials) — **CRITICAL**
   - 1.1 [Credential Handling](#11-credential-handling)
   - 1.2 [Avoid Plaintext Password Parameters](#12-avoid-plaintext-password-parameters)
   - 1.3 [Credential Disconnect & Cleanup](#13-credential-disconnect--cleanup)
2. [Error Handling & Robustness](#2-error-handling--robustness) — **CRITICAL**
   - 2.1 [ErrorActionPreference](#21-erroractionpreference)
   - 2.2 [Try/Catch/Finally for vCenter Operations](#22-trycatchfinally-for-vcenter-operations)
   - 2.3 [Connection State Check Before Queries](#23-connection-state-check-before-queries)
3. [PowerCLI Connection Management](#3-powercli-connection-management) — **HIGH**
   - 3.1 [Single Connect, Reuse Session](#31-single-connect-reuse-session)
   - 3.2 [Always Disconnect in Finally](#32-always-disconnect-in-finally)
   - 3.3 [PowerCLI Configuration for Automation](#33-powercli-configuration-for-automation)
4. [vSphere API & Data Retrieval](#4-vsphere-api--data-retrieval) — **HIGH**
   - 4.1 [Get-View for Advanced API Access](#41-get-view-for-advanced-api-access)
   - 4.2 [Bulk Queries Over One-by-One](#42-bulk-queries-over-one-by-one)
   - 4.3 [ExtensionData for Hidden Properties](#43-extensiondata-for-hidden-properties)
5. [PowerShell Code Quality](#5-powershell-code-quality) — **MEDIUM-HIGH**
   - 5.1 [Approved Verbs](#51-approved-verbs)
   - 5.2 [Parameter Attributes](#52-parameter-attributes)
   - 5.3 [Pipeline Support](#53-pipeline-support)
   - 5.4 [Strong Typing](#54-strong-typing)
6. [Testing with Pester](#6-testing-with-pester) — **MEDIUM**
   - 6.1 [Isolate Helper Functions](#61-isolate-helper-functions)
   - 6.2 [Mock External Dependencies](#62-mock-external-dependencies)
   - 6.3 [Test Edge Cases](#63-test-edge-cases)
7. [Output & Formatting](#7-output--formatting) — **MEDIUM**
   - 7.1 [CSV Encoding for German Excel](#71-csv-encoding-for-german-excel)
   - 7.2 [PSCustomObject for Structured Output](#72-pscustomobject-for-structured-output)
   - 7.3 [Write-Progress for Long Operations](#73-write-progress-for-long-operations)
8. [Documentation & Help](#8-documentation--help) — **LOW-MEDIUM**
   - 8.1 [Comment-Based Help](#81-comment-based-help)
   - 8.2 [Synopsis and Description](#82-synopsis-and-description)
   - 8.3 [Examples](#83-examples)
9. [State-Changing Operations](#9-state-changing-operations) — **CRITICAL**
   - 9.1 [SupportsShouldProcess](#91-supportsshouldprocess)
   - 9.2 [Read-Only by Default](#92-read-only-by-default)
   - 9.3 [Test-Get-Invoke Pattern](#93-test-get-invoke-pattern)
10. [Secret Management](#10-secret-management) — **HIGH**
    - 10.1 [SecretManagement Module](#101-secretmanagement-module)
    - 10.2 [No Hardcoded Secrets](#102-no-hardcoded-secrets)
11. [Modular Architecture](#11-modular-architecture) — **MEDIUM-HIGH**
    - 11.1 [Public vs Private Functions](#111-public-vs-private-functions)
    - 11.2 [Scripts as Wrappers](#112-scripts-as-wrappers)
    - 11.3 [Structured Output Only](#113-structured-output-only)

---

## 1. Security & Credentials

**Impact: CRITICAL**

Credential handling is the #1 security concern in vSphere automation. Hardcoded passwords or insecure credential handling can lead to credential leaks and unauthorized access.

### 1.1 Credential Handling

**Impact: CRITICAL (prevents credential leaks)**

Use `Get-Credential` or `PSCredential` objects for all authentication. Never hardcode passwords in scripts.

**Incorrect: hardcoded password**

```powershell
$password = "MySecret123!"
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("admin", $securePassword)
Connect-VIServer -Server vcenter.local -User admin -Password "MySecret123!"
```

**Correct: interactive credential prompt**

```powershell
$credential = Get-Credential -Message "vCenter-Anmeldung" -UserName "user@vsphere.local"
Connect-VIServer -Server $vCenter -Credential $credential
```

**Correct: PSCredential parameter**

```powershell
function Connect-Vcenter {
    param(
        [Parameter(Mandatory)]
        [string]$Server,

        [Parameter(Mandatory)]
        [PSCredential]$Credential
    )

    Connect-VIServer -Server $Server -Credential $Credential
}
```

### 1.2 Avoid Plaintext Password Parameters

**Impact: CRITICAL (prevents password exposure in logs)**

Never use `[string]` parameters for passwords. PSScriptAnalyzer rule `PSAvoidUsingPlainTextForPassword` enforces this.

**Incorrect: plaintext string parameter**

```powershell
function Connect-MyVcenter {
    param(
        [string]$Server,
        [string]$Password  # Exposed in command history, logs, and memory
    )
    # ...
}
```

**Correct: PSCredential parameter**

```powershell
function Connect-MyVcenter {
    param(
        [Parameter(Mandatory)]
        [string]$Server,

        [Parameter(Mandatory)]
        [PSCredential]$Credential
    )
    # ...
}
```

### 1.3 Credential Disconnect & Cleanup

**Impact: HIGH (prevents session leaks)**

Always disconnect from vCenter and clean up credentials after use.

**Incorrect: no cleanup**

```powershell
Connect-VIServer -Server $vCenter -Credential $credential
# ... operations ...
# Session stays open, credentials remain in memory
```

**Correct: cleanup in finally block**

```powershell
$viConnection = $null
try {
    $viConnection = Connect-VIServer -Server $vCenter -Credential $credential
    # ... operations ...
}
finally {
    if ($viConnection) {
        Disconnect-VIServer -Server $viConnection -Confirm:$false -ErrorAction SilentlyContinue
    }
}
```

---

## 2. Error Handling & Robustness

**Impact: CRITICAL**

Proper error handling prevents partial failures, silent data loss, and orphaned sessions.

### 2.1 ErrorActionPreference

**Impact: HIGH (controls error behavior)**

Set `$ErrorActionPreference = "Stop"` at the top of scripts to convert non-terminating errors to terminating errors, enabling try/catch handling.

**Incorrect: default behavior (Continue)**

```powershell
# Non-terminating errors are displayed but execution continues
Get-VMHost -Server $vCenter
# If this fails, the script continues with $null
$vmHosts | ForEach-Object { ... }
```

**Correct: Stop on error**

```powershell
$ErrorActionPreference = "Stop"
try {
    $vmHosts = Get-VMHost -Server $vCenter
}
catch {
    Write-Error "Failed to retrieve VMHosts: $($_.Exception.Message)"
    exit 1
}
```

### 2.2 Try/Catch/Finally for vCenter Operations

**Impact: CRITICAL (prevents orphaned sessions and silent failures)**

All vCenter operations must be wrapped in try/catch/finally blocks.

**Incorrect: no error handling**

```powershell
$vmHosts = Get-VMHost
foreach ($vmHost in $vmHosts) {
    $networkSystem = Get-View -Id $vmHost.ExtensionData.ConfigManager.NetworkSystem
    $networkHints = $networkSystem.QueryNetworkHint([string[]]@())
}
# If any host fails, the script crashes with no cleanup
```

**Correct: comprehensive error handling**

```powershell
try {
    $vmHosts = Get-VMHost | Sort-Object Name
    if (-not $vmHosts) {
        throw "No ESXi hosts found."
    }

    foreach ($vmHost in $vmHosts) {
        try {
            $networkSystem = Get-View -Id $vmHost.ExtensionData.ConfigManager.NetworkSystem
            $networkHints = $networkSystem.QueryNetworkHint([string[]]@())
        }
        catch {
            Write-Warning "Query failed for $($vmHost.Name): $($_.Exception.Message)"
            $results.Add([PSCustomObject]@{
                VMHost       = $vmHost.Name
                QueryStatus  = "Error"
                ErrorMessage = $_.Exception.Message
            })
        }
    }
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
}
finally {
    if ($viConnection) {
        Disconnect-VIServer -Server $viConnection -Confirm:$false -ErrorAction SilentlyContinue
    }
}
```

### 2.3 Connection State Check Before Queries

**Impact: HIGH (prevents errors on disconnected hosts)**

Check `ConnectionState` before running queries that require a connected host.

**Incorrect: query without state check**

```powershell
foreach ($vmHost in $vmHosts) {
    # Fails on disconnected/maintenance hosts
    $networkSystem = Get-View -Id $vmHost.ExtensionData.ConfigManager.NetworkSystem
    $networkHints = $networkSystem.QueryNetworkHint([string[]]@())
}
```

**Correct: check connection state first**

```powershell
foreach ($vmHost in $vmHosts) {
    if ($vmHost.ConnectionState -ne "Connected") {
        Write-Warning "$($vmHost.Name) is not connected (state: $($vmHost.ConnectionState)), skipping."
        $results.Add([PSCustomObject]@{
            VMHost              = $vmHost.Name
            HostConnectionState = $vmHost.ConnectionState
            QueryStatus         = "Skipped"
            ErrorMessage        = "Host not connected."
        })
        continue
    }
    # ... proceed with query ...
}
```

---

## 3. PowerCLI Connection Management

**Impact: HIGH**

Proper connection management prevents session leaks, improves performance, and ensures clean automation.

### 3.1 Single Connect, Reuse Session

**Impact: HIGH (avoids repeated authentication overhead)**

Connect to vCenter once and reuse the session for all operations.

**Incorrect: reconnecting per host**

```powershell
foreach ($vmHost in $vmHosts) {
    Connect-VIServer -Server $vCenter -Credential $credential
    # ... query host ...
    Disconnect-VIServer -Server $vCenter -Confirm:$false
}
```

**Correct: single connection**

```powershell
$viConnection = Connect-VIServer -Server $vCenter -Credential $credential
# All operations use this session
$vmHosts = Get-VMHost
foreach ($vmHost in $vmHosts) {
    # ... query host ...
}
# Disconnect once at the end
```

### 3.2 Always Disconnect in Finally

**Impact: CRITICAL (prevents session leaks)**

Always disconnect in a `finally` block to ensure cleanup even on errors.

**Incorrect: disconnect may not execute**

```powershell
$viConnection = Connect-VIServer -Server $vCenter -Credential $credential
# ... operations that might throw ...
Disconnect-VIServer -Server $viConnection -Confirm:$false
# If an error occurs above, disconnect never runs
```

**Correct: finally block**

```powershell
$viConnection = $null
try {
    $viConnection = Connect-VIServer -Server $vCenter -Credential $credential
    # ... operations ...
}
catch {
    Write-Error "Failed: $($_.Exception.Message)"
}
finally {
    if ($viConnection) {
        Disconnect-VIServer -Server $viConnection -Confirm:$false -ErrorAction SilentlyContinue
    }
}
```

### 3.3 PowerCLI Configuration for Automation

**Impact: MEDIUM (suppresses interactive prompts)**

Set PowerCLI configuration to avoid CEIP prompts and invalid certificate actions that block automation.

**Incorrect: default config may prompt**

```powershell
# Without configuration, PowerCLI may prompt for:
# - CEIP participation
# - Invalid certificate acceptance
Connect-VIServer -Server $vCenter -Credential $credential
```

**Correct: configure for automation**

```powershell
Set-PowerCLIConfiguration `
    -Scope Session `
    -InvalidCertificateAction Ignore `
    -ParticipateInCEIP $false `
    -Confirm:$false
```

---

## 4. vSphere API & Data Retrieval

**Impact: HIGH**

Efficient data retrieval patterns reduce script runtime and vCenter load.

### 4.1 Get-View for Advanced API Access

**Impact: HIGH (access properties not exposed by cmdlets)**

Use `Get-View` to access the vSphere API directly for properties not available in PowerCLI cmdlets.

**Example: QueryNetworkHint for CDP info**

```powershell
$networkSystem = Get-View -Id $vmHost.ExtensionData.ConfigManager.NetworkSystem
$networkHints = $networkSystem.QueryNetworkHint([string[]]@())

foreach ($hint in $networkHints) {
    $cdp = $hint.ConnectedSwitchPort
    if ($cdp) {
        $device = $cdp.DevId
        $port = $cdp.PortId
    }
}
```

### 4.2 Bulk Queries Over One-by-One

**Impact: HIGH (reduces vCenter API calls)**

Retrieve all objects at once instead of querying per-item.

**Incorrect: per-host cluster query**

```powershell
foreach ($vmHost in $vmHosts) {
    $cluster = Get-Cluster -VMHost $vmHost  # One API call per host
}
```

**Acceptable: query all clusters once**

```powershell
$allClusters = Get-Cluster
$clusterLookup = @{}
foreach ($cluster in $allClusters) {
    foreach ($host in $cluster.ExtensionData.Host) {
        $clusterLookup[$host.Value] = $cluster.Name
    }
}

foreach ($vmHost in $vmHosts) {
    $clusterName = $clusterLookup[$vmHost.Id]
}
```

### 4.3 ExtensionData for Hidden Properties

**Impact: MEDIUM (access full vSphere API objects)**

Use `.ExtensionData` to access properties not surfaced in the PowerCLI object model.

```powershell
$networkSystemRef = $vmHost.ExtensionData.ConfigManager.NetworkSystem
$networkSystem = Get-View -Id $networkSystemRef

$cpuMhz = $vmHost.ExtensionData.Hardware.CpuInfo.Hz
$numCpuCores = $vmHost.ExtensionData.Hardware.CpuInfo.NumCpuCores
$memoryBytes = $vmHost.ExtensionData.Hardware.MemorySize
```

---

## 5. PowerShell Code Quality

**Impact: MEDIUM-HIGH**

### 5.1 Approved Verbs

Use only approved verbs. Check with `Get-Verb`.

**Incorrect:**

```powershell
function Pull-VMHostInfo { ... }  # 'Pull' is not approved
```

**Correct:**

```powershell
function Get-VMHostInfo { ... }    # 'Get' is approved
```

### 5.2 Parameter Attributes

Use `[Parameter()]` attributes with `Mandatory`, `ValueFromPipeline`, etc.

**Correct:**

```powershell
function Get-HostInfo {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VMware.VimAutomation.ViCore.Types.V1.VMHost]$VMHost,

        [Parameter()]
        [string]$Cluster
    )
    # ...
}
```

### 5.3 Pipeline Support

Support pipeline input using `ValueFromPipeline` and `process` blocks.

**Correct:**

```powershell
function Get-HostCdp {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$VMHost
    )
    begin { $results = [System.Collections.Generic.List[object]]::new() }
    process {
        # ... query CDP for $VMHost ...
        $results.Add($result)
    }
    end { return $results }
}
# Usage: Get-VMHost | Get-HostCdp
```

### 5.4 Strong Typing

Use strong types for parameters and variables.

**Incorrect:**

```powershell
function Get-HostInfo {
    param($VMHost, $Name)
    $results = @()
}
```

**Correct:**

```powershell
function Get-HostInfo {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [int]$Timeout = 30
    )
    $results = [System.Collections.Generic.List[object]]::new()
}
```

---

## 6. Testing with Pester

**Impact: MEDIUM**

### 6.1 Isolate Helper Functions

Extract helper functions so they can be tested without a vCenter connection.

**Correct:**

```powershell
function Export-Windows1252Csv {
    param(
        [Parameter(Mandatory)][object[]]$InputObject,
        [Parameter(Mandatory)][string]$Path
    )
    $csvContent = $InputObject | ConvertTo-Csv -Delimiter ";" -NoTypeInformation
    [System.IO.File]::WriteAllLines($Path, $csvContent, [System.Text.Encoding]::GetEncoding(1252))
}
```

### 6.2 Mock External Dependencies

Mock all PowerCLI cmdlets in tests.

**Correct:**

```powershell
BeforeAll {
    Mock Get-VMHost { @(
        [PSCustomObject]@{ Name = "esx01.local"; ConnectionState = "Connected" }
    ) }
    Mock Connect-VIServer { $true }
    Mock Disconnect-VIServer { $true }
}
```

### 6.3 Test Edge Cases

Test null values, empty arrays, disconnected hosts, and error conditions.

```powershell
Describe "ConvertTo-CleanText" {
    It "Handles null" {
        ConvertTo-CleanText -Value $null | Should -Be ""
    }
    It "Handles empty string" {
        ConvertTo-CleanText -Value "" | Should -Be ""
    }
    It "Handles arrays" {
        ConvertTo-CleanText -Value @("a", "b") | Should -Be "a, b"
    }
}
```

---

## 7. Output & Formatting

**Impact: MEDIUM**

### 7.1 CSV Encoding for German Excel

Use Windows-1252 encoding for CSV files opened in German Excel.

**Correct:**

```powershell
function Export-Windows1252Csv {
    param(
        [Parameter(Mandatory)][object[]]$InputObject,
        [Parameter(Mandatory)][string]$Path
    )
    if ($PSVersionTable.PSEdition -eq "Core") {
        [System.Text.Encoding]::RegisterProvider(
            [System.Text.CodePagesEncodingProvider]::Instance
        )
    }
    $encoding = [System.Text.Encoding]::GetEncoding(1252)
    $csvContent = $InputObject | ConvertTo-Csv -Delimiter ";" -NoTypeInformation
    [System.IO.File]::WriteAllLines($Path, $csvContent, $encoding)
}
```

### 7.2 PSCustomObject for Structured Output

Use `[PSCustomObject]` for structured output.

**Correct:**

```powershell
$result = [PSCustomObject]@{
    vCenter         = $vCenter
    Cluster         = $clusterName
    VMHost          = $vmHost.Name
    PhysicalAdapter = $physicalAdapter.Name
    CDPDeviceID     = ConvertTo-CleanText $cdp.DevId
    QueryStatus     = "CDP-Daten gefunden"
}
```

### 7.3 Write-Progress for Long Operations

```powershell
$hostNumber = 0
foreach ($vmHost in $vmHosts) {
    $hostNumber++
    Write-Progress `
        -Activity "CDP-Informationen werden ausgelesen" `
        -Status "Host $hostNumber von $($vmHosts.Count): $($vmHost.Name)" `
        -PercentComplete (($hostNumber / $vmHosts.Count) * 100)
}
Write-Progress -Activity "CDP-Informationen werden ausgelesen" -Completed
```

---

## 8. Documentation & Help

**Impact: LOW-MEDIUM**

### 8.1 Comment-Based Help

Always include comment-based help.

```powershell
<#
.SYNOPSIS
    Liest CDP-Informationen aller ESXi-Hosts eines vCenters aus.

.DESCRIPTION
    Das Skript verbindet sich per PowerCLI mit einem vCenter und liest
    die CDP-Informationen aller physischen Netzwerkadapter ab.

.PARAMETER VCenter
    Der FQDN oder die IP-Adresse des vCenter-Servers.

.EXAMPLE
    .\Get-CdpNetworkInfo.ps1
    Startet das Skript im interaktiven Modus.

.NOTES
    Author: VMware Admin Team
    Requirements: VMware PowerCLI 12+
#>
```

### 8.2 Synopsis and Description

`.SYNOPSIS` should be one line. `.DESCRIPTION` should explain the full workflow.

### 8.3 Examples

Provide `.EXAMPLE` blocks that show real usage.

```powershell
<#
.EXAMPLE
    .\Get-CdpNetworkInfo.ps1 -VCenter vcenter.domain.local -OutputPath C:\Reports

    Verbindet mit dem angegebenen vCenter und speichert den CSV-Report
    im Ordner C:\Reports.
#>
```

---

## 9. State-Changing Operations

**Impact: CRITICAL**

State-changing operations must be protected with `-WhatIf`/`-Confirm` and follow a Test-Get-Invoke pattern.

### 9.1 SupportsShouldProcess

**Impact: CRITICAL (prevents accidental changes)**

Every function that modifies VMs, hosts, datastores, networks, or configurations must declare `SupportsShouldProcess`.

**Incorrect: no protection**

```powershell
function Stop-MyVM {
    param([string]$VMName)
    Stop-VM -VM $VMName  # No confirmation, no -WhatIf
}
```

**Correct: SupportsShouldProcess**

```powershell
function Stop-MyVM {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$VMName
    )

    if ($PSCmdlet.ShouldProcess($VMName, "Virtuelle Maschine herunterfahren")) {
        Stop-VM -VM $VMName -Confirm:$false
    }
}

# Now -WhatIf and -Confirm work automatically:
# Stop-MyVM -VMName "vm01" -WhatIf
# Stop-MyVM -VMName "vm01" -Confirm
```

### 9.2 Read-Only by Default

**Impact: HIGH (prevents unintended modifications)**

Functions should default to read-only. Separate analysis from remediation.

**Correct: three-function pattern**

```powershell
# 1. Analyze (read-only)
Test-VMwareConfiguration -Server $vCenter -Credential $cred

# 2. Plan (read-only)
Get-VMwareRemediationPlan -Server $vCenter -Credential $cred

# 3. Execute (state-changing, with -WhatIf)
Invoke-VMwareRemediation -Server $vCenter -Credential $cred -WhatIf
```

### 9.3 Test-Get-Invoke Pattern

**Impact: HIGH (structured remediation workflow)**

Follow a structured approach: Test → Get Plan → Invoke.

```powershell
# Phase 1: Collector (read-only)
$state = Get-VMwareCurrentState -Server $vCenter -Credential $cred

# Phase 2: Compare (read-only)
$comparison = Compare-VMwareConfiguration -Current $state -Expected $baseline

# Phase 3: Remediation plan (read-only)
$plan = Get-VMwareRemediationPlan -Comparison $comparison

# Phase 4: Execute (with -WhatIf first)
Invoke-VMwareRemediation -Plan $plan -WhatIf
# Then for real:
Invoke-VMwareRemediation -Plan $plan -Confirm
```

---

## 10. Secret Management

**Impact: HIGH**

Passwords must never be hardcoded or stored in config files. Use Microsoft SecretManagement.

### 10.1 SecretManagement Module

**Impact: HIGH (centralized, secure credential storage)**

Use `Microsoft.PowerShell.SecretManagement` for credential storage.

```powershell
# Register a vault (one-time setup)
Register-SecretVault -Name "VMwareVault" -ModuleName Microsoft.PowerShell.SecretStore

# Store a credential
$cred = Get-Credential -Message "vCenter-Admin"
Set-Secret -Name "VMware-vCenter-Production" -Secret $cred -Vault "VMwareVault"

# Retrieve a credential in scripts
$credential = Get-Secret -Name "VMware-vCenter-Production" -Vault "VMwareVault"
```

### 10.2 No Hardcoded Secrets

**Impact: CRITICAL (prevents credential leaks)**

Never hardcode passwords, API keys, or tokens.

**Incorrect:**

```powershell
$password = "P@ssw0rd123!"
$server = "vcenter-prod.firma.local"
```

**Correct:**

```powershell
$credential = Get-Secret -Name "VMware-vCenter-Production" -Vault "VMwareVault"
$server = $config.Production.vCenter  # from config file
```

---

## 11. Modular Architecture

**Impact: MEDIUM-HIGH**

Build a PowerShell module with Public/Private functions instead of isolated scripts.

### 11.1 Public vs Private Functions

**Impact: HIGH (reusability, testability)**

- **Public functions**: Cmdlets that administrators use (e.g., `Get-VMHostNetworkInfo`)
- **Private functions**: Internal helpers (e.g., `Connect-VIServerSession`, `Write-ScriptLog`, `Export-ReportCsv`)

```
src/ps-script-machine/
├── Public/    # Exported cmdlets
├── Private/   # Internal helpers
├── ps-script-machine.psd1  # Manifest
└── ps-script-machine.psm1  # Loader
```

### 11.2 Scripts as Wrappers

**Impact: MEDIUM (consistency, automation-ready)**

Scripts in `scripts/` should be thin wrappers around module functions.

**Incorrect: all logic in script**

```powershell
# 200+ lines of inline logic, untestable, not reusable
Connect-VIServer ...
Get-VMHost ...
# ... inline processing ...
Export-Csv ...
```

**Correct: wrapper around module**

```powershell
# scripts/Export-CdpInformation.ps1
Import-Module $modulePath
$results = Get-VMHostNetworkInfo -Server $VCenter -Credential $credential
$results | Export-ReportCsv -Path $csvPath
```

### 11.3 Structured Output Only

**Impact: MEDIUM (composable, pipeline-friendly)**

Functions must return structured objects, never formatted output.

**Incorrect: formatting inside function**

```powershell
function Get-HostInfo {
    # ...
    $results | Format-Table  # Breaks pipeline, consumer can't use data
    $results | Export-Csv   # Forces one output format
}
```

**Correct: structured output**

```powershell
function Get-HostInfo {
    # ...
    return [PSCustomObject]@{
        VMHost  = $vmHost.Name
        Adapter = $adapter.Name
        # ...
    }
}

# Consumer decides what to do:
$result = Get-HostInfo
$result | Format-Table
$result | Export-Csv
$result | ConvertTo-Json
```
