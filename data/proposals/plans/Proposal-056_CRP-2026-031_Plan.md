# Implementation Plan - Proposal #56 (CRP-2026-031): Autonomous Loop-Fencing, Execution Boundaries, and T0 State Recovery Engine

- **Proposal ID**: `#56`
- **CR ID**: `CRP-2026-031`
- **Target Systems**: `Antigravity IDE` / `LCM Runtime Environment` / `LCM Backup` (Privileged Subsystem)
- **Governance Tier**: `T2 (Standard Architecture)`
- **Governance State**: `approved`
- **Progress State**: `queued`
- **Author**: Technical Engineering & Governance Team
- **Date**: 2026-09-02

---

## 1. Executive Summary & Subsystem Architecture

Proposal #56 establishes deterministic runtime guardrails for autonomous agent tool execution, prevents unhandled token exhaustion and cyclic spinning, and bootstraps the privileged companion subsystem repository: **`LCM Backup`**.

### Subsystem Governance Principles (Privileged Subsystem Standard)
1. **Decoupling & Baseline Governance**:
   - Built strictly upon absorbed, authoritative baseline LCM rules (`.agents/rules/`).
   - Completely decoupled from external unabsorbed proposals (no dependency on draft "Augmentation V1.1" or `Workspace_NG2`).
   - Adheres to the **AADR (Architecture / Agile Design & Requirements)** documentation taxonomy.
