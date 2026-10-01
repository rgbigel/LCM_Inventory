# Change Request Proposal: CRP-125
# Comprehensive Administrative Tool Discovery & Catalog Elevation Alignment

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-125` |
| **Lifecycle State** | `COMPLETED` (Implemented & Accepted in d18119a) |
| **Origin Repository** | `LCM` / Tool Architecture & Governance |
| **Target Scope** | `.lcm/config/tool_catalog.json`, `.lcm/tools/internal/Update-ToolCatalog.ps1`, `.lcm/Cmd/*.cmd`, `CRP-107` Retirement |
| **Author** | Rolf, LCM_AI |
| **Date** | 2026-09-08 |
| **Version Impact** | `v7.4.0` |
| **Predecessor / Supersedes** | `CRP-107` (Operational Gaps A & B) |

---

## 1. Executive Summary & Operational Rationale

Following the architectural consolidation of the Single Authoritative Tool Catalog (`CRP-117`), an audit against `RULE-ELEV-006` revealed that several administrative tools were still cataloged as `"Admin": false` due to a shallow 40-line heuristic in `Update-ToolCatalog.ps1`.

Specifically:
1. **Machine-Scope Environment Setters**: `Set-GitRoot.ps1` sets Machine-scope environment variables (`Git_Root` and PATH), but when run un-elevated it silently modifies only the User scope.
2. **Volume & ACL Repair Utilities**: `Repair-VolumeAcl.ps1`, `Repair-SystemAcl.ps1`, and `Get-SystemAclAudit.ps1` take ownership and configure file system security descriptors, failing or throwing access denied without elevation.
3. **Driver & Service Controllers**: `Forced USO Unlock.cmd` and `AcronisMiniFilterCleanup.cmd` manage Windows Update services and detach kernel mini-filter drivers via `fltmc`.
4. **Shallow Scanner Heuristic**: `Update-ToolCatalog.ps1` only evaluated the first 40 lines of scripts (`-TotalCount 40`), causing scripts with extensive documentation headers to miss elevation keyword detection.

This unified proposal resolves both Gap A (catalog alignment) and Gap B (deep AST heuristic scanning) in a single atomic change, and formally retires `CRP-107`.

---

## 2. Architecture & Implementation Scope

### 2.1 Deep Administrative Heuristic in `Update-ToolCatalog.ps1`
- Expand script content preview from `-TotalCount 40` to **250 lines** (or full content inspection).
- Broaden regex detection to catch:
  - `\[EnvironmentVariableTarget\]::Machine`
  - `'Machine'` scope environment modifications
  - `fltmc` driver operations
  - `takeown` / ownership changes
  - `sc.exe` service commands
  - Explicit tool names: `Set-GitRoot`, `Repair-VolumeAcl`, `Repair-SystemAcl`, `Get-SystemAclAudit`, `Forced USO Unlock`, `AcronisMiniFilterCleanup`.

### 2.2 Authoritative Catalog Alignment in `tool_catalog.json`
- Explicitly update `"Admin": true` for:
  - `Set-GitRoot.ps1`
  - `Repair-VolumeAcl.ps1`
  - `Repair-SystemAcl.ps1`
  - `Get-SystemAclAudit.ps1`
  - `Forced USO Unlock.cmd`
  - `AcronisMiniFilterCleanup.cmd`

### 2.3 Trampoline Recompilation in `.lcm/Cmd/*.cmd`
- Recompile all command trampolines via `Update-ToolCatalog.ps1`.
- Verify that `SetGitRoot.cmd`, `RepairVolumeAcl.cmd`, and companion launchers now include the deterministic `net session` elevation preamble per `RULE-ELEV-005` and `RULE-ELEV-006`.

### 2.4 Formal Retirement of Predecessor `CRP-107`
- Update `CRP-107` documentation status to `SUPERSEDED_AND_RETIRED` by `CRP-125`.
- Maintain codified `RULE-ELEV-006` in `ElevationPolicy.md` intact.

---

## 3. Invariant & Governance Compliance

| Invariant | Status | Verification Plan |
| :--- | :--- | :--- |
| **RULE-ELEV-005** | Enforced | Elevated console windows retain `-NoExit` / `/k` and do not auto-close. |
| **RULE-ELEV-006** | Enforced | Administrative tools require elevation; trampolines auto-elevate via UAC. |
| **Single Source of Truth** | Enforced | All elevation flags reside in `tool_catalog.json`. |
| **Zero Code Drift** | Enforced | Scanner heuristics and catalog flags remain 100% aligned. |