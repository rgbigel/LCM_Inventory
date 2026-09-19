# Change Request Proposal: Mermaid Diagram Standard & Multi-Scope Markdown/CM Conversion Engine

- **Proposal ID**: `CRP-109`
- **Target Repository**: `LCM` (`Git_Repositories/.lcm/tools`, `Workspace_AI`, `Workspace_Inventory`)
- **Target Version**: `v7.3.0`
- **Domain**: `Lifecycle Model (LCM) Documentation Standards & Diagram Automation`
- **Author**: Rolf, Workspace_AI Governance
- **Status**: `OPEN` (Awaiting Operator Review & PROCEED Trigger)
- **Created**: `2026-09-07 15:25:00`
- **Priority**: `HIGH`
- **Target Scope**: `.agents/rules/DocumentationStandardsPolicy.md`, `.lcm/tools/internal/Format-LcmMarkdownDiagrams.ps1`, `.lcm/Cmd/FormatDiagrams.cmd`, `.lcm/tools/hooks/Enforce-LcmPostToolPolicy.ps1`, `Workspace_Inventory/data/proposals/proposals.json`
- **Affected Version Range**: `v7.0.0 - v7.3.0`
- **Impacted Repositories**: `Git_Repositories`, `Workspace_AI`, `Workspace_Inventory`, `All Governed Repositories`

---

## 1. Objective & Operational Rationale

This Change Request Proposal establishes the **authoritative Mermaid diagramming standard** across all Lifecycle Model (LCM) documentation (`.md` / `.cm` Configuration Management files) and introduces a multi-scoped operator command to scan, detect, and convert ASCII art diagrams and diagrammatic tables into compliant Mermaid representations.

### Identified Deficits & User Friction
1. **PDF & Reader Clipping**: Markdown tables containing repetitive paths (e.g. child repository junction matrices) wrap awkwardly, truncate columns, and cause poor visual presentation in PDF exports and CLI document viewers.
2. **Legacy ASCII Framing**: Many existing architecture documents utilize monospace box art (`+---+`, `|-->`, ASCII software layer stacks) that do not render interactively or scale well on high-DPI displays.
3. **Typography Inconsistency**: Mermaid default fonts can vary between platforms; without explicit font-size constraints, diagram boxes can render text too small or wrap unpredictably.
4. **Lack of Multi-Scope Automation**: Operators lack a centralized, multi-scope command to audit and transform markdown diagrams across the entire workspace, a specific repository, a folder, or a single active file.

---

## 2. Normative Governance Standards

### 2.1 Mandatory Diagram-First Presentation Invariant (`RULE-DOC-007`)
1. **Diagrammatic Representation Scope**:
   - Whenever creating or updating a `.md` or Configuration Management (`.cm`) specification, all:
     - **Software layer stacks** (e.g., Core $\rightarrow$ Supervisor $\rightarrow$ OS $\rightarrow$ Hardware).
     - **Topological & Hub-and-Spoke deployment matrices** (e.g., Junction links, cross-repository distribution).
     - **Procedural sequences & fast-path incubation strategies**.
     - **State machines & decision flows**.
     `MUST` be authored as Mermaid diagrams (`flowchart TD`, `flowchart LR`, `sequenceDiagram`, `stateDiagram-v2`).
2. **ASCII Box Art Prohibition**:
   - Monospace text boxes with box-drawing characters (`+---+`, `|===|`) attempting to depict component architectures are strictly prohibited in governed documentation.
3. **Preservation of Reference Tables**:
   - Tabular reference data (syntax dictionaries like VBA-to-Python mappings, API parameter signatures, and DOX metadata headers) `MUST` remain formatted as standard Markdown tables.

### 2.2 8-Point Minimum Typography Standard
- Every Mermaid diagram containing node boxes, containers, or subgraphs `MUST` enforce a minimum font size of 8 points (`8pt`):
  ```mermaid
  flowchart TD
      classDef default font-size:8pt;
  
```
- Subgraph labels, node titles, and body text inside diagram boxes must remain legible in high-resolution PDF outputs and scaled mobile/tablet displays.

