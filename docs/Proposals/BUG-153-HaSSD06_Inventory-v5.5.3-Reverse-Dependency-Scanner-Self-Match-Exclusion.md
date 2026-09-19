# Proposal: BUG-153 Reverse-Dependency Scanner Self-Match Exclusion for Automations and Scripts

## Metadata
- **Proposal ID**: `153`
- **Bundle ID**: `BUG-153`
- **Origin Repo**: `HaSSD06_Inventory`
- **Target Component**: [`HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1), [`HaSSD06_Inventory/tools/Invoke-HaRenameCascade.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Invoke-HaRenameCascade.ps1)
- **Author**: Operator Directive / BUG Intake
- **Date**: 2026-09-19
- **Priority**: High (`H`)
- **Status**: Completed

---

## 1. Problem Statement & Root Cause
When an operator initiates a rename or delete inspection for an automation or script (e.g. `script.confirmable_notification` or `automation.zone_notification`), the Reverse-Dependency Reference Scanner incorrectly includes the item itself as an impacted dependency.

### Root Cause
1. In `Show-HaInventoryApp.ps1`:
   - `countEntityReferences(entityId)` iterated through `automations_catalog`, `scripts_catalog`, and `helpers_and_virtual` without checking `if (a.entity === entityId) return;` or `if (s.entity === entityId) return;`. Because the script/automation's own `entity` string matches `entityId`, the counter incremented to `1`.
   - `scanEntityReverseDependencies(entityId)` pushed a match for the entity itself into the impacted dependency list.
   - In `openAutomationDeleteModal`, `countEntityReferences` caused a false positive warning: *"⚠️ 1 active reference(s) found! Please verify before deleting."* on unreferenced items.
2. In `Invoke-HaRenameCascade.ps1`:
   - In the reverse dependency scan loops (lines 282-325), `if ($auto.entity -match $oe)` matched `$auto.entity` against `$oe` even when `$auto.entity` was the target being renamed.

---

## 2. Proposed Changes & Specifications

### 2.1 Self-Match Exclusion in `Show-HaInventoryApp.ps1`
- In `countEntityReferences(entityId)`:
  - Add `if (a.entity === entityId) return;`
  - Add `if (s.entity === entityId) return;`
  - Add `if (h.entity === entityId) return;`
- In `scanEntityReverseDependencies(entityId)`:
  - Add strict self-exclusion: `if (a.entity === entityId) return;`, `if (s.entity === entityId) return;`, `if (h.entity === entityId) return;`.
- In `scanDeviceReverseDependencies(devName, childEids)`:
  - Exclude self-references where `a.entity === eid`, `s.entity === eid`, `h.entity === eid`.

### 2.2 Self-Match Exclusion in `Invoke-HaRenameCascade.ps1`
- In reverse dependency scanning loops:
  - Add `if ($auto.entity -eq $oe) { continue }`
  - Add `if ($scr.entity -eq $oe) { continue }`
  - Add `if ($hlp.entity -eq $oe) { continue }`

### 2.3 Deep Link Optimization for Automations & Scripts
- In `openEntityRenameModal(entityId)`:
  - Route deep links to `/config/automation/dashboard` or `/config/script/dashboard` when renaming an automation or script, rather than the generic entity registry page.

---

## 3. Verification Plan
1. **Automated Quality Gates**:
   - Execute `pwsh tools/Test-RepoReadiness.ps1` in `HaSSD06_Inventory` (5/5 Quality Gates passing).
2. **Dashboard Recompilation**:
   - Run `pwsh tools/Show-HaInventoryApp.ps1 -NoLaunch` to compile `SHOW_HA_INVENTORY.html` and `Entities_Inventory_HaSSD06.html`.
3. **Modal Verification**:
   - Inspect renaming and deletion modals for `script.confirmable_notification` — verify 0 dependencies / clean state is reported.
