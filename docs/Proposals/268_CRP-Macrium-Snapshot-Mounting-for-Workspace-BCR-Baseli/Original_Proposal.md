# Original Proposal: CRP-268

**Title:** Macrium Snapshot Mounting for Workspace BCR Baselines  
**Status at intake:** Suggested  
**Origin repository:** LCM_Inventory  
**Priority:** 5  
**Record status:** Reconstructed on 2026-10-14 from authoritative proposal-ledger intake fields; original freeform wording was not retained.

## Intake Text

Extend the existing normal workspace review session definition with a tool call
that selects and mounts the most suitable read-only Macrium D: drive snapshot
as the historical baseline for changed-repository Workspace BCRs. Record the
snapshot identity, restore point, mount path, scope, and fallback behavior;
reuse existing changed-repository review filtering.

## Temporary Measures to Replace

The following measures were introduced only to keep review work progressing
while this proposal is being constructed. CRP-268 must replace them with one
coherent, review-gated design:

1. **Writable operator-managed LHS.** The Beyond Compare LHS is temporarily
   treated as writable operator-owned reference content. LCM must not read,
   write, hash, compare, clean, or infer review intent from it.
2. **RHS-only acceptance.** `ACCEPTED` temporarily stages eligible current RHS
   worktree changes after the operator accepts the review. The former
   LHS-derived `Completed`/`Uncopied` staging-manifest protocol was removed.
3. **No Git-derived LHS baseline.** The current Git-export baseline approach is
   unsuitable for the intended mounted Macrium snapshot workflow and must be
   replaced by an explicit snapshot selection, mount, identity, and fallback
   contract.
4. **Daemon availability workaround.** The desktop daemon currently has a
   scheduled-task watchdog for eventual recovery. CRP-268 must define the
   trusted action-time start, readiness check, and one bounded retry required
   for immediate ShowCM feedback.

These measures do not establish review semantics for the final solution. They
are temporary compatibility behavior to be superseded by CRP-268.

## Agreed Requirements for the CRP-268 Rewrite

### Persistent Workspace BCR Profile

1. The BCR baseline is a writable temporary mount of a Macrium Reflect backup
   of the complete `D:` drive, exposed through an operator-selected drive
   letter such as `F:`.
2. Beyond Compare compares `F:\Git-Repositories` as LHS with
   `D:\Git_Repositories` as RHS.
3. BCR opens the user-managed permanent profile named
   `_LCM_Git_repositories F:.>D:...`. Its profile settings define the roots,
   content comparison, changed-items display, and non-reviewable exclusions.
4. LCM may read the profile configuration to validate availability. It must not
   rewrite the permanent profile or treat unsaved temporary session XML as
   configuration authority.
5. BCR does not create per-CRP sessions, alter the session title, close the
   window, or reopen a window that the operator can reuse directly.

### LHS Ownership and Review Acceptance

1. The LHS is operator-managed reference content. LCM does not read, compare,
   hash, clean, stage from, or infer review acceptance or operator intent from
   LHS changes.
2. `ACCEPTED` remains the explicit operator review gate and stages eligible
   current RHS worktree changes only.
3. Lifecycle transitions are unchanged by this CRP.
4. After a successful accepted commit, LCM may reconcile only the exact paths
   included in that commit into the currently mounted LHS. The reconciliation
   must validate the mount, handle deletions, verify affected paths, and record
   a receipt.
5. Push does not change RHS content and requires no baseline action.
6. A revert may perform the same bounded LHS reconciliation only for explicit
   paths restored by that successful revert. It must not trigger a broad scan
   or inferred synchronization.

### Macrium Baseline Provisioning

1. A dedicated privilege-aware tool may query Macrium Reflect for usable
   backups of the intended `D:` source volume and mount a selected backup.
2. The operator is responsible for ensuring that at least one incremental or
   differential `D:` backup is available for each working day before work
   begins.
3. For an explicitly requested intra-day baseline, the tool presents the
   selected backup identity, restore point, completion time, mount path, and
   drive letter, then requires explicit confirmation before mounting.
4. The tool must never silently fall back to a Git-export, scratch baseline,
   older backup, or another drive letter.
5. It must not replace or detach a baseline while the BCR profile is active.

### GoodMorning Daily Baseline

1. GoodMorning selects the newest usable `D:` backup whose completion date is
   today, mounts it through the configured drive letter, and reports the backup
   identity, completion time, mount path, and selected drive letter.
2. This normal start-of-day action does not require confirmation because it
   selects an already-produced daily backup.
3. If today's eligible backup is not available, GoodMorning displays a visible
   waiting state, polls at a documented interval, shows the last eligible
   backup observed, and allows operator cancellation.
4. GoodMorning must not silently use yesterday's backup, create a backup,
   replace an active mount, or run indefinitely without visible status.

## Clarifications Required Before Implementation

1. Define the authoritative replay source for accepted commit/revert deltas
   after a writable mount has been unloaded: immutable Git commit content or a
   separate governed overlay store.
2. Define the maximum GoodMorning wait duration and its timeout/escalation
   behavior.
3. Define the configured preferred drive-letter source and the exact
   operator-resolution flow for an occupied letter.
4. Confirm the supported Macrium Reflect integration surface and the evidence
   required to prove that a selected restore point represents the intended
   `D:` volume.

## Verified Beyond Compare Test Findings

The 2026-10-14 F:-to-D: test established the following implementation facts:

1. The required comparison is the two-way folder scope
   `F:\Git_Repositories` (LHS) to `D:\Git_Repositories` (RHS).
2. The Beyond Compare saved session name must be command-safe. Profile labels
   containing path punctuation or comparison symbols can be parsed as files or
   comparison arguments. The operator renamed the working profile to `_LCM`.
3. The saved profile owns the configured `NameFilter`, including its explicit
   positive `.git/hooks` override, plus `dirCompareFilesOnly` and content
   comparison. Raw folder launches bypass these settings and can expose
   junction loops.
4. `NoEdit/Left` must not be present in the saved session XML: it disables the
   operator's writable-LHS workflow even when the mounted drive is writable.
5. A standalone `.session.xml` file opens as text when passed directly to
   Beyond Compare; it is a preserved configuration reference, not a direct
   folder-comparison launch argument.
6. The installed non-GUI `BComp.com` client can safely produce a read-only
   HTML folder-diff report by loading the two roots, applying the exact saved
   filter, and executing `folder-report`. It performs no copy or
   synchronization unless such commands are explicitly included.
