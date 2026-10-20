# Bug Defect Specification: BUG-299

| Metadata Field | Value |
| :--- | :--- |
| **Defect ID** | `BUG-299` |
| **Lifecycle State** | `OPEN` (ledger state: `suggested`; awaiting explicit activation) |
| **Origin Repository** | `LCM_Inventory` |
| **Target Scope** | Macrium daily BCR baseline workflow, especially `tools/Invoke-MacriumDailyBcrBaseline.ps1` |
| **Author** | rgbig |
| **Date** | 2026-10-20 |
| **Priority** | 5 (initial BUG intake priority) |

---

## 1. Observed Defect

During the 2026-10-20 Macrium baseline mount attempt, the elevated worker exited with:

> Macrium Browse Image dialog did not become ready within 30 seconds.

The operator reported that the Browse Image dialog was visibly displayed while the readiness check timed out. The failure is raised in `tools/Invoke-MacriumDailyBcrBaseline.ps1` after the UI Automation polling loop.

## 2. Expected Behavior

The baseline workflow should reliably recognize the ready Browse Image dialog when it is visibly presented and continue the operator-confirmed mount flow, rather than reporting a readiness timeout while the dialog is available.

## 3. Current Evidence and Unknowns

- The worker's readiness polling is bounded by a 30-second deadline.
- The operator observed the dialog on screen during the failed readiness check.
- The actual cause has not been established.
- Candidate explanations include an insufficient timeout or detection that depends on a UI Automation element, process/window relationship, or screen location that can vary. These are hypotheses only.
- A later check confirmed the expected Macrium volume mounted at `F:` with `F:\Git_Repositories` present. This does not establish which action completed the mount.

## 4. Intake Boundary

This record captures the defect report only. No fix, root-cause conclusion, implementation plan, or activation is authorized by registration. Investigate and implement only after an explicit activation trigger, preserving the operator's interactive selection and mount safeguards.

## 5. Verification Criteria (for a future activated fix)

- Reproduce or otherwise test the dialog-readiness detection when the dialog appears after a delayed interval.
- Verify detection is independent of variable window placement and does not confuse unrelated Macrium windows or dialogs.
- Verify timeout failures remain explicit and actionable when the expected dialog never appears.
- Verify the existing mount options, operator selection, and mounted-volume validation remain intact.
