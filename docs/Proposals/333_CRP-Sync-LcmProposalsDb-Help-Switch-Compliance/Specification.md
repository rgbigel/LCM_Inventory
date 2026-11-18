# Specification: CRP-333

Module: docs/Proposals/333_CRP-Sync-LcmProposalsDb-Help-Switch-Compliance/Specification.md  
Purpose: Make Sync-LcmProposalsDb.ps1 print its own usage for -Help / -h / -? (RULE-PS-010).  
Path: LCM_Inventory/docs/Proposals/333_CRP-Sync-LcmProposalsDb-Help-Switch-Compliance/Specification.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4
Status: Suggested (registered)  
Date: 2026-11-15 15:44:55

```yaml
CRP-ID: CRP-333
Title: Sync-LcmProposalsDb Help Switch Compliance
Scope: LCM_Inventory
Target Scope: LCM_Inventory/tools/Sync-LcmProposalsDb.ps1
Affected Version Range: 10.6.4
Impacted Repositories: [LCM_Inventory]
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-15 15:44:55
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: 5
App-ID: None
```

---

## 0. Registration Note

Created and registered by Claude (operator instruction 2026-11-15, WORKPLAN D-29) via `New-LCM_Proposal`. `Implementation_Plan.md` and `Walkthrough.md` are tool placeholders. Found while registering CRP-332.

## 1. Gate 0 Contract (RULE-GOAL-002)

- **Target State**: `Sync-LcmProposalsDb.ps1 -Help`, `-h` and `-?` print the tool's own usage (synopsis, parameters, examples) and exit without mutation.
- **Binding Principle**: "Cause no havoc: ask rather than invent or infer, and avoid unnecessary complexity."
- **Exit Criteria**: all three switches show the tool's help; the script passes `Parser::ParseInput`; no other behaviour changes.
- **Explicit Non-Goals**: no change to sync logic, parameters or outputs; no sweep of other tools (a separate CRP if wanted).

## 2. Facts (2026-11-15)

- `pwsh -File Sync-LcmProposalsDb.ps1 -Help` and `-h` print the generic PowerShell topic "PowerShell Help System" instead of the tool's help.
- Cause: line 122 calls `Get-Help -Path $PSCommandPath -Detailed`; `-Path` selects a help provider location, not the script. Correct form: `Get-Help -Name $PSCommandPath -Detailed` (or a hand-written usage block like other LCM tools).
- Line 115 declares `[switch]$Help` without `[Alias('h', '?')]` (RULE-PS-010).

## 3. Requested Changes

1. Line 115: `[Alias('h', '?')][switch]$Help`.
2. Line 122: `Get-Help -Name $PSCommandPath -Detailed`.
