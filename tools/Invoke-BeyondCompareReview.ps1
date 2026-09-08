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

  [Parameter(Mandatory = $false, HelpMessage = 'CRP or Change Request identifier (e.g. CRP-2026-005, CR-2026-034)')]
  [Alias('Cr', 'ChangeRequest', 'Proposal', 'ProposalId')]
  [string]$CRP = '',

  [Parameter(Mandatory = $false)]
  [string]$BeyondComparePath = 'D:\Tools\Beyond Compare 5\BCompare.exe',

  [Parameter(Mandatory = $false)]
  [switch]$Wait,

  [Alias('h', '?')]
  [switch]$Help
)

<#
.SYNOPSIS
    Compares a repository's current state against any prior commit in Beyond Compare 5 with interactive review staging.
.DESCRIPTION
    Module: tools/Invoke-BeyondCompareReview.ps1
    Purpose: Compares a repository's current state against any prior commit in Beyond Compare 5 with interactive review staging,
             automatic exclusion of .venv/cache/scratch directories, 4-directive action parsing (Accept, Delete, Rename, Defer),
             and SHA-256 staging manifest generation.
    Path: tools/Invoke-BeyondCompareReview.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 2.3.1
    Date: 2026-09-08
.PARAMETER RepositoryName
    The name or directory path of the Git repository to review (e.g. 'AuthorizeMasterUser', 'Git_Repositories', '.').
.PARAMETER BaseCommit
    The base Git commit to compare against (e.g. 'HEAD~1', 'HEAD', 'root', SHA). Defaults to 'HEAD'.
.PARAMETER Exclusions
    Additional file or directory exclusion masks (Aliases: -Exclude, -Filters). Standard LCM exclusions are always applied.
.PARAMETER BeyondComparePath
    Path to BCompare.exe executable. Defaults to 'D:\Tools\Beyond Compare 5\BCompare.exe'.
.PARAMETER Wait
    Wait synchronously for the Beyond Compare review session to close before evaluating staging.
.PARAMETER Help
    Displays this parameter reference (Aliases: -h, -?).
.EXAMPLE
    pwsh tools/Invoke-BeyondCompareReview.ps1 -RepositoryName Git_Repositories
.EXAMPLE
    pwsh tools/Invoke-BeyondCompareReview.ps1 -RepositoryName AuthorizeMasterUser -BaseCommit HEAD~1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "2.3.0"
$scriptName = "Invoke-BeyondCompareReview"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " BEYOND COMPARE 5 REPOSITORY REVIEW LAUNCHER (v$scriptVersion)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Exports the local Git HEAD baseline to a temporary inspection tree and opens"
  Write-Host "  Beyond Compare 5 on your interactive desktop with out-of-scope filter exclusions."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Invoke-BeyondCompareReview.ps1 [-RepositoryName <repo>] [-BaseCommit <commit>] [-Exclusions <array>] [-Wait] [-h]"
  Write-Host "  BCR [-RepositoryName <repo>] [-BaseCommit <commit>]"
  Write-Host ""
  Write-Host "REVIEW DIRECTIVES (APPLIED IN LEFT PANE):" -ForegroundColor Yellow
  Write-Host "  1. Copy Right -> Left     : Staged for ACCEPTANCE upon 'ACCEPT' command."
  Write-Host "  2. Line 'Delete' on Left  : Permanently DELETE file on disk and in Git."
  Write-Host "  3. Line 'Rename [to] X'   : RENAME file on disk and in Git to X (cleans up old file)."
  Write-Host "  4. Leave Left Untouched   : Skipped / remains uncommitted in working directory."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
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
    $itemsFolder = $xml.BCSessions.TSessionFolder.Items

    $sessionNode = $itemsFolder.SelectSingleNode("TDirCompareSession[@Value='$SessionName']")
    if (-not $sessionNode) {
      $sessionNode = $xml.CreateElement('TDirCompareSession')
      $sessionNode.SetAttribute('Value', $SessionName)
      $null = $itemsFolder.PrependChild($sessionNode)
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

    $xml.Save($bcSessionsPath)
  }
  catch {
    Write-Verbose "Could not update BCSessions.xml: $($_.Exception.Message)"
  }
}

