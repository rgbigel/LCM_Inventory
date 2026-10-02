# CRP-210: Minimal Tests Switch and Single-Cycle State Modifier

```yaml
CRP-ID: CRP-210
Priority: 8
Scope: Test Readiness Execution, Single-Cycle Minimal Testing, and Lifecycle State Representation
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Affected-Repos:
  - LCM_Inventory
  - LCM_AI
  - LCM_Shared
  - All Governed Repositories
```

## Objective

Introduce a standardized, single-cycle **"Minimal Tests"** execution switch and governance mechanism across the Lifecycle Model (LCM). This mechanism restricts the Implementation Phase "Test Readiness" step to fast essential hygiene checks (syntax validation, line endings, encoding, basic formatting) and bypasses heavy, multi-minute test cascades (deep integration DAGs, elevated test suites, external network/device mocks) during rapid iteration, user discretion, or automated circumvention.

The switch is strictly ephemeral: it applies to a single implementation process (a single `BUG` or an explicit `CRPs Group`) and unconditionally auto-resets afterwards. The exceptional use of Minimal Tests must be recorded in the audit log, documented in the proposal bundle, and explicitly reflected in the **`state`** (not status) field of the affected proposal records.

---

## 1. Problem Statement & Motivation

During rapid interactive development, automated bug circumvention (`RULE-REV-001`), or low-risk documentation/metadata updates, executing full-tier test cascades via `Test-RepoReadiness.ps1` (including deep Pester suites, elevated runner handoffs, and long-running subsystem validations) causes excessive latency, high token consumption, and workflow bottlenecks.

While `RULE-LCM-006` defines a coarse workspace-wide `Testing OFF` switch, that switch is an emergency platform toggle that defers testing until pre-push. There is currently no granular, per-proposal mechanism to:
1. Request lightweight, immediate syntax and hygiene readiness for a single item without running full integration suites.
2. Ensure the bypass scope automatically expires and resets after that specific item/group concludes.
3. Formally track and display in Configuration Management ledgers that an item was verified under minimal testing rather than full verification.

---

## 2. Normative Requirements

### 2.1. Activation Triggers & CLI Interface
1. **Operator Discretion**: The operator may explicitly invoke the switch via interactive commands:
   - `Proceed <ID> --minimal-tests` (or `do <ID> --minimal-tests`)
   - `Minimal Tests <ID>` / `Minimal Tests <ID-range>`
   - Parameter switch: `-MinimalTests` on `Test-RepoReadiness.ps1`, `Submit-ReviewResult.ps1`, and Control Hub actions.
2. **Automated Circumvention**: When the system invokes an autonomous exception under `RULE-REV-001` (e.g. self-remediating a critical loop-inducing bug with $\le 2$ attempts), the runner `SHALL` automatically engage `-MinimalTests` to prevent cascading test recursions.

### 2.2. Single-Cycle Lifecycle & Auto-Reset Invariant
1. **Single-Process Lifetime**: The `-MinimalTests` modifier applies strictly and exclusively to the active execution cycle of the target `BUG` or declared `CRPs Group`.
2. **Automatic Ephemeral Reset**:
   - Immediately upon concluding the target item's readiness check, review submission (`Submit-ReviewResult.ps1`), or turn completion, the testing scope `MUST UNCONDITIONALLY RESET` to standard full testing (`full`).
   - Minimal testing `MUST NOT` persist as an ambient or sticky workspace mode.
   - Subsequent proposals or batch runs default back to standard full readiness suites.

### 2.3. Execution Boundary: What Runs vs. What is Skipped
When `Minimal Tests` is active:
* **Mandatory Fast-Tier Checks (ALWAYS RUN)**:
  1. **PowerShell AST Parsing**: `[System.Management.Automation.Language.Parser]::ParseFile()` on all modified scripts/modules to guarantee 0 syntax errors (`RULE-PS-005`, `RULE-REV-001`).
  2. **Python Compilation**: `py_compile.compile()` on all modified `.py` files.
  3. **Encoding & Line Endings**: Verification of UTF-8 without BOM and Windows CRLF (`InvariantRules.md`).
  4. **Language Rule**: Verification of English invariant (`LanguagePolicy.md`).
  5. **Core Structural Verification**: `Assert-RepoStructure` and `Assert-RepoGovernanceLinks`.
* **Deferred / Bypassed Checks**:
  1. Deep elevated test runner executions (`Invoke-ElevatedTest.ps1`, UAC/Session 0 subprocesses).
  2. Multi-minute integration test suites and multi-component DAGs.
  3. Subsystem API live connectivity polling.

### 2.4. Audit Logging & Evidence Recording
1. **CM Audit Ledger**: Every activation of Minimal Tests `MUST` record an entry in `LCM_Inventory/logs/cm_activity.log`:
   `[ACTION] Minimal Tests switch engaged for Proposal <ID> (<CR_ID>). Scope: Syntax & Structure only. Rationale: <OperatorDiscretion | AutonomousCircumvention>.`
2. **Review Receipt Recording**: The generated review evidence (`LCM_Inventory/data/reviews/REVIEW-*.json`) `MUST` record:
   `"test_readiness_scope": "minimal"` and `"skipped_suites": ["ElevatedIntegration", "DeepPesterDAG"]`.
3. **Walkthrough Documentation**: The proposal bundle's `Walkthrough.md` `MUST` document the fast-tier test output and declare that minimal testing was utilized.

### 2.5. State (Not Status) Representation Invariant
1. **Ledger `state` Property Representation**:
   - In `LCM_Inventory/data/proposals/proposals.json`, the authoritative **`state`** attribute `MUST` visibly distinguish completion under minimal tests:
     - Standard: `"state": "completed"`
     - Minimal Tests: `"state": "completed [minimal-tests]"` (or `"state": "completed (minimal-tests)"`)
   - The proposal record `MUST` additionally capture `"test_scope": "minimal"` in its metadata.
2. **UI & Control Hub Visibility**:
   - The CM Control Hub (`CM_CONTROL_HUB.html`) and Inventory viewers `MUST` render the state badge with an amber or distinct indicator chip (e.g. `COMPLETED ⚠️ MINIMAL`) rather than a plain green badge, providing instantaneous operator visibility into verification depth.
3. **Publication Preflight Behavior**:
   - Prior to remote publication (`PUBLISH` / `PUSH`), the lockstep preflight gate inspects all proposals in `completed [minimal-tests]` state. If the target repository has deep tests defined, the pre-push hook may run the full suite once before pushing or require explicit confirmation.

---

## 3. Governance Integration

This proposal will amend:
1. **[`ProposalReviewFlowPolicy.md`](file:///d:/Git_Repositories/.agents/rules/ProposalReviewFlowPolicy.md)**:
   - Add `RULE-LCM-023: Minimal Tests Single-Cycle Execution Switch & State Reflection Invariant`.
2. **[`ReviewCommitGovernancePolicy.md`](file:///d:/Git_Repositories/.agents/rules/ReviewCommitGovernancePolicy.md)**:
   - Update `RULE-REV-001` and `RULE-REV-002` to formally recognize `completed [minimal-tests]` as a valid, audited review disposition.
3. **`Test-RepoReadiness.ps1` & `RepoQualityGates.psm1`**:
   - Add `-MinimalTests` switch to skip `Invoke-ElevatedTest` while enforcing all AST, formatting, encoding, and link checks.

---

## Non-Goals

* Permanently disabling unit tests across the workspace.
* Allowing unparsed, syntactically broken, or non-English code to pass readiness gates.
* Removing full readiness execution from the pre-push publication barrier (`Invoke-WorkspacePush.ps1`).
