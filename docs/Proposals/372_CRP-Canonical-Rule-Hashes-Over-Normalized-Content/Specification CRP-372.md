# Specification: CRP-372

Module: docs/Proposals/372_CRP-Canonical-Rule-Hashes-Over-Normalized-Content/Specification CRP-372.md  
Purpose: Canonical Rule Hashes Over Normalized Content  
Path: LCM_Inventory/docs/Proposals/372_CRP-Canonical-Rule-Hashes-Over-Normalized-Content/Specification CRP-372.md  
Authors: Rolf  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-19 17:06:02

```yaml
CRP-ID: CRP-372
Title: Canonical Rule Hashes Over Normalized Content
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-19 17:06:02
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

- Finding (2026-11-19): computing the hashes costs about 30 ms for 21 files once per session (Check 0 of
  `/goodmorning`); the overhead is document churn: 4 re-hash entries in `CANONICAL_HASHES.md` on 2026-11-19, 2 of them
  for formatting-only changes (line-ending conversion, header line breaks), each one a review item.
- Operator 2026-11-19 accepted: hash the normalized content instead of a configuration switch.

## 2. Gate 0 Contract

### Target State

T1 The hash of a canonical rule file is SHA-256 (first 16 hex) over its normalized content: line endings unified to LF
and trailing spaces and tabs of every line removed.

T2 One Python helper computes it (check mode for Check 0, update mode for a re-hash with one log entry); the
goodmorning skill and the re-hash step call it instead of inline hashing.

T3 `CANONICAL_HASHES.md` states the normalization, and its table is re-hashed once with the new method (one log entry).

### Invariants and Exit Criteria

- A content change still changes the hash; a formatting-only change (line endings, trailing spaces) does not.
- Exit: unit tests show both properties; Check 0 reports OK on the current rules; one log entry for the method switch.

### Explicit Non-Goals

- Hashing files outside `LCM_AI/.agents/rules`; a configuration switch.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Sequence

Implemented after the operator's Gate 2 accepts of CRP-361 / BUG-364 / BUG-368 / BUG-370 (operator 2026-11-19).

## Operator Decisions (2026-11-19 17:32:57)

- The shared hash helper lives in `LCM_Inventory/tools/` (catalogued, usable by every host).
