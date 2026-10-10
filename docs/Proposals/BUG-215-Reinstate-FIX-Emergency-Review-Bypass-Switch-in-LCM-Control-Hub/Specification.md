# BUG-215: Reinstate FIX Emergency Review Bypass Switch

| Metadata Field | Value |
|---|---|
| Bug ID | `BUG-215` |
| Lifecycle State | `IN_PROGRESS` |
| Scope | LCM Control Hub review-action UI and emergency review bypass dispatch |
| Affected Repositories | `LCM_Inventory` |
| Severity | High |

## Intake Evidence

The proposal ledger records a missing visible FIX/emergency review-bypass action in the LCM
Control Hub. This bundle was missing when BUG-215 was selected for investigation; this document
is now its authoritative intake specification.

## Expected Behavior

An operator-authorized critical blocking issue can invoke the defined emergency review-bypass
path from the Control Hub. Normal review gating remains the default, and every bypass must be
explicitly identified and auditable.

