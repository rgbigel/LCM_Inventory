# Specification: CRP-363

Module: docs/Proposals/363_CRP-Atom-Data-Design-And-ShowAtoms-Display/Specification CRP-363.md  
Purpose: Atom Data Design And ShowAtoms Display  
Path: LCM_Inventory/docs/Proposals/363_CRP-Atom-Data-Design-And-ShowAtoms-Display/Specification CRP-363.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 10:34:00

```yaml
CRP-ID: CRP-363
Title: Atom Data Design And ShowAtoms Display
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-19 10:34:00
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

- The atom defines the elevation (CRP-343), but the operator cannot look at atoms directly: there is no atom table and no atom display.
- Today an atom exists only implicitly as a row of `tool_intents` (column `elevated`); `tool_atom_permissions` holds the lists of level 2 tools; the only atom-centred view is the generated `data/tools/elevation_policy.json` read by the DO daemon.
- `ShowToolIntents` shows the privilege only as ADMIN / USER (a mapping of the old true/false), not the level range 0..3 in text form; it has no elevation column and no linkage between an intent and the component atoms it uses.
- Intent: a proper data design for atoms first, then a `ShowAtoms` display built on it.
- Timing (operator 2026-11-19): registered in suggested mode; work starts only when things have stabilized; not part of CRP-343.
- Review: this Specification only (Plan and Walkthrough not written yet).

## 2. Gate 0 Contract

### Target State

T1 Atom data design: `docs/DataDesign-Tools.md` (RULE-DOC-012) defines atoms as first-class records: atom script, elevation, owning tool and its level, the intents that start it, the tools permitted to call it, and the link from an intent to the component atoms it uses.

T2 `tools.db` carries that design (tables or views per T1); the elevation policy for the DO daemon is generated from it, as today.

T3 `ShowAtoms` display (served on port 9876 like the other Show displays): one row per atom with elevation, owning tool, tool level as text (TBD / granted / controlled / admin), intent keys, permitted callers and open consistency conflicts.

T4 `ShowToolIntents` shows the tool level as text (0..3) instead of ADMIN / USER and a separate elevation column, with the link to the component atoms.

### Invariants and Exit Criteria

- The elevation decision itself (CRP-343 rule, daemon caller check) is unchanged; this CRP makes it visible and gives it a data model.
- Data design reviewed by the operator before any table change; a `.sql` dump precedes every table restructuring (working agreement 2026-11-18).
- Table fields are never dropped (archive by marking rows).
- New display and macro registered in the catalog and `macro-definitions.md` in the same change set (RULE-LCM-021).

### Explicit Non-Goals

- No change to CRP-343's elevation rule, levels or conflict check.
- No work before the operator lifts the deferral.
- Default: cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Origin

- Operator remarks 2026-11-19 during CRP-343 segment 2 (Walkthrough CRP-343, sections 6 to 11): "the Atoms table defines the elevation, and i can't look at them directly, which is bad"; "the intents only show the privilege as ADMIN or USER which maps the old True/False cases ... there also is not elevation column at all, nor is there any linkage between the intents and the component-atoms"; option A (ShowAtoms) recommended, "definitely not within the scope of CRP 343 ... it will require a proper data design".

## Operator Decisions (2026-11-19 17:29:38)

1. A tool may own several atoms (1:n); an atom needs its own key.
2. The permission list of a controlled tool (admin level 2) names atoms, not intent aliases.
3. Atom calls are recorded for all scanned calls (full call graph), not only for elevated atoms.
4. The required parameter switch of an atom gets its own field (e.g. `required_switch`; empty = none). (decided 2026-11-19 17:32:57)
