# Walkthrough & Verification: BUG-172
# Remediate Get-Content Parameter Conflict in Apply-AllCustomizations

| Field | Value |
| :--- | :--- |
| **Proposal ID** | `BUG-172` |
| **Status** | `REVIEW` (Gate 2 Review Gate) |
| **Target Files** | `SystemConfiguration/Source/Apply-AllCustomizations.ps1`, `LCM_Inventory/tools/Update-ToolCatalog.ps1`, `LCM_Inventory/tools/Flush-LcmLegacyLogs.ps1` |
| **Date** | 2026-10-13 |

---

## 1. Defect Remediation Summary

1. **`SystemConfiguration/Source/Apply-AllCustomizations.ps1`**:
   - Lines 222, 229, and 236: Replaced `Get-Content -LiteralPath $Path -TotalCount <N> -Raw` with `(Get-Content -LiteralPath $Path -TotalCount <N> -ErrorAction SilentlyContinue) -join "`n"`.
   - Prevents parameter binding exception under PowerShell `StrictMode` when checking for `$TraceMode` and `$ShowAll` flags.
2. **Latent Invariant Protection**:
   - `LCM_Inventory/tools/Update-ToolCatalog.ps1` (Line 981): Replaced `-TotalCount 250 -Raw` with `(Get-Content -LiteralPath $f.FullName -TotalCount 250 -ErrorAction SilentlyContinue) -join "`n"`.
   - `LCM_Inventory/tools/Flush-LcmLegacyLogs.ps1` (Line 78): Replaced `-TotalCount 15 -Raw` with `(Get-Content -LiteralPath $Path -TotalCount 15 -ErrorAction SilentlyContinue) -join "`n"`.

---

## 2. Verification Receipts

- Syntax validation: `pwsh -File SystemConfiguration/Source/Apply-AllCustomizations.ps1 -h` executed cleanly with exit code 0.
- Parameter resolution verification: Tested reading top 40 lines of `@02-Set_the_date_and_time_format_(ADM_systemwide).ps1`; regex inspection returned `HasTrace: True | HasShowAll: True` without parameter errors.

---

## 3. Review Gate (Gate 2)

Awaiting operator review and disposition at Gate 2 per `RULE-LCM-014`.
