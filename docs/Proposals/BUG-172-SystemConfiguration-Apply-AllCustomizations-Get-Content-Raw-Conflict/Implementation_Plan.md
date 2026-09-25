# Implementation Plan: BUG-172
# Remediate Get-Content Parameter Conflict in Apply-AllCustomizations

| Field | Value |
| :--- | :--- |
| **Proposal ID** | `BUG-172` |
| **State** | `IN_PROGRESS` (DOIT Mode Execution directly to Gate 2) |
| **Target Files** | `SystemConfiguration/Source/Apply-AllCustomizations.ps1`, `.lcm/tools/internal/Update-ToolCatalog.ps1`, `.lcm/tools/internal/Flush-LcmLegacyLogs.ps1` |
| **Author** | Rolf, Antigravity AI Assistant |
| **Date** | 2026-09-25 |

---

## 1. Modifications

### Step 1: `SystemConfiguration/Source/Apply-AllCustomizations.ps1`
- Line 222 (.bat): Replace `Get-Content -LiteralPath $Path -TotalCount 20 -Raw` with `(Get-Content -LiteralPath $Path -TotalCount 20 -ErrorAction SilentlyContinue) -join "`n"`.
- Line 229 (.cmd): Replace `Get-Content -LiteralPath $Path -TotalCount 20 -Raw` with `(Get-Content -LiteralPath $Path -TotalCount 20 -ErrorAction SilentlyContinue) -join "`n"`.
- Line 236 (.ps1): Replace `Get-Content -LiteralPath $Path -TotalCount 40 -Raw` with `(Get-Content -LiteralPath $Path -TotalCount 40 -ErrorAction SilentlyContinue) -join "`n"`.

### Step 2: `.lcm/tools/internal/Update-ToolCatalog.ps1`
- Line 981: Replace `Get-Content -LiteralPath $f.FullName -TotalCount 250 -Raw` with `(Get-Content -LiteralPath $f.FullName -TotalCount 250 -ErrorAction SilentlyContinue) -join "`n"`.

### Step 3: `.lcm/tools/internal/Flush-LcmLegacyLogs.ps1`
- Line 78: Replace `Get-Content -LiteralPath $Path -TotalCount 15 -Raw` with `(Get-Content -LiteralPath $Path -TotalCount 15 -ErrorAction SilentlyContinue) -join "`n"`.

---

## 2. Verification
1. Run syntax validation: `pwsh -NoProfile -Command "Get-Command -Syntax ..."` and AST parse on `Apply-AllCustomizations.ps1`.
2. Run `Apply-AllCustomizations.ps1 -WhatIf` or test step inspection to ensure step 2 resolves without parameter binding error.
3. Advance `BUG-172` to Gate 2 (Review).
