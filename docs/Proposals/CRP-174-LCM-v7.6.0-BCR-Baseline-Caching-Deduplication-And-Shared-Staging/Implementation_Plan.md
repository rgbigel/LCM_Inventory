# Implementation Plan: CRP-174

```yaml
CRP-ID: CRP-174
Title: Beyond Compare Review Baseline Caching, Invocation Fix, UI Ergonomics, and COMPLETE Lifecycle Consolidation
Gate: Gate 2 (Visual Review Gate)
Status: in_progress
Priority: High
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-25
```

---

## Executed Changes

### 1. `LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1`
- Added `-ForceRebuild` / `-NoCache` switch parameter.
- Added immutable baseline caching: checks for `$tempReviewRoot` and `.lcm_baseline_manifest.json` before running `git archive` / `tar -xf`. Reuses cached baseline with `[CACHE HIT]` when valid.

### 2. `LCM_Inventory/assets/LCM_SIDECAR.html`
- Fixed daemon BCR execution path: changed `tools/Invoke-BeyondCompareReview.ps1` to authoritative `LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1`.
- Renamed button to **"Review with BC"**.
- Added **"✅ Complete"** button to the Action Ribbon to trigger unified review completion.
- Added direct **Proposal Switcher dropdown** (`#proposalSwitcher`) in the target banner with dynamic options populated from `proposals.json`.
- Implemented dynamic fetch `fetchFreshProposals()` on startup and on `DATA_UPDATED` broadcast event.
- Removed internal plumbing tools (`catalog`, `readiness`) from the user `COMMAND_CATALOG`.

### 3. `LCM_Inventory/tools/Show-LcmSidecar.ps1`
- Reduced standalone Edge App window dimensions to compact geometry: `--window-size=500,680 --window-position=1380,50`.

### 4. `LCM_Inventory/assets/CM_CONTROL_HUB.html`
- Compacted `.stats-row` and `.stat-card` padding and sizing: height reduced from 70px to compact 32px flex cards with values inline.
- Fixed relative BCR execution command path to `LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1`.
- Added automatic dynamic startup call `refreshHubData(false)` to fetch fresh data from REST daemon immediately.

### 5. `LCM_Inventory/tools/Submit-ReviewResult.ps1`
- Added `Completed`, `Complete`, and `COMPLETE ALL` to the `-Result` ValidateSet.
- Added automatic post-commit synchronization that marks matching open proposals in `proposals.json` as `completed`.

### 6. Canonical Rules Migration to `LCM_AI`
- Migrated 17 physical rule markdown documents from `LCM_Inventory\.agents\rules\` to **`LCM_AI\.agents\rules\`**.
- Re-pointed all NTFS directory junctions (`LCM_Inventory\.agents\rules`, root `D:\Git_Repositories\.agents\rules`, `D:\Git_Repositories\.lcm\.agents\rules`, `PowerBGInfo\.agents\rules`, etc.) directly or transitively to `LCM_AI\.agents\rules`.
- Verified 100% rule discovery across all child repositories with zero broken reparse points.

### 7. Transparent Single-Session BCR & Symlink Traversal
- Configured `<FollowSymLinks Value="True"/>` in Beyond Compare 5 session settings (`BCSessions.xml`).
- Removed `-.agents\rules\` from the repository exclusion filter list in `Invoke-BeyondCompareReview.ps1`.
- Completely retired the redundant second BC review session dispatch; Beyond Compare 5 now navigates directory junctions inline in a single window.
- Added automatic rules baseline extraction from `LCM_AI` HEAD into `$tempReviewRoot\.agents\rules` for child repo reviews.

### 8. Governance Documentation Synchronization
- Updated [`AGENTS.md`](file:///d:/Git_Repositories/AGENTS.md) Section 2 to designate `LCM_AI\.agents\rules\` as the Canonical Hub.
- Updated [`RuleAuthority.md`](file:///d:/Git_Repositories/LCM_AI/.agents/rules/RuleAuthority.md) (`RULE-AUTH-001`) to reflect `LCM_AI` as the authoritative physical host.
- Updated [`Export-LCMRules.ps1`](file:///d:/Git_Repositories/.lcm/tools/internal/Export-LCMRules.ps1) to prioritize `LCM_AI\.agents\rules`.
