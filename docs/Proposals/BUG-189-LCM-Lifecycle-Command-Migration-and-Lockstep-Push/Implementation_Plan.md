# Implementation Plan: BUG-189

## Scope

1. Separate local review completion from remote publication.
2. Require a completed proposal cohort before remote dispatch.
3. Include every proposal `affected_repos` member and `Workspace_Inventory` in the same preflight.
4. Update command-facing documentation and generated catalog metadata.
5. Add a proposal-only publication command for governed repositories that already contain `docs/Proposals`.
6. Add a bundle-in-HEAD preflight requirement before lifecycle `PUSH` may transition a completed proposal.

## Changed Components

- `Workspace_Inventory/tools/Submit-ReviewResult.ps1`
- `Workspace_Inventory/tools/Invoke-WorkspacePush.ps1`
- `Workspace_Inventory/tools/Invoke-BeyondCompareReview.ps1`
- `Workspace_Inventory/modules/WorkspacePushEligibility.psm1`
- `Workspace_Inventory/tests/WorkspacePushEligibility.Tests.ps1`
- `Workspace_AI/.agents/rules/*.md`
- `.lcm/tools/hooks/Enforce-LcmPreToolPolicy.ps1`
- `.lcm/tools/internal/Set-LcmActionProgress.ps1`
- Root macro summaries and generated tool catalog artifacts
- `Workspace_Inventory/tools/Publish-WorkspaceProposalBundles.ps1`
- Proposal bundle publication and bundle-in-HEAD Pester tests

## Verification

- Parse all modified PowerShell files.
- Run focused Pester eligibility tests for rejected, successful, and blocked cohorts.
- Parse the regenerated tool catalog as JSON.
- Run `git diff --check` for all affected repositories.
- Verify proposal-only publication does not stage an unrelated dirty file.
- Verify lifecycle `PUSH` rejects a completed proposal whose bundle is absent from `HEAD`.
