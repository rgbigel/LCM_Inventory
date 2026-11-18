# Implementation Plan: CRP-196

1. Define the visible statuses `Open`, `Active`, `Review`, `Complete`,
   `Published`, `Held`, and `Cancelled`, including valid actions and legacy
   state migration rules.
2. Define the internal execution ledger, checkpoints, receipts, verification
   depths, and recovery routes without exposing them as Control Hub statuses.
3. Define the LCM Query Index projections for proposals, repositories, runs,
   artifacts, actions, tools, interfaces, messages, and workflows.
4. Define direct NTFS source access, `es.exe` discovery, and port 9876 command
   and event transport boundaries.
5. Refactor lifecycle services so BCompare review compares the pushed baseline
   to live work; acceptance creates the local commit and moves to `Complete`.
6. Add CRP-specific immutable review snapshots on `accepted` and `accepted
   with changes`; refresh BCompare sessions so any snapshot can be selected as
   the left side without modifying the live right side.
7. Require a final pushed-baseline-to-live roll-up review before local commit,
   regardless of prior snapshot decisions.
8. Build the standard-display work queue conforming strictly to `DisplayStandardsPolicy.md` 10.0.0 and `CM_CONTROL_HUB_IMPLEMENTATION_0.html`: presets, mode, Intern, filters, integrated sorting, reset controls, and global commands.
9. Replace the sidecar with a full-width selection and bulk-action work area
   that exposes only actions valid for the selected cohort.
10. Show Status, Plan State, Progress Status, numeric priority, busy phase, and
   `Failed for <reason>` indication without exposing every internal phase as a
   lifecycle status.
11. Expose execution switches in the Control Hub and record their effective
   values in each execution run.
12. Sort bulk cohorts by numeric priority $10$ through $0$ and provide a
    dependency-, risk-, reversibility-, and validation-cost-aware recommendation
    order for equal-priority items.
13. Maintain the root-owned Control Hub application as the operational UI,
   clearly identify live instances, and advance each behavior increment
   through review before enabling lifecycle mutation.
14. Add migration, transition, action-validity, query-index, UI workflow,
   review, verification-depth, and no-push-before-review tests.