# Implementation Plan: CRP-192

1. Define an inclusion manifest containing repositories, baseline references,
   repository-relative paths, and exclusions.
2. Materialize `Baseline` and `Working` trees with explicit repository roots and
   unchanged repository-relative paths.
3. Create a dedicated BCompare session with deterministic filters and stale
   same-repository review-window cleanup.
4. Verify same-named files from different repository paths remain distinct.
5. Keep compact review read-only: no staging, copying, committing, or pushing.