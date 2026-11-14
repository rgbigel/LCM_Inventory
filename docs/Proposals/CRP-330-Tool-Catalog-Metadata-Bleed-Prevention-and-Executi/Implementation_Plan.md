# Implementation Plan: CRP-330

## Step 1: Update-ToolCatalog.ps1 Indexing Refactor
- Refactor lines 723-735 to populate `$authoritativeCatalogByPath` using normalized lowercase `RelativePath`.
- Populate a filename frequency table to allow safe fallback lookups for non-colliding files.
- Refactor lines 950-962 to lookup by normalized path first.

## Step 2: Set-MachineWideExecutionPolicy.ps1 Synchronization
- Synchronize `LCM_Tools/tools/Set-MachineWideExecutionPolicy.ps1` from v1.0.0 to v1.1.0.
- Ensure proper file header, version, and parameter structure conforming to `RULE-PS-008/009/010`.

## Step 3: Catalog Regeneration and Invalidation
- Run `Update-ToolCatalog.ps1` to re-generate `tool_catalog.json`.
- Validate entry for `LCM_Inventory\tools\Set-MachineWideExecutionPolicy.ps1`:
  - `ShortName`: `SetMachineWideExecutionPolicy`
  - `Group`: `LCM_Tools`
  - `Domain`: `LCM_Tools`
- Verify duplicate tools across repositories have correct, non-bleeding ShortNames.

## Step 4: Verification & Parity
- Run AST syntax validation.
- Verify `tools.db` and `tool_catalog.json` parity (320 rows/items).
