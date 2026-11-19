# Implementation Plan: CRP-369 - Single Source For VS Code Settings

Module: docs/Proposals/369_CRP-Single-Source-For-VS-Code-Settings/Implementation Plan CRP-369.md  
Purpose: Concrete changes per file for CRP-369.  
Path: LCM_Inventory/docs/Proposals/369_CRP-Single-Source-For-VS-Code-Settings/Implementation Plan CRP-369.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 17:43:45

---

| File | Change | Gate 0 clause |
|:---|:---|:---|
| `.vscode/settings.json` in AuthorizeMasterUser, BGMSAMVInv, BackgroundModifier, BootEntryManager, LCM_AI, LCM_Shared (tracked) and VolumeInventory (untracked) | deleted; the empty `.vscode` folder of AuthorizeMasterUser removed; the `tasks.json` files stay (non-goal) | T1, T2 |
| root `.vscode/settings.json` | unchanged: it already holds every key of the deleted copies except the two dropped ones | T3 |

Commits: LCM_AI and LCM_Shared through the governed COMPLETE; the other five repositories are not LCM-governed and need their own commit of the deletion.
