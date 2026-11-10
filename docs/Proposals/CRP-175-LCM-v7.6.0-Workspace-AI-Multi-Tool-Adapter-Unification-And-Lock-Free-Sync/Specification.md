# Change Request Proposal: CRP-175

```yaml
CRP-ID: CRP-175
Title: Workspace AI Multi-Tool Adapter Unification and Lock-Free Gemini Synchronization
Scope: LCM_AI, Root Git_Repositories, .copilot, .continue, .gemini, Update-Gemini.ps1, Invoke-BeyondCompareReview.ps1
Baseline-Version: 10.2.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-10-13
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: Medium
Impacted-Repositories:
  - LCM_AI
  - LCM_Inventory
  - Git_Repositories
```

---

## 1. Executive Summary & Problem Context

Following the successful relocation of the 17 canonical governance rules to `LCM_AI\.agents\rules\` in `CRP-174`, an audit of AI configuration directories across the workspace revealed significant fragmentation across multi-tool adapter surfaces:

1. **Fragmented & Divergent Copilot Folders**:
   - `D:\Git_Repositories\.agents\rules\` contains a static physical copy of 17 rules from early September (CRP-169).
   - `D:\Git_Repositories\LCM_AI\.agents\rules\` contains 9 obsolete, frozen prototype rules from August 16, 2026 (10.0.0 era).
2. **Scattered Tool Adapters**:
   - AI tools (`.agents`, `.copilot`, `.continue`) have physical files scattered between the root container and `LCM_AI`.
   - Modifying a tool prompt or instruction creates dirty working tree churn in the root container instead of being isolated in `LCM_AI`.
3. **The `.gemini` File-Locking Challenge**:
   - The user global profile directory `C:\Users\rgbig\.gemini` cannot simply be junctioned wholesale into Git because the running IDE actively locks SQLite databases (`state.vscdb`, `*.vscdb-wal`), session sockets, and runtime logs.
   - Whole-folder Git tracking or direct junctioning of `~/.gemini` causes Windows file-locking collisions (`The process cannot access the file because it is being used by another process`).

---

## 2. Technical Architecture: The Single Physical AI Hub & Dot-Directory Alignment

All AI prompts, governance rules, assistant instructions, agent templates, and model configurations will physically reside **exclusively in `LCM_AI`**. Root container dot-directories will be strictly unified as zero-churn NTFS junctions:

```
Physical Storage (Authoritative Domain Owner: LCM_AI)
└── LCM_AI\
    ├── .agents\
    │   ├── rules\            <-- Canonical Rules (17 policies)
    │   ├── skills\           <-- Universal agent skills
    │   ├── hooks.json        <-- Hook definitions
    │   ├── mcp_config.json   <-- MCP server definitions
    │   └── ACTIVE_SESSION.md <-- Active session context
    ├── .copilot\
    │   ├── instructions.md   <-- Copilot assistant instructions
    │   ├── Atoms\            <-- Modular prompt atoms
    │   └── Rules\ ──────────────► Junction pointing to ..\.agents\rules\
    ├── .continue\
    │   ├── config.yaml       <-- Continue model configurations
    │   └── rules\ ──────────────► Junction pointing to ..\.agents\rules\
    └── .github\
        └── agents\           <-- Canonical GitHub agent templates (single copy)

