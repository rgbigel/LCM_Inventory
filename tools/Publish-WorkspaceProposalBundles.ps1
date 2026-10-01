<#
.SYNOPSIS
  Publishes proposal bundle documentation from governed repositories.
.DESCRIPTION
  Module: tools/Publish-WorkspaceProposalBundles.ps1
  Purpose: Stages only docs/Proposals content, creates proposal-only commits, and
           optionally pushes those commits without staging unrelated changes.
  Path: LCM_Inventory/tools/Publish-WorkspaceProposalBundles.ps1
  Authors: GitHub Copilot
  Version: 8.0.0
  Date: 2026-09-29
#>

[CmdletBinding()]
param(
  [string]$WorkspaceRoot = 'D:\Git_Repositories',

  [string[]]$Repositories = @(),

  [switch]$Commit,

  [switch]$Push,

  [switch]$DryRun,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Usage: Publish-WorkspaceProposalBundles.ps1 [-Repositories <name[]>] [-Commit] [-Push] [-DryRun]'
  Write-Host 'Stages only docs/Proposals and refuses to commit when unrelated files are already staged.'
  return
}

if ($Push -and -not $Commit) {
  throw '-Push requires -Commit so every published bundle is committed before remote dispatch.'
}

$workspaceRoot = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
$repositoryTargets = @(
  [pscustomobject]@{ Name = 'Git_Repositories'; Path = $workspaceRoot }
  Get-ChildItem -LiteralPath $workspaceRoot -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName '.git')
  } | ForEach-Object {
    [pscustomobject]@{ Name = $_.Name; Path = $_.FullName }
  }
)

if ($Repositories.Count -gt 0) {
  $repositoryTargets = @($repositoryTargets | Where-Object { $_.Name -in $Repositories })
}

$publicationTargets = @()
foreach ($repository in $repositoryTargets) {
  $proposalPath = Join-Path $repository.Path 'docs\Proposals'
  if (-not (Test-Path -LiteralPath $proposalPath)) {
    continue
  }

  $publishPaths = @('docs/Proposals')
  if ($repository.Name -eq 'LCM_Inventory') {
    $publishPaths += 'data/proposals/proposals.json'
  }
  $proposalChanges = @(git -C $repository.Path status --porcelain=v1 --untracked-files=all -- @publishPaths)
  if ($proposalChanges.Count -gt 0) {
    $publicationTargets += [pscustomobject]@{
      Name = $repository.Name
      Path = $repository.Path
      ProposalPath = $proposalPath
      PublishPaths = @($publishPaths)
      ChangeCount = $proposalChanges.Count
    }
  }
}

if ($publicationTargets.Count -eq 0) {
  Write-Host 'No uncommitted proposal bundle changes were found.' -ForegroundColor DarkGray
  return
}

foreach ($target in $publicationTargets) {
  Write-Host "[$($target.Name)] $($target.ChangeCount) proposal bundle change(s)" -ForegroundColor Cyan
  if ($DryRun) {
    continue
  }

  $preStaged = @(git -C $target.Path diff --cached --name-only)
  $unrelatedStaged = @($preStaged | Where-Object {
    $stagedPath = $_.Replace('\', '/')
    -not ($stagedPath -like 'docs/Proposals/*' -or ($target.Name -eq 'LCM_Inventory' -and $stagedPath -eq 'data/proposals/proposals.json'))
  })
  if ($unrelatedStaged.Count -gt 0) {
    throw "[$($target.Name)] proposal publication refused because unrelated files are already staged: $($unrelatedStaged -join ', ')"
  }

  if (-not $Commit) {
    continue
  }

  git -C $target.Path add -- @($target.PublishPaths)
  $stagedFiles = @(git -C $target.Path diff --cached --name-only)
  $unrelatedStaged = @($stagedFiles | Where-Object {
    $stagedPath = $_.Replace('\', '/')
    -not ($stagedPath -like 'docs/Proposals/*' -or ($target.Name -eq 'LCM_Inventory' -and $stagedPath -eq 'data/proposals/proposals.json'))
  })
  if ($unrelatedStaged.Count -gt 0) {
    throw "[$($target.Name)] proposal publication refused because staging includes unrelated files: $($unrelatedStaged -join ', ')"
  }

  git -C $target.Path commit -m 'docs(proposals): publish proposal bundles'
  if ($LASTEXITCODE -ne 0) {
    throw "[$($target.Name)] proposal bundle commit failed."
  }
}

if ($Push -and -not $DryRun) {
  foreach ($target in $publicationTargets) {
    $branch = (git -C $target.Path branch --show-current).Trim()
    $remotes = @(git -C $target.Path remote)
    if ($remotes.Count -eq 0) {
      throw "[$($target.Name)] proposal publication cannot push because no Git remote is configured."
    }
    git -C $target.Path push origin $branch
    if ($LASTEXITCODE -ne 0) {
      throw "[$($target.Name)] proposal bundle push failed. Earlier repositories may already have been pushed."
    }
  }
}