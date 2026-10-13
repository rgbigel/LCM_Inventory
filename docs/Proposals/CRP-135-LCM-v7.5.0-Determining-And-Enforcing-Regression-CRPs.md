---
Proposal-ID: CRP-135
CR-ID: CRP-135
Scope: LCM
Version: 10.0.0
Affected-Repos: [LCM, LCM_Inventory, LCM_AI]
Severity: High
Status: ACCEPTED
Date: 2026-10-13
Author: Operator Directive / CRP Intake
Target Scope: LCM_Inventory/tools/, LCM_Inventory/modules/, LCM_AI/tools/, Governance Rules
Affected Version Range: 10.0.0+
Impacted Repositories: [LCM, LCM_Inventory, LCM_AI, Governed Child Repositories]
Max-Regression-Depth: 2
---

# Change Request Proposal: CRP-135
# Determining and Enforcing Automated Regression CRPs in CM

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-135` |
| **Lifecycle State** | `ACCEPTED` (Approved by Operator; MaxRegressionDepth=2) |
| **Origin Repository** | `LCM` / `LCM_Inventory` |
| **Target Scope** | CM Ledger (`proposals.json`), CM Inspection Tools, Governance Rules (`RULE-LCM-*`) |
| **Author** | Operator Directive / CRP Intake |
| **Date** | 2026-10-13 |
| **Priority** | `High` |
| **Version Impact** | `10.0.0+` |
| **Max Regression Depth** | `2` |

---

## 1. Executive Summary & Problem Statement
In multi-repository Lifecycle Model (LCM) environments, changes introduced by a Change Request Proposal (CRP) frequently induce ripple effects across dependent repositories, tools, or configurations. Currently, regression testing and downstream remediation are largely triggered manually or observed during periodic audits.

This proposal establishes an authoritative, deterministic mechanism to:
1. Automatically detect when a change requires downstream regression (`RegressionNeeded = true`).
2. Identify cross-repository collision/overlap with other active, uncompleted CRPs.
3. Automatically generate derivative regression child CRPs (`Regression for <Parent CRP>`) in the `OPEN` state.
4. Enforce two-stage verification on the target repository when a regression is executed:
   - **Consistency Validation**: Ensure the change does not introduce goal contradictions, established invariant violations, or functional regressions.
   - **Full Rule Compliance**: Verify repository conformance against all applicable local and LCM/CM governance rules, spawning auto-generated defect remediation CRPs if non-conformance is detected.
5. Prevent infinite regression cascading via cycle detection and DAG depth guarding.
6. Compute a deterministic topological execution order (`ListOfChangesRequired`) utilizing negative priority ranges (`-1`, `-2`, `-3`...), surfacing this execution plan on the primary parent CRP.

---

## 2. Detailed Technical Specification

### 2.1 Schema Enhancement: `RegressionNeeded` and `ListOfChangesRequired`
The canonical proposal schema in `proposals.json` and proposal metadata frontmatter will incorporate:
- `regression_needed` (Boolean): Flag indicating downstream regression requirements.
- `regression_triggers` (Array): Specific triggers that set `regression_needed = true`:
  - **Explicit Author Intent**: Stated by the CRP author, operator, or LCM itself.
  - **Semantic Scope Filter**: Inferred when the CRP targets global scopes (e.g. *"affects all tools"*, *"all repositories"*, or workspace-level rule alterations).
  - **Active Dependency Overlap**: Another uncompleted CRP (`progress_state != 'completed'`) already has `regression_needed = true`, and their impacted repositories (`ListOfChangesRequired` / `impacted_repositories`) intersect.
- `parent_crp_id` (String/Integer): Backlink pointing to the parent CRP that generated this regression task.
- `list_of_changes_required` (Array of Objects): Explicit list of downstream repository changes, structured as:
  ```json
  [
    {
      "repo": "SystemConfiguration",
      "scope": "tools",
      "suggested_priority": -1,
      "reason": "Shared parameter convention update"
    }
  ]
  ```

### 2.2 Automated Child Regression CRP Generation
When a CRP with `regression_needed = true` is evaluated:
1. CM tooling analyzes the `ListOfChangesRequired` and groups targets by repository/subsystem domain.
2. For each identified regression area, a child CRP is automatically minted:
   - **Title**: `Regression: <Area/Repo> for CRP-<ParentId> (<Parent Title>)`
   - **State**: Strictly initialized to `suggested` (`OPEN` progress state) per `RULE-LCM-015`.
   - **Priority**: Computed negative priority index (`-1`, `-2`, etc.) indicating sequence.
   - **Backlink**: `parent_crp_id: <ParentId>`.

### 2.3 Post-Application Verification Protocol
When a regression CRP transitions to execution, the target repository must pass a two-tier verification gate:
1. **Consistency Verification Gate**:
   - Verify that the target change does not conflict with already established repository goals, existing functional invariants, or uncompleted sibling CRP specifications.
2. **Comprehensive Governance Rule Verification Gate**:
   - Execute all applicable static and dynamic tests (`Test-LCMRuleHealth.ps1`, repo-specific readiness test runners, strict mode checks, ASCII/CRLF compliance).
   - If a rule check fails, the regression engine halts automatic propagation and generates a defect remediation CRP detailing the exact failure telemetry and remediation goal.

### 2.4 Cycle Detection, MaxRegressionDepth=2 & Remedial Action Protocol
Because child regression CRPs could conceivably trigger further regression evaluations, the engine `MUST` enforce:
1. **Directed Acyclic Graph (DAG) Tracking**: The CM ledger records dependency edges (`parent_crp_id`, `depends_on`). Before generating any child CRP, a cycle detector verifies that no closed path exists (`A -> B -> A`).
2. **Deterministic Depth Bound Guard (`MaxRegressionDepth = 2`)**:
   - A hard limit of `MaxRegressionDepth = 2` is enforced workspace-wide.
   - Primary CRP (Depth 0) $\rightarrow$ Immediate Dependent Components / Direct Consumers (Depth 1) $\rightarrow$ Secondary Leaf Tools / Interfaces (Depth 2).
   - Any generation attempt exceeding Depth 2 is blocked immediately.
3. **Governor Remedial Action on `Blocked_Cycle`**:
   - If a cycle or depth breach is detected, the CM Governor automatically places the offending regression chain into the **`Blocked_Cycle`** state.
   - Simply halting is insufficient; the Governor `MUST` instantiate an actionable remediation workflow:
     1. **Generate Cycle Mediation Proposal**: The Governor automatically mints a specialized **Cycle Resolution Proposal** (`CRP-<ID> [Cycle Mediation]: Resolve Circular Coupling between <RepoA> and <RepoB>`).
     2. **Propose Automated Disentanglement Strategy**:
        - **Strategy 1 (Interface Extraction / Hoisting)**: Hoist the oscillating contract, data structure, or configuration constant into a common root parent (e.g. `LCM_Shared`, an environment constant, or an authoritative JSON schema), breaking the mutual dependency.
        - **Strategy 2 (Atomic Joint Review Bundle)**: Collapse the oscillating pair of changes into a single **Joint Atomic Review Batch** where both repositories are reviewed and committed simultaneously under one atomic review session rather than cascading sequentially.
        - **Strategy 3 (One-Way Interface Decoupling / Exemption)**: If one side of the interface offers backward compatibility, the Governor allows the operator to mark the reverse edge as `RegressionExempt: true` with a documented rationale receipt.
     3. **Control Hub Dashboard Alert & Action**: `Show-CmControlHub` surfaces a high-visibility `Blocked_Cycle` badge with direct 1-click links to the mediation proposal and strategy picker.

### 2.5 Priority Ordering & Parent CRP Visualization
1. **Negative Priority Scale**: Child regression CRPs use negative priorities (`-1`, `-2`, `-3`...) to clearly differentiate downstream sequential dependencies from standard user-assigned priorities (`High`, `Medium`, `Low`). Lower negative numbers (e.g. `-1` before `-2`) represent earlier execution steps in the topological sort.
2. **Parent Proposal Dashboard View**: The output/summary of the parent CRP displays an ordered table of all generated regression requirements and child CRPs, showing execution status, target repo, and assigned execution sequence.

---

## 3. Governance Integration Plan
1. **Rule Addition**: Introduce `RULE-LCM-019: Automated Regression CRP Lifecycle and Cycle Prevention` in `ProposalReviewFlowPolicy.md`.
2. **Tooling Updates**:
   - Update `Invoke-ProposalAction.ps1` to support regression evaluation and child CRP generation.
   - Update `Show-CmControlHub.ps1` and `LcmToolCatalog.psm1` to render regression child links and dependency trees.

> [!IMPORTANT]
> **Awaiting Operator Authorization**: Per `RULE-LCM-015` and `RULE-LCM-016`, this CRP is registered in the `OPEN` state. Implementation planning and code modifications will proceed only upon receipt of an explicit `PROCEED 135` trigger.
