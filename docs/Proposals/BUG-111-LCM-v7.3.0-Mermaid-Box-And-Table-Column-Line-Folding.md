---
Proposal-ID: BUG-111
CR-ID: BUG-111
Scope: LCM / Documentation & Visualization
Version: 10.0.0
Affected-Repos: [LCM, LCM_AI, LCM_Inventory]
Status: OPEN
Date: 2026-10-13
Author: rgbig
Target Scope: LCM Markdown & HTML Rendering Engines (LCM_Inventory/tools/Format-LcmMarkdownDiagrams.ps1, LCM_Inventory/assets/lcm-table-print-atom.css, Universal Table CSS)
Affected Version Range: 10.0.0
Impacted Repositories: [LCM, LCM_AI, LCM_Inventory]
Severity: Medium
---

# BUG-111 / BUG-111: Mermaid Box and Table Column Long-Line Folding and Text Wrapping Support

## 1. Defect Description & Discovery Vector
In markdown documents and generated HTML dashboards across the workspace:
1. **Mermaid Diagram Boxes**: Nodes containing extended text strings (e.g. file paths, module names, URL targets, long descriptions) render as horizontally stretched single lines or overflow their container boundaries because default Mermaid styling lacks automatic text-wrapping / line folding or `<br/>` soft breaks.
2. **Table Columns**: Tables in markdown and rendered HTML viewers (such as document tables and inventory viewers) lack automatic wrapping on long string values (e.g. paths, SHA hashes, parameters), forcing table columns to stretch excessively and inducing wide horizontal scrolling.

## 2. Root Cause Analysis
- **Mermaid Box Styling**: Mermaid SVG rendering computes node box dimensions based on text length without default word wrapping unless explicit soft line breaks (`<br/>`) are inserted or CSS text wrapping (`word-break: break-word`, `overflow-wrap: break-word`, `max-width`, or foreignObject text wrapping) is configured.
- **Table CSS Columns**: Standard table cell styling (`th`, `td`) without explicit `word-break: break-word;` or `white-space: normal;` coupled with min/max column constraints causes long uninterrupted alphanumeric tokens to push table boundaries beyond standard viewport widths.

## 3. Remediation Strategy (Proposed)
1. **Mermaid Node Text Folding**:
   - Enhance the diagram formatting engine ([Format-LcmMarkdownDiagrams.ps1](file:///D:/Git_Repositories/LCM_Inventory/tools/Format-LcmMarkdownDiagrams.ps1)) to inspect node labels and insert balanced `<br/>` break tags or wrap long labels when exceeding a threshold (e.g., 30-40 characters).
   - Ensure Mermaid diagram definitions include responsive styling rules or class definitions permitting text wrapping where supported.
2. **Table Column Wrapping Standard**:
   - Update universal table styling across `LCM_Inventory/assets/` and generated HTML viewers (`CM_CONTROL_HUB.html`, `SHOW_HA_INVENTORY.html`, etc.) ensuring `word-break: break-word;`, `overflow-wrap: break-word;`, and reasonable column `max-width` constraints are applied to prevent column blowout.
3. **Automated Verification**:
   - Test markdown rendering with Mermaid diagrams and wide tables across child repositories.

> [!IMPORTANT]
> **Awaiting Operator Authorization**: Per `RULE-LCM-015` and `RULE-LCM-016`, this bug proposal is currently registered in the `OPEN` state. Implementation planning and code edits will commence upon receipt of an explicit `PROCEED 111` or `PROCEED ALL` command.

