# Walkthrough: BUG-368 - Python Intents Record pwsh As Executable

Module: docs/Proposals/368_BUG-Python-Intents-Record-pwsh-As-Executable/Walkthrough BUG-368.md  
Purpose: Implementation and verification record for BUG-368.  
Path: LCM_Inventory/docs/Proposals/368_BUG-Python-Intents-Record-pwsh-As-Executable/Walkthrough BUG-368.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 16:01:23

---

| Check | Result |
|:---|:---|
| Found | 60 Python intents with `executable = pwsh.exe` (CRP-361 T6 registration) |
| AST parse of both changed files | 0 errors |
| Catalog + `Sync-LcmToolCatalogDb -Action Sync` | 60 Python intents now `D:\Tools\Python314\python.exe`; other types unchanged |
| `Test-LcmExternalToolDocumentation.ps1` | before the second fix 1 undocumented (full path); after: 0 undocumented, exit 0 |
| Consumers | `Show-ToolIntents.ps1` builds `executable + script` without trampoline: was the broken `pwsh.exe x.py`, now correct |
