# Requirements Specification: Workspace Inventory & Configuration Management Engine

Module: docs/Requirements.md  
Purpose: Normative technical requirements, environmental prerequisites, safety boundaries, and compliance constraints for Workspace_Inventory.  
Path: D:/Git_Repositories/Workspace_Inventory/docs/Requirements.md  
Authors: Rolf, Workspace_AI Engine  
Version: 7.0.0  
Status: Authoritative Requirements  
Date: 2026-09-19  

---

## 1. Environmental Prerequisites & Platform Constraints

1. **PowerShell Runtime**: Must execute on **PowerShell 7.4+ (`pwsh`)** with `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`. Windows PowerShell 5.1 is prohibited.
2. **Operating System**: Windows 11 64-bit with NTFS file system supporting symbolic links and volume mount junctions.
3. **Execution Privilege**: Default un-elevated (User) context. Tools requiring administrator privileges must route through `Start-ScriptProcessElevated.ps1` with the non-auto-close invariant (`RULE-ELEV-001` - `006`).
4. **Encoding & Line Endings**: UTF-8 without BOM, CRLF line endings, 2-space JSON and Markdown indentation (`INVARIANT-RULES`).

---

## 2. Normative Invariants & CM Governance Rules

### REQ-WINV-001: Review Gate Enforcement (`RULE-REV-001`)
- No automated tool or AI assistant `MAY` commit changes to Git repositories without explicit operator visual review via Beyond Compare 5 (`Invoke-BeyondCompareReview.ps1`).
- Direct invocation of `git commit` outside the review runner is strictly prohibited during interactive development.

### REQ-WINV-002: Audit Receipt Generation & Persistence (`RULE-REV-003`)
- Every approved commit `MUST` produce an immutable audit receipt in `Workspace_Inventory/data/reviews/review_<Repo>_<timestamp>.json`.
- Receipts must record repository name, target branch, commit hash, commit message, and changed file paths.

### REQ-WINV-003: Single Source of Truth for Proposals (`RULE-LCM-001`)
- All change requests, bug fixes, and feature proposals `MUST` be registered in `Workspace_Inventory/data/proposals/proposals.json`.
- Proposals must contain: unique integer `id`, `title`, `state`, `origin_repo`, `priority`, and formal `plan_path`.

### REQ-WINV-004: Workspace Audit & Drift Detection (`RULE-EFF-001`)
- `Invoke-WorkspaceAudit.ps1` `MUST` inspect all 24 directories under `D:\Git_Repositories`, assessing:
  - Git repository validity and current branch.
  - Working tree dirty state (clean vs uncommitted changes).
  - Tracking status (ahead/behind remote origin).
  - Absorbed LCM baseline parity against `GlobalLCMVersion`.
  - NTFS junction health pointing to `.agents/rules`.

### REQ-WINV-005: Lockstep Multi-Repository Push (`RULE-LCM-013`)
- `Invoke-WorkspacePush.ps1` `MUST` conduct pre-push validation (Gemini rules export and tool catalog synchronization).
- It `MUST` iterate across all ahead repositories, execute `git push origin <branch>`, log structured audit records to `logs/cm_activity.log`, and transition completed proposals to `pushed`.

### REQ-WINV-006: Runtime Presentation Artifact Isolation (`RULE-DSP-008` / `CRP-156`)
- All generated HTML dashboard reports, document viewers, and temporary interactive tables `MUST` be written to `data/artifacts/` or `data/staging/`.
- Generated HTML runtime views `MUST NOT` be committed to repository `docs/` directories.

---

## 3. UI/UX Display Standards Compliance

All interactive viewers in `Workspace_Inventory` (such as `Show-CmControlHub.ps1`, `Show-WorkspaceInventoryApp.ps1`, `Show-WorkspaceReadiness.ps1`) `MUST` conform to [`DisplayStandardsPolicy.md`](file:///D:/Git_Repositories/.agents/rules/DisplayStandardsPolicy.md):
1. **Canonical Token Architecture**: Must inherit styles from `StandardTableDisplay.css` (Glassmorphic dark mode, hsl custom properties).
2. **Double-Row Sticky Table Headers**: Row 1 for column titles and multi-column sorting; Row 2 for live filter inputs.
3. **Action Logging Drawer**: Must provide collapsible floating audit drawer capturing all desktop dispatches with timestamps and exit codes.
4. **Desktop Dispatch Routing**: Must invoke native applications via background runners without terminal focus stealing (`RULE-PS-012`).
