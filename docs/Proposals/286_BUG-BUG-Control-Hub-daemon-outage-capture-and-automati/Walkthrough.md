# Walkthrough: BUG-286 - [BUG] Control Hub daemon outage capture and automatic recovery

## 1. Executive Summary
BUG-286 was registered after identifying that a port-9876 daemon outage was not durably captured or automatically actioned during an interactive Control Hub launch.

## 2. Verification Evidence
- Registered BUG-286 in `proposals.json`, then transitioned it to `in_progress` through `Set-WorkspaceProposalState -State bug`; the ledger records `flow_mode: doit` and `always_proceed: true`.
- Preserved the observed outage in `data/incidents/daemon-outage-20261017_202813.json`: the initial port-9876 probe was refused, the registered daemon was started once, and `http://127.0.0.1:9876/ping` subsequently returned `ONLINE`.
- `Register-LcmDesktopDaemon.ps1 -Status` now reports `Legacy HKCU Run Key : ABSENT (expected)` and confirms the registered, online daemon without a StrictMode exception.
- PowerShell AST parsing passed for `Show-LcmControl.ps1` and `Register-LcmDesktopDaemon.ps1`.
- Focused Pester assertion `records and automatically attempts one daemon recovery before local fallback` passed: 1 passed, 0 failed.
- `git diff --check` passed.
- `Invoke-ProposalAction.ps1 -Action verify -TargetExpression BUG-286` moved the repair to `verified`; `Show-LcmControl.ps1 -NoLaunch` then rendered the current Hub artifact without opening or reloading a browser.
- One operator-authorized temporary BCR title probe reused the active F: mounted baseline and `_LCM` window, then verified the retained native title `_LCM - Folder Compare - Beyond Compare [BUG-286]`. The successful probe was promoted to live code: every reused or newly opened `_LCM` BCR window now appends the resolved CRP, BUG, or COH identity without changing the `_LCM` prefix.

## 3. Gate-2 Review Status
The operator confirmed the active `_LCM` Beyond Compare review window is showing BUG-286. The ledger was reconciled from `verified` to `in_review`, preserving `bcr_scope: BUG-286` and its existing review initiation timestamp. No acceptance, commit, or push was performed.

## 4. Known Baseline Test Failures
The complete `ControlHubSafety.Tests.ps1` file still has two unrelated failures in the pre-existing working tree:

- `routes row wizard lifecycle actions through the explicit active ITEM target` expects the exact literal `Do ITEM</button>`, while the current template generates the button through `lifecycleButton("Do ITEM", ...)`.
- `clears the BUG-276 obligation warning after the LCM_AI review resolves` has an existing review-obligation fixture mismatch.

Neither failure was introduced by BUG-286. They are not repaired or reclassified by this BUG.