NTFS Directory Junctions (Universal Zero-Churn Reparse Points)
├── D:\Git_Repositories\.agents        ──────► D:\Git_Repositories\LCM_AI\.agents
├── D:\Git_Repositories\.copilot       ──────► D:\Git_Repositories\LCM_AI\.copilot
├── D:\Git_Repositories\.continue      ──────► D:\Git_Repositories\LCM_AI\.continue
├── D:\Git_Repositories\.github\agents ──────► D:\Git_Repositories\LCM_AI\.github\agents
└── <ChildRepos>\.agents\rules         ──────► D:\Git_Repositories\LCM_AI\.agents\rules
```

### Dot-Directory Inventory & Alignment Matrix

| Dot-Directory | Root Container (`D:\Git_Repositories`) | Canonical Hub (`LCM_AI`) | Alignment Action |
|:---|:---|:---|:---|
| **`.agents`** | Junction $\rightarrow$ `LCM_Inventory\.agents` | Physical folder (`rules/`, `skills/`) | Merge `LCM_Inventory\.agents` files (`ACTIVE_*.md`, `hooks.json`, `mcp_config.json`) into `LCM_AI\.agents\`. Eliminate `LCM_Inventory\.agents`. Repoint root `.agents` junction directly to `LCM_AI\.agents`. |
| **`.copilot`** | Physical folder (tracked in root git) | Physical folder (`LCM_AI\.copilot`) | Prune obsolete `Fixes/` & `Step1Engine.json`. Replace `LCM_AI\.agents\rules` with junction to `LCM_AI\.agents\rules`. Untrack in root git (`git rm -r --cached .copilot`). Replace root `.copilot` with NTFS junction $\rightarrow$ `LCM_AI\.copilot`. Add `/.copilot/` to root `.gitignore`. |
| **`.continue`** | Physical folder (untracked stub) | Does not exist | Create `LCM_AI\.continue` (Option B), create internal junction `LCM_AI\.continue\rules` $\rightarrow$ `LCM_AI\.agents\rules`. Replace root `.continue` with NTFS junction $\rightarrow$ `LCM_AI\.continue`. Add `/.continue/` to root `.gitignore`. |
| **`.github/agents`** | Physical folder (13 tracked files) | Physical folder (15 files) | Verify all 15 agents in `LCM_AI\.github\agents`. Untrack in root git (`git rm -r --cached .github/agents`). Replace root `.github\agents` with NTFS junction $\rightarrow$ `LCM_AI\.github\agents`. Add `/.github/agents/` to root `.gitignore`. |
| **`.vscode`** | Physical folder (workspace settings) | Physical folder (child repo settings) | Kept separate by scope. Root defines multi-repo workspace settings; `LCM_AI` defines child repo settings. No junction needed. |
| **`.venv`** | Physical folder (Python virtualenv) | Does not exist | Retained at root. Excluded in `.gitignore`. |
| **`.lcm`** | Physical folder (LCM engine) | Does not exist | Retained at root. Cleaned up obsolete `LCM_Inventory\.agents` directory. |

### Elimination of the Redundant `LCM_Inventory\.agents` Hop
Currently, root `D:\Git_Repositories\.agents` points to `LCM_Inventory\.agents`, which in turn points to `LCM_AI\.agents\rules`. Unifying all session metadata and MCP configurations directly into `LCM_AI\.agents` eliminates this intermediate reparse hop, allowing the root `.agents` to point directly to `LCM_AI\.agents`.

### Pruning of Obsolete `.copilot/Fixes` and `Step1Engine.json`
- **Audit Finding**: `Fix_S1E01.json` through `Fix_S1E16.json` and `Fix_Atomic.json` date from early August 2026 during the `Workspace_AC` system recovery epoch. They are static JSON patches for pre-AI codebase reconstruction that have not been executed or referenced in months. Zero active scripts reference them.
- **Action**: Completely prune `.copilot/Fixes/` and `Step1Engine.json`.

### Evolution of `.agents/atoms` vs `.agents`
- **Historical Role of Atoms**: In early 2026, Copilot had a 4,000-token context limit. `CMD.atom`, `JSON.atom`, `PowerShell.atom`, and `Invariant.atom` were terse 4-line rule summaries injected directly into user prompts.
- **Modern LCM Analog**: As the LCM framework evolved, atoms expanded into authoritative frontmatter-scoped policies (`CMDRules.md`, `PowerShellRules.md`, `JsonRules.md`, `InvariantRules.md`). The modern atom is the **Core Invariant column in `AGENTS.md`** and the targeted YAML frontmatter rules (`globs: "*.ps1"`).
- **Action**: Retain `LCM_AI\.agents\atoms` as reference templates for token-constrained Copilot prompts, but ensure all operational rule logic routes through `LCM_AI\.agents\rules`.

---

## 3. Strategies to Circumvent `.gemini` File-Locking

To maintain zero-drift Git tracking of Gemini customizations without colliding with the live IDE process:

### Strategy A: Granular Directory-Slicing Junctions (Recommended)
- **Problem**: `~/.gemini` contains both **declarative configuration** (skills, rules, plugins) and **volatile runtime state** (`antigravity-ide/`, `logs/`, SQLite databases).
- **Solution**: Do NOT junction the root `~/.gemini`. Instead, junction **only the declarative layer**:
  `C:\Users\rgbig\.gemini\config\` $\rightarrow$ `D:\Git_Repositories\LCM_AI\.gemini\config\`
  `C:\Users\rgbig\.gemini\config\plugins\` $\rightarrow$ `D:\Git_Repositories\LCM_AI\.gemini\plugins\`
  The live IDE writes temporary caches and databases to its non-junctioned runtime folder, while declarative skills and customizations are instantly versioned in Git without any file locks.

### Strategy B: Non-Exclusive `FileShare.ReadWrite` Stream Harvesting
- In [`Update-Gemini.ps1`](file:///D:/Git_Repositories/LCM_AI/tools/Update-Gemini.ps1) and [`Sync-LCMResearchSnapshot.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Sync-LCMResearchSnapshot.ps1), replace default `Get-Content` / `[System.IO.File]::ReadAllBytes` with non-exclusive sharing:
  ```powershell
  $stream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete)
  ```
