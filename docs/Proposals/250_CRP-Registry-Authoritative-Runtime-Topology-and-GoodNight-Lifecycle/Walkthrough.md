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

The original lifecycle remained in progress while active runtime callers were
being assessed. The remaining CMD and Set-GitRoot authority work is now owned
by CRP-283.

## Supersession

CRP-250 is superseded by CRP-283 for the remaining machine-registry-only CMD
launcher and Set-GitRoot authority migration. Its delivered resolver, core
lifecycle adoption, retired `.lcm` topology cleanup, and GoodNight
archive-before-publish behavior remain preserved historical outcomes.
