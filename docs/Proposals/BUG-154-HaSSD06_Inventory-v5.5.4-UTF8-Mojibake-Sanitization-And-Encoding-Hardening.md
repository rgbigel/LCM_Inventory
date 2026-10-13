# Proposal: BUG-154 Subsystem Inventory and Rename Engine UTF-8 Mojibake Sanitization and Encoding Hardening

## Metadata
- **Proposal ID**: `154`
- **Bundle ID**: `BUG-154`
- **Origin Repo**: `HaSSD06_Inventory`
- **Target Components**:
  - `data/subsystem_inventory.json`
  - `tools/extract_ha_central_registry.py`
  - `tools/Update-HaInventory.ps1`
  - `tools/Invoke-HaRenameCascade.ps1`
  - `tools/Show-HaInventoryApp.ps1`
  - `docs/SHOW_HA_INVENTORY.html`
- **Author**: Operator Directive / BUG Intake
- **Date**: 2026-10-13
- **Priority**: High (`H`)
- **Status**: Completed (`completed`)


---

## 1. Problem Statement
During initial inventory extraction and Windows PowerShell subprocess pipeline capture, raw UTF-8 byte streams containing German Umlauts (`ü`, `ä`, `ö`, `ß`) and emojis were parsed using Windows legacy console OEM codepages (CP437/CP850). This corrupted text in `data/subsystem_inventory.json` into literal Mojibake sequences (e.g. `K├╝che` for `Küche`, `T├╝r` for `Tür`, `B├╝roleuchte` for `Büroleuchte`, `≡ƒæ╗` for `👻`).

While Home Assistant internal Entity IDs are intentionally transliterated/slugified to ASCII (`ü` -> `ue`, `ä` -> `ae`, etc.), human-readable display names and area labels (`name`, `friendly_name`, `device_name`, `area`) are fully valid in UTF-8 and must be displayed and cascaded cleanly without corruption. Furthermore, existing Mojibake corrupts automatic slugification during rename operations (e.g., `slugify("K├╝che")` fails to match `ü` and generates `k_che`).

---

## 2. Proposed Architecture & Remediation

### 2.1 Database Sanitization
- Execute a comprehensive sanitization pass across `HaSSD06_Inventory/data/subsystem_inventory.json` restoring all corrupted character sequences to clean UTF-8:
  - `├╝` $\rightarrow$ `ü`
  - `├ñ` $\rightarrow$ `ä`
  - `├╢` $\rightarrow$ `ö`
  - `├ƒ` $\rightarrow$ `ß`
  - `├ä` $\rightarrow$ `Ä`
  - `├û` $\rightarrow$ `Ö`
  - `├£` $\rightarrow$ `Ü`
  - `≡ƒæ╗` $\rightarrow$ `👻`

### 2.2 Extraction & Pipeline Encoding Hardening
- In `tools/extract_ha_central_registry.py` and `tools/Update-HaInventory.ps1`:
  - Enforce UTF-8 stdout configuration and set PowerShell `$OutputEncoding = [System.Text.UTF8Encoding]::new($false)` and `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)`.
  - Ensure all file writes strictly use UTF-8 without BOM.

### 2.3 Rename Cascade & Display Transliteration Guard
- In `tools/Invoke-HaRenameCascade.ps1` and `tools/Show-HaInventoryApp.ps1`:
  - Preserve clean UTF-8 strings in human-readable fields (`name`, `friendly_name`, `device_name`, `area`).
  - Ensure `ConvertTo-Slug` (PowerShell) and `slugify` (JavaScript) robustly transliterate UTF-8 characters (`ä` $\rightarrow$ `ae`, `ö` $\rightarrow$ `oe`, `ü` $\rightarrow$ `ue`, `ß` $\rightarrow$ `ss`) to produce clean ASCII entity IDs.

### 2.4 Dashboard Recompilation & Verification
- Recompile `docs/SHOW_HA_INVENTORY.html` and verify that all tables, filter dropdowns, badges, and modals render clean Umlauts (`Küche`, `Büroleuchte`, `Tür`) without Mojibake.

---

## 3. Verification Plan
1. Validate `data/subsystem_inventory.json` has zero residual box-drawing Mojibake codepoints (`U+251C`, `U+255D`, etc.).
2. Run `pwsh tools/Test-RepoReadiness.ps1` to ensure all 5 quality gates pass.
3. Recompile and verify `docs/SHOW_HA_INVENTORY.html` in browser.
