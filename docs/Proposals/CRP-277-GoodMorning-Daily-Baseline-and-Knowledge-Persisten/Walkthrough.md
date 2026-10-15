# Walkthrough: CRP-277 - GoodMorning Daily Baseline and Knowledge Persistence Routine

## 1. Executive Summary
Implementation and verification records for CRP-277's daily Macrium baseline
and BCR preparation scope. The GoodNIGHT Save All receipt/recovery scope was
split into CRP-278 before CRP-277 review completion.

## 2. Verification Evidence
- Proposal bundle and durable original intake record created.
- Pending operator-approved implementation after the Macrium interface,
  drive-letter, wait-policy, and GoodNIGHT receipt decisions are resolved.
- 2026-10-15 interface research found the documented Macrium Reflect X
  per-drive detach form: `Reflect.exe <DriveLetter> -u`. The locally installed
  executable is `C:\Program Files\Macrium\Reflect\Reflect.exe`; it was not
  invoked for a detach.
- A temporary, confirmation-gated probe was drafted at
  `tools/Invoke-MacriumImageDetachProbe.ps1`. It remains unrun pending
  operator inspection.
- The first approved detach test handed off to Macrium but left `F:` mounted
  while Beyond Compare held the F:-to-D: comparison open. The probe now
  identifies the named `_LCM` Folder Compare session, requests a graceful
  close, and waits for it to exit before attempting the detach. It leaves
  unrelated Beyond Compare windows alone and fails explicitly if the mounted
  image session cannot close. Its allowable mounted-image drive range is
  constrained to `F:` through `I:`.
- 2026-10-15 live interface tests established that both Macrium Browse Image
  and per-drive detach require elevation in this environment. Browse Image can
  select only the `D:` partition, use the required `F:` assignment, enable
  restricted-folder access and writable mode, and mount successfully.
- The saved `_LCM` BCR profile was verified to open `F:\Git_Repositories`
  against `D:\Git_Repositories` with its saved content comparison, changed-only
  display, and `.git\hooks` inclusion untouched.
- `Invoke-WorkspaceGoodMorning.ps1` remains the existing read-only recovery
  report. The daily Macrium/BCR flow is opt-in through
  `-PrepareBcrBaseline`, which delegates to
  `Invoke-MacriumDailyBcrBaseline.ps1`; no existing GoodMorning behavior was
  removed.
- GoodNIGHT Save All receipt/recovery work was moved to CRP-278. It was not
  represented as complete by CRP-277.
