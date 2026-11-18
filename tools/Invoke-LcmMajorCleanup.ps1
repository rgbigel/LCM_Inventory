[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Write a dry-run manifest of everything the cleanup would delete')]
  [switch]$Report,

  [Parameter(Mandatory = $false, HelpMessage = 'Delete exactly the entries of a confirmed manifest')]
  [switch]$Apply,

  [Parameter(Mandatory = $false, HelpMessage = 'Manifest JSON written by -Report (required with -Apply)')]
  [string]$Manifest = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Manifest hash printed by -Report; confirms the operator reviewed this manifest')]
  [string]$ManifestHash = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Also select the further deletion candidates in the manifest (-Report)')]
  [switch]$IncludeCandidates,

  [Parameter(Mandatory = $false, HelpMessage = 'Workspace root (default: parent of LCM_Inventory)')]
  [string]$WorkspaceRoot = '',

  [Alias('h', '?')]
  [switch]$Help
)

<#
.SYNOPSIS
  Manually triggered major-version cleanup with in-place log and completed-proposal ledger (CRP-355).
.DESCRIPTION
  Module: tools/Invoke-LcmMajorCleanup.ps1
  Purpose: Deletes items of major M-2 and older (M = current major from LCM_AI/.agents/version.json) in proposals,
           review receipts and logs. -Report writes a manifest (JSON + Markdown) to LCM_Inventory/data/analysis/history;
           -Apply deletes exactly the entries of that manifest after the operator confirmed its hash, compacts the
           deleted proposals to ledger rows (never removed, ID counter stays continuous), regenerates
           docs/Proposals/LEDGER_COMPLETED.md and appends one block to the in-place log in
           LCM_AI/docs/Logs/03_Propagation-and-Continuous-History/Major_Version_Milestone_Rollup.md.
  Path: LCM_Inventory/tools/Invoke-LcmMajorCleanup.ps1
  Authors: Rolf, Claude
  Version: 10.7.5
  Date: 2026-11-18
  Implementation Choices (CRP-355): the release register is the Markdown table in Major_Version_Milestone_Rollup.md
           (no database table before CRP-358); the origin major of a proposal is derived from lcm_version
           ("Legacy (<10.0)" = before 10, and since 9 was never released, 8 or older). Protected regardless of major:
           non-terminal states, members of an open cohort, IDs cited in .agents/ACTIVE_CONTEXT.md or LEARNED_ADVICE.md.
           Logs and review receipts are selected by date (before the first release of a major above M-2).
           Permanent evolution history (LCM_AI/docs/Logs) is never selected. -Apply refuses a manifest whose hash
           differs from -ManifestHash; there is no unguarded second call.
  Implementation Choices (CRP-355, operator Q1-Q3 2026-11-18): review receipts git does not track are deleted like
           the others. A one-time rule (ids below 150 counted as major 8, because the 10.0.0 migration overwrote their
           version and dates) was used for the run CLEANUP-20261118_220338 and removed afterwards.
.NOTES
  Caveats: deleted files that git does not track (logs, data/reviews) cannot be recovered; the manifest marks them.
           Reparse points are removed as links only (RULE-PS-018).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help -or (-not $Report -and -not $Apply)) {
  Write-Host 'Invoke-LcmMajorCleanup.ps1 -Report [-IncludeCandidates] [-WorkspaceRoot <path>]' -ForegroundColor Yellow
  Write-Host 'Invoke-LcmMajorCleanup.ps1 -Apply -Manifest <manifest.json> -ManifestHash <hash> [-WorkspaceRoot <path>]' -ForegroundColor Yellow
  Write-Host '  -Report writes a manifest of items of major M-2 and older; -Apply deletes exactly its selected entries.'
  return
}
if ($Report -and $Apply) { throw 'Use either -Report or -Apply.' }

$inventoryRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { $WorkspaceRoot = Split-Path $inventoryRoot -Parent }
$WorkspaceRoot = $WorkspaceRoot.TrimEnd('\')
$invRoot = Join-Path $WorkspaceRoot 'LCM_Inventory'
Import-Module -Name (Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1') -Force
$logDir = Join-Path $invRoot 'logs'
$logFile = Join-Path $logDir ('Invoke-LcmMajorCleanup-{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
function Write-CleanupLog([string]$Level, [string]$Message) {
  $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
  if (Test-Path -LiteralPath $logDir) { Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8 }
  Write-Host $line
}

$rollupPath = Join-Path $WorkspaceRoot 'LCM_AI\docs\Logs\03_Propagation-and-Continuous-History\Major_Version_Milestone_Rollup.md'
$terminalStates = @('pushed', 'superseded', 'rejected', 'withdrawn')

function Get-CleanupReleaseRegister {
  $rows = foreach ($line in [IO.File]::ReadAllLines($rollupPath)) {
    if ($line -match '^\|\s*(\d+)\s*\|\s*([\d.]+)\s*\|\s*(\d{4}-\d\d-\d\d)\s*\|') {
      [pscustomobject]@{ Major = [int]$Matches[1]; Release = $Matches[2]; Date = [datetime]::ParseExact($Matches[3], 'yyyy-MM-dd', $null) }
    }
  }
  if (@($rows).Count -eq 0) { throw "No release register rows in $rollupPath." }
  return @($rows)
}

function Get-CleanupOriginMajor([psobject]$Proposal) {
  $version = if ($Proposal.PSObject.Properties['lcm_version']) { [string]$Proposal.lcm_version } else { '' }
  if ($version -match '^(?i)legacy') { return 8 }  # "Legacy (<10.0)": 9.x was never released
  if ($version -match '^(\d+)\.') { return [int]$Matches[1] }
  return $null
}

# CRP-355: sum of a property that also works for an empty list (Measure-Object then has no Sum under StrictMode).
function Get-CleanupSum($Items, [string]$Property) {
  $total = [int64]0
  foreach ($item in @($Items)) { $total += [int64]$item.$Property }
  return $total
}

function Get-TrackedSet([string]$RepoPath) {
  $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  if (Test-Path -LiteralPath (Join-Path $RepoPath '.git')) {
    foreach ($f in @(git -C $RepoPath ls-files 2>$null)) { [void]$set.Add($f.Replace('/', '\')) }
  }
  return , $set
}

function Get-EntryStats([string]$FullPath) {
  $item = Get-Item -LiteralPath $FullPath -Force
  if ($item.PSIsContainer -and -not $item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
    $files = @(Get-ChildItem -LiteralPath $FullPath -Recurse -File -Force -ErrorAction SilentlyContinue)
    return [pscustomobject]@{ Files = $files.Count; Bytes = [int64](Get-CleanupSum $files 'Length') }
  }
  $len = if ($item.PSIsContainer) { 0 } else { [int64]$item.Length }
  return [pscustomobject]@{ Files = 1; Bytes = $len }
}

function Get-ManifestHash([psobject]$Data) {
  $selected = [ordered]@{
    entries = @($Data.entries | Where-Object { $_.selected } | ForEach-Object { '{0}|{1}' -f $_.kind, $_.path })
    ledger  = @($Data.ledger | ForEach-Object { [string]$_.id })
  }
  $bytes = [Text.Encoding]::UTF8.GetBytes(($selected | ConvertTo-Json -Depth 4 -Compress))
  return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

if ($Report) {
  $versionJson = Get-Content -LiteralPath (Join-Path $WorkspaceRoot 'LCM_AI\.agents\version.json') -Raw | ConvertFrom-Json
  $currentMajor = [int](([string]$versionJson.version).Split('.')[0])
  $cutoffMajor = $currentMajor - 2
  $register = Get-CleanupReleaseRegister
  $nextRelease = @($register | Where-Object { $_.Major -gt $cutoffMajor } | Sort-Object Date)[0]
  if ($null -eq $nextRelease) { throw "Release register has no release above major $cutoffMajor." }
  $dateCutoff = $nextRelease.Date
  Write-CleanupLog 'INFO' ("Current major {0}; items of major {1} and older; date cutoff {2:yyyy-MM-dd} (first release of major {3})." -f $currentMajor, $cutoffMajor, $dateCutoff, $nextRelease.Major)

  # protected IDs: cited in the continuity files, members of open cohorts
  $protected = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($name in 'ACTIVE_CONTEXT.md', 'LEARNED_ADVICE.md') {
    $path = Join-Path $WorkspaceRoot "LCM_AI\.agents\$name"
    if (Test-Path -LiteralPath $path) { foreach ($m in [regex]::Matches([IO.File]::ReadAllText($path), '\b(?:CRP|BUG)-\d{3,}\b')) { [void]$protected.Add($m.Value) } }
  }
  $store = Get-ProposalStore
  $openCohortIds = @(if ($store.PSObject.Properties['review_cohorts'] -and $store.review_cohorts) { $store.review_cohorts | Where-Object { [string]$_.state -eq 'open' } | ForEach-Object { @($_.proposal_ids) } })

  $entries = [System.Collections.Generic.List[object]]::new()
  $ledger = [System.Collections.Generic.List[object]]::new()
  $kept = [System.Collections.Generic.List[string]]::new()
  $tracked = @{}
  foreach ($repo in @('LCM_Inventory', 'LCM_AI')) { $tracked[$repo] = Get-TrackedSet (Join-Path $WorkspaceRoot $repo) }
  function Add-CleanupEntry([string]$Kind, [string]$Repo, [string]$FullPath, [string]$Reason, [bool]$Selected) {
    if (-not (Test-Path -LiteralPath $FullPath)) { return }
    $stats = Get-EntryStats $FullPath
    $rel = $FullPath.Substring($WorkspaceRoot.Length).TrimStart('\')
    $repoRel = $FullPath.Substring((Join-Path $WorkspaceRoot $Repo).Length).TrimStart('\')
    $isTracked = $tracked.ContainsKey($Repo) -and (@($tracked[$Repo] | Where-Object { $_ -eq $repoRel -or $_.StartsWith($repoRel + '\', [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0)
    $entries.Add([pscustomobject][ordered]@{ kind = $Kind; path = $rel; files = $stats.Files; bytes = $stats.Bytes; tracked = $isTracked; reason = $Reason; selected = $Selected })
  }

  # proposals of major <= cutoff in a final state
  $proposalsDir = Join-Path $invRoot 'docs\Proposals'
  $flatFiles = @(if (Test-Path -LiteralPath $proposalsDir) { Get-ChildItem -LiteralPath $proposalsDir -File })
  foreach ($p in @($store.proposals)) {
    $identity = if ($p.PSObject.Properties['crp_id'] -and $p.crp_id) { [string]$p.crp_id } else { '' }
    $major = Get-CleanupOriginMajor $p
    if ($null -eq $major -or $major -gt $cutoffMajor) { continue }
    if ([string]$p.state -notin $terminalStates) { $kept.Add("$identity ($($p.state))"); continue }
    if ($identity -and $protected.Contains($identity)) { $kept.Add("$identity (cited in continuity files)"); continue }
    if ($openCohortIds -contains [int]$p.id) { $kept.Add("$identity (open cohort)"); continue }
    if ($p.PSObject.Properties['archived_at'] -and $p.archived_at) { continue }
    $ledger.Add([pscustomobject][ordered]@{ id = [int]$p.id; crp_id = $identity; title = [string]$p.title; state = [string]$p.state; origin_major = $major })
    if ($p.PSObject.Properties['bundle_dir'] -and $p.bundle_dir) {
      Add-CleanupEntry 'bundle' 'LCM_Inventory' (Join-Path $invRoot ([string]$p.bundle_dir).Replace('/', '\')) "$identity $($p.state), major $major" $true
    }
    if ($identity) {
      foreach ($flat in @($flatFiles | Where-Object { $_.Name.StartsWith($identity + '-', [StringComparison]::OrdinalIgnoreCase) })) {
        Add-CleanupEntry 'flat-proposal' 'LCM_Inventory' $flat.FullName "$identity legacy flat file" $true
      }
    }
  }

  # review receipts and logs dated before the cutoff
  $reviewsDir = Join-Path $invRoot 'data\reviews'
  if (Test-Path -LiteralPath $reviewsDir) {
    foreach ($f in @(Get-ChildItem -LiteralPath $reviewsDir -File)) {
      if ($f.Name -match '_(\d{8})_' -and [datetime]::ParseExact($Matches[1], 'yyyyMMdd', $null) -lt $dateCutoff) {
        Add-CleanupEntry 'review-receipt' 'LCM_Inventory' $f.FullName ('dated ' + $Matches[1]) $true
      }
    }
  }
  foreach ($dir in @((Join-Path $invRoot 'logs'), (Join-Path $invRoot 'data\logs'))) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -File -Recurse | Where-Object { $_.Name -ne 'cm_activity.log' -and $_.LastWriteTime -lt $dateCutoff })) {
      Add-CleanupEntry 'log' 'LCM_Inventory' $f.FullName ('last written {0:yyyy-MM-dd}' -f $f.LastWriteTime) $true
    }
  }

  # further deletion candidates (CRP-355 section 3); selected only with -IncludeCandidates
  $candidates = @(
    @('LCM_Inventory', 'tools\Invoke-PrivilegedTool.ps1', 'retired by RULE-ELEV-006, only PrivilegedTool.cmd refers to it'),
    @('LCM_Inventory', 'Cmd\PrivilegedTool.cmd', 'launcher of the retired Invoke-PrivilegedTool.ps1'),
    @('LCM_Inventory', 'Cmd\RunShell.cmd', 'unreferenced'),
    @('LCM_Inventory', 'tools\RunShell.ps1', 'unreferenced (link into LCM_Tools)'),
    @('LCM_Inventory', 'data\proposals\proposals.json.bak', 'stale backup'),
    @('LCM_Inventory', 'Cmd\archive-Clean.cmd', 'duplicate of ArchiveClean.cmd')
  )
  foreach ($c in $candidates) { Add-CleanupEntry 'candidate' $c[0] (Join-Path (Join-Path $WorkspaceRoot $c[0]) $c[1]) $c[2] ([bool]$IncludeCandidates) }
  foreach ($f in @(if (Test-Path -LiteralPath (Join-Path $invRoot 'data\proposals')) { Get-ChildItem -LiteralPath (Join-Path $invRoot 'data\proposals') -File -Filter 'CRP-2026*.json' })) { Add-CleanupEntry 'candidate' 'LCM_Inventory' $f.FullName 'stray proposal JSON' ([bool]$IncludeCandidates) }
  foreach ($d in @(if (Test-Path -LiteralPath $proposalsDir) { Get-ChildItem -LiteralPath $proposalsDir -Directory | Where-Object { $_.Name -match '^(CRP-24[3-6]|24[3-6]_CRP)-.*Test' } })) { Add-CleanupEntry 'candidate' 'LCM_Inventory' $d.FullName 'test residue bundle' ([bool]$IncludeCandidates) }

  # reconciliation JSON vs database (T3, read-only)
  $reconciliation = 'not run'
  $syncScript = Join-Path $invRoot 'tools\Sync-LcmProposalsDb.ps1'
  if ((Test-Path -LiteralPath $syncScript) -and -not $env:LCM_PROPOSAL_STORE_PATH) {
    $reconciliation = (@(& pwsh -NoProfile -File $syncScript -Action Verify 2>&1) | Where-Object { "$_" -match 'PASS|FAIL|mismatch' } | Select-Object -First 1) -as [string]
  }

  $runId = 'CLEANUP-{0}' -f (Get-Date -Format 'yyyyMMdd_HHmmss')
  $data = [pscustomobject][ordered]@{
    run_id = $runId; created = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); workspace = $WorkspaceRoot
    current_major = $currentMajor; cutoff_major = $cutoffMajor; date_cutoff = $dateCutoff.ToString('yyyy-MM-dd')
    reconciliation = $reconciliation; protected_kept = @($kept); entries = @($entries); ledger = @($ledger)
  }
  $hash = Get-ManifestHash $data
  $data | Add-Member -NotePropertyName manifest_hash -NotePropertyValue $hash
  $outDir = Join-Path $invRoot 'data\analysis\history'
  $null = New-Item -ItemType Directory -Path $outDir -Force
  $jsonPath = Join-Path $outDir "$runId.json"
  $data | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
  $sel = @($entries | Where-Object { $_.selected })
  $md = [System.Collections.Generic.List[string]]::new()
  $md.Add("# Cleanup manifest $runId"); $md.Add('')
  $md.Add("Major $currentMajor, items of major $cutoffMajor and older, date cutoff $($dateCutoff.ToString('yyyy-MM-dd')). Reconciliation: $reconciliation"); $md.Add('')
  $md.Add('| Kind | Selected | Entries | Files | Bytes | Untracked |'); $md.Add('|:---|:---|---:|---:|---:|---:|')
  foreach ($g in @($entries | Group-Object kind, selected)) {
    $grp = @($g.Group); $md.Add(('| {0} | {1} | {2} | {3} | {4} | {5} |' -f $grp[0].kind, $grp[0].selected, $grp.Count, (Get-CleanupSum $grp 'files'), (Get-CleanupSum $grp 'bytes'), @($grp | Where-Object { -not $_.tracked }).Count))
  }
  $md.Add(''); $md.Add("Ledger rows compacted: $($ledger.Count). Protected and kept: $($kept.Count)."); $md.Add(''); $md.Add("Manifest hash: $hash")
  $mdPath = Join-Path $outDir "$runId.md"
  $md | Set-Content -LiteralPath $mdPath -Encoding UTF8
  Write-CleanupLog 'SUMMARY' ("Report {0}: {1} selected entries ({2} files, {3} bytes), {4} ledger rows, {5} protected kept, {6} candidates listed. Manifest {7}; hash {8}" -f $runId, $sel.Count, (Get-CleanupSum $sel 'files'), (Get-CleanupSum $sel 'bytes'), $ledger.Count, $kept.Count, @($entries | Where-Object { $_.kind -eq 'candidate' }).Count, $jsonPath, $hash)
  [pscustomobject]@{ Manifest = $jsonPath; Summary = $mdPath; ManifestHash = $hash; Selected = $sel.Count; LedgerRows = $ledger.Count }
  return
}

# ------------------------------ Apply ------------------------------
if ([string]::IsNullOrWhiteSpace($Manifest) -or [string]::IsNullOrWhiteSpace($ManifestHash)) { throw '-Apply requires -Manifest and -ManifestHash.' }
$data = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
if ([string]$data.workspace -ne $WorkspaceRoot) { throw "Manifest workspace '$($data.workspace)' differs from '$WorkspaceRoot'." }
$actual = Get-ManifestHash $data
if ($actual -ne $ManifestHash.ToLowerInvariant() -or $actual -ne [string]$data.manifest_hash) { throw "Manifest hash mismatch: confirmed '$ManifestHash', manifest content '$actual'. Nothing was deleted." }

$shas = [ordered]@{}
foreach ($repo in @('Git_Repositories', 'LCM_AI', 'LCM_Inventory')) {
  $repoPath = if ($repo -eq 'Git_Repositories') { $WorkspaceRoot } else { Join-Path $WorkspaceRoot $repo }
  $shas[$repo] = if (Test-Path -LiteralPath (Join-Path $repoPath '.git')) { (git -C $repoPath rev-parse --short HEAD).Trim() } else { 'none' }
}
$deleted = [System.Collections.Generic.List[object]]::new()
foreach ($e in @($data.entries | Where-Object { $_.selected })) {
  $full = Join-Path $WorkspaceRoot $e.path
  if (-not $full.StartsWith($WorkspaceRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Entry escapes the workspace: $($e.path)" }
  if (-not (Test-Path -LiteralPath $full)) { continue }
  $item = Get-Item -LiteralPath $full -Force
  if ($item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { $item.Delete() }  # link only (RULE-PS-018)
  elseif ($item.PSIsContainer) { Remove-Item -LiteralPath $full -Recurse -Force }
  else { Remove-Item -LiteralPath $full -Force }
  $deleted.Add($e)
}

# ledger compaction: rows stay, details go
$store = Get-ProposalStore
$stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$ledgerIds = @($data.ledger | ForEach-Object { [int]$_.id })
$compacted = 0
$list = [System.Collections.Generic.List[object]]::new()
foreach ($p in @($store.proposals)) {
  if ($ledgerIds -contains [int]$p.id) {
    $history = @(if ($p.PSObject.Properties['state_history'] -and $p.state_history) { $p.state_history })
    $pushedAt = @($history | Where-Object { [string]$_.state -eq 'pushed' } | Select-Object -Last 1 | ForEach-Object { [string]$_.timestamp })
    $completedAt = @($history | Where-Object { [string]$_.state -eq 'completed' } | Select-Object -Last 1 | ForEach-Object { [string]$_.timestamp })
    $row = [ordered]@{}
    foreach ($key in 'id', 'crp_id', 'cr_id', 'title', 'state', 'lcm_version', 'timestamp', 'commit_sha', 'github_url', 'bundle_dir') {
      $row[$key] = if ($p.PSObject.Properties[$key]) { $p.$key } else { $null }
    }
    $row['origin_major'] = (@($data.ledger | Where-Object { [int]$_.id -eq [int]$p.id })[0]).origin_major
    $row['completed_at'] = if ($completedAt.Count -gt 0) { $completedAt[0] } else { $null }
    $row['pushed_at'] = if ($pushedAt.Count -gt 0) { $pushedAt[0] } else { $null }
    if ([string]::IsNullOrWhiteSpace([string]$row['commit_sha'])) { $row['commit_sha'] = 'unknown' }
    $row['archived_at'] = $stamp
    $row['archive_run'] = [string]$data.run_id
    $list.Add([pscustomobject]$row); $compacted++
  } else { $list.Add($p) }
}
$store.proposals = @($list)
Set-ProposalStore -Store $store

# completed-proposal ledger (Markdown projection of all archived rows)
$ledgerMd = [System.Collections.Generic.List[string]]::new()
$ledgerMd.Add('# Completed Proposal Ledger'); $ledgerMd.Add('')
$ledgerMd.Add('Module: docs/Proposals/LEDGER_COMPLETED.md  '); $ledgerMd.Add('Purpose: Compact rows of proposals removed by the major-version cleanup (CRP-355); generated, do not edit.  ')
$ledgerMd.Add('Path: LCM_Inventory/docs/Proposals/LEDGER_COMPLETED.md  '); $ledgerMd.Add('Authors: Rolf, Claude  '); $ledgerMd.Add('Version: 10.7.4  '); $ledgerMd.Add("Date: $stamp"); $ledgerMd.Add('')
$ledgerMd.Add('| ID | Title | Final state | Major | Completed | Pushed | Commit | Run |'); $ledgerMd.Add('|:---|:---|:---|:---|:---|:---|:---|:---|')
foreach ($r in @($store.proposals | Where-Object { $_.PSObject.Properties['archived_at'] -and $_.archived_at } | Sort-Object { [int]$_.id })) {
  $ledgerMd.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |' -f $r.crp_id, ([string]$r.title).Replace('|', '/'), $r.state, $r.origin_major, $r.completed_at, $r.pushed_at, $r.commit_sha, $r.archive_run))
}
$ledgerPath = Join-Path $invRoot 'docs\Proposals\LEDGER_COMPLETED.md'
$ledgerMd | Set-Content -LiteralPath $ledgerPath -Encoding UTF8

# in-place log block
$block = [System.Collections.Generic.List[string]]::new()
$block.Add(''); $block.Add("### Cleanup run $($data.run_id) ($stamp)"); $block.Add('')
$block.Add("* **Scope**: current major $($data.current_major); items of major $($data.cutoff_major) and older; logs and review receipts before $($data.date_cutoff).")
foreach ($g in @($deleted | Group-Object kind)) {
  $grp = @($g.Group)
  $block.Add(('* **{0}**: {1} entries, {2} files, {3} bytes deleted; {4} not tracked by git (not recoverable).' -f $grp[0].kind, $grp.Count, (Get-CleanupSum $grp 'files'), (Get-CleanupSum $grp 'bytes'), @($grp | Where-Object { -not $_.tracked }).Count))
}
$block.Add("* **Ledger**: $compacted proposals compacted to rows (see LCM_Inventory/docs/Proposals/LEDGER_COMPLETED.md).")
$block.Add('* **Retrieval anchors (HEAD before deletion)**: ' + (($shas.Keys | ForEach-Object { '{0} {1}' -f $_, $shas[$_] }) -join ', ') + '.')
$block.Add('* **Protected and kept**: ' + $(if (@($data.protected_kept).Count -gt 0) { (@($data.protected_kept) -join ', ') } else { 'none' }) + '.')
$block.Add("* **Manifest**: $Manifest (hash $actual).")
Add-Content -LiteralPath $rollupPath -Value ($block -join "`r`n") -Encoding UTF8

Write-CleanupLog 'SUMMARY' ("Applied {0}: {1} entries deleted, {2} ledger rows compacted; in-place log appended to {3}. Gate 2: review the deletions with BCR before commit." -f $data.run_id, $deleted.Count, $compacted, $rollupPath)
[pscustomobject]@{ RunId = $data.run_id; Deleted = $deleted.Count; Compacted = $compacted; Ledger = $ledgerPath; Log = $rollupPath }
