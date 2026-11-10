<#
.SYNOPSIS
  Scaffolds standard tripartite specifications and installation runbooks for a repository.
.DESCRIPTION
  Module: New-RepositoryDocumentation
  Purpose: Generates standard DOX-compliant tripartite specification templates (Architecture.md,
           Requirements.md, Implementation.md per RULE-DOC-001 - 003) and 7-phase installation
           runbooks (install/Installation.md per RULE-DOC-004) on demand.
  Path: LCM_Inventory/tools/New-RepositoryDocumentation.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-11-10
.PARAMETER RepositoryName
  Name or folder path of the target repository.
.PARAMETER WorkspaceRoot
  Root directory containing repositories. Defaults to 'D:\Git_Repositories'.
.PARAMETER Authors
  Document authors string for DOX metadata headers. Defaults to 'Rolf, LCM_AI Engine'.
.PARAMETER Version
  Initial baseline version string. Defaults to '10.0.0'.
.PARAMETER IncludeInstall
  When specified, scaffolds install/Installation.md conforming to the 7-phase runbook standard.
.PARAMETER Force
  Overwrites existing documentation files if they already exist.
.PARAMETER Help
  Displays parameter reference and usage (-h / -Help / -?).
.EXAMPLE
  pwsh LCM_Inventory/tools/New-RepositoryDocumentation.ps1 -RepositoryName 'MyNewSubsystem' -IncludeInstall
  Scaffolds docs/ tripartite templates and install/Installation.md for MyNewSubsystem.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$RepositoryName,

  [Parameter(Mandatory = $false)]
  [string]$WorkspaceRoot = 'D:\Git_Repositories',

  [Parameter(Mandatory = $false)]
  [string]$Authors = 'Rolf, LCM_AI Engine',

  [Parameter(Mandatory = $false)]
  [string]$Version = '10.0.0',

  [switch]$IncludeInstall,

  [switch]$Force,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = '10.0.0'
