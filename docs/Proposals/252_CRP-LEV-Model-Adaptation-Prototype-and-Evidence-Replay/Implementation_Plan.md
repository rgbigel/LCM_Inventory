# Implementation Plan: CRP-252

## 1. Core Architecture Steps
1. **Stage 0 - Deterministic Pre-Gate (`LCM_AI/tools/Test-LcmDeterministicGate.ps1`)**:
   - Implement YAML frontmatter regex validator.
   - Implement repo boundary validator against `Scope`.
   - Implement NTFS reparse point checker for `.agents/rules`.
   - Implement elevation governance check (`RULE-ELEV-001..005`).
2. **Stage 1 - System-1 Decider Client (`LCM_AI/tools/Invoke-LcmSystemOneClient.ps1`)**:
   - Implement `/v1/systemone` REST client.
   - Implement strict timeout `<= 1500ms` using `HttpClient` or `Invoke-RestMethod -TimeoutSec 2`.
   - Parse `noul`, `choice`, `score` primitives.
   - Return structured `[PSCustomObject]` with `Availability`, `Decision`, `Confidence`, `RequiresFallback`.
3. **Stage 2 - Existing LCM Fallback & Escalation Adapter (`LCM_AI/tools/Invoke-LcmStageTwoFallback.ps1`)**:
   - Implement adapter calling `Test-RepoReadiness.ps1` or `Test-GeneralReadiness.ps1`.
   - Return normalized status matching LCM System-2 results.
4. **Orchestrator Façade (`LCM_AI/tools/Invoke-LcmDecisionGate.ps1`)**:
   - Orchestrate Stage 0 -> Stage 1 -> Stage 2.
   - Route failures to `Show-LcmFailureDiagnostic.ps1`.
   - Emit `[OK]` / `[FAIL]` structured console output.
5. **Unit & Integration Test Suite (`LCM_AI/tests/Test-LcmDecisionCascade.Tests.ps1`)**:
   - Test Stage 0 deterministic failure cases.
   - Test Stage 1 offline fallback (`RequiresFallback = $true`).
   - Test Stage 1 simulated online response.
   - Test Stage 2 fallback execution.
   - Test orchestrator end-to-end.
6. **AST Syntax Validation & Quality Gates**:
   - Validate AST syntax across all new files.
   - Verify zero-regression against existing tools.
