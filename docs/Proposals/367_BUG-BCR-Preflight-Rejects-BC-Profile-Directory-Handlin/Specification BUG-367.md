# Specification: BUG-367 - BCR Preflight Rejects BC Profile Directory Handling

Module: docs/Proposals/367_BUG-BCR-Preflight-Rejects-BC-Profile-Directory-Handlin/Specification BUG-367.md  
Purpose: BCR Preflight Rejects BC Profile Directory Handling  
Path: LCM_Inventory/docs/Proposals/367_BUG-BCR-Preflight-Rejects-BC-Profile-Directory-Handlin/Specification BUG-367.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Pushed  
Date: 2026-11-19 12:16:42

```yaml
CRP-ID: BUG-367
Title: BCR Preflight Rejects BC Profile Directory Handling
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Claude
Bug-ID: BUG-367
Severity: Medium
Affected-Repos: LCM_Inventory
Root-Cause: The BCR preflight enforced a Beyond Compare view setting (directory handling) that is the operator's choice.
Date: 2026-11-19 12:15:53
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: 5
App-ID: None
```

---

## 1. Defect

`Invoke-MacriumDailyBcrBaseline.ps1` threw at the Gate 2 BCR of CRP-366 (2026-11-19 12:05) because the `_LCM` profile had directory handling `dirShowAll`; the baseline (today's image `...-10-10.mrimgx`, 09:18:36) was already mounted on F:, the review window was not refreshed.

## 2. Target State

Operator 2026-11-19 (option B): "this check is not rq'd". Directory handling is logged, never enforced; left path, right path and content comparison stay checked.
