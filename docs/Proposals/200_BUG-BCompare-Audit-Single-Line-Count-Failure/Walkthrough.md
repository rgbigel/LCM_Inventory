# Walkthrough: BUG-200

## Reproduction

The CRP-199 review launched successfully, then failed after the visual session
closed with `The property 'Count' cannot be found on this object.`

## Repair

The normalized directive-line pipeline now always returns an array, including
when it contains exactly one line.

## Verification

- PowerShell AST parsing passed for `Invoke-BeyondCompareReview.ps1` and
	`Submit-ReviewResult.ps1`.
- `tests/BCompareReviewLifecycle.Tests.ps1` passed: 6 tests, 0 failures.
- A live Beyond Compare review launched for `LCM_Inventory` against
	baseline `4993fe3` under `BUG-200`. After the session closed, the staging
	audit completed successfully and wrote its receipt without the former
	scalar `.Count` exception.

## Review State

The repair is ready for the Gate 2 visual review disposition. No completion
selection or commit has been made.