# Implementation Plan: BUG-202

1. Retain `Update-BCReviewSession` as the authoritative writer of review
   paths, filters, and comparison rules.
2. Change the BCompare launch handoff to pass the saved session name with the
   documented `/solo` switch.
3. Do not replay the generated comparison command line through the interactive
   desktop dispatch path. Beyond Compare can interpret that handoff as a
   command-reference request instead of opening the configured folder compare.
4. Always use `/solo` for dynamically written review sessions. A resident
   Beyond Compare process caches its session list; without a fresh instance it
   can treat the newly written session name as unknown and open the command-line
   reference.
5. Add a focused Pester contract preventing reintroduction of the long command
   line and requiring the `/solo` named-session launch.
6. Parse the launcher, run the focused lifecycle test suite, and launch one
   live BCompare review to confirm the folder comparison opens directly.