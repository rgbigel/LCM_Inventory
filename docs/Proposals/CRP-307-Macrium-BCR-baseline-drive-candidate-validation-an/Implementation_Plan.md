# Implementation Plan: BUG-307 - Macrium BCR baseline drive candidate validation, registry timestamp tracking, and BCR fast-path

```yaml
CRP-ID: BUG-307
Title: Macrium BCR baseline drive candidate validation and registry timestamp tracking
Scope: LCM_Inventory
Baseline-Version: 10.0.2
Author: rgbig
Date: 2026-11-06 16:51:55
Status: In_Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Problem Context
This plan details the implementation steps for BUG-307 to provide configurable drive candidate scanning, inverted baseline lifecycle semantics (`-NewBaseline`), registry timestamp tracking (`MRMTimeStamp`, `MRMdrive`, `ActMTimeStamp`, `actMdrive`, `MRPushTimeStamp`), log timestamp plausibility verification against Macrium backup images, and an instant fast-path for BCR review re-use.

---

## 2. Gate 0 Traceability Matrix
- **Clause 1 (Inverted Baseline Semantics)**: `Invoke-MacriumDailyBcrBaseline.ps1`, `Invoke-MacriumBcrReview.ps1`, `Mount-MacriumLatestBaseline.ps1`
- **Clause 2 (Configurable Candidate Drives)**: `Invoke-MacriumDailyBcrBaseline.ps1` parameter `[string[]]$CandidateDrives` with normalization
- **Clause 3 (Registry Backup Metadata)**: Helper functions `Get-LcmRegistryValue` / `Set-LcmRegistryValue` for `HKLM:\SOFTWARE\LCM\MacriumBaseline\`
- **Clause 4 (Plausibility & Freshness Checks)**: `Find-MountedMacriumBaselineCandidates`, `Get-LcmInternalLogTimestamp`, interactive/headless selection loop
- **Clause 5 (BCR Instant Fast-Path & Post-Push Notice)**: Fast-path shortcut when mounted baseline is current; notice if `MRPushTimeStamp > MRMTimeStamp`
- **Clause 6 (Push Telemetry `MRPushTimeStamp`)**: `Invoke-LCM_Push.ps1` registry update upon successful push; `Invoke-LCM_GoodMorning.ps1` sync gap check
- **Clause 7 (GoodMorning Single-Authority Delegation)**: `Invoke-LCM_GoodMorning.ps1` delegates directly to `Invoke-MacriumDailyBcrBaseline.ps1`

---

## 3. Implementation Choices & Technical Design

### Choice 1: GoodMorning Alignment
- Retain `Invoke-MacriumDailyBcrBaseline.ps1` as the single authoritative routine for baseline mounting, and keep delegation in `Invoke-LCM_GoodMorning.ps1`.

### Choice 2: Registry Hive & Persistence Model
- Machine-wide `HKLM:\SOFTWARE\LCM\MacriumBaseline` storing:
  - `MRMTimeStamp` (string: `yyyy-MM-dd HH:mm:ss`)
  - `MRMdrive` (string: e.g. `F:`)
  - `ActMTimeStamp` (string: `yyyy-MM-dd HH:mm:ss`)
  - `actMdrive` (string: e.g. `F:`)
- Global key `HKLM:\SOFTWARE\LCM` storing:
  - `MRPushTimeStamp` (string: `yyyy-MM-dd HH:mm:ss`)

### Choice 3: Candidate Drive Parsing & Normalization
- Support arrays `@('F', 'G')`, semicolon `"F;G"`, and comma `"F,G"`.
- Strip trailing colons and whitespace, convert to uppercase, enforce `Count -ge 1`.

### Choice 4: Internal Log Freshness Evaluation
- Read `[x:]\Git_Repositories\LCM_Inventory\data\logs\lcm-internal\*.log`.
- Compare newest file `LastWriteTime` against `MRMTimeStamp`.
- Threshold: drift $> 1$ day triggers warning. In non-interactive runs, select the newest candidate baseline and log warning.

### Choice 5: BCR Fast-Path
- When `-NewBaseline` is `$false` and a candidate baseline is already mounted:
  - Check `B:\Backups\D4P3+4-WDB850-AD\*.mrimgx`.
  - If no newer backup file exists relative to `MRMTimeStamp`: immediately reuse without elevation or remounting ($< 500$ ms).

---

## 4. Verification & Quality Gates
- Pre-handoff AST parse validation across all touched scripts (`RULE-PS-021`).
- Pester execution of `MacriumBcrReview.Tests.ps1`.
- Dry-run validation via `-WhatIf`.
