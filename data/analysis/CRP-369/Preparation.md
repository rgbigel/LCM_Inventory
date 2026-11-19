# CRP-369 Preparation: Single Source For VS Code Settings

Module: data/analysis/CRP-369/Preparation.md  
Purpose: CRP-369 Preparation: Single Source For VS Code Settings  
Path: LCM_Inventory/data/analysis/CRP-369/Preparation.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Analysis (preparation, read-only; nothing implemented)  
Date: 2026-11-19 17:27:06

---

## 1. Inventory

Root `.vscode/settings.json`: 28 settings; workspace file settings: 11 keys.

| Copy | Keys | Git-tracked | Only in the copy | Value differs from the root | Other files in `.vscode` |
|:---|---:|:---|:---|:---|:---|
| `AuthorizeMasterUser/.vscode/settings.json` | 5 | yes | `powershell.pester.pesterVersion`, `powershell.scriptAnalysis.enable` | - | - |
| `BGMSAMVInv/.vscode/settings.json` | 4 | yes | - | `meta` | tasks.json |
| `BackgroundModifier/.vscode/settings.json` | 4 | yes | - | `meta` | tasks.json |
| `BootEntryManager/.vscode/settings.json` | 4 | yes | - | `meta` | tasks.json |
| `LCM_AI/.vscode/settings.json` | 8 | yes | - | `meta` | tasks.json |
| `LCM_Shared/.vscode/settings.json` | 4 | yes | - | `meta` | tasks.json |
| `VolumeInventory/.vscode/settings.json` | 4 | no | - | `meta` | tasks.json |

Findings: every copy is a subset of the root file except the two `AuthorizeMasterUser` keys; the differing key `meta` is
the copy's own header object. Six repositories also carry `.vscode/tasks.json` (non-goal of CRP-369, untouched).

## 2. Steps

1. Move the two AuthorizeMasterUser-only keys into the root file if wanted (operator question 1).
2. Delete the 7 copies (6 tracked: one commit per repository; VolumeInventory untracked: plain delete).
3. Parse check of the root file (JSONC); Walkthrough lists every removed key with its disposition.

## 3. Dependencies

Shares no files with the other six CRPs; can run first or in any slot.

## 4. Operator Questions

1. `powershell.pester.pesterVersion` and `powershell.scriptAnalysis.enable` exist only in AuthorizeMasterUser: move them
   into the root file (applies to all repositories) or drop them?
