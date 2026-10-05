# Walkthrough: CRP-203 Post-Commit BCR Proposal Session Cleanup

## Summary of Changes

CRP-203 implements a dedicated post-commit Beyond Compare session and review cache cleanup tool to eliminate stale session drift in Beyond Compare and clean proposal scratch review artifacts.

### 1. Dedicated Cleanup Tool: `Clear-BCReviewSession.ps1`
- **Location**: [`LCM_Inventory/tools/Clear-BCReviewSession.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Clear-BCReviewSession.ps1)
- **Features**:
  - Targets explicit CRP/BUG identifiers (`CRP-###`, `BUG-###`) and repository scope.
  - Safely modifies `%APPDATA%\Scooter Software\Beyond Compare 5\BCSessions.xml` using XPath to isolate and remove only matching `TDirCompareSession` entries (e.g. `CRP-203_Review`, `CRP-203_LCM_Inventory_Review`), leaving user-created and other proposal sessions intact.
  - Purges the proposal-scoped scratchpad directory under `LCM_Inventory/scratch/BC_Review/<cleanCRP>` while safely unlinking all NTFS directory junctions prior to directory deletion.
  - Respects active BCompare runtime instances: if Beyond Compare is actively running, directory purge is deferred unless `-Force` is supplied, preventing "Fast refresh / Path not found" error dialogs.
  - Supports `-DryRun` preview mode returning structured metadata (`SessionsRemoved`, `FoldersPurged`, `DryRun`, `Success`) without performing destructive changes.
  - Provides full `-h` / `-Help` interactive command assistance.

### 2. Post-Commit Pipeline Integration: `Submit-ReviewResult.ps1`
- **Location**: [`LCM_Inventory/tools/Submit-ReviewResult.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Submit-ReviewResult.ps1)
- **Features**:
  - Invokes `Clear-BCReviewSession.ps1` immediately after a successful staged commit is created.
  - Non-blocking error handling: wrapped in `try/catch` with diagnostic logging, guaranteeing cleanup issues do not reverse or fail the commit.
  - Retains fallback scratchpad purge logic when metadata cannot be resolved.

### 3. Test Coverage & Verification: `BCompareReviewLifecycle.Tests.ps1`
- **Location**: [`LCM_Inventory/tests/BCompareReviewLifecycle.Tests.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tests/BCompareReviewLifecycle.Tests.ps1)
- **Validations Added**:
  - AST syntax parse validation for `Clear-BCReviewSession.ps1`.
  - Integration assertion verifying `Submit-ReviewResult.ps1` invokes `Clear-BCReviewSession.ps1`.
  - Unit validation verifying parameter rejection for invalid proposal identifiers.
  - Unit validation verifying `-DryRun` returns structured preview results without destructive execution.
  - Updated single-window tab reuse launch assertions (`BUG-245` alignment).

---

## Verification Results

### Pester Execution: `BCompareReviewLifecycle.Tests.ps1`
```text
Describing BCompare review lifecycle contracts
  [+] parses all review lifecycle scripts 85ms
  [+] normalizes single-line review directives to an array before Count checks 12ms
  [+] leaves review materiality to Beyond Compare insignificant-difference rules 42ms
  [+] uses one deterministic live-junction name per repository and CRP directory 8ms
  [+] opens the configured Beyond Compare named session without replaying command-line switches 8ms
  [+] derives post-commit cleanup from BCR review metadata 9ms
  [+] keeps the baseline-directory fallback when CRP metadata is unavailable 3ms
  [+] rejects completion without a current, matching BCompare staging manifest 6ms
  [+] creates receipts and purges scratch only after a real staged commit 9ms
  [+] creates a short-lived authorization bound to the reviewed staged diff 6ms
  [+] blocks commits without a current authorization for the exact staged diff 6ms
  [+] invokes Clear-BCReviewSession post-commit to purge dynamic Beyond Compare sessions 6ms
  [+] Clear-BCReviewSession rejects invalid proposal identifiers 58ms
  [+] Clear-BCReviewSession supports dry-run preview mode 116ms
Tests completed in 1.02s
Tests Passed: 14, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0
```