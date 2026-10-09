<#
Module: BCompareBaseline.psm1
Version: 1.0.0
Purpose: Resolves reproducible local Git baselines for repository reviews.
Caller Contract: Invoke-BeyondCompareReview supplies a target repository and local base reference.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-BCompareGitTreePath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $true)]
    [string]$Commit,

    [Parameter(Mandatory = $true)]
    [string]$RelativePath
  )

  $treePath = (@(& git -C $RepositoryPath ls-tree -r --name-only $Commit -- $RelativePath 2>$null) -join "`n").Trim()
  return -not [string]::IsNullOrWhiteSpace($treePath)
}

function Get-BCompareBaselineDescriptor {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $false)]
    [string]$BaseCommit = 'HEAD'
  )

  <#
  .SYNOPSIS
      Resolves a local target commit and an optional junction-backed rules authority commit.
  .DESCRIPTION
      Keeps the reviewed repository baseline independent from the local commit used to materialize
      canonical rules exposed through a .agents\rules junction.
  .PARAMETER RepositoryPath
      Absolute path to the repository being reviewed.
  .PARAMETER BaseCommit
      Local Git reference to resolve for the reviewed repository.
  #>

  $targetCommit = (& git -C $RepositoryPath rev-parse --verify --short $BaseCommit 2>$null).Trim()
  if ([string]::IsNullOrWhiteSpace($targetCommit)) {
    throw "Unable to resolve local baseline '$BaseCommit' for '$RepositoryPath'."
  }

  $descriptor = [ordered]@{
    TargetRepositoryPath = $RepositoryPath
    TargetCommit = $targetCommit
    RulesAuthorityPath = $null
    RulesAuthorityCommit = $null
    RulesAuthorityRelativePath = $null
    RulesAuthorityContentPresent = $false
    RulesBaselineRepositoryPath = $null
    RulesBaselineCommit = $null
    RulesBaselineRelativePath = $null
    RulesBaselineSource = 'none'
    CopilotBaselineRepositoryPath = $null
    CopilotBaselineCommit = $null
  }

  $copilotPath = Join-Path $RepositoryPath '.copilot'
  if (Test-Path -LiteralPath $copilotPath) {
    $copilotItem = Get-Item -LiteralPath $copilotPath -Force
    if ($copilotItem.LinkType -eq 'Junction' -and -not [string]::IsNullOrWhiteSpace([string]$copilotItem.Target)) {
      $copilotTargetPath = [string]$copilotItem.Target
      $copilotAuthorityPath = (& git -C $copilotTargetPath rev-parse --show-toplevel 2>$null).Trim()
      if (-not [string]::IsNullOrWhiteSpace($copilotAuthorityPath)) {
        $copilotCommit = (& git -C $copilotAuthorityPath rev-parse --verify --short HEAD 2>$null).Trim()
        if (-not [string]::IsNullOrWhiteSpace($copilotCommit)) {
          $descriptor.CopilotBaselineRepositoryPath = $copilotAuthorityPath
          $descriptor.CopilotBaselineCommit = $copilotCommit
        }
      }
    }
  }

  $rulesPath = Join-Path $RepositoryPath '.agents\rules'
  if (-not (Test-Path -LiteralPath $rulesPath)) {
    return [pscustomobject]$descriptor
  }

  $rulesItem = Get-Item -LiteralPath $rulesPath -Force
  if ($rulesItem.LinkType -eq 'Junction' -and -not [string]::IsNullOrWhiteSpace([string]$rulesItem.Target)) {
    $rulesTargetPath = [string]$rulesItem.Target
  }
  else {
    $agentsPath = Join-Path $RepositoryPath '.agents'
    if (Test-Path -LiteralPath $agentsPath) {
      $agentsItem = Get-Item -LiteralPath $agentsPath -Force
      if ($agentsItem.LinkType -eq 'Junction' -and -not [string]::IsNullOrWhiteSpace([string]$agentsItem.Target)) {
        $rulesTargetPath = Join-Path ([string]$agentsItem.Target) 'rules'
      }
      else {
        return [pscustomobject]$descriptor
      }
    }
    else {
      return [pscustomobject]$descriptor
    }
  }
  $authorityPath = (& git -C $rulesTargetPath rev-parse --show-toplevel 2>$null).Trim()
  if ([string]::IsNullOrWhiteSpace($authorityPath)) {
    throw "Rules junction '$rulesPath' does not target a Git repository."
  }

  $authorityCommit = (& git -C $authorityPath rev-parse --verify --short HEAD 2>$null).Trim()
  if ([string]::IsNullOrWhiteSpace($authorityCommit)) {
    throw "Unable to resolve local rules authority commit for '$authorityPath'."
  }

  $relativeRulesPath = [System.IO.Path]::GetRelativePath($authorityPath, $rulesTargetPath).Replace('\', '/')
  if ([System.IO.Path]::IsPathRooted($relativeRulesPath) -or $relativeRulesPath -eq '..' -or $relativeRulesPath.StartsWith('../', [System.StringComparison]::Ordinal)) {
    throw "Rules junction '$rulesPath' targets content outside its Git authority."
  }

  $descriptor.RulesAuthorityPath = $authorityPath
  $descriptor.RulesAuthorityCommit = $authorityCommit
  $descriptor.RulesAuthorityRelativePath = $relativeRulesPath
  $descriptor.RulesAuthorityContentPresent = Test-BCompareGitTreePath -RepositoryPath $authorityPath -Commit $authorityCommit -RelativePath $relativeRulesPath

  $targetRulesRelativePath = '.agents/rules'
  if (Test-BCompareGitTreePath -RepositoryPath $RepositoryPath -Commit $targetCommit -RelativePath $targetRulesRelativePath) {
    $descriptor.RulesBaselineRepositoryPath = $RepositoryPath
    $descriptor.RulesBaselineCommit = $targetCommit
    $descriptor.RulesBaselineRelativePath = $targetRulesRelativePath
    $descriptor.RulesBaselineSource = 'target-commit'
  }
  else {
    $targetCommitDate = (& git -C $RepositoryPath show -s --format=%cI $targetCommit 2>$null).Trim()
    $authorityBaselineCommit = if ([string]::IsNullOrWhiteSpace($targetCommitDate)) {
      $authorityCommit
    } else {
      (& git -C $authorityPath rev-list -1 "--before=$targetCommitDate" $authorityCommit 2>$null).Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($authorityBaselineCommit) -and (Test-BCompareGitTreePath -RepositoryPath $authorityPath -Commit $authorityBaselineCommit -RelativePath $relativeRulesPath)) {
      $descriptor.RulesBaselineRepositoryPath = $authorityPath
      $descriptor.RulesBaselineCommit = $authorityBaselineCommit
      $descriptor.RulesBaselineRelativePath = $relativeRulesPath
      $descriptor.RulesBaselineSource = 'authority-time-aligned'
    } else {
      $historicalRulesCommits = @(& git -C $RepositoryPath rev-list $targetCommit -- $targetRulesRelativePath 2>$null)
      foreach ($historicalRulesCommit in $historicalRulesCommits) {
        if (Test-BCompareGitTreePath -RepositoryPath $RepositoryPath -Commit $historicalRulesCommit -RelativePath $targetRulesRelativePath) {
          $descriptor.RulesBaselineRepositoryPath = $RepositoryPath
          $descriptor.RulesBaselineCommit = $historicalRulesCommit
          $descriptor.RulesBaselineRelativePath = $targetRulesRelativePath
          $descriptor.RulesBaselineSource = 'target-history'
          break
        }
      }
    }

    if ($descriptor.RulesBaselineSource -eq 'none' -and $descriptor.RulesAuthorityContentPresent) {
      $descriptor.RulesBaselineRepositoryPath = $authorityPath
      $descriptor.RulesBaselineCommit = $authorityCommit
      $descriptor.RulesBaselineRelativePath = $relativeRulesPath
      $descriptor.RulesBaselineSource = 'authority-commit'
    }
  }

  return [pscustomobject]$descriptor
}

