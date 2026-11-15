<#
.SYNOPSIS
  Reports or converts lone LF line endings to CRLF in LCM text files (byte level, BOM-preserving).

.DESCRIPTION
  Module: LCM_Inventory/tools/Repair-LcmLineEndings.ps1
  Purpose: Enforcement tool for the LCM line-ending invariant (newline-crlf, operator Option A, CRP-332): dry-run report by
  default, in-place conversion with -Apply. Used for the one-time workspace conversion, by Submit-ReviewResult.ps1 before
  staging (completion time) and by the Claude write hook.
  Path: LCM_Inventory/tools/Repair-LcmLineEndings.ps1
  Authors: Rolf, Claude (Anthropic)
  Version: 10.6.4
  Date: 2026-11-15

  Implementation Choices (CRP-332): thin controller over LcmLineEndingAtoms.psm1; directories are walked without following
  junctions; only CRLF-governed extensions are touched (*.sh and *.go excluded); a CRLF correction is not a review-relevant
  change (operator 2026-11-15).

.PARAMETER Path
  One or more files or directories. Directories are scanned recursively unless -NoRecurse.

.PARAMETER Apply
  Convert in place. Without it the tool only reports (dry run).

.PARAMETER NoRecurse
  Scan only the top level of each directory.

.PARAMETER Quiet
  Print nothing except failures; the summary object is still returned.

.PARAMETER NoLog
  Do not write a log file (for per-file hook calls).

.PARAMETER Help
  Prints usage and exits without mutation.

.EXAMPLE
  Repair-LcmLineEndings.ps1 -Path D:\Git_Repositories\LCM_Tools
  Repair-LcmLineEndings.ps1 -Path D:\Git_Repositories\LCM_Tools -Apply

.NOTES
  Caveats: Files locked by another process are reported as Failed after 3 attempts. No elevation required.
#>
[CmdletBinding()]
param(
  [string[]]$Path,
  [switch]$Apply,
  [switch]$NoRecurse,
  [switch]$Quiet,
  [switch]$NoLog,
  [Alias('h', '?')][switch]$Help
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolName = 'Repair-LcmLineEndings.ps1'
$toolVersion = '10.6.4'

if ($Help -or $null -eq $Path -or 0 -eq @($Path).Count) {
  Write-Host ('{0} v{1}' -f $toolName, $toolVersion)
  Write-Host 'Repair-LcmLineEndings -Path <file|directory>[,...] [-Apply] [-NoRecurse] [-Quiet] [-NoLog]'
  Write-Host '  Default is a dry run (report only); -Apply converts lone LF to CRLF in place (byte level, BOM kept).'
  Write-Host '  Governed types: see Get-LcmCrlfExtensions in LcmLineEndingAtoms.psm1; *.sh and *.go are excluded.'
  Write-Host '  Junctions and symbolic links are not followed; .git, node_modules, .venv, bin, obj are skipped.'
  return
}

# pwsh -File passes '-Path a,b' as one string; split it here.
$Path = @($Path | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmLineEndingAtoms.psm1') -Force

$results = [Collections.Generic.List[object]]::new()
foreach ($item in @($Path)) {
  if (Test-Path -LiteralPath $item -PathType Container) {
    foreach ($file in (Get-LcmCrlfCandidateFiles -Root $item -NoRecurse:$NoRecurse)) {
      $results.Add((Repair-LcmLineEnding -Path $file -DryRun:(-not $Apply)))
    }
  } elseif (Test-Path -LiteralPath $item -PathType Leaf) {
    $results.Add((Repair-LcmLineEnding -Path $item -DryRun:(-not $Apply)))
  } else {
    $results.Add([pscustomobject]@{ Path = $item; Status = 'Skipped'; LoneLf = 0; Reason = 'path not found' })
  }
}

$changed = @($results | Where-Object { $_.Status -in @('Converted', 'WouldConvert') })
$failed = @($results | Where-Object { 'Failed' -eq $_.Status })
$mode = if ($Apply) { 'Apply' } else { 'DryRun' }
$status = if ($failed.Count -gt 0) { 'Failed' } else { 'Succeeded' }
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

$logPath = ''
if ($Apply -and -not $NoLog -and ($changed.Count -gt 0 -or $failed.Count -gt 0)) {
  $logDir = Join-Path $PSScriptRoot '..\data\logs\lcm'
  if (-not (Test-Path -LiteralPath $logDir)) { $null = New-Item -ItemType Directory -Path $logDir -Force }
  $logPath = Join-Path (Resolve-Path -LiteralPath $logDir).Path ('{0}-{1}.log' -f [IO.Path]::GetFileNameWithoutExtension($toolName), (Get-Date -Format 'yyyyMMdd_HHmmss'))
  $lines = [Collections.Generic.List[string]]::new()
  $lines.Add(('[INFO] {0} {1} Mode={2} Paths={3}' -f $stamp, $toolName, $mode, (@($Path) -join ';')))
  foreach ($r in $changed) { $lines.Add(('[ACTION] {0} {1} LoneLf={2}' -f $r.Status, $r.Path, $r.LoneLf)) }
  foreach ($r in $failed) { $lines.Add(('[ERROR] {0} {1}' -f $r.Path, $r.Reason)) }
  $lines.Add(('[SUMMARY] Tool={0} Version={1} Status={2} Mode={3} Scanned={4} Changed={5} Failed={6} Time={7}' -f $toolName, $toolVersion, $status, $mode, $results.Count, $changed.Count, $failed.Count, $stamp))
  [IO.File]::WriteAllText($logPath, (($lines -join "`r`n") + "`r`n"), [Text.UTF8Encoding]::new($false))
}

foreach ($r in $failed) { Write-Warning ('{0}: {1}' -f $r.Path, $r.Reason) }
if (-not $Quiet) {
  foreach ($r in $changed) { Write-Host ('  {0,-12} {1} (lone LF: {2})' -f $r.Status, $r.Path, $r.LoneLf) }
  Write-Host ('[SUMMARY] Tool={0} Version={1} Status={2} Mode={3} Scanned={4} Changed={5} Failed={6} Log={7} Time={8}' -f $toolName, $toolVersion, $status, $mode, $results.Count, $changed.Count, $failed.Count, $logPath, $stamp)
}

[pscustomobject]@{ Mode = $mode; Scanned = $results.Count; Changed = $changed.Count; Failed = $failed.Count; LogPath = $logPath }
if ($failed.Count -gt 0) { exit 1 }
