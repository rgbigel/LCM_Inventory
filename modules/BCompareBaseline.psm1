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
  }

  $rulesPath = Join-Path $RepositoryPath '.agents\rules'
  if (-not (Test-Path -LiteralPath $rulesPath)) {
    return [pscustomobject]$descriptor
  }

  $rulesItem = Get-Item -LiteralPath $rulesPath -Force
  if ($rulesItem.LinkType -ne 'Junction' -or [string]::IsNullOrWhiteSpace([string]$rulesItem.Target)) {
    return [pscustomobject]$descriptor
  }

  $rulesTargetPath = [string]$rulesItem.Target
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
}

Export-ModuleMember -Function Get-BCompareBaselineDescriptor, Export-BCompareBaseline