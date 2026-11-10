# Change Request Proposal: BUG-307

```yaml
CRP-ID: BUG-307
Title: Macrium BCR baseline drive candidate validation and registry timestamp tracking
Scope: LCM_Inventory
Baseline-Version: 10.2.2
Author: rgbig
Date: 2026-11-06 16:51:55
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Problem Context
During BCR baseline initialization (`Invoke-MacriumDailyBcrBaseline.ps1` and `Invoke-MacriumBcrReview.ps1`), several structural limitations prevented flexible, automated, and verifiable operation:
1. Drive letter scanning was hardcoded to `F:`–`I:` rather than an operator-configurable candidate list.
2. The `-ReuseMountedBaseline` parameter prevented `bcr` from automatically mounting missing baselines and lacked the clean inverse semantics of a `-NewBaseline` switch.
3. No persisted system registry record was maintained to track the mounted backup timestamp (`MRMTimeStamp`), the mounted drive (`MRMdrive`), the active baseline internal log timestamp (`ActMTimeStamp`), and the active drive (`actMdrive`).
4. Candidate drive volumes were not plausibility-tested against internal log activity timestamps (`LCM_Inventory\data\logs\lcm-internal`), risking comparing against stale or misidentified partitions.
5. Push completion did not record host-wide synchronization telemetry (`MRPushTimeStamp`).
6. Routine BCR invocations lacked a fast-path to immediately reuse an existing valid baseline when no newer backup exists.

---

## 2. Gate 0 Contract & Target-State Requirements

### Clause 1: Inverted Baseline Lifecycle Logic (`-NewBaseline`)
- Replace `-ReuseMountedBaseline` with `[switch]$NewBaseline` (default: `$false`) in `Invoke-MacriumDailyBcrBaseline.ps1` and forward from `Invoke-MacriumBcrReview.ps1`.
- **Default (`-NewBaseline:$false`)**: Validate candidate drives for an existing plausible baseline mount. If found, reuse it without remounting or resetting operator progress. If absent, automatically mount today's backup image.
- **Explicit (`-NewBaseline:$true`)**: Dismount any existing baseline mount in the candidate list and mount today's new Macrium image.

### Clause 2: Configurable Candidate Drive List Parameter
- Add a parameter in `Invoke-MacriumDailyBcrBaseline.ps1`: `[string[]]$CandidateDrives = @('F', 'G', 'H', 'I')`.
- Parameter accepts arrays or delimited strings (e.g., `"F;G;H;I"` or `"F,G,H,I"`).
- Validation requirement: The list length must be $\ge 1$ after normalization.
- All errors, status messages, and operator choices are written to structured logs (`cm_activity.log` / `Invoke-MacriumDailyBcrBaseline-*.log`).

### Clause 3: Registry Backup Metadata Maintenance (`MRMTimeStamp`, `MRMdrive`)
- Registry Key: `HKLM:\SOFTWARE\LCM\MacriumBaseline\`
- In `Mount-MacriumLatestBaseline.ps1` / `Invoke-MacriumDailyBcrBaseline.ps1`, retrieve the LastWriteTime of the latest Macrium backup image file.
- If not found: Abort and log the failure.
- If found: Store/update in the system registry (elevated execution):
  - `MRMTimeStamp`: String timestamp of the Macrium backup image file (`yyyy-MM-dd HH:mm:ss`).
  - `MRMdrive`: Drive letter (e.g., `F:`) assigned upon mounting.

### Clause 4: Baseline Candidate Verification & Log Timestamp Plausibility (`ActMTimeStamp`, `actMdrive`)
- Iterate through the configured candidate drive list to find drives matching `ExpectedVolumeLabel` (default `D4P3-WDB850-D`).
- **If none found in candidate list**: Automatically trigger `ForceNewBackup` (with warning and log).
- **If candidate(s) found**:
  - Retrieve the timestamp of the newest file in `[x:]\Git_Repositories\LCM_Inventory\data\logs\lcm-internal`.
  - Compare this timestamp with `MRMTimeStamp`:
    - If the timestamp is $> 1$ day older or newer than `MRMTimeStamp`: Issue a warning.
    - Interactive mode: Prompt the operator to use the next candidate drive in the list, accept, or abort.
    - Non-interactive / Automated mode: Automatically proceed with the newest candidate baseline volume and log a warning.
  - Store the selected timestamp and drive in `HKLM:\SOFTWARE\LCM\MacriumBaseline\`:
    - `ActMTimeStamp`: Timestamp of the newest log file on the selected baseline volume (`yyyy-MM-dd HH:mm:ss`).
    - `actMdrive`: Selected drive letter.
  - If the selected `ActMTimeStamp` is $> 1$ day older than the latest Macrium backup: Issue a warning (allowing the operator to ignore or trigger `ForceNewBackup`).

### Clause 5: BCR Instant Fast-Path & Post-Push Discretion
- **BCR Fast-Path**: When `bcr` is invoked without `-NewBaseline`:
  - If a valid baseline drive is already mounted in `CandidateDrives`, and the latest backup file in the backup folder does not have a newer modification date than `MRMTimeStamp`, immediately reuse the active baseline without remounting, polling, or UAC prompts.
- **Post-Push Sync Notice**: If `MRPushTimeStamp` is newer than `MRMTimeStamp`, inform the operator that repositories have been pushed since the mounted backup was taken, providing discretion to re-run with `-NewBaseline` if a fresh baseline is desired.

### Clause 6: Push Synchronization Timestamp Telemetry (`MRPushTimeStamp`)
- Registry Key: `HKLM:\SOFTWARE\LCM`
- In `Invoke-LCM_Push.ps1`, upon successful multi-repository push execution, write/update:
  - `MRPushTimeStamp`: Timestamp of the successful push completion (`yyyy-MM-dd HH:mm:ss`).
- Telemetry use cases:
  1. Surface in `Invoke-LCM_GoodMorning.ps1` for host sync gap detection (raises attention item if multiple days elapsed without pushing).
  2. Display in `Invoke-LCM_Push.ps1` pre-flight banner to report time elapsed since the last push.
  3. Corroborate in `Invoke-MacriumDailyBcrBaseline.ps1` whether the mounted backup image was created before or after the last push.

### Clause 7: GoodMorning Single-Authority Baseline Alignment
- In `Invoke-LCM_GoodMorning.ps1`, maintain `Invoke-MacriumDailyBcrBaseline.ps1` as the single authoritative routine for baseline preparation, delegating cleanly to it with `-StartBackupIfMissing` and inheriting candidate drive validation and registry telemetry.

---

## 3. Implementation Choices & Architectural Decisions

### Decision 1: Single Authoritative Routine for GoodMorning (Choice 2)
- **Context**: Whether to remove baseline mounting from `Invoke-LCM_GoodMorning.ps1` or delegate to `Invoke-MacriumDailyBcrBaseline.ps1`.
- **Selected Choice**: Retain `Invoke-MacriumDailyBcrBaseline.ps1` as the single authoritative routine and delegate to it from GoodMorning when `-PrepareBcrBaseline` is requested.
- **Rationale**: Enforces `RULE-AUTHORITY` (Single Source of Truth), prevents divergent drive scanning logic, and provides unified registry telemetry and candidate validation.

### Decision 2: Registry Key Architecture (`HKLM:\SOFTWARE\LCM\MacriumBaseline\` and `HKLM:\SOFTWARE\LCM\`)
- **Context**: Choosing between user-scoped registry (`HKCU`), system environment variables, or a dedicated machine key.
- **Selected Choice**: System-wide registry key `HKLM:\SOFTWARE\LCM\MacriumBaseline\` for baseline parameters and `HKLM:\SOFTWARE\LCM\` for global sync telemetry (`MRPushTimeStamp`).
- **Rationale**: Hardware mounts and Macrium drive letters are system-wide machine resources. The elevated mounting worker already runs with administrative rights, making `HKLM` natural and persistent across all user sessions and background services.

### Decision 3: Flexible Candidate Drive List Specification
- **Context**: How to accept drive candidate inputs (`CandidateDrives`).
- **Selected Choice**: Parameter declared as `[string[]]$CandidateDrives = @('F', 'G', 'H', 'I')`, paired with a normalization helper that splits semicolon/comma-separated strings, strips colons/whitespace, uppercases letters, and enforces `Count -ge 1`.
- **Rationale**: Allows seamless usage from interactive PowerShell, `.cmd` batch wrappers, and automated dispatchers without syntax friction.

### Decision 4: Log Freshness Plausibility via `data\logs\lcm-internal`
- **Context**: Verifying whether a mounted volume is a valid contemporaneous LCM workspace backup rather than a stale clone.
- **Selected Choice**: Inspect `[x:]\Git_Repositories\LCM_Inventory\data\logs\lcm-internal` for the newest `.log` file, compare its timestamp against `MRMTimeStamp`, and warn if drift exceeds 1 day.
- **Automated Fallback**: In non-interactive/headless execution, if multiple candidates exist, select the volume with the newest internal log timestamp and record a structured warning.

### Decision 5: BCR Instant Fast-Path
- **Context**: Avoiding repetitive elevation dialogs and mounting delays during rapid iterative BCR review cycles.
- **Selected Choice**: If a matching candidate drive is already mounted and no newer `.mrimgx` file exists in `B:\Backups\` than `MRMTimeStamp`, immediately reuse the mounted baseline in $< 500$ ms.

---

## 4. Verification Criteria
1. AST parse validation across all touched scripts (`RULE-PS-021`).
2. Registry key verification for `HKLM:\SOFTWARE\LCM\MacriumBaseline\` and `HKLM:\SOFTWARE\LCM`.
3. Pester unit and regression tests in `tests/MacriumBcrReview.Tests.ps1`.
4. Dry-run / WhatIf validation confirming candidate drive parsing, default path resolution, fast-path detection, and logging.
