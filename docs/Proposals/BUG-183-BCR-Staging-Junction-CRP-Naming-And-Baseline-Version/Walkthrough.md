# BUG-183 Walkthrough: Beyond Compare Review Staging Naming Alignment & Active CRP Resolution

## 1. Problem & Root Cause Analysis
- **Right-Hand Side Junction Naming**: In `Invoke-BeyondCompareReview.ps1` (v8.0.0), the live review junction was created with the static leaf `Live_${repoName}` under `scratch\BC_Review\<CRP>\` (or `scratch\BC_Review\Review_${repoName}\`). Because Beyond Compare 5's path input boxes are narrow and truncate long paths from the left, only the last ~25 characters (`...Live_LCM_Inventory`) were visible, completely cutting off the CRP identifier and leaving no indication of which Change Request Proposal was under review.
- **Left-Hand Side Baseline Version Naming**: The baseline export tree was named `Baseline_${repoName}_${commitSha}`, omitting the baseline semantic version. The user believed that displaying the version was not achievable due to Beyond Compare CLI constraints (specifically that folder compare mode ignores `/title1` and `/title2`). However, because the baseline export folder is physically generated in scratch, embedding `v${baselineVersion}` directly in the folder stem completely bypasses this CLI constraint and makes the version prominently visible in the path box.
- **Active CRP Resolution Gap**: `Get-ActiveCRP` strictly searched for proposals with `state` in `@('in_progress', 'staged', 'suggested', 'review')`. At Gate 2, completed proposals awaiting review before remote push have `state: "completed"` or `state: "committed"`, causing `Get-ActiveCRP` to fail and fall back to `Review_${repoName}`.
- **CM Control Hub Filter Gap**: In `CM_CONTROL_HUB.html` (line 3867), `launchReviewForProposal` only passed `-CRP` if `crp.startsWith("CRP-")`, dropping the flag for `BUG-###` defect proposals.

---

## 2. Implementation Changes

### 1. `LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1` (v8.1.0)
- **Enhanced `Get-ActiveCRP`**:
  - Expanded proposal discovery to recognize all unpushed proposals (`state -notin @('pushed', 'deleted')`).
  - Added multi-phase priority matching: in-flight/review/suggested $\rightarrow$ unpushed completed/committed $\rightarrow$ newest overall.
  - Normalized target repo names with full alias support for root repository (`Git_Repositories`, `Root`, `LCM`, `LCM / Git_Repositories`).
  - Added Git commit message regex scanner (`(?i)\b(CRP-\d+|BUG-\d+|CR-\d+)\b`) for target repo.
- **Early Baseline Version Resolution**:
  - Moved `$baselineVersion = Get-RepoVersion -TargetRepoPath $repoPath -TargetCommit $commitSha` before scratch directory and junction construction.
- **Left-Hand Baseline Stem**:
  - Configured `$reviewFolderStem = "Baseline_${repoName}_v${baselineVersion}_${commitSha}"` (e.g. `Baseline_LCM_Inventory_v8.0.0_e94f262`).
- **Right-Hand Live Junction Stem**:
  - Configured `$liveJunctionStem = "Live_${repoName}_${CRP}"` (e.g. `Live_LCM_Inventory_BUG-183`).
  - Added pre-creation cleanup of stale `Live_*` junctions in `$crpReviewDir`.
- **BC Named Session Syntax Invariant**:
  - Reverted `$bcArgString = "`"$sessionName`" /ro1"`. In Beyond Compare 5 CLI syntax, appending `/title1` and `/title2` switches causes BC to treat the first argument as a relative file/folder path rather than a saved session name. In non-interactive/elevated contexts running from `System32`, this erroneously attempted to open `C:\Windows\System32\BUG-183_Review` as a second spurious compare tab. Relying purely on the named session saved in `BCSessions.xml` eliminates the spurious session and loads the exact left/right paths cleanly.

### 2. `LCM_Inventory/assets/CM_CONTROL_HUB.html`
- Updated line 3867: `const crpArg = crp ? `-CRP "${crp}"` : "";` to forward both `CRP-###` and `BUG-###` identifiers.

---

## 3. Verification & Evidence

### Path Truncation Test (Rightmost 25 Characters)
```
Left (Baseline):  D:\Git_Repositories\LCM_Inventory\scratch\BC_Review\BUG-183\Baseline_LCM_Inventory_v8.0.0_e94f262
Right (Live):     D:\Git_Repositories\LCM_Inventory\scratch\BC_Review\BUG-183\Live_LCM_Inventory_BUG-183

Last 25 Chars Left:  ..._Inventory_v8.0.0_e94f262
Last 25 Chars Right: ...rkspace_Inventory_BUG-183
```
- **Left Pane**: The repository identity (`_Inventory`), semantic baseline version (`v8.0.0`), and commit SHA (`e94f262`) are clearly visible within the 25-character window.
- **Right Pane**: The repository identity (`rkspace_Inventory`) and active proposal ID (`BUG-183` / `CRP-###`) are clearly visible within the 25-character window.

### `Get-ActiveCRP` Multi-Repo Test Output
```
Target: LCM_Inventory -> Active CRP: [BUG-183]
Target: LCM_AI        -> Active CRP: [CRP-176]
Target: Git_Repositories   -> Active CRP: [CRP-142]
Target: HaSSD06_Inventory   -> Active CRP: [BUG-154]
```

### AST Syntax & Rule Health
- `Invoke-BeyondCompareReview.ps1`: `0 AST Errors`.
- `Test-LCMRuleHealth.ps1`: `15/15` repositories 100% In Compliance.
