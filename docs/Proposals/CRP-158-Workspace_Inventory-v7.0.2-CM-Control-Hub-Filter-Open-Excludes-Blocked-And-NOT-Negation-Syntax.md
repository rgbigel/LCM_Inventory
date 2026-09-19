# Proposal: CRP-158 CM Control Hub Open Filter Refinement & Universal Column-Qualified Negation Search Engine

## Metadata
- **Proposal ID**: `158`
- **Bundle ID**: `CRP-158`
- **Origin Repo**: `Workspace_Inventory`
- **Target Components**:
  - `Workspace_Inventory/assets/CM_CONTROL_HUB.html`
  - `Workspace_Inventory/data/artifacts/CM_CONTROL_HUB.html`
  - `Workspace_Inventory/scratch/CM_CONTROL_HUB.html`
  - `Workspace_Inventory/tools/Show-CmControlHub.ps1`
  - `.lcm/assets/lcm-table-engine.js`
  - `Workspace_Inventory/assets/lcm-table-engine.js`
  - `Workspace_Inventory/.agents/rules/DisplayStandardsPolicy.md`
- **Author**: Operator Directive / CRP Intake
- **Date**: 2026-09-19
- **Priority**: Medium (`M`)
- **Status**: Completed (`completed`) / Pushed (`pushed`)

---

## 1. Problem Statement
When operators manage change requests and proposals within the **LCM Configuration Management Control Hub** and broader standard display dashboards:
1. **"Open" Status Inaccuracy**: The default column filter selection **"Open"** (`#thProgStateFilter`) only filtered out items in `completed` and `pushed` states. Proposals marked as `blocked` (or `failed`/`rejected`) continued to appear in the active "Open" view, cluttering operational focus and obscuring work-in-progress tasks.
2. **Missing NOT / Negation & Column-Qualified Filtering Syntax**: The search input field (`#searchInput`) performed only naive substring matching across proposal properties. It lacked support for field-prefixed negation operators (e.g. `state:!blocked`, `!state:blocked`, `status:!blocked`, `prio:!D`, `scope:!LCM`) or general negation tokens (`!term`), preventing operators from excluding specific states, repositories, or priority levels during triage.
3. **Ecosystem Standard Display Fragmentation**: Other standard table views (e.g. `WORKSPACE_INVENTORY_VIEWER.html`, `User_Tools_Explorer_LCM.html`, `SUPERVISION_CONTROL_HUB.html`) lacked a centralized, reusable engine for column-qualified and NOT-negation search queries.

---

## 2. Root Cause Analysis
In `Workspace_Inventory/assets/CM_CONTROL_HUB.html`:
- Line 2845: `if (progState === "open" && (p.progress_state === "completed" || p.progress_state === "pushed" || p.state === "completed" || p.state === "pushed")) return false;` did not check for `p.progress_state === "blocked"` or `p.state === "blocked"`.
- Lines 2852–2861: Search string evaluation only performed a monolithic `search.includes(...)` comparison without tokenizing query terms or parsing field prefixes (`field:value` / `!field:value` / `field:!value`).
- In `.lcm/assets/lcm-table-engine.js`: `matchesQuery()` only checked simple substring terms without column-name qualifiers or DOM-level header index mapping.

---

## 3. Specification & Technical Implementation

### 3.1 Refined "Open" Status Evaluation
When `progState === 'open'`, proposals are excluded if their implementation progress state or plan state represents non-active/terminal/blocked states:
- `progress_state` is `completed`, `pushed`, `blocked`, or `failed`.
- `state` is `completed`, `pushed`, `blocked`, or `rejected`.

Active open states retained: `undecided`, `queued`, `in_progress`, `verification`, `committed`.

### 3.2 Tokenized Search Engine & Field-Prefixed Negation Syntax
Implemented `parseSearchToken()` and `matchesProposalToken()` in `CM_CONTROL_HUB.html` supporting:
1. **Field-Prefixed Negation**:
   - `state:!blocked` and `!state:blocked` (evaluates both plan state and progress state).
   - `status:!blocked` and `!status:blocked` (evaluates progress state).
   - `prio:!D` and `!prio:D` (evaluates priority code).
   - `scope:!LCM` and `!scope:LCM` (evaluates repository scope).
   - `id:!157` and `!id:157` / `crp:!157` (evaluates proposal identifier).
2. **General Term Negation**:
   - `!term` (excludes proposals containing `term` in title, details, ID, scope, or states).
3. **Compound Search**:
   - Space-delimited multi-token queries with implicit `AND` logic across all positive and negative constraints (e.g. `scope:Workspace_Inventory prio:!D state:!blocked`).

### 3.3 Generalization into `LcmTableEngine` (`v1.1.0`)
Upgraded `.lcm/assets/lcm-table-engine.js` and `Workspace_Inventory/assets/lcm-table-engine.js`:
- Added `LcmTableEngine.parseTokens(query)`: Robust parser supporting column qualifiers (`Col:Val`), quoted strings (`Col:"multi word"`), and negation (`!Col:Val`, `Col:!Val`, `!term`).
- Added `LcmTableEngine.getColumnMap(table)`: Dynamic column header mapping for DOM `<table>` elements.
- Added `LcmTableEngine.matchesRow(tr, tokens, colMap, options)`: Evaluates DOM table rows against compound parsed tokens with alias support.
- Added `LcmTableEngine.matchesObject(obj, query, options)`: Evaluates in-memory JSON objects against compound parsed tokens with alias support.
- Added `LcmTableEngine.filterTable(options)` & `LcmTableEngine.bindSearch(options)`: One-line search binding and live count updates for all standard displays.

### 3.4 Governance Policy Alignment (`DisplayStandardsPolicy.md`)
Updated `RULE-DSP-006` in `.agents/rules/DisplayStandardsPolicy.md` to formally mandate column-qualified and negation search engine support across all LCM standard displays.

---

## 4. Verification & Testing
1. **Negation Query Test Suite**: Verified permutations of `state:!blocked`, `!state:blocked`, `status:!blocked`, `prio:!D`, `!scope:LCM`, and compound filters.
2. **Universal Engine Test Suite (`test_universal_table_engine.js`)**: Verified DOM row matching, in-memory object matching, quoted token phrases, and backward compatibility.
3. **Open Filter Verification**: Confirmed that blocked proposals are hidden when "Open" filter is active, while remaining visible under "All Status" or direct status selection.
4. **Recompilation**: Re-ran `Show-CmControlHub.ps1 -NoLaunch` to regenerate `data/artifacts/CM_CONTROL_HUB.html`.