2. **Repository Scope**: `LCM Backup` (`D:\Git_Repositories\LCM_Backup`) hosts its own domain tools, engine scripts, test harnesses, and documentation structure.
3. **Rule Propagation**: Core LCM governance rules (`.agents/rules/`) propagate deterministically to `LCM Backup` via standard NTFS junction.
4. **CM Centralization**: Change management, proposals, review records, and lifecycle auditing remain strictly centralized in `Workspace_Inventory`.
5. **Data Placement & Ledger Isolation**: All telemetry, state data, backup manifests, recovery indexes, and payloads reside centrally within `Workspace_Inventory` (`Workspace_Inventory/data/backups/`, `Workspace_Inventory/logs/backups/`), eliminating local scattering.
6. **LCM Extensibility**: The primary `.lcm` platform recognizes and integrates `LCM Backup` as an authoritative tool extension provider via `tool_catalog.json` and `.lcm\Cmd\` trampolines.
7. **Windows Task Governance via `Workspace_Supervision`**: Whenever `LCM_Backup` utilizes Windows Scheduled Tasks (especially for LCM Events, state capture triggers, or inter-tool communication), all created tasks must be registered with, supervised by, and governed through the `Workspace_Supervision` subsystem (`Manage-SupervisionTask.ps1` / `data/supervision_catalog.json`), ensuring centralized observability, health accounting, and dual-layer schedule resilience.

---

## 2. Phased Implementation Breakdown

### Phase 1: Subsystem Scaffold & Tool Integration (`LCM Backup`)

1. **Subsystem Scaffolding**:
   - Initialize `D:\Git_Repositories\LCM_Backup` with canonical structure:
     - `docs/` (`Architecture.md`, `Requirements.md`, `Implementation.md`) authored under AADR taxonomy.
     - `install/` (`Installation.md`) standard runbook.
     - `tools/`, `modules/`, `tests/`.
     - `AGENTS.md` and `README.md`.
   - Establish single-hop NTFS junction: `LCM_Backup\.agents\rules` $\rightarrow$ `D:\Git_Repositories\.lcm\.agents\rules`.
2. **Centralized Data Path Routing**:
   - Establish storage directory structure in `Workspace_Inventory`:
     - `Workspace_Inventory/data/backups/` (manifests, recovery points, snapshot indices).
     - `Workspace_Inventory/logs/backups/` (telemetry and operational execution logs).
3. **LCM Platform Integration**:
   - Register backup domain commands in `.lcm/tools/internal/tool_catalog.json`.
   - Generate trampoline shortcuts in `.lcm/Cmd/` per LCM tool standards.
4. **Workspace_Supervision Task Governance Integration**:
   - Define integration protocols ensuring all Windows Scheduled Tasks created or utilized by `LCM_Backup` (for LCM events and tool coordination) are registered and tracked in `Workspace_Supervision/data/supervision_catalog.json` via `Manage-SupervisionTask.ps1`.

---

### Phase 2: Local-Scratch Lease Engine

1. **OneDrive Sync Isolation**:
   - Anchor ephemeral lease tracking strictly to local scratch (`.lcm/scratch/` verified in `.gitignore`, or `%LOCALAPPDATA%\LCM\scratch\`).
   - Completely prevents OneDrive sync engine recalculation, lock contention, and background thrashing during rapid tool calls.
2. **Lease Lifecycle Management (`active_execution_lease.json`)**:
   - Schema tracks:
     ```json
     {
       "proposal_id": 56,
       "cr_id": "CRP-2026-031",
       "started_at": "2026-09-02T20:40:00Z",
       "heartbeat_at": "2026-09-02T20:41:30Z",
       "consecutive_turns": 8,
       "max_turns": 15,
       "host_pid": 12844,
       "last_tool_hash": "a1b2c3d4..."
     }
     ```
   - Ephemeral helper routines to acquire, refresh heartbeat, evaluate limits, and release leases cleanly upon task completion.

---

### Phase 3: PreToolUse Loop Fence & Guardrails

1. **Turn Budget Enforcement (`Enforce-LcmPreToolPolicy.ps1`)**:
   - Enforce default threshold: **15 consecutive autonomous tool turns** without human operator intervention.
   - Support **Operator Turn Extension Flag** (`-MaxTurns <int>` or interactive continuation prompt) to accommodate deep architectural multi-pass sessions without hard walls.
2. **Deterministic Loop Detection (SHA256 Call Signature)**:
   - Compute normalized hash: `SHA256(ToolName + CanonicalSortedArgs)`.
   - Track sliding window of last 5 tool calls in the local lease state.
   - Halt immediately on **3 identical consecutive calls** without intervening state progress (`LOOP_FENCE_TRIP: Repetitive tool loop detected`).
3. **Context Buffer Clamp**:
   - Restrict tool return payloads to **50 KB** max per invocation. Outputs exceeding the threshold are cleanly truncated with line/byte summaries to prevent model context blowout.

---

### Phase 4: Process Watchdog & T0 Crash Rollback

1. **Synchronous Execution Watchdog (`Invoke-LcmScriptRunner.ps1`)**:
   - Wrap commands dispatched via `run_command` in an active watchdog process.
   - Enforce a **90-second synchronous timeout**: forcefully terminate child process tree (`Stop-Process -Force -PassThru`) if a non-daemon command exceeds 90 seconds.
2. **T0 Orphaned Lease Recovery (`Invoke-LcmSessionAudit.ps1`)**:
   - On session startup or pre-tool audit, check for active leases.
   - If `(CurrentTime - Heartbeat) > 180s` OR `Get-Process -Id $host_pid` returns null:
     - Automatically transition affected proposal in `proposals.json` to `progress_state: "blocked"`.
     - Append diagnostic note to `state_history` with exact reason (`SYSTEM_T0_RECOVERY: Orphaned lease detected after unexpected process termination`).
     - Archive stale lease file to `.lcm/logs/recovery/`.
3. **Atomic Ledger Serialization Pattern**:
   - Mandate `[System.IO.File]::Replace("proposals.json.tmp", "proposals.json", "proposals.json.bak")` across all proposal mutation routines to guarantee zero-byte corruption prevention under `RULE-EFF-003`.

---

## 3. Impacted File Paths

| Component / Subsystem | Path | Action |
| :--- | :--- | :--- |
| **LCM Governance** | `Workspace_Inventory/data/proposals/proposals.json` | `[MODIFY]` |
| **LCM Backup Repo** | `D:\Git_Repositories\LCM_Backup\` | `[NEW REPO]` |
| **LCM Backup Governance**| `LCM_Backup/AGENTS.md`, `LCM_Backup/README.md` | `[NEW]` |
| **LCM Backup Docs** | `LCM_Backup/docs/Architecture.md`, `Requirements.md`, `Implementation.md` | `[NEW]` |
| **LCM Backup Install** | `LCM_Backup/install/Installation.md` | `[NEW]` |
| **Centralized Backup Data**| `Workspace_Inventory/data/backups/`, `Workspace_Inventory/logs/backups/` | `[NEW DIR]` |
| **PreToolUse Hook** | `.lcm/tools/hooks/Enforce-LcmPreToolPolicy.ps1` | `[MODIFY]` |
| **PostToolUse Hook** | `.lcm/tools/hooks/Enforce-LcmPostToolPolicy.ps1` | `[MODIFY]` |
| **Session Audit / T0** | `.lcm/tools/hooks/Invoke-LcmSessionAudit.ps1` | `[MODIFY]` |
| **Process Watchdog** | `Workspace_Inventory/tools/Invoke-LcmScriptRunner.ps1` | `[NEW]` |
| **Proposal Manager** | `Workspace_Inventory/modules/ProposalManager.psm1` | `[MODIFY]` |
| **Governance Policy** | `.agents/rules/MethodEfficiencyPolicy.md` | `[MODIFY]` |

---

## 4. Verification & Testing Plan

1. **Subsystem Readiness Verification**:
   - Verify junction health: `Test-Path D:\Git_Repositories\LCM_Backup\.agents\rules\RuleAuthority.md`.
   - Verify AADR documentation files exist and pass markdown lint checks.
2. **Turn Fence & Loop Test**:
   - Mock rapid identical tool calls to verify exit code 1 rejection on turn 3.
   - Verify turn count threshold stops autonomous execution at 15 turns unless `-MaxTurns` is passed.
3. **Process Watchdog Test**:
   - Execute a mock 120-second sleep command via `Invoke-LcmScriptRunner.ps1` and verify hard termination at 90 seconds.
4. **T0 Orphaned Lease Recovery Test**:
   - Create a dummy stale lease with a dead PID; trigger `Invoke-LcmSessionAudit.ps1`; verify target proposal transitions to `blocked` and ledger integrity remains 100% intact.
5. **LCM Dates & Proposal Status Audit**:
   - Execute `Show-CrpDates.ps1 -Id 56 -Detail` to confirm state progression.
