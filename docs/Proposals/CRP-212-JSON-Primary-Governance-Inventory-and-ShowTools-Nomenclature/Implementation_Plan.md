# Implementation Plan: CRP-212

## Phase 1: Command Trampoline & Catalog Alignment
1. Verify `.lcm/Cmd/ShowTools.cmd` is the primary entrypoint and `.lcm/config/tool_catalog.json` designates `ShowTools` as the primary command.
2. Ensure `ToolsExplorer.cmd` acts as a clean backward-compatible alias.
3. Update `macro-definitions.md` and `AGENTS.md` indexing `ShowTools` as canonical.

## Phase 2: JSON-Primary Schema Verification
1. Ensure `LCM_Inventory/data/inventory.json` remains the authoritative source for all repository classifications and junction deployments.
2. Validate that `Show-RepositoryInventory.ps1` or related viewers derive presentation from JSON.

## Phase 3: Session State Verification
1. Verify `git status` in `LCM_AI` recognizes `.agents/ACTIVE_SESSION.md` and `ACTIVE_CONTEXT.md` as tracked/stageable files without `.gitignore` suppression.
2. Document the deferral rule for `"Available in a later lifecycle-action release"` controls.
