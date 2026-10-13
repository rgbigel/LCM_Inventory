---
Proposal-ID: BUG-113
CR-ID: BUG-113
Scope: LCM / Security, Elevation & Environment Management
Version: 10.0.0
Affected-Repos: [LCM, LCM_AI, LCM_Inventory]
Status: OPEN
Date: 2026-10-13
Author: rgbig
Target Scope: Environment Variable Configuration Tools, Elevation Interceptors, Admin Policy (LCM_Inventory/tools/Set-SystemEnvironment.ps1, LCM_Inventory/tools/Invoke-ElevatedCommand.ps1, ElevationPolicy.md)
Affected Version Range: 10.0.0
Impacted Repositories: [LCM, LCM_AI, LCM_Inventory]
Severity: High
---

# BUG-113 / BUG-113: Admin Elevation Gating and Process Restart Notification for System Environment Variables

## 1. Defect Description & Discovery Vector
1. **Improper Privilege Level for Machine-Level Environment Variables**:
   Modifying `Git_Root` (and similar environment variables) at the Machine / System Level (`[EnvironmentVariableTarget]::Machine` / `HKLM:\System\CurrentControlSet\Control\Session Manager\Environment`) is mistakenly treated or executed as a standard User-level command rather than requiring Administrator elevation. Under Windows access controls, non-elevated processes cannot write to Machine environment registry paths, leading to silent failures, fallback to User scope (`HKCU`), or permission errors.
2. **Missing Process Propagation & Restart Notice (including Antigravity IDE)**:
   Even when successfully committed to the system registry, changes to Machine or User environment variables are not retroactively applied to already-running processes (e.g. running PowerShell terminals, CMD shells, background daemons, Windows Explorer, or Antigravity IDE itself). Currently, the system does not inform the user that dependent processes, Explorer, or Antigravity must be restarted for the newly set environment variable to take effect.

## 2. Root Cause Analysis
- **Missing Admin Elevation Interception**: Per `RULE-ELEV-001` through `RULE-ELEV-006` (Elevation Policy), commands modifying Machine-level configuration must be intercepted and elevated to an administrator context.
- **Process Environment Isolation Invariant**: Windows processes inherit their environment block from their parent process at spawn time. While broadcasting `WM_SETTINGCHANGE` (with lParam `"Environment"`) updates Explorer and newly launched applications, running processes (such as Antigravity, active shells, and daemon processes) do not update their in-memory environment table without an explicit restart.
- **Lack of Operator Advisory Banner**: No prompt or advisory is emitted warning the operator that dependent processes (specifically Antigravity, active terminals, and Explorer) must be restarted before the new variable becomes active.

## 3. Remediation Strategy (Proposed)
1. **Strict Admin Elevation Gating**:
   - Enforce Administrator elevation when targeting `[EnvironmentVariableTarget]::Machine` or system-wide settings.
   - Route through the elevated dispatcher (`Invoke-ElevatedTest.ps1` / elevation interceptor per `RULE-ELEV-004`).
2. **Process Restart & Explorer Refresh Notification**:
   - Automatically broadcast `WM_SETTINGCHANGE` with `HWND_BROADCAST` to signal Explorer and the Windows shell.
   - Output an explicit high-visibility warning banner in Chat, Terminal, and Dashboard:
     > [!WARNING]
     > **Process Restart Required**: Environment variable changes (e.g. `Git_Root`) will NOT take effect in already running processes. You MUST restart:
     > 1. **Antigravity IDE**
     > 2. **Active Terminal / PowerShell Sessions**
     > 3. **Windows Explorer** (or sign out / sign back in)
3. **Automated Verification**:
   - Verify that Machine-level modifications prompt for elevation or execute via elevated runner.
   - Verify that the restart notification is reliably emitted across all CLI and dashboard dispatch vectors.

> [!IMPORTANT]
> **Awaiting Operator Authorization**: Per `RULE-LCM-015` and `RULE-LCM-016`, this bug proposal is registered in the `OPEN` state. Detailed implementation planning and code modifications remain suspended until an explicit `PROCEED 113` or `PROCEED ALL` command is received.

