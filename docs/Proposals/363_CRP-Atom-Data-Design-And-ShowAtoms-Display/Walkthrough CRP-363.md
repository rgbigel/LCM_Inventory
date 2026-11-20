# Walkthrough: CRP-363 - Atom Data Design And ShowAtoms Display

Status: In Progress
Date: 2026-11-19 10:32:41

## T1/T2 tables (2026-11-20 17:32:48, with CRP-358, operator instruction)

- Built per `data/analysis/CRP-363/DataDesign-Atoms-Draft.md` revision 2: `atoms`, `atom_permissions`, `atom_calls`, view `v_atoms`; `tool_intents.atom_id`.
- Open question of the draft decided without the operator (operator 2026-11-20: no trivial questions): `required_switch` is an explicit column, NULL until a catalog entry declares one.
- Result: 330 atoms, 85 elevated, 6 permissions, 0 conflicts (matches the draft facts). `atom_calls` stays empty until the call scan of T3.
- Open: T3 ShowAtoms display incl. the call scan, T4 ShowToolIntents level text / elevation column.
