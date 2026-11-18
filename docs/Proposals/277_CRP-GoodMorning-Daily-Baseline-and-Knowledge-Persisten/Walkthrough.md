# Walkthrough: CRP-277 - Macrium Reflect-Backed BCR Review Workflow

## 1. Executive Summary
Implementation and verification records for CRP-277's complete Macrium
Reflect-backed BCR review workflow.

## 2. Verification Evidence
- 2026-10-15 interface research found the documented Macrium Reflect X
  per-drive detach form: `Reflect.exe <DriveLetter> -u`. The locally installed
  executable is `C:\Program Files\Macrium\Reflect\Reflect.exe`.
- 2026-10-15 live interface tests established that both Macrium Browse Image
  and per-drive detach require elevation in this environment. Browse Image can
  select only the `D:` partition, use its selected `F:`-`I:` assignment, enable
  restricted-folder access and writable mode, and mount successfully.
- The saved `_LCM` BCR profile was verified to open the label-matched
  `F:\Git_Repositories`
  against `D:\Git_Repositories` with its saved content comparison, changed-only
  display, and `.git\hooks` inclusion untouched.
- `Invoke-MacriumDailyBcrBaseline.ps1` prepares and verifies the writable
  Macrium baseline. The BCR action then resolves the exact review identity,
  reuses exactly one existing `_LCM` Folder Compare window when available,
  opens `_LCM` only when absent, and refuses ambiguous duplicate windows. The
  stable window title is unchanged; each review identity is recorded in its
  metadata receipt before required cross-repository review tabs open.
- BCR review remains distinct from acceptance: only RHS review evidence can
  later authorize staging, completion, and commit actions.
