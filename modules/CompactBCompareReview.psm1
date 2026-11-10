<#
.SYNOPSIS
    Creates a hierarchy-preserving, inclusion-scoped BCompare review projection.
.DESCRIPTION
    Module: CompactBCompareReview.psm1
    Purpose: Materializes selected baseline and working files into scratch-only Baseline and
             Working repository roots without changing the live repository.
    Path: modules/CompactBCompareReview.psm1
    Authors: Rolf, GitHub Copilot
    Version: 10.2.0
    Date: 2026-10-13
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CompactBCompareInclusion {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$InclusionManifest
  )

  if (-not (Test-Path -LiteralPath $InclusionManifest -PathType Leaf)) {
    throw "Inclusion manifest not found: $InclusionManifest"
  }

  $manifest = Get-Content -LiteralPath $InclusionManifest -Raw -Encoding UTF8 | ConvertFrom-Json
  $paths = @(if ($null -ne $manifest.PSObject.Properties['include']) { @($manifest.include) } else { @($manifest) })
  if ($paths.Count -eq 0) {
    throw 'Inclusion manifest must contain at least one repository-relative path.'
  }

  foreach ($path in $paths) {
    $relativePath = [string]$path
    if ([string]::IsNullOrWhiteSpace($relativePath) -or [System.IO.Path]::IsPathRooted($relativePath) -or $relativePath -match '(^|[\\/])\.\.([\\/]|$)') {
      throw "Invalid repository-relative inclusion path: $relativePath"
    }
    $relativePath.Replace('/', '\').TrimStart('\')
  }
}

function New-CompactBCompareReviewTree {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $true)]
    [string]$BaseCommit,

    [Parameter(Mandatory = $true)]
    [string]$InclusionManifest,

    [Parameter(Mandatory = $true)]
    [string]$ScratchRoot
  )

  if (-not (Test-Path -LiteralPath (Join-Path $RepositoryPath '.git'))) {
    throw "Repository path is not a Git repository: $RepositoryPath"
  }

  $repository = Get-Item -LiteralPath $RepositoryPath
  $include = @(Get-CompactBCompareInclusion -InclusionManifest $InclusionManifest)
  $sessionRoot = Join-Path $ScratchRoot ("Compact_{0}_{1}_{2}" -f $repository.Name, (Get-Date -Format 'yyyyMMdd_HHmmss_fff'), [guid]::NewGuid().ToString('N'))
  $baselineRoot = Join-Path $sessionRoot (Join-Path 'Baseline' $repository.Name)
  $workingRoot = Join-Path $sessionRoot (Join-Path 'Working' $repository.Name)
  $null = New-Item -ItemType Directory -Path $baselineRoot -Force
  $null = New-Item -ItemType Directory -Path $workingRoot -Force

  foreach ($relativePath in $include) {
    $workingPath = Join-Path $repository.FullName $relativePath
    if (-not (Test-Path -LiteralPath $workingPath -PathType Leaf)) {
      throw "Included working file not found: $relativePath"
    }

    $workingTarget = Join-Path $workingRoot $relativePath
    $baselineTarget = Join-Path $baselineRoot $relativePath
    $null = New-Item -ItemType Directory -Path (Split-Path $workingTarget -Parent) -Force
    $null = New-Item -ItemType Directory -Path (Split-Path $baselineTarget -Parent) -Force
    Copy-Item -LiteralPath $workingPath -Destination $workingTarget -Force
    $srcFile = Get-Item -LiteralPath $workingPath -Force
    [System.IO.File]::SetCreationTime($workingTarget, $srcFile.CreationTime)
    [System.IO.File]::SetLastWriteTime($workingTarget, $srcFile.LastWriteTime)

    $gitObject = "${BaseCommit}:$($relativePath.Replace('\', '/'))"
    & git -C $repository.FullName show $gitObject 2>$null > $baselineTarget
    if ($LASTEXITCODE -ne 0) {
      throw "Included baseline file not found at ${BaseCommit}: $relativePath"
    }

    # Preserve baseline file timestamp
    $destFile = Get-Item -LiteralPath $baselineTarget -Force
    if ($destFile.Length -eq $srcFile.Length -and (Get-FileHash -LiteralPath $baselineTarget -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $workingPath -Algorithm SHA256).Hash) {
      [System.IO.File]::SetCreationTime($baselineTarget, $srcFile.CreationTime)
      [System.IO.File]::SetLastWriteTime($baselineTarget, $srcFile.LastWriteTime)
    } else {
      $commitDateStr = (& git -C $repository.FullName log -1 --format=%cI $BaseCommit -- $relativePath 2>$null)
      if ([string]::IsNullOrWhiteSpace($commitDateStr)) {
        $commitDateStr = (& git -C $repository.FullName log -1 --format=%cI $BaseCommit 2>$null)
      }
      $targetTime = if (-not [string]::IsNullOrWhiteSpace($commitDateStr)) {
        [System.DateTime]::Parse($commitDateStr)
      } else {
        $srcFile.LastWriteTime
      }
      [System.IO.File]::SetCreationTime($baselineTarget, $targetTime)
      [System.IO.File]::SetLastWriteTime($baselineTarget, $targetTime)
    }
  }

  # Propagate folder timestamps bottom-up across baselineRoot and workingRoot
  foreach ($treeRoot in @($baselineRoot, $workingRoot)) {
    if (Test-Path -LiteralPath $treeRoot) {
      $allDirs = @(Get-ChildItem -LiteralPath $treeRoot -Recurse -Directory -Force |
        Sort-Object -Property { $_.FullName.Length } -Descending)
      foreach ($d in $allDirs) {
        $ch = @(Get-ChildItem -LiteralPath $d.FullName -Force)
        if ($ch.Count -gt 0) {
          $maxT = ($ch | Measure-Object -Property LastWriteTime -Maximum).Maximum
          if ($maxT) {
            [System.IO.Directory]::SetCreationTime($d.FullName, $maxT)
            [System.IO.Directory]::SetLastWriteTime($d.FullName, $maxT)
          }
        }
      }
      $rootCh = @(Get-ChildItem -LiteralPath $treeRoot -Force)
      if ($rootCh.Count -gt 0) {
        $maxRootT = ($rootCh | Measure-Object -Property LastWriteTime -Maximum).Maximum
        if ($maxRootT) {
          [System.IO.Directory]::SetCreationTime($treeRoot, $maxRootT)
          [System.IO.Directory]::SetLastWriteTime($treeRoot, $maxRootT)
        }
      }
    }
  }

  Copy-Item -LiteralPath $InclusionManifest -Destination (Join-Path $sessionRoot 'inclusion-manifest.json') -Force
  [pscustomobject]@{
    SessionRoot = $sessionRoot
    BaselinePath = $baselineRoot
    WorkingPath = $workingRoot
    IncludedPath = $include
  }
}

Export-ModuleMember -Function Get-CompactBCompareInclusion, New-CompactBCompareReviewTree
