# Change Request Proposal: CRP-301

```yaml
CRP-ID: CRP-301
Title: Relocate docs content into LCM_AI docs: correct folder references, shift versions to 10.0.0, update LCM_* references
Scope: LCM_AI, LCM_Inventory, LCM_Shared, LCM_Supervision (references only)
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-10-21 13:01:30
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent

The operator copied the original `D:\Git_Repositories\docs` content into `LCM_AI\docs`, flattened: the files from the former subfolders `Architecture\` and `Requisites\` now sit directly in `LCM_AI\docs` (the two Requisites files are expected in `LCM_AI\docs\Requisites`; this is verified, not assumed). Once the content is internally corrected, `D:\Git_Repositories\docs` is to be replaced by a junction to `LCM_AI\docs`. This proposal prepares that state. The junction itself is NOT part of this proposal.

## 2. Gate 0 Contract

### Target State

1. Every file that existed in the original `D:\Git_Repositories\docs` is located in `LCM_AI\docs` (verified by content comparison) and its content shows the correct new folder locations.
2. Current version fields in those files read `10.0.0`; change-log and history references keep their old versions.
3. Every reference to those file names in the `LCM_*` repositories points to the new location.
4. A detailed report lists every file changed, with the old and new text.

### Original files in scope (inventory taken 2026-10-21)

| Original path | Expected new location |
|:---|:---|
| `docs\Architecture\LCM_Subsystem_Architecture.md` | `LCM_AI\docs\LCM_Subsystem_Architecture.md` |
| `docs\Architecture\Parent_Workspace_Solution.md` | `LCM_AI\docs\Parent_Workspace_Solution.md` |
| `docs\Requisites\external-tools.json` | `LCM_AI\docs\Requisites\external-tools.json` |
| `docs\Requisites\README.md` | `LCM_AI\docs\Requisites\README.md` |

Note: the operator stated the original was flat; the inventory found the two subfolders above. The operator confirmed the flattened result for the Architecture files and the Requisites location.

### Invariants and Exit Criteria

- Step 1, locate: for each original file, find its copy in `LCM_AI\docs` and confirm identical content (hash) before editing. Any file that cannot be found or differs unexpectedly is reported and not edited.
- Step 2, correct content: replace folder paths in the copies that refer to the old layout (for example `docs/Architecture/...`, `docs/Requisites/...`, `D:/Git_Repositories/docs/...`) with the new locations.
- Step 3, versions: the `Version:` header and other current-version fields become `10.0.0`. Change logs, history tables, and references to past versions are unchanged. `LCM_Subsystem_Architecture.md` (currently 2.1.0): `Version:` becomes `10.0.0`; the `Status: Authoritative Architecture` line is left unchanged; the report flags that ACTIVE_CONTEXT.md declares this file NOT ACCEPTED (operator decision 2026-10-21, option 1; RULE-DOC-008 applies to any further edit).
- Step 4, references: search the repositories `LCM_*` (not other repositories) for the original file names and old paths, and replace them with references to the new locations. Search with `es.exe` first, then `rg.exe` (`RULE-EFF-007`). Historical records (proposal bundles that document past states, change logs, review receipts, baselines) are reported but not rewritten unless the operator agrees.
- Step 5, report: for each change give repository, file, line, old text, new text; plus lists of files examined and left unchanged with the reason.
- Dates in edited file headers follow the header-maintenance rule; encodings and line endings are preserved (UTF-8 without BOM where present, CRLF).
- Original files in `D:\Git_Repositories\docs` are NOT modified, moved or deleted.
- No commit and no push without the review gate.

### Explicit Non-Goals

- Creating the junction `D:\Git_Repositories\docs -> LCM_AI\docs`, and removing the original `docs` folder.
- `.venv` and `.vscode` junctions.
- Content changes beyond folder references and version fields; no rewording or restructuring.
- Editing repositories that are not `LCM_*`.
- Resolving the "not accepted" state of `LCM_Subsystem_Architecture.md`.
- Default Non-Goal: cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants

- Invariant 1: Must conform to LCM governance standards (`RULE-LCM-001` to `024`, `RULE-DOC-008`).
- Invariant 2: Edits are atomic per file (`RULE-LCM-022`); each edited file is verified after the edit.
- Invariant 3: A proposed ambiguity (for example a reference that fits two new locations) is reported to the operator, not guessed.

## 4. Verification and Review

- Hash comparison of originals against their copies before any edit.
- After all edits, a search for the old paths and file names in `LCM_*` returns only the reported historical exceptions.
- Version scan of the edited files shows no current-version field other than `10.0.0`.
- Beyond Compare review of the full change set, then commit through the review gate.
