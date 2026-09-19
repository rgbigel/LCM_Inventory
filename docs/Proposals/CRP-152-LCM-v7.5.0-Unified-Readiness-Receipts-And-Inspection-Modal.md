# Proposal: CRP-152 Unified Quality Gate Readiness Receipt Engine, In-Dashboard Modal, and Workspace Rollup

## Metadata
- **Proposal ID**: `152`
- **Bundle ID**: `CRP-152`
- **Origin Repo**: `Workspace_Inventory` (Global LCM Engine / All Governed Repositories)
- **Target Components**:
  - `tools/Test-RepoReadiness.ps1` (Child repositories)
  - `Workspace_Inventory/tools/Test-LCMRuleHealth.ps1`
  - `tools/assets/StandardTableDisplay.css`, `tools/assets/lcm-table-engine.js`
  - `.lcm/tools/hub/Show-WorkspaceReadiness.ps1`
- **Author**: Operator Directive / CRP Intake
- **Date**: 2026-09-19
- **Status**: Completed (`completed`)
- **Completed Date**: 2026-09-19

---

## 1. Executive Summary & Intent
Provides a universal, transparent mechanism for operators to immediately inspect and trigger quality gate readiness check results across all 34 repositories in the workspace, bridging the disconnect between terminal scripts and visual dashboards.

---

## 2. Technical Architecture & Component Design

### 2.1 Standard Readiness Receipt Contract (`data/readiness/latest_readiness.json`)
- Every `Test-RepoReadiness.ps1` and `Test-LCMRuleHealth.ps1` script will emit a machine-readable JSON receipt containing:
  - Timestamp, repository name, duration_ms, overall status (`PASSED`, `FAILED`, `WARNING`).
  - Gate-by-gate array: `id`, `name`, `status`, `details`, `failure_reason`.

### 2.2 In-Dashboard Visual Integration (Standard Table Display)
- **Header Readiness Badge**: Clickable badge displayed prominently in the dashboard header:
  - `🟢 Readiness: 5/5 PASSED` (or `🔴 Readiness: Gate 4 FAILED`).
- **Interactive Readiness Inspection Modal (`#readinessModal`)**:
  - Clicking the header badge or clicking `🔍 Inspect / Run` in the Tools tab opens an interactive dialog with gate cards, live pass/fail details, and a `▶️ Run Live Check` button that updates the receipt and UI in real time.

### 2.3 Workspace-Wide Readiness Rollup (`Show-WorkspaceReadiness.ps1`)
- A central CLI and HTML viewer in `.lcm\tools\hub\Show-WorkspaceReadiness.ps1` aggregating `latest_readiness.json` across all 34 workspace repositories into a single matrix.

---

## 3. Verification & Quality Gates Plan
- Validate JSON receipt schema against test runs.
- Validate `#readinessModal` interactive rendering and live re-test dispatch.
- Verify multi-repo aggregation in `Show-WorkspaceReadiness.ps1`.
- Ensure 100% compliance with PowerShell standards (`RULE-PS-001` through `014`).
