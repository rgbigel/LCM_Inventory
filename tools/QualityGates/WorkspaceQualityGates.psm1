<#
Module: WorkspaceQualityGates.psm1
Purpose: Provide reusable LCM_AI readiness and stabilization quality gates.
Path: tools/QualityGates/WorkspaceQualityGates.psm1
Authors: LCM_AI Engine
Version: 1.15.1
Caller Contract: Imported by native governance scripts; validates LCM_AI state without writing to external repositories.
Changelog:
- 2026-08-17: Clarified SettingsPath root-container scope for Assert-IgnoredRepositories.
- 2026-08-02: Added target-local proposal cleanup scanner validation.
- 2026-08-02: Added target-local method instance bootstrap policy validation.
- 2026-08-02: Added proposal-directory cleanup methodology validation.
- 2026-08-02: Added target-local method instance ownership validation.
- 2026-08-02: Added target-local Markdown proposal authority validation.
- 2026-08-02: Added repository lifecycle and explicit event-triggered integrity preflight validation.
- 2026-08-01: Allowed confirmed read-only real-repository dry-run while keeping external writes blocked.
- 2026-08-01: Added bottom-up concrete change-request flow validation.
- 2026-08-01: Added phased dry-run sequence validation for documentation-first real-repository testing.
- 2026-08-01: Added adapter content comparison state validation for intended action preview.
- 2026-08-01: Added intended action preview policy validation for real-repository dry-run.
- 2026-08-01: Added read-only Git command allow-list validation for real-repository dry-run.
- 2026-08-01: Added dry-run target profile and adapter surface inventory checks.
- 2026-08-01: Added transition-policy and dry-run state consistency checks.
- 2026-08-01: Added real-repository test plan and dry-run policy quality gate.
- 2026-08-01: Consolidated helper Test-* scripts into one quality-gate module.
#>

function Get-WorkspaceRoot {
  [CmdletBinding()]
  param(
    [string]$ModuleRoot = $PSScriptRoot
  )

  return Split-Path (Split-Path (Split-Path $ModuleRoot -Parent) -Parent) -Parent
}

function Resolve-TargetMethodInstance {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$RepositoryPath
  )

  $docsRoot = Get-ChildItem -LiteralPath $RepositoryPath -Directory -ErrorAction Stop | Where-Object { $_.Name -ieq 'Docs' } | Select-Object -First 1
  if (-not $docsRoot) {
    return [pscustomobject]@{
      Exists = $false
      MethodRoot = $null
      ManifestPath = $null
    }
  }

  $methodRoot = Get-ChildItem -LiteralPath $docsRoot.FullName -Directory -ErrorAction Stop | Where-Object { $_.Name -ieq 'Methods' } | Select-Object -First 1
  if (-not $methodRoot) {
    return [pscustomobject]@{
      Exists = $false
      MethodRoot = $null
      ManifestPath = $null
    }
  }

  $manifestPath = Join-Path $methodRoot.FullName 'MethodInstance.json'
  return [pscustomobject]@{
    Exists = Test-Path -LiteralPath $manifestPath
    MethodRoot = $methodRoot.FullName
    ManifestPath = $manifestPath
  }
}

function Assert-IgnoredRepositories {
  [CmdletBinding()]
  param(
    [string]$SettingsPath,

    [string]$WorkspaceParent = 'D:\Git_Repositories',

    [string]$WorkspaceRoot
  )

  if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Get-WorkspaceRoot
  }

  $invPath = Join-Path $WorkspaceParent 'LCM_Inventory\data\inventory.json'
  $trackedNonGit = @()
  if (Test-Path -LiteralPath $invPath) {
    try {
      $inv = Get-Content -LiteralPath $invPath -Raw | ConvertFrom-Json
      $trackedNonGit = @($inv.repositories | Where-Object { $_.Classification -eq 'non-git' } | ForEach-Object { $_.Path })
    } catch { }
  }

  $nonGitDirectories = Get-ChildItem -Path $WorkspaceParent -Directory | Where-Object {
    $dir = $_
    -not $dir.Name.StartsWith('.') -and -not (Test-Path -LiteralPath (Join-Path $dir.FullName '.git'))
  }

  return [pscustomobject]@{
    Status = 'OK'
    TrackedNonGitCount = $trackedNonGit.Count
    NonGitDirectoryCount = $nonGitDirectories.Count
  }
}

