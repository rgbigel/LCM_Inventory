# Implementation Plan: CRP-309 (Master Implementation Plan)

```yaml
CRP-ID: CRP-309
Document: Implementation_Plan
Title: Unified Elevated Desktop Daemon, Universal Back Channel, Security Gateway, and Standard Interface Object Architecture
Scope: LCM_Inventory and governed display repositories
Baseline-Version: 10.0.1
Author: rgbig
Date: 2026-11-08 15:01:00
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: High
App-ID: APP-001
Supersedes: CRP-292, CRP-293, CRP-294, CRP-295, CRP-296, CRP-297, CRP-248, BUG-289
```

---

## 1. Executive Summary & Problem Context

This Master Implementation Plan consolidates the desktop daemon transport, administrative elevation, thin-client interfaces, UI feedback, security authorization gateway, and universal command dispatcher into a single, cohesive, verifiable workflow. It formally absorbs and supersedes `CRP-292` through `CRP-297`, `BUG-289`, and `CRP-248`.

---

## 2. Gate 0 Traceability Matrix

| Target State Clause | Implementation Component | Verification Artifact |
| :--- | :--- | :--- |
| **Clause 1**: Single Elevated Daemon Task | Component 1: `Register-LcmDesktopDaemon.ps1` | `Get-ScheduledTask LCM_DesktopDaemon` (`RunLevel: Highest`) |
| **Clause 2**: Universal Back Channel | Component 2: `DaemonActionController.ps1` (`ExecuteCommand`) | Pester synchronous stream redirection test |
| **Clause 3**: Thin-Client & Typed Routes | Component 3: `DaemonActionController.ps1` & UI controllers | Pester REST typed endpoint contract test |
| **Clause 4**: Rich Live Feedback Drawer | Component 4: `CM_CONTROL_HUB.html` & `lcm-tool-explorer.js` | Browser / Webview manual & DOM verification |
| **Clause 5**: Binding CORS & IDE Pane | Component 5: `LcmDisplayHttp.psm1` & `lcm-display-freshness.js` | HTTP header assertions (`Access-Control-Allow-Origin: *`) |
| **Clause 6**: JIT Ephemeral Token Gate | Component 6: `LcmTokenVault.psm1` | Pester token issuance, HMAC check, and burn test |
| **Clause 7**: Dispatcher Remediation | Component 7: `Invoke-InteractiveDesktop.ps1` | Interactive desktop launch test without short-circuit |
| **Clause 8**: Governance Switch Fix | Component 8: `CM_CONTROL_HUB.html` (`BUG-289`) | Real-time state reflection test |
| **Clause 9**: Universal Command Gateway & DTO | Component 9: `LCM_Inventory/Cmd/lcm.cmd` & `Invoke-LcmAction.ps1` | CLI execution tests (`lcm do <target>`) with output stream fidelity |
| **Clause 10**: Tiered Security Gateway & Audit | Component 10: `LcmSecurityGateway.psm1` | Security tier authorization tests and `security_gateway.log` receipt verification |

---

## 3. Proposed Changes

### Component 1: Elevated Scheduled Task Registration
* **Target:** `LCM_Inventory/tools/Register-LcmDesktopDaemon.ps1`
* **Changes:**
  * Configure `New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest`.
  * Ensure silent background launch at logon with auto-restart on unexpected exit.

### Component 2: Universal Back Channel & Process Redirection
* **Target:** `LCM_Inventory/modules/LcmDaemon/Classes/DaemonActionController.ps1`
* **Changes:**
  * Expand `ExecuteCommand`: When `req.Sync` is true, use `ProcessStartInfo` with UTF-8 stdout/stderr redirection.
  * Measure execution duration and return structured JSON (`status`, `exitCode`, `stdout`, `stderr`, `durationMs`).
  * When `req.Elevated` and `req.NoExit` are requested asynchronously, spawn visible Session 1 console with `-NoExit`.

### Component 3: Thin-Client Typed Controller Routes
* **Target:** `LCM_Inventory/tools/LcmDesktopDaemon.ps1` & `DaemonActionController.ps1`
* **Changes:**
  * Implement typed routes: `POST /api/tools/run`, `POST /api/proposal/action`, `POST /api/governance/mode`.
  * Strip raw command-string generation out of `lcm-tool-explorer.js` and `CM_CONTROL_HUB.html`.

