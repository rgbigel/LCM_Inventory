# Change Request Proposal: CRP-174

```yaml
CRP-ID: CRP-174
Title: Beyond Compare Review Baseline Caching, Invocation Fix, UI Ergonomics, and COMPLETE Lifecycle Consolidation
Scope: Review Lifecycle, LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1, LCM_SIDECAR.html, CM_CONTROL_HUB.html, Submit-ReviewResult.ps1, Tool Explorer
Baseline-Version: v7.6.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-25
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: High
Impacted-Repositories:
  - LCM_Inventory
  - .lcm
```

---

## 1. Executive Summary & Problem Context

Operating experience with `CRP-173` revealed several core friction points across the Beyond Compare Review (BCR) workflow, Sidecar ergonomics, and CM Control Hub synchronization:

1. **Unconditional Baseline Destruction on Re-Launch**:
   - [`Invoke-BeyondCompareReview.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1) blindly wiped existing baseline temporary trees on every call, forcing repeated tar unpacking and SHA256 re-hashing even when the Git baseline SHA was unchanged.
2. **Broken Daemon Invocation Path (Exit 1)**:
   - In [`LCM_SIDECAR.html`](file:///D:/Git_Repositories/LCM_Inventory/assets/LCM_SIDECAR.html), the review action executed `tools/Invoke-BeyondCompareReview.ps1` instead of `LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1`, causing the daemon to fail with `Exit 1: The term is not recognized`.
3. **Misleading Button Wording**:
   - The button text read "Launch Beyond Compare 5 review gate" rather than a concise, active phrase: **"Review with BC"**.
4. **Sidecar Context Isolation & Proposal Switching**:
   - The Sidecar had no direct proposal dropdown/search, leaving the operator stranded if the Hub did not switch rows.
5. **Internal Plumbing Cluttering User Surfaces**:
   - "Catalog" and "Readiness" were exposed as manual actions, whereas they are automated internal checks.
   - Internal scripts should not be mixed into developer command ribbons.
6. **Terminology Simplification: COMPLETE as Primary Lifecycle Verb**:
   - The distinction between "Accept" and "Complete" caused confusion. The term "Accept" is consolidated into **"Complete"** (`complete <id>`), which orchestrates verification, review commit, receipt generation, proposal completion, and baseline cleanup.
7. **Control Hub Live Refresh & Layout Sizing**:
   - Control Hub refresh was blocked by CORS when opened via `file://`.
   - Intake buttons consumed excessive space; Sidecar initial dimensions were unnecessarily oversized.

---

## 2. Technical Architecture & Invariants

### Invariant 1: Immutable Baseline Caching
- Before extracting Git archives in `Invoke-BeyondCompareReview.ps1`, verify if `$tempReviewRoot` and `$tempReviewRoot\.lcm_baseline_manifest.json` already exist for the current commit SHA.
- If present, reuse the cached baseline immediately (0-second I/O). Provide `-ForceRebuild` / `-NoCache` switch for manual override.

### Invariant 2: Authoritative Invocation Routing
- All daemon execution strings in `LCM_SIDECAR.html` and `CM_CONTROL_HUB.html` use deterministic relative paths: `LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1`.
- Review button labeled **"Review with BC"**.

### Invariant 3: Automated Quality Gate Decoupling
- Remove "Catalog" and "Readiness" from user action ribbons.
- `Test-LCMReadiness.ps1` runs automatically during commit/push validation.
- `Update-ToolCatalog.ps1` runs automatically during maintenance and builds.

### Invariant 4: Unified COMPLETE Workflow
- Operator command **`complete <id>`** (or Sidecar "Complete" button) executes the unified post-review pipeline:
  1. Validates review staging manifest.
  2. Executes review Git commit with audit receipt in `LCM_Inventory/data/reviews/`.
  3. Updates proposal state to `completed` in `LCM_Inventory/data/proposals/proposals.json`.
  4. Purges temporary baseline scratch tree.
  5. Broadcasts reload event to Control Hub and Sidecar.
- `ACCEPT` is maintained strictly as an internal synonym for backwards compatibility.

### Invariant 5: Compact Ergonomics & In-Sidecar Proposal Switching
- Add proposal dropdown selector directly into Sidecar target banner.
- Shrink intake buttons into a single compact toolbar row.
- Set initial Sidecar window size to compact dimensions (500px $\times$ 680px).

### Invariant 6: Canonical Rules Relocation to LCM_AI & Universal Junction Sync
- Move canonical physical rules repository from `LCM_Inventory\.agents\rules\` to **`LCM_AI\.agents\rules\`** (the authoritative domain owner for AI prompts, policies, and governance).
- Re-link all junctions (`LCM_Inventory\.agents\rules`, `D:\Git_Repositories\.agents\rules`, `.lcm\.agents\rules`, and child repositories) to point directly or transitively to `LCM_AI\.agents\rules\`.
- Update [`AGENTS.md`](file:///d:/Git_Repositories/AGENTS.md) and [`RuleAuthority.md`](file:///d:/Git_Repositories/LCM_AI/.agents/rules/RuleAuthority.md) to enshrine `LCM_AI\.agents\rules` as the Canonical Physical Hub (`RULE-AUTH-001`).

### Invariant 7: Transparent Single-Session Beyond Compare Review (FollowSymLinks)
- Configure `<FollowSymLinks Value="True"/>` in Beyond Compare 5 session settings (`BCSessions.xml`).
- Remove `-.agents\rules\` from the repository exclusion filter list so BC5 evaluates rules inline.
- Retire the redundant second BC review session dispatch; a single Beyond Compare window traverses directory junctions transparently.
- Automatically populate baseline rules into `$tempReviewRoot\.agents\rules` from `LCM_AI` HEAD if a child repo baseline does not natively contain them.
