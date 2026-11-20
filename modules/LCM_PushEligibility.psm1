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
  Implementation Choices (BUG-380 B12): the push targets every workspace repository with commits ahead of its
  remote (Get-LCM_PushRepositoryStates), governed or not, instead of origin_repo / affected_repos of completed
  proposals; origin_repo is the ledger home (RULE-LCM-034). Completed proposals only drive the pushed transition.
  Implementation Choices (BUG-380 B12, operator review item 10 and its correction of 2026-11-20): governed = the LCM
  core (LCM_* repositories, workspace root) plus the repositories the inventory classifies as governed; a governed
  repository outside the core that is not converged to the active LCM version is held back (-HeldRepositories),
  never pushed; LCM rules (lockstep preflight) apply to governed repositories only; non-governed ones are backup.
  Authors: GitHub Copilot, Claude
  Version: 10.2.2
  Date: 2026-11-20
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

function Test-LCM_CorePushRepository {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryName
  )

  # The LCM core: the governed LCM_* repositories (RULE-LCM-034) and the root container (RULE-LCM-004).
  $name = ConvertTo-WorkspacePushRepositoryName -RepositoryName $RepositoryName
  return ($name -in @('LCM_AI', 'LCM_Inventory', 'LCM_Shared', 'LCM_Supervision', 'LCM_Tools', 'Git_Repositories'))
}

function Test-LCM_GovernedPushRepository {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryName,

    [Parameter(Mandatory = $false)]
    [AllowEmptyCollection()]
    [object[]]$InventoryRepositories = @()
  )

  # Operator review item 10 with the operator correction of 2026-11-20: governed = the LCM core plus every repository
  # the inventory classifies as governed (e.g. BootEntryManager, VolumeInventory); every other repository is a plain
  # Git repository and is pushed as backup without LCM rules.
  if (Test-LCM_CorePushRepository -RepositoryName $RepositoryName) { return $true }
  $name = ConvertTo-WorkspacePushRepositoryName -RepositoryName $RepositoryName
  $entry = @($InventoryRepositories | Where-Object { $_.PSObject.Properties['RepositoryName'] -and [string]$_.RepositoryName -eq $name })
  if ($entry.Count -eq 0) { return $false }
  $status = if ($entry[0].PSObject.Properties['LCMStatus']) { [string]$entry[0].LCMStatus } else { '' }
  return ($status -eq 'governed')
}

function Get-LCM_UnconvergedPushRepositories {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [object[]]$InventoryRepositories,

    [Parameter(Mandatory = $true)]
    [string]$LcmVersion
  )

  # Operator 2026-11-20: a governed repository outside the LCM core is not pushed until it is brought to LCM
  # convergence; converged = its inventory CurrentLCMVersion equals the active LCM version (.agents/version.json).
  foreach ($entry in @($InventoryRepositories)) {
    if (-not $entry.PSObject.Properties['RepositoryName'] -or -not $entry.RepositoryName) { continue }
    $name = [string]$entry.RepositoryName
    if (Test-LCM_CorePushRepository -RepositoryName $name) { continue }
    if (-not (Test-LCM_GovernedPushRepository -RepositoryName $name -InventoryRepositories $InventoryRepositories)) { continue }
    $version = if ($entry.PSObject.Properties['CurrentLCMVersion'] -and $entry.CurrentLCMVersion) { [string]$entry.CurrentLCMVersion } else { '' }
    if ($version -ne $LcmVersion) {
      [pscustomobject]@{ Name = $name; Version = $version; Reason = "not converged (LCM $version, active $LcmVersion)" }
    }
  }
}

function Get-LCM_PushRepositoryStates {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot
  )

  # BUG-380 B12: every Git repository of the workspace (root and first-level children), governed or not.
  $candidates = @([pscustomobject]@{ Name = 'Git_Repositories'; Path = $WorkspaceRoot })
  $candidates += @(
    Get-ChildItem -LiteralPath $WorkspaceRoot -Directory |
      Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.git') } |
      Sort-Object -Property Name |
      ForEach-Object { [pscustomobject]@{ Name = $_.Name; Path = $_.FullName } }
  )

  foreach ($candidate in $candidates) {
    $repoPath = $candidate.Path
    $hasGit = Test-Path -LiteralPath (Join-Path $repoPath '.git')
    $hasRemote = $false
    $hasUpstream = $false
    $aheadCount = 0
    $branch = ''
    if ($hasGit) {
      $remotes = @(git -C $repoPath remote 2>$null)
      $hasRemote = $remotes.Count -gt 0
      $branch = [string](git -C $repoPath rev-parse --abbrev-ref HEAD 2>$null)
      $branch = $branch.Trim()
      if ($hasRemote) {
        $statusSummary = (@(git -C $repoPath status -sb 2>$null) -join "`n")
        $hasUpstream = $statusSummary -match '^## [^\r\n]+\.\.\.'
        if ($statusSummary -match 'ahead\s+(\d+)') {
          $aheadCount = [int]$Matches[1]
        }
      }
    }
    [pscustomobject]@{
      Name = $candidate.Name
      Path = $repoPath
      HasGit = $hasGit
      HasRemote = $hasRemote
      HasUpstream = $hasUpstream
      AheadCount = $aheadCount
      Branch = $branch
    }
  }
}

