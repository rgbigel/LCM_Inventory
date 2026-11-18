# Walkthrough: CRP-345 - AHK Atoms As Registered Intents Only

Date: 2026-11-18 14:19:34

## 1. Path taken and issues on the way
- Feasibility probe (2026-11-18, own BC `/solo` window, closed afterwards): BC exposes no tab names, but the window title names the active tab and Ctrl+Tab / Ctrl+Shift+Tab cycle the tabs; each tab owns one view control (`TDirCompareView`, `THomeView`). The tab atom is built on this. Choice made without the operator: the atom activates the BC window and cycles its tabs ("list" ends on the starting tab), so it is not purely read-only as the Specification said; keys only reach the foreground window.
- Refresh key: the atom sends F5 (BC "Refresh"). Whether BC's "Full Refresh" needs another key was not verified; to be checked in the CRP-346 live test.
- Choice made without the operator: AutoHotkey and the other external tools are documented in `install/Installation.md` (Phase 1, "External Tools"), not in `.copilot/CopilotTools.md`, which has carried a legacy status line since 2026-11-16 (its BC path is also wrong).
- Defect found in the existing runner: it pointed `LCM_AHK_OUT` at the file that also receives the atom's redirected stdout. The first live test of the tab atom therefore stopped with AutoHotkey error 32 ("file used by another process") in 4 visible error dialogs (operator report: "it seems to loop"); the runner ended them at the timeout. Fixed: `LCM_AHK_OUT` gets its own file. The Macrium dialog atom also writes to `LCM_AHK_OUT`, so it was exposed to the same lock.
- The external tool audit finds 40 executable names. Eight are only "registered for documentation" (classification, path and version still open), which the exit criterion allows; they are listed in the fourth table.
- The catalog run also corrected stale target paths in 9 `DoT/*.cmd` launchers (e.g. `GoAdm.ps1` now points to `SystemConfiguration\Source`); this is regular generator output.

## 2. Verification evidence (2026-11-18 14:19:34)
- Parse gate: `LcmAhkAtoms.psm1`, `Invoke-MacriumMountWorker.ps1`, `LcmToolScanLocations.psm1`, `Update-ToolCatalog.ps1`, `Test-LcmExternalToolDocumentation.ps1` 0 errors.
- `Invoke-Pester tests/LcmAhkAtoms.Tests.ps1`: 7 passed (atom listing; registered atom runs with arguments; output written to `LCM_AHK_OUT` is collected; unregistered and non-AHK intents refused; elevation mismatch refused; file runner not exported, no inline code).
- Catalog: `Get-LcmAhkAtomIntents` lists `mount-macriumbrowsedialog` (elevated) and `select-beyondcomparetab` (not elevated) with their aliases; no `.cmd` trampolines were generated for them.
- Refusal log lines written to `logs/LcmAhkAtoms-20261118.log`.
- Live tab atom through `Invoke-LcmAhkAtom` (own two-tab BC window): `list` -> 2 tabs, ends on the start tab; `activate left` and `refresh left` -> found, F5 sent; `activate xyz-missing` -> exit 3 `NOT_FOUND`; no AHK process left.
- `Test-LcmExternalToolDocumentation.ps1`: 40 named, 0 undocumented, 8 registered for documentation; exit 0.
- No direct AutoHotkey invocation remains outside `LcmAhkAtoms.psm1` (scan of the `LCM_*` repositories).
- Open: exit criterion "the Macrium dialog atom still mounts (live BCR)" can only be checked when a new image is mounted (today's image is already mounted).