# Implementation Plan: CRP-275 - Tool Explorer Filter Pattern Matching

## 1. Executive Summary & Problem Context
Extend Tool Explorer field filters with simple case-insensitive wildcard matching: * matches zero or more characters, ? matches exactly one character, and $ anchors a pattern at the end of a value. Examples: Group:LCM*, Group:*abc, and Group:LCM$.

## 2. Proposed Changes

1. Extract a small, testable field-value matcher for the global Tool Explorer
   search syntax.
2. Preserve the current case-insensitive literal `includes` behavior when a
   pattern has no wildcard or trailing `$`.
3. Translate only `*`, `?`, and a final `$` to matching semantics; escape all
   other characters so user input cannot become arbitrary regular expression.
4. Use the matcher for each field-qualified branch in `matchRowSearch`, while
   preserving `!` exclusion behavior.
5. Update in-product filter help with supported examples and the explicit
   no-regex boundary.

## 3. Verification Plan

1. Verify the five acceptance examples in the specification against catalog
   rows with representative group, role, and description values.
2. Verify literal field filters and negated field filters retain current
   results.
3. Verify unsupported regular-expression constructs are interpreted literally
   rather than executed as regex.
4. Run the smallest existing JavaScript/browser regression coverage for Tool
   Explorer, followed by the relevant readiness gate.
