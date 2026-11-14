# Change Request Proposal: CRP-243 (Gemini Ref: CRP-2026-005)

```yaml
CRP-ID: CRP-243
Gemini-Reference: CRP-2026-005
Title: Integration of Read-Only Analysis Protocol & Implementation Gating into Workspace Governance
Scope: LCM_AI, LCM_Inventory, Workspace-wide
Baseline-Version: 10.2.0
Author: rgbig
Date: 2026-10-13
Status: Approved
Plan-State: approved
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Establishes a formal, model-first analysis lifecycle across all workspace AI interactions (specifically Antigravity IDE and Gemini sessions). This proposal introduces strict modal separation between **READ-ONLY ANALYSIS** and **GOVERNED IMPLEMENTATION**, enforced via intent wake words, verifiable provenance tagging, and explicit human-in-the-loop decision gates. 

Additionally, it mandates runtime state transparency by surfacing active governance variables (`OperatingMode`, `ActiveHypothesis`, `SettledFactCount`, `SearchRadius`, `CircuitBreaker`) directly to the LCM Control Hub and monitoring interfaces.

---

## 2. Operational Rules & State Machine

### 2.1 Intent Wake Words & Gating
* **`ANALYZE` (Wake Word):** Locks the session into **READ-ONLY ANALYSIS**. File modification tools (`edit_file`, `write_to_file`, `replace_file_content`, `multi_replace_file_content`, `git commit`) are strictly forbidden. The agent must first construct a structured model defining Entities, State Variables, Actions, and Constraints. No solutions or code proposals may be generated at this stage.
* **`IMPLEMENT` (Transition Word):** Unlocks **GOVERNED IMPLEMENTATION**. Implementation must strictly follow the conclusions and paths agreed upon during the preceding `ANALYZE` phase.
* **Circuit Breaker:** If implementation encounters missing prerequisites, ambiguities, or contradictions, execution halts immediately. The session drops back to `ANALYZE` mode, registers the gap, and requests operator steering.

### 2.2 Governance Constraint: Phase Exclusion
* **CRP Restriction:** During active `ANALYZE` mode, the formulation or execution of Implementation CRPs or code modification directives is **STRICTLY PROHIBITED**. Only analytical findings, gap audits, and decision options may be generated.

### 2.3 Circuit Breaker Protocol (Returning from Implementation to Analysis)
If `IMPLEMENT` is triggered and the agent discovers that an assumed API parameter does not exist, an environment path is inaccessible, or the implementation contradicts an earlier finding, it must not guess or force a workaround. It is mandated to execute:

```markdown
### [ANALYSIS RESUMED] - Implementation Block Encountered
Status: Implementation Halted | Reason: Ambiguity / Constraint Mismatch

1. Encountered Block
* [GAP / CONFLICT]: <Exact technical mismatch or undefined parameter>.
* Source Context: <File or component where divergence occurred>.

2. Impact on Previous Consensus
* Invalidation: <Why the previously chosen path cannot proceed as drafted>.

3. Recommended Next Steps (Decision Gate)
* Option A: <Alternative implementation branch addressing the gap>.
* Option B: <Re-open analysis of prerequisite components>.
* Option C: <Abort change and restore prior baseline>.
```
This status must also be exposed as an actionable state/action in the LCM Control Hub.

---

## 3. State Visibility & Monitoring (LCM Control Hub Integration)
To prevent hidden drift and opaque agent logic, the analysis engine must expose its operational state registers in real time. These variables must be readable via the LCM Control Hub / status dashboards:

| State Variable | Type | Allowed Values | Monitoring & Enforcement Rule |
| :--- | :--- | :--- | :--- |
| `LCM_OperatingMode` | String | `READ_ONLY_ANALYSIS`, `GOVERNED_IMPLEMENTATION`, `CIRCUIT_BREAKER_HALT` | Displayed prominently in UI. If `READ_ONLY_ANALYSIS`, block any execution pipeline attempting to invoke write hooks. |
| `LCM_ActiveGate` | String | `STEP_001` .. `STEP_nnn` | Current position in the interactive DAG. |
| `LCM_SearchRadius` | Integer | Max `2` (Default) | Fences ripgrep / file inspection depth from the specified root directory. |
| `LCM_SettledFacts` | Array[ID] | e.g., `["F-001", "F-002", "F-006"]` | IDs of verified facts; prevents repetitive re-printing of historical baseline data. |
| `LCM_OpenHypotheses` | Array[ID] | e.g., `["HYP-001A", "HYP-004"]` | Currently contested hypotheses under active audit. |
| `LCM_CircuitBreaker` | Boolean | `true`, `false` | Tripped when implementation feasibility checks fail; alerts user with a resumption block. |

---

## 4. Architecture State Transition Model

```
[ User Prompt: "ANALYZE ..." ]
             │
             ▼
┌─────────────────────────────────────────┐
│        STATE 1: READ-ONLY ANALYSIS      │
│  - Model Formulation                    │
│  - Evidence Verification [VERIFIED/GAP] │◄──────────┐
│  - Interactive Decision Gates (A, B, C) │           │ (Ambiguity /
└────────────────────┬────────────────────┘           │  Conflict
                     │                                │  Encountered)
    [ User Prompt: "IMPLEMENT ..." ]                  │
                     │                                │
                     ▼                                │
┌─────────────────────────────────────────┐           │
│     STATE 2: GOVERNED IMPLEMENTATION    │           │
│  - Bound to Selected Analysis Path      │           │
│  - Standard LCM File / Patch Execution  │           │
│  - Pre-execution Feasibility Check     ───► [FAILS] ─┘
└────────────────────┬────────────────────┘
                     │ [SUCCEEDS]
                     ▼
┌─────────────────────────────────────────┐
│     STATE 3: VERIFICATION & AUDIT       │
│  - Permanent Log / State Recorded       │
└────────────────────┬────────────────────┘
```

---

## 5. Verification & Acceptance Criteria
- [ ] Issuing a prompt starting with `ANALYZE` in Antigravity IDE emits the Structured Model first and refuses all write/edit operations.
- [ ] Findings produced strictly cite sources with `[VERIFIED: <file#line>]` or flag unconfirmed points with `[GAP: <missing_data>]`.
- [ ] The session terminates each step with exactly 2–3 actionable choices (A, B, C) and pauses for user input.
- [ ] Attempting to execute an implementation action while `LCM_OperatingMode == 'READ_ONLY_ANALYSIS'` results in an explicit governance block.
- [ ] Issuing `IMPLEMENT` switches `LCM_OperatingMode` to `GOVERNED_IMPLEMENTATION` and binds execution strictly to prior findings.
- [ ] Tripping an implementation feasibility failure cleanly switches mode to `CIRCUIT_BREAKER_HALT`, outputs `[ANALYSIS RESUMED]`, and updates LCM Control Hub state registers.

