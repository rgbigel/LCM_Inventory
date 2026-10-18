# Walkthrough: CRP-278 - GoodNIGHT Save-All Receipt and GoodMorning Recovery Gate

## 1. Origin

CRP-278 was split from CRP-277 on 2026-10-15 so the accepted Macrium/Beyond
Compare baseline implementation could complete without claiming that GoodNIGHT
receipt/recovery behavior already existed.

## 2. Initial Verification State

- No durable GoodNIGHT Save All receipt currently exists.
- `Invoke-WorkspaceGoodMorning.ps1` reports session context but does not
  certify a GoodNIGHT receipt.
- The existing GoodMorning behavior must be retained while the receipt gate is
  implemented and tested.

## 3. Delivered Recovery Gate

- Added `modules\GoodNightReceipt.psm1` with a versioned JSON receipt contract
  and explicit state classification.
- Added `-SaveAllConfirmed` to GoodNight. Without that acknowledgement,
  GoodNight writes no receipt and warns that the next GoodMorning check will
  require recovery.
- Added receipt validation to GoodMorning before its automatic short-gap
  return. A non-valid receipt is now an attention item with the precise
  remediation command.

## 4. Verification Evidence

- `GoodNightReceipt.Tests.ps1`: 2 passed, 0 failed.
- PowerShell AST parsing: passed for `GoodNightReceipt.psm1`,
  `Invoke-WorkspaceGoodMorning.ps1`, and
  `Invoke-WorkspaceGoodNight.ps1`.
- `Test-WorkspaceReadiness.ps1`: completed with `OK` results.
