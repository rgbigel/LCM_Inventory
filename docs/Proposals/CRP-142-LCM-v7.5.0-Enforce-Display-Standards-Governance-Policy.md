---
Proposal-ID: CRP-142
Scope: LCM
Version: 10.0.0
Affected-Repos: [LCM_Inventory, .lcm, HaSSD06_Inventory, All Child Repositories]
Priority: High
Status: Open
Target Scope: Workspace-wide
---

# CRP-142: Codify and Enforce Canonical LCM Display Standards Governance Policy

## 1. Problem Statement & Motivation
Multiple LCM-governed tools, subsystem viewers, and inventory explorers generate interactive HTML dashboards and reports (e.g. `Show-Tools.ps1`, `Show-Rules.ps1`, `Show-Subsystems.ps1`, `Show-HaInventoryApp.ps1`, `Show-CmdFolderAnalysis.ps1`). Previously, UI layout conventions, color tokens, symbol sizing (Inspect 🔍, Sort ▲▼), sticky headers, theme persistence, and print engines varied or were maintained in ad-hoc script-local CSS, leading to visual fragmentation and inconsistent user experience.

## 2. Proposed Governance Rule: DisplayStandardsPolicy.md
Establish a new authoritative governance policy in `.agents/rules/DisplayStandardsPolicy.md` defining:
1. **RULE-DSP-001 (Canonical Theme & Tokens)**: All LCM HTML displays MUST import or embed the authoritative `StandardTableDisplay.css` design system tokens (`Inter`, `JetBrains Mono`, `--bg-primary`, `--bg-secondary`, `--accent`, `--border`, etc.).
2. **RULE-DSP-002 (Universal Dark/Light Mode Sync)**: All viewers MUST support instant Dark/Light mode toggling with persistent `localStorage('lcm_theme')` synchronization.
3. **RULE-DSP-003 (Standard Header & Breadcrumbs)**: Headers MUST provide Title + Version badge, live relative timestamps, `[⬅️ Back]` navigation breadcrumbs, theme toggles, and print export buttons.
4. **RULE-DSP-004 (Double-Row Sticky Table Headers)**: Data tables MUST implement sticky top headers with aligned second-row (`.col-filter-row`) column selectors and text inputs.
5. **RULE-DSP-005 (Prominent Action & Sort Symbols)**: Action symbols (Inspect `🔍`, Copy `📋`) and column sort indicators (`▲`, `▼`, `⇅`) MUST be rendered in large, legible font sizes (minimum 14–15px) with distinct hover accents.
6. **RULE-DSP-006 (Negation Search Engine & Live Match Counter)**: Filter toolbars MUST support `!exclude` / `-exclude` tokenization and display live match counts (`Showing X of Y`).
7. **RULE-DSP-007 (Print & PDF Export Atom)**: High-density tables MUST integrate `lcm-table-print-atom.js` for multi-page print and PDF export.
8. **RULE-DSP-008 (Desktop Dispatch Invariant)**: HTML viewers launched via CLI MUST route through `Invoke-InteractiveDesktop.ps1` per `RULE-PS-011`.

## 3. Scope of Impact
- Authoritative rule file `.agents/rules/DisplayStandardsPolicy.md` in `LCM_Inventory/.agents/rules/`.
- Cross-reference matrix updates in `AGENTS.md` and `LCM-Rules-Cross-Reference.md`.
- Automated quality gate verification across all `Show-*.ps1` viewer tools.