- This allows reading locked or open files directly even while the IDE holds an exclusive write handle.

### Strategy C: Strict Ephemeral Lock Exclusion Filtering
- Hardcode ignore patterns for volatile lock files in the pre-push snapshot scanner:
  `-*.lock`, `-*.wal`, `-*.shm`, `-*.vscdb*`, `-MANIFEST.txt.tmp`, `-logs\*`, `-scratch\*`.
- Ensure `Set-Content -Path $manifestPath` writes to an ephemeral `.tmp` file and performs an atomic replace with retry loops to bypass transient antivirus or indexing locks.

---

## 4. Invariants & Implementation Deliverables

1. **`RULE-AUTH-003` (Single Physical AI Hub Invariant)**:
   - All AI adapter surfaces (`.copilot`, `.continue`, `.agents`, `.github/agents`) have exactly ONE physical location in `LCM_AI`.
   - Root container and child repos link via NTFS directory junctions.
2. **Retire Obsolete `LCM_AI\.copilot` Prototype Rules & Fixes**:
   - Remove stale August 16 prototype files; replace with junction pointing to `LCM_AI\.agents\rules`.
   - Prune obsolete `Fixes/` and `Step1Engine.json`.
3. **Root Git Untangling**:
   - Remove `.copilot` and `.github/agents` from root Git tracking (`git rm -r --cached`).
   - Add `/.copilot/`, `/.continue/`, and `/.github/agents/` to root `.gitignore` under excluded NTFS junctions.
