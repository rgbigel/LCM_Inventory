# Implementation Plan: CRP-321

## 1. Phases
1. **Rule Codification (`LCM_AI/.agents/rules/DecisionCascadeGovernancePolicy.md`)**:
   - Author canonical rule with DOX metadata header.
   - Define `RULE-DEC-001` through `RULE-DEC-005` (incorporating Pre-Publish Triage and Stepwise Requalification).
2. **Requalification Module & Dynamic Remediation Engine (`LCM_Inventory/modules/LcmPushRequalification.psm1`)**:
   - Implement `Test-LcmPublishPreflight` to detect active relief switches and minimal-test proposal debt.
   - Implement `Show-LcmPublishTriagePrompt` offering the 4-choice interactive menu.
   - Implement `Invoke-RemediationStep` supporting dynamic step injection on anomalies.
   - Implement `Invoke-LcmStepwiseRequalification` executing the 5-stage qualification DAG.
3. **Publish Engine Integration (`LCM_Inventory/tools/Invoke-LCM_Push.ps1`)**:
   - Wire preflight triage check.
   - Add parameters: `-ForceRequalify`, `-BypassReliefGate`, `-NonInteractive`.
   - Implement post-push clean state reset.
4. **Standalone Tool (`LCM_Inventory/tools/Invoke-LcmPushRequalification.ps1`)**:
   - Provide on-demand manual CLI invocation.
5. **Quality Gates & Pester Verification**:
   - Author `Test-LcmPushRequalification.Tests.ps1` (9 unit/integration tests).
   - Run `Test-GeneralReadiness.ps1` across `LCM_Inventory` and `LCM_AI` (6/6 gates pass).
