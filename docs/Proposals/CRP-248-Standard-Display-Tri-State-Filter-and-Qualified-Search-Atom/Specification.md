# CRP-248: Standard Display Tri-State Filter and Qualified Search Atom

| Metadata Field | Value |
|---|---|
| **Proposal ID** | `CRP-248` |
| **Lifecycle State** | `SUGGESTED` |
| **Origin Repository** | `LCM_Inventory` |
| **Target Scope** | Reusable Standard Display atom and future `Show-*` adoption |
| **Author** | rgbig |
| **Date** | 2026-10-05 |
| **Flow Mode** | Normal review cycle |

## 1. Problem Statement

The LCM Analysis Viewer now proves a practical interaction pattern for dense
Standard Display evidence:

- metric buttons that cycle white (ignore), green (include), and red (omit);
- a green-only scope button where omission has no useful meaning;
- qualified Boolean search with implicit AND, explicit AND/OR, negation,
  grouping, and quoted phrases; and
- source navigation with an editor URI, line, and column.

Other Standard Display `Show-*` tools currently implement filtering and search
independently. Repeating this pattern per display would cause UX drift and
duplicate client-side logic.

## 2. Objective

Design and implement a reusable Standard Display atom that provides:

1. configurable tri-state metric filtering;
2. qualified Boolean search;
3. keyboard- and screen-reader-accessible filter-state indication;
4. a defined data contract for record predicates, metric counts, labels, and
   editor locations; and
5. incremental, opt-in adoption by selected `Show-*` tools.

## 3. Scope

### In scope after approval

- A reusable atom implementation under the governed Standard Display assets or
  module layer selected during design.
- Configuration for metric predicates, include-only metrics, labels, and
  column qualifiers.
- A documented search grammar:
  implicit AND; `AND`/`+`; `OR`/`|`; `!`; parentheses; quoted phrases; and
  named column qualifiers.
- Adoption planning for each affected `Show-*` tool.

### Explicit non-actions before approval

- Do not modify `Show-LcmAnalysisViewer.ps1`.
- Do not modify any other `Show-*` tool or shared display asset.
- Do not infer that every existing display must adopt the atom.
- Do not alter CRP-247 lifecycle, evidence, or review state.

## 4. Acceptance Criteria

1. The atom has a documented, versioned record/configuration contract.
2. Tri-state filters combine deterministic include and exclude predicates.
3. Search parsing handles valid qualified/grouped expressions and reports
   invalid expressions visibly rather than silently changing results.
4. Adopted displays retain existing controls until their migration acceptance
   checks pass.
5. Each migration is separately scoped, tested, and reviewed.