function Export-BCompareBaseline {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [pscustomobject]$Descriptor,

    [Parameter(Mandatory = $true)]
    [string]$DestinationPath
  )

  <#
  .SYNOPSIS
      Exports a resolved baseline, including the committed canonical rules authority when present.
  .DESCRIPTION
      Exports only committed Git objects. An authority file absent from its local commit fails clearly
      instead of copying the mutable working tree into a historical review baseline.
  .PARAMETER Descriptor
      Descriptor returned by Get-BCompareBaselineDescriptor.
  .PARAMETER DestinationPath
      Empty directory that receives the baseline tree.
  #>

  $null = New-Item -ItemType Directory -Path $DestinationPath -Force
  $targetArchivePath = Join-Path $DestinationPath 'target-baseline.tar'
  & git -C $Descriptor.TargetRepositoryPath archive $Descriptor.TargetCommit -o $targetArchivePath
  if ($LASTEXITCODE -ne 0) {
    throw "Could not export target baseline commit '$($Descriptor.TargetCommit)'."
  }
  & tar -xf $targetArchivePath -C $DestinationPath
  if ($LASTEXITCODE -ne 0) {
    throw "Could not extract target baseline commit '$($Descriptor.TargetCommit)'."
  }
  Remove-Item -LiteralPath $targetArchivePath -Force

  if (-not [string]::IsNullOrWhiteSpace($Descriptor.RulesBaselineRepositoryPath)) {
    $authorityArchivePath = Join-Path $DestinationPath 'rules-authority-baseline.tar'
    & git -C $Descriptor.RulesBaselineRepositoryPath archive -o $authorityArchivePath $Descriptor.RulesBaselineCommit -- $Descriptor.RulesBaselineRelativePath
    if ($LASTEXITCODE -ne 0) {
      throw "Could not export rules baseline commit '$($Descriptor.RulesBaselineCommit)'."
    }
    & tar -tf $authorityArchivePath | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Rules baseline commit '$($Descriptor.RulesBaselineCommit)' does not contain '$($Descriptor.RulesBaselineRelativePath)'."
    }
    & tar -xf $authorityArchivePath -C $DestinationPath
    if ($LASTEXITCODE -ne 0) {
      throw "Could not extract rules baseline commit '$($Descriptor.RulesBaselineCommit)'."
    }
    Remove-Item -LiteralPath $authorityArchivePath -Force
  }

  # Export .copilot from authority baseline when target repository uses an external junction (e.g. root Git_Repositories)
  if (-not [string]::IsNullOrWhiteSpace($Descriptor.CopilotBaselineRepositoryPath)) {
    $copilotArchivePath = Join-Path $DestinationPath 'copilot-authority-baseline.tar'
    & git -C $Descriptor.CopilotBaselineRepositoryPath archive -o $copilotArchivePath $Descriptor.CopilotBaselineCommit -- '.copilot'
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $copilotArchivePath)) {
      & tar -xf $copilotArchivePath -C $DestinationPath 2>$null
      Remove-Item -LiteralPath $copilotArchivePath -Force -ErrorAction SilentlyContinue
    }
  }

  # Recreate internal tool junctions inside baseline .copilot to match live repository topology
  $destCopilot = Join-Path $DestinationPath '.copilot'
  if (Test-Path -LiteralPath $destCopilot) {
    $destRules = Join-Path $DestinationPath '.agents\rules'
    $destCopilotRules = Join-Path $destCopilot 'Rules'
    if (-not (Test-Path -LiteralPath $destCopilotRules)) {
      $targetRules = if (Test-Path -LiteralPath $destRules) { $destRules } elseif ($Descriptor.RulesAuthorityPath) { Join-Path $Descriptor.RulesAuthorityPath '.agents\rules' } else { $null }
      if ($targetRules -and (Test-Path -LiteralPath $targetRules)) {
        New-Item -ItemType Junction -Path $destCopilotRules -Target $targetRules -Force | Out-Null
      }
    }

    $destAtoms = Join-Path $DestinationPath '.agents\atoms'
    $destCopilotAtoms = Join-Path $destCopilot 'Atoms'
    if (-not (Test-Path -LiteralPath $destCopilotAtoms)) {
      $targetAtoms = if (Test-Path -LiteralPath $destAtoms) { $destAtoms } elseif ($Descriptor.RulesAuthorityPath) { Join-Path $Descriptor.RulesAuthorityPath '.agents\atoms' } else { $null }
      if ($targetAtoms -and (Test-Path -LiteralPath $targetAtoms)) {
        New-Item -ItemType Junction -Path $destCopilotAtoms -Target $targetAtoms -Force | Out-Null
      }
    }
  }

  # ----------------------------------------------------------------------------
  # Timestamp Preservation (RULE-LCM-003 / CRP-221)
  # ----------------------------------------------------------------------------
  $targetCommitDateStr = (& git -C $Descriptor.TargetRepositoryPath log -1 --format=%cI $Descriptor.TargetCommit 2>$null)
  $targetCommitTime = if (-not [string]::IsNullOrWhiteSpace($targetCommitDateStr)) {
    [System.DateTime]::Parse($targetCommitDateStr)
  } else {
    [System.DateTime]::UtcNow
  }

  $rulesCommitTime = $targetCommitTime
  if (-not [string]::IsNullOrWhiteSpace($Descriptor.RulesBaselineRepositoryPath)) {
    $rulesCommitDateStr = (& git -C $Descriptor.RulesBaselineRepositoryPath log -1 --format=%cI $Descriptor.RulesBaselineCommit 2>$null)
    if (-not [string]::IsNullOrWhiteSpace($rulesCommitDateStr)) {
      $rulesCommitTime = [System.DateTime]::Parse($rulesCommitDateStr)
    }
  }

  $allExportedFiles = @(Get-ChildItem -LiteralPath $DestinationPath -Recurse -File -Force)
  foreach ($exportedFile in $allExportedFiles) {
    $relPath = [System.IO.Path]::GetRelativePath($DestinationPath, $exportedFile.FullName)
    $normalizedRel = $relPath.Replace('\', '/')

    $isRuleFile = (-not [string]::IsNullOrWhiteSpace($Descriptor.RulesBaselineRelativePath)) -and `
                  ($normalizedRel -eq $Descriptor.RulesBaselineRelativePath -or $normalizedRel.StartsWith("$($Descriptor.RulesBaselineRelativePath)/", [System.StringComparison]::OrdinalIgnoreCase))

    $defaultTime = if ($isRuleFile) { $rulesCommitTime } else { $targetCommitTime }

    $workFilePath = Join-Path $Descriptor.TargetRepositoryPath $relPath
    $matchedWorkingTime = $null

    if (Test-Path -LiteralPath $workFilePath -PathType Leaf) {
      $srcItem = Get-Item -LiteralPath $workFilePath -Force
      if ($exportedFile.Length -eq $srcItem.Length) {
        $destHash = (Get-FileHash -LiteralPath $exportedFile.FullName -Algorithm SHA256).Hash
        $srcHash = (Get-FileHash -LiteralPath $srcItem.FullName -Algorithm SHA256).Hash
        if ($destHash -eq $srcHash) {
          $matchedWorkingTime = $srcItem
        }
      }
    }

    if ($matchedWorkingTime) {
      [System.IO.File]::SetCreationTime($exportedFile.FullName, $matchedWorkingTime.CreationTime)
      [System.IO.File]::SetLastWriteTime($exportedFile.FullName, $matchedWorkingTime.LastWriteTime)
    } else {
      [System.IO.File]::SetCreationTime($exportedFile.FullName, $defaultTime)
      [System.IO.File]::SetLastWriteTime($exportedFile.FullName, $defaultTime)
    }
  }
}

Export-ModuleMember -Function Get-BCompareBaselineDescriptor, Export-BCompareBaseline