4. **Tool Script Modernization & Reference Alignment**:
   - Update [`LCM_AI/tools/LoadRules.ps1`](file:///D:/Git_Repositories/LCM_AI/tools/LoadRules.ps1) line 29 from `.agents\rules` to `.agents\rules`.
   - Update [`LCM_Inventory/tools/Test-LCMRuleHealth.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Test-LCMRuleHealth.ps1) and [`Repair-LCMRules.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Repair-LCMRules.ps1) to use `LCM_AI\.agents\rules` as canonical authority.
   - Deprecate/clean obsolete `Fixes/` loader [`LCM_AI/tools/LoadFixes.ps1`](file:///D:/Git_Repositories/LCM_AI/tools/LoadFixes.ps1) and references in `Advance-Governance.ps1` and `Validate-CopilotProfile.ps1`.
   - Update `Invoke-BeyondCompareReview.ps1` to resolve `.agents` junction baseline directly to `LCM_AI\.agents`.
5. **Lock-Free Hashing & Snapshot Engine**:
   - Update `Sync-LCMResearchSnapshot.ps1` with retry loops and `FileShare.ReadWrite` stream handling to guarantee zero file-access errors during pre-push sync.
   - Update `Update-Gemini.ps1` to use non-exclusive read streams for SHA256 calculation.

---

## 5. Dangling & Outdated Reference Audit & Remediation Plan

A comprehensive search of the workspace revealed multiple files retaining references to superseded structures:

| Target Category | Files Affected | Current Outdated Reference | Target Canonical Reference |
|:---|:---|:---|:---|
| **Rule Health Scripts** | `LCM_Inventory/tools/Test-LCMRuleHealth.ps1`<br>`LCM_Inventory/tools/Repair-LCMRules.ps1`<br>`LCM_Inventory/tools/Export-LCMRules.ps1` | `LCM_Inventory\.agents\rules`<br>`LCM_Inventory\.agents\rules`<br>`legacy .agents/rules` | `LCM_AI\.agents\rules`<br>(Validate `.agents\rules` is an NTFS junction to `.agents\rules`) |
| **Review Gate Tooling** | `LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1` | Left baseline resolves to `LCM_Inventory\.agents`<br>Filter array has old `.agents\rules` paths | Baseline resolves to `LCM_AI\.agents`<br>Clean junction filters |
| **Helper Scripts** | `LCM_AI/tools/LoadRules.ps1`<br>`LCM_AI/tools/Advance-Governance.ps1`<br>`LCM_AI/tools/Validate-CopilotProfile.ps1` | `.agents\rules`<br>`Step1Engine.json` | `.agents\rules`<br>Remove legacy Step1Engine validation |
| **Governance Policies** | `LCM_AI/.agents/rules/RuleAuthority.md`<br>`LCM_AI/.agents/rules/ReviewCommitGovernancePolicy.md`<br>`LCM_AI/.agents/rules/ProposalReviewFlowPolicy.md` | `LCM_Inventory\.agents\rules`<br>`LCM_Inventory\.agents`<br>`LCM_Inventory\.agents\rules` | `LCM_AI\.agents\rules`<br>`LCM_AI\.agents` |
| **Agent Specs** | `LCM_AI/.github/agents/DirectoryRules.md`<br>`LCM_AI/.github/agents/Workspace-Rules.md` | `.agents/rules/core`<br>`LCM_AI\.agents\rules` | `.agents/rules/`<br>`LCM_AI\.agents\rules` |
| **Workspace Anchors** | `LCM_AI/AGENTS.md`<br>`LCM_AI/GEMINI.md` | `**Canonical Source Authority**: .agents/rules/` | `**Canonical Source Authority**: .agents/rules/` |
| **Architecture Docs** | `LCM_AI/docs/LCM-Rules-Cross-Reference.md`<br>`LCM_Inventory/docs/LCM_METHODOLOGY_AND_MEMORY_ANCHOR.md`<br>`LCM_Inventory/docs/CM_POLICIES.md` | Diagrams & text pointing to `LCM_Inventory/.agents/rules` and `LCM_Inventory/.agents` | Updated Mermaid diagrams and text pointing to `LCM_AI/.agents/rules` |

### Mandatory Pre/Post-Check Quality Gate:
Both before starting file modifications and after completing them, run:
```powershell
rg "(\.lcm[\\/]\.agents|\.copilot[\\/]Rules|\.copilot[\\/]Fixes|Step1Engine|LCM_Inventory[\\/]\.agents)" "D:\Git_Repositories" -g "!*.log" -g "!*.jsonl" -g "!*archive*" -g "!*temp*" -g "!*.git/*" -g "!*node_modules/*"
```
The post-check MUST return **0 active occurrences** across scripts, governance policies, and active agent templates.
