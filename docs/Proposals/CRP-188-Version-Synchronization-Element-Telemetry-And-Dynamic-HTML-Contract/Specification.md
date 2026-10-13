# Change Request Proposal: CRP-188

## Metadata Header
* **Proposal ID**: `CRP-188`
* **Title**: Version Synchronization Invariant, Element Telemetry Logging, ShowXYZ View Density, and Dynamic HTML-JSON Runtime Contract
* **Author**: Rolf, Antigravity AI Assistant
* **Date**: 2026-10-13
* **Status**: Suggested (Preliminary)
* **Severity**: High
* **Priority**: Low
* **Target Repositories**: `LCM_Inventory`, `LCM_Shared`, `LCM_AI`, `Git_Repositories`
* **App Context**: `A7` (Proposal Management / LCM Hub) & `A1` (Subsystems & Governance Engine)
* **Lifecycle State**: Suggested (`RULE-LCM-001`)

---

## 1. Executive Summary & Intent
This preliminary proposal addresses systemic version tracking drift across documents and code, mandates element-level version telemetry in logs and displays, establishes an ergonomic solution for displaying and sorting timestamps and version numbers in `ShowXYZ` applications, and designs a dynamic HTML-JSON runtime contract to minimize redundant HTML recompilation by leveraging daemon parameter files over Port 9876.

---

## 2. Problem Statement & Findings
1. **Document & Code Internal Version Stagnation**:
   * During recent development cycles, files modified in the working tree (e.g. documentation, scripts) show extensive content diffs against baseline in Beyond Compare 5, yet their internally coded versions (in DOX headers or script manifests) remain identical to the baseline.
   * Tool Explorer (`lcm-tool-explorer.js`, `Show-ToolsExplorer.ps1`) underwent significant feature changes and bug fixes, but its displayed version was not updated.
2. **Missing Element Version in Telemetry**:
   * Log messages, terminal outputs, and dashboard banners often emit generic messages without declaring the specific version of the executing module or script, complicating multi-version debugging and drift analysis.
3. **Screen Real-Estate Scarcity in `ShowXYZ` Viewers**:
   * Operators need to inspect and sort by item version numbers and timestamps in `ShowXYZ` list views (e.g. `Show-Subsystems`, `Show-LCM`, `Show-Contracts`). However, horizontal column space is strictly constrained.
4. **Excessive HTML Compilation Overhead**:
   * Current tooling frequently re-compiles complete static HTML files when data changes, even though the client-side JavaScript already possesses JSON-rendering capabilities.
   * Instructions exchanged over Port 9876 often duplicate state rather than passing lightweight parameter file references.

---

## 3. Scope of Requirements & Proposed Solutions

### Item 1: Strict Version Progression Invariant
* **Rule Invariant**: Whenever any document (markdown) or code file (PS1, PSM1, JS, PY) is modified, its internally coded version (DOX metadata block, header comment, or `$version` string) `MUST` increment once per proposal cycle as defined in `DocumentationStandardsPolicy.md` (`RULE-DOC-005`) and SemVer standards.
* Pre-review and pre-commit quality gates `MUST` reject diffs where file contents have changed but internal version numbers remain frozen.

### Item 2: Tool Explorer Version Tracking
* Enforce synchronized version bumps for `Show-ToolsExplorer.ps1`, `lcm-tool-explorer.js`, and `tool_catalog.json` whenever UI, data schemas, or dispatch actions are altered.

### Item 3: Open Architectural Question (Recorded for Evaluation)
> [!IMPORTANT]
> **Open Question for Decision Gate**:
> *Should we synchronize all constituent elements inside a repository to match the repository's major version `X.0.0` whenever the repository's major version `X` is incremented upon `git push`?*
> 
> * **Option A (Universal Major Alignment)**: Reset/advance all constituent scripts, modules, and docs to `X.0.0` at major push, establishing workspace-wide baseline clarity.
> * **Option B (Independent Monotonic Evolution)**: Permit individual constituent elements (e.g. pure atoms, specific tools) to evolve on their own SemVer tracks (`M.Y.Z`), tracking the parent repo version via metadata reference in `inventory.json`.

### Item 4: Element-Keyed Version Telemetry
* Every code element (cmdlet, script, class, CLI trampoline) `MUST` include its own constituent version in:
  * Structured log records (`[yyyy-MM-dd HH:mm:ss] [<Element> v<Version>] <Message>`)
  * Interactive terminal banners (`-h` / `--help` outputs)
  * UI headers and status bars.

### Item 5: `ShowXYZ` Ergonomic View Density & Column Set Toggling
* To provide version and timestamp visibility without horizontal crowding:
  * Implement an interactive **Column Set Toggle** (e.g. `[Set A: Operational]` vs. `[Set B: Diagnostics & Audit]`).
  * **Set A**: Name, Status, Role, Actions.
  * **Set B**: Name, Version (sortable), Last Modified Timestamp (sortable ISO 8601), Author/Commit SHA.
  * Alternatively, implement compact compound cells (e.g. primary title with muted sub-text displaying `10.0.0 • 2026-10-13 21:00`).

### Item 6: Dynamic HTML-JSON Parameterization & Port 9876 Contract
* **Compile-Time vs. Runtime Decoupling**:
  * Define explicit criteria: HTML compilation is only required when HTML/CSS structural templates or core layout scripts change.
  * When data changes (proposals, catalog, telemetry), the HTML UI reads updated `.json` data files directly from disk or via local fetch.
* **Port 9876 Lightweight Contract**:
  * Instead of passing massive payload structures over the local loopback socket, the daemon action protocol will pass parameter file paths/tokens (e.g. `{"action": "refresh", "param_file": "D:/.../options.json"}`).
  * This protocol specification will be codified as a formal contract under `LCM_Shared`.

---

## 4. Architectural Invariants
* **RULE-LCM-001**: Proposal recorded in `suggested` state for deliberate review prior to implementation.
* **RULE-DOC-005**: Version progression enforced across all tripartite documentation and software assets.
* **Contract-First Design**: Communication protocols and parameterization standards versioned under `LCM_Shared/contracts/`.
