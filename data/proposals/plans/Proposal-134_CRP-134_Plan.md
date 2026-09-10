# Implementation Plan: Proposal-134 (CRP-134)
# De-Parameterize BeyondComparePath in Invoke-BeyondCompareReview and Standardize Environment Constant

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-134` / `#134` |
| **Target Repository** | `Workspace_Inventory` |
| **Target Version** | `v7.5.0` |
| **Status** | `IN_PROGRESS` |
| **Date** | 2026-09-10 |

## 1. Technical Scope
1. Remove `[Parameter(Mandatory = $false)][string]$BeyondComparePath` from `Invoke-BeyondCompareReview.ps1` CLI parameters.
2. Resolve Beyond Compare executable location internally using constant environment cascade:
   - `$env:BCOMPARE_PATH`
   - `D:\Tools\Beyond Compare 5\BCompare.exe`
   - `${env:ProgramFiles}\Beyond Compare 5\BCompare.exe`
   - `Get-Command BCompare.exe`
3. Add `HelpMessage` attributes and `.PARAMETER CRP` documentation to all parameters in `Invoke-BeyondCompareReview.ps1`.
4. Update `tool_catalog.json` so `-BeyondComparePath` is no longer a configurable parameter in Tool Explorer.
