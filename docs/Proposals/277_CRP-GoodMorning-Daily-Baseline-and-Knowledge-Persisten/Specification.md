# Change Request Proposal: CRP-277

```yaml
CRP-ID: CRP-277
Title: Macrium Reflect-Backed BCR Review Workflow
Scope: LCM_Inventory
Baseline-Version: 10.2.0
Author: rgbig
Date: 2026-10-15 14:31:18
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Re-implement the complete governed review workflow around a writable Macrium
Reflect image baseline. The workflow selects today's eligible `D:` backup,
mounts it in Macrium's chosen `F:`-`I:` slot, validates the operator-owned `_LCM` Beyond Compare profile,
and launches the exact CRP or cohort BCR review against
`D:\Git_Repositories`. It provides review preparation and BCR execution, not
GoodMorning or GoodNIGHT session-recovery behavior.

## 2. Technical Requirements & Invariants
- The workflow selects only a same-day completed Macrium backup for the `D:`
  source volume. It never silently substitutes an older image, Git baseline,
  scratch baseline, or a volume whose label does not match the configured
  Macrium source.
- Macrium Reflect supplies the writable review baseline. The selected image
  mounts only its `D:` partition in the bounded `F:`-`I:` range, with
  restricted-folder access and
  writable mode enabled.
- A BCR action finds the current writable baseline by its expected volume label
  in `F:`-`I:` and reuses that mount with the `_LCM` profile; it
  never remounts or replaces the baseline during the workday. This preserves
  operator RHS-to-LHS copies as review-progress indicators.
- Existing matching Macrium image mounts are detached only in the bounded
  `F:`-`I:` range. Detach and Browse Image operations run through the elevated
  interactive desktop path.
- The mounted label-matched `X:\Git_Repositories` tree (`X` in `F:`-`I:`) is the BCR LHS; live
  `D:\Git_Repositories` is the RHS. The LHS is reference content only and
  cannot imply lifecycle acceptance, staging, completion, or operator intent.
- The operator-owned `_LCM` Beyond Compare profile owns roots, content
  comparison, changed-only handling, filters, and the `.git\hooks` inclusion.
  The workflow validates it and never rewrites it.
- BCR resolves the exact CRP, BUG, or declared cohort; synchronizes every
  applicable cohort member before launch; records the BCR scope and review
  disposition; and preserves the existing Gate-2 acceptance requirements.
- GoodMorning and GoodNIGHT orchestration, recovery receipts, and session
  persistence are outside this CRP.

## 3. Resolved Operational Decisions

- Macrium completion reports are the authority for image selection. When no
  same-day image exists or the backup directory is unavailable, the configured
  definition is started once and polled for a bounded period. Automatic
  creation is limited to one request per local calendar day; the seven-hour
  GoodMorning session-break rule does not make a second automatic backup
  eligible. `-ForceNewBackup` is the explicit operator-only exception for an
  additional same-day baseline.
- The expected volume label is mandatory. The assigned drive letter is accepted
  only when it is in the bounded `F:`-`I:` range and contains
  `Git_Repositories`.
- The baseline receipt identifies the mounted image, Macrium restore point,
  and exact BCR review scope. It is not lifecycle acceptance evidence.
- The receipt also records confirmed F:-I: detach/reappearance and snapshot
  corroboration. A GoodNight or session timestamp alone does not prove the
  mounted image is current; it corroborates the daily image only after a
  confirmed detach followed by reappearance.
- The BCR launcher reuses one existing stable `_LCM` Folder Compare window when
  the writable baseline is unchanged. It launches `_LCM` only when no matching
  window is open and refuses ambiguous duplicate windows. The exact CRP, BUG,
  or COH identity remains in per-review metadata; the `_LCM` window title is
  not rewritten.
- Review acceptance, staging, commit authorization, and completion remain
  RHS-only governed actions after BCR; the Macrium image never authorizes
  them.
- Starting a governed review establishes `in_review`; an expressed Acceptance
  creates the ordinary commit authorization and the successful commit completes
  that review. A documented premature-completion repair restores only the
  affected CRP to `in_review` and preserves its prior history.