function Assert-StabilizationPolicy {
  [CmdletBinding()]
  param(
    [string]$StabilizationPath,

    [string]$RealRepoTestPlanPath,

    [string]$WorkspaceRoot
  )

  if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Get-WorkspaceRoot
  }

  $copilotRoot = Join-Path $WorkspaceRoot '.copilot'

  if (-not $StabilizationPath) {
    $StabilizationPath = Join-Path $copilotRoot 'History\Logs\Stabilization.json'
  }

  if (-not $RealRepoTestPlanPath) {
    $RealRepoTestPlanPath = Join-Path $copilotRoot 'History\Logs\RealRepoTestPlan.json'
  }

  foreach ($requiredPath in @($StabilizationPath, $RealRepoTestPlanPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
      throw "Policy file missing: $requiredPath"
    }
  }

  $stabilizationState = Get-Content -Raw -Path $StabilizationPath | ConvertFrom-Json
  $realRepoPlan = Get-Content -Raw -Path $RealRepoTestPlanPath | ConvertFrom-Json
  $requiredOffLimits = @('D:\Git_Repositories\Workspace_AC', 'B:\Backups\Base_WS_AC')

  foreach ($requiredOffLimit in $requiredOffLimits) {
    if (@($stabilizationState.off_limits_paths) -notcontains $requiredOffLimit) {
      throw "Missing off-limits path in stabilization state: $requiredOffLimit"
    }
  }

  if ($stabilizationState.real_repository_testing_enabled -ne $false) {
    throw 'real_repository_testing_enabled must remain false during self-stabilization.'
  }

  if ($stabilizationState.external_repository_write_allowed -ne $false) {
    throw 'external_repository_write_allowed must remain false during self-stabilization.'
  }

  if ($realRepoPlan.write_allowed -ne $false -or $realRepoPlan.dry_run.write_allowed -ne $false) {
    throw 'Real-repository test plan must remain read-only during self-stabilization.'
  }

  if ($realRepoPlan.enabled -eq $true -and ($realRepoPlan.mode -ne 'dry-run' -or -not $realRepoPlan.selected_repository -or $realRepoPlan.dry_run.enabled -ne $true)) {
    throw 'Enabled real-repository testing must be a selected, confirmed read-only dry-run.'
  }

  return [pscustomobject]@{
    Status = 'OK'
    Phase = $stabilizationState.phase
    RealRepositoryTestingEnabled = $stabilizationState.real_repository_testing_enabled
    RealRepositorySelected = [bool]$realRepoPlan.selected_repository
    OffLimitsPathCount = @($stabilizationState.off_limits_paths).Count
  }
}

