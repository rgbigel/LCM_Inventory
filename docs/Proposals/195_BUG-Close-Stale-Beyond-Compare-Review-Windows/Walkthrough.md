# Walkthrough: BUG-195

## Failure

Repeated review launches accumulated obsolete BCompare tabs and the review view
refreshed while the operator was inspecting it.

## Remediation

The launcher finds BCompare folder-compare windows whose title identifies the
same repository and closes them before opening the replacement review.

## Verification

The stale `LCM_Inventory` BUG-194 review window was closed and exactly
one replacement BUG-194 review window was launched without the `-Wait` audit
path.

## Review

The operator reviewed the current BCompare session and authorized completion.