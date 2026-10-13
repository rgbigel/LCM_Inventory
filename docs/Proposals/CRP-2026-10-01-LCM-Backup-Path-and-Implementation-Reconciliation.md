# CRP: LCM_Backup Path and Implementation Reconciliation

Module: docs/Proposals/CRP-2026-10-13-LCM-Backup-Path-and-Implementation-Reconciliation.md  
Purpose: Suggested correction proposal for active `Workspace_Inventory` path references and implementation claims in LCM_Backup.  
Path: D:\Git_Repositories\LCM_Inventory\docs\Proposals\CRP-2026-10-13-LCM-Backup-Path-and-Implementation-Reconciliation.md  
Authors: LCM documentation reconciliation  
Version: 10.0.0
Status: Suggested  
Date: 2026-10-13

---

## Scope

Repository: `LCM_Backup`  
State: `suggested`  
Progress state: `undecided`

## Evidence

`LCM_Backup/tools/Invoke-LcmBackup.ps1` currently uses
`D:\Git_Repositories\Workspace_Inventory\data\backups` and
`D:\Git_Repositories\Workspace_Inventory\logs\backups`, including its help
example. The current physical configuration-management root is
`D:\Git_Repositories\LCM_Inventory`.

The current LCM_Backup tree contains `tools/Invoke-LcmBackup.ps1` but does not
contain the `modules/`, `install/`, or `tests/` implementation artifacts
described by its tripartite specifications.

## Recommended Correction

1. Change the runner's central data and log paths and its help example from
   `Workspace_Inventory` to `LCM_Inventory`.
2. Decide whether the absent module, installation runbook, restore/integrity
   tools, and Pester test are planned deliverables. Either implement them or
   revise the specifications to describe only the existing runner.
3. Reconcile the LCM_Backup README, `AGENTS.md`, and tripartite specifications
   with the current physical LCM roots after the code decision.

## Acceptance Evidence

Run `Invoke-LcmBackup.ps1 -DryRun` and verify that all reported central paths
are beneath `D:\Git_Repositories\LCM_Inventory`. Review the resulting diff and
perform the repository's required validation before promotion.