---

## 3. Tool Implementation Specification: `Format-LcmMarkdownDiagrams.ps1`

### 3.1 Script Metadata & Header
- **Path**: `.lcm/tools/internal/Format-LcmMarkdownDiagrams.ps1`
- **Short-Name Alias**: `.lcm/Cmd/FormatDiagrams.cmd`
- **Conformance**: `RULE-PS-008` (Metadata Header), `RULE-PS-009` (Audit Logging), `RULE-PS-010` (-h Help).

### 3.2 Supported Execution Scopes
The command `FormatDiagrams` supports 4 distinct operational levels:
1. **`Git_root`** (`-Scope Git_root` / `-All`):
   - Recursively processes all governed repositories under `D:\Git_Repositories\`.
2. **`Repo`** (`-Scope Repo` / `-Repo <Name>`):
   - Targets the current repository (auto-detected via active directory) or a specified child repository.
3. **`Folder`** (`-Scope Folder` / `-Path <Directory>`):
   - Targets all `.md` files within the active or specified directory.
4. **`Document`** (`-Scope Document` / `-File <FilePath>`):
   - Targets a single specific `.md` or `.cm` file.

### 3.3 CLI Parameters & Switches
```powershell
param(
  [ValidateSet('Git_root', 'Repo', 'Folder', 'Document', 'Auto')]
  [string]$Scope = 'Auto',

  [string]$Target = '',
  [string]$FontSize = '8pt',
  [switch]$Inspect,     # Scan and report candidates without modifying
  [switch]$Fix,         # Apply in-place conversions
  [switch]$NoBackup,    # Suppress temporary .bak creation
  [string]$LogFile = '',
  [switch]$Help
)
```

### 3.4 Operational Pipeline
1. **Discovery & Filtering**:
   - Scans files matching the selected scope, excluding `.git`, `.venv`, `node_modules`, `.agents/skills`, and legacy archives.
2. **Detection Patterns**:
   - Flags ASCII art boxes (`^\s*\+[-=]{4,}\+`).
   - Flags markdown tables whose cells represent hub-and-spoke topologies or workflow arrows.
   - Detects Mermaid diagrams lacking the `font-size: 8pt` typography declaration.
3. **Transformation Engine**:
   - Inserts `classDef default font-size:8pt;` into Mermaid blocks lacking font styling.
   - Replaces recognized ASCII boxes and topological matrix tables with structured Mermaid blocks.
4. **Audit Logging**:
   - Writes detailed execution records to `Workspace_Inventory/logs/diagram_conversions.log`.

---

## 4. Hook Integration & Lifecycle Verification

1. **Pre-Commit / PostTool Hook (`Enforce-LcmPostToolPolicy.ps1`)**:
   - When a `.md` or `.cm` file is edited by an agent or operator, the hook inspects the diff for new ASCII art boxes.
   - Emits an immediate advisory warning if legacy ASCII boxes or un-styled Mermaid blocks are introduced.
2. **Quality Gate (`Test-RepoReadiness.ps1`)**:
   - Incorporates a documentation linter asserting that Mermaid code blocks are syntactically valid and conform to the 8pt minimum font requirement.

---

## 5. Rollout & Staging Plan

1. **Phase 1**: Register `CRP-109` in `Workspace_Inventory/data/proposals/proposals.json` in `OPEN` state.
2. **Phase 2**: Codify `RULE-DOC-007` in `DocumentationStandardsPolicy.md` and synchronize `AGENTS.md` and `LCM-Rules-Cross-Reference.md`.
3. **Phase 3**: Implement `.lcm/tools/internal/Format-LcmMarkdownDiagrams.ps1` and trampoline `.lcm/Cmd/FormatDiagrams.cmd`.
4. **Phase 4**: Register the tool in `tool_catalog.json` and execute verification across scopes (`Document`, `Folder`, `Repo`, `Git_root`).


