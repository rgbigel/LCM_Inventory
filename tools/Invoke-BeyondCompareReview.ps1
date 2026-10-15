[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Name or path of the repository to review')]
  [Alias('RepositoryPath', 'Path', 'Repo', 'Name')]
  [string]$RepositoryName,

  [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Base Git commit or reference to compare against (e.g., HEAD~1, root, SHA, tag)')]
  [string]$BaseCommit,

  [Parameter(Mandatory = $false, HelpMessage = 'Additional directory or file exclusions to filter from review display')]
  [Alias('Exclude', 'Filters')]
  [string[]]$Exclusions = @(),

  [Parameter(Mandatory = $false, HelpMessage = 'Exact CRP or BUG identifier (e.g. CRP-257)')]
  [Alias('Cr', 'ChangeRequest', 'Proposal', 'ProposalId')]
  [ValidatePattern('^(CRP|BUG)-\d+$')]
  [string]$CRP = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Isolated on-disk review identity; defaults to the exact CRP or BUG identity')]
  [ValidatePattern('^[A-Za-z0-9_.-]+$')]
  [string]$ReviewIdentity = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Wait synchronously for the Beyond Compare review session to close before evaluating staging')]
  [switch]$Wait,

  [Parameter(Mandatory = $false, HelpMessage = 'Force re-extraction and rebuild of baseline cache even if existing cached tree matches commit SHA')]
  [Alias('Force', 'RebuildBaseline', 'NoCache')]
  [switch]$ForceRebuild,

  [Parameter(Mandatory = $false, HelpMessage = 'Prepare the review baseline and staging manifest without opening a Beyond Compare window')]
  [switch]$NoLaunch,

  [Alias('h', '?')]
  [switch]$Help
)

<#
.SYNOPSIS
    Compares a repository's current state against any prior commit in Beyond Compare with interactive review staging.
.DESCRIPTION
    Module: tools/Invoke-BeyondCompareReview.ps1
    Purpose: Compares a repository's current state against any prior commit in Beyond Compare with interactive review staging,
             automatic exclusion of .venv/cache/scratch directories, 4-directive action parsing (Complete, Delete, Rename, Defer),
             and SHA-256 staging manifest generation.
    Path: tools/Invoke-BeyondCompareReview.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 10.0.0
    Date: 2026-10-13
.PARAMETER RepositoryName
    The name or directory path of the Git repository to review (e.g. 'AuthorizeMasterUser', 'Git_Repositories', '.').
.PARAMETER BaseCommit
    The base Git commit to compare against (e.g. 'HEAD~1', 'HEAD', 'root', SHA). Defaults to 'HEAD'.
.PARAMETER Exclusions
    Additional file or directory exclusion masks (Aliases: -Exclude, -Filters). Standard LCM exclusions are always applied.
.PARAMETER CRP
    Exact Change Request Proposal or BUG identifier (e.g. 'CRP-134' or 'BUG-12') to correlate with lifecycle review receipts.
.PARAMETER Wait
    Wait synchronously for the Beyond Compare review session to close before evaluating staging.
.PARAMETER Help
    Displays this parameter reference (Aliases: -h, -?).
.EXAMPLE
    pwsh tools/Invoke-BeyondCompareReview.ps1 -CRP CRP-261 -RepositoryName Git_Repositories
.EXAMPLE
    pwsh tools/Invoke-BeyondCompareReview.ps1 -CRP BUG-12 -RepositoryName AuthorizeMasterUser -BaseCommit HEAD~1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$bcompareWindowToolsPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\BCompareWindowTools.psm1'
Import-Module -Name $bcompareWindowToolsPath -Force
$bcompareBaselinePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\BCompareBaseline.psm1'
Import-Module -Name $bcompareBaselinePath -Force
$proposalManagerPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\ProposalManager.psm1'
Import-Module -Name $proposalManagerPath -Force

$scriptVersion = "10.0.0"
$scriptName = "Invoke-BeyondCompareReview"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " BEYOND COMPARE REPOSITORY REVIEW LAUNCHER (v$scriptVersion)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Exports the local Git HEAD baseline to a temporary inspection tree and opens"
  Write-Host "  Beyond Compare on your interactive desktop with out-of-scope filter exclusions."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Invoke-BeyondCompareReview.ps1 -CRP <CRP-ID> [-RepositoryName <repo>] [-BaseCommit <commit>] [-Exclusions <array>] [-Wait] [-h]"
  Write-Host "  BCR -CRP <CRP-ID> [-RepositoryName <repo>] [-BaseCommit <commit>]"
  Write-Host ""
  Write-Host "REVIEW PROTOCOL:" -ForegroundColor Yellow
  Write-Host "  1. Left pane is operator-owned reference content. LCM does not write to it or use it as lifecycle evidence."
  Write-Host "  2. Review or edit the live right pane. Right-pane edits are accepted changes."
  Write-Host "  3. Close the review and issue COMPLETE to record acceptance and commit the reviewed live worktree."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}


