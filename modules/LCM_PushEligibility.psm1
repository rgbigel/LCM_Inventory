<#
.SYNOPSIS
  Resolves and validates completed-proposal push cohorts.
.DESCRIPTION
  Module: modules/LCM_PushEligibility.psm1
  Purpose: Prevents pushes of repositories without completed proposals and enforces
           LCM_Inventory lockstep participation before remote dispatch.
  Path: LCM_Inventory/modules/LCM_PushEligibility.psm1
  Implementation Choices (BUG-349): proposal bundles of governed LCM_* repositories live only in
  LCM_Inventory (RULE-LCM-034, RULE-SUB-008); the push plan records that bundle repository
  separately (BundleRepository) and the HEAD check uses it. Repository stays the origin repository.
  A missing or unrecorded bundle is bookkeeping: it is reported as a warning and never aborts a
  push (RULE-EFF-002, operator 2026-11-17).
  Authors: GitHub Copilot, Claude
  Version: 10.2.1
  Date: 2026-11-17
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-LCM_PushRepositoryName {
  [CmdletBinding()]
  [Alias('ConvertTo-WorkspacePushRepositoryName')]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryName
  )

  switch ($RepositoryName.Trim()) {
    '.' { return 'Git_Repositories' }
    'root' { return 'Git_Repositories' }
    'Root' { return 'Git_Repositories' }
    'LCM' { return 'Git_Repositories' }
    'Git_Repositories' { return 'Git_Repositories' }
    default { return $RepositoryName.Trim() }
  }
}

