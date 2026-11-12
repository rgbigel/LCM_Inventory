# Change Request Proposal: CRP-321

```yaml
CRP-ID: CRP-321
Title: System-1 Decision Cascade Governance, Gate 2A Documentation Checkpoint, Pre-Push Clean State, and Stepwise Requalification
Scope: LCM_AI, LCM_Inventory
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-12 12:45:00
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: 8
App-ID: None
Predecessor-ID: CRP-252
```

---

## 1. Executive Summary & Intent
Establishes the governance rule authority for the Multi-Stage System-1 Decision Cascade (`RULE-DEC-001..005`), creates the standalone **Gate 2A Documentation Completeness & Consistency Checkpoint**, specifies automated bypass rules for non-significant/minimal-tests changes, implements the **Pre-Push Clean State & Relief Switch Reset Invariant** in `Invoke-LCM_Push.ps1`, and introduces the **Stepwise Requalification Pipeline with Dynamic Remediation Step Injection** (`LcmPushRequalification.psm1`).

---

## 2. Gate 0 Contract

### Target State
1. **Canonical Governance Rule (`LCM_AI\.agents\rules\DecisionCascadeGovernancePolicy.md`)**:
   - `RULE-DEC-001`: Multi-Stage System-1 Decision Cascade (`Stage 0`, `Stage 1`, `Stage 2`).
   - `RULE-DEC-002`: Sub-85% Low-Confidence Operator Triage Invariant (surfaces explicit `noul` reasoning and interactive override options).
   - `RULE-DEC-003`: Gate 2A Standalone Documentation Completeness & Consistency Checkpoint (pre-commit stabilization).
   - `RULE-DEC-004`: Gate 2A Automated Bypass Conditions (low significance / mechanical changes and `-MinimalTests` iteration cycles).
   - `RULE-DEC-005`: Pre-Push Clean State, Pre-Publish Triage, and Stepwise Requalification Invariant.

2. **Stepwise Requalification Pipeline & Dynamic Remediation (`LCM_Inventory/modules/LcmPushRequalification.psm1`)**:
   - Preflight Triage Prompt (`Show-LcmPublishTriagePrompt`): Four interactive options: `[1] Force Requalification (Stepwise DAG)`, `[2] Circumvent / Force Push`, `[3] Continue (May Fail)`, `[4] Cancel`.
   - Stepwise 5-Stage Requalification DAG (`Invoke-LcmStepwiseRequalification`):
     - `[1/5]` Reset Development Relief Switches (`Set-LcmReliefMode.ps1 -Off`).
     - `[2/5]` AST Syntax & UTF-8 BOM Preflight Gate.
     - `[3/5]` General Quality Gate Readiness Verification (`Test-GeneralReadiness.ps1`).
     - `[4/5]` Proposal State Upgrade & Ledger Sync (upgrades `completed [minimal-tests]` proposals to `completed`, syncs SQLite DB and SQL text dump).
     - `[5/5]` Remote Push Hand-off & Audit Receipt Logging.
   - Dynamic Remediation Step Injection (`Invoke-RemediationStep`): On any failure, pauses and injects an interactive resolution step (`[Auto-Remediate]`, `[Inspect]`, `[Retry]`, `[Skip/Defer]`, `[Abort]`).

3. **Publish Engine Integration (`LCM_Inventory/tools/Invoke-LCM_Push.ps1`)**:
   - Accepts `-ForceRequalify`, `-BypassReliefGate` (alias `SkipReliefGate`, `ForceRelief`), and `-NonInteractive`.
   - Replaces hard crash with interactive preflight triage and seamless stepwise qualification.

4. **Standalone Tool (`LCM_Inventory/tools/Invoke-LcmPushRequalification.ps1`)**:
   - Enables running the 5-step requalification DAG on demand at any time.

---

## 3. Invariants and Exit Criteria
- **Zero-Bypass on Final Push Invariant**: No proposal with incomplete documentation or `[minimal-tests]` may be pushed upstream without explicit operator override.
- **Dynamic Remediation Invariant**: Failures during qualification spawn interactive remediation steps instead of unhandled crashes.
- **Authority Invariant**: Single physical source in `LCM_AI\.agents\rules\`.
- **Readiness Gate Pass**: All repositories pass 6/6 `Test-GeneralReadiness.ps1` gates.
- **Pester Test Suite Pass**: `Test-LcmPushRequalification.Tests.ps1` achieves 100% pass (9/9).
