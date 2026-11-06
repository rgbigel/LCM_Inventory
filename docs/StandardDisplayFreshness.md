# Standard Display Delivery and Freshness

Module: LcmDisplayCoordinator
Authors: Rolf, Copilot
Version: 10.0.1
Date: 2026-10-21

## Delivery

Standard Displays open through the existing daemon at
`http://127.0.0.1:9876` only. The live routes are `/tools`, `/rules`,
`/inventory`, `/hub` and `/dates`. Styles, scripts and data use the same
origin. Browser-facing `file:` URLs, user-profile HTML launches, alternate
ports and daemon-offline file fallbacks are not supported.

Generated artifacts and evidence still exist on disk as backend inputs and
retained outputs. Their existence is not an instruction to open them directly.
The daemon serves allowlisted routes, not arbitrary filesystem paths.

After updating the daemon sources, restart the existing daemon to load the
new modules. The `/ping` response advertises `standardDisplays: 1`; launchers
refuse an older daemon explicitly rather than falling back to files.
The shared launcher passes the HTTP URL itself to the interactive desktop
dispatcher, allowing Windows to use the registered browser association rather
than invoking File Explorer with a URL argument.
The shared launcher makes one existing-daemon recovery attempt if offline.
The Tool Explorer badge identifies the constructing script and renderer template
separately (`LCM-Show: vX.Y.Z Template: vA.B.C`), reading their `Version:` metadata
at render time rather than displaying the global baseline as a tool version.
Maintain those semantic versions when revising either component; rendering does
not invent version increments. Both sources are presentation dependencies, so
their changes invalidate already-open views.

All five live displays and newly generated failure-analysis, CON analysis, and
readiness snapshots use `LcmDisplayVersion.psm1` to read semantic versions from
source metadata comments. Missing, malformed, or duplicate version fields fail
explicitly; document payloads and global baseline defaults are not substitutes.
For embedded templates (Rules, CON analysis, readiness), both axes refer to the
same source file. Separate HTML templates have their own metadata headers.
Retained snapshots keep the versions recorded when they were constructed.

## Live revisions

The [dependency manifest](../modules/LcmDisplayDependencies.psm1) declares
data and presentation inputs separately. Catalog discovery locations are
shared with the catalog generator, including child-owned tool sources.
Inventory documentation and proposal documents are dependencies too.

Each open view reconciles its dependency revision on startup, focus,
reconnection, explicit Refresh and periodic status requests. Content hashes
detect edits, creates, renames and deletions, even with unchanged file times.
No additional service or whole-disk watcher is introduced. Poll requests are
coalesced; fingerprint checks are rate-limited.

The coordinator starts only a fixed allowlisted renderer in a child process.
It does not wait in the HTTP request loop for rendering to finish.
`Updating` is not `Current`: only a successful, validated output is published.
Presentation/source changes during a render invalidate that result. A failed
or timed-out render preserves the previous published bytes, reports `Failed`
and identifies its operation log. Explicit Refresh retries; a new input
revision can also recover a failed publication.

Status and content responses use `Cache-Control: no-store`. A content revision
header prevents applying bytes from a different publication than the status
being reconciled. The delivered HTML also carries its presentation revision,
so a change between initial navigation and the first status response cannot
mix an older script/template with newer data. A publication needs a valid
structured JSON object before it can be Current.
Data adapters update the current view in place; a changed
presentation revision triggers a controlled HTTP reload with view state
preservation. There is no fixed delay interpreted as successful refresh.

The visible status distinguishes Current, Updating, Stale, Failed and
Disconnected. Daemon connectivity alone never certifies current display data.
An already-open disconnected view may retain its last delivered content,
clearly marked; it does not open a local cached HTML file.

## Retained evidence

Failure-analysis, functional-analysis and readiness reports are historical
snapshots. Their HTML is served under an opaque retained snapshot route on
port 9876. Opening or reloading a snapshot does not run an analysis, audit,
readiness test or privileged command. Source evidence and its collection time
remain authoritative for what the report observed, not current system state.

## Operations

- Launch existing commands such as `ShowTools`, `ShowRules` and `ShowCM`.
- Refresh uses `/displays/refresh/{id}` and observes completion through
  `/displays/status/{id}`; `DISPATCHED` is never considered publication.
- Publication logs are under `data\logs\lcm\displays`, keyed by display and
  operation ID.
- The daemon must remain available on port 9876. A failed recovery or missing
  route is an explicit error, not permission to use a file-based display.

Existing tabs opened with `file:` before this upgrade must be closed and
reopened once through their command. The daemon cannot replace a browser page
that was loaded from an unrelated filesystem origin. Subsequent revisions of
the HTTP-delivered view reconcile automatically.
