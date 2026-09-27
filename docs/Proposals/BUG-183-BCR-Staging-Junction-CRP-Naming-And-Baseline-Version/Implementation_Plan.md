# BUG-183 Implementation Plan: Beyond Compare Review Staging Naming Alignment

## Proposed Changes

### `Workspace_Inventory/tools/Invoke-BeyondCompareReview.ps1`
1. **Update `Get-ActiveCRP`**:
   - Normalize target repo names and support root repository aliases (`Git_Repositories`, `Root`, `LCM`).
   - Match unpushed proposals (`state -notin @('pushed', 'deleted')`), prioritizing `in_progress`, `review`, `staged`, `suggested`, followed by `completed` and `committed`.
   - Add commit message regex inspection (`(?i)\b(CRP-\d+|BUG-\d+|CR-\d+)\b`) from target repo Git log.
2. **Early Baseline Version Resolution**:
   - Resolve `$baselineVersion = Get-RepoVersion -TargetRepoPath $repoPath -TargetCommit $commitSha` before directory path construction.
3. **Left-Hand Baseline Directory Stem**:
   - Set `$reviewFolderStem = "Baseline_${repoName}_v${baselineVersion}_${commitSha}"` (or without commit if `unborn`).
4. **Right-Hand Live Junction Stem**:
   - Set `$liveJunctionStem = if (-not [string]::IsNullOrWhiteSpace($CRP)) { "Live_${repoName}_${CRP}" } else { "Live_${repoName}" }`.
   - Purge stale `Live_*` junctions in `$crpReviewDir` before creating the fresh junction.
5. **Pass Title Arguments**:
   - Include `/title1="$title1" /title2="$title2"` in `$bcArgString`.
6. **Increment Version**: Bump to `8.1.0`.

### `Workspace_Inventory/assets/CM_CONTROL_HUB.html`
1. Update `launchReviewForProposal` at line 3867:
   - Change `const crpArg = crp && crp.startsWith("CRP-") ? ...` to `const crpArg = crp ? `-CRP "${crp}"` : "";`.

## Verification Strategy
1. Unit test `Get-ActiveCRP` against `Workspace_Inventory` to verify it resolves `CRP-182` or `BUG-183`.
2. Dry-run `Invoke-BeyondCompareReview.ps1 -RepositoryName Workspace_Inventory` (or inspect path generation) to ensure:
   - Left path contains `Baseline_Workspace_Inventory_v8.0.0_<SHA>`
   - Right path contains `Live_Workspace_Inventory_<CRP>`
3. Run `Test-RepoReadiness.ps1` to verify quality gates.
