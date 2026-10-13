# Change Request Proposal: CRP-118
# Automated Privilege-Aware Tool Execution CLI Interceptor Engine

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-118` |
| **Lifecycle State** | `COMPLETED` (Accepted by Operator) |
| **Origin Repository** | `LCM` / Execution & Elevation Governance |
| **Target Scope** | CLI & Agent Execution Layer (`LCM_Inventory/tools/Invoke-PrivilegedTool.ps1`, `Invoke-InteractiveDesktop.ps1`, `Update-ToolCatalog.ps1`, `LCM_Inventory/Cmd/*.cmd`, `.agents/rules/ElevationPolicy.md`) |
| **Author** | Rolf, LCM_AI |
| **Date** | 2026-10-13 (Completed: 2026-10-13) |
| **Version Impact** | `10.0.0` |
| **Related Proposals** | `CRP-107` (`CRP-2026-024`), `CRP-116` (`CRP-2026-030`), `CRP-117` (`CRP-2026-031`), `CRP-158` |

---

## 1. Executive Summary & Problem Statement

In **`CRP-107` (`CRP-2026-024`)**, the workspace established **[`RULE-ELEV-006`](file:///D:/Git_Repositories/.agents/rules/ElevationPolicy.md#L61-L73)**, mandating that any tool or script requiring administrative elevation (`"Admin": true`) must never be executed directly within an un-elevated user shell, but must instead be automatically intercepted and routed through the Session 1 Desktop Daemon bridge (`http://127.0.0.1:9876/execute`) or `Invoke-InteractiveDesktop.ps1`.

### The Implementation Gap
While the **Web Tool Explorer UI** (`lcm-tool-explorer.js`) enforces this policy when users click tools in the browser, the **CLI and AI Agent execution layer** lacks an automated pre-flight interception mechanism:
1. **Un-elevated Agent Execution**: When an AI agent (or operator in a standard terminal) executes an admin-required tool (such as `Set-GitRoot.ps1`, `Restore-SystemSettings.ps1`, `KillLogitechUpdate.ps1`, or `Repair-VolumeAcl.ps1`), the command runs directly in the current un-elevated process.
2. **Partial Degradation & Silent Invariant Failure**: Scripts attempting registry or environment variable updates (e.g. `Set-GitRoot.ps1`) fall back to user-level modifications or fail with access-denied errors without operator notice.
3. **Session 0 Hangs**: When `.cmd` trampolines attempt inline `Start-Process -Verb RunAs`, background agent tasks hang indefinitely because Windows Session 0/non-interactive isolation prevents UAC elevation prompts from appearing.

**Goal**: Close this gap by providing an automated, deterministic CLI and agent interception utility (`Invoke-PrivilegedTool.ps1`) and updating trampoline compiler logic so that `RULE-ELEV-006` is 100% enforced across CLI, terminal, and agent execution paths.

---

## 2. Architecture & Implementation Scope

### 2.1 Reusable CLI & Agent Dispatch Engine (`Invoke-PrivilegedTool.ps1`)
Standardized PowerShell dispatcher in `LCM_Inventory/tools/Invoke-PrivilegedTool.ps1`:
```powershell
pwsh LCM_Inventory/tools/Invoke-PrivilegedTool.ps1 -Tool <NameOrShortName> [-Arguments <string>] [-NoExit] [-DryRun] [-Force]
```
**Execution Sequence**:
1. **Catalog Lookup**: Queries `LCM_Inventory/config/tool_catalog.json` to resolve tool metadata and inspect whether `"Admin": true`. Includes word-token fuzzy matching and alias lookup.
2. **Privilege Inspection**: Evaluates whether the current shell process holds administrator rights via `WindowsPrincipal.IsInRole([WindowsBuiltInRole]::Administrator)`.
3. **Deterministic Routing**:
   - **Case A (`Admin: false` or already elevated)**: Invokes the target script directly in-process with passed arguments.
   - **Case B (`Admin: true` and un-elevated)**:
     - Outputs the structured `RULE-ELEV-005` pre-launch notice (Timestamp, Target, Elevation Mode, Log Path).
     - Dispatches execution to the Session 1 Desktop Daemon (`POST http://127.0.0.1:9876/execute` with `{ "command": "<cmd>", "elevated": true, "noExit": true }`).
     - Falls back to `Invoke-InteractiveDesktop.ps1 -Elevated` if the daemon is offline.
     - Never hangs on Session 0 UAC prompts.

### 2.2 Trampoline `.cmd` Interception Alignment
Updated trampoline generation logic in [Update-ToolCatalog.ps1](file:///D:/Git_Repositories/LCM_Inventory/tools/Update-ToolCatalog.ps1):
- For tools marked `"Admin": true`, generated batch trampolines check `net session >nul 2>&1`. If un-elevated, they delegate directly to `Invoke-PrivilegedTool.ps1 -Tool <ShortName> -Arguments "%*"` and exit cleanly.

### 2.3 Agent Operational Rule Integration
- Updated [`.agents/rules/ElevationPolicy.md`](file:///D:/Git_Repositories/.agents/rules/ElevationPolicy.md) to explicitly codify `Invoke-PrivilegedTool.ps1` and trampoline routing under `RULE-ELEV-006`.

---

## 3. Invariant & Governance Verification Plan

| Invariant / Check | Expected Behavior | Verification Method |
| :--- | :--- | :--- |
| **`RULE-ELEV-006` Enforcement** | Standard shell running `Invoke-PrivilegedTool -Tool SetGitRoot` routes to Port 9876 with `elevated: true`. | Dry-run in un-elevated terminal; verify Session 1 UAC trigger and log entry. |
| **Non-Admin Tool Passthrough** | Running a standard tool (e.g. `Show-Rules.ps1`) runs directly in-process without daemon overhead. | Execute `Invoke-PrivilegedTool -Tool ShowRules` and confirm direct in-process execution. |
| **`RULE-ELEV-005` Compliance** | Spawned elevated console includes `-NoExit` so logs remain visible to operator. | Verify window remains open upon execution completion. |
| **Last-Alias & Catalog Safety** | Preserves existing catalog metadata and short-name trampolines. | Run `Update-ToolCatalog.ps1` and verify 0 regressions. |

---

## 4. Current State & Verification Delivery

> [!NOTE]
> **Delivery Status**: Implementation completed and verified. Transitioned to **`VERIFICATION`** state awaiting formal Beyond Compare Review (BCR) operator disposition.

