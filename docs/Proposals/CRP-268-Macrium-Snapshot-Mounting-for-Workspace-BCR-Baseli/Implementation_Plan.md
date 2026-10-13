# Implementation Plan: CRP-268 - Macrium Snapshot Mounting for Workspace BCR Baselines

## 1. Executive Summary & Problem Context
Extend the existing normal workspace review session definition with a tool call that selects and mounts the most suitable read-only Macrium D: drive snapshot as the historical baseline for changed-repository Workspace BCRs. Record the snapshot identity, restore point, mount path, scope, and fallback behavior; reuse existing changed-repository review filtering.

## 2. Proposed Changes
### Component 1: Existing Beyond Compare Session Model
- Use [`reference/LCM-History-Git-Repositories.session.xml`](reference/LCM-History-Git-Repositories.session.xml) as the preserved model for the normal workspace-history review.
- The source session is named `_LCM F:\History<->Git_Repositories` in the operator's Beyond Compare 5 session store.
- It compares the read-only historical mount `F:\Git_Repositories` with the live workspace `D:\Git_Repositories`, disables timestamp comparison, and uses content comparison.
- CRP-268 must preserve the review exclusions and read-only historical-side behavior while replacing the fixed `F:` assumption with the Macrium-selected mount path.
- This is a non-lifecycle review: it must not use a CRP/BUG/COH identity, alter lifecycle state, or overwrite lifecycle cohort staging evidence.
- It must produce a dedicated non-lifecycle receipt and an exact root-scope review manifest that is separate from every `staged_review_<repository>.json` lifecycle manifest.
- The comparison scope must be restricted to repositories changed since the selected historical snapshot; it must not indiscriminately compare the complete local or Git workspace root.
- Standard transient paths (including logs, scratch, generated review output, and other configured exclusions) are disclosed as excluded/non-committable and cannot enter the review manifest's committable selection.

### Component 2: Macrium Baseline Selection and Mounting
- Add the tool call that chooses the suitable daily Macrium D: drive snapshot and mounts it read-only before constructing the workspace BCR baseline.
- Record the backup identity, restore point, resolved mount path, and changed-repository scope in the review receipt.
- Do not use a local workspace or Git-root baseline as a substitute for the mounted historical source. If no suitable read-only Macrium mount is available, fail closed and report the missing baseline rather than silently falling back.

## 3. Verification Plan
- Validate the mounted historical root is read-only and contains `Git_Repositories`.
- Verify the generated session preserves content comparison and does not use timestamps.
- Verify that the dedicated non-lifecycle receipt and exact root-scope manifest do not collide with CRP/COH lifecycle staging artifacts.
- Verify only changed repositories are compared and excluded paths are never committable.
- Run focused Pester tests and readiness quality gates.
