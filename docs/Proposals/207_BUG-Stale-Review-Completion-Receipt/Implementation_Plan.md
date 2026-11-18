# Implementation Plan: BUG-207

1. Reproduce completion with no current staging manifest and verify that no
   receipt, commit, or scratch cleanup occurs.
2. Bind completion to the requested CRP, review baseline, and staging manifest.
3. Reject missing, stale, or mismatched review state before any side effect.
4. Add focused lifecycle tests for current, missing, stale, and mismatched
   manifests.