function Get-ActiveCRP {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$TargetRepoName,

    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRootPath
  )

  # Normalize TargetRepoName for alias matching (e.g. Git_Repositories / LCM)
  $isRootRepo = $TargetRepoName -in @('Git_Repositories', 'Root', 'LCM')

  # 1. Search proposals.json for matching proposals
  $pJson = Join-Path $WorkspaceRootPath "LCM_Inventory\data\proposals\proposals.json"
  if (Test-Path -LiteralPath $pJson) {
    try {
      $pData = Get-Content -LiteralPath $pJson -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($pData.PSObject.Properties['proposals']) {
        # Filter proposals by target repository
        $allRepoProposals = @($pData.proposals | Where-Object {
          if ($isRootRepo) {
            ($_.PSObject.Properties['origin_repo'] -and ($_.origin_repo -in @('Git_Repositories', 'Root', 'LCM', 'LCM / Git_Repositories') -or $_.origin_repo -like '*Git_Repositories*')) -or
            ($_.PSObject.Properties['repo'] -and ($_.repo -in @('Git_Repositories', 'Root', 'LCM') -or $_.repo -like '*Git_Repositories*'))
          }

          else {
            ($_.PSObject.Properties['origin_repo'] -and $_.origin_repo -eq $TargetRepoName) -or
            ($_.PSObject.Properties['repo'] -and $_.repo -eq $TargetRepoName) -or
            ($_.PSObject.Properties['impacted_repos'] -and $_.impacted_repos -contains $TargetRepoName) -or
            ($_.PSObject.Properties['affected_repos'] -and $_.affected_repos -contains $TargetRepoName)
          }
        })

        if ($allRepoProposals.Count -gt 0) {
          # Priority 1: In-flight / suggested / review / staged proposals
          $active = @($allRepoProposals | Where-Object {
            $_.PSObject.Properties['state'] -and $_.state -in @('in_progress', 'review', 'staged', 'suggested')
          })
          if ($active.Count -gt 0) {
            $latest = $active | Sort-Object { [int]($_.id -replace '\D', '') } -Descending | Select-Object -First 1
            if ($latest.PSObject.Properties['crp_id'] -and -not [string]::IsNullOrWhiteSpace($latest.crp_id)) { return [string]$latest.crp_id }
            if ($latest.PSObject.Properties['id']) { return "CRP-$($latest.id)" }
          }

          # Priority 2: Unpushed completed or committed proposals awaiting review / push
          $unpushed = @($allRepoProposals | Where-Object {
            $_.PSObject.Properties['state'] -and $_.state -notin @('pushed', 'deleted')
          })
          if ($unpushed.Count -gt 0) {
            $latest = $unpushed | Sort-Object { [int]($_.id -replace '\D', '') } -Descending | Select-Object -First 1
            if ($latest.PSObject.Properties['crp_id'] -and -not [string]::IsNullOrWhiteSpace($latest.crp_id)) { return [string]$latest.crp_id }
            if ($latest.PSObject.Properties['id']) { return "CRP-$($latest.id)" }
          }

          # Priority 3: Fall back to newest proposal overall for this repo
          $latestOverall = $allRepoProposals | Sort-Object { [int]($_.id -replace '\D', '') } -Descending | Select-Object -First 1
          if ($latestOverall) {
            if ($latestOverall.PSObject.Properties['crp_id'] -and -not [string]::IsNullOrWhiteSpace($latestOverall.crp_id)) { return [string]$latestOverall.crp_id }
            if ($latestOverall.PSObject.Properties['id']) { return "CRP-$($latestOverall.id)" }
          }
        }
      }
    }
    catch {}
  }

  # 2. Search recent commit message on repo path
  $targetRepoDir = Join-Path $WorkspaceRootPath $TargetRepoName
  if ($TargetRepoName -eq 'Git_Repositories') { $targetRepoDir = $WorkspaceRootPath }
  if (Test-Path -LiteralPath $targetRepoDir) {
    try {
      $lastMsg = (git -C $targetRepoDir log -n 1 --pretty=format:"%s" 2>$null)
      if ($lastMsg -match "(?i)\b(CRP-\d+|BUG-\d+|CR-\d+)\b") {
        return $Matches[1].ToUpperInvariant()
      }
    }
    catch {}
  }

  # 3. Search ACTIVE_SESSION.md
  $activeSessionFile = Join-Path $WorkspaceRootPath ".agents\ACTIVE_SESSION.md"
  if (Test-Path -LiteralPath $activeSessionFile) {
    try {
      $content = Get-Content -LiteralPath $activeSessionFile -Raw -Encoding UTF8
      if ($content -match "(?i)$TargetRepoName.*?\[?(CRP-\d+|BUG-\d+|CR-\d+)\]?") {
        return $Matches[1].ToUpperInvariant()
      }
      if ($content -match "(?i)Current In-Flight:.*?(CRP-\d+|BUG-\d+|CR-\d+)") {
        return $Matches[1].ToUpperInvariant()
      }
    }
    catch {}
  }

  return ''
}

