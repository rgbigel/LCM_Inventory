# Change Request Proposal: CRP-309

```yaml
CRP-ID: CRP-309
Title: Unified Elevated Desktop Daemon, Universal Back Channel, and Binding CORS Display Architecture
Scope: LCM_Inventory
Baseline-Version: 10.0.1
Author: rgbig
Date: 2026-11-07 16:56:06
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent

Consolidate desktop daemon and elevated task execution into a single, unified, high-performance daemon on **Port 9876** running with `-RunLevel Highest` under the active user account. 
This proposal achieves three core architectural objectives:
1. **Binding CORS & IDE Pane Hosting Parity**: Enforces binding `Access-Control-Allow-Origin: *`, `Access-Control-Allow-Methods`, and `Access-Control-Allow-Private-Network` headers across all Port 9876 Standard Displays and static assets in [`LcmDisplayHttp.psm1`](file:///d:/Git_Repositories/LCM_Inventory/modules/LcmDisplayHttp.psm1), enabling reliable embedded Antigravity IDE pane hosting (`ShowTools -Pane`) alongside existing external browser launches.
2. **Universal Synchronous Back Channel**: Enables synchronous `stdout`, `stderr`, and `exitCode` capture for all commands (elevated and un-elevated alike) over HTTP JSON responses, eliminating the previous fire-and-forget limitation of `Start-Process -Verb RunAs`.
3. **Just-In-Time (JIT) Ephemeral Token Security Gate**: Protects privileged mutation endpoints (`POST /execute`) with a 30-second single-use HMAC-SHA256 command-bound token, adhering to the workspace's authoritative **Quad-Principal `Authenticated Users` (Universal SID S-1-5-11) multi-boot ACL standard**.
4. **Interactive Dispatch Hygiene**: Eliminates the premature `$currentSessionId -ne 0` short-circuit in [`Invoke-InteractiveDesktop.ps1`](file:///d:/Git_Repositories/LCM_Inventory/tools/Invoke-InteractiveDesktop.ps1), establishing proper REST daemon dispatch prioritization with try/catch fallback.

---

## 2. Gate 0 Contract

### Target State
1. A single Windows Scheduled Task (`LCM_DesktopDaemon`) runs `LcmDesktopDaemon.ps1` at user logon with `-RunLevel Highest` on `127.0.0.1:9876`.
2. All HTTP responses from Port 9876 (both REST endpoints and Standard Display routes) consistently return standard CORS headers (`Access-Control-Allow-Origin: *`, `Access-Control-Allow-Private-Network: true`).
3. Calling `ShowTools -Pane` or opening Standard Displays in an IDE webview / Simple Browser pane functions interactively without CORS or Content-Security-Policy connection errors.
4. `POST http://127.0.0.1:9876/execute` supports `{ "command": "...", "elevated": true, "sync": true }` and returns synchronous `stdout`, `stderr`, and `exitCode` across the HTTP socket without triggering interactive Windows UAC prompts.
5. Privileged command execution requires a valid, single-use, 30-second TTL ephemeral token bound to the command hash.
6. Token and cache directories conform to the Quad-Principal `Authenticated Users:(OI)(CI)F` multi-boot standard.

### Invariants and Exit Criteria
* **RULE-ELEV-005 Compliance**: Spawning interactive elevated consoles continues to enforce `-NoExit` / `/k` so operator output remains visible.
* **RULE-DSP-008 Compliance**: Displays remain container-agnostic, supporting both external browser windows and IDE pane embedding seamlessly.
* **CRP-305 Compliance**: The browser communicates exclusively via `http://127.0.0.1:9876`; no secondary ports or local-file fallbacks.
* **Zero UAC Interruption**: Automated and background agent tool executions route through the pre-authorized elevated daemon without blocking on manual UAC confirmation dialogs.

### Explicit Non-Goals
* No external or remote network binding: the daemon remains strictly bound to `127.0.0.1` (loopback).
* No multi-port daemon fragmentation: no secondary daemon on Port 9877.
* No changes to underlying tool execution semantics or core repository business logic.

---

## 3. Technical Requirements & Invariants

### Clause 1: Binding CORS and CSP Alignment in Standard Display Subsystem
* In `modules/LcmDisplayHttp.psm1`, update `Send-LcmDisplayResponse` to emit:
  * `Access-Control-Allow-Origin: *`
  * `Access-Control-Allow-Methods: GET, POST, OPTIONS`
  * `Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Private-Network`
  * `Access-Control-Allow-Private-Network: true`
* Update Content-Security-Policy to allow frame ancestry and connection from IDE webview containers (`frame-ancestors 'self' vscode-webview:; connect-src 'self' http://127.0.0.1:* vscode-webview:;`).
* Update `assets/lcm-display-freshness.js` to permit execution within IDE pane environments while verifying Port 9876 delivery.

### Clause 2: Single Elevated Daemon Task Architecture
* Reconfigure `Register-LcmDesktopDaemon.ps1` to register `LCM_DesktopDaemon` with:
  * `Principal`: `$env:USERNAME`
  * `RunLevel`: `Highest`
  * `LogonType`: `Interactive`
* Because the daemon runs with administrative privileges in Session 1, it can execute both standard and administrative commands directly.

### Clause 3: Universal Back Channel for Privileged and Standard Tasks
* Update `DaemonActionController.ps1` (`ExecuteCommand`):
  * When `req.Sync` is `$true`, execute via synchronous process redirection (`RedirectStandardOutput = $true`, `RedirectStandardError = $true`), returning full streams and exit code.
  * When `req.Sync` is `$false` and `req.Elevated` is `$true` with `req.NoExit`, dispatch a visible elevated console to Session 1 per `RULE-ELEV-005`.

### Clause 4: Ephemeral Token Security Gate
* Implement `LcmTokenVault.psm1`:
  * JIT generation of 32-byte cryptographic nonce.
  * Command signature: `HMAC-SHA256(Nonce, Command)`.
  * TTL: 30 seconds.
  * Single-use burn on verification.
  * Token store directory: `LCM_Inventory/data/tokens/` governed by Quad-Principal ACL (`Authenticated Users:(OI)(CI)F`, `SYSTEM:F`, `Administrators:F`).

### Clause 5: Dispatcher Remediation (`Invoke-InteractiveDesktop.ps1`)
* Remove the premature short-circuit on `$currentSessionId -ne 0` that prevented routing to Port 9876.
* Enforce Route A (Port 9876 REST `/open` and `/execute`) as the primary path, wrapped in robust try/catch with fallback to Route B (Task Scheduler).