### Component 4: Rich Live Execution Feedback Drawer
* **Target:** `LCM_Inventory/assets/CM_CONTROL_HUB.html` & `LCM_Inventory/assets/lcm-tool-explorer.js`
* **Changes:**
  * Add collapsible `<div class="execution-feedback-drawer">` with stdout/stderr display, duration badge, and exit code indicator.
  * Auto-expand on non-zero exit codes.

### Component 5: Binding CORS & IDE Webview Permissive CSP
* **Target:** `LCM_Inventory/modules/LcmDisplayHttp.psm1` & `LCM_Inventory/assets/lcm-display-freshness.js`
* **Changes:**
  * In `Send-LcmDisplayResponse`, emit standard CORS headers on all display responses.
  * Adjust CSP to `frame-ancestors 'self' vscode-webview:; connect-src 'self' http://127.0.0.1:* vscode-webview:;`.
  * In `lcm-display-freshness.js`, permit execution when running inside webview panes.
  * Add `-Pane` switch to `Show-ToolsExplorer.ps1` and `Show-LcmControl.ps1`.

### Component 6: JIT Ephemeral Token Security Gate
* **Target:** `LCM_Inventory/modules/LcmDaemon/Classes/LcmTokenVault.psm1`
* **Changes:**
  * Implement single-use HMAC-SHA256 token issuance and verification.
  * Enforce Quad-Principal ACL on token store (`Authenticated Users:(OI)(CI)F`, `SYSTEM:F`, `Administrators:F`).

### Component 7: Dispatcher Remediation
* **Target:** `LCM_Inventory/tools/Invoke-InteractiveDesktop.ps1`
* **Changes:**
  * Remove early short-circuit `$currentSessionId -ne 0`.
  * Prioritize Route A (`http://127.0.0.1:9876/open` and `/execute`) with robust try/catch fallback to Route B.

### Component 8: Governance Switch Reflection (`BUG-289`)
* **Target:** `LCM_Inventory/assets/CM_CONTROL_HUB.html`
* **Changes:**
  * Bind switch visual state strictly to backend `lcm_mode` returned by `/displays/data/hub`.
  * Suppress optimistic recoloring until backend confirmation.

### Component 9: Universal Command Gateway (`lcm.cmd` & `Invoke-LcmAction.ps1`)
* **Target:** `LCM_Inventory/Cmd/lcm.cmd` & `LCM_Inventory/tools/Invoke-LcmAction.ps1`
* **Changes:**
  * Implement unified CLI runner `lcm do <target> [flags/json]`.
  * Construct typed `LcmActionIntent` JSON DTO and post to `http://127.0.0.1:9876/api/action`.
  * Render synchronous output stream directly to the caller terminal with real exit code.
  * Plan progressive retirement of 140+ individual `.cmd` trampolines.

### Component 10: Central Security Authorization Gateway & Audit Trail
* **Target:** `LCM_Inventory/modules/LcmDaemon/Classes/LcmSecurityGateway.psm1`
* **Changes:**
  * Implement 3-tier capability authorization check before task dispatch (Tier 1 Public, Tier 2 Operator, Tier 3 Admin).
  * Require valid ephemeral token for Tier 3 mutations.
  * Implement persistent structured audit logging to `LCM_Inventory/data/logs/security_gateway.log`.

---

## 4. Verification Plan

### Automated Testing
* **New Test Suite:** `LCM_Inventory/tests/LcmElevatedDaemon.Tests.ps1`
  * Test 1: Pester test for CORS headers on `/tools`, `/hub`, and `/ping`.
  * Test 2: Pester test for synchronous stdout/stderr back-channel capture.
  * Test 3: Pester test for Ephemeral Token issuance, valid verification, and replay-attack rejection (burn on use).
  * Test 4: Pester test for typed controller endpoints (`POST /api/tools/run`).
  * Test 5: Pester test for `lcm do <target>` invocation with Interface Object serialization.
  * Test 6: Pester test for 3-tier Security Authorization and `security_gateway.log` audit receipt generation.
* **Existing Gate Verification:**
  * `pwsh LCM_Inventory/tests/LcmDisplayFreshness.Tests.ps1`
  * `pwsh LCM_Inventory/tools/Test-Guardrail.ps1 -Scan`

### Manual / Visual Inspection
* Launch `ShowTools -Pane` and verify it loads and functions inside the Antigravity IDE editor pane.
* Run an elevated tool from Tool Explorer and verify synchronous output displays cleanly in the UI drawer with zero UAC prompts.
* Execute `lcm do RestoreSettings -DryRun` from a regular PowerShell or CMD console and verify seamless execution, audit log entry, and stream fidelity.
