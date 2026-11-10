# CRP-263: LCM Inbox Two-Phase Acknowledgement

```yaml
CRP-ID: CRP-263
Title: LCM Inbox Two-Phase Acknowledgement
Scope: LCM_Inventory
Baseline-Version: 10.2.0
Author: rgbig
Date: 2026-10-13 16:15:33
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: High
App-ID: None
```

| Metadata Field | Value |
|---|---|
| Proposal ID | `CRP-263` |
| Lifecycle State | `SUGGESTED` |
| Priority | `10` (Urgent) |
| Target Scope | LCM inbox return channel, daemon dispatch, and inbox synchronization |
| Impacted Repository | `LCM_Inventory` |

## Deficit

The inbox sender currently receives acknowledgement only after the complete processing workflow
finishes. If processing fails, blocks, or classifies an item unexpectedly, the sender cannot
determine whether the item was received, rejected, or still pending.

## Required Outcome

Implement a durable two-phase acknowledgement protocol:

1. **Phase 1 - Immediate receipt ACK:** acknowledge an inbox item immediately after it is
   discovered and accepted for processing, before classification, proposal creation, archival, or
   daemon dispatch.
2. **Phase 2 - Terminal outcome ACK:** publish exactly one terminal `success` or `failure`
   outcome after processing finishes. The outcome must identify the resulting proposal when one
   was created, or provide an actionable failure reason.

## Technical Requirements and Invariants

- Each acknowledgement must carry a stable correlation identity derived from the inbox item.
- Phase 1 must be persisted before irreversible processing steps begin.
- A terminal acknowledgement must be emitted for every Phase 1 acknowledgement, including
  classification failures, proposal-creation failures, archive failures, and unexpected errors.
- Retrying an already acknowledged item must be idempotent: it must not create duplicate
  proposals or contradictory terminal outcomes.
- An unexpected item type, including a classification such as `AUDIT` where proposal intake is
  not permitted, must produce a terminal `failure` acknowledgement rather than leave the sender
  without a result.
- The sender-facing return channel must expose receipt and terminal acknowledgements without
  requiring access to local daemon logs.
- Existing successful inbox intake, proposal creation, and archiving behavior must remain intact.
- The protocol must not acknowledge successful completion before the associated work is complete.

## Non-Goals

- This CRP does not change proposal lifecycle transitions.
- This CRP does not redefine inbox classification policy; it makes classification outcomes visible
  to the sender.
- This CRP does not make daemon processing synchronous.

## Acceptance Criteria

1. A valid inbox item receives a persisted receipt ACK before proposal intake begins.
2. A successfully processed item receives one terminal success ACK containing its proposal ID.
3. A failed, blocked, or unsupported item receives one terminal failure ACK with a useful reason.
4. Reprocessing the same item is idempotent and preserves the original correlation identity.
5. Focused tests cover receipt-before-processing, terminal success, terminal failure, and retry
   behavior.
