# Change Request Proposal: CRP-330

```yaml
CRP-ID: CRP-330
Title: Tool Catalog Metadata Bleed Prevention and ExecutionPolicy Alignment
Scope: LCM_Inventory, LCM_Tools
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-14 13:10:00
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Prevent cross-domain tool metadata bleeding in `Update-ToolCatalog.ps1` caused by bare-filename caching in `$authoritativeCatalog`, and align duplicate `Set-MachineWideExecutionPolicy.ps1` implementations to the modernized v1.1.0 standard.

Currently, `Update-ToolCatalog.ps1` indexes the baseline catalog strictly by `$entry.Name` (`$fileName`). When identical script filenames exist across different domains (e.g. `SystemConfiguration\Source` and `LCM_Inventory\tools` / `LCM_Tools\tools`), disambiguated properties (such as `ShortName: "SystemConfigurationSetMachineWideExecutionPolicy"`) overwrite or bleed into unrelated entries.

Furthermore, `Set-MachineWideExecutionPolicy.ps1` in `LCM_Tools\tools` is an outdated v1.0.0 (57 lines) missing parameter handling and structured logging, while `SystemConfiguration\Source` hosts a modernized v1.1.0 (169 lines).

---

## 2. Gate 0 Contract

### Target State
1. **Keyed by Relative Path**: `Update-ToolCatalog.ps1` indexes `$authoritativeCatalog` primarily by normalized `RelativePath` (lowercase backslashes), falling back to filename only for unique, non-colliding names.
2. **Zero Cross-Domain Bleed**: Tools sharing identical filenames in different domains retain their domain-appropriate metadata, roles, and ShortNames without cross-contamination.
3. **Clean ExecutionPolicy Tool Definition**: `LCM_Inventory\tools\Set-MachineWideExecutionPolicy.ps1` has `ShortName: "SetMachineWideExecutionPolicy"` (or `LcmSetMachineWideExecutionPolicy`), removing the erroneous `SystemConfiguration` prefix.
4. **Standardized Implementation**: `LCM_Tools\tools\Set-MachineWideExecutionPolicy.ps1` is upgraded to the v1.1.0 implementation with full `-Policy`, `-ShowAll`, `-LogFile`, and `-h` help support.
5. **Dual-State Parity**: Regenerated `tool_catalog.json` is dual-state synced to `tools.db` and `tools.sql`.

### Invariants & Exit Criteria
- `tool_catalog.json` must validate cleanly against JSON schema rules (`JSON-RULES`).
- `Update-ToolCatalog.ps1` must execute without errors or unhandled exceptions.
- `tools.db` row count must match `tool_catalog.json` item count (320 items).
- All 6 duplicate tool filenames across the workspace must have domain-correct, distinct ShortNames and metadata.

### Explicit Non-Goals
- Altering the physical folder layout or deleting legitimate subsystem copies across repos.
- Renaming the underlying `.ps1` files on disk.

---

## 3. Technical Design & Implementation

### 3.1 `Update-ToolCatalog.ps1` Enhancements
1. **Primary Indexing by Path**:
   ```powershell
   # Primary index: normalized relative path
   if (-not [string]::IsNullOrWhiteSpace($entry.RelativePath)) {
     $normKey = $entry.RelativePath.Replace('/', '\').ToLowerInvariant()
     $authoritativeCatalogByPath[$normKey] = $entry
   }
   # Secondary tracking for unique names
   ```
2. **Lookup Precedence**:
   When resolving existing metadata for a scanned file:
   - Check `$authoritativeCatalogByPath[$normRel.ToLowerInvariant()]` first.
   - If not found, check `$authoritativeCatalogByName[$fileName]` ONLY if `$fileName` is unique (count == 1) in the catalog.
3. **Disambiguation Safety**:
   Ensure ShortName collision resolution produces deterministic names for both entries without mutating the stored metadata of the sibling entry.

### 3.2 `Set-MachineWideExecutionPolicy.ps1` Standardization
- Update `LCM_Tools/tools/Set-MachineWideExecutionPolicy.ps1` to v1.1.0.
- Update header comment to reflect LCM governance and proper relative paths.

---

## 4. Verification Plan
1. **AST & Syntax Gate**: Validate `Update-ToolCatalog.ps1` and `Set-MachineWideExecutionPolicy.ps1` with PowerShell AST parser (`RULE-PS-021`).
2. **Catalog Generation Run**: Execute `Update-ToolCatalog.ps1` and inspect the resulting entry for `LCM_Inventory\tools\Set-MachineWideExecutionPolicy.ps1`.
3. **Bleed Verification**: Verify with a Python audit script that no other tools suffer from cross-domain metadata bleeding.
4. **Database Parity**: Verify SQLite `tools.db` and `tool_catalog.json` row parity.
