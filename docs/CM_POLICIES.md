# Configuration Management (CM) Policies & Invariants

Module: docs/CM_POLICIES.md
Purpose: Formal rules, policies, and invariants governing Configuration Management across the multi-repo workspace.
Path: D:\Git_Repositories\Workspace_Inventory\docs\CM_POLICIES.md
Authors: Rolf, Workspace_AI Engine
Version: 1.0.0
Date: 2026-08-15

---

## 1. Scope & Authority

This document defines the binding Configuration Management (CM) invariants for all repositories and directories located under `D:\Git_Repositories\`.

1. **CM Authority**: `Workspace_Inventory` is the authoritative CM catalog and auditing authority.
2. **LCM Design Authority**: `Workspace_AI` is the authoritative source for LCM rule definitions, prompt architectures, and onboarding templates.
3. **Repository Autonomy**: Component repositories own their source code, tests, and target-local documentation. Governance rules are inherited via NTFS directory junctions (`.agents/rules/core` and `.copilot/Rules/core`).

---

## 2. Repository Classification Policy

Every directory under `D:\Git_Repositories\` must have an explicit classification:

* **`active-design-workshop`**: The incubation workshop for LCM development (`Workspace_AI`).
* **`lcm-governed`**: A software repository that has been onboarded into LCM, possessing valid directory junctions to `Workspace_AI`, root agent instructions, and `.lcm/config.json`.
* **`standard-git`**: A Git repository that is currently un-onboarded to LCM.
* **`non-git`**: A component directory lacking a `.git` database, listed in `git.ignoredRepositories`.
* **`legacy-retired`**: Off-limits historical reference repositories (`Workspace_AC`, `Workspace_GC`).
* **`parent-infra`**: Root Solution workspace infrastructure directories (`.agents`, `.copilot`, `.github`, `.venv`, `.vscode`).

---

## 3. Versioning & Absorption Invariants

1. **Absorption Version (`absorbed_lcm_version`)**: When a repository is first onboarded, the active LCM release version of `Workspace_AI` at that timestamp is recorded in `.lcm/config.json` and `data/inventory.json`.
2. **Current Version (`current_lcm_version`)**: When an onboarded repository is updated via `Invoke-LCMUpdate.ps1`, the `current_lcm_version` is updated.
3. **Version Drift Invariant**: Any repository whose `current_lcm_version` does not match the active `Workspace_AI` release baseline is flagged as **Drifted / Outdated**.
4. **Override Preservation**: During LCM updates, target-specific customizations recorded in `.lcm/overrides.json` must be strictly preserved.

---

## 4. Change Request (CR) Policy

1. **Human-Readable Markdown Authority**: All change requests and proposals must be authored and reviewed in Markdown (`Docs/Methods/Proposals/*.md` or `docs/Logs/`). JSON records are derived index sidecars.
2. **Status Lifecycle**:
   * `proposed`: CR drafted and waiting for operator review.
   * `under-review`: CR actively being evaluated.
   * `approved`: Operator gave explicit approval to proceed with execution.
   * `implemented`: Changes applied to code and documentation.
   * `verified`: Passed all quality gates and test suites.
   * `closed`: Changes committed and verified.
   * `rejected`: Proposal declined with documented reason.
3. **Multi-Repo Impact**: CRs impacting multiple repositories must be cross-indexed in `data/change_requests.json`.

---

## 5. Audit & Activity Logging Policy

1. **Non-Destructive Auditing**: Audits run via `Invoke-WorkspaceAudit.ps1` are strictly read-only relative to audited repositories; they only update `Workspace_Inventory`'s internal databases (`data/inventory.json`, `docs/INVENTORY_DASHBOARD.md`).
2. **Event Ledger**: Commit, push, onboarding, and update actions must append a structured timestamped record to `logs/cm_activity.log`.
