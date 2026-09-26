# Comprehensive Execution Trace: Beyond Compare 5 Diagnostic & Resolution Flow

This document details the complete technical trace, tool execution log, command outputs, and decision path across the entire Beyond Compare 5 troubleshooting process.

---

## 1. Execution Statistics & Scope
* **Workspace Context**: `D:\Git_Repositories` (Root) / `Workspace_Inventory`
* **Target Script**: `Workspace_Inventory\tools\Invoke-BeyondCompareReview.ps1`
* **Target Binary**: `D:\Tools\Beyond Compare 5\BCompare.exe` (v5.x 64-bit)
* **Configuration Target**: `%APPDATA%\Scooter Software\Beyond Compare 5\BCSessions.xml`
* **Total Operations**:
  - File Views & Greps: 11
  - Shell / PowerShell Executions: 23
  - Web & Documentation Searches: 2
  - Code Replaces & AST Verifications: 2

---

## 2. Granular Step-by-Step Operation Log

### Phase A: Script Inspection & Launch Argument Analysis
1. **Tool**: `grep_search`
   - *Query*: `Invoke-BeyondCompareReview` across `d:\Git_Repositories`
   - *Result*: Identified canonical implementation in `Workspace_Inventory\tools\Invoke-BeyondCompareReview.ps1` and internal catalog mappings in `.lcm`.
2. **Tool**: `view_file`
   - *Target*: `Workspace_Inventory\tools\Invoke-BeyondCompareReview.ps1` (lines 90–220)
   - *Finding*: Examined function `Update-BCReviewSession`. It attempted to manipulate `$xml.BCSessions.TSessionFolder.Items` and edit `//TDirCompareSession[not(@Value)]`.