$scriptName = 'New-RepositoryDocumentation'

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM REPOSITORY DOCUMENTATION SCAFFOLDER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Scaffolds standard tripartite specifications (Architecture.md, Requirements.md,"
  Write-Host "  Implementation.md) and 7-phase install/Installation.md (RULE-DOC-001 - 004)."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/New-RepositoryDocumentation.ps1 -RepositoryName <name> [-IncludeInstall] [-Force] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -RepositoryName <name>  : Target repository name or directory."
  Write-Host "  -WorkspaceRoot <dir>    : Workspace root path (Default: 'D:\Git_Repositories')."
  Write-Host "  -Authors <string>       : Authors metadata header value."
  Write-Host "  -Version <string>       : Baseline version (Default: '10.0.0')."
  Write-Host "  -IncludeInstall         : Scaffolds install/Installation.md with 7-phase lifecycle."
  Write-Host "  -Force                  : Overwrites existing files."
  Write-Host "  -h, -Help, -?           : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# Resolve target repository directory
$targetDir = $null
if ([System.IO.Path]::IsPathRooted($RepositoryName)) {
  $targetDir = $RepositoryName
  $RepositoryName = Split-Path $targetDir -Leaf
} else {
  $targetDir = Join-Path $WorkspaceRoot $RepositoryName
}

if (-not (Test-Path -LiteralPath $targetDir)) {
  Write-Host "Target repository directory does not exist: $targetDir. Creating directory..." -ForegroundColor Yellow
  New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

$docsDir = Join-Path $targetDir 'docs'
if (-not (Test-Path -LiteralPath $docsDir)) {
  New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
}

$today = (Get-Date).ToString("yyyy-MM-dd")

# 1. Architecture.md
$archPath = Join-Path $docsDir 'Architecture.md'
if (-not (Test-Path -LiteralPath $archPath) -or $Force) {
  $archContent = @"
# Architecture Specification: $RepositoryName

Module: docs/Architecture.md  
Purpose: End-user mental model, conceptual architecture, and operational topology for $RepositoryName.  
Path: $RepositoryName/docs/Architecture.md  
Authors: $Authors  
Version: $Version  
Status: Authoritative Standard  
Date: $today  

---

## 1. Executive Summary & Intent

Describes the system from the end-user and operator perspective complying with ``RULE-DOC-001``.

## 2. Conceptual Architecture & Mental Model

- **Core Abstractions**: Key functional domains and boundary separation.
- **User Entrypoints**: Interactive dashboards, cmd trampolines, and operational CLI scripts.

## 3. Workflow & Visual Topology

```mermaid
graph TD
    User["Operator / AI"] --> Entry["Command Entrypoint"]
    Entry --> Controller["Domain Controller"]
    Controller --> Engine["Execution Atom / Subsystem"]
```
"@
  [System.IO.File]::WriteAllText($archPath, $archContent, [System.Text.UTF8Encoding]::new($false))
  Write-Host "[CREATED] $archPath" -ForegroundColor Green
} else {
  Write-Host "[EXISTS] $archPath (Skipped; use -Force to overwrite)" -ForegroundColor DarkGray
}

# 2. Requirements.md
$reqPath = Join-Path $docsDir 'Requirements.md'
if (-not (Test-Path -LiteralPath $reqPath) -or $Force) {
  $reqContent = @"
# Requirements Specification: $RepositoryName

Module: docs/Requirements.md  
Purpose: Technical constraints, environmental prerequisites, and normative invariants for $RepositoryName.  
Path: $RepositoryName/docs/Requirements.md  
Authors: $Authors  
Version: $Version  
Status: Authoritative Standard  
Date: $today  

---

## 1. Environmental Prerequisites

- **Operating System**: Windows 11 / Windows Server 2022+.
- **PowerShell Version**: PowerShell 7+ (``pwsh.exe``).
- **Execution Elevation**: Non-elevated user session default (``RULE-ELEV-001``).

## 2. Technical Invariants & Safety Constraints

- **Invariant 1**: All scripts must enforce ``Set-StrictMode -Version Latest`` and ```$ErrorActionPreference = 'Stop'``.
- **Invariant 2**: Deterministic UTF-8 without BOM encoding and CRLF line endings.
- **Invariant 3**: Left-side null checks (``RULE-PS-023``).
"@
  [System.IO.File]::WriteAllText($reqPath, $reqContent, [System.Text.UTF8Encoding]::new($false))
  Write-Host "[CREATED] $reqPath" -ForegroundColor Green
} else {
  Write-Host "[EXISTS] $reqPath (Skipped; use -Force to overwrite)" -ForegroundColor DarkGray
}

# 3. Implementation.md
$implPath = Join-Path $docsDir 'Implementation.md'
if (-not (Test-Path -LiteralPath $implPath) -or $Force) {
  $implContent = @"
# Implementation Specification: $RepositoryName

Module: docs/Implementation.md  
Purpose: Code representation, file inventory, parameter contracts, and test traceability for $RepositoryName.  
Path: $RepositoryName/docs/Implementation.md  
Authors: $Authors  
Version: $Version  
Status: Authoritative Standard  
Date: $today  

---

## 1. Code & Module Topology

- **Tools Directory (``tools/``)**: User-executable commands and automated operational scripts.
- **Modules Directory (``modules/``)**: Reusable domain logic and service atoms.
- **Tests Directory (``tests/``)**: Automated Pester test coverage.

## 2. Parameter Signatures & Data Contracts

Catalogs exported functions, parameters, and return types.

## 3. Verification & Pester Traceability

- Every tool and module atom must have corresponding Pester coverage in ``tests/``.
"@
  [System.IO.File]::WriteAllText($implPath, $implContent, [System.Text.UTF8Encoding]::new($false))
  Write-Host "[CREATED] $implPath" -ForegroundColor Green
} else {
  Write-Host "[EXISTS] $implPath (Skipped; use -Force to overwrite)" -ForegroundColor DarkGray
}

# 4. Optional install/Installation.md
if ($IncludeInstall) {
  $installDir = Join-Path $targetDir 'install'
  if (-not (Test-Path -LiteralPath $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
  }
  $installPath = Join-Path $installDir 'Installation.md'
  if (-not (Test-Path -LiteralPath $installPath) -or $Force) {
    $installContent = @"
# $RepositoryName Operational Installation & Lifecycle Runbook

Module: install/Installation.md  
Purpose: Authoritative 7-phase operational installation, maintenance, and verification runbook for $RepositoryName.  
Path: $RepositoryName/install/Installation.md  
Authors: $Authors  
Version: $Version  
Status: Authoritative Standard  
Date: $today  

---

## Phase 1: Prerequisites & Environmental Dependencies
1. Windows 11 / Server 2022+.
2. PowerShell 7+ (``pwsh.exe``).
3. Least-privilege user execution default (``RULE-ELEV-001``).

## Phase 2: Target Destination Layout & Directory Topology
- Repository root: ``$targetDir``
- Separation of user entrypoints in ``Cmd/`` and tools in ``tools/``.

## Phase 3: Preflight System Health Checks
1. Verify PowerShell 7+ edition.
2. Verify git availability and working tree cleanliness.

## Phase 4: Step-by-Step Deployment & Configuration
1. Payload staging and junction linking.
2. Permission hardening.

## Phase 5: Post-Deployment Verification & Smoke Tests
1. Run automated Pester test suites: ``Invoke-Pester tests/``.

## Phase 6: Ongoing Servicing & Update Runbook
1. Maintenance procedures and version updates conforming to ``RULE-DOC-005``.

## Phase 7: Rollback & De-provisioning Procedures
1. Clean process termination and file removal instructions.
"@
    [System.IO.File]::WriteAllText($installPath, $installContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[CREATED] $installPath" -ForegroundColor Green
  } else {
    Write-Host "[EXISTS] $installPath (Skipped; use -Force to overwrite)" -ForegroundColor DarkGray
  }
}

Write-Host "Scaffolding completed for $RepositoryName." -ForegroundColor Cyan
