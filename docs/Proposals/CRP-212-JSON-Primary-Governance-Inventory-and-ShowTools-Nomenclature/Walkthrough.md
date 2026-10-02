# Walkthrough: CRP-212

## Intake & Checkpoint Record

- **Proposal**: CRP-212
- **Title**: JSON-Primary Governance Inventory and ShowTools Nomenclature Reconciliation
- **Priority**: 8
- **Status**: Suggested (Gate 1 Checkpoint)
- **Origin Repository**: `LCM_Inventory`
- **Impacted Repositories**: `LCM_Inventory`, `LCM_AI`, `LCM_Tools`

### Summary of Decisions
1. **JSON Primary Source**: Machine-readable data in `LCM_Inventory/data/` is the single source of truth; markdown serves as rendered presentation.
2. **Command Primacy**: `ShowTools` reinstated as the primary command; `ToolsExplorer` retained as alias.
3. **Living Session History**: `.agents/ACTIVE_SESSION.md` is committed and pushed in `LCM_AI`.
4. **Deferral Handling**: Controls labeled `"Available in a later lifecycle-action release"` are deferred from batch execution.