function Assert-RealRepoTestPlan {
  [CmdletBinding()]
  param(
    [string]$RealRepoTestPlanPath,

    [string]$StabilizationPath,

    [string]$WorkspaceRoot
  )

  if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Get-WorkspaceRoot
  }

  $copilotRoot = Join-Path $WorkspaceRoot '.copilot'

  if (-not $RealRepoTestPlanPath) {
    $RealRepoTestPlanPath = Join-Path $copilotRoot 'History\Logs\RealRepoTestPlan.json'
  }

  if (-not $StabilizationPath) {
    $StabilizationPath = Join-Path $copilotRoot 'History\Logs\Stabilization.json'
  }

  foreach ($requiredPath in @($RealRepoTestPlanPath, $StabilizationPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
      throw "Real-repository policy file missing: $requiredPath"
    }
  }

  $realRepoPlan = Get-Content -Raw -Path $RealRepoTestPlanPath | ConvertFrom-Json
  $stabilizationState = Get-Content -Raw -Path $StabilizationPath | ConvertFrom-Json

  if (-not $realRepoPlan.PSObject.Properties['dry_run']) {
    throw 'Real-repository test plan is missing dry_run policy block.'
  }

  if (-not $realRepoPlan.PSObject.Properties['candidate_policy']) {
    throw 'Real-repository test plan is missing candidate_policy block.'
  }

  if (-not $realRepoPlan.PSObject.Properties['transition_policy']) {
    throw 'Real-repository test plan is missing transition_policy block.'
  }

  if (-not $realRepoPlan.PSObject.Properties['target_profile']) {
    throw 'Real-repository test plan is missing target_profile block.'
  }

  if (-not $realRepoPlan.PSObject.Properties['action_preview']) {
    throw 'Real-repository test plan is missing action_preview block.'
  }

  if (-not $realRepoPlan.PSObject.Properties['repository_lifecycle_policy']) {
    throw 'Real-repository test plan is missing repository_lifecycle_policy block.'
  }

  if (-not $realRepoPlan.PSObject.Properties['integrity_preflight_policy']) {
    throw 'Real-repository test plan is missing integrity_preflight_policy block.'
  }

  $lifecyclePolicy = $realRepoPlan.repository_lifecycle_policy
  if ($lifecyclePolicy.inside_workspace_parent_is_not_sufficient_for_operation -ne $true) {
    throw 'Repository lifecycle policy must state that location under the workspace parent is not enough for operation.'
  }

  $lifecycleStates = @($lifecyclePolicy.states)
  foreach ($requiredLifecycleState in @('discovered-only', 'blocked-do-not-operate', 'candidate', 'read-only-dry-run', 'external-intake', 'cleanup-candidate', 'active-governed', 'retired')) {
    if (-not ($lifecycleStates | Where-Object { $_.id -eq $requiredLifecycleState })) {
      throw "Repository lifecycle policy is missing state: $requiredLifecycleState"
    }
  }

  if ($lifecyclePolicy.external_code_policy.outside_code_is_evidence_not_authority -ne $true) {
    throw 'External code intake policy must treat outside code as evidence, not authority.'
  }

  if ($lifecyclePolicy.external_code_policy.intake_may_create_repo_skeleton -ne $true -or $lifecyclePolicy.external_code_policy.intake_stops_for_review_before_remediation -ne $true) {
    throw 'External code intake policy must create or populate structure and stop for review before remediation.'
  }

  if (-not $lifecyclePolicy.PSObject.Properties['proposal_location_policy']) {
    throw 'Repository lifecycle policy is missing proposal_location_policy block.'
  }

  $proposalLocationPolicy = $lifecyclePolicy.proposal_location_policy
  if ($proposalLocationPolicy.proposals_are_target_local -ne $true -or $proposalLocationPolicy.workspace_ai_does_not_store_target_repo_proposals -ne $true) {
    throw 'Proposal location policy must keep ordinary repo proposals target-local.'
  }

  if ($proposalLocationPolicy.ordinary_repo_proposal_root -ne 'Docs/Methods/Proposals' -or $proposalLocationPolicy.ordinary_repo_required_review_format -ne 'md') {
    throw 'Ordinary repo proposals must be Markdown files under Docs/Methods/Proposals.'
  }

  if ($proposalLocationPolicy.markdown_review_source_of_truth -ne $true -or $proposalLocationPolicy.proposal_may_not_be_accepted_from_json_sidecar_only -ne $true) {
    throw 'Markdown proposal files must be the review source of truth.'
  }

  if ($proposalLocationPolicy.json_sidecars_allowed -ne $true -or $proposalLocationPolicy.json_sidecars_reviewable -ne $false -or $proposalLocationPolicy.json_sidecars_have_independent_authority -ne $false) {
    throw 'JSON proposal sidecars must be non-reviewable derived artifacts without independent authority.'
  }

  if ($proposalLocationPolicy.proposal_directory_is_working_review_queue -ne $true -or $proposalLocationPolicy.accepted_implemented_proposals_are_void -ne $true -or $proposalLocationPolicy.void_proposals_must_be_removed_from_proposal_dir -ne $true) {
    throw 'Proposal directory policy must treat accepted and implemented proposals as void review artifacts that are removed from Docs/Methods/Proposals.'
  }

  if ($lifecyclePolicy.cleanup_policy.starts_as_proposal_only -ne $true) {
    throw 'Cleanup policy must start as proposal-only.'
  }

  if ($lifecyclePolicy.cleanup_policy.implemented_accepted_proposal_cleanup_required -ne $true -or $lifecyclePolicy.cleanup_policy.proposal_cleanup_must_not_delete_logs_results_or_permanent_records -ne $true) {
    throw 'Cleanup policy must require cleanup of accepted and implemented proposal files without deleting durable logs, results, or records.'
  }

  if ($lifecyclePolicy.cleanup_policy.proposal_cleanup_check_command -ne 'tools/Test-RealRepoProposalCleanup.ps1' -or $lifecyclePolicy.cleanup_policy.proposal_cleanup_check_is_read_only -ne $true) {
    throw 'Cleanup policy must provide a read-only target-local proposal cleanup check command.'
  }

  $proposalCleanupCheckPath = Join-Path $WorkspaceRoot $lifecyclePolicy.cleanup_policy.proposal_cleanup_check_command
  if (-not (Test-Path -LiteralPath $proposalCleanupCheckPath)) {
    throw "Proposal cleanup check command is missing: $proposalCleanupCheckPath"
  }

  $integrityPreflightPolicy = $realRepoPlan.integrity_preflight_policy
  if ($integrityPreflightPolicy.mode -ne 'explicit-event-triggered-cost-tiered') {
    throw 'Integrity preflight must be explicit, event-triggered, and cost-tiered.'
  }

  if ($integrityPreflightPolicy.surreptitious_checks_allowed -ne $false -or $integrityPreflightPolicy.periodic_background_checks_allowed -ne $false) {
    throw 'Integrity preflight must not allow hidden or periodic background checks.'
  }

  if ($integrityPreflightPolicy.repo_wide_checksum_default_allowed -ne $false) {
    throw 'Integrity preflight must not allow repo-wide checksums by default.'
  }

  if ($integrityPreflightPolicy.escalation_policy.use_cheapest_discriminating_check_first -ne $true -or $integrityPreflightPolicy.escalation_policy.report_before_expensive_checks -ne $true) {
    throw 'Integrity preflight must use cheap checks first and report before expensive checks.'
  }

  if (@($realRepoPlan.dry_run.adapter_surface_candidates).Count -eq 0) {
    throw 'Real-repository dry-run requires at least one adapter surface candidate.'
  }

  $allowedGitCommands = @($realRepoPlan.dry_run.allowed_git_commands)
  if ($allowedGitCommands.Count -eq 0) {
    throw 'Real-repository dry-run requires an explicit read-only Git command allow-list.'
  }

  $forbiddenGitPatterns = @(' add ', ' commit', ' checkout', ' reset', ' clean', ' merge', ' rebase', ' stash')
  foreach ($allowedGitCommand in $allowedGitCommands) {
    $currentAllowedGitCommand = " $([string]$allowedGitCommand)"
    foreach ($forbiddenGitPattern in $forbiddenGitPatterns) {
      if ($currentAllowedGitCommand -like "*$forbiddenGitPattern*") {
        throw "Real-repository dry-run Git command allow-list contains forbidden command: $allowedGitCommand"
      }
    }
  }

  if ($realRepoPlan.write_allowed -ne $false -or $realRepoPlan.dry_run.write_allowed -ne $false) {
    throw 'Real-repository test plan must keep all write permissions disabled during self-stabilization.'
  }

  if ($realRepoPlan.candidate_policy.selection_does_not_enable_writes -ne $true) {
    throw 'Real-repository candidate selection must not enable writes.'
  }

  if ($realRepoPlan.transition_policy.write_enablement_supported -ne $false) {
    throw 'LCM_AI transition policy must not support write enablement during self-stabilization.'
  }

  if ($realRepoPlan.transition_policy.workspace_ai_dry_run_enablement_supported -ne $false) {
    throw 'LCM_AI must not support local enablement of target-repo dry-run state.'
  }

  if (-not $realRepoPlan.PSObject.Properties['target_method_instance_policy']) {
    throw 'Real-repository test plan is missing target_method_instance_policy block.'
  }

  $targetMethodInstancePolicy = $realRepoPlan.target_method_instance_policy
  if ($targetMethodInstancePolicy.target_repo_owns_method_instance -ne $true -or $targetMethodInstancePolicy.workspace_ai_role -ne 'method-baseline-only') {
    throw 'Target repository must own the method instance while LCM_AI remains baseline-only.'
  }

  if ($targetMethodInstancePolicy.target_repo_method_root -ne 'Docs/Methods') {
    throw 'Target-local method instance root must be Docs/Methods.'
  }

  if ($targetMethodInstancePolicy.bootstrap_command -ne 'tools/Initialize-RealRepoMethodInstance.ps1' -or $targetMethodInstancePolicy.bootstrap_writes_only_target_method_instance -ne $true -or $targetMethodInstancePolicy.bootstrap_must_not_stage_or_commit_target_repo -ne $true) {
    throw 'Target-local method instance bootstrap policy must be explicit, target-scoped, and must not stage or commit target changes.'
  }

  $bootstrapCommandPath = Join-Path $WorkspaceRoot $targetMethodInstancePolicy.bootstrap_command
  if (-not (Test-Path -LiteralPath $bootstrapCommandPath)) {
    throw "Target-local method instance bootstrap command is missing: $bootstrapCommandPath"
  }

  if ($targetMethodInstancePolicy.workspace_ai_must_not_store_target_dry_run_results -ne $true -or $targetMethodInstancePolicy.workspace_ai_must_not_store_target_work_logs -ne $true -or $targetMethodInstancePolicy.workspace_ai_must_not_store_target_repo_proposals -ne $true) {
    throw 'LCM_AI must not store target dry-run results, work logs, or repo proposals.'
  }

  if ($targetMethodInstancePolicy.target_local_method_instance_auto_accepted_for_candidate_repos -ne $true) {
    throw 'Target-local method instance must be treated as an automatically accepted structural override for candidate repos.'
  }

  if ($realRepoPlan.mode -eq 'not-selected' -and $realRepoPlan.selected_repository) {
    throw 'Real-repository test plan cannot have mode not-selected while selected_repository is set.'
  }

  if ($realRepoPlan.mode -eq 'not-selected' -and $realRepoPlan.dry_run.enabled -ne $false) {
    throw 'Real-repository dry-run must be disabled when no repository is selected.'
  }

  $targetMethodInstance = $null
  if ($realRepoPlan.selected_repository) {
    $selectedRepository = [System.IO.Path]::GetFullPath([string]$realRepoPlan.selected_repository).TrimEnd('\')
    $targetMethodInstance = Resolve-TargetMethodInstance -RepositoryPath $selectedRepository
  }

  if ($realRepoPlan.mode -eq 'candidate-selected') {
    if ($targetMethodInstance -and $targetMethodInstance.Exists) {
      if ($realRepoPlan.dry_run.status -ne 'ready-for-read-only-dry-run') {
        throw 'Candidate-selected dry-run status must be ready after the target-local method instance exists.'
      }

      if ($realRepoPlan.action_preview.status -ne 'ready-read-only-action-preview') {
        throw 'Candidate-selected action preview must be ready after the target-local method instance exists.'
      }
    } else {
      if ($realRepoPlan.action_preview.status -ne 'blocked-until-target-local-method-instance') {
        throw 'Candidate-selected action preview must remain blocked until the target-local method instance exists.'
      }
    }
  }

  if ($realRepoPlan.mode -eq 'dry-run' -or $realRepoPlan.dry_run.enabled -eq $true) {
    throw 'LCM_AI-local dry-run mode is no longer valid; target dry-run state must be target-local.'
  }

  if ($realRepoPlan.target_profile.write_probe_performed -ne $false) {
    throw 'Real-repository dry-run target profile must not perform write probes.'
  }

  if ($realRepoPlan.action_preview.write_allowed -ne $false) {
    throw 'Real-repository action preview must remain read-only.'
  }

  foreach ($requiredActionType in @('would-create-adapter-surface', 'would-update-adapter-surface', 'would-review-existing-adapter-surface', 'would-leave-target-unchanged')) {
    if (@($realRepoPlan.action_preview.allowed_action_types) -notcontains $requiredActionType) {
      throw "Real-repository action preview is missing allowed action type: $requiredActionType"
    }
  }

  foreach ($requiredActionType in @('would-assess-repository-structure', 'would-check-repository-specifications', 'would-check-documentation-level', 'would-report-documentation-discrepancies', 'would-queue-documentation-change-request')) {
    if (@($realRepoPlan.action_preview.allowed_action_types) -notcontains $requiredActionType) {
      throw "Real-repository phased dry-run is missing allowed action type: $requiredActionType"
    }
  }

  $phases = @($realRepoPlan.action_preview.phases)
  if ($phases.Count -lt 5) {
    throw 'Real-repository action preview requires a phased dry-run sequence.'
  }

  $documentationPhase = $phases | Where-Object { $_.id -eq 'phase-04-documentation-discrepancies' } | Select-Object -First 1
  if (-not $documentationPhase -or $documentationPhase.scope -ne 'documentation-only' -or $documentationPhase.write_allowed -ne $false) {
    throw 'Real-repository dry-run must include a read-only documentation discrepancy phase.'
  }

  foreach ($phase in $phases) {
    if ($phase.write_allowed -ne $false) {
      throw "Real-repository dry-run phase must remain read-only: $($phase.id)"
    }
  }

  if (-not $realRepoPlan.action_preview.PSObject.Properties['change_request_flow']) {
    throw 'Real-repository action preview is missing bottom-up change_request_flow block.'
  }

  $changeRequestFlow = $realRepoPlan.action_preview.change_request_flow
  if ($changeRequestFlow.orientation -ne 'bottom-up') {
    throw 'Concrete change-request flow must be bottom-up.'
  }

  if ($changeRequestFlow.documentation_changes_expected -ne $true) {
    throw 'Concrete change-request flow must allow documentation changes after approval.'
  }

  $changeRequestPhases = @($changeRequestFlow.phases)
  foreach ($requiredChangeRequestPhase in @('cr-01-analyze-request', 'cr-02-determine-impact', 'cr-03-propose-doc-changes', 'cr-04-propose-code-changes')) {
    if (-not ($changeRequestPhases | Where-Object { $_.id -eq $requiredChangeRequestPhase })) {
      throw "Concrete change-request flow is missing phase: $requiredChangeRequestPhase"
    }
  }

  foreach ($changeRequestPhase in $changeRequestPhases) {
    if ($changeRequestPhase.write_allowed -ne $false -and $changeRequestPhase.write_allowed -ne 'requires-approval') {
      throw "Concrete change-request phase has invalid write policy: $($changeRequestPhase.id)"
    }
  }

  foreach ($requiredComparisonState in @('target-missing', 'target-identical', 'target-different', 'source-missing')) {
    if (@($realRepoPlan.action_preview.comparison_states) -notcontains $requiredComparisonState) {
      throw "Real-repository action preview is missing comparison state: $requiredComparisonState"
    }
  }

  $forbiddenActionTypes = @($realRepoPlan.action_preview.forbidden_action_types)
  foreach ($forbiddenActionType in @('write-file', 'delete-file', 'stage-file', 'commit-file', 'run-target-installer')) {
    if ($forbiddenActionTypes -notcontains $forbiddenActionType) {
      throw "Real-repository action preview is missing forbidden action type: $forbiddenActionType"
    }
  }

  if ($realRepoPlan.selected_repository) {
    $selectedRepository = [System.IO.Path]::GetFullPath([string]$realRepoPlan.selected_repository).TrimEnd('\')
    $workspaceRootPath = [System.IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\')
    if ($selectedRepository.Equals($workspaceRootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw 'LCM_AI cannot be selected as its own real-repository test target.'
    }

    foreach ($offLimitsPath in @($stabilizationState.off_limits_paths)) {
      $normalizedOffLimitsPath = [System.IO.Path]::GetFullPath([string]$offLimitsPath).TrimEnd('\')
      if ($selectedRepository.Equals($normalizedOffLimitsPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Selected repository is off-limits: $selectedRepository"
      }
    }
  }

  return [pscustomobject]@{
    Status = 'OK'
    Mode = $realRepoPlan.mode
    DryRunEnabled = $realRepoPlan.dry_run.enabled
    DryRunStatus = $realRepoPlan.dry_run.status
    SelectedRepository = $realRepoPlan.selected_repository
    WriteAllowed = $realRepoPlan.write_allowed
    ConfirmationRequired = $realRepoPlan.transition_policy.dry_run_requires_read_only_confirmation
    AdapterSurfaceCandidateCount = @($realRepoPlan.dry_run.adapter_surface_candidates).Count
    AllowedGitCommandCount = $allowedGitCommands.Count
    ActionPreviewStatus = $realRepoPlan.action_preview.status
    ActionPreviewPhaseCount = $phases.Count
    DocumentationFirstPhase = $documentationPhase.id
    ChangeRequestPhaseCount = $changeRequestPhases.Count
    ChangeRequestOrientation = $changeRequestFlow.orientation
    LifecycleStateCount = $lifecycleStates.Count
    IntegrityPreflightMode = $integrityPreflightPolicy.mode
    OrdinaryRepoProposalRoot = $proposalLocationPolicy.ordinary_repo_proposal_root
    ProposalReviewFormat = $proposalLocationPolicy.ordinary_repo_required_review_format
    ProposalCleanupRequired = $lifecyclePolicy.cleanup_policy.implemented_accepted_proposal_cleanup_required
    VoidProposalRemovalRequired = $proposalLocationPolicy.void_proposals_must_be_removed_from_proposal_dir
    ProposalCleanupCheckCommand = $lifecyclePolicy.cleanup_policy.proposal_cleanup_check_command
    TargetMethodRoot = $targetMethodInstancePolicy.target_repo_method_root
    TargetDryRunRoot = $targetMethodInstancePolicy.target_repo_dry_run_root
    TargetBootstrapCommand = $targetMethodInstancePolicy.bootstrap_command
    TargetMethodInstancePresent = [bool]($targetMethodInstance -and $targetMethodInstance.Exists)
  }
}

function Assert-StaleAuthorityReferences {
  [CmdletBinding()]
  param(
    [string]$WorkspaceRoot
  )

  if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Get-WorkspaceRoot
  }

  $scanRoots = @(
    (Join-Path $WorkspaceRoot '.vscode'),
    (Join-Path $WorkspaceRoot '.copilot'),
    (Join-Path $WorkspaceRoot '.github'),
    (Join-Path $WorkspaceRoot 'docs'),
    (Join-Path $WorkspaceRoot 'tools')
  )

  $allowedFiles = @(
    '.vscode/settings.json',
    'docs/real-repo-dry-run.md',
    '.copilot/History/Logs/Stabilization.json',
    '.copilot/History/Logs/Proposals.json',
    'tools/QualityGates/WorkspaceQualityGates.psm1'
  )

  $staleAuthorityPatterns = @(
    'Workspace_AC Engine',
    'Workspace_GC Engine',
    'Workspace_AC fix-module execution',
    'Workspace_GC fix-module execution',
    'Path: D:/Git_Repositories/Workspace_AC',
    'Path: D:/Git_Repositories/Workspace_GC',
    'Canonical workspace root:\s*D:\\Git_Repositories\\Workspace_AC',
    'Canonical workspace root:\s*D:\\Git_Repositories\\Workspace_GC',
    'authoritative path:\s*D:\\Git_Repositories\\Workspace_GC',
    'authoritative path:\s*D:\\Git_Repositories\\Workspace_AC'
  )

  $matches = @()
  foreach ($scanRoot in $scanRoots) {
    if (-not (Test-Path -LiteralPath $scanRoot)) {
      continue
    }

    $files = Get-ChildItem -Path $scanRoot -Recurse -File -Include *.ps1,*.psm1,*.json,*.md
    foreach ($file in $files) {
      $currentFile = $file
      $relativePath = $currentFile.FullName.Substring($WorkspaceRoot.Length).TrimStart('\').Replace('\', '/')
      if ($relativePath -like '.copilot/Logs/*' -or $relativePath -like '.copilot/History/Logs/*' -or $relativePath -like 'docs/Logs/*') {
        continue
      }

      if ($allowedFiles -contains $relativePath) {
        continue
      }

      $fileMatches = Select-String -Path $currentFile.FullName -Pattern $staleAuthorityPatterns -ErrorAction Stop
      foreach ($fileMatch in @($fileMatches)) {
        $currentMatch = $fileMatch
        $matches += [pscustomobject]@{
          Path = $relativePath
          Line = $currentMatch.LineNumber
          Text = $currentMatch.Line.Trim()
        }
      }
    }
  }

  if ($matches.Count -gt 0) {
    $message = ($matches | ForEach-Object { "$($_.Path):$($_.Line) $($_.Text)" }) -join '; '
    throw "Unexpected stale authority references found: $message"
  }

  return [pscustomobject]@{
    Status = 'OK'
    ScannedRoots = $scanRoots.Count
    UnexpectedReferenceCount = 0
  }
}

function Assert-PesterV5Syntax {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$TargetRepositoryPath
  )

  if (-not (Test-Path -LiteralPath $TargetRepositoryPath)) {
    throw "Target repository path not found: $TargetRepositoryPath"
  }

  $testFiles = @(Get-ChildItem -Path $TargetRepositoryPath -Recurse -File -Include *.Tests.ps1,*.tests.ps1 | Where-Object { $_.FullName -notmatch '\\\.git\\' })
  $violations = @()

  $v4Pattern = '(?<![\w-])Should\s+(?:Not\s+)?(Be|BeGreaterThan|BeLessThan|BeNullOrEmpty|Throw|Match|Contain|BeOfType|BeTrue|BeFalse|BeInSet|BeLike|Exist)\b'

  foreach ($file in $testFiles) {
    $found = Select-String -Path $file.FullName -Pattern $v4Pattern
    foreach ($m in $found) {
      $violations += [pscustomobject]@{
        File       = $file.FullName
        LineNumber = $m.LineNumber
        Line       = $m.Line.Trim()
      }
    }
  }

  if ($violations.Count -gt 0) {
    $summary = ($violations | ForEach-Object { "$($_.File):$($_.LineNumber) -> $($_.Line)" }) -join "`n"
    throw "Pester v4 legacy syntax detected! Pester v5 requires hyphenated syntax (e.g. 'Should -Be', 'Should -Not -BeNullOrEmpty'):`n$summary"
  }

  return [pscustomobject]@{
    Status           = 'OK'
    TestFilesChecked = $testFiles.Count
    Violations       = 0
  }
}

function Assert-TripartiteDocumentationCompliance {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$TargetRepositoryPath,

    [Parameter(Mandatory=$false)]
    [switch]$ThrowOnMissing
  )

  if (-not (Test-Path -LiteralPath $TargetRepositoryPath)) {
    throw "Target repository path not found: $TargetRepositoryPath"
  }

  $docsDir = Join-Path $TargetRepositoryPath 'docs'
  $requiredDocs = @('Architecture.md', 'Requirements.md', 'Implementation.md')
  $results = @{}
  $missing = @()

  foreach ($doc in $requiredDocs) {
    $docPath = Join-Path $docsDir $doc
    if (Test-Path -LiteralPath $docPath) {
      $content = Get-Content -LiteralPath $docPath -Raw
      $hasDox = ($content -match '(?m)^Module:\s+' -and $content -match '(?m)^Purpose:\s+')
      $results[$doc] = [pscustomobject]@{
        Exists  = $true
        DoxHeader = $hasDox
      }
    }
    else {
      $results[$doc] = [pscustomobject]@{
        Exists  = $false
        DoxHeader = $false
      }
      $missing += $doc
    }
  }

  $isCompliant = ($missing.Count -eq 0)

  if ($ThrowOnMissing -and -not $isCompliant) {
    throw "Repository '$TargetRepositoryPath' violates RULE-DOC-001 (Tripartite Documentation Standard). Missing: $($missing -join ', ')"
  }

  return [pscustomobject]@{
    RepositoryPath = $TargetRepositoryPath
    IsCompliant    = $isCompliant
    MissingDocs    = $missing
    Details        = $results
  }
}

Export-ModuleMember -Function Get-WorkspaceRoot, Resolve-TargetMethodInstance, Assert-IgnoredRepositories, Assert-StabilizationPolicy, Assert-RealRepoTestPlan, Assert-StaleAuthorityReferences, Assert-PesterV5Syntax, Assert-TripartiteDocumentationCompliance