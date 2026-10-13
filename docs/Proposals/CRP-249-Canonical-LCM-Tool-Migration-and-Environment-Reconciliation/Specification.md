# CRP-249: Canonical LCM Tool Migration and Environment Reconciliation

| Metadata Field | Value |
|---|---|
| **Proposal ID** | `CRP-249` |
| **Lifecycle State** | `IN_PROGRESS` |
| **Origin Repository** | `LCM_Inventory` |
| **Impacted Repositories** | `["LCM_Inventory", "LCM_AI"]` |
| **Author** | rgbig |
| **Date** | 2026-10-13 |
| **Flow Mode** | DOIT |

## Problem Statement

The live workspace contains 21 PowerShell tools and three contained modules
under `LCM_AI\tools`, while CRP-246 establishes `LCM_Inventory` as the
physical authority for LCM runtime and operational tooling. `LCM_Inventory\Cmd`
contains 21 launchers targeting the old location. User PATH also exposes the
old direct script directory, and machine PATH still exposes the removed
`LCM_Inventory\Cmd` location.

## Objective

Move only `LCM_AI\tools` into the flat `LCM_Inventory\tools` surface. Retain
the newer implementation for filename collisions, keep `LCM_AI` as the rules
and governance-document authority, and make `LCM_Inventory\Cmd` the canonical
launcher directory on machine PATH.

## Scope

- Move the 21 `LCM_AI\tools\*.ps1` files and the `Onboarding` and
  `QualityGates` module directories to `LCM_Inventory\tools`.
- Resolve the `Update-Gemini.ps1` collision by retaining the newer
  implementation.
- Retarget all 21 affected `LCM_Inventory\Cmd` launchers.
- Update active callers, tool-catalog scan definitions, dependency indexing,
  and active tripartite documentation.
- Replace machine PATH `LCM_Inventory\Cmd` with `LCM_Inventory\Cmd`.
- Remove `LCM_AI\tools` from user PATH.
- Preserve machine `Git_Root=D:\Git_Repositories` and remove any conflicting
  user-scope value if present.
- Verify Run-key and scheduled-task references; retain paths that already
  correctly point to `LCM_Inventory`.

## Non-Goals

- Do not relocate rules, `.agents`, or the remainder of `LCM_AI`.
- Do not alter historical immutable analysis evidence or historical proposal
  bundles solely to rewrite past paths.
- Do not modify unrelated `LCM_Tools` or temporary-tool structures.
