# Bug Defect Specification: BUG-159
# CM Control Hub Real-Time Command Execution Output Capture & Automatic Ledger Re-Query Refresh

| Metadata Field | Value |
| :--- | :--- |
| **Defect ID** | `BUG-159` |
| **Lifecycle State** | `OPEN` (Registered via Strict Intake Gate per `RULE-LCM-015`) |
| **Origin Repository** | `LCM_Inventory` |
| **Target Scope** | CM Control Hub & Desktop Daemon Bridge (`LCM_Inventory/assets/CM_CONTROL_HUB.html`, `.lcm/modules/LcmDaemon/Classes/DaemonActionController.ps1`, `.lcm/tools/internal/LcmDesktopDaemon.ps1`, `LCM_Inventory/tools/Show-CmControlHub.ps1`) |
| **Author** | Rolf, LCM_AI Intake |
| **Date** | 2026-09-19 |
| **Version Impact** | `v7.0.3` |
| **Severity** | High (Operational Visibility & UI Synchronization Defect) |

---

## 1. Problem Statement & Root-Cause Analysis

### Observed Defect Behavior
When executing lifecycle commands (such as `proceed <id>`, `do <id>`, `verify <id>`, `complete <id>`, `priority <id>`, `status <id> <state>`) from the **CM Control Hub Console**:
1. **Monolithic Placeholder Output in Response Feed**:
   - The Response Feed only displays a static, uninformative one-liner (e.g. `[OK] Proceeded CRP(s) 121 along lifecycle pipeline.`).
   - The rich structured output produced by `Invoke-ProposalAction.ps1` (such as the target status reached, transition history, updated table rows, error warnings, or blocking diagnostics) is completely hidden from the operator.
2. **Missing UI Table / Metrics Refresh**:
   - The Control Hub UI does not automatically refresh its state from `proposals.json` after command execution finishes.
   - The table only showed optimistic in-memory edits that did not survive page reloads or reflect backend server truth, requiring manual browser restarts or CLI script recompilations.
3. **Silent Failure & Error Swallowing**:
   - If an underlying PowerShell script fails or throws an exception, the daemon fire-and-forget execution hides the error, and the Control Hub misleadingly reports `[OK]`.

### Root Cause
- In [`.lcm/modules/LcmDaemon/Classes/DaemonActionController.ps1`](file:///D:/Git_Repositories/.lcm/modules/LcmDaemon/Classes/DaemonActionController.ps1), the `/execute` route dispatches processes asynchronously via `Start-Process` without capturing stdout, stderr, or process exit codes for CLI management commands.
- In [`LCM_Inventory/assets/CM_CONTROL_HUB.html`](file:///D:/Git_Repositories/LCM_Inventory/assets/CM_CONTROL_HUB.html), the console command handlers send a fire-and-forget fetch to `/execute` and immediately append a hardcoded message, without awaiting the process result, displaying stdout/stderr, or calling `GET /proposals` to dynamically reload the updated proposal store.

---

## 2. Proposed Architectural Solution & Implementation Scope

### 2.1 Synchronous Output-Capturing Daemon Route (`/execute` & `sync: true`)
1. Update `DaemonActionController.ps1` and `LcmDesktopDaemon.ps1` to support synchronous command execution when requested (`sync: true` or dedicated management execution):
   - Executes the command capturing `stdout`, `stderr`, and `ExitCode`.
   - Returns JSON payload:
     ```json
     {
       "status": "COMPLETED",
       "exitCode": 0,
       "stdout": "...",
       "stderr": "..."
     }
     ```
   - If execution fails or non-zero exit code occurs, returns:
     ```json
     {
       "status": "ERROR",
       "exitCode": 1,
       "stdout": "...",
       "stderr": "..."
     }
     ```

### 2.2 CM Control Hub Console Output Engine
1. Update [`CM_CONTROL_HUB.html`](file:///D:/Git_Repositories/LCM_Inventory/assets/CM_CONTROL_HUB.html) command handler:
   - Await execution response from `http://127.0.0.1:9876/execute` with `sync: true`.
   - Ingest `stdout` and format it in the **Response Feed** console (preserving structured ASCII tables and colorizing status tags).
   - If `stderr` is present or `exitCode !== 0`, render the error lines in `msg-err` (red) with full problem diagnostics.
   - Explicitly highlight the **Target Status Reached** (e.g. `[STATUS] CRP-121 -> in_progress`).

### 2.3 Automatic Post-Command Dynamic Re-Query & UI Refresh
1. Immediately upon command completion:
   - Call `GET http://127.0.0.1:9876/proposals` to fetch the authoritative, live `proposals.json` from disk.
   - Update `proposalsData` in-memory store.
   - Trigger `updateMetricCards()`, `updateHeaderGovernanceBadges()`, and `renderTable()`.
   - Update live ticker banner with exact reached status and timestamp.

---

## 3. Verification Plan

| Check | Expected Result |
| :--- | :--- |
| **Command Execution Output** | Running `proceed 121` in Control Hub console displays the full PowerShell output table and reached status in Response Feed. |
| **Error / Problem Visibility** | Running an invalid command or targeting a non-existent CRP displays red error diagnostics in Response Feed without swallowing errors. |
| **Auto-Refresh** | Proposals table, metric cards, and filter badges update immediately after command execution without page reload. |
| **Persistence Sync** | Refreshing browser tab retains updated status loaded directly from `proposals.json`. |

---

## 4. Lifecycle Intake State

> [!NOTE]
> Registered in **`OPEN`** state per `RULE-LCM-015`. Awaiting explicit operator activation (`PROCEED 159`) before implementation planning and execution.
