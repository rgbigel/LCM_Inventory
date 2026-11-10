---
Proposal-ID: CRP-146
Scope: HaSSD06_Inventory
Version: 10.2.0
Affected-Repos: [HaSSD06_Inventory, HaSSD06]
Priority: High
Status: Open
Target Scope: Subsystem Explorer Device and Entity Renaming Action Subpanels
---

# CRP-146: Device and Entity Renaming Action Subpanels with Pattern-Based Propagation

## 1. Problem Statement & Motivation
Managing large Home Assistant device fleets requires standardized naming conventions across physical devices, areas, and their underlying entity IDs and friendly names. Currently, renaming devices and entities requires manual interventions or direct YAML/storage edits. 

Operators require interactive action subpanels in the Subsystem Inventory Explorer to:
1. Trigger renames for Devices and Entities directly from table action buttons or bulk action menus.
2. Support configurable naming patterns (e.g., `<Area> <Device>`, `<Area> <Device> <EntityName>`, `<Domain>.<Area>_<Device>_<Measurement>`), mirroring Home Assistant's automatic entity renaming behavior.
3. Automatically propagate and cascade renames across all local inventory snapshots, automation references, script bindings, and dashboard definitions.

## 2. Proposed Enhancements
1. **Interactive Renaming Action Subpanels / Modals**:
   - Add a `✏️ Rename` action button to each row in the Devices and Live Entities tables.
   - Provide a flyout/modal subpanel with live preview of the proposed Device Name, Entity IDs, and Friendly Names before execution.
2. **Pattern-Based Renaming Engine**:
   - Support tokenized naming templates such as `<Area>`, `<Device>`, `<OriginalName>`, `<Domain>`, `<Measurement>`.
   - Provide bulk renaming tools allowing entire areas or device classes to be renamed systematically according to defined patterns.
3. **Automated Cross-Location Reference Cascade & Safe Updates**:
   - Identify and update references across automations, scripts, configuration YAML files, and inventory records.
   - Support staging renames via JIT ephemeral dispatch or PowerShell update scripts with pre-flight dry-run validation.
4. **Audit and Safety Controls**:
   - Back up existing state prior to mutation.
   - Enforce explicit confirmation for cascaded entity ID changes that affect automations and lovelace cards.

## 3. Impacted Assets
- [`HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1)
- [`HaSSD06_Inventory/tools/Update-HaInventory.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Update-HaInventory.ps1)
- [`HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html`](file:///d:/Git_Repositories/HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html)
- [`HaSSD06/tools/`](file:///d:/Git_Repositories/HaSSD06/tools/)
