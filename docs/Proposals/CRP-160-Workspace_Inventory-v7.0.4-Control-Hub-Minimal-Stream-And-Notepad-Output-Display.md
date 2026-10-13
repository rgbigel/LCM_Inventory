# Change Request Proposal Specification: CRP-160
# CM Control Hub Stream Area Minimization, Default Output De-cluttering & Notepad Display Action

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-160` |
| **Lifecycle State** | `VERIFICATION` |
| **Origin Repository** | `LCM_Inventory` |
| **Target Scope** | CM Control Hub UI (`LCM_Inventory/assets/CM_CONTROL_HUB.html`, `LCM_Inventory/tools/LcmDesktopDaemon.ps1`, `LCM_Inventory/tools/Show-CmControlHub.ps1`) |
| **Author** | Rolf, LCM_AI Intake |
| **Date** | 2026-10-13 |
| **Version Impact** | `10.0.0` |
| **Severity / Priority** | Medium / Normal |

---

## 1. Problem Statement & Motivation

1. **Intrusive Default Help Clutter**:
   - On initialization and after clearing the feed, the Control Hub console output was pre-populated with a 12-line multi-bullet help message.
   - This immediately caused the scroll container to report a large `scrollHeight`, triggering the auto-expansion engine and inflating the feed height unnecessarily upon load.

2. **Large Inline Help Dump**:
   - Running the `help` command dumped 17 lines of commands into the stream, inflating the height and pushing actual operational output out of view.

3. **Lack of Dedicated External Output Display**:
   - For detailed multi-proposal CLI tables, transition histories, or diagnostic logs, displaying large text directly inside the web console constrains vertical table space.
   - Operators require a dedicated `display` / `notepad` action to export the current console buffer to a temporary scratch file and open it in standard **Notepad** (for material not intended for edits), allowing the on-screen console stream to remain minimal and compact.

---

## 2. Proposed Architectural Solution

### 2.1 Minimal Initial & Cleared Stream State
- Replace the multi-line help banner with a clean, single-line placeholder:
  `[Ready] CM Interactive Console. Type commands below (or 'help' / 'display').`
- Ensure `clearConsoleStream()` and initial render do not expand the container height.
- Set base height to a compact 80px.

### 2.2 Notepad "Display" Command & Header Quick-Action
- Add a new command in the console:
  - `display` / `notepad` / `show` / `export`: Captures all text content currently in `#consoleStream`.
- Add a top console header action chip:
  - `📝 Display`
- Endpoint Integration:
  - The client posts the console text content to `http://127.0.0.1:9876/open_editor` with `editor: "notepad"` and opens it in standard Notepad via the desktop daemon.

### 2.3 Compact Inline Help with Notepad Fallback
- Make `help` output concise (2 lines summarizing core verbs), with an explicit note:
  `System/UI: status | readiness | push | display (open in Notepad) | clear`

---

## 3. Verification Plan

| Check | Expected Result |
| :--- | :--- |
| **Initial Load State** | Console stream shows a single clean line; stream remains at minimal base height without auto-expansion. |
| **Clear Action** | Clicking `🧹 clear` or typing `clear` resets stream to single-line ready state and minimal base height. |
| **Display Command** | Typing `display` or clicking `📝 Display` exports the active stream text and opens it in Notepad. |
| **Auto-Expansion** | Console expands smoothly only when large command outputs arrive, and returns to minimal height on refresh/clear. |

