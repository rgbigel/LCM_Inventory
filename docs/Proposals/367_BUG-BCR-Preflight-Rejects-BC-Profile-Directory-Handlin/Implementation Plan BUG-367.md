# Implementation Plan: BUG-367 - BCR Preflight Rejects BC Profile Directory Handling

Module: docs/Proposals/367_BUG-BCR-Preflight-Rejects-BC-Profile-Directory-Handlin/Implementation Plan BUG-367.md  
Purpose: Concrete changes per file for BUG-367.  
Path: LCM_Inventory/docs/Proposals/367_BUG-BCR-Preflight-Rejects-BC-Profile-Directory-Handlin/Implementation Plan BUG-367.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: In Progress  
Date: 2026-11-19 12:16:42

---

| File | Change |
|:---|:---|
| `tools/Invoke-MacriumDailyBcrBaseline.ps1` 10.2.10 | `throw` on directory handling replaced by an INFO log line; header Implementation Choices (BUG-367) |
