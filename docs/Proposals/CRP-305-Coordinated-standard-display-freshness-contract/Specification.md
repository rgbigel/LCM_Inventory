# Change Request Proposal: CRP-305

```yaml
CRP-ID: CRP-305
Title: Coordinated standard display freshness contract
Scope: LCM_Inventory
Baseline-Version: 10.2.1
Author: Rolf, Copilot
Date: 2026-10-21 21:55:00
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator selected Option B: shared freshness contract for coordinated display synchronization. Cover relevant data and presentation inputs, completion-aware publication, open-view reconciliation, visible stale/error states and snapshot preservation, reusing existing daemon notification infrastructure.

Specification accepted with "doIT 304, 305" at 2026-10-21 22:03:44 +02:00,
including the exclusive port-9876 delivery clarification. Implementation
activated through the canonical lifecycle action; acceptance scope retained
in the proposal ledger.

## 2. Gate 0 Contract
### Target State
Relevant LCM changes propagate through discovery, synchronization, publication
and delivery to affected standard displays. No display claims Current until
its rendered data and presentation revisions equal the latest valid published
revisions. No fixed sleep, process dispatch, daemon ping or recent generation
timestamp is treated as proof of freshness.

Operator clarification, 2026-10-21 22:02:03 +02:00: the existing LCM daemon
at http://127.0.0.1:9876 is the ONLY allowed browser-facing communication
and delivery path for Standard Displays. Local file URLs, direct browser
filesystem reads and local-file fallbacks are invalid, including during outages.

Apply one shared contract to the Inventory-owned ShowTools, Workspace Inventory,
Rules and CM Control Hub live displays. Include the Dates prototype's data
refresh behavior. Treat failure-analysis, functional-analysis and readiness
outputs explicitly as evidence snapshots, not automatically rerun analyses.

### Invariants and Exit Criteria
1. Maintain a concrete dependency manifest for the included displays covering
   relevant source/metadata, configuration, data, templates, scripts and styles.
   Record data and presentation revisions separately. Content changes, including
   rename/delete/create, invalidate the affected revisions.
2. Reuse existing daemon transport and refresh infrastructure behind small
   shared components; do not add an independent server, generic command
   executor, background service or parallel notification authority.
3. Governed writers invalidate affected displays. Filesystem reconciliation
   handles IDE/external edits and missed notifications. Watch notifications are
   hints, not proof of change or successful publication. Reconcile on startup,
   reconnect, focus and explicit Refresh without requiring an operator relaunch.
4. Refresh has explicit requested/running/published/failed states and carries an
   operation/revision identity. Publish a complete, validated revision before
   notifying views. Preserve the previous valid revision on failure; reject
   obsolete concurrent results rather than overwriting a newer revision.
5. Existing browser views consume published revisions, preserving filters,
   sort, selection, expansion and view mode where their targets still exist.
   Update data in place; presentation changes trigger a controlled transition
   to the published presentation revision.
6. Display Current, Updating, Stale, Failed and Disconnected truthfully, with
   last successful revision and explicit error information. Connection health
   does not certify data freshness. An already-open view may retain its last
   delivered content marked stale/disconnected, but no local-file fallback
   may be opened or read.
7. Remove obsolete refresh targets, swallowed refresh failures and arbitrary
   reload delays from the included surfaces. Explicit Refresh waits for or
   observes verifiable publication, not DISPATCHED.
8. Snapshot reports identify original evidence revision/time and snapshot
   status. Opening/reloading a snapshot never starts an audit, readiness test,
   privileged action or new analysis. Newer available snapshots may be offered,
   not silently substituted for the selected report.
9. Source/input events are bounded, debounced and coalesced. Rendering is
   serialized/coordinated to avoid recursive update loops, request-loop blocking
   and event storms caused by generated outputs. Recovery is deterministic.
10. Verify newly added/edited/renamed/deleted tool visibility in an already-open
    ShowTools view, shared presentation invalidation, inventory/rule/proposal
    updates, slow jobs, failed generation, malformed payloads, daemon outage,
    reconnection, missed events and state preservation.
11. Keep new components small and single-responsibility, with a target of at
    most 250 lines per new production file. Existing large files receive only
    necessary integration edits or cohesive extractions, not broad unrelated
    rewrites. Validate registration/documentation and actual visible revisions,
    not just endpoint responses.
12. Serve included Standard Display pages, templates/assets, data, revision
    status and events through the existing daemon on port 9876, using same-origin
    routes. No file: navigation, user-profile/temp HTML launch, direct browser
    filesystem dependency or alternate-port/server fallback. Retained evidence
    and backend templates may remain on disk; they are not browser delivery paths.
13. Remove ShowCM's existing daemon-offline file fallback as well as ShowTools'
    normal local-file launch. Reuse governed daemon recovery where applicable;
    if recovery fails, stop display opening with an explicit actionable error.
    Test outages and all included page/asset/data requests for HTTP-only delivery.

### Explicit Non-Goals
Do not change lifecycle authorization, review/commit rules or failure
classification. Do not run expensive or privileged evidence producers merely
because their snapshots are stale. Do not watch the entire disk or rewrite
every application. Child-owned Home Assistant displays and unrelated sibling
repositories are outside this implementation boundary; they require their
own inspected adapters before claiming workspace-wide coverage. No push.

## 3. Technical Requirements & Invariants
- Existing Control Hub completion refresh, SSE transport and proposal-document
  observation are prior art, not proof that all relevant changes are covered.
- The accepted contract requires a dependency/integration inventory before
  source editing, including each governed writer and rendering entry point.
- Work follows CRP-304 in operator-requested order, but neither item may
  reuse the other's review acceptance. Implement bounded, verifiable increments
  with explicit evidence and Gate 2 review.
- Production changes follow the accepted Specification. Exact review and
  operator disposition are still required before completion or commit.
