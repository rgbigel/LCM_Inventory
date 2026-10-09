<#
.SYNOPSIS
  Orchestrates complete Gemini AI context synchronization, rule export, knowledge mirroring, and inbox intake.
.DESCRIPTION
  Module: tools/Update-Gemini.ps1
  Purpose: Executes the full Gemini AI integration pipeline:
           1. Consolidates all 17+ LCM governance policies via Export-LCMRules.ps1.
           2. Mirrors workspace repository code and tripartite docs to Google Drive (D:\GDrive\LCM)
              with .txt normalization via Sync-LCMResearchSnapshot.ps1.
           3. Ingests instructions and bug reports from D:\GDrive\LCM\INBOX via Sync-GeminiInbox.ps1.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: LCM_Inventory/tools/Update-Gemini.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 7.2.0
  Date: 2026-09-25
.PARAMETER Force
  Forces a full clean export of knowledge base files.
.PARAMETER ToClipboard
  Copies the consolidated governance rules to clipboard for instant pasting.
.PARAMETER Help
  Displays this command syntax and parameter reference (-h / -Help / -?).
.EXAMPLE
  updategemini
.EXAMPLE
  pwsh tools/Update-Gemini.ps1 -ToClipboard
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Forces a full clean export of knowledge base files')]
  [switch]$Force,

  [Parameter(Mandatory = $false, HelpMessage = 'Copies the consolidated governance rules to clipboard')]
  [Alias('c', 'CopyToClipboard')]
  [switch]$ToClipboard,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "1.0.0"
$scriptName = "Update-Gemini"
$workspaceRoot = 'D:\Git_Repositories'
$lcdInternal = Join-Path $workspaceRoot 'LCM_Inventory\tools'

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " GEMINI AI CONSOLIDATED CONTEXT & GOVERNANCE PIPELINE (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Synchronizes rules, knowledge base, and inbox queue for Gemini AI integration."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  updategemini [-Force] [-ToClipboard] [-h]"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " GEMINI AI CONSOLIDATED CONTEXT & GOVERNANCE PIPELINE (v$($scriptVersion))" -ForegroundColor Cyan
Write-Host " Workspace : $workspaceRoot"
Write-Host " Timestamp : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "==========================================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. Consolidate Authoritative Governance Rules
# ------------------------------------------------------------------------------
Write-Host "`n[1/3] Consolidating & Exporting Authoritative LCM Rules..." -ForegroundColor Yellow
$exportRulesScript = Join-Path $lcdInternal 'Export-LCMRules.ps1'
if (Test-Path -LiteralPath $exportRulesScript) {
  $clipArg = if ($ToClipboard) { "-ToClipboard" } else { "" }
  if ($ToClipboard) {
    & $exportRulesScript -ToClipboard
  } else {
    & $exportRulesScript
  }
} else {
  Write-Warning "Export-LCMRules.ps1 not found in $lcdInternal"
}

# ------------------------------------------------------------------------------
# 2. Mirror Workspace Knowledge Base to Google Drive with .txt Normalization
# ------------------------------------------------------------------------------
Write-Host "`n[2/3] Mirroring Workspace Knowledge Base Snapshot to Google Drive (D:\GDrive\LCM)..." -ForegroundColor Yellow
$syncSnapshotScript = Join-Path $lcdInternal 'Sync-LCMResearchSnapshot.ps1'
if (-not (Test-Path -LiteralPath $syncSnapshotScript)) {
  $syncSnapshotScript = Join-Path $workspaceRoot 'tools\Sync-LCMResearchSnapshot.ps1'
}

if (Test-Path -LiteralPath $syncSnapshotScript) {
  if ($Force) {
    & $syncSnapshotScript -Force
  } else {
    & $syncSnapshotScript
  }
} else {
  Write-Warning "Sync-LCMResearchSnapshot.ps1 not found in $lcdInternal or tools"
}