function Resolve-LCM_ProposalBundlePath {
  [CmdletBinding()]
  [Alias('Resolve-WorkspaceProposalBundlePath')]
  param(
    [Parameter(Mandatory = $true)]
    [psobject]$Proposal,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryName
  )

  $bundleDirectoryProperty = $Proposal.PSObject.Properties['bundle_dir']
  if ($bundleDirectoryProperty -and $bundleDirectoryProperty.Value) {
    return ([string]$bundleDirectoryProperty.Value).Replace('\', '/').Trim('/')
  }

  $planPathProperty = $Proposal.PSObject.Properties['plan_path']
  if ($planPathProperty -and $planPathProperty.Value) {
    $planPath = ([string]$planPathProperty.Value).Replace('\', '/').Trim('/')
    $repositoryPrefix = "$RepositoryName/"
    if ($planPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      $planPath = $planPath.Substring($repositoryPrefix.Length)
    }
    return (Split-Path -Path $planPath -Parent).Replace('\', '/').Trim('/')
  }

  return ''
}

function Resolve-LCM_ProposalBundleRepository {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryName
  )

  # BUG-349: RULE-LCM-034 / RULE-SUB-008 - governed LCM_* proposals keep their bundles in LCM_Inventory.
  $governedRepositories = @('LCM_AI', 'LCM_Inventory', 'LCM_Shared', 'LCM_Supervision', 'LCM_Tools')
  $name = ConvertTo-WorkspacePushRepositoryName -RepositoryName $RepositoryName
  if ($name -in $governedRepositories) {
    return 'LCM_Inventory'
  }
  return $name
}

function Resolve-LCM_PushPlan {
  [CmdletBinding()]
  [Alias('Resolve-WorkspacePushPlan')]
  param(
    [Parameter(Mandatory = $true)]
    [object[]]$Proposals,

    [Parameter(Mandatory = $false)]
    [string[]]$RequestedRepositories = @(),

    [Parameter(Mandatory = $false)]
    [int[]]$ProposalIds = @()
  )

  $completedProposals = @(
    $Proposals | Where-Object {
      $_.state -eq 'completed' -and $_.progress_state -eq 'completed'
    }
  )

  if ($ProposalIds.Count -gt 0) {
    $incompleteIds = @(
      $ProposalIds | Where-Object {
        $proposalId = $_
        -not ($completedProposals | Where-Object { [int]$_.id -eq $proposalId })
      }
    )
    if ($incompleteIds.Count -gt 0) {
      throw "PUSH requires completed proposals. Ineligible proposal IDs: $($incompleteIds -join ', ')."
    }
    $completedProposals = @($completedProposals | Where-Object { [int]$_.id -in $ProposalIds })
  }

  if ($completedProposals.Count -eq 0) {
    throw 'PUSH requires at least one proposal with both state and progress_state set to completed.'
  }

  $completedRepositories = @(
    $completedProposals |
      ForEach-Object {
        $proposal = $_
        $proposalRepositories = @($proposal.origin_repo)
        $affectedRepositoriesProperty = $proposal.PSObject.Properties['affected_repos']
        if ($affectedRepositoriesProperty -and $affectedRepositoriesProperty.Value) {
          $proposalRepositories += @($affectedRepositoriesProperty.Value)
        }
        $proposalRepositories | ForEach-Object {
          ConvertTo-WorkspacePushRepositoryName -RepositoryName $_
        }
      } |
      Where-Object { $_ -ne 'LCM_Inventory' } |
      Select-Object -Unique
  )

  $requestedTargets = @(
    $RequestedRepositories |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { ConvertTo-WorkspacePushRepositoryName -RepositoryName $_ } |
      Where-Object { $_ -ne 'LCM_Inventory' } |
      Select-Object -Unique
  )

  $ineligibleRepositories = @($requestedTargets | Where-Object { $_ -notin $completedRepositories })
  if ($ineligibleRepositories.Count -gt 0) {
    throw "PUSH requires completed proposals for every requested repository. Ineligible repositories: $($ineligibleRepositories -join ', ')."
  }

  $targetProposals = if ($requestedTargets.Count -gt 0) {
    @(
      $completedProposals | Where-Object {
        $proposal = $_
        $proposalRepositories = @($proposal.origin_repo)
        $affectedRepositoriesProperty = $proposal.PSObject.Properties['affected_repos']
        if ($affectedRepositoriesProperty -and $affectedRepositoriesProperty.Value) {
          $proposalRepositories += @($affectedRepositoriesProperty.Value)
        }
        $normalizedRepositories = @(
          $proposalRepositories | ForEach-Object {
            ConvertTo-WorkspacePushRepositoryName -RepositoryName $_
          }
        )
        @($normalizedRepositories | Where-Object { $_ -in $requestedTargets }).Count -gt 0
      }
    )
  } else {
    @($completedProposals)
  }

  $targetRepositories = @(
    $targetProposals |
      ForEach-Object {
        $proposal = $_
        $proposalRepositories = @($proposal.origin_repo)
        $affectedRepositoriesProperty = $proposal.PSObject.Properties['affected_repos']
        if ($affectedRepositoriesProperty -and $affectedRepositoriesProperty.Value) {
          $proposalRepositories += @($affectedRepositoriesProperty.Value)
        }
        $proposalRepositories | ForEach-Object {
          ConvertTo-WorkspacePushRepositoryName -RepositoryName $_
        }
      } |
      Where-Object { $_ -ne 'LCM_Inventory' } |
      Select-Object -Unique
  )
  if ($targetRepositories.Count -eq 0) {
    throw 'PUSH requires at least one completed proposal owned by a non-LCM_Inventory repository.'
  }

  [pscustomobject]@{
    TargetRepositories = @($targetRepositories)
    RequiredRepositories = @($targetRepositories + 'LCM_Inventory' | Select-Object -Unique)
    CompletedProposalIds = @($targetProposals | Select-Object -ExpandProperty id)
    CompletedProposals = @(
      $targetProposals | ForEach-Object {
        [pscustomobject]@{
          Id = [int]$_.id
          Repository = ConvertTo-WorkspacePushRepositoryName -RepositoryName $_.origin_repo
          BundleRepository = Resolve-LCM_ProposalBundleRepository -RepositoryName $_.origin_repo
          BundlePath = Resolve-WorkspaceProposalBundlePath -Proposal $_ -RepositoryName $_.origin_repo
        }
      }
    )
  }
}

function Test-LCM_PushCohort {
  [CmdletBinding()]
  [Alias('Test-WorkspacePushCohort')]
  param(
    [Parameter(Mandatory = $true)]
    [psobject]$PushPlan,

    [Parameter(Mandatory = $true)]
    [object[]]$RepositoryStates
  )

  $statesByRepository = @{}
  foreach ($repositoryState in $RepositoryStates) {
    $name = ConvertTo-WorkspacePushRepositoryName -RepositoryName $repositoryState.Name
    $statesByRepository[$name] = $repositoryState
  }

  foreach ($repositoryName in $PushPlan.RequiredRepositories) {
    if (-not $statesByRepository.ContainsKey($repositoryName)) {
      throw "PUSH lockstep preflight missing repository state for '$repositoryName'."
    }

    $repositoryState = $statesByRepository[$repositoryName]
    if (-not $repositoryState.HasGit) {
      throw "PUSH lockstep preflight requires '$repositoryName' to be a Git repository."
    }
    if (-not $repositoryState.HasRemote) {
      throw "PUSH lockstep preflight requires '$repositoryName' to have a Git remote."
    }
    if ([int]$repositoryState.AheadCount -le 0) {
      throw "PUSH lockstep preflight requires '$repositoryName' to be ahead of its remote."
    }
  }

  return $true
}

function Test-LCM_ProposalBundlesInHead {
  [CmdletBinding()]
  [Alias('Test-WorkspaceProposalBundlesInHead')]
  param(
    [Parameter(Mandatory = $true)]
    [psobject]$PushPlan,

    [Parameter(Mandatory = $true)]
    [object[]]$RepositoryStates
  )

  $statesByRepository = @{}
  foreach ($repositoryState in $RepositoryStates) {
    $name = ConvertTo-WorkspacePushRepositoryName -RepositoryName $repositoryState.Name
    $statesByRepository[$name] = $repositoryState
  }

  $allPresent = $true
  foreach ($proposal in $PushPlan.CompletedProposals) {
    if ([string]::IsNullOrWhiteSpace($proposal.BundlePath)) {
      Write-Warning "PUSH bookkeeping: proposal $($proposal.Id) has no proposal bundle path recorded (not blocking, RULE-EFF-002)."
      $allPresent = $false
      continue
    }
    # BUG-349: the bundle lives in its bundle repository (LCM_Inventory for governed LCM_* repos).
    $bundleRepositoryProperty = $proposal.PSObject.Properties['BundleRepository']
    $bundleRepository = if ($bundleRepositoryProperty -and $bundleRepositoryProperty.Value) { [string]$bundleRepositoryProperty.Value } else { [string]$proposal.Repository }
    if (-not $statesByRepository.ContainsKey($bundleRepository)) {
      Write-Warning "PUSH bookkeeping: proposal $($proposal.Id): repository state is missing for '$bundleRepository' (not blocking, RULE-EFF-002)."
      $allPresent = $false
      continue
    }

    $repositoryState = $statesByRepository[$bundleRepository]
    $bundleObject = "HEAD:$($proposal.BundlePath)"
    & git -C $repositoryState.Path cat-file -e $bundleObject 2>$null
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "PUSH bookkeeping: proposal $($proposal.Id): bundle '$($proposal.BundlePath)' is not present in $bundleRepository HEAD (not blocking, RULE-EFF-002)."
      $allPresent = $false
    }
  }

  return $allPresent
}

Export-ModuleMember -Function Resolve-LCM_PushPlan, Resolve-WorkspacePushPlan, Test-LCM_PushCohort, Test-WorkspacePushCohort, Test-LCM_ProposalBundlesInHead, Test-WorkspaceProposalBundlesInHead -Alias Resolve-WorkspacePushPlan, Test-WorkspacePushCohort, Test-WorkspaceProposalBundlesInHead
