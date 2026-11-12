# Walkthrough: CRP-252 - Multi-Stage System-1 Decision Cascade (Core PowerShell Pipeline & Fallback)

## 1. Executive Summary
CRP-252 implements the standalone PowerShell 7.6 (`pwsh`) backend pipeline for the System-1 Decision Cascade (`/v1/systemone` contract for `lev` / `strands-decider`) in `LCM_AI`. It establishes zero-latency deterministic pre-gating, a resilient HTTP decider client with strict timeout enforcement, and seamless fallback to existing LCM System-2 validation.

## 2. Implemented Components
1. **Stage 0: Deterministic Pre-Gate (`LCM_AI/tools/Test-LcmDeterministicGate.ps1`)**:
   - Zero-latency structural validation:
     - YAML frontmatter schema validation (`CRP-ID`, `Title`, `Scope`, `Status`/`Plan-State`).
     - Scope/Boundary validation (verifying target file paths match designated repo boundaries).
     - NTFS junction integrity check (`.agents\rules` -> `LCM_AI\.agents\rules`).
     - Elevation governance safety check (`RULE-ELEV-001..005`).
   - Hard structural failures exit immediately without triggering remote calls.

2. **Stage 1: System-1 Decider Client (`LCM_AI/tools/Invoke-LcmSystemOneClient.ps1`)**:
   - Encapsulates `/v1/systemone` HTTP protocol (`noul`, `choice`, `score` primitives).
   - Strict timeout: `<= 1500ms`.
   - Returns structured `[PSCustomObject]` contract (`Availability`, `Decision`, `Confidence`, `RequiresFallback`, `LatencyMs`, `RawResponse`).
   - Flags `RequiresFallback = $true` whenever unconfigured, offline, or confidence < threshold.

3. **Stage 2: Existing LCM Fallback Adapter (`LCM_AI/tools/Invoke-LcmStageTwoFallback.ps1`)**:
   - Seamlessly invokes existing LCM validation and System-2 evaluation tools (`Test-RepoReadiness.ps1` / `Test-GeneralReadiness.ps1`).
   - Guarantees zero functional regression when `lev` / `strands-decider` is unavailable.

4. **Orchestrator Façade (`LCM_AI/tools/Invoke-LcmDecisionGate.ps1`)**:
   - Authoritative entry point coordinating Stages 0, 1, and 2.
   - Emits standardized `[OK]` / `[FAIL]` telemetry with deterministic exit codes.
   - Normalizes output contract (`Status`, `ExecutionPath`, `Decision`, `Confidence`, `Reason`, `Timestamp`).
   - Optional diagnostic routing to `Show-LcmFailureDiagnostic.ps1` upon hard governance failure.

5. **Test Suite (`LCM_AI/tests/Test-LcmDecisionCascade.Tests.ps1`)**:
   - Automated 13-point test suite covering AST parsing, Stage 0 rejection, Stage 1 timeout/unconfigured handling, Stage 2 contract validation, and Orchestrator execution paths.

## 3. Verification Evidence
- **Automated Test Run**:
  ```powershell
  pwsh LCM_AI/tests/Test-LcmDecisionCascade.Tests.ps1
  ```
  Result: **13 PASSED, 0 FAILED** (100% pass rate).
- **AST Parse**: 0 syntax errors across all 4 new scripts.
- **Latency Bounded**: Offline timeout observed at ~539ms (well within the <= 1500ms fence).
