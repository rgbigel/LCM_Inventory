# CRP-250 Walkthrough

## Initial Evidence

- CRP-249 completed the physical migration from `LCM_AI\tools`.
- Active Inventory runtime code still contains 330 `.lcm`, `Git_Root`, or
  environment-resolution references across command wrappers, tools, modules,
  and daemon classes.
- The GoodNight prototype initially invoked workspace maintenance directly
  before publish, risking daemon-log truncation before archival.

## Preserved Work in Progress

- `LcmWorkspaceContext.psm1` resolves machine-registry `Git_Root`.
- `Archive-LcmDaemonLogs.ps1` copies daemon logs to a timestamped archive with
  shared-read access.
- GoodNight, SaveAll, and ArchiveLcmDaemonLogs use registry-backed launchers.

The lifecycle remains in progress until every active runtime caller has been
migrated and the GoodNight/GoodMorning contract is fully reviewed.
