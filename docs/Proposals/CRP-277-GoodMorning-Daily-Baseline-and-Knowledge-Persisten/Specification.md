# Change Request Proposal: CRP-277

`yaml
CRP-ID: CRP-277
Title: GoodMorning Daily Baseline and Knowledge Persistence Routine
Scope: LCM_Inventory
Baseline-Version: 10.0.0
Author: rgbig
Date: 2026-10-15 14:31:18
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
`

---

## 1. Executive Summary & Intent
Define the explicit GoodMorning preparation that waits for and mounts today's
Macrium `D:` backup as the writable Beyond Compare LHS baseline, validates the
operator-owned review profile, and reports the selected baseline without
changing lifecycle rules. GoodNIGHT receipt/recovery requirements are in
CRP-278.

## 2. Technical Requirements & Invariants
- The operator is responsible for ensuring that an incremental or differential
  backup for the `D:` source volume is available before work starts each day.
- GoodMorning selects the newest usable restore point completed on the current
  local date. It mounts the backup at the configured LHS drive letter and
  verifies the expected `Git_Repositories` root.
- If today's eligible backup is unavailable, GoodMorning shows a visible
  waiting state, polls at a documented interval, displays the most recent
  eligible backup observed, supports cancellation, and ends according to a
  documented timeout/escalation policy.
- The routine must not silently use an older backup, create a backup, select a
  different drive letter, replace an active mount, or fall back to a Git or
  scratch baseline.
- The mounted LHS remains operator-managed reference content. GoodMorning must
  not inspect its contents as lifecycle evidence or infer review intent from
  it.
- The established Beyond Compare profile owns its filters, including the
  explicit `.git/hooks` positive override. GoodMorning validates the profile
  rather than rewriting its settings.
- Lifecycle transitions and review acceptance semantics remain unchanged.

## 3. Resolved Operational Decisions

- Macrium Browse Image and per-drive detach run through an elevated interactive
  worker. The worker selects only the image `D:` partition and enables
  restricted-folder access and writable mode through the Browse Image dialog.
- `F:` is the required baseline assignment. Before mounting, only matching
  mounted-image volumes in the bounded `F:`-`I:` range are detached. An
  alternate automatically proposed drive letter is an explicit failure, not a
  silent substitute.
- A Macrium same-day completion report is the authority for selecting the
  image. If today's report is absent, the configured definition is started
  once and the flow polls for a bounded period; an older image is never used.
- The existing GoodMorning recovery report remains intact and read-only by
  default. Baseline preparation is explicit through `-PrepareBcrBaseline`.
- The resolved CRP/BUG is recorded as the explicit RHS review scope in the
  baseline execution receipt. The operator-owned `_LCM` profile is never
  rewritten to carry lifecycle data. When no active CRP/BUG is available, the
  flow records the non-lifecycle `BCR-BASELINE-DUMMY` scope and creates no
  acceptance or completion evidence.
- GoodNIGHT Save All receipt and recovery enforcement are explicitly out of
  scope for this CRP and are owned by CRP-278.
