# Implementation Plan: CRP-305 - Coordinated standard display freshness contract

## 1. Executive Summary & Problem Context
Operator selected Option B: shared freshness contract for coordinated display synchronization. Cover relevant data and presentation inputs, completion-aware publication, open-view reconciliation, visible stale/error states and snapshot preservation, reusing existing daemon notification infrastructure.

## 2. Gate 0 Traceability
- Dependency/revision inventory and shared coordination: criteria 1-4, 9.
- Open-view delivery, truthful status and refresh repairs: criteria 5-7.
- Snapshot safeguards: criterion 8.
- End-to-end validation and source atomization: criteria 10-11.
- Exclusive port-9876 page/asset/data delivery and outage behavior: criteria 12-13.

## 3. Proposed Changes
1. Inventory included display dependencies, governed mutation paths, existing
   routes and view-state persistence. Record known coverage gaps before editing.
2. Extract/reuse daemon revision/publication and event-delivery services in
   small focused components. Define operation status and atomic publication.
   Provide same-origin display/asset/data routes on port 9876; migrate local-file
   launches and remove ShowCM's existing offline file fallback.
3. Integrate ShowTools first: catalog synchronization, source and presentation
   invalidation, open-view delivery, recovery and explicit failure states.
4. Integrate Rules, Workspace Inventory, Control Hub and Dates data refresh using
   that same contract rather than duplicating refresh logic.
5. Label snapshot-only viewers and preserve selected historical evidence;
   ensure no auto-refresh path launches evidence producers.
6. Add focused tests and update related documentation/registrations. Reach
   exact-item review checkpoints in bounded increments; no automatic commit.

## 4. Verification Plan
- Unit/contract tests for dependency fingerprints, data/presentation distinction,
  missing/deleted inputs, coalescing, operation state and atomic publication.
- Failure tests: process starts but fails, slow render, malformed output,
  unreachable daemon, lost event/reconnect and out-of-order publication.
- Browser verification with an already-open view: add/edit/rename/remove a
  fixture tool; verify exact rendered revision and preserved user state.
- Verify shared template/script changes invalidate affected presentation;
  unrelated inputs do not trigger unnecessary regeneration.
- Verify no watcher-generated output loop, daemon request-loop blocking or
  implicit analysis/test/privileged execution.
- AST/JavaScript syntax, encoding and smallest focused existing regressions.
- Browser network/navigation assertions: all Standard Display delivery uses
  port 9876; no file: requests, temp/profile HTML launches or alternate-port
  fallbacks. Daemon recovery failure must report an error without opening files.
