# Log Directory Redirector

> [!IMPORTANT]
> **This directory has been deprecated as of LCM V6.2.0 (CRP-2026-036).**

All log files previously written here have been migrated to the unified CM log store:

**New Canonical Location**: [`Workspace_Inventory/data/logs/`](file:///D:/Git_Repositories/Workspace_Inventory/data/logs/)

## Sub-directory Mapping

| Old Path | New Canonical Path |
| :--- | :--- |
| `Workspace_Inventory/logs/*.log` | `Workspace_Inventory/data/logs/` |
| `Workspace_Inventory/logs/history/` | `Workspace_Inventory/data/logs/history/` |
| `Workspace_Inventory/logs/backups/` | `Workspace_Inventory/data/logs/` (merged) |
| `.lcm/tools/internal/logs/` | `Workspace_Inventory/data/logs/lcm-internal/` |
| `tools/logs/` | `Workspace_Inventory/data/logs/` |

Tools that previously wrote to this directory must update their log path variable to:
```powershell
$logDir = 'D:\Git_Repositories\Workspace_Inventory\data\logs'
```
