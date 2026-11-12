# Change Request Proposal: CRP-252

```yaml
CRP-ID: CRP-252
Title: Multi-Stage System-1 Decision Cascade - Core PowerShell Pipeline and Graceful Fallback
Scope: LCM_AI
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-12 08:45:00
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Gate-1: Accepted (2026-11-12 08:48:00)
Priority: 8
App-ID: None
Successor-ID: CRP-318
```

---

## 1. Architectural Objective & Multi-Stage Design
We are integrating a System-1 Decision Gate (`/v1/systemone` contract for `lev` / `strands-decider`) into our LCM 10.2.1 governance architecture (`D:\Git_Repositories\LCM_AI`).

To enforce strict separation of concerns and align with `GoalFirstDesignPolicy.md` (`RULE-AUTH-003`), this initiative is split into two sequential, decoupled Change Request Proposals:
- **CRP-252 (CRP-1: Core PowerShell Pipeline & Fallback Architecture):** Builds and verifies the standalone multi-stage `pwsh` scripts (Stage 0, Stage 1, Stage 2 Fallback, and the Orchestrator Façade) without altering active IDE workflows or rule matrices yet.
- **CRP-318 (CRP-2: Rule Authority Sync & Dual-IDE Integration):** Registers the new governance rule in `LCM_AI\.agents\rules\`, synchronizes all discovery matrices per `RULE-AUTH-002`, and integrates task definitions for Antigravity IDE and VS Code.

---

## 2. Gate 0 Contract

### Target State
1. **Stage 0 - Deterministic Pre-Gate (`tools/Test-LcmDeterministicGate.ps1`)**:
   - Pure, zero-latency `pwsh` structural validation:
     - YAML frontmatter schema validation (`CRP-ID`, `Title`, `Scope`, `Status`, `Plan-State`).
     - Scope/Boundary validation (verifying target file paths match designated repo boundaries).
     - NTFS junction integrity check (`.agents\rules` -> `LCM_AI\.agents\rules`).
     - Elevation governance safety check (`RULE-ELEV-001..005`).
   - Hard structural violations fail immediately with an explicit exit code without invoking Stage 1 or Stage 2.

2. **Stage 1 - System-1 Decider Client (`tools/Invoke-LcmSystemOneClient.ps1`)**:
   - Strictly encapsulates the `/v1/systemone` HTTP contract (`noul`, `choice`, `score` primitives).
   - Validates `$env:LCM_DECIDER_URL` and connectivity within a strict timeout (`<= 1500ms`).
   - Returns structured `[PSCustomObject]` contract:
     ```powershell
     [PSCustomObject]@{
       Availability     = [string] # 'Online' | 'Unconfigured' | 'Offline'
       Decision         = [string] # 'Approve' | 'Reject' | 'Defer' | 'None'
       Confidence       = [double] # 0.00 to 1.00
       RequiresFallback = [bool]   # $true if offline, unconfigured, or Confidence < $ConfidenceThreshold
       LatencyMs        = [int]    # Round-trip duration in milliseconds
       RawResponse      = [string] # Diagnostic response payload
     }
     ```

3. **Stage 2 - Existing LCM Fallback & Escalation Adapter (`tools/Invoke-LcmStageTwoFallback.ps1`)**:
   - Triggered when Stage 1 reports `RequiresFallback = $true` (e.g. `lev` / `strands-decider` is not deployed, offline, or confidence < 0.85).
   - Seamlessly invokes existing LCM validation and System-2 evaluation tools (`Test-RepoReadiness.ps1`) to guarantee zero functional regression.

4. **Orchestrator Façade (`tools/Invoke-LcmDecisionGate.ps1`)**:
   - The single entry point coordinating Stages 0, 1, and 2.
   - Normalizes output contract:
     ```powershell
     [PSCustomObject]@{
       Status        = [string] # 'PASSED' | 'FAILED' | 'ESCALATED'
       ExecutionPath = [string] # 'Stage0_Deterministic' | 'Stage1_Lev' | 'Stage2_Fallback'
       Decision      = [string] # 'Approved' | 'Rejected' | 'Deferred' | 'ManualReview'
       Confidence    = [double] # Score
       Reason        = [string] # Diagnostic reason string
       Timestamp     = [string] # ISO8601 second-precision (YYYY-MM-DDTHH:mm:ss)
     }
     ```
   - Emits standardized `[OK]` / `[FAIL]` telemetry with deterministic exit codes.
   - Routes hard governance failures to `D:\Git_Repositories\LCM_Inventory\tools\Show-LcmFailureDiagnostic.ps1`.

### Invariants and Exit Criteria
- **Zero-Regression Invariant**: When `$env:LCM_DECIDER_URL` is unset or offline, execution path transparently defaults to `'Stage2_Fallback'` with identical results to baseline LCM 10.2.1.
- **Latency Fence**: Stage 1 network call terminates within `1500ms`.
- **PowerShell 7.6.x Invariants**: StrictMode Latest, `$ErrorActionPreference = 'Stop'`, 2-space indentation, ASCII-only identifiers, single apostrophes for string literals, UTF-8 without BOM, CRLF line endings, zero backtick line continuations.
- **Mandatory Pre-Handoff AST Syntax Gate**: 100% clean AST parse via `[System.Management.Automation.Language.Parser]::ParseInput`.
- **Zero-Assumption Unit & Fallback Testing**: Complete test suite in `LCM_AI/tests/Test-LcmDecisionCascade.Tests.ps1` covering Stage 0 rejection, Stage 1 online mock, Stage 1 offline/timeout fallback, and Stage 2 escalation.

### Explicit Non-Goals
- Do not modify `AGENTS.md` or canonical rules in `LCM_AI\.agents\rules\` in this CRP (deferred to CRP-318).
- Do not modify `.vscode/tasks.json` or Antigravity IDE workflow hooks in this CRP (deferred to CRP-318).
- Do not alter existing proposal lifecycle states outside CRP-252.

---

## 3. File Inventory
- `LCM_AI/tools/Test-LcmDeterministicGate.ps1` (New)
- `LCM_AI/tools/Invoke-LcmSystemOneClient.ps1` (New)
- `LCM_AI/tools/Invoke-LcmStageTwoFallback.ps1` (New)
- `LCM_AI/tools/Invoke-LcmDecisionGate.ps1` (New)
- `LCM_AI/tests/Test-LcmDecisionCascade.Tests.ps1` (New)
