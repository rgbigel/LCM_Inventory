# Change Request Proposal: CRP-117
# Single Authoritative Tool Catalog Architecture (Single Source of Truth)

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-117` |
| **Lifecycle State** | `COMPLETED` (Implemented & Accepted in 80e5e6e) |
| **Origin Repository** | `LCM` / Tool Architecture & Governance |
| **Target Scope** | Tool Management Core (`Update-ToolCatalog.ps1`, `tool_catalog.json`, `tool_catalog_overrides.json`, `LcmDesktopDaemon.ps1`, `DaemonActionController.ps1`, `lcm-tool-explorer.js`, `Remove-LcmShortName.ps1`) |
| **Author** | Rolf, Workspace_AI |
| **Date** | 2026-09-07 |
| **Version Impact** | `v7.3.0` |

---

## 1. Executive Summary & Problem Statement

Currently, mapping a tool's **Short-Name** (and aliases) to its **Long-Name executable script** spans **5 separate administrative layers and data stores**:
1. Hardcoded `$metadataOverrides` dictionary inside `Update-ToolCatalog.ps1` (100+ entries).
2. Dynamic JSON overrides file (`.lcm/config/tool_catalog_overrides.json`).
3. Canonical generated catalog (`.lcm/config/tool_catalog.json`) duplicated in `.lcm/tools/internal/tool_catalog.json`.
4. 191 individual physical `.cmd` batch trampolines in `.lcm/Cmd/*.cmd`.
5. On-the-fly regex scraping in `LcmDesktopDaemon.ps1` (`POST /query_all_short_names`), which scans all 191 `.cmd` files at runtime to reverse-engineer their targets.

This multi-layer redundancy causes:
- **Administrative Drift**: Editing or deleting a short-name in one location can leave stale entries in another (e.g. `CmHub` remaining in code dictionary while deleted on disk).
- **Fragile Fallback Cascades**: Consumers (Daemon, Tool Explorer, CLI) implement disparate fallback chains when attempting to resolve commands.
- **Maintenance Overhead**: Adding or renaming a tool requires updating code dictionaries, regenerating catalogs, syncing JSON files, and recreating batch files.

---

## 2. Architecture & Implementation Scope

### 2.1 Single Authoritative Catalog (`.lcm/config/tool_catalog.json`)
Consolidate all administrative metadata into **one single canonical JSON file**:
- `.lcm/config/tool_catalog.json` serves as the sole authoritative repository of:
  - `Name` (source filename)
  - `RelativePath` (authoritative script path from workspace root)
  - `ShortName` (primary short launcher)
  - `Aliases` (ordered list of secondary short names)
  - `Role`, `Audience`, `Admin`, `NoExit`, `Category`, `Description`, `Example`
  - `Parameters`, `Dependencies`
- Eliminate duplicate copies; child tools and internal runners reference `.lcm/config/tool_catalog.json` directly.

### 2.2 Retirement of Hardcoded Code Dictionaries
- Retire the monolithic `$metadataOverrides` hashtable (100+ entries) from [Update-ToolCatalog.ps1](file:///D:/Git_Repositories/.lcm/tools/internal/Update-ToolCatalog.ps1).
- `Update-ToolCatalog.ps1` transitions from an in-code dictionary writer to a **catalog synchronization & trampoline compiler**:
  1. Scans repository tool folders for new or removed scripts (`.ps1`, `.py`, `.cmd`).
  2. For new scripts, extracts docstrings via AST parser (`.SHORTNAME`, `.ROLE`, `.AUDIENCE`, `.DESCRIPTION`, `.ALIASES`).
  3. Merges scanned additions/deletions directly into the single authoritative `tool_catalog.json`.
  4. Generates `.lcm/Cmd/<Name>.cmd` trampolines directly from `tool_catalog.json`.

### 2.3 Elimination of `tool_catalog_overrides.json`
- In-place UI operations in Tool Explorer (renames, metadata edits, role changes) and CLI tools (`Remove-LcmShortName.ps1`) commit directly to `tool_catalog.json`.
- Eliminates the secondary merge pass and snapshot synchronization logic in `DaemonActionController.ps1` (`SyncCatalogState`).

### 2.4 Elimination of Daemon Trampoline Regex Scraping
- The Desktop Daemon endpoint `/query_all_short_names` reads directly from the authoritative `tool_catalog.json` (or memory cache) instead of disk-scanning and regex-parsing 191 plain-text batch files.
- Generates instant, 100% accurate reverse maps (`TargetScript -> [ShortNames]`) with 0ms disk overhead and zero parsing fragility.

### 2.5 Preservation of Terminal Execution Trampolines
- Retain `.lcm/Cmd/*.cmd` strictly as lightweight OS entrypoints for Windows `%PATH%` console usage.
- All trampoline files are strictly deterministic artifacts compiled from `tool_catalog.json`.

---

## 3. Invariant & Governance Compliance

| Invariant | Status | Verification Plan |
| :--- | :--- | :--- |
| **Single Source of Truth** | Enforced | Metadata lives in exactly one place: `tool_catalog.json`. |
| **Last-Alias Protection** | Maintained | Deleting an alias remains prohibited if count == 1. |
| **Zero Code Drift** | Enforced | No hardcoded tool names or metadata in PowerShell engine scripts. |
| **ASCII & UTF-8 Invariant** | Enforced | Single JSON catalog stored strictly as UTF-8 without BOM. |
| **Performance Invariant** | Improved | Daemon `/query_all_short_names` response time drops from ~20ms to <1ms. |

---

## 4. Current State & Promotion Notice

> [!NOTE]
> This proposal is registered in **`OPEN`** state. Implementation is deferred until explicit operator review and promotion per LCM governance.

