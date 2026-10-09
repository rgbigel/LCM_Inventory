# Implementation Plan: Fix BCR Baseline Resolution to Local Git HEAD and Correct Path Mangling

- **Proposal**: #58
- **CR ID**: `CRP-2026-033`
- **Governance Tier**: T1 (Trivial Defect / Tooling & Path Fix)
- **Origin Repo**: `.lcm / Tooling`
- **Author**: Technical Engineering & Governance Team
- **Date**: 2026-09-03
- **Status**: Completed

---

## 1. Objectives & Scope

1. **Path Mangling Rectification**:
   - Eliminate legacy and malformed path references (`LCM_Inventory/.tools`, `LCM_Inventory\..tools`, `\.\tools`) across the workspace.
   - Standardize all references to canonical platform paths: `LCM_Inventory/tools/...` (or `LCM_Inventory\tools\...`).
   - Fix 33 malformed relative paths in `tool_catalog.json` and associated HTML dashboard views.

2. **Beyond Compare Review (BCR) Comparison Target**:
   - Ensure BCR comparisons strictly anchor to local Git `HEAD` (working tree vs. local HEAD), eliminating hardcoded `origin/main` or network-dependent fetches.
   - Decouple parameter evaluation in `Invoke-BeyondCompareReview.ps1` so omitting `-RepositoryName` defaults to the active repository root instead of blocking execution with a help banner.
   - Introduce dedicated `BCR.cmd` short trampolines in `LCM_Inventory/Cmd/` and `LCM_Inventory/Cmd/`.

---

## 2. Technical Deliverables

### A. Path Correction
- **`tool_catalog.json`**: Replaced all 33 occurrences of `LCM_Inventory\.tools\internal\` with canonical `LCM_Inventory\tools\`.
- **Scratch Dashboards**: Corrected `SHOW_TOOLS.html` and `User_Tools_Explorer_LCM.html`.
- **System Directives**: Corrected `AGENTS.md` system restore path and `.agents/ACTIVE_SESSION.md` tool explorer path.
- **Documentation**: Updated `LCM_AI/docs/` specifications to use `LCM_Inventory/tools/` and `LCM_Inventory/Cmd/`.

### B. BCR Tooling
- **`Invoke-BeyondCompareReview.ps1`**:
  - Anchors `$BaseCommit` to `'HEAD'` by default.
  - Resolves commit SHA strictly via `git -C $repoPath rev-parse --short $BaseCommit`.
  - Automatically derives `$RepositoryName` from active Git top-level directory when omitted.
- **Trampolines**: Added `BCR.cmd` in `LCM_Inventory\Cmd\` and `LCM_Inventory\Cmd\`.

---

## 3. Verification Plan
- Verify zero occurrences of `LCM_Inventory/.tools` or `LCM_Inventory\..tools` across all tracked repository files.
- Verify `Invoke-BeyondCompareReview.ps1 -Help` displays clean usage and updated `BCR` launcher syntax.
- Verify `git rev-parse --short HEAD` resolution against local commit `9bff0c7`.
