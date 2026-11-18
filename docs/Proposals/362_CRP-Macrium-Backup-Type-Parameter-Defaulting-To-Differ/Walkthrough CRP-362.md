# Walkthrough: CRP-362 - Macrium Backup Type Parameter Defaulting To Differential

Date: 2026-11-18 23:12:53

## 1. Path taken
- `Get-ReflectArgumentList` builds `-e -full|-diff|-inc <definition>`; `-BackupType` (ValidateSet, default Diff) feeds it; help, header and log lines name the type.
- Edited while a full backup started by the previous version was running (the running process is unaffected).

## 2. Verification evidence (2026-11-18 23:12:53)

| Check                              | Result                                   |
|:-----------------------------------|:-----------------------------------------|
| Parse gate                         | 0 errors                                 |
| `MacriumBackupType.Tests.ps1`      | 3/3                                      |
| `-h`                               | shows `-BackupType` and the default      |