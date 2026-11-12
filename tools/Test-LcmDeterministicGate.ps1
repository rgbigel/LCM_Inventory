<#
.SYNOPSIS
  Deterministic pre-gate structural and governance validator (Stage 0).
.DESCRIPTION
  Module: tools/Test-LcmDeterministicGate.ps1
  Purpose: Executes zero-latency structural validation on proposals prior to any
           System-1 or System-2 invocation. Validates YAML frontmatter, scope
           boundary rules, NTFS junction integrity, and elevation safety.
  Path: LCM_AI/tools/Test-LcmDeterministicGate.ps1
  Authors: rgbig, LCM_AI Engine
  Version: 10.2.1
  Date: 2026-11-12 08:50:00
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Path to proposal specification markdown file.')]
  [string]$ProposalPath = '',

  [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Path to repository being evaluated.')]
  [string]$RepositoryPath = '',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host '==========================================================================' -ForegroundColor Cyan
  Write-Host ' DETERMINISTIC PRE-GATE VALIDATOR (Test-LcmDeterministicGate)' -ForegroundColor Green
  Write-Host '==========================================================================' -ForegroundColor Cyan
  Write-Host 'SYNOPSIS:' -ForegroundColor Yellow
  Write-Host '  Zero-latency Stage 0 structural and governance gate.'
  Write-Host ''
  Write-Host 'USAGE:' -ForegroundColor Yellow
  Write-Host '  pwsh LCM_AI/tools/Test-LcmDeterministicGate.ps1 [-ProposalPath <file>] [-RepositoryPath <dir>] [-h]'
  Write-Host '==========================================================================' -ForegroundColor Cyan
  return
}

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$proposalId = ''
$scope = ''
$timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')

# ------------------------------------------------------------------------------
# 1. Proposal Structural & Frontmatter Validation
# ------------------------------------------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($ProposalPath)) {
  if (-not (Test-Path -LiteralPath $ProposalPath)) {
    $errors.Add("Proposal file not found: '$ProposalPath'")
  } else {
    $rawContent = Get-Content -LiteralPath $ProposalPath -Raw -Encoding UTF8
    if ($rawContent -match '(?s)```yaml\s*\r?\n(.*?)\r?\n```') {
      $yamlBlock = $matches[1]
      if ($yamlBlock -match '(?m)^(?:CRP-ID|Proposal-ID|BUG-ID):\s*(.+)$') {
        $proposalId = $matches[1].Trim()
      } else {
        $errors.Add('Missing required CRP-ID / Proposal-ID in YAML frontmatter.')
      }

      if ($yamlBlock -match '(?m)^Scope:\s*(.+)$') {
        $scope = $matches[1].Trim()
      } else {
        $errors.Add('Missing required Scope in YAML frontmatter.')
      }

      if (-not ($yamlBlock -match '(?m)^Title:\s*(.+)$')) {
        $errors.Add('Missing required Title in YAML frontmatter.')
      }

      if (-not ($yamlBlock -match '(?m)^(?:Status|Plan-State):\s*(.+)$')) {
        $errors.Add('Missing required Status/Plan-State in YAML frontmatter.')
      }
    } else {
      $errors.Add('Proposal missing required YAML frontmatter fence (```yaml ... ```).')
    }
  }
}

# ------------------------------------------------------------------------------
# 2. Scope & Boundary Validation
# ------------------------------------------------------------------------------
$workspaceRoot = 'D:\Git_Repositories'
if ([string]::IsNullOrWhiteSpace($RepositoryPath) -and -not [string]::IsNullOrWhiteSpace($scope)) {
  $RepositoryPath = Join-Path $workspaceRoot $scope
}

if (-not [string]::IsNullOrWhiteSpace($RepositoryPath)) {
  if (-not (Test-Path -LiteralPath $RepositoryPath)) {
    $errors.Add("Target repository path does not exist: '$RepositoryPath'")
  } else {
    # --------------------------------------------------------------------------
    # 3. NTFS Junction Integrity (.agents/rules)
    # --------------------------------------------------------------------------
    $rulesJunction = Join-Path $RepositoryPath '.agents\rules'
    $canonicalHub = Join-Path $workspaceRoot 'LCM_AI\.agents\rules'

    if ($RepositoryPath -ne (Join-Path $workspaceRoot 'LCM_AI')) {
      if (Test-Path -LiteralPath $rulesJunction) {
        $item = Get-Item -LiteralPath $rulesJunction -Force -ErrorAction SilentlyContinue
        if ($item.LinkType -ne 'Junction') {
          $errors.Add("Rules directory '$rulesJunction' is not an NTFS junction.")
        } else {
          $target = $item.Target
          if ($target -ne $canonicalHub -and $target -ne 'D:\Git_Repositories\LCM_AI\.agents\rules\') {
            $warnings.Add("Rules junction targets '$target' instead of canonical hub '$canonicalHub'.")
          }
        }
      } else {
        $errors.Add("Missing required rules junction: '$rulesJunction'")
      }
    }

    # --------------------------------------------------------------------------
    # 4. Elevation Governance Safety (RULE-ELEV-001..005)
    # --------------------------------------------------------------------------
    $isAdmin = $false
    try {
      $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
      $principal = [Security.Principal.WindowsPrincipal]::new($identity)
      $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
      $warnings.Add('Unable to evaluate elevation token.')
    }

    # Verify no unguarded elevated requirements unless explicitly authorized
    $adminConfigFile = Join-Path $workspaceRoot 'LCM_Inventory\data\adminmode.json'
    if (Test-Path -LiteralPath $adminConfigFile) {
      try {
        $adminMode = Get-Content -LiteralPath $adminConfigFile -Raw | ConvertFrom-Json
        if ($adminMode.enabled -and -not $isAdmin) {
          $warnings.Add('Workspace is in AdminMode, but current process is running in standard user context.')
        }
      } catch {
        $warnings.Add('Could not parse adminmode.json.')
      }
    }
  }
}

$passed = ($errors.Count -eq 0)

[PSCustomObject]@{
  Passed     = $passed
  ProposalId = $proposalId
  Scope      = $scope
  Errors     = @($errors)
  Warnings   = @($warnings)
  Timestamp  = $timestamp
}