function Audit-BeyondCompareReviewStaging {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$TempReviewRoot,

    [Parameter(Mandatory = $true)]
    [string]$RepoPath,

    [Parameter(Mandatory = $true)]
    [string]$RepoName,

    [Parameter(Mandatory = $true)]
    [string]$CommitSha
  )

  $reviewsDir = "D:\Git_Repositories\Workspace_Inventory\data\reviews"
  if (-not (Test-Path $reviewsDir)) { New-Item -ItemType Directory -Path $reviewsDir -Force | Out-Null }

  $baselineManifestPath = Join-Path $TempReviewRoot ".lcm_baseline_manifest.json"
  $baselineManifest = @{}
  if (Test-Path -LiteralPath $baselineManifestPath) {
    try {
      $json = Get-Content -LiteralPath $baselineManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($json) {
        foreach ($prop in $json.PSObject.Properties) {
          $baselineManifest[$prop.Name] = [string]$prop.Value
        }
      }
    }
    catch {}
  }

  function Get-FileSha256([string]$filePath) {
    if (-not (Test-Path -LiteralPath $filePath)) { return $null }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    $hashBytes = $sha.ComputeHash($bytes)
    return [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant()
  }

  function Test-PathExcluded([string]$relPath) {
    if ($relPath -like ".git*" -or $relPath -like "*\.git\*" -or $relPath -like "*\logs\*" -or $relPath -like "logs\*" -or $relPath -like "*\scratch\*" -or $relPath -like "scratch\*" -or $relPath -like "*.log" -or $relPath -like "*.tmp" -or $relPath -like ".venv*" -or $relPath -like "*\.venv\*") {
      return $true
    }
    if ($RepoPath -ne $workspaceRoot) {
      if ($relPath -like ".agents\rules*" -or $relPath -like "*\.agents\rules\*" -or $relPath -like ".copilot\Rules*" -or $relPath -like "*\.copilot\Rules\*") {
        return $true
      }
    }
    return $false
  }

  # Scan Right files
  $rightFileList = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
  $scannedFiles = @(Get-ChildItem -LiteralPath $RepoPath -Recurse -File | Where-Object {
      $rel = $_.FullName.Substring($RepoPath.Length).TrimStart('\')
      -not (Test-PathExcluded $rel)
    })
  if ($scannedFiles.Count -gt 0) { $rightFileList.AddRange($scannedFiles) }

  # Include files from directory junctions (e.g. .agents / .agents\rules) per RULE-REV-008
  $auditJunctions = @((Join-Path $RepoPath ".agents"), (Join-Path $RepoPath ".agents\rules"))
  foreach ($aj in $auditJunctions) {
    if (Test-Path -LiteralPath $aj) {
      try {
        $jItem = Get-Item -LiteralPath $aj -Force -ErrorAction SilentlyContinue
        if ($jItem -and $jItem.LinkType -eq 'Junction' -and -not [string]::IsNullOrWhiteSpace($jItem.Target)) {
          $targetDir = [string]$jItem.Target
          if (Test-Path -LiteralPath $targetDir) {
            $jFiles = @(Get-ChildItem -LiteralPath $targetDir -Recurse -File | Where-Object {
                $subRel = $_.FullName.Substring($targetDir.Length).TrimStart('\')
                $junctionRel = [System.IO.Path]::GetRelativePath($RepoPath, (Join-Path $jItem.FullName $subRel))
                -not (Test-PathExcluded $junctionRel)
              })
            foreach ($jf in $jFiles) {
              $subRel = $jf.FullName.Substring($targetDir.Length).TrimStart('\')
              $mappedPath = Join-Path $jItem.FullName $subRel
              if (Test-Path -LiteralPath $mappedPath) {
                $rightFileList.Add([System.IO.FileInfo]::new($mappedPath))
              }
            }
          }
          if ($jItem.Name -eq '.agents') { break }
        }
      }
      catch {}
    }
  }
  $rightFiles = @($rightFileList)

  # Scan Left files
  $leftFiles = @(Get-ChildItem -LiteralPath $TempReviewRoot -Recurse -File | Where-Object {
      $_.Name -ne '.lcm_review.json' -and $_.Name -ne '.lcm_baseline_manifest.json' -and $_.Name -ne 'archive.tar'
    })

  $acceptedFiles = [System.Collections.Generic.List[PSCustomObject]]::new()
  $renameFiles = [System.Collections.Generic.List[PSCustomObject]]::new()
  $deleteFiles = [System.Collections.Generic.List[PSCustomObject]]::new()
  $uncopiedFiles = [System.Collections.Generic.List[PSCustomObject]]::new()
  $rejectedEmpty = [System.Collections.Generic.List[PSCustomObject]]::new()

  $evaluatedLeftRelPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

  foreach ($lf in $leftFiles) {
    $rel = $lf.FullName.Substring($TempReviewRoot.Length).TrimStart('\')
    $null = $evaluatedLeftRelPaths.Add($rel)

    $rfPath = Join-Path $RepoPath $rel
    $leftContent = [System.IO.File]::ReadAllText($lf.FullName, [System.Text.Encoding]::UTF8)

    if ([string]::IsNullOrWhiteSpace($leftContent)) {
      $rejectedEmpty.Add([PSCustomObject]@{ RelativePath = $rel; FullPath = $lf.FullName; Reason = "Empty content" })
      continue
    }

    $lines = $leftContent.Trim().Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        
    # Check Delete
    if ($lines.Count -eq 1 -and ($lines[0] -match '^(?i)(?:#|//|;|--)?\s*delete\s*$')) {
      $deleteFiles.Add([PSCustomObject]@{
          RelativePath = $rel
          LivePath     = $rfPath
          Directive    = "DELETE"
        })
      continue
    }

    # Check Rename
    if ($lines.Count -eq 1 -and ($lines[0] -match '^(?i)(?:#|//|;|--)?\s*rename\s+(?:to\s+)?([^\s\r\n]+)\s*$')) {
      $rawTarget = $Matches[1]
      $sourceExt = [System.IO.Path]::GetExtension($rel)
      $targetExt = [System.IO.Path]::GetExtension($rawTarget)
      $targetName = if ([string]::IsNullOrWhiteSpace($targetExt) -and -not [string]::IsNullOrWhiteSpace($sourceExt)) {
        $rawTarget + $sourceExt
      }
      else {
        $rawTarget
      }
      $targetRel = if ($rel -match '^(.*\\)[^\\]+$') { $Matches[1] + $targetName } else { $targetName }
      $targetLivePath = Join-Path $RepoPath $targetRel

      $renameFiles.Add([PSCustomObject]@{
          OldRelativePath = $rel
          OldLivePath     = $rfPath
          NewRelativePath = $targetRel
          NewLivePath     = $targetLivePath
          Directive       = "RENAME"
        })
      continue
    }

    $leftHash = Get-FileSha256 $lf.FullName
    $rightHash = if (Test-Path -LiteralPath $rfPath) { Get-FileSha256 $rfPath } else { $null }
    $baselineHash = if ($baselineManifest.ContainsKey($rel)) { $baselineManifest[$rel] } else { $null }

    if ($leftHash -and $rightHash -and $leftHash -eq $rightHash) {
      if ($leftHash -ne $baselineHash) {
        $acceptedFiles.Add([PSCustomObject]@{
            RelativePath = $rel
            LivePath     = $rfPath
            Hash         = $leftHash
            Status       = "ACCEPTED"
          })
      }
    }
    elseif ($leftHash -eq $baselineHash -and $rightHash -and $leftHash -ne $rightHash) {
      $uncopiedFiles.Add([PSCustomObject]@{
          RelativePath = $rel
          LivePath     = $rfPath
          Status       = "UNCOPIED_MODIFIED"
        })
    }
  }

  foreach ($rf in $rightFiles) {
    $rel = $rf.FullName.Substring($RepoPath.Length).TrimStart('\')
    if (-not $evaluatedLeftRelPaths.Contains($rel)) {
      $uncopiedFiles.Add([PSCustomObject]@{
          RelativePath = $rel
          LivePath     = $rf.FullName
          Status       = "UNCOPIED_NEW"
        })
    }
  }

  $stagingManifest = [ordered]@{
    RepositoryName = $RepoName
    RepositoryPath = $RepoPath
    BaselineCommit = $CommitSha
    TempReviewRoot = $TempReviewRoot
    Timestamp      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Accepted       = $acceptedFiles
    Renames        = $renameFiles
    Deletions      = $deleteFiles
    Uncopied       = $uncopiedFiles
    RejectedEmpty  = $rejectedEmpty
  }

  $manifestFile = Join-Path $reviewsDir "staged_review_${RepoName}.json"
  $stagingManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestFile -Encoding UTF8

  Write-Host ""
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " BEYOND COMPARE INTERACTIVE REVIEW STAGING EVALUATION" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " Repository      : $RepoName"
  Write-Host " Baseline Commit : $CommitSha"
  Write-Host " Staging Record  : $manifestFile" -ForegroundColor DarkCyan
  Write-Host "--------------------------------------------------------------------------"

  if ($acceptedFiles.Count -gt 0) {
    Write-Host " [STAGED FOR ACCEPTANCE] ($($acceptedFiles.Count) files):" -ForegroundColor Green
    foreach ($af in $acceptedFiles) { Write-Host "   + $($af.RelativePath)" -ForegroundColor Green }
  }

  if ($renameFiles.Count -gt 0) {
    Write-Host " [RENAMES REQUESTED] ($($renameFiles.Count) files):" -ForegroundColor Yellow
    foreach ($rf in $renameFiles) { Write-Host "   -> $($rf.OldRelativePath) => $($rf.NewRelativePath)" -ForegroundColor Yellow }
  }

  if ($deleteFiles.Count -gt 0) {
    Write-Host " [MARKED FOR DELETION] ($($deleteFiles.Count) files):" -ForegroundColor Red
    foreach ($df in $deleteFiles) { Write-Host "   x $($df.RelativePath)" -ForegroundColor Red }
  }

  if ($uncopiedFiles.Count -gt 0) {
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkYellow
    Write-Host " [UNCOPIED FILES DETECTED] ($($uncopiedFiles.Count) files):" -ForegroundColor DarkYellow
    Write-Host " (These files were modified/created on Right but NOT copied to Left)" -ForegroundColor DarkGray
    foreach ($uf in $uncopiedFiles) { Write-Host "   ? $($uf.RelativePath) [$($uf.Status)]" -ForegroundColor DarkYellow }
  }

  if ($rejectedEmpty.Count -gt 0) {
    Write-Host " [REJECTED - EMPTY] ($($rejectedEmpty.Count) files):" -ForegroundColor Magenta
    foreach ($re in $rejectedEmpty) { Write-Host "   ! $($re.RelativePath) (0 bytes)" -ForegroundColor Magenta }
  }

  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " Awaiting Operator Command:" -ForegroundColor Yellow
  Write-Host "   - 'ACCEPT'        -> Commits staged files, executes renames & clean deletions."
  if ($uncopiedFiles.Count -gt 0) {
    Write-Host "   - 'ACCEPT ALL'    -> Commits staged files PLUS all uncopied files above."
  }
  Write-Host "   - 'REJECT'        -> Discards review staging; zero changes committed."
  Write-Host "==========================================================================" -ForegroundColor Cyan

  return $stagingManifest
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

if (-not (Test-Path -LiteralPath $BeyondComparePath)) {
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

# ------------------------------------------------------------------------------
# 3. Export Baseline Commit into Workspace Scratch Review Inspection Tree (Variant A)
# ------------------------------------------------------------------------------
$scratchReviewDir = Join-Path $workspaceRoot "Workspace_Inventory\scratch\BC_Review"
if (-not (Test-Path -LiteralPath $scratchReviewDir)) {
  $null = New-Item -ItemType Directory -Path $scratchReviewDir -Force
}

$reviewFolderStem = if (-not [string]::IsNullOrWhiteSpace($CRP)) {
  "${CRP}_${repoName}_${commitSha}"
}
else {
  "${repoName}_${commitSha}"
}

$tempReviewRoot = Join-Path $scratchReviewDir $reviewFolderStem

if (Test-Path -LiteralPath $tempReviewRoot) {
  Remove-Item -LiteralPath $tempReviewRoot -Recurse -Force -ErrorAction SilentlyContinue
}
$null = New-Item -ItemType Directory -Path $tempReviewRoot -Force

Write-Host ("Exporting baseline commit [{0}: {1}] to temp review directory..." -f $commitSha, $commitMsg) -ForegroundColor Cyan

if ($commitSha -ne 'unborn') {
  $tarPath = Join-Path $tempReviewRoot "archive.tar"
  git -C $repoPath archive $commitSha -o $tarPath
  tar -xf $tarPath -C $tempReviewRoot
  Remove-Item -LiteralPath $tarPath -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------------------
# 4. Generate Baseline Manifest for Staging Audits
# ------------------------------------------------------------------------------
$baselineManifest = @{}
$baselineFiles = @(Get-ChildItem -LiteralPath $tempReviewRoot -Recurse -File | Where-Object { $_.Name -ne 'archive.tar' })
$sha = [System.Security.Cryptography.SHA256]::Create()
foreach ($bf in $baselineFiles) {
  try {
    $rel = $bf.FullName.Substring($tempReviewRoot.Length).TrimStart('\')
    if ([System.IO.File]::Exists($bf.FullName)) {
      $bytes = [System.IO.File]::ReadAllBytes($bf.FullName)
      $hash = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
      $baselineManifest[$rel] = $hash
    }
  }
  catch {}
}
$baselineManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $tempReviewRoot ".lcm_baseline_manifest.json") -Encoding UTF8

# ------------------------------------------------------------------------------
# 5. Construct Authoritative Exclusion Filter List
# ------------------------------------------------------------------------------
$filterList = [System.Collections.Generic.List[string]]::new()

if ($repoPath -eq $workspaceRoot) {
  $keepDirs = @('.copilot', '.vscode', '.github', '.git', '.lcm')
  $allDirs = @(Get-ChildItem -LiteralPath $workspaceRoot -Directory -Force)
  foreach ($d in $allDirs) {
    if ($d.Name -notin $keepDirs) {
      $filterList.Add("-$($d.Name)\")
      $filterList.Add("-*\$($d.Name)\*")
    }
  }
}
else {
  # Exclude child repo junction directories
  $junctionFilters = @('-.agents\rules\', '-*\.agents\rules\*', '-.copilot\Rules\', '-*\.copilot\Rules\*', '-.copilot\skills\', '-*\.copilot\skills\*')
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

Update-BCReviewSession -LeftPath $tempReviewRoot -RightPath $repoPath -FilterMask $filterMask -SessionName 'LCM_Review'

$sessionMeta = [ordered]@{
  RepositoryName   = $repoName
  RepositoryPath   = $repoPath
  BaseCommit       = $commitSha
  CommitMessage    = $commitMsg
  CommitDate       = if ($commitSha -ne 'unborn') { (git -C $repoPath log -n 1 --pretty=format:"%cI" $commitSha) } else { (Get-Date).ToString("o") }
  SessionStartedAt = (Get-Date).ToString("o")
  FilterMask       = $filterMask
}
$sessionMeta | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $tempReviewRoot ".lcm_review.json") -Encoding utf8

Write-Host "Launching Beyond Compare 5 on interactive desktop..." -ForegroundColor Green
Write-Host ("  Left (Baseline {0}): {1}" -f $commitSha, $tempReviewRoot)
Write-Host ("  Right (Current Live):       {0}" -f $repoPath)
Write-Host ("  Filters Applied:            {0}" -f $filterMask)

$title1 = if (-not [string]::IsNullOrWhiteSpace($CRP)) {
  "Baseline $CRP ($commitSha)"
}
else {
  "Baseline ($commitSha)"
}
$title2 = "Current Live ($repoName)"
$bcArgString = "`"$tempReviewRoot`" `"$repoPath`" `"/title1=$title1`" `"/title2=$title2`" `"/filters=$filterMask`""

$dispatcherCandidates = @(
  (Join-Path $workspaceRoot ".lcm\tools\internal\Invoke-InteractiveDesktop.ps1"),
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

if ($dispatcherPath) {
  & pwsh -File $dispatcherPath -FilePath $BeyondComparePath -ArgumentList $bcArgString | Out-Null
}
else {
  Start-Process -FilePath $BeyondComparePath -ArgumentList @("`"$tempReviewRoot`"", "`"$repoPath`"", "`"/title1=$title1`"", "`"/title2=$title2`"", "`"/filters=$filterMask`"")
}

# ------------------------------------------------------------------------------
# 7. Dual-Session Beyond Compare Review for Directory Junctions (RULE-REV-008)
# ------------------------------------------------------------------------------
# Repositories frequently link .agents or .agents\rules via NTFS directory junctions.
# Beyond Compare 5 does not follow directory junctions across filesystem boundaries by default.
# Per RULE-REV-008, automatically detect any junctions within the repository and dispatch
# a second Beyond Compare review session targeting the live junction destination on the right pane.
$candidateJunctionPaths = @(
  (Join-Path $repoPath ".agents"),
  (Join-Path $repoPath ".agents\rules")
)

$detectedJunctions = @()
foreach ($cPath in $candidateJunctionPaths) {
  if (Test-Path -LiteralPath $cPath) {
    try {
      $item = Get-Item -LiteralPath $cPath -Force -ErrorAction SilentlyContinue
      if ($item -and $item.LinkType -eq 'Junction' -and -not [string]::IsNullOrWhiteSpace($item.Target)) {
        $detectedJunctions += $item
      }
    }
    catch {}
  }
}

$processedJunctions = @()
foreach ($jItem in $detectedJunctions) {
  $rel = [System.IO.Path]::GetRelativePath($repoPath, $jItem.FullName)
  $alreadyCovered = $false
  foreach ($pj in $processedJunctions) {
    if ($rel.StartsWith($pj.RelativePath + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
      $alreadyCovered = $true
      break
    }
  }
  if ($alreadyCovered) { continue }

  $targetPath = [string]$jItem.Target
  if (-not [System.IO.Path]::IsPathRooted($targetPath)) {
    $targetPath = [System.IO.Path]::GetFullPath((Join-Path (Split-Path $jItem.FullName -Parent) $targetPath))
  }
  else {
    $targetPath = [System.IO.Path]::GetFullPath($targetPath)
  }

  if (Test-Path -LiteralPath $targetPath) {
    # Resolve appropriate baseline directory for junction review (BUG-123)
    $leftJunctionPath = Join-Path $tempReviewRoot $rel

    # Case 1: Root Container (Git_Repositories) - committed baseline is in .lcm\.agents
    if ($rel -eq '.agents' -or $rel -like '.agents\*') {
      $lcmAgentsBaseline = Join-Path $tempReviewRoot ('.lcm\' + $rel)
      if (Test-Path -LiteralPath $lcmAgentsBaseline) {
        $leftJunctionPath = $lcmAgentsBaseline
      }
    }

    # Case 2: Child repository where baseline snapshot does not contain junction files
    # Resolve against the authoritative committed baseline of Git_Repositories
    $hasBaselineFiles = (Test-Path -LiteralPath $leftJunctionPath) -and @(Get-ChildItem -LiteralPath $leftJunctionPath -Recurse -File -ErrorAction SilentlyContinue).Count -gt 0
    if (-not $hasBaselineFiles) {
      $canonicalLcmAgents = Join-Path $workspaceRoot '.lcm\.agents'
      if ($targetPath.StartsWith($canonicalLcmAgents, [System.StringComparison]::OrdinalIgnoreCase) -or
          $targetPath.StartsWith((Join-Path $workspaceRoot '.agents'), [System.StringComparison]::OrdinalIgnoreCase)) {
        $subRel = if ($targetPath.Length -gt $canonicalLcmAgents.Length) {
          $targetPath.Substring($canonicalLcmAgents.Length).TrimStart('\', '/')
        } else {
          ''
        }
        $rootHeadSha = (git -C $workspaceRoot rev-parse --short HEAD 2>$null)
        if ($rootHeadSha) {
          $rootReviewSnap = Join-Path (Split-Path $tempReviewRoot -Parent) "Git_Repositories_$rootHeadSha"
          if (-not (Test-Path -LiteralPath $rootReviewSnap)) {
            New-Item -ItemType Directory -Path (Join-Path $rootReviewSnap '.lcm\.agents') -Force | Out-Null
            & git -C $workspaceRoot archive HEAD .lcm/.agents | tar -x -C $rootReviewSnap 2>$null
          }
          $fallbackLeft = Join-Path $rootReviewSnap (Join-Path '.lcm\.agents' $subRel)
          if (Test-Path -LiteralPath $fallbackLeft) {
            $leftJunctionPath = $fallbackLeft
          }
        }
      }
    }

    if (-not (Test-Path -LiteralPath $leftJunctionPath)) {
      New-Item -ItemType Directory -Path $leftJunctionPath -Force | Out-Null
    }

    $processedJunctions += [PSCustomObject]@{
      RelativePath = $rel
      BaselinePath = $leftJunctionPath
      LiveTarget   = $targetPath
    }
  }
}

foreach ($pj in $processedJunctions) {
  Start-Sleep -Milliseconds 500
  Write-Host ("Launching second Beyond Compare review session for junction target '{0}'..." -f $pj.RelativePath) -ForegroundColor Cyan
  Write-Host ("  Left (Baseline {0}): {1}" -f $commitSha, $pj.BaselinePath)
  Write-Host ("  Right (Junction Live Target): {0}" -f $pj.LiveTarget)

  $jSessionName = "LCM_Review_$($pj.RelativePath.Replace('\', '_').TrimStart('.'))"
  $jFilterMask = "-.git\;-*\.git\*;-.git*;-scratch\;-*\scratch\*;-logs\;-*\logs\*;-*.log;-*.tmp;-*.bak"
  Update-BCReviewSession -LeftPath $pj.BaselinePath -RightPath $pj.LiveTarget -FilterMask $jFilterMask -SessionName $jSessionName

  $jTitle1 = if (-not [string]::IsNullOrWhiteSpace($CRP)) {
    "Baseline $CRP ($commitSha) [$($pj.RelativePath)]"
  }
  else {
    "Baseline ($commitSha) [$($pj.RelativePath)]"
  }
  $jTitle2 = "Current Live Junction Target ($($pj.RelativePath) -> $($pj.LiveTarget))"
  $jBcArgString = "`"$($pj.BaselinePath)`" `"$($pj.LiveTarget)`" `"/title1=$jTitle1`" `"/title2=$jTitle2`" `"/filters=$jFilterMask`""

  if ($dispatcherPath) {
    & pwsh -File $dispatcherPath -FilePath $BeyondComparePath -ArgumentList $jBcArgString | Out-Null
  }
  else {
    Start-Process -FilePath $BeyondComparePath -ArgumentList @("`"$($pj.BaselinePath)`"", "`"$($pj.LiveTarget)`"", "`"/title1=$jTitle1`"", "`"/title2=$jTitle2`"", "`"/filters=$jFilterMask`"")
  }
}

if ($Wait) {
  Write-Host "Waiting for Beyond Compare review session to close..." -ForegroundColor DarkGray
  Audit-BeyondCompareReviewStaging -TempReviewRoot $tempReviewRoot -RepoPath $repoPath -RepoName $repoName -CommitSha $commitSha
}