3. **Tool**: `view_file`
   - *Target*: `Workspace_Inventory\tools\Invoke-BeyondCompareReview.ps1` (lines 690–754)
   - *Finding*: Inspected the execution line:
     ```powershell
     $bcArgString = "`"$tempReviewRoot`" `"$repoPath`" `"/title1=$title1`" `"/title2=$title2`" `"/filters=$filterMask`""
     ```
     Observed that `Update-BCReviewSession -SessionName 'LCM_Review'` was called, but `"LCM_Review"` was omitted from `$bcArgString` and `Start-Process`.

---

### Phase B: Configuration File & Active Memory State Inspection
4. **Tool**: `run_command`
   - *Command*: Read `$env:APPDATA\Scooter Software\Beyond Compare 5\BCSessions.xml`
   - *Result*: Confirmed file existed (~126 KB). 
5. **Tool**: `run_command`
   - *Command*: Search for `TDirCompareSession[@Value='LCM_Review']` via XML XPath.
   - *Result*: `LCM_Review count: 0`. The named session was completely missing from the XML.
6. **Tool**: `run_command`
   - *Command*: Check child elements of `$xml.BCSessions.TSessionFolder.Items`.
   - *Result*: Revealed `Child: TSessionFolder Value:` and `Child: TDirCompareSession Value:`. Discovered that named sessions are contained within a nested `TSessionFolder/Items` node, not directly under the root `Items`.
7. **Tool**: `run_command`
   - *Command*: Check directory listing of `%APPDATA%\Scooter Software\Beyond Compare 5`.
   - *Result*:
     - `BCSessions.xml` (126,524 bytes)
     - `BCSessions.xml.bak` (139,101 bytes)
     - `BCPreferences.xml` (7,170 bytes)
     - `BCState.xml` (23,188 bytes)
8. **Tool**: `run_command`
   - *Command*: Search `BCSessions.xml` for `FollowSymLinks` or `Symbolic`.
   - *Result*: Found that older specific sessions (`CRP-173_Workspace_AI_a751a11 <--> Workspace_AI`, `Git_Repositories <--> Workspace_AI`, `Baseline CRP-169`) had `<Rules><FollowSymLinks Value="True"/></Rules>`, confirming valid XML syntax.
9. **Tool**: `run_command`
   - *Command*: Check the unnamed template node `TDirCompareSession[not(@Value)]`.
   - *Result*: Only contained `<State><DisplayFilter .../><InsigIgnored Value="True"/></State>`. It had **no** `<Rules>` node.

---

### Phase C: Investigating Command-Line Capabilities & Local Help Manual
10. **Tool**: `run_command`
    - *Command*: Locate Beyond Compare executable and run `BCompare.exe /?`.
    - *Result*: Exited with code 0 without writing any usage text to standard output (spawned an asynchronous Win32 help window).
11. **Tool**: `run_command`
    - *Command*: List files in `C:\Program Files\Beyond Compare 5`.
    - *Result*: Found `BCompare.chm` (compiled HTML help file, 2,704,426 bytes).
12. **Tool**: `run_command`
    - *Command*: Attempt decompile via Windows `hh.exe -decompile`.
    - *Result*: Failed to output extracted files in non-interactive environment.
13. **Tool**: `run_command`
    - *Command*: Discover installed archive extractor for CHM.
    - *Result*: Identified Scoop shim `7z.exe` (`D:\Tools\SCOOP\shims\7z.exe`).
14. **Tool**: `run_command`
    - *Command*: Use `7z e` to extract `command_line_reference.html` from `BCompare.chm`.
    - *Result*: Extracted reference page and searched for CLI switches.
15. **Tool**: `run_command` & `search_web`
    - *Command / Query*: Evaluated all documented switches (`/automerge`, `/filters`, `/fv`, `/iu`, `/mergeoutput`, `/qc`, `/reviewconflicts`, `/ro`, `/silent`, `/solo`, `/sync`, `/title1..4`, `/vcs1..4`).
    - *Cross-Reference*: Queried Scooter Software official documentation.
    - *Conclusion*: There is **no CLI flag** to toggle symbolic link handling. The **only** mechanism supported by BC5 to apply session rules via CLI is:
      `BCompare.exe "Session Name" "Left Path" "Right Path"`

---

### Phase D: Process Concurrency & XML Overwrite Discovery
16. **Tool**: `run_command`
    - *Command*: Check running processes matching `*bcomp*`.
    - *Result*: Found active process:
      ```
      PID 22184 | BCompare.exe | D:\Tools\Beyond Compare 5\BCompare.exe
      Session: 1 (Console) | StartTime: 14:18:35
      Window Title: "Baseline 175 (759c0c4) <--> Current Live (Git_Repositories) - Folder Compare"
      ```
    - *Finding*: Beyond Compare was already open. When BC5 runs, it loads its session defaults into memory. If external scripts write to `BCSessions.xml` while BC5 is running, BC5 overwrites those modifications on application exit with its cached in-memory state.

---

### Phase E: Implementation, Patching, and Verification
17. **Tool**: `multi_replace_file_content`
    - *Target*: `Workspace_Inventory\tools\Invoke-BeyondCompareReview.ps1`
    - *Changes*:
      - Corrected session target path in `Update-BCReviewSession`:
        `$xml.SelectSingleNode('/BCSessions/TSessionFolder/Items/TSessionFolder/Items')`
      - Corrected default session template target:
        `$xml.SelectSingleNode('/BCSessions/TSessionFolder/Items/TDirCompareSession[not(@Value) or @Value=""]')`
      - Injected `<Rules><FollowSymLinks Value="True"/></Rules>` into both the default template and `LCM_Review`.

---

### Phase F: The 3-Argument Positional Collision (3-Way Merge Defect)
18. **Symptom Observed**:
    - When passing `"LCM_Review"` followed by `$tempReviewRoot` and `$repoPath`, BC5 opened a **3-way Folder Merge** with the left folder showing an error: `C:\Windows\System32\LCM_Review`.
19. **Root Cause Analysis**:
    - Beyond Compare's CLI positional parser behaves as follows:
      - 1 argument: `BCompare.exe "Named Session"` (loads named session).
      - 2 arguments: `BCompare.exe "Left" "Right"` (opens 2-way Folder Compare).
      - 3 arguments: `BCompare.exe "Left" "Right" "Center"` (opens 3-way Folder Merge).
    - BC5 does **not** recognize `"LCM_Review"` as a session switch when followed by multiple paths. It interpreted `"LCM_Review"` as a relative path to the left folder, `$tempReviewRoot` as the right folder, and `$repoPath` as the center folder.
20. **Final Resolution**:
    - Restored the CLI invocation to strictly **two** folder arguments:
      ```powershell
      $bcArgString = "`"$tempReviewRoot`" `"$repoPath`" `"/title1=$title1`" `"/title2=$title2`" `"/filters=$filterMask`""
      ```
    - Because the default `TDirCompareSession` template in `BCSessions.xml` is permanently patched with `<Rules><FollowSymLinks Value="True"/></Rules>`, every 2-path Folder Compare automatically inherits link-following without triggering 3-way merge semantics. Verified live: window opened cleanly as a 2-way `Folder Compare` with symlinks traversed.
