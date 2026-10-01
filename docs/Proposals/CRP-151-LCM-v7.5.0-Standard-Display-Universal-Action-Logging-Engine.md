# Proposal: CRP-151 Standard Display Universal Action Logging Engine & In-Browser Audit Drawer

## Metadata
- **Proposal ID**: `151`
- **Bundle ID**: `CRP-151`
- **Origin Repo**: `LCM_Inventory` (Global LCM Engine / All Governed Subsystems)
- **Target Components**:
  - `tools/assets/StandardTableDisplay.css`, `tools/assets/lcm-table-engine.js`
  - `.lcm/tools/internal/lcm_daemon.py` / REST Daemon (`:9876/log`)
  - `LCM_Shared/`, `HaSSD06_Inventory/`, `LCM_Inventory/`
- **Author**: Operator Directive / CRP Intake
- **Date**: 2026-09-19
- **Priority**: Normal (`N`)
- **Status**: Completed (`completed`)

---

## 1. Executive Summary & Intent
Establishes a universal, lightweight, zero-friction **Action Logging Architecture** across all interactive Standard Displays (HTML dashboards), PowerShell helpers, Python diagnostic scans, and scratch tools.

---

## 2. Technical Architecture & Component Design

### 2.1 Central Dispatch & UI Telemetry Funnel
- **JavaScript Telemetry Hook**: In `dispatchCommand(cmd, elevated)`, send an asynchronous background telemetry payload to local REST daemon (`POST http://127.0.0.1:9876/log`) recording:
  - Timestamp, Source Dashboard/View, Subsystem Name, Action Type, Target Device/Entity, Command string, User.
- **Protocol Fallback**: When dispatching via `lcm://` protocol handler, log invocation parameters automatically.

### 2.2 Reusable Logging Libraries
- **PowerShell (`RULE-PS-009`)**: Standardized logging integration in all helper scripts writing to `<RepoRoot>/logs/actions.log` and `.lcm/logs/actions.jsonl`.
- **Python Diagnostic Scripts**: Shared helper `from lcm_audit import log_action` recording deep scan parameters and target brand probes.
- **Scratch Scripts**: Log execution traces to `.lcm/logs/scratch_actions.log`.

### 2.3 In-Browser Action Log Drawer
- Add a dedicated **`📜 Action Log`** button in the Standard Display top-right header actions.
- Opens a slide-out drawer displaying chronological session actions, filterable by type, with `📋 Copy Log`, `📥 Export JSONL`, and `Show Last Log` deep links.

---

## 3. Storage Specification
- **Primary Machine-Readable Ledger**: `D:\Git_Repositories\.lcm\logs\actions.jsonl`
- **Human-Readable Subsystem Stream**: `D:\Git_Repositories\<Subsystem>_Inventory\logs\actions.log`

---

## 4. Verification & Quality Gates Plan
- Validate `/log` background REST ingestion.
- Test in-browser Action Log drawer in dark and light modes.
- Verify zero UI blocking / instant async dispatch.
- Ensure all quality gates pass across governed repositories.
