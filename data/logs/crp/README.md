# CRP Execution Logs & Tool Output Traces

**Location**: `Workspace_Inventory/data/logs/crp/`  
**Governance Framework**: Lifecycle Model (LCM V6.2.0)  
**Governing Rule**: `RULE-CM-009` (CRP Tool Execution Traces & Artifact Retention)  
**Authoritative Subsystem**: `Workspace_Inventory` Data Plane  

---

## 1. Overview & Role

This directory serves as the canonical, authoritative repository for all execution traces, tool telemetry, test harness outputs, linter validations, and Git hook execution logs generated during the lifecycle of **Change Request Proposals (CRPs)**.

Per `RULE-CM-009` and LCM subsystem isolation architecture (`LCM_Subsystem_Architecture.md`), execution traces must never pollute source code directories, transient root folders, or agent scratch spaces. All runtime stdout/stderr artifacts must be captured and persisted in this directory.

---

## 2. Naming Conventions

All execution trace files stored in this hierarchy must adhere to the deterministic naming schema:

```
<CRP-ID>_<tool_or_phase_name>[_<timestamp>].log
```

### Examples
- `CRP-2026-037_init.log`
- `CRP-2026-037_ASTValidation.log`
- `CRP-2026-037_PrePushHook_20260904_111500.log`
- `CRP-2026-038_TestRepoReadiness.log`

---

## 3. Capture Requirements

1. **Standard Output & Error Capture**: Multi-phase agent or operator tasks executing automated tools, linters, test suites, or Git hooks must capture stdout/stderr via `Tee-Object` or redirection into this directory.
2. **Ledger Cross-Referencing**: Prior to transitioning a proposal to `completed` in `Workspace_Inventory/data/proposals/proposals.json`, the proposal record must either:
   - Reference the generated log file paths under an `artifacts.logs` array, and/or
   - Provide a concise diagnostic excerpt and path reference in the final `state_history.reason` entry.
