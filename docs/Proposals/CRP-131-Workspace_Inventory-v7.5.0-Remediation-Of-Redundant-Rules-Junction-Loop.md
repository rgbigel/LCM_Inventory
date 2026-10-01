# Change Request Proposal: CRP-131
# Remediation of Redundant Rules Junction Loop in LCM_Inventory

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-131` |
| **Lifecycle State** | `OPEN` (Awaiting Operator Review & PROCEED Trigger per RULE-LCM-015) |
| **Origin Repository** | `LCM_Inventory` |
| **Target Scope** | `LCM_Inventory\.agents\rules` Junction Topology & Review Exclusions |
| **Author** | Operator Directive / CRP Intake |
| **Date** | 2026-09-09 |
| **Priority** | `Medium` |
| **Version Impact** | `v7.5.0` |
| **Governing Policy** | `ProposalReviewFlowPolicy.md` (`RULE-LCM-015`, `RULE-LCM-016`) |

---

## 1. Executive Summary & Intent

The operator identified an architectural redundancy and potential directory loop in `LCM_Inventory`:
- An unnecessary NTFS directory junction exists at `LCM_Inventory\.agents\rules` targeting `D:\Git_Repositories\.lcm\.agents\rules` (or `Git_Repositories\.agents`).
- If `LCM_Inventory` directly contains or hosts physical rules, or if child repositories junction back to a root that physically resides or maps into the same tree, a circular junction reference exists.
- In Beyond Compare visual reviews (`Invoke-BeyondCompareReview.ps1`), this triggers a redundant second review session traversing `.agents\rules` unnecessarily.
- This CRP establishes formal intake to analyze the physical rules topology, eliminate redundant junctions, prevent loop traversals, and align `LCM_Inventory` with canonical LCM governance.

---

## 2. Problem Analysis & Mechanical Findings

1. **Junction Invariant in LCM (`RULE-REV-008`, `RULE-LCM-004`)**:
   - Governed child repositories are designed to junction `.agents/rules` directly to `D:\Git_Repositories\.agents\rules` (or `.lcm\.agents\rules`).
   - However, `LCM_Inventory` serves as the central inventory container for the entire workspace.
2. **Identified Discrepancy**:
   - `LCM_Inventory\.agents\rules` is currently mapped as an NTFS directory junction:
     `D:\Git_Repositories\LCM_Inventory\.agents\rules` $\rightarrow$ `D:\Git_Repositories\.lcm\.agents\rules`.
   - If physical rule files exist directly within the repository, maintaining a junction pointing back out to the parent root container introduces an unnatural circular dependency.
   - Without careful exclusion handling, Windows tooling and Git review traversals encounter duplicate paths for the identical physical ruleset.

---

## 3. Normative Specification (Option B: LCM_Inventory Rule Ownership)

1. **Rule Ownership & Commit Gate Alignment**:
   - `LCM_Inventory` is codified as the authoritative physical owner and single commit gate for LCM governance rules.
   - The physical ruleset is migrated to and tracked by `LCM_Inventory` under `LCM_Inventory\.agents\rules\`.
2. **Junction Inversion & Root Decoupling**:
   - The root container `Git_Repositories` un-tracks `.lcm/.agents/rules/` and creates an NTFS directory junction pointing to `LCM_Inventory\.agents\rules\`.
   - Root commits in `Git_Repositories` for rule updates are eliminated.
3. **Tooling & Review Harness Alignment**:
   - `Repair-LCMRules.ps1` recognizes `LCM_Inventory` as the physical canonical source and skips junction creation on it.
   - `Invoke-BeyondCompareReview.ps1` includes `.agents\rules` directly in the primary `LCM_Inventory` review and suppresses redundant secondary junction review sessions.
4. **Rule Authority Policy Update**:
   - Update `RuleAuthority.md` (`RULE-AUTH-001`) to reflect that `LCM_Inventory\.agents\rules` is the physical source of truth, surfaced to the workspace root via junction.

---

## 4. Affected Components

- `LCM_Inventory\.agents\rules` (NTFS Directory Junction)
- `LCM_Inventory\tools\Invoke-BeyondCompareReview.ps1`
- `LCM_Inventory\tools\Repair-LCMRules.ps1`
- `LCM_Inventory\tools\Test-LCMRuleHealth.ps1`
- `LCM_Inventory\data\proposals\proposals.json`
