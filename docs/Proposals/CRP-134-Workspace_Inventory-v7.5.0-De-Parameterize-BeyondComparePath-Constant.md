---
Proposal-ID: CRP-134
CR-ID: CRP-134
Scope: LCM_Inventory
Version: v7.5.0
Affected-Repos: [LCM_Inventory, LCM]
Severity: Low
Status: ACCEPTED
Date: 2026-09-10
Author: Operator Directive / CRP Intake
Target Scope: LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1, .lcm/config/
Affected Version Range: v7.5.0
Impacted Repositories: [LCM_Inventory, LCM]
---

# Change Request Proposal: CRP-134
# De-Parameterize BeyondComparePath in Invoke-BeyondCompareReview and Standardize Environment Constant

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-134` |
| **Lifecycle State** | `ACCEPTED` (Approved by Operator; Awaiting PROCEED for Execution) |
| **Origin Repository** | `LCM_Inventory` |
| **Target Scope** | `LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1` |
| **Author** | Operator Directive / CRP Intake |
| **Date** | 2026-09-10 |
| **Priority** | `Medium` |
| **Version Impact** | `v7.5.0` |

---

## 1. Executive Summary & Rationale
Currently, `Invoke-BeyondCompareReview.ps1` defines an optional CLI parameter:
```powershell
[Parameter(Mandatory = $false)]
[string]$BeyondComparePath = 'D:\Tools\Beyond Compare 5\BCompare.exe',
```
Prompting or passing `-BeyondComparePath` as a runtime parameter during daily operator reviews is impractical and clutters parameter dialogs. In the LCM governance model:
1. The Beyond Compare 5 executable location is an environment constant defined in LCM documentation and workstation configuration (`D:\Tools\Beyond Compare 5\BCompare.exe`).
2. Requiring or exposing this parameter on each review invocation creates unnecessary noise in CLI usage, Tool Explorer parameter dialogs, and automated dispatchers.

## 2. Proposed Changes
1. **Remove Parameter Exposure**: Remove `[Parameter(...)] [string]$BeyondComparePath` from the `param(...)` block of `Invoke-BeyondCompareReview.ps1`.
2. **Deterministic Resolution**: Within the script body, resolve `BCompare.exe` via an environment variable / configuration constant cascade:
   - Check `$env:BCOMPARE_PATH` (if defined).
   - Check standard LCM path: `D:\Tools\Beyond Compare 5\BCompare.exe`.
   - Check standard 64-bit Program Files: `${env:ProgramFiles}\Beyond Compare 5\BCompare.exe`.
   - Fall back to `Get-Command BCompare.exe -ErrorAction SilentlyContinue`.
3. **Tool Catalog Alignment**: Update `tool_catalog.json` and Tool Explorer metadata so `-BeyondComparePath` is no longer listed as a configurable parameter for `BeyondCompareReview`.

---

## 3. Invariant Verification & Compliance
- **RULE-LCM-015 / 016**: Registered in `OPEN` state. No implementation changes occur prior to explicit `PROCEED 134`.
- **PowerShell Standards**: Conforms to Microsoft approved verbs and StrictMode Latest.
