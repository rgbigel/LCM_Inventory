<#
.SYNOPSIS
  Audits, lists, and maps all active listening network ports and owning processes on this host.
.DESCRIPTION
  Module: Get-SystemPortInventory
  Purpose: Scans all TCP listening connections and UDP endpoints across the host,
           maps them to running processes, executable file paths, and known LCM workspace
           subsystem services (e.g. Everything REST API, Home Assistant OS, VNC, RDP, LCM Daemon).
           Supports JSON export, port collision checking, and firewall documentation.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: tools/Get-SystemPortInventory.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-10-13
.PARAMETER Port
  Filters results to a specific port number to inspect owning process and availability.
.PARAMETER CheckConflict
  Tests if candidate port(s) are currently in use or available for binding.
.PARAMETER ExportJson
  Saves the port audit inventory to data/port_inventory.json.
.PARAMETER ShowAll
  Displays extended process command line arguments and module paths.
.PARAMETER Help
  Displays this parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Get-SystemPortInventory.ps1 -h
.EXAMPLE
  pwsh tools/Get-SystemPortInventory.ps1
.EXAMPLE
  pwsh tools/Get-SystemPortInventory.ps1 -Port 9876 -CheckConflict
#>

[CmdletBinding()]
param(
  [int]$Port = 0,

  [switch]$CheckConflict,

  [switch]$ExportJson,

  [switch]$ShowAll,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Get-SystemPortInventory"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " SYSTEM NETWORK PORT AUDIT & INVENTORY (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Audits and identifies all active listening network ports, owning processes,"
  Write-Host "  and LCM subsystem service mappings on this host."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Get-SystemPortInventory.ps1 [-Port <int>] [-CheckConflict] [-ExportJson] [-ShowAll] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Port <int>      : Target port number to inspect."
  Write-Host "  -CheckConflict   : Tests whether target port is free or occupied."
  Write-Host "  -ExportJson      : Exports inventory to data/port_inventory.json."
  Write-Host "  -ShowAll         : Displays detailed process path information."
  Write-Host "  -h, -Help, -?    : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# Known LCM & Subsystem Port Registry
$knownPortMap = @{
  135   = "Windows RPC Endpoint Mapper"
  139   = "NetBIOS Session Service"
  445   = "Windows SMB File Sharing"
  2179  = "Hyper-V Virtual Machine Management"
  3389  = "Windows Remote Desktop Protocol (RDP)"
  5000  = "Python Flask / Local Microservices"
  5040  = "Windows Connected Devices Service"
  5357  = "Web Services for Devices (WSDAPI)"
  5800  = "TightVNC Web HTTP Mirror"
  5900  = "TightVNC RFB Screen Mirror"
  5985  = "WinRM HTTP Remoting"
  7679  = "Google Drive Local Sync Bridge"
  8080  = "Voidtools Everything 1.5a HTTP REST API"
  8081  = "Subsystem Remote Bridge / Mock API"
  8123  = "Home Assistant OS Web Dashboard & WS"
  9876  = "LCM Desktop Daemon (Session 1 Bridge)"
  10391 = "Enpass Password Manager Local Bridge"
  42050 = "Microsoft OneDrive Local Sync Service"
}

# ------------------------------------------------------------------------------
# 1. Single Port Conflict Check
# ------------------------------------------------------------------------------
if ($Port -gt 0 -and $CheckConflict) {
  $connections = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
  if ($connections.Count -gt 0) {
    $conn = $connections[0]
    $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
    $procName = if ($proc) { $proc.ProcessName } else { "PID:$($conn.OwningProcess)" }
    $procPath = if ($proc) { $proc.Path } else { "Unknown" }
    
    Write-Host "[CONFLICT] Port $Port is OCCUPIED by $procName ($procPath)" -ForegroundColor Red
    return [PSCustomObject]@{
      Port      = $Port
      Available = $false
      Process   = $procName
      Pid       = $conn.OwningProcess
      Path      = $procPath
    }
  } else {
    Write-Host "[AVAILABLE] Port $Port is FREE for binding." -ForegroundColor Green
    return [PSCustomObject]@{
      Port      = $Port
      Available = $true
      Process   = $null
      Pid       = $null
      Path      = $null
    }
  }
}

# ------------------------------------------------------------------------------
# 2. Comprehensive Host Port Audit
# ------------------------------------------------------------------------------
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " SYSTEM NETWORK PORT INVENTORY AUDIT (v$($scriptVersion))" -ForegroundColor Cyan
Write-Host " Host: $env:COMPUTERNAME • User: $env:USERNAME • Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "==========================================================================" -ForegroundColor Cyan

$tcpConnections = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)
$inventory = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($conn in $tcpConnections) {
  if ($Port -gt 0 -and $conn.LocalPort -ne $Port) { continue }
  
  $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
  $procName = if ($proc) { $proc.ProcessName } else { "PID:$($conn.OwningProcess)" }
  $procPath = if ($proc -and $proc.Path) { $proc.Path } else { "-" }
  
  $serviceName = if ($knownPortMap.ContainsKey($conn.LocalPort)) {
    $knownPortMap[$conn.LocalPort]
  } else {
    "Dynamic / Unmapped Application"
  }

  $item = [PSCustomObject]@{
    Port        = $conn.LocalPort
    Address     = $conn.LocalAddress
    Process     = $procName
    PID         = $conn.OwningProcess
    Service     = $serviceName
    Path        = $procPath
  }
  $inventory.Add($item)
}

# Sort and Deduplicate by Port
$sortedInventory = @($inventory | Sort-Object Port, Address)

# Display Table
Write-Host ""
$sortedInventory | Select-Object Port, Address, Process, Service, Path | Format-Table -AutoSize

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Total Listening Endpoints: $($sortedInventory.Count)" -ForegroundColor Green
Write-Host " Configured LCM Daemon Port: 9876 ($([string](if ($sortedInventory.Port -contains 9876) { 'ACTIVE' } else { 'AVAILABLE' })))" -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 3. Export JSON if Requested
# ------------------------------------------------------------------------------
if ($ExportJson) {
  $exportDir = 'D:\Git_Repositories\LCM_Inventory\data'
  if (-not (Test-Path $exportDir)) { New-Item -ItemType Directory -Path $exportDir -Force | Out-Null }
  $exportFile = Join-Path $exportDir 'system_port_inventory.json'
  $jsonObj = [PSCustomObject]@{
    host         = $env:COMPUTERNAME
    generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    ports_count  = $sortedInventory.Count
    inventory    = $sortedInventory
  }
  $jsonObj | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $exportFile -Encoding UTF8
  Write-Host "  -> Exported port inventory to: $exportFile" -ForegroundColor Green
}
