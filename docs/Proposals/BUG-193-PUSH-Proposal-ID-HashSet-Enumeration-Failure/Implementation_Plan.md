# Implementation Plan: BUG-193

1. Replace the invalid `HashSet[int].ToArray()` call with PowerShell enumeration.
2. Run the focused push eligibility tests.
3. Rerun the explicit proposal-ID push preflight.
