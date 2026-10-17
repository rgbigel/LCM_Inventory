# Bug Repair: BUG-289

```yaml
Bug-ID: BUG-289
Title: [BUG] Control Hub governance switch does not reflect or apply backend state
Scope: LCM_Inventory
Author: rgbig
Date: 2026-10-17 22:32:48
Status: Suggested
```

---

## 1. Defect and Intent
The Control Hub presents its Governance switch as `ON` while the authoritative proposal ledger reports `lcm_mode: paused`. A click provides no trustworthy indication that the daemon received the request, changed state, or rejected it.

## 2. Backend-Confirmed Normal Governance
- The control must display its state only from current backend-confirmed data.
- A request must show a concise pending result and must not optimistically recolor the switch.
- On success, refresh authoritative state and report the effective result, including unchanged requests such as `Governance: On — unchanged; normal governance was already active.`
- On failure, retain the last confirmed state and surface the failure with the attempted action.

## 3. Explicit State Semantics
- **Green — `Gov: On`:** normal lifecycle governance is active.
- **Red — `Gov: Off`:** governance is explicitly disabled and the Hub must display the authorization, reason, and timestamp. No lifecycle-changing action may silently proceed under this state.
- **Yellow — `Gov: Bounded (<scope>)`:** an operator-authorized recovery transaction is active only for a named cohort or proposal set. It must show its scope, reason, authorization, and timestamp.

## 4. Bounded Recovery Invariants
Yellow is not a general governance bypass. It permits only the authorized state reconciliation for its declared scope, retains Gate 2 review, blocks unrelated lifecycle changes, requires one shared review receipt and completion transaction per affected repository, and returns explicitly to `Gov: On` when the recovery closes.

## 5. Verification
- Test the active/paused backend transitions and exact rendered green/red state.
- Test daemon failure and unchanged-state responses without visual misrepresentation.
- Test that yellow requires an explicit scope and authorization and cannot affect an unrelated proposal.
- Verify all displayed state, authorization, reason, and timestamp values are backend-confirmed.
