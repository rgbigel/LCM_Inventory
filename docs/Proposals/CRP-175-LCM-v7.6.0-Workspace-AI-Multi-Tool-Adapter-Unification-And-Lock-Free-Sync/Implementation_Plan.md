# Implementation Plan: CRP-175

```yaml
CRP-ID: CRP-175
Title: Workspace AI Multi-Tool Adapter Unification and Lock-Free Gemini Synchronization
Gate: Gate 2 (Visual Review & Disposition Gate)
Status: completed
Priority: Medium
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-25
```

---

## Planned Execution Steps

### Phase 1: AI Adapter & Dot-Directory Consolidation
1. Audit all files in `D:\Git_Repositories\.copilot` and `D:\Git_Repositories\LCM_AI\.copilot`.
2. Migrate active prompt atoms and instructions to `LCM_AI\.copilot`; completely prune obsolete `Fixes/` and `Step1Engine.json`.
3. In `LCM_AI\.copilot\Rules`, remove stale 544-byte prototype files and establish junction to `LCM_AI\.agents\rules`.
4. Remove `.copilot` from root git tracking (`git rm -r --cached .copilot`), delete root physical `.copilot` directory, create NTFS junction `D:\Git_Repositories\.copilot` $\rightarrow$ `LCM_AI\.copilot`, and add `/.copilot/` to root `.gitignore`.
5. Create `LCM_AI\.continue` (Option B), establish junction `LCM_AI\.continue\rules` $\rightarrow$ `LCM_AI\.agents\rules`, replace root `.continue` with NTFS junction $\rightarrow$ `LCM_AI\.continue`, and add `/.continue/` to root `.gitignore`.
6. Consolidate GitHub agent templates in `LCM_AI\.github\agents`, untrack `.github/agents` in root git (`git rm -r --cached .github/agents`), replace root `.github\agents` with an NTFS junction $\rightarrow$ `LCM_AI\.github\agents`, and add `/.github/agents/` to root `.gitignore`.
7. Eliminate `.lcm\.agents` middleman hop: merge active session files (`ACTIVE_CONTEXT.md`, `ACTIVE_SESSION.md`, `hooks.json`, `mcp_config.json`) directly into `LCM_AI\.agents`, remove `.lcm\.agents`, and repoint root `D:\Git_Repositories\.agents` directly to `LCM_AI\.agents`.
### Phase 1.5: Remediation of Dangling & Outdated References
1. Run pre-check ripgrep audit across `D:\Git_Repositories` to catalog all occurrences.
2. Update [`LCM_Inventory/tools/Test-LCMRuleHealth.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Test-LCMRuleHealth.ps1) and [`Repair-LCMRules.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Repair-LCMRules.ps1):
   - Set canonical rules directory to `LCM_AI\.agents\rules`.
   - Update `.copilot\Rules` check to verify it is an NTFS junction to `.agents\rules`.
3. Update [`LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1):
   - Resolve `.agents` junction baseline directly to `LCM_AI\.agents` (eliminating legacy `.lcm\.agents` lookup).
4. Update [`LCM_AI/tools/Advance-Governance.ps1`](file:///D:/Git_Repositories/LCM_AI/tools/Advance-Governance.ps1), [`LoadRules.ps1`](file:///D:/Git_Repositories/LCM_AI/tools/LoadRules.ps1), and [`Validate-CopilotProfile.ps1`](file:///D:/Git_Repositories/LCM_AI/tools/Validate-CopilotProfile.ps1):
   - Point rule lookups to `.agents\rules`.
   - Remove legacy references to `Step1Engine.json` and deprecate `LoadFixes.ps1`.
5. Update Governance Policies (`RuleAuthority.md`, `ReviewCommitGovernancePolicy.md`, `ProposalReviewFlowPolicy.md`):
   - Replace references to `LCM_Inventory\.agents\rules` and `.lcm\.agents` with `LCM_AI\.agents\rules` and `LCM_AI\.agents`.
6. Update Agent Markdown Templates (`DirectoryRules.md`, `Workspace-Rules.md`) and Root Anchors (`LCM_AI/AGENTS.md`, `LCM_AI/GEMINI.md`):
   - Correct canonical source authority statements to `.agents/rules/`.
7. Update Architecture Diagrams and Specs (`LCM-Rules-Cross-Reference.md`, `LCM_METHODOLOGY_AND_MEMORY_ANCHOR.md`, `CM_POLICIES.md`).

### Phase 2: Lock-Free `.gemini` Synchronization & Granular Slicing
1. Implement granular slicing for `C:\Users\rgbig\.gemini\config`:
   - Evaluate selective junction of `config/` (skills and custom plugins) into `LCM_AI`.
2. Update [`Sync-LCMResearchSnapshot.ps1`](file:///D:/Git_Repositories/.lcm/tools/internal/Sync-LCMResearchSnapshot.ps1):
   - Wrap `MANIFEST.txt` writes in a robust 3-attempt retry loop with exponential backoff.
   - Use atomic temporary file staging (`MANIFEST.txt.tmp` $\rightarrow$ `MANIFEST.txt`) with `[System.IO.File]::Move($tmp, $dest, $true)`.
3. Update [`Update-Gemini.ps1`](file:///D:/Git_Repositories/LCM_AI/tools/Update-Gemini.ps1):
   - Use `FileShare.ReadWrite` streams for SHA256 hashing to eliminate transient read locks.

### Phase 3: Verification & Quality Gate
1. **Dangling Reference Post-Check**:
   - Execute ripgrep pattern audit across `D:\Git_Repositories` to assert **0 active occurrences** of superseded paths (`.lcm\.agents`, `.copilot\Rules` [non-junction], `.copilot\Fixes`, `Step1Engine`, `LCM_Inventory\.agents`).
2. **Rule Health Verification**:
   - Execute `Test-LCMRuleHealth.ps1` to verify 100% junction health across all child repos.
3. **Review Gate Verification**:
   - Launch `Invoke-BeyondCompareReview.ps1 -RepositoryName LCM_AI -CRP CRP-175` to verify clean single-session review without junction baseline errors.
4. **Pre-Push Snapshot Test**:
   - Run `Invoke-WorkspacePush.ps1 -DryRun` to confirm zero locking collisions and clean pre-push pipeline.
