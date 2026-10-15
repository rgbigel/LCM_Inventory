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
