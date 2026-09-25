# Change Request Proposal: CRP-173

```yaml
CRP-ID: CRP-173
Title: Shared AI Memory (.gemini) Migration Safeguards, GitHub Baseline Verification, Hash Validation, and Pre-Push Integration
Scope: AI Memory Management, .lcm/tools/internal/Initialize-SharedAiMemory.ps1, Workspace_AI, Pre-Push Pipeline
Baseline-Version: v7.6.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-25
Status: Suggested
Plan-State: suggested
Progress-State: queued
Priority: High
Impacted-Repositories:
  - Workspace_AI
  - Workspace_Inventory
  - .lcm
```

---

## 1. Executive Summary & Problem Context

In multi-boot environments (e.g., across partitions `W:`, `X:`, `Y:`, `Z:`), the AI Memory and configuration store (`.gemini`) must reside on a shared physical volume (`A:\.gemini`) and be accessible from `%USERPROFILE%\.gemini` via an **NTFS Directory Junction**.

While [`Initialize-SharedAiMemory.ps1`](file:///D:/Git_Repositories/.lcm/tools/internal/Initialize-SharedAiMemory.ps1) establishes the foundational mechanism, operational experience and risk analysis require enhanced safeguards:

1. **Risk of Data Loss During Migration**:
   - The live directory at `C:\Users\<user>\.gemini` must be fully copied and verified on `A:\.gemini` *before* attempting any directory swap or junction creation.
   - If active processes (e.g. running IDE) prevent renaming, the live source must remain completely untouched.

2. **Inadvertent Junction Re-Creation**:
   - If `%USERPROFILE%\.gemini` is already an NTFS Directory Junction pointing to `A:\.gemini`, it must be checked twice and preserved unconditionally without deleting or re-linking.

3. **GitHub Baseline & Version Verification**:
   - `A:\.gemini` must be verified against an authoritative repository baseline stored on GitHub.
   - If `A:\.gemini` is older than the GitHub baseline, the GitHub version replaces/updates `A:\.gemini`.

4. **Cryptographic Hash Consistency**:
   - The `.gemini` configurations, skills, and plugins must be validated against a SHA256 manifest hash code to guarantee structural integrity and prevent silent drift.

5. **Automated Pre-Push Synchronization**:
   - During pre-push execution (`Invoke-WorkspacePush.ps1` / `Update-Gemini.ps1`), the authoritative `.gemini` configuration manifest and hash must be updated and committed so GitHub always mirrors the latest pushed operational state.

---

## 2. Technical Architecture & Proposed Safeguards

### Invariant 1: Two-Phase Fail-Safe Migration Sequence
1. **Phase 1 (Sync First)**:
   - Synchronize all files from `$sourcePath` (`C:\Users\<user>\.gemini`) to `$targetRoot` (`A:\.gemini`) using `robocopy /E /COPY:DAT /R:2 /W:1 /XJ /NP`.
   - Perform post-copy verification confirming all file counts and timestamps on `A:\.gemini` match or exceed the source.
2. **Phase 2 (Atomic Junction Substitution)**:
   - Only after Phase 1 succeeds, test whether file locks allow atomic renaming (`Rename-Item`).
   - If locks exist, output clear notification to close the IDE briefly to finalize the junction, leaving the original source directory fully functional.
   - If locks are clear, create NTFS Directory Junction: `New-Item -ItemType Junction -Path $sourcePath -Target $targetRoot`.

### Invariant 2: Double-Checked Junction Idempotency
- **Check 1**: Test if `$sourcePath` has `ReparsePoint` attribute or `LinkType -eq 'Junction'`.
- **Check 2**: Test `(Get-Item $sourcePath).Target`. If normalized target equals `A:\.gemini`, log that the junction is healthy and **exit immediately** without touching the filesystem.

### Invariant 3: GitHub Baseline & Age Reconciliation
- Maintain an authoritative `.gemini` configuration baseline in `Workspace_AI/data/gemini_baseline/` tracked in Git and published to GitHub.
- If `A:\.gemini` contains older timestamps than the committed GitHub baseline, update `A:\.gemini` from the repository baseline.

### Invariant 4: Cryptographic Hash Verification (`gemini_manifest.json`)
- Maintain a manifest file `gemini_manifest.json` containing:
  - `version`: SemVer string (e.g., `1.2.0`)
  - `timestamp`: UTC ISO 8601 string
  - `root_hash`: SHA256 checksum over canonical configuration files (`config/`, plugins, skills, hooks)
  - `file_hashes`: Dictionary mapping relative paths to SHA256 hashes
- Verification engine validates local files against `gemini_manifest.json`.

### Invariant 5: Pre-Push Manifest Update (`Invoke-WorkspacePush.ps1`)
- Extend the `[Pre-Push Pipeline]` in `Invoke-WorkspacePush.ps1` to:
  1. Scan active `.gemini/config` and compute current SHA256 hashes.
  2. If changes exist, update `Workspace_AI/data/gemini_baseline/gemini_manifest.json` and mirror files.
  3. Commit updates in `Workspace_AI` prior to remote push.
