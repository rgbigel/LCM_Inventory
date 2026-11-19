# Specification: CRP-371

Module: docs/Proposals/371_CRP-References-Relative-To-The-Git-Root/Specification CRP-371.md  
Purpose: References Relative To The Git Root  
Path: LCM_Inventory/docs/Proposals/371_CRP-References-Relative-To-The-Git-Root/Specification CRP-371.md  
Authors: Rolf  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-19 16:56:39

```yaml
CRP-ID: CRP-371
Title: References Relative To The Git Root
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-19 16:56:39
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

Operator 2026-11-19 (global comment, Gate 2 review): absolute paths into the git root are "very bad", because CRP-253
needs the freedom of the drive letter and the path when LCM is used for sandboxing. All references inside the git root
must be relative to it ("Git_Repositories"). References outside the root (machine-installed tools) are not affected by
sandboxing and may stay absolute; there is no second root variable; a sandbox adjusts individual entries inside the
root (e.g. the runtimes table).

## 2. Gate 0 Contract

### Target State

T1 Canonical rule: references inside the git root are relative to it; code resolves the root at run time from its own
location or an explicit root parameter; docs write `LCM_Inventory/...` style paths. Outside the root, absolute paths
are allowed. Synced per RULE-AUTH-002.

T2 The stock is repaired: 240 files in LCM_AI (77), LCM_Inventory (126), LCM_Shared (11), LCM_Supervision (7) and
LCM_Tools (19) contain an absolute git-root path (outside data, logs, scratch and bundles; count of 2026-11-19).

T3 A check (readiness gate) reports new absolute in-root paths.

### Invariants and Exit Criteria

- Behaviour unchanged on the current machine; every changed script passes its syntax gate and tests.
- Exit: the count of T2 is 0 except documented exceptions (e.g. Windows scheduled task definitions outside the tree).

### Explicit Non-Goals

- Paths to machine tools outside the git root.
- Generated data under data/, logs and bundles (they are regenerated or historical).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Relation

- CRP-253 (sandboxing) depends on it; done in this session already: do.exe GetGitRoot, runtimes registry (CRP-361 review
  corrections). Planned with the JSON elimination and CRP-369 where the same files are touched.

## Operator Decisions (2026-11-19 17:32:57)

- Scope includes HaSSD06 and HaSSD06_Inventory (they live under the git root), besides the five LCM repositories.
