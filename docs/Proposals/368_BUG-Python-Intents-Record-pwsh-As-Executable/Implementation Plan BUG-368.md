# Implementation Plan: BUG-368 - Python Intents Record pwsh As Executable

Module: docs/Proposals/368_BUG-Python-Intents-Record-pwsh-As-Executable/Implementation Plan BUG-368.md  
Purpose: Concrete changes per file for BUG-368.  
Path: LCM_Inventory/docs/Proposals/368_BUG-Python-Intents-Record-pwsh-As-Executable/Implementation Plan BUG-368.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 16:01:23

---

| File | Change |
|:---|:---|
| `tools/Update-ToolCatalog.ps1` | Python intents: `executable` = registered interpreter (`$script:LcmPythonExe`, RULE-PY-010) in both intent builders |
| `tools/Test-LcmExternalToolDocumentation.ps1` 10.7.5 | compares the file name of an intent executable (full paths now) |

Observation, not changed (choosing their executable would be a guess): `.reg` (12), `.lnk` (10), `.txt` (4) intents also carry `pwsh.exe`.
