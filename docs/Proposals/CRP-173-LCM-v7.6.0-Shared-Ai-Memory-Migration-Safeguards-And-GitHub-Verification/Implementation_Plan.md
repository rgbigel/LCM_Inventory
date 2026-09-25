# Implementation Plan: CRP-173
# Shared AI Memory (.gemini) Migration Safeguards, GitHub Baseline Verification, Hash Validation, and Pre-Push Integration

| Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-173` |
| **State** | `SUGGESTED` (Gate 1 Planning Gate Halt per RULE-LCM-014) |
| **Target Files** | `.lcm/tools/internal/Initialize-SharedAiMemory.ps1`, `Workspace_AI/tools/Update-Gemini.ps1`, `Workspace_Inventory/tools/Invoke-WorkspacePush.ps1` |
| **Author** | Rolf, Antigravity AI Assistant |
| **Date** | 2026-09-25 |

---

## 1. Planned Code Changes

### Step 1: `.lcm/tools/internal/Initialize-SharedAiMemory.ps1`
1. **Double-Checked Junction Preservation**:
   - Double-check existing junctions using `(Get-Item $sourcePath).LinkType` and target path normalization.
   - If pointing to `$targetRoot`, return immediately with zero modifications.
2. **Fail-Safe Pre-Migration Sync**:
   - Execute `robocopy` sync to `$targetRoot` (`A:\.gemini`).
   - Verify file count and size before proceeding.
3. **Age & GitHub Verification**:
   - Read `gemini_manifest.json` from `Workspace_AI/data/gemini_baseline/`.
   - Compare timestamp and git commit date against `A:\.gemini`.
   - If `A:\.gemini` is older than the GitHub baseline, copy newer baseline files to `A:\.gemini`.
4. **Hash Consistency Check**:
   - Calculate SHA256 of local config files and compare against `gemini_manifest.json`.
   - Log verification receipts.

### Step 2: `Workspace_AI/tools/Update-Gemini.ps1`
- Add Phase 4: `Sync-GeminiBaseline`:
  - Scans active `.gemini/config` directory.
  - Computes SHA256 hashes for all files.
  - Writes `Workspace_AI/data/gemini_baseline/gemini_manifest.json`.
  - Mirrors core configuration files to `Workspace_AI/data/gemini_baseline/`.

### Step 3: `Workspace_Inventory/tools/Invoke-WorkspacePush.ps1`
- Verify that `Update-Gemini.ps1` commits `Workspace_AI/data/gemini_baseline` and `gemini_manifest.json` in the pre-push hook.

---

## 2. Verification Strategy

1. **Gate 1 Planning Gate Halt**:
   - Register `CRP-173` in `proposals.json` as `suggested`.
   - Halt execution and await operator trigger (`Proceed 173` / `do 173`).
2. **Upon Authorization**:
   - Test double-checked junction guard with mock paths.
   - Test SHA256 hash generation and verification.
   - Test pre-push pipeline integration in `-DryRun` mode.
   - Present diffs at Gate 2.
