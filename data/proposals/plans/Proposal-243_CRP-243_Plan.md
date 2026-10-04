# Implementation Plan: CRP-243 - Integration of Read-Only Analysis Protocol & Implementation Gating into Workspace Governance

## 1. Executive Summary & Problem Context
Establishes a model-first analysis lifecycle across all workspace AI interactions (specifically Antigravity IDE and Gemini sessions). The proposal addresses unconstrained speculative code modifications by enforcing strict modal separation between **READ-ONLY ANALYSIS** and **GOVERNED IMPLEMENTATION**, backed by intent wake words, verifiable provenance tagging, interactive decision gates, and Control Hub telemetry.

---

## 2. Proposed Changes & Work Breakdown

### Phase 1: Governance Rule Deployment (`LCM_AI/.agents/rules/`)
- Create [`LCM_AI/.agents/rules/AnalysisGovernancePolicy.md`](file:///D:/Git_Repositories/LCM_AI/.agents/rules/AnalysisGovernancePolicy.md) (or `LCM_Analysis_Governance.md`):
  - **`RULE-ANA-001` (Intent Wake Word Gating):** `ANALYZE` enforces read-only mode; file modification tools (`write_to_file`, `replace_file_content`, `multi_replace_file_content`, `git commit`) are prohibited.
  - **`RULE-ANA-002` (Provenance Tagging & 4-Part Output Contract):**
    1. Structured Model (Entities, State Variables, Actions, Constraints).
    2. Findings with `[VERIFIED: <file#line>]`, `[INFERRED]`, or `[GAP: <missing_data>]`.
    3. State Delta & Settled Facts.
    4. Interactive Decision Gate (2–3 concrete options A, B, C).
  - **`RULE-ANA-003` (Search Radius Fencing):** Constrain discovery searches to task roots with maximum depth 2 and capped match counts.
  - **`RULE-ANA-004` (Implementation Transition & Binding):** `IMPLEMENT` unlocks governed implementation, strictly bound to selected analysis consensus.
  - **`RULE-ANA-005` (Circuit Breaker Protocol):** Missing prerequisites or contradictions trigger immediate execution halt, transition to `CIRCUIT_BREAKER_HALT`, and emission of `[ANALYSIS RESUMED]`.
- Update [`LCM_AI/docs/LCM-Rules-Cross-Reference.md`](file:///D:/Git_Repositories/LCM_AI/docs/LCM-Rules-Cross-Reference.md) and [`AGENTS.md`](file:///D:/Git_Repositories/AGENTS.md) with rule index entries.

### Phase 2: State Tracking & Engine Enforcement (`LCM_Inventory`)
- Schema extension in `LCM_Inventory/data/session_state/active_session.json`:
  ```json
  {
    "operating_mode": "READ_ONLY_ANALYSIS",
    "active_gate": "STEP_001",
    "search_radius": 2,
    "settled_facts": [],
    "open_hypotheses": [],
    "circuit_breaker": false
  }
  ```
- Add helper functions in `ProposalManager.psm1` or dedicated `AnalysisGovernance.psm1`:
  - `Get-LcmOperatingMode`, `Set-LcmOperatingMode`
  - `Assert-LcmImplementationAllowed`
- Add gating interceptor to execution dispatchers (`Invoke-ProposalAction.ps1`, `DaemonActionController.ps1`) to reject write/commit commands if operating mode is `READ_ONLY_ANALYSIS`.

### Phase 3: LCM Control Hub UI Surfacing (`LCM_Inventory/assets/CM_CONTROL_HUB.html`)
- Surface active governance state registers in the Topbar / Status Rail:
  - Mode indicator pill: `READ_ONLY_ANALYSIS` (amber/blue), `GOVERNED_IMPLEMENTATION` (green), `CIRCUIT_BREAKER_HALT` (red alert).
  - Metrics display: Active Gate, Search Radius, Settled Fact Count, Open Hypotheses Count.
  - Action trigger: `[ANALYSIS RESUMED]` halt status display and resumption action options.

### Phase 4: Architecture Documentation (`docs/Architecture.md`)
- Embed the 3-state architecture transition model into `docs/Architecture.md`:
  - State 1: Read-Only Analysis (Model formulation, verification, decision gates).
  - State 2: Governed Implementation (Bound to analysis consensus, feasibility checks).
  - State 3: Verification & Audit.
  - Circuit Breaker Loop-back transition on feasibility failure.

---

## 3. Verification & Quality Gates
- **AST & Script Validation:** `Test-ScriptSyntax` / Pester tests on all modified PowerShell modules.
- **Enforcement Verification:**
  - Verify that when `LCM_OperatingMode == 'READ_ONLY_ANALYSIS'`, execution scripts throw a governance block.
  - Verify that `IMPLEMENT` command transitions state to `GOVERNED_IMPLEMENTATION`.
  - Verify Circuit Breaker triggers return `CIRCUIT_BREAKER_HALT` and format `[ANALYSIS RESUMED]`.
- **UI Verification:** Check Control Hub rendering in browser for mode indicator and register visibility.

---

## 4. Rollback & Contingency
If rule or dispatcher integration causes unintended blockers, the operating mode defaults to standard LCM mode (`GOVERNED_IMPLEMENTATION`), restoring pre-CRP behavior without data loss.