# ------------------------------------------------------------------------------
# 3. Synchronize Gemini Google Drive Inbox Queue
# ------------------------------------------------------------------------------
Write-Host "`n[3/4] Synchronizing Gemini Google Drive Inbox Queue (D:\GDrive\LCM\INBOX)..." -ForegroundColor Yellow
$syncInboxScript = Join-Path $lcdInternal 'Sync-GeminiInbox.ps1'
if (Test-Path -LiteralPath $syncInboxScript) {
  & $syncInboxScript
} else {
  Write-Warning "Sync-GeminiInbox.ps1 not found in $lcdInternal"
}

# ------------------------------------------------------------------------------
# 4. Synchronize .gemini Baseline Manifest & Cryptographic Hashes
# ------------------------------------------------------------------------------
Write-Host "`n[4/4] Synchronizing .gemini Configuration Baseline & Computing SHA256 Hashes..." -ForegroundColor Yellow
try {
  $geminiConfig = Join-Path $env:USERPROFILE '.gemini\config'
  if (-not (Test-Path -LiteralPath $geminiConfig) -and (Test-Path -LiteralPath 'A:\.gemini\config')) {
    $geminiConfig = 'A:\.gemini\config'
  }

  if (Test-Path -LiteralPath $geminiConfig) {
    $baselineDir = Join-Path $workspaceRoot 'LCM_AI\data\gemini_baseline'
    $targetConfig = Join-Path $baselineDir 'config'
    if (-not (Test-Path -LiteralPath $targetConfig)) {
      New-Item -Path $targetConfig -ItemType Directory -Force | Out-Null
    }

    & robocopy.exe $geminiConfig $targetConfig /MIR /R:2 /W:1 /XJ /NP /NFL /NDL | Out-Null

    $files = @(Get-ChildItem -Path $targetConfig -Recurse -File | Sort-Object FullName)
    $fileMap = [ordered]@{}
    $hashLines = [System.Collections.Generic.List[string]]::new()

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
      foreach ($f in $files) {
        $rel = $f.FullName.Substring($targetConfig.Length).TrimStart('\').Replace('\', '/')
        $fs = [System.IO.FileStream]::new($f.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
          $hashBytes = $sha256.ComputeHash($fs)
          $h = [System.BitConverter]::ToString($hashBytes).Replace('-', '')
        } finally {
          $fs.Dispose()
        }
        $fileMap[$rel] = $h
        $hashLines.Add("$($rel):$($h)")
      }
    } finally {
      $sha256.Dispose()
    }

    $combined = $hashLines -join "`n"
    $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($combined))
    $rootHash = (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash

    $nowUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $commitSha = try { (git -C (Join-Path $workspaceRoot 'LCM_AI') rev-parse HEAD).Trim() } catch { '' }

    $manifest = [PSCustomObject]@{
      version     = '1.2.0'
      updated_at  = $nowUtc
      commit_sha  = $commitSha
      root_hash   = $rootHash
      total_files = $files.Count
      files       = $fileMap
    }

    $manifestPath = Join-Path $baselineDir 'gemini_manifest.json'
    $manifestJson = $manifest | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.Encoding]::UTF8)
    Write-Host "  -> Baseline synchronized: $($files.Count) files (Root SHA256: $($rootHash.Substring(0, 12))...)" -ForegroundColor Green
  } else {
    Write-Warning ".gemini configuration directory not found at $geminiConfig"
  }
} catch {
  Write-Warning "Failed to synchronize .gemini baseline manifest: $_"
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " [SUMMARY] Gemini AI Context & Knowledge Base Pipeline Completed" -ForegroundColor Green
Write-Host " Consolidated Rules : LCM_AI/docs/LCM_Rules_Gemini_Export.md"
Write-Host " Google Drive Mirror: D:\GDrive\LCM (Code & Tripartite Docs with .txt)"
Write-Host " Google Drive Inbox : D:\GDrive\LCM\INBOX"
Write-Host " Baseline Manifest  : LCM_AI/data/gemini_baseline/gemini_manifest.json"
Write-Host "==========================================================================" -ForegroundColor Cyan
