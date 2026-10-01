# Bug Report: BUG-139
# Pushed Proposal Immutability, Sequence Integrity, and Origin Traceability

| Metadata Field | Value |
| :--- | :--- |
| **Bug ID** | `BUG-139` |
| **Lifecycle State** | `OPEN` (Awaiting Operator Activation per RULE-LCM-015) |
| **Origin Repository** | `LCM_Inventory` |
| **Target Scope** | Configuration Management Governance / Proposal Flow |
| **Author** | Operator Directive / BUG Intake |
| **Date** | 2026-09-11 |
| **Severity** | `High` |
| **Version Impact** | `v7.5.0` |
| **Governing Policy** | `ProposalReviewFlowPolicy.md` (`RULE-LCM-007`, `RULE-LCM-008`, `RULE-LCM-010`, `RULE-LCM-015`) |

---

## 1. Defect Summary & Symptoms

During triage and intake of newly reported issues from testing:
1. The AI agent attempted to create proposal files reusing sequence identifiers (`133`, `134`, `135`) whose proposals were already committed, completed, and pushed to remote in previous sessions.
2. Re-using sequence numbers or mutating already-pushed proposals violates Configuration Management ledger immutability and risks ledger corruption.
3. New defects and change requests must always be allocated fresh, monotonically increasing sequence IDs and must explicitly link back to the originating/parent proposals from which the regressions or follow-ups arose.

---

## 2. Root Cause Analysis

1. In the active session, `BUG-133`, `CRP-134`, and `CRP-135` were previously completed and pushed (`pushed_at: 2026-09-10 18:33:01`).
2. The agent's initial sequence lookup during intake failed to query the true maximum ID in `proposals.json`, causing an attempted overwrite of IDs 133–135.
3. This violated the core LCM invariant that pushed proposals are immutable historical artifacts.

---

## 3. Corrective Measures & Proposed Remediation

1. **Strict Ledger Sequence Enforcement**:
   - The ledger `last_proposal_id` counter must always strictly monotonically increase.
   - Any new proposal or bug report MUST receive the next unallocated integer ID (`id = max(id) + 1`).
2. **Pushed Proposal Immutability**:
   - Files for proposals in `pushed` or `completed` state are strictly read-only and immutable.
   - No agent action may edit, overwrite, rename, or re-purpose an existing proposal file or ledger record.
3. **Mandatory Origin Cross-Linking**:
   - Every regression bug or follow-up proposal must explicitly document its lineage by linking to the originating proposal in its header metadata, problem description, and `proposals.json` details (e.g. `Originating Proposal: [BUG-133](file:///...)`).
4. **Lineage Alignment**:
   - `BUG-136` (ShowActions log filter) links to `BUG-133` (where ShowActions parameter dispatch was introduced).
   - `BUG-137` (Daemon foreground focus inversion) links to `BUG-133` (where daemon `/open` handling was modified).
   - `CRP-138` (ShowTools button and header layout) links to `BUG-133` and `BUNDLE-STD-DISPLAY-v7.5.0` (where ShowTools buttons were introduced).
