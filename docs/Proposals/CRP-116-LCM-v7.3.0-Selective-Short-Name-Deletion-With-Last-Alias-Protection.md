# Change Request Proposal: CRP-116
# Selective Short-Name Deletion with Last-Alias Protection Invariant in Tool Explorer

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-116` |
| **Lifecycle State** | `COMPLETED` (Accepted and Enforced) |
| **Origin Repository** | `LCM` / Desktop UI & Tools |
| **Target Scope** | Tool Explorer (`Show-Tools`, `LcmToolCatalog.psm1`, `lcm-tool-explorer.js`, `lcm-dashboard-theme.css`, `LcmDesktopDaemon.ps1`, `Remove-LcmShortName.ps1`) |
| **Author** | Rolf, LCM_AI |
| **Date** | 2026-09-07 |
| **Version Impact** | `v7.3.0` |

---

## 1. Executive Summary & Problem Statement
During operational audit of command launchers in `LCM_Inventory/Cmd/*.cmd`, multiple duplicate and spelling-variant short-names were identified mapping to the same underlying long-named script file (e.g., 5 spelling variants for `Apply-AllCustomizations.ps1`).

In the Tool Explorer (`ShowTools`), operators lacked an elementary action to prune or delete an extraneous short-name alias without deleting the underlying script code. Furthermore, safety requires that a script must never become orphaned: **if a short-name is the last remaining launcher for a long-named script, deleting it must be strictly disallowed**.

## 2. Architecture & Implementation Scope

### 2.1 Tool Explorer Rename Modal Enhancement
In the Rename modal (`#rename-modal-overlay`):
1. Introduce a dedicated checkmark:
   `[ ] Delete short name only (removes .cmd launcher, preserves script)`
2. When checked:
   - Queries all active `.cmd` launchers in `LCM_Inventory/Cmd/` pointing to the target script.
   - If count <= 1 (Last Alias Protection Invariant):
     - Displays an explicit warning banner: `⚠️ Disallowed: '<ShortName>' is the last remaining short-name launcher for '<ScriptName>'. Every tool must retain at least one short name.`
     - Disables the delete execution button.
   - If count > 1 (Multiple aliases exist):
     - Displays an informative status: `Safe to delete: Found {count} short names for this script. Other launchers: [{list}].`
     - Enables action button: `🗑️ Delete Short Name Only` (styled with danger accent).
     - Execution calls the daemon endpoint `/delete_short_name`.

### 2.2 Source Files Mode Inline Short-Names & Delete Option (User Addendum)
When Tool Explorer is toggled to **Mode: Source Files (Dev)** (`isSourceMode === true` displaying full long filenames):
1. Underneath each script file name, all associated short-name launchers are rendered as inline pill badges (`💬 ShortName`).
2. Each badge provides an individual delete option:
   - **Multiple Launchers Exist**: Badge renders a red `✕` delete button with tooltip `Delete short-name launcher <ShortName>.cmd (preserves underlying script)`. Clicking prompts for confirmation, invokes `/delete_short_name`, prunes aliases, and refreshes the table immediately with a toast notification.
   - **Sole Remaining Launcher**: Badge renders a locked badge (`💬 ShortName 🔒`) with tooltip `Disallowed: Sole remaining launcher for this script (Last-Alias Invariant)`. Deletion is strictly prevented.

### 2.3 CLI & Daemon Enforcement (`Remove-LcmShortName.ps1`)
Provide a reusable PowerShell tool adhering to `RULE-PS-001` - `014`:
```powershell
Remove-LcmShortName.ps1 -ShortName <name> [-TargetScript <script>] [-Force]
```
- Validates the target launcher in `LCM_Inventory/Cmd/<ShortName>.cmd`.
- Scans `LCM_Inventory/Cmd/*.cmd` to identify all trampolines targeting the same underlying script.
- Enforces the **Last-Alias Invariant**: rejects removal if fewer than 2 launchers point to the script.
- Atomically deletes the specified `.cmd` file.
- Automatically prunes alias overrides from `Update-ToolCatalog.ps1` and `tool_catalog.json`.

### 2.4 Daemon Endpoints (`/query_all_short_names`, `/query_short_names`, `/delete_short_name`)
- `POST /query_all_short_names`: Maps every script leaf to its active `.cmd` launchers dynamically.
- `POST /query_short_names`: Returns array of all short names currently bound to a target script.
- `POST /delete_short_name`: Validates last-alias invariant, executes `Remove-LcmShortName.ps1`, and returns structured status.

---

## 3. Invariant Verification & Compliance
- **Last-Alias Protection Invariant**: Strictly disallows leaving any script without at least one valid short-name trampoline.
- **English-Always & ASCII Invariant**: All code, comments, logs, and documentation conform to UTF-8 without BOM and ASCII standards.
- **PowerShell Standards Compliance**: Conforms to approved verbs (`Remove-LcmShortName`), StrictMode Latest, and CmdletBinding.