function Resolve-LCM_PushPlan {
  [CmdletBinding()]
  [Alias('Resolve-WorkspacePushPlan')]
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [object[]]$Proposals,

    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [string[]]$AheadRepositories,

    [Parameter(Mandatory = $false)]
    [string[]]$RequestedRepositories = @(),

    [Parameter(Mandatory = $false)]
    [int[]]$ProposalIds = @(),

    [Parameter(Mandatory = $false)]
    [AllowEmptyCollection()]
    [string[]]$HeldRepositories = @()
  )

  # BUG-380 B12 (operator rule 2026-11-20): everything that was changed is pushed once it is completed and
  # committed: every repository ahead of its remote, governed or not; unchanged repositories are not pushed.
  # origin_repo is the ledger home (RULE-LCM-034), not the push target. A push is administrative
  # maintenance and backup; completed proposals only drive the completed -> pushed transition.
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

  # Operator 2026-11-20: held repositories (governed, not converged) are never push targets.
  $heldTargets = @(
    $HeldRepositories |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { ConvertTo-WorkspacePushRepositoryName -RepositoryName $_ }
  )
  $aheadTargets = @(
    $AheadRepositories |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { ConvertTo-WorkspacePushRepositoryName -RepositoryName $_ } |
      Where-Object { $_ -notin $heldTargets } |
      Select-Object -Unique
  )

  $requestedTargets = @(
    $RequestedRepositories |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { ConvertTo-WorkspacePushRepositoryName -RepositoryName $_ } |
      Select-Object -Unique
  )

  $heldRequested = @($requestedTargets | Where-Object { $_ -in $heldTargets })
  if ($heldRequested.Count -gt 0) {
    throw "PUSH: requested repositories are governed but not converged to the active LCM version: $($heldRequested -join ', ')."
  }
  $notAheadRepositories = @($requestedTargets | Where-Object { $_ -notin $aheadTargets })
  if ($notAheadRepositories.Count -gt 0) {
    throw "PUSH: requested repositories have no commits ahead of their remote: $($notAheadRepositories -join ', ')."
  }

  $targetRepositories = @(if ($requestedTargets.Count -gt 0) { $requestedTargets } else { $aheadTargets })
  if ($targetRepositories.Count -eq 0) {
    throw 'PUSH: no repository has commits ahead of its remote; nothing to push.'
  }

  # RULE-LCM-005 lockstep: LCM_Inventory rides along whenever it has commits ahead.
  $requiredRepositories = @($targetRepositories)
  if ('LCM_Inventory' -in $aheadTargets) {
    $requiredRepositories = @($requiredRepositories + 'LCM_Inventory' | Select-Object -Unique)
  }

  [pscustomobject]@{
    TargetRepositories = @($targetRepositories)
    RequiredRepositories = @($requiredRepositories)
    CompletedProposalIds = @($completedProposals | ForEach-Object { $_.id })
    CompletedProposals = @(
      $completedProposals | ForEach-Object {
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
    if (-not (Test-LCM_CorePushRepository -RepositoryName $repositoryName)) {
      # Operator review item 10: the lockstep preflight is an LCM core rule; it never refuses another repository.
      continue
    }
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

Export-ModuleMember -Function Test-LCM_CorePushRepository, Test-LCM_GovernedPushRepository, Get-LCM_UnconvergedPushRepositories, Get-LCM_PushRepositoryStates, Resolve-LCM_PushPlan, Resolve-WorkspacePushPlan, Test-LCM_PushCohort, Test-WorkspacePushCohort, Test-LCM_ProposalBundlesInHead, Test-WorkspaceProposalBundlesInHead -Alias Resolve-WorkspacePushPlan, Test-WorkspacePushCohort, Test-WorkspaceProposalBundlesInHead
