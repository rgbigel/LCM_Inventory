# Implementation Plan: CRP-244

## Superseded Plan

No implementation is authorized for CRP-244. The original branch-and-rollback
idea is superseded by [CRP-251](../CRP-251-Sandboxed-Prototyping-Mode/Implementation_Plan.md),
which must establish a disposable isolation boundary before prototype work can
begin.

The retained design input is that an unfinalized analysis may need a practical
WHAT-IF experiment. CRP-251 preserves that capability without allowing a trial
to alter the governed workspace or to acquire authority through its own branch
history.
