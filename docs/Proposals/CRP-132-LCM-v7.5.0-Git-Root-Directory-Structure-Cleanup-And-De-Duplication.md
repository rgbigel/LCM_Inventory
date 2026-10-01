# Change Request Proposal: CRP-132
# Git-Root Directory Structure Cleanup and De-Duplication

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-132` |
| **Lifecycle State** | `OPEN` (Awaiting Operator Review & PROCEED Trigger per RULE-LCM-015) |
| **Origin Repository** | `LCM / Git_Repositories` |
| **Target Scope** | Git-Root `.lcm/` Structure (`.lcm/hooks`, `.lcm/tools/hooks`, `.lcm/tools/hub`, `.lcm/tools/internal`) |
| **Author** | Operator Directive / CRP Intake |
| **Date** | 2026-09-09 |
| **Priority** | `High` |
| **Version Impact** | `v7.5.0` |
| **Governing Policy** | `ProposalReviewFlowPolicy.md` (`RULE-LCM-015`, `RULE-LCM-016`) |

---

## 1. Executive Summary & Intent

Following the migration of canonical governance rules and configuration management tools into `LCM_Inventory` (as the physical owner and primary commit gate per `CRP-131`), the remaining directory layout of the Git root container (`D:\Git_Repositories\.lcm\`) exhibits structural redundancy and fragmentation:
1. **Duplicate Directory Names**:
   - `D:\Git_Repositories\.lcm\hooks\` vs. `D:\Git_Repositories\.lcm\tools\hooks\`.
2. **Duplication in Hub Infrastructure**:
   - `D:\Git_Repositories\.lcm\tools\hub\` vs. `LCM_Inventory\tools\` (where `Show-CmControlHub.ps1` and `CM_CONTROL_HUB.html` reside).
3. **Misplaced "internal" Hierarchy**:
   - `D:\Git_Repositories\.lcm\tools\internal\` hosts core tools (`LcmDesktopDaemon.ps1`, `Show-Tools.ps1`, `Invoke-InteractiveDesktop.ps1`, `Restore-SystemSettings.ps1`) while administrative and governance tools reside in `LCM_Inventory\tools\`.
4. **Classification as High-Risk Architectural Redesign**:
   - Reorganizing root `.lcm` directory paths affects desktop shortcuts, daemon HTTP endpoints, hardcoded path references in scripts, and PowerShell module resolution.
   - This proposal establishes formal intake to safely plan, de-duplicate, and rationalize the directory architecture across the Git root container.

---

## 2. Problem Analysis & Discrepancies

### Identified Structural Duplications
- **Hooks Fragmentation**: Two distinct `hooks` directories exist under `.lcm`:
  - `.lcm\hooks\` (contains pre-commit/pre-push orchestrator hooks and shell hooks).
  - `.lcm\tools\hooks\` (contains Git hook trampolines and tool runners).
- **Hub Duplication**:
  - Control Hub frontend templates and server handlers are split between `.lcm\tools\hub\` and `LCM_Inventory\`.
- **Misplaced `internal` Directory**:
  - The distinction between `.lcm\tools\internal\` and `LCM_Inventory\tools\` is ambiguous given that `LCM_Inventory` is now the single commit gate for tools and governance rules.

---

## 3. Normative Scope & Objectives (For Implementation Planning Upon PROCEED Trigger)

1. **Holistic Path Audit**:
   - Trace all hardcoded references to `.lcm/tools/internal`, `.lcm/tools/hub`, and `.lcm/hooks` across all scripts, modules, and JSON configurations.
2. **De-Duplication of Hooks**:
   - Consolidate all Git and lifecycle hooks into a single canonical location (e.g. `.lcm/hooks/`).
3. **Rationalization of Tools vs. LCM_Inventory**:
   - Define clear boundary between root container support plumbing (e.g., Session 0/1 desktop dispatchers in `.lcm/`) and first-class user/CM tools in `LCM_Inventory/tools/`.
   - Flatten or re-locate `.lcm/tools/internal/` to eliminate nested redundancy.
4. **Backward Compatibility & Safe Aliasing**:
   - Provide junction or link fallbacks during transition to guarantee that running desktop shortcuts and daemon processes do not break.

---

## 4. Affected Components

- `D:\Git_Repositories\.lcm\hooks\`
- `D:\Git_Repositories\.lcm\tools\hooks\`
- `D:\Git_Repositories\.lcm\tools\hub\`
- `D:\Git_Repositories\.lcm\tools\internal\`
- `LCM_Inventory\tools\`
- `LCM_Inventory\data\proposals\proposals.json`
