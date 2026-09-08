# Change Request Proposal: Automated Privilege-Aware Tool Execution & Elevation Interception

- **Proposal ID**: `CRP-107`
- **Target Repository**: `LCM` (`Git_Repositories/.agents/rules`, `.lcm/modules`, `Workspace_Inventory`)
- **Target Version**: `v7.3.0`
- **Domain**: `Lifecycle Model (LCM) Security, Elevation & Tool Dispatch Governance`
- **Author**: Rolf, Workspace_AI Governance
- **Status**: `ACCEPTED` (Approved by Operator via PROCEED, Codified)
- **Created**: `2026-09-07 11:38:00`
- **Priority**: `HIGH`
- **Target Scope**: `.agents/rules/ElevationPolicy.md`, `PowerShellStandardsPolicy.md`, `.lcm/config/tool_catalog.json`
- **Affected Version Range**: `v7.0.0 - v7.3.0`
- **Impacted Repositories**: `Git_Repositories`, `Workspace_Inventory`

---

## 1. Objective & Operational Rationale

Ensure that any tool, script, or shorthand command requiring Windows Administrator privileges is never executed directly within a standard un-elevated user context. Instead, enforce automatic metadata discovery, runtime privilege inspection, and automated routing/interception through the background desktop daemon (`LcmDesktopDaemon.ps1` on Port 9876) or `gsudo` bridge.

### Operational Problem
When tools requiring administrative elevation (e.g. `Set-GitRoot.ps1`, `Restore-SystemSettings.ps1`, registry setters, disk formatters) are executed directly in standard non-elevated user shells or background agent runner processes:
1. **Partial Modification / Silent Degradation**: Scripts may silently fail or fall back to user-level registry/environment modifications (e.g. setting `Git_Root` at User scope instead of Machine scope).
2. **Cross-Session Elevation Hangs**: Background runners executing `Start-Process -Verb RunAs` hang indefinitely because Windows Session 0 / background process isolation prevents interactive UAC prompts from rendering on the user's interactive desktop (Session 1).
3. **Manual Escalation Friction**: Operators are forced to diagnose why a command failed, manually open elevated terminals, or construct custom REST payloads.

---

## 2. Normative Policy Addition: `RULE-ELEV-006`

This proposal formalizes `RULE-ELEV-006` to be codified into `.agents/rules/ElevationPolicy.md`:

### `RULE-ELEV-006` (Automated Privilege-Aware Tool Execution & Elevation Interception)
Before executing any tool, script, or shorthand command, the AI agent `MUST` perform the following deterministic validation sequence:

1. **Catalog & Schema Lookup**:
   - Query the authoritative tool catalog (`.lcm/config/tool_catalog.json` / `WorkspaceInventory`) to resolve the target tool's metadata record.
   - Inspect the execution profile to determine if `"Admin": true` (or equivalent elevation requirement flag).

2. **Context & Privilege Verification**:
   - Verify whether the current runtime shell session holds elevated administrative rights (e.g. `([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)`).

3. **Execution Routing & Interception**:
   - **Standard Execution**: If the tool does **not** require admin rights (`"Admin": false` or unset), execute it directly in the current session.
   - **Elevated Interception**: If `"Admin": true` and the current session is un-elevated:
     - The agent `MUST NOT` execute the script directly in the un-elevated context.
     - The agent `MUST` intercept the call and route execution through the established background desktop daemon bridge (`POST http://127.0.0.1:9876/execute` with `{ elevated: true, noExit: true }`) or `Invoke-InteractiveDesktop.ps1` / `gsudo`.
     - This guarantees the interactive UAC dialog renders in Session 1 and keeps the console window open upon completion per `RULE-ELEV-005`.

---

## 3. Implementation Plan Scope (On PROCEED)

Upon operator approval via `PROCEED CRP-107` or `PROCEED 107`:
1. **Rule Codification**:
   - Add `RULE-ELEV-006` to `.agents/rules/ElevationPolicy.md`.
   - Update `AGENTS.md` Quick-Reference index table and Cross-Reference Matrix.
2. **Tool Catalog Alignment**:
   - Audit `.lcm/config/tool_catalog.json` to ensure tools with administrative requirements (including `Set-GitRoot.ps1`) have `"Admin": true`.
3. **Dispatch & Interception Utilities**:
   - Ensure pre-flight check helper or agent dispatch routines cleanly route calls with `"Admin": true` to the Session 1 daemon bridge without blocking.

