# Walkthrough: BUG-370 - Claude EOL Hook Swallows Errors Without A Trace

Module: docs/Proposals/370_BUG-Claude-EOL-Hook-Swallows-Errors-Without-A-Trace/Walkthrough BUG-370.md  
Purpose: Implementation and verification record for BUG-370.  
Path: LCM_Inventory/docs/Proposals/370_BUG-Claude-EOL-Hook-Swallows-Errors-Without-A-Trace/Walkthrough BUG-370.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 16:26:01

---

| Check | Result |
|:---|:---|
| Old hook against the new tests | 2 of 4 failed (failure and invalid payload left no trace): defect confirmed |
| `flake8 --select=E9,F63,F7,F82,F401,F541,F841` | 0 |
| `python -I -m unittest discover` (all LCM_Inventory Python tests) | 20 run, OK, 1 skipped (live window test) |
| Live hook on the Write of the hook itself | LF applied, no log line (no error) |
