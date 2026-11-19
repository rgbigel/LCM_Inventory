# Walkthrough: BUG-367 - BCR Preflight Rejects BC Profile Directory Handling

Module: docs/Proposals/367_BUG-BCR-Preflight-Rejects-BC-Profile-Directory-Handlin/Walkthrough BUG-367.md  
Purpose: Implementation and verification record for BUG-367.  
Path: LCM_Inventory/docs/Proposals/367_BUG-BCR-Preflight-Rejects-BC-Profile-Directory-Handlin/Walkthrough BUG-367.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 12:16:42

---

| Check | Result |
|:---|:---|
| AST parse `Invoke-MacriumDailyBcrBaseline.ps1` | 0 errors |
| Pester `MacriumBcrReview.Tests.ps1` (child process) | 15 passed, 0 failed |
| Live: BCR for CRP-366 after the fix | see section 2 after the run |
