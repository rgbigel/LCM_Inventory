# Implementation Plan: BUG-189

## Scope

1. Separate local review completion from remote publication.
2. Require a completed proposal cohort before remote dispatch.
3. Include every proposal `affected_repos` member and `LCM_Inventory` in the same preflight.
4. Update command-facing documentation and generated catalog metadata.
5. Add a proposal-only publication command for governed repositories that already contain `docs/Proposals`.
6. Add a bundle-in-HEAD preflight requirement before lifecycle `PUSH` may transition a completed proposal.

## Changed Components

- `LCM_Inventory/tools/Submit-ReviewResult.ps1`
- `LCM_Inventory/tools/Invoke-WorkspacePush.ps1`
- `LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1`
- `LCM_Inventory/modules/WorkspacePushEligibility.psm1`
- `LCM_Inventory/tests/WorkspacePushEligibility.Tests.ps1`
- `LCM_AI/.agents/rules/*.md`
- `LCM_Inventory/tools/hooks/Enforce-LcmPreToolPolicy.ps1`
- `LCM_Inventory/tools/Set-LcmActionProgress.ps1`
- Root macro summaries and generated tool catalog artifacts
- `LCM_Inventory/tools/Publish-WorkspaceProposalBundles.ps1`
- Proposal bundle publication and bundle-in-HEAD Pester tests

## Verification

- Parse all modified PowerShell files.
- Run focused Pester eligibility tests for rejected, successful, and blocked cohorts.
- Parse the regenerated tool catalog as JSON.
- Run `git diff --check` for all affected repositories.
- Verify proposal-only publication does not stage an unrelated dirty file.
- Verify lifecycle `PUSH` rejects a completed proposal whose bundle is absent from `HEAD`.
