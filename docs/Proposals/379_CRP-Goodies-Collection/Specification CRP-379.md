# Specification: CRP-379

Module: docs/Proposals/379_CRP-Goodies-Collection/Specification CRP-379.md  
Purpose: Goodies Collection  
Path: LCM_Inventory/docs/Proposals/379_CRP-Goodies-Collection/Specification CRP-379.md  
Authors: Rolf  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-19 23:50:40

```yaml
CRP-ID: CRP-379
Title: Goodies Collection
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-19 23:50:40
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 2
App-ID: None
```

---

## 1. Executive Summary & Intent

A collection point for small improvements ("goodies") found during work and live tests. The operator decides when
they are packaged into a CRP of their own (operator 2026-11-19); until then nothing here is implemented.

## 2. Goodies

| # | Goodie | Origin | Notes |
|:---|:---|:---|:---|
| G1 | `Set-LcmWindowZone.py --activate`: bring the placed window to the foreground | CRP-361 live test 2026-11-19 (operator) | Windows limits foreground changes by background programs; route through the daemon's existing `/foreground` |

## 3. Gate 0 Contract

Written when the operator packages goodies into a CRP; each goodie then gets its target state and exit criterion.
