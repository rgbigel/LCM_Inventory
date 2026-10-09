# CRP-249 Walkthrough

## Initial Evidence

- `LCM_AI\tools` contains 21 scripts and three module manifests/modules.
- `LCM_Inventory\Cmd` has exactly 21 wrappers targeting those 21 scripts.
- No affected wrapper currently targets a missing script.
- `Update-Gemini.ps1` is the sole filename collision in the flat Inventory
  tools destination.
- Machine `Git_Root` is already `D:\Git_Repositories`.
- Machine PATH contains stale `LCM_Inventory\Cmd`; user PATH contains stale
  `LCM_AI\tools`.
- The `LCM_DesktopDaemon_rgbig` scheduled task already correctly targets
  `LCM_Inventory\tools\LcmDesktopDaemon.ps1`.

## Implementation Status

- The 21 scripts and two module directories moved from `LCM_AI\tools` to
  `LCM_Inventory\tools`.
- The 502-byte Inventory `Update-Gemini.ps1` delegating wrapper was replaced
  with the newer 8,482-byte implementation from the retired location.
- All 21 affected public launchers now target `LCM_Inventory\tools`.
- The empty retired tools directory was moved without deletion to
  `LCM_Inventory\data\archives\CRP-249\2026-10-07-LCM_AI-tools-empty`.
- Historical proposals, closed change records, and immutable evidence that
  mention the retired path remain preserved as provenance; CRP-249 is the
  authoritative correction for the active topology.

## Validation Evidence

- PowerShell AST parsing passed for 27 migrated or directly modified scripts
  and modules.
- All 21 migrated public command wrappers resolve to exactly one existing
  `LCM_Inventory\tools` target.
- Catalog regeneration completed successfully: 132 entries, 101 Inventory
  tool entries, and zero `LCM_AI\tools` entries. It generated or refreshed 12
  generator-owned launchers while preserving 122 unmanaged launchers.
- Forward and reverse dependency indexes were regenerated. The forward index
  contains zero retired `LCM_AI\tools` references.
- Machine PATH contains one `LCM_Inventory\Cmd` entry and no `LCM_Inventory\Cmd`
  entry. User PATH contains no `LCM_AI\tools` entry.
- Machine `Git_Root` remains `D:\Git_Repositories`; no user `Git_Root`
  override exists.

## Follow-On Scope

CRP-250 owns the deferred registry-authoritative runtime-topology correction
and the GoodNight/GoodMorning lifecycle integration.
