# Change Request Proposal: BUG-311

```yaml
CRP-ID: BUG-311
Title: [BUG] Repair Macrium Daily Baseline Selection, BCompare Non-Interference, and Direct Intent Mapping
Scope: LCM_Inventory, LCM_AI
Baseline-Version: 10.1.0
Author: Rolf, LCM_AI Engine
Date: 2026-11-09 17:20:00
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Repairs critical flaws identified during operator critique of BCR execution telemetry:
1. Fast-path logic previously prioritized any existing mounted drive (`H:`) without checking if a newer completed Macrium backup image existed for the current calendar day (`B:\Backups\D4P3+4-WDB850-AD\C425281FE84743F1-@B_D4P3+4-WDB850-AD-09-09.mrimgx`), leading to silent reuse of stale baselines.
2. Premature termination of Beyond Compare processes via `MainWindowHandle -eq 0` checks killed BCompare during normal window initialization, triggering misleading diagnostic errors.
3. Rigid single-window assertions (`Count -ne 1`) disrupted operator workflows when multiple BCR sessions or windows were open.
4. Linear search through documentation to discover commands was replaced with a structured intent-to-command catalog (`LCM_Inventory/config/tool_intents.json`).
5. Reinforced governance rules against speculative code-dumping prior to execution (`RULE-EFF-009`), visual review process interference (`RULE-REV-012`), and bounded retry loops (`RULE-LCM-017`).
6. Decoupled Macrium backup production from `Invoke-LCM_GoodMorning.ps1`, establishing `Start-MacriumDailyBackup.ps1` as an isolated atom executed at operator discretion with optional `-Mount` delegation.

## 2. Gate 0 Contract
### Target State
- `Invoke-MacriumDailyBcrBaseline.ps1` checks for today's completed `.mrimgx` before evaluating candidate reuse. If an existing mount is stale relative to today's completed image, it warns the operator and proceeds to mount today's fresh backup.
- BCompare processes are never killed or asserted to have a single instance.
- Direct intent mapping is codified in `LCM_Inventory/config/tool_intents.json`.
- Backup generation is cleanly removed from `Invoke-LCM_GoodMorning.ps1` and isolated into `Start-MacriumDailyBackup.ps1` with `-Mount` support.
- All Pester tests in `MacriumBcrReview.Tests.ps1`, `LcmMacriumAtoms.Tests.ps1`, and general readiness gates pass 100%.

### Invariants and Exit Criteria
- `RULE-EFF-009`: Anti-Code-Reading & Direct Goal Execution Invariant.
- `RULE-REV-012`: Review Tool Window Non-Interference, Title Neutrality & Baseline Currency Invariant.
- `RULE-LCM-017`: Strict 2-Attempt Loop Breaker.
- 16/16 Pester tests passing across `MacriumBcrReview.Tests.ps1` and `LcmMacriumAtoms.Tests.ps1`.
- 6/6 General Quality Gates passing in `LCM_Inventory` and `LCM_AI`.
