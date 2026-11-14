# Specification: BUG-327


```yaml
CRP-ID: BUG-327
Title: [BUG] BCR and Macrium Baseline Admin Flag Alignment and Headless Elevation Hang Remediation
Scope: LCM_Inventory
Baseline-Version: 10.2.5
Author: Rolf & Antigravity
Date: 2026-11-14 08:53:32
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: 9
App-ID: None
```

## Document Information
- **Proposal ID**: `BUG-327`
- **Title**: BCR and Macrium Baseline Admin Flag Alignment and Headless Elevation Hang Remediation
- **Author**: Rolf & Antigravity (LCM Governance)
- **Status**: in_progress
- **Date**: 2026-11-14
- **Target Repository**: `LCM_Inventory`
- **Impacted Subsystems**: `tool_catalog.json`, `tools.sql`, `DoT/BCR.cmd`, `DoT/MacriumDailyBcrBaseline.cmd`, `tools/Invoke-MacriumDailyBcrBaseline.ps1`
- **Priority**: High (Runtime Blocker on Gate 2 Visual Review)

---

## 1. Executive Summary & Problem Statement

When attempting to launch a Beyond Compare Review (`bcr 326` / `BCR.cmd` / `Invoke-MacriumBcrReview.ps1`) when a daily baseline partition is not yet mounted, the mount workflow hung indefinitely.

### Root Causes
1. **Catalog Admin Flag Misclassification**:
   - In `LCM_Inventory/config/tool_catalog.json` and `tools.sql`, `Invoke-MacriumDailyBcrBaseline.ps1` and `Invoke-MacriumBcrReview.ps1` (`BCR`) were marked `"Admin": false`.
   - Consequently, `Update-ToolCatalog.ps1` generated trampoline wrappers (`DoT/BCR.cmd` and `DoT/MacriumDailyBcrBaseline.cmd`) without administrative elevation gating (`net session` / `do.cmd -Elevated`), running non-elevated.
2. **Elevated Worker Fallback Hang in Headless/Agent Contexts**:
   - When not elevated, `Invoke-MacriumDailyBcrBaseline.ps1` lines 1107-1117 fell back directly to `Start-Process ... -Verb RunAs -Wait`.
   - In agent shells and non-interactive sessions, `Start-Process -Verb RunAs` triggered `consent.exe` without visible focus on the interactive desktop, hanging the caller indefinitely.
   - It failed to utilize the running, authenticated Session 1 elevated daemon (`http://127.0.0.1:9876/execute`), which executes elevated operations in Session 1 in milliseconds with zero UAC prompts.

---

## 2. Invariants & Required Changes

1. **Tool Catalog Alignment**:
   - Update `Invoke-MacriumDailyBcrBaseline.ps1` to `"Admin": true` in `tool_catalog.json` and `tools.sql`.
   - Update `Invoke-MacriumBcrReview.ps1` to `"Admin": true` in `tool_catalog.json` and `tools.sql`.
   - Regenerate DoT trampolines (`BCR.cmd`, `MacriumDailyBcrBaseline.cmd`) via `Update-ToolCatalog.ps1` so they enforce `net session` and delegate to `do.cmd -Elevated`.
2. **Desktop Daemon Priority for Elevated Worker**:
   - In `Invoke-MacriumDailyBcrBaseline.ps1`, when administrative elevation is required, first attempt execution via the Port 9876 Desktop Daemon (`/execute` with `elevated = $true` and `sync = $true`).
   - Only fall back to local `Start-Process -Verb RunAs` if the daemon is offline.
3. **Verification**:
   - Verify `do.exe status` is online.
   - Run `BCR.cmd` / mount sequence cleanly through the daemon without hanging.

