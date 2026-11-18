# Walkthrough: CRP-362 - Macrium Backup Type Parameter Defaulting To Differential

Date: 2026-11-18 23:49:34

## 1. Path taken
- `Get-ReflectArgumentList` builds `-e -full|-diff|-inc <definition>`; `-BackupType` (ValidateSet, default Diff) feeds it; help, header and log lines name the type.
- Edited while a full backup started by the previous version was running (the running process is unaffected).

## 2. Verification evidence (2026-11-18 23:12:53)

| Check                              | Result                                   |
|:-----------------------------------|:-----------------------------------------|
| Parse gate                         | 0 errors                                 |
| `MacriumBackupType.Tests.ps1`      | 3/3                                      |
| `-h`                               | shows `-BackupType` and the default      |

## 3. Revision: default Inc (2026-11-18 23:49:34)

- Default changed from `Diff` to `Inc` (`tools/Start-MacriumDailyBackup.ps1` 10.2.2; help and header text); test expectation updated, not run.
- Gate 2 exception RULE-REV-001 (1): explicit operator `IMMEDIATE` ("Do not test, IMMEDIATE, I accept the result with all consequences"); visual review and tests waived by the operator; syntax gate run: 0 errors.
- The item title still says "Defaulting To Differential" (renaming would rename the bundle folder again); the Specification states `Inc`.
