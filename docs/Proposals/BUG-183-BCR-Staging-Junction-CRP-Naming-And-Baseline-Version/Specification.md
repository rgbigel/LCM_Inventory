---
Bug-ID: BUG-183
Scope: LCM_Inventory
Version: 10.0.0
Affected-Repos: [LCM_Inventory]
Severity: Medium
Status: Open
Root-Cause: Invoke-BeyondCompareReview.ps1 constructed right-hand live review junctions using static leaf 'Live_${repoName}' without embedding the CRP number, and left-hand baseline folders using 'Baseline_${repoName}_${commitSha}' without embedding the baseline Version. In Beyond Compare 5, narrow path input boxes truncate from the left, obscuring both the parent CRP directory and the repository identity. Furthermore, Get-ActiveCRP omitted unpushed 'completed' and 'committed' proposals, and CM_CONTROL_HUB.html only forwarded CRP-prefixed proposal IDs.
---

# BUG-183 Specification: Beyond Compare Review Staging Naming Alignment & Active CRP Resolution

## 1. Problem Statement
When launching a Beyond Compare 5 review session via `Invoke-BeyondCompareReview.ps1` (or `bcr` / `BCR` / CM Control Hub):
1. **Right-Hand Side Junction Naming**: The junction was constructed as `Join-Path $crpReviewDir "Live_${repoName}"` (e.g. `...\scratch\BC_Review\Review_LCM_Inventory\Live_LCM_Inventory`). Due to path length, Beyond Compare's path input box truncates from the left, displaying only the last ~25 characters (`...Live_LCM_Inventory`), completely obscuring the CRP number even if a parent CRP folder was present.
2. **Left-Hand Side Baseline Version Naming**: The baseline export directory was constructed as `Baseline_${repoName}_${commitSha}`. The baseline semantic version (`$baselineVersion`, e.g. `10.0.0`) was omitted from the directory name and only resolved late in the script for terminal output. Because Beyond Compare 5 folder comparisons do not render CLI `/title1` / `/title2` switches, the user could not see the baseline version in the path box.
3. **`Get-ActiveCRP` Resolution Gap**: `Get-ActiveCRP` only matched proposals in `@('in_progress', 'staged', 'suggested', 'review')`. When a proposal is at Gate 2 with state `completed` or `committed` awaiting review prior to `git push`, `Get-ActiveCRP` returned empty, falling back to `Review_${repoName}`.
4. **CM Control Hub Forwarding Filter**: In `CM_CONTROL_HUB.html` (line 3867), `launchReviewForProposal` only passed `-CRP` if `crp.startsWith("CRP-")`, dropping the parameter for `BUG-###` defect proposals.

## 2. Requirements & Desired Behavior
1. **Right-Hand Live Junction**: Include the proposal identifier in the leaf junction name: `Live_${repoName}_${CRP}` (e.g. `Live_LCM_Inventory_CRP-182` or `Live_LCM_Inventory_BUG-183`). When truncated to the rightmost 25 characters, the proposal ID is guaranteed to be prominently visible.
2. **Left-Hand Baseline Directory**: Include the baseline semantic version and commit SHA: `Baseline_${repoName}_v${baselineVersion}_${commitSha}` (e.g. `Baseline_LCM_Inventory_10.0.0_e94f262`). When truncated to the rightmost 25 characters, `v${baselineVersion}_${commitSha}` is prominently visible.
3. **Robust Active CRP Resolution**: Expand `Get-ActiveCRP` to recognize all unpushed proposals (`state -notin @('pushed', 'deleted')`), prioritizing in-flight, completed, and committed proposals for the target repository, and inspecting recent git commit messages and aliases for `Git_Repositories`.
4. **Universal Control Hub Forwarding**: Update `CM_CONTROL_HUB.html` to forward any non-empty `crp` string (supporting both `CRP-###` and `BUG-###`).
