# Walkthrough: BUG-288 - [BUG] Priority action advances held proposal lifecycle state

## 1. Executive Summary
BUG-288 records the unexpected lifecycle advance caused by a priority update.

## 2. Verification Evidence
- Reproduced: `Invoke-ProposalAction.ps1 -Action priority -TargetExpression BUG-287 -Priority L` correctly set priority to `3` but changed `state` from `held` to `in_progress`.
- BUG-287 was immediately restored to `held` through the proposal manager; its priority remains `3`.
- BUG-288 is held during the operator-led LCM on-disk review. No implementation or tests have been executed.
