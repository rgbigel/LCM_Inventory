# Walkthrough: CRP-369 - Single Source For VS Code Settings

Module: docs/Proposals/369_CRP-Single-Source-For-VS-Code-Settings/Walkthrough CRP-369.md  
Purpose: Implementation and verification record for CRP-369.  
Path: LCM_Inventory/docs/Proposals/369_CRP-Single-Source-For-VS-Code-Settings/Walkthrough CRP-369.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 17:43:45

---

## 1. Keys Present Only In A Deleted Copy (T3)

| Repository copy | Keys not in the root file | Disposition |
|:---|:---|:---|
| AuthorizeMasterUser | `powershell.pester.pesterVersion`, `powershell.scriptAnalysis.enable` | dropped (operator 2026-11-19) |
| BGMSAMVInv | none | - |
| BackgroundModifier | none | - |
| BootEntryManager | none | - |
| LCM_AI | none | - |
| LCM_Shared | none | - |
| VolumeInventory | none | - |

## 2. Verification (2026-11-19 17:43:45)

| Check | Result |
|:---|:---|
| `settings.json` files below the git root after the change | root and OutlookVBAConversion only (exit criterion) |
| Root file | unchanged, parses as JSONC (checked 2026-11-19 with all settings files) |
| Workspace behaviour | unchanged: `Solution.code-workspace` has the git root as the only repository folder, so VS Code applied only the root file before and after |