function Register-DiscoveredCrossRepositoryReviewObligations {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryName,

    [Parameter(Mandatory = $true)]
    [string]$CRP,

    [psobject]$BaselineDescriptor
  )

  $store = Get-ProposalStore
  $proposal = @($store.proposals | Where-Object {
    $proposalCrpId = if ($_.PSObject.Properties['crp_id']) { [string]$_.crp_id } else { '' }
    $proposalCrId = if ($_.PSObject.Properties['cr_id']) { [string]$_.cr_id } else { '' }
    $proposalCrpId -eq $CRP -or $proposalCrId -eq $CRP -or "CRP-$($_.id)" -eq $CRP
  }) | Select-Object -First 1
  if ($null -eq $proposal) { return @() }

  $candidates = @()
  if ($proposal.PSObject.Properties['impacted_repos'] -and $proposal.impacted_repos) {
    $candidates += @($proposal.impacted_repos)
  }
  if ($proposal.PSObject.Properties['affected_repos'] -and $proposal.affected_repos) {
    $candidates += @($proposal.affected_repos)
  }
  if ($BaselineDescriptor -and -not [string]::IsNullOrWhiteSpace($BaselineDescriptor.RulesBaselineRepositoryPath)) {
    $authorityPath = [System.IO.Path]::GetFullPath($BaselineDescriptor.RulesBaselineRepositoryPath).TrimEnd('\')
    if ((Split-Path -Parent $authorityPath).Equals([System.IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
      $candidates += (Split-Path -Leaf $authorityPath)
    }
  }

  $registered = @()
  foreach ($candidate in @($candidates | Select-Object -Unique | Where-Object { $_ -and $_ -ne $RepositoryName })) {
    $candidatePath = Join-Path $WorkspaceRoot $candidate
    if (-not (Test-Path -LiteralPath (Join-Path $candidatePath '.git'))) { continue }
    $changedPaths = @(git -C $candidatePath status --porcelain 2>$null | ForEach-Object {
      if ($_.Length -gt 3) { $_.Substring(3).Trim() }
    } | Where-Object {
      $_ -and $_ -notmatch '^(scratch|logs|work|data)(\\|/|$)' -and $_ -notmatch '(^|[\\/])(__pycache__|\.venv|venv)([\\/]|$)'
    })
    if ($changedPaths.Count -gt 0) {
      $registered += Register-LcmCrossRepositoryReviewObligation -Id $proposal.id -Repository $candidate `
        -Reason "Durable changes discovered during $CRP BCR preparation: $($changedPaths -join ', ')."
    }
  }
  return @($registered | Where-Object { $null -ne $_ })
}

function Update-BCReviewSession {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$LeftPath,

    [Parameter(Mandatory = $true)]
    [string]$RightPath,

    [Parameter(Mandatory = $false)]
    [string]$FilterMask,

    [Parameter(Mandatory = $false)]
    [string]$SessionName = 'LCM_Review'
  )

  $bcSessionsPath = Join-Path $env:APPDATA 'Scooter Software\Beyond Compare 5\BCSessions.xml'
  if (-not (Test-Path -LiteralPath $bcSessionsPath)) { return }

  try {
    $xml = [xml](Get-Content -LiteralPath $bcSessionsPath -Raw)
    $rootNode = $xml.SelectSingleNode('/BCSessions')
    if (-not $rootNode) { return }

    # The authoritative saved named sessions reside directly under /BCSessions
    $sessionNode = $rootNode.SelectSingleNode("TDirCompareSession[@Value='$SessionName']")
    if (-not $sessionNode) {
      $templateNode = $rootNode.SelectSingleNode("TDirCompareSession[@Value='LCM_Review']")
      if ($templateNode) {
        $sessionNode = $templateNode.CloneNode($true)
        $sessionNode.SetAttribute('Value', $SessionName)
      } else {
        $sessionNode = $xml.CreateElement('TDirCompareSession')
        $sessionNode.SetAttribute('Value', $SessionName)
      }
      $null = $rootNode.AppendChild($sessionNode)
    }

    # Specs (Left and Right)
    $specs = $sessionNode.SelectSingleNode('Specs')
    if (-not $specs) {
      $specs = $xml.CreateElement('Specs')
      $null = $sessionNode.AppendChild($specs)
    }
    $left = $specs.SelectSingleNode('Left')
    if (-not $left) {
      $left = $xml.CreateElement('Left')
      $null = $specs.AppendChild($left)
    }
    $left.SetAttribute('Value', $LeftPath)

    $right = $specs.SelectSingleNode('Right')
    if (-not $right) {
      $right = $xml.CreateElement('Right')
      $null = $specs.AppendChild($right)
    }
    $right.SetAttribute('Value', $RightPath)

    # The LHS is operator-owned. Remove inherited pane locks so Beyond Compare
    # permits the operator's manual baseline maintenance.
    @($sessionNode.SelectNodes('.//*[contains(translate(name(), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz"), "readonly")]')) |
      ForEach-Object { $null = $_.ParentNode.RemoveChild($_) }

    # Filters
    if ($FilterMask) {
      $filters = $sessionNode.SelectSingleNode('Filters')
      if (-not $filters) {
        $filters = $xml.CreateElement('Filters')
        $null = $sessionNode.AppendChild($filters)
      }
      $nf = $filters.SelectSingleNode('NameFilter')
      if (-not $nf) {
        $nf = $xml.CreateElement('NameFilter')
        $null = $filters.AppendChild($nf)
      }
      $nf.SetAttribute('Value', $FilterMask)
    }

    $setAttr = {
      param($parent, $name, $val)
      $n = $parent.SelectSingleNode($name)
      if (-not $n) {
        $n = $parent.OwnerDocument.CreateElement($name)
        $null = $parent.AppendChild($n)
      }
      $n.SetAttribute('Value', $val)
    }

    # Rules
    $rules = $sessionNode.SelectSingleNode('Rules')
    if (-not $rules) {
      $rules = $xml.CreateElement('Rules')
      $null = $sessionNode.AppendChild($rules)
    }
    & $setAttr $rules 'ContentCompareKind' 'ccRulesBased'
    & $setAttr $rules 'UseContentComparison' 'False'
    & $setAttr $rules 'UseSizeComparison' 'True'
    & $setAttr $rules 'UseTimestampComparison' 'True'
    & $setAttr $rules 'FollowSymLinks' 'True'

    # State
    $state = $sessionNode.SelectSingleNode('State')
    if (-not $state) {
      $state = $xml.CreateElement('State')
      $null = $sessionNode.AppendChild($state)
    }
    & $setAttr $state 'ColAttributesVisible' 'True'
    & $setAttr $state 'ColCRCVisible' 'False'
    $dirH = $state.SelectSingleNode('DirHandling')
    if ($dirH) { $null = $state.RemoveChild($dirH) }
    & $setAttr $state 'DisplayFilter' '[showLeftAdded, showRightAdded, showLeftChanged, showRightChanged, showConflict]'
    & $setAttr $state 'InsigIgnored' 'True'
    & $setAttr $state 'SortCol' 'colModified'

    # Also ensure default TDirCompareSession template has FollowSymLinks = True
    $defaultSession = $xml.SelectSingleNode('/BCSessions/TSessionFolder/Items/TDirCompareSession[not(@Value) or @Value=""]')
    if ($defaultSession) {
      $defRules = $defaultSession.SelectSingleNode('Rules')
      if (-not $defRules) {
        $defRules = $xml.CreateElement('Rules')
        $null = $defaultSession.AppendChild($defRules)
      }
      & $setAttr $defRules 'FollowSymLinks' 'True'
    }

    $xml.Save($bcSessionsPath)
  }
  catch {
    Write-Verbose "Could not update BCSessions.xml: $($_.Exception.Message)"
  }
}

function Get-FileSha256 {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
  )

  if (-not (Test-Path -LiteralPath $FilePath)) { return $null }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $bytes = [System.IO.File]::ReadAllBytes($FilePath)
  $hashBytes = $sha.ComputeHash($bytes)
  return [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant()
}

function Test-StandardBcrExcludedPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
  )

  $normalizedPath = $RelativePath.Replace('/', '\').TrimStart('\')
  return $normalizedPath -match '^(?i)(?:\.git|\.venv|venv|\.env|__pycache__|scratch|logs|work|data|node_modules|bin|obj)(?:\\|$)|(?:^|\\)\.lcm\\(?:logs|scratch|archive|tools\\links)(?:\\|$)|(?i)\.(?:pyc|pyo|inventory|log|tmp|bak|swp|lock)$'
}

function Get-BeyondCompareReviewAcceptanceContext {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoName,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^(CRP|BUG)-\d+$')]
    [string]$CRP
  )

  return [PSCustomObject]@{
    RepositoryName = $RepoName
    CRP = $CRP
    LhsInspected = $false
  }
}

if ($MyInvocation.InvocationName -eq '.') {
  return
}

if ([string]::IsNullOrWhiteSpace($CRP)) {
  throw '-CRP is required. Repository-based CRP inference is not permitted.'
}

if ([string]::IsNullOrWhiteSpace($RepositoryName)) {
  $currentToplevel = (git rev-parse --show-toplevel 2>$null)
  if ($currentToplevel) {
    $RepositoryName = $currentToplevel.Trim()
  }
  else {
    $RepositoryName = '.'
  }
}

# ------------------------------------------------------------------------------
# 1. Resolve Target Repository & Workspace Root
# ------------------------------------------------------------------------------
$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
  $workspaceRoot = Split-Path $PSScriptRoot -Parent
}

$repoPath = $null
if ($RepositoryName -in @('root', 'Git_Repositories', (Split-Path $workspaceRoot -Leaf))) {
  $repoPath = $workspaceRoot
}
elseif (Test-Path -LiteralPath $RepositoryName) {
  $repoPath = (Resolve-Path $RepositoryName).Path
}
else {
  $candidatePath = Join-Path $workspaceRoot $RepositoryName
  if (Test-Path -LiteralPath $candidatePath) {
    $repoPath = $candidatePath
  }
}

if (-not $repoPath -or -not (Test-Path -LiteralPath $repoPath)) {
  throw "Repository path not found for input: '$RepositoryName'"
}

$repoName = Split-Path $repoPath -Leaf

if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) {
  throw "Target folder is not a valid Git repository: '$repoPath'"
}

# Resolve Beyond Compare 5 executable path deterministically
$BeyondComparePath = if (-not [string]::IsNullOrWhiteSpace($env:BCOMPARE_PATH) -and (Test-Path -LiteralPath $env:BCOMPARE_PATH)) {
  $env:BCOMPARE_PATH
} elseif (Test-Path -LiteralPath 'D:\Tools\Beyond Compare 5\BCompare.exe') {
  'D:\Tools\Beyond Compare 5\BCompare.exe'
} elseif (Test-Path -LiteralPath "${env:ProgramFiles}\Beyond Compare 5\BCompare.exe") {
  "${env:ProgramFiles}\Beyond Compare 5\BCompare.exe"
} else {
  $cmd = Get-Command "BCompare.exe" -ErrorAction SilentlyContinue
  if ($cmd) { $cmd.Source } else { 'D:\Tools\Beyond Compare 5\BCompare.exe' }
}

if (-not $NoLaunch -and -not (Test-Path -LiteralPath $BeyondComparePath)) {
  throw "Beyond Compare executable not found at: '$BeyondComparePath'"
}

# ------------------------------------------------------------------------------
# 2. Resolve Base Commit (Anchored strictly to local Git HEAD; no remote fetches)
# ------------------------------------------------------------------------------
$commitSha = $null
$commitMsg = ""

if ([string]::IsNullOrWhiteSpace($BaseCommit)) {
  $BaseCommit = 'HEAD'
}

try {
  # Strictly resolve against local Git HEAD without origin/main or network fetches
  $commitSha = (git -C $repoPath rev-parse --short $BaseCommit 2>$null).Trim()
  $commitMsg = (git -C $repoPath log -n 1 --pretty=format:"%s" $BaseCommit 2>$null).Trim()
}
catch {
  $commitSha = 'unborn'
  $commitMsg = 'Initial Empty Baseline'
}

if (-not $commitSha) {
  $commitSha = 'unborn'
  $commitMsg = 'Initial Empty Baseline'
}

Write-Host "Verified Baseline Resolution: [${commitSha}: $commitMsg]" -ForegroundColor DarkCyan

$baselineDescriptor = $null
if ($commitSha -ne 'unborn') {
  $baselineDescriptor = Get-BCompareBaselineDescriptor -RepositoryPath $repoPath -BaseCommit $BaseCommit
  $commitSha = $baselineDescriptor.TargetCommit
}

# ------------------------------------------------------------------------------
# 3. Export Baseline Commit into Workspace Scratch Review Inspection Tree (Variant A)
# ------------------------------------------------------------------------------
$scratchReviewDir = Join-Path $workspaceRoot "LCM_Inventory\scratch\BC_Review"
if (-not (Test-Path -LiteralPath $scratchReviewDir)) {
  $null = New-Item -ItemType Directory -Path $scratchReviewDir -Force
}

$reviewIdentity = if ([string]::IsNullOrWhiteSpace($ReviewIdentity)) { $CRP } else { $ReviewIdentity }
$reviewStagingDir = Join-Path $scratchReviewDir $reviewIdentity
if (-not (Test-Path -LiteralPath $reviewStagingDir)) {
  $null = New-Item -ItemType Directory -Path $reviewStagingDir -Force
}

# Left-hand side: identifies the local target commit and the committed rules snapshot used to replace a junction.
$rulesBaselineSegment = if ($baselineDescriptor -and -not [string]::IsNullOrWhiteSpace($baselineDescriptor.RulesBaselineCommit)) {
  $rulesBaselineSha = $baselineDescriptor.RulesBaselineCommit.Substring(0, [Math]::Min(7, $baselineDescriptor.RulesBaselineCommit.Length))
  "rules-$($baselineDescriptor.RulesBaselineSource)-$rulesBaselineSha"
}
else {
  'rules-none'
}
$reviewFolderStem = if ($commitSha -ne 'unborn') {
  "Baseline_${repoName}_local-${commitSha}_${rulesBaselineSegment}"
} else {
  "Baseline_${repoName}_unborn_${rulesBaselineSegment}"
}
$tempReviewRoot = Join-Path $reviewStagingDir $reviewFolderStem

# The lifecycle review directory is scoped by its exact CRP/BUG identity.
$liveJunctionStem = "Live_${repoName}"
$liveJunction = Join-Path $reviewStagingDir $liveJunctionStem
$baselineManifestFile = Join-Path $tempReviewRoot ".lcm_baseline_manifest.json"

$reuseCache = $false
if (-not $ForceRebuild -and (Test-Path -LiteralPath $tempReviewRoot) -and (Test-Path -LiteralPath $baselineManifestFile)) {
  # Verify that cache contains files and valid manifest
  try {
    $existingManifestJson = Get-Content -LiteralPath $baselineManifestFile -Raw -Encoding UTF8 -ErrorAction Stop
    if (-not [string]::IsNullOrWhiteSpace($existingManifestJson)) {
      $reuseCache = $true
    }
  }
  catch {
    $reuseCache = $false
  }
}

if ($reuseCache) {
  Write-Host ("[CACHE HIT] Reusing existing verified baseline cache: {0}" -f $reviewFolderStem) -ForegroundColor Green
}
else {
  if (Test-Path -LiteralPath $tempReviewRoot) {
    Remove-Item -LiteralPath $tempReviewRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
  $null = New-Item -ItemType Directory -Path $tempReviewRoot -Force

  Write-Host ("Exporting baseline commit [{0}: {1}] to temp review directory..." -f $commitSha, $commitMsg) -ForegroundColor Cyan

  if ($baselineDescriptor) {
    Export-BCompareBaseline -Descriptor $baselineDescriptor -DestinationPath $tempReviewRoot
  }

  # ------------------------------------------------------------------------------
  # 4. Generate Baseline Manifest for Staging Audits
  # ------------------------------------------------------------------------------
  $baselineManifest = @{}
  $baselineFiles = @(Get-ChildItem -LiteralPath $tempReviewRoot -Recurse -File | Where-Object { $_.Name -ne 'archive.tar' })
  foreach ($bf in $baselineFiles) {
    try {
      $rel = $bf.FullName.Substring($tempReviewRoot.Length).TrimStart('\')
      if ([System.IO.File]::Exists($bf.FullName)) {
        $baselineManifest[$rel] = Get-FileSha256 -FilePath $bf.FullName
      }
    }
    catch {}
  }
  $baselineManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $baselineManifestFile -Encoding UTF8
}

# ------------------------------------------------------------------------------
# 5. Construct Authoritative Exclusion Filter List
# ------------------------------------------------------------------------------
$filterList = [System.Collections.Generic.List[string]]::new()

if ($repoPath -eq $workspaceRoot) {
  $keepDirs = @('.copilot', '.vscode', '.github', '.git')
  $allDirs = @(Get-ChildItem -LiteralPath $workspaceRoot -Directory -Force)
  foreach ($d in $allDirs) {
    if ($d.Name -notin $keepDirs) {
      $filterList.Add("-$($d.Name)\")
      $filterList.Add("-*\$($d.Name)\*")
    }
  }
}
elseif ($repoName -ne 'LCM_AI') {
  # Exclude external tool junction directories (.copilot) for child repos while allowing .agents\rules to be traversed transparently via FollowSymLinks
  $junctionFilters = @('-.copilot\Rules\', '-*\.copilot\Rules\*', '-.copilot\skills\', '-*\.copilot\skills\*')
  foreach ($jf in $junctionFilters) {
    if (-not $filterList.Contains($jf)) {
      $filterList.Add($jf)
    }
  }
}

$standardExclusions = @(
  '-.git\', '-*\.git\*', '-.git*',
  '-.venv\', '-*\.venv\*', '-venv\', '-*\venv\*',
  '-.env\', '-*\.env\*',
  '-__pycache__\', '-*\__pycache__\*', '-*.pyc', '-*.pyo',
  '-scratch\', '-*\scratch\*',
  '-logs\', '-*\logs\*',
  '-work\', '-*\work\*',
  '-data\', '-*\data\*',
  '-*.inventory', '-data\inventory.json', '-inventory.json',
  '-*.log', '-*.tmp', '-*.bak', '-*.swp', '-*.lock',
  '-node_modules\', '-*\node_modules\*',
  '-bin\', '-*\bin\*',
  '-obj\', '-*\obj\*',
  '-.lcm\logs\', '-*\.lcm\logs\*',
  '-.lcm\scratch\', '-*\.lcm\scratch\*',
  '-.lcm\archive\', '-*\.lcm\archive\*',
  '-.lcm\tools\links\', '-*\.lcm\tools\links\*'
)

foreach ($ex in $standardExclusions) {
  if (-not $filterList.Contains($ex)) {
    $filterList.Add($ex)
  }
}

if ($Exclusions -and $Exclusions.Count -gt 0) {
  foreach ($userEx in $Exclusions) {
    if (-not [string]::IsNullOrWhiteSpace($userEx)) {
      $formatted = $userEx.Trim()
      if (-not $formatted.StartsWith('-') -and -not $formatted.StartsWith('+')) {
        $formatted = "-$formatted"
      }
      if (-not $filterList.Contains($formatted)) {
        $filterList.Add($formatted)
      }
    }
  }
}

$filterMask = ($filterList -join ';')

# ------------------------------------------------------------------------------
# 6. Establish Dedicated Per-CRP Review Bridge & Update Review Session
# ------------------------------------------------------------------------------
# Purge any stale live junction for this repo in this CRP directory (exact name match — no suffix).
$oldJunctions = @(Get-ChildItem -LiteralPath $reviewStagingDir -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "Live_${repoName}" -and $_.LinkType -eq 'Junction' })
foreach ($oj in $oldJunctions) {
  try { [System.IO.Directory]::Delete($oj.FullName, $false) } catch {}
}
if (Test-Path -LiteralPath $liveJunction) {
  try { [System.IO.Directory]::Delete($liveJunction, $false) } catch {}
}
New-Item -ItemType Junction -Path $liveJunction -Target $repoPath | Out-Null

$junctionBaseline = Join-Path $scratchReviewDir "ACTIVE_BASELINE"
$junctionLiveRoot = Join-Path $scratchReviewDir "ACTIVE_LIVE"
if (Test-Path -LiteralPath $junctionBaseline) {
  try { [System.IO.Directory]::Delete($junctionBaseline, $false) } catch {}
}
if (Test-Path -LiteralPath $junctionLiveRoot) {
  try { [System.IO.Directory]::Delete($junctionLiveRoot, $false) } catch {}
}
New-Item -ItemType Junction -Path $junctionBaseline -Target $tempReviewRoot | Out-Null
New-Item -ItemType Junction -Path $junctionLiveRoot -Target $repoPath | Out-Null

$sessionName = "${reviewIdentity}_Review"

# Update BCSessions.xml for both the dedicated CRP session and legacy LCM_Review.
# The right-pane bridge retains the CRP-specific display name while targeting the live repository.
if (-not $NoLaunch) {
  Update-BCReviewSession -LeftPath $tempReviewRoot -RightPath $liveJunction -FilterMask $filterMask -SessionName $sessionName
  Update-BCReviewSession -LeftPath $tempReviewRoot -RightPath $liveJunction -FilterMask $filterMask -SessionName 'LCM_Review'
}

$sessionMeta = [ordered]@{
  RepositoryName   = $repoName
  RepositoryPath   = $repoPath
  BaseCommit       = $commitSha
  BaselineIdentity = "local-$commitSha"
  RulesAuthorityRepository = if ($baselineDescriptor) { $baselineDescriptor.RulesAuthorityPath } else { $null }
  RulesAuthorityCommit = if ($baselineDescriptor) { $baselineDescriptor.RulesAuthorityCommit } else { $null }
  RulesAuthorityPath = if ($baselineDescriptor) { $baselineDescriptor.RulesAuthorityRelativePath } else { $null }
  RulesAuthorityContentPresent = if ($baselineDescriptor) { $baselineDescriptor.RulesAuthorityContentPresent } else { $false }
  RulesBaselineRepository = if ($baselineDescriptor) { $baselineDescriptor.RulesBaselineRepositoryPath } else { $null }
  RulesBaselineCommit = if ($baselineDescriptor) { $baselineDescriptor.RulesBaselineCommit } else { $null }
  RulesBaselinePath = if ($baselineDescriptor) { $baselineDescriptor.RulesBaselineRelativePath } else { $null }
  RulesBaselineSource = if ($baselineDescriptor) { $baselineDescriptor.RulesBaselineSource } else { 'none' }
  CommitMessage    = $commitMsg
  CommitDate       = if ($commitSha -ne 'unborn') { (git -C $repoPath log -n 1 --pretty=format:"%cI" $commitSha) } else { (Get-Date).ToString("o") }
  SessionStartedAt = (Get-Date).ToString("o")
  FilterMask       = $filterMask
  ReviewIdentity   = $reviewIdentity
  ReviewType       = 'Lifecycle'
}
$sessionMeta['CRP'] = $CRP
$sessionMeta | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $tempReviewRoot ".lcm_review.json") -Encoding utf8
$sessionMeta | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $reviewStagingDir ".lcm_review.json") -Encoding utf8
$sessionFiles = @(
  (Join-Path $tempReviewRoot ".lcm_review.json"),
  (Join-Path $reviewStagingDir ".lcm_review.json")
)
if (@($sessionFiles | Where-Object { -not (Test-Path -LiteralPath $_) }).Count -gt 0) {
  throw "Lifecycle BCR session metadata was not materialized on disk for '$reviewIdentity'."
}

# Freeze baseline metadata timestamps to commit date so NTFS does not stamp baseline root with 'now'
$metaCommitTime = if ($commitSha -ne 'unborn') {
  $dateStr = (& git -C $repoPath log -n 1 --pretty=format:"%cI" $commitSha 2>$null)
  if (-not [string]::IsNullOrWhiteSpace($dateStr)) { [System.DateTime]::Parse($dateStr) } else { [System.DateTime]::UtcNow }
} else { [System.DateTime]::UtcNow }

$reviewJsonPath = Join-Path $tempReviewRoot ".lcm_review.json"
if (Test-Path -LiteralPath $baselineManifestFile) {
  [System.IO.File]::SetCreationTime($baselineManifestFile, $metaCommitTime)
  [System.IO.File]::SetLastWriteTime($baselineManifestFile, $metaCommitTime)
}
if (Test-Path -LiteralPath $reviewJsonPath) {
  [System.IO.File]::SetCreationTime($reviewJsonPath, $metaCommitTime)
  [System.IO.File]::SetLastWriteTime($reviewJsonPath, $metaCommitTime)
}

$tempChildren = @(Get-ChildItem -LiteralPath $tempReviewRoot -Force | Where-Object { $_.Name -notin @('.lcm_baseline_manifest.json', '.lcm_review.json') })
if ($tempChildren.Count -gt 0) {
  $maxTime = ($tempChildren | Measure-Object -Property LastWriteTime -Maximum).Maximum
  if ($maxTime) {
    [System.IO.Directory]::SetCreationTime($tempReviewRoot, $maxTime)
    [System.IO.Directory]::SetLastWriteTime($tempReviewRoot, $maxTime)
  }
}

$title1 = "$repoName local-$commitSha ($rulesBaselineSegment)"
$title2 = if (-not [string]::IsNullOrWhiteSpace($CRP)) {
  "Live $repoName [$CRP]"
}
else {
  "Live $repoName"
}

$null = Get-BeyondCompareReviewAcceptanceContext -RepoName $repoName -CRP $CRP

if (-not [string]::IsNullOrWhiteSpace($CRP)) {
  $newObligations = @(Register-DiscoveredCrossRepositoryReviewObligations -WorkspaceRoot $workspaceRoot -RepositoryName $repoName -CRP $CRP -BaselineDescriptor $baselineDescriptor)
  foreach ($obligation in $newObligations) {
    Write-Host "Lifecycle BCR obligation active for $($obligation.repository): $($obligation.id)" -ForegroundColor Yellow
  }
}

if ($NoLaunch) {
  Write-Host "Prepared lifecycle review staging without launching Beyond Compare." -ForegroundColor DarkGray
  return
}
else {
$existingReviewProcesses = @(Get-SameRepositoryBCompareProcess -RepositoryName $repoName -Process @(Get-Process -Name 'BCompare' -ErrorAction SilentlyContinue) -CRP $CRP)
if ($existingReviewProcesses.Count -gt 1) {
  # If duplicate windows exist for the exact same comparison, close surplus instances keeping only the primary
  Write-Host "Closing surplus duplicate Beyond Compare windows (Count: $($existingReviewProcesses.Count))..." -ForegroundColor DarkYellow
  $surplus = @($existingReviewProcesses | Select-Object -Skip 1)
  foreach ($s in $surplus) {
    Stop-Process -Id $s.Id -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "Activating Beyond Compare on interactive desktop (Per-CRP Single Window)..." -ForegroundColor Green
Write-Host ("  Session Name:        {0}" -f $sessionName)
Write-Host ("  Left (Baseline {0}): {1}" -f $commitSha, $tempReviewRoot)
Write-Host ("  Right (Live Bridge): {0} -> {1}" -f $liveJunction, $repoPath)
Write-Host ("  Pane Titles:         [Left: '{0}'] <--> [Right: '{1}']" -f $title1, $title2)
Write-Host ("  Filters Applied:     {0}" -f $filterMask)

# Open session with /solo so each CRP opens in its own dedicated top-level window per cohort isolation invariant
$bcArgString = "/solo `"$sessionName`""

$dispatcherCandidates = @(
  (Join-Path $workspaceRoot "LCM_Inventory\tools\Invoke-InteractiveDesktop.ps1"),
  (Join-Path $workspaceRoot ".lcd\tools\internal\Invoke-InteractiveDesktop.ps1"),
  (Join-Path $workspaceRoot "tools\Invoke-InteractiveDesktop.ps1")
)

$dispatcherPath = $null
foreach ($cand in $dispatcherCandidates) {
  if (Test-Path -LiteralPath $cand) {
    $dispatcherPath = $cand
    break
  }
}
}

# ------------------------------------------------------------------------------
# Dispatch Beyond Compare 5 via Port 9876 Session 1 Desktop Daemon
# ------------------------------------------------------------------------------
$daemonPort = if ($env:LCM_DAEMON_PORT -match '^\d+$') { [int]$env:LCM_DAEMON_PORT } else { 9876 }
$daemonOnline = $false
try {
  $ping = Invoke-RestMethod -Uri "http://127.0.0.1:$daemonPort/ping" -TimeoutSec 1 -ErrorAction Stop
  if ($ping -and $ping.status -eq 'ONLINE') { $daemonOnline = $true }
} catch {}

$runningReview = @(Get-CimInstance Win32_Process -Filter "Name = 'BCompare.exe'" -ErrorAction SilentlyContinue | Where-Object {
  $_.CommandLine -and ($_.CommandLine -like "*$sessionName*" -or ($CRP -and $_.CommandLine -like "*$CRP*"))
})

if ($runningReview.Count -gt 0) {
  Write-Host "Review session '$sessionName' is already open in Beyond Compare; bringing window to focus without opening duplicate tab." -ForegroundColor Green
  if ($daemonOnline) {
    try {
      $null = Invoke-RestMethod -Uri "http://127.0.0.1:$daemonPort/foreground" -Method Post -Body (@{ title = "Beyond Compare" } | ConvertTo-Json) -ContentType "application/json" -TimeoutSec 2 -ErrorAction SilentlyContinue
    } catch {}
  } else {
    try {
      $wsh = New-Object -ComObject WScript.Shell
      $null = $wsh.AppActivate("Beyond Compare")
    } catch {}
  }
} else {
  if ($daemonOnline) {
    Write-Host "Dispatching Beyond Compare review window to Interactive Desktop via Port $daemonPort Daemon..." -ForegroundColor Green
    $execPayload = @{
      command = "& `"$BeyondComparePath`" /solo $sessionName"
      windowStyle = "Hidden"
    } | ConvertTo-Json
    $null = Invoke-RestMethod -Uri "http://127.0.0.1:$daemonPort/execute" -Method Post -Body $execPayload -ContentType "application/json" -TimeoutSec 5
    Start-Sleep -Milliseconds 300
    try {
      $null = Invoke-RestMethod -Uri "http://127.0.0.1:$daemonPort/foreground" -Method Post -Body (@{ title = "Beyond Compare" } | ConvertTo-Json) -ContentType "application/json" -TimeoutSec 2 -ErrorAction SilentlyContinue
    } catch {}
  } elseif ($dispatcherPath) {
    & pwsh -File $dispatcherPath -FilePath $BeyondComparePath -ArgumentList $bcArgString | Out-Null
  } else {
    Start-Process -FilePath $BeyondComparePath -ArgumentList @('/solo', $sessionName)
  }
}

# If this CRP affects additional repositories with physical uncommitted changes, open each as a tab in the same window
if (-not [string]::IsNullOrWhiteSpace($CRP)) {
  $pJson = Join-Path $workspaceRoot "LCM_Inventory\data\proposals\proposals.json"
  if (Test-Path -LiteralPath $pJson) {
    try {
      $pData = Get-Content -LiteralPath $pJson -Raw -Encoding UTF8 | ConvertFrom-Json
      $matchedP = $pData.proposals | Where-Object {
        $proposalCrpId = if ($_.PSObject.Properties['crp_id']) { [string]$_.crp_id } else { '' }
        $proposalCrId = if ($_.PSObject.Properties['cr_id']) { [string]$_.cr_id } else { '' }
        $proposalCrpId -eq $CRP -or $proposalCrId -eq $CRP -or "CRP-$($_.id)" -eq $CRP
      } | Select-Object -First 1

      if ($matchedP) {
        $otherCandidates = @()
        if ($matchedP.PSObject.Properties['impacted_repos'] -and $matchedP.impacted_repos) {
          $otherCandidates += @($matchedP.impacted_repos)
        }
        if ($matchedP.PSObject.Properties['affected_repos'] -and $matchedP.affected_repos) {
          $otherCandidates += @($matchedP.affected_repos)
        }
        if ($baselineDescriptor -and -not [string]::IsNullOrWhiteSpace($baselineDescriptor.RulesBaselineRepositoryPath)) {
          $rulesAuthorityPath = [System.IO.Path]::GetFullPath($baselineDescriptor.RulesBaselineRepositoryPath).TrimEnd('\')
          $workspaceRootPath = [System.IO.Path]::GetFullPath($workspaceRoot).TrimEnd('\')
          if ((Split-Path -Parent $rulesAuthorityPath).Equals($workspaceRootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $otherCandidates += (Split-Path -Leaf $rulesAuthorityPath)
          }
        }
        $otherCandidates = @($otherCandidates | Select-Object -Unique | Where-Object { $_ -and $_ -ne $repoName })

        foreach ($otherRepo in $otherCandidates) {
          $otherRepoPath = Join-Path $workspaceRoot $otherRepo
          if (Test-Path -LiteralPath (Join-Path $otherRepoPath '.git')) {
            $diffCheck = (git -C $otherRepoPath status --porcelain 2>$null)
            if (-not [string]::IsNullOrWhiteSpace($diffCheck)) {
              $otherSession = "${CRP}_${otherRepo}_Review"
              $runningOther = @(Get-CimInstance Win32_Process -Filter "Name = 'BCompare.exe'" -ErrorAction SilentlyContinue | Where-Object {
                $_.CommandLine -and $_.CommandLine -like "*$otherSession*"
              })
              if ($runningOther.Count -eq 0) {
                Write-Host "Opening additional tab for affected repository with physical changes: $otherRepo" -ForegroundColor Cyan
                $otherScratchDir = Join-Path $scratchReviewDir "${reviewIdentity}_${otherRepo}"
                if (-not (Test-Path -LiteralPath $otherScratchDir)) {
                  New-Item -ItemType Directory -Path $otherScratchDir -Force | Out-Null
                }
                $otherDesc = Get-BCompareBaselineDescriptor -RepositoryPath $otherRepoPath -BaseCommit 'HEAD'
                if ($otherDesc) {
                  Export-BCompareBaseline -Descriptor $otherDesc -DestinationPath $otherScratchDir
                }
                $otherJunction = Join-Path $otherScratchDir "ACTIVE_LIVE_${otherRepo}"
                if (Test-Path -LiteralPath $otherJunction) {
                  try { [System.IO.Directory]::Delete($otherJunction, $false) } catch {}
                }
                New-Item -ItemType Junction -Path $otherJunction -Target $otherRepoPath | Out-Null
                Update-BCReviewSession -LeftPath $otherScratchDir -RightPath $otherJunction -FilterMask $filterMask -SessionName $otherSession
                Start-Sleep -Milliseconds 400
                if ($daemonOnline) {
                  $otherPayload = @{
                    command = "& `"$BeyondComparePath`" /solo `"$otherSession`""
                    windowStyle = "Hidden"
                  } | ConvertTo-Json
                  $null = Invoke-RestMethod -Uri "http://127.0.0.1:$daemonPort/execute" -Method Post -Body $otherPayload -ContentType "application/json" -TimeoutSec 5
                } elseif ($dispatcherPath) {
                  & pwsh -File $dispatcherPath -FilePath $BeyondComparePath -ArgumentList "/solo `"$otherSession`"" | Out-Null
                } else {
                  Start-Process -FilePath $BeyondComparePath -ArgumentList @('/solo', $otherSession)
                }
              } else {
                Write-Host "Additional tab for '$otherRepo' is already open in Beyond Compare." -ForegroundColor Green
              }
            }
          }
        }
      }
    } catch {
      Write-Warning "Could not enumerate additional affected repo tabs: $_"
    }
  }
}

# ------------------------------------------------------------------------------
# 7. Single-Session Beyond Compare Review (Transparent Junction Traversal)
# ------------------------------------------------------------------------------
# Beyond Compare 5 traverses NTFS directory junctions (.agents\rules) inline within
# the primary session via FollowSymLinks='True'. Dual-session dispatch is retired.

if ($Wait) {
  Write-Host "Waiting for Beyond Compare review session to close..." -ForegroundColor DarkGray
  Get-BeyondCompareReviewAcceptanceContext -RepoName $repoName -CRP $CRP
}
