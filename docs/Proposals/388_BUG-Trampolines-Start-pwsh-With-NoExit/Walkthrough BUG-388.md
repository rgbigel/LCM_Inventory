# Walkthrough: BUG-388 - Trampolines Start pwsh With NoExit

Module: docs/Proposals/388_BUG-Trampolines-Start-pwsh-With-NoExit/Walkthrough BUG-388.md  
Purpose: Walkthrough of BUG-388.  
Path: LCM_Inventory/docs/Proposals/388_BUG-Trampolines-Start-pwsh-With-NoExit/Walkthrough BUG-388.md  
Authors: Rolf, Claude  
Version: 10.8.4  
Status: Verified  
Date: 2026-11-20 16:44:15

---

- `tools/Update-ToolCatalog.ps1` 10.2.13: the trampoline generator never writes `-NoExit` (the catalog field NoExit stays as metadata).
- Regenerated with `Update-ToolCatalog.ps1 -Silent`: 0 trampolines with `-NoExit` in `DoT/` and `Cmd/`; parse clean.
