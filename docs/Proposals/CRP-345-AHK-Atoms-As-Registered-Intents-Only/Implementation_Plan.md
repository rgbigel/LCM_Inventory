# Implementation Plan: CRP-345 - AHK Atoms As Registered Intents Only

Date: 2026-11-18 14:19:34

## Changes per file
- `modules/LcmAhkAtoms.psm1` (10.2.0 -> 10.2.1)
  - New `Invoke-LcmAhkAtom -Intent <key> [-ArgumentList] [-TimeoutSeconds]`: resolves the intent in `config/tool_intents.json` (executable AutoHotkey, script `*.ahk`); refuses an unregistered or non-AHK intent and an intent whose `elevated` flag differs from the caller's elevation; each refusal is a `[WARN]` line in `logs/LcmAhkAtoms-<date>.log`.
  - New `Get-LcmAhkAtomIntents`: lists the registered AHK atoms.
  - `Invoke-LcmAhkScript`: `-InlineScript` removed, `-ScriptPath` mandatory, no longer exported (module-internal).
  - `LCM_AHK_OUT` gets its own temporary file; its content is appended to the result output.
- `tools/automation/Select-BeyondCompareTab.ahk` (new): `<hwnd> list|activate|refresh [titlePrefix]`.
- `tools/Invoke-MacriumMountWorker.ps1` (10.7.4 -> 10.7.5): dialog atom through `Invoke-LcmAhkAtom -Intent mount-macriumbrowsedialog`.
- `modules/LcmToolScanLocations.psm1` (10.2.1 -> 10.2.2): scan `LCM_Inventory\tools\automation\*.ahk`.
- `tools/Update-ToolCatalog.ps1` (10.2.9 -> 10.2.10): type `AutoHotkey`, intent executable `AutoHotkey64.exe`, declared `IntentElevated` as default for new intents, no `.cmd` trampoline for AHK atoms; metadata for both atoms (Macrium dialog: admin, elevated; BC tab: not elevated).
- `install/Installation.md` (10.2.0 -> 10.2.1): Phase 1 "External Tools" section with four tables.
- `tools/Test-LcmExternalToolDocumentation.ps1` (new): the audit of section 4.
- `tests/LcmAhkAtoms.Tests.ps1` (new, 7 tests).
- Regenerated: `config/tool_catalog.json`, `config/tool_intents.json`, `data/tools/tools.sql`, `docs/README.md`, launchers in `DoT/` and `Cmd/`.