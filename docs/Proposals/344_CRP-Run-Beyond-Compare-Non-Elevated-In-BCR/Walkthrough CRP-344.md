# Walkthrough: CRP-344 - Run Beyond Compare Non-Elevated In BCR

Date: 2026-11-18 18:31:34

## 1. Path taken
- The exit criteria were reached by CRP-343 segment 1 (2026-11-17); this item records the live evidence and closes without changes of its own.
- The tri-state `tools.admin` (CRP-343 section 9) will reclassify the BCR tools as `controlled`; that does not change the BC launch level.

## 2. Verification evidence (2026-11-18 18:31:34)
- Catalog (`data/tools/tools.db`): `Invoke-MacriumBcrReview.ps1`, `Invoke-MacriumDailyBcrBaseline.ps1`, `Invoke-BcrDispatcher.ps1`, `Select-BeyondCompareTab.ahk` and their intents `elevated = 0`; `Invoke-MacriumMountWorker.ps1`, `Dismount-MacriumCurrentBaseline.ps1`, `Mount-MacriumBrowseDialog.ahk` intents `elevated = 1` (owning tools `admin = 1`).
- Mount through the elevated atom: `logs/Invoke-MacriumMountWorker-20261118_132348.log` / `_132353.log` (F: detached and remounted, AHK dialog atom: restricted folders, writable, partition, OK - SUCCESS).
- Beyond Compare: exactly one process (PID 40376, started 2026-11-18 13:23:55), title `_LCM - Folder Compare - Beyond Compare [...]` without `Administrator:`; its process handle opens from a Medium-integrity shell (non-elevated).
- Baseline side usable: the operator reviewed CRP-346, BUG-352, CRP-355, CRP-359 in this window on 2026-11-18 (review markers on F:).