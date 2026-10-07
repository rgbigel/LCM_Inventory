<#
.SYNOPSIS
  Read LCM_AI real-repository test plan state without changing it.

.PARAMETER AsJson
  Output the test plan state in JSON format.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Output the test plan state in JSON format.')]
  [switch]$AsJson,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Get-RealRepoTestPlan.ps1 - Inspect real-repository test plan state." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Get-RealRepoTestPlan.ps1 [-AsJson] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -AsJson Output plan state as JSON."
  Write-Host "  -Help   (-h, -?) Displays this help message."
  exit 0
}

<#
Module: Get-RealRepoTestPlan.ps1
Purpose: Read LCM_AI real-repository test plan state without changing it.
Path: tools/Get-RealRepoTestPlan.ps1
Authors: LCM_AI Engine
Version: 1.11.0
Caller Contract: Called by operators or governance scripts when inspecting real-repository dry-run state; performs no external repository access.
Changelog:
- 2026-08-02: Added proposal cleanup check summary field.
- 2026-08-02: Added target-local method instance bootstrap summary field.
- 2026-08-02: Added proposal-directory cleanup summary fields.
- 2026-08-02: Added target-local method instance ownership summary fields.
- 2026-08-02: Added proposal location and Markdown authority summary fields.
- 2026-08-02: Added lifecycle and integrity preflight policy summary fields.
- 2026-08-01: Added bottom-up change-request flow summary fields.
- 2026-08-01: Added phased dry-run sequence summary fields.
- 2026-08-01: Added intended-action preview status fields.
- 2026-08-01: Added read-only Git command allow-list count.
- 2026-08-01: Added adapter surface and target profile summary fields.
- 2026-08-01: Added read-only real-repository test plan inspection command.
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$planPath = Join-Path $workspaceRoot '.copilot\History\Logs\RealRepoTestPlan.json'

if (-not (Test-Path -LiteralPath $planPath)) {
  throw "Real-repository test plan not found: $planPath"
}

$plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json
$result = [pscustomobject]@{
  Status = 'OK'
  Mode = $plan.mode
  Enabled = $plan.enabled
  SelectedRepository = $plan.selected_repository
  DryRunEnabled = $plan.dry_run.enabled
  DryRunStatus = $plan.dry_run.status
  WriteAllowed = $plan.write_allowed
  RequiresUserConfirmation = $plan.requires_user_confirmation
  AdapterSurfaceCandidateCount = @($plan.dry_run.adapter_surface_candidates).Count
  AllowedGitCommandCount = @($plan.dry_run.allowed_git_commands).Count
  TargetProfileStatus = $plan.target_profile.status
  ActionPreviewStatus = $plan.action_preview.status
  ActionPreviewWriteAllowed = $plan.action_preview.write_allowed
  ActionPreviewPhaseCount = @($plan.action_preview.phases).Count
  DocumentationFirstPhase = 'phase-04-documentation-discrepancies'
  ChangeRequestOrientation = $plan.action_preview.change_request_flow.orientation
  ChangeRequestPhaseCount = @($plan.action_preview.change_request_flow.phases).Count
  LifecycleStateCount = @($plan.repository_lifecycle_policy.states).Count
  IntegrityPreflightMode = $plan.integrity_preflight_policy.mode
  HiddenIntegrityChecksAllowed = $plan.integrity_preflight_policy.surreptitious_checks_allowed
  RepoWideChecksumDefaultAllowed = $plan.integrity_preflight_policy.repo_wide_checksum_default_allowed
  OrdinaryRepoProposalRoot = $plan.repository_lifecycle_policy.proposal_location_policy.ordinary_repo_proposal_root
  ProposalReviewFormat = $plan.repository_lifecycle_policy.proposal_location_policy.ordinary_repo_required_review_format
  JsonSidecarsReviewable = $plan.repository_lifecycle_policy.proposal_location_policy.json_sidecars_reviewable
  ProposalCleanupRequired = $plan.repository_lifecycle_policy.cleanup_policy.implemented_accepted_proposal_cleanup_required
  VoidProposalRemovalRequired = $plan.repository_lifecycle_policy.proposal_location_policy.void_proposals_must_be_removed_from_proposal_dir
  ProposalCleanupCheckCommand = $plan.repository_lifecycle_policy.cleanup_policy.proposal_cleanup_check_command
  TargetMethodRoot = $plan.target_method_instance_policy.target_repo_method_root
  TargetDryRunRoot = $plan.target_method_instance_policy.target_repo_dry_run_root
  TargetBootstrapCommand = $plan.target_method_instance_policy.bootstrap_command
  WorkspaceStoresTargetDryRunResults = -not $plan.target_method_instance_policy.workspace_ai_must_not_store_target_dry_run_results
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6
} else {
  $result
}