# CRP-213: LCM Index Integration for NTFS Queries via ES.exe and Action Atoms

```yaml
CRP-ID: CRP-213
Priority: 2
Scope: LCM Index Integration, ES.exe NTFS Queries, Action Atoms & Product Tools
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Affected-Repos:
  - LCM_AI
  - LCM_Inventory
  - Governed Repositories
```

## Memo Overview (Held for Later)

> [!NOTE]
> **Memo Status**: This CRP is registered as a placeholder memo for later implementation per operator direction. Detailed analysis is intentionally deferred until active lifecycle scheduling.

### Core Intent
1. **LCM Index Integration into Internal Handling**:
   - Leverage the availability of LCM's index (Everything / `es.exe`) across internal toolchains.
2. **NTFS Query Optimization Rule**:
   - Establish the rule that wherever possible, queries of NTFS file system information (folders, files, attributes, etc.) MUST be executed via `es.exe` instead of slower file system scanners or legacy tools (`gs.exe` / recursive scans).
3. **Phased Extension**:
   - **Phase 1**: Core NTFS file and attribute discovery via indexed queries.
   - **Phase 2**: Extend to concrete research and action "atoms" discovered by the IDE.
   - **Phase 3**: Extend indexed search integration to other product-tools across the workspace inventory.
