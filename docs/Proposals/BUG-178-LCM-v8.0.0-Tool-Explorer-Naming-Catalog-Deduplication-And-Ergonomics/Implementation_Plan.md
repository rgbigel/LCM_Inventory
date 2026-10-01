# Implementation Plan: BUG-178

```yaml
BUG-ID: BUG-178
Title: Tool Explorer Approved Verb Naming, Catalog Deduplication, Self-Tool Filtering, and Scrollbar Hardening
Date: 2026-09-26
Status: Completed
```

---

## 1. Execution Steps

### Phase 1: Script & Trampoline Realignment
- [x] Create canonical `Show-ToolsExplorer.ps1` adhering to `RULE-PS-002` approved verb conventions.
- [x] Create companion forwarder `ToolsExplorer.ps1` for backward script invocation compatibility.
- [x] Establish `.lcm/Cmd/ToolExplorer.cmd`, `.lcm/Cmd/ToolsExplorer.cmd`, and `.lcm/Cmd/ShowTools.cmd` trampolines.

### Phase 2: Catalog Deduplication & Module Hardening
- [x] Physically delete obsolete `.lcm/tools/internal/tool_catalog.json` artifact.
- [x] Update candidate lookup paths in `LcmToolCatalog.psm1` to isolate authoritative config.
- [x] Correct fallback catalog path in `Sync-ToolSymlinks.ps1`.
- [x] Close missing `</tbody>` HTML tag in `LcmToolCatalog.psm1`.

### Phase 3: Metadata Overrides & Generator Sync
- [x] Register `Show-ToolsExplorer.ps1` in `$metadataOverrides` of `Update-ToolCatalog.ps1`.
- [x] Update `NoExit` whitelist in `Update-ToolCatalog.ps1`.
- [x] Execute `Update-ToolCatalog.ps1` to persist manifest and README.

### Phase 4: UI Ergonomics & Self-Tool Filtering
- [x] Implement self-tool exclusion filter in `lcm-tool-explorer.js` (both `.lcm/assets` and `LCM_Inventory/assets`).
- [x] Enforce `table { min-width: 1560px !important; }` in `LCMToolCatalog.css`.
- [x] Reconfigure horizontal scrollbar track and thumb styling for high visibility across WebKit and Gecko engines.

### Phase 5: Verification & Ledger Registration
- [x] Validate generation via `Show-ToolsExplorer.ps1 -NoLaunch`.
- [x] Register `BUG-178` in `proposals.json` and generate review receipt.
- [x] Dual-commit sync across governed repositories.
