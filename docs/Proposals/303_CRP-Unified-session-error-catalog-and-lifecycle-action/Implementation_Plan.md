# Implementation Plan: CRP-303 - Unified session error catalog and lifecycle action diagnostics

## 1. Executive Summary & Problem Context
Reconstruct an evidence-based, active-host-specific failure-mode report from the historical catalog. Accept a bare item number or quoted conversation anchor, default to the last referenced item, combine read-only lifecycle diagnostics and Show-Actions output, and write a timestamped sibling report identifying generator name/version and including a Summary. Preserve original catalog and all lifecycle state.

## 2. Gate 0 Traceability
- Report command and host adapters: Specification exit criteria 1-5.
- Number-only target resolution and read-only lifecycle section: criteria 6-7.
- Action evidence and failure taxonomy: criteria 8-10.
- Timestamped output and integration/tests: criteria 11-12.

## 3. Proposed Changes
1. Add the Inventory report command with number/text selectors, active-host
   export reuse, offline transcript fallback, temporary-export cleanup, and
   explicit source provenance. Preserve access to native tool-result evidence
   where existing normalized exports omit error output.
2. Classify observed tool failures against the historical catalog, retaining
   source citations, unclassified errors, and explicit coverage gaps. Include
   category countermeasures without claiming inferred causes are proven.
3. Reuse canonical lifecycle diagnostics without invoking a valid action.
   Integrate a captured, read-only `Show-Actions.ps1` section; report missing
   optional evidence as a limitation.
4. Build a Summary and generator name/version header. Write a timestamped
   sibling report with collision-safe creation; leave the original untouched.
5. Add command registration, usage documentation, and focused tests. Regenerate
   catalog artifacts through the existing generator and keep unrelated work.

## 4. Verification Plan
- Parse every changed PowerShell source/test with the PowerShell AST parser.
- Run one focused Pester selection covering the new command and touched
  diagnostic behavior. Use fixtures for both hosts and tool-error payloads.
- Verify all seven categories, unclassified failures, literal text/number
  anchors, absent anchors, latest matching anchor disclosure, and no-item cases.
- Hash the ledger and original catalog before/after a live read-only run.
- Assert generator name/version, Summary, full time through seconds, filename
  shape, CRLF/UTF-8 encoding, no overwrite, and report path existence.
- Validate catalog/trampoline integration without running unrelated suites.
- Stop at the review checkpoint; do not commit or publish automatically.

## 5. Correction Revision Under Existing CRP-303

1. Reinstate the completed item through the canonical lifecycle action.
2. Retain physical JSONL lines, call/turn/parent IDs, arguments and tool titles.
   Preserve the global exporters; disclose the Antigravity metadata gaps.
3. Add line-aware `Invoke-Investigator`: reject diff/source/fenced text, require
   failure status, separate unresolved diagnostics, retain bounded runtime
   context, and optionally corroborate exact text in supplied operational logs.
4. Render successful/failed/unknown execution flow with explicit call linkage
   and separately labeled conversation context; omit synthetic error times.
5. Extend focused regressions and test the actual reported diff read-only.
   Update usage/catalog metadata and revision evidence, verify, then launch
   exact-item review for 303. No commit or push.
