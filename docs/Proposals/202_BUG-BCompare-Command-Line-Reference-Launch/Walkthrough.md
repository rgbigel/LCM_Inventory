# Walkthrough: BUG-202

## Reproduction

`Invoke-BeyondCompareReview.ps1` opened Beyond Compare's command-line
reference before the requested comparison.

## Repair

The launcher now dispatches the saved named session after configuring it.
Focused validation and live launch verification are pending.