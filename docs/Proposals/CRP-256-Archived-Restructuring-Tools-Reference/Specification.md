# CRP-256 - Archived Restructuring Tools (Reference Material)

State: suggested
Origin: LCM_Inventory
Created: 2026-10-09

## Purpose

During the 7.x restructuring several one-purpose tools were built. Their migrations are finished and
they are no longer part of the active tool suite (`LCM_Inventory/tools/`, catalog and `Cmd/` trampolines
removed). The scripts are kept here as reference material for the app-centric architecture work (CRP-048,
CRP-161), the junction work (CRP-253 and a future SuperJunction scheme) and the Go migration (CRP-254).

## Reference scripts (`reference/`)

| Script | Original purpose |
|:---|:---|
| `Merge-RepositoriesToApps.ps1` | Merge an external repository into an umbrella repository as an `App: #` slice |
| `Split-LcmArchitectureToApps.ps1` | Decompose monolithic tripartite specs into per-App slices |
| `Split-LcmAppDocs.ps1` | Script form of the `Split-LcmAppDocs` function (the function itself lives on in `ProposalManager.psm1`) |
| `Invoke-LcmJunctionCorrection.ps1` | Create or replace one approved migration junction |
| `Initialize-SharedAiMemory.ps1` | Antigravity-era AI memory setup on a shared drive (historical) |

## Not included

`Update-Gemini.ps1` and `Sync-GeminiInbox.ps1` stay in `tools/`: `ProposalReviewFlowPolicy.md` names the
Gemini export as part of the mandatory PUSH pipeline. They need an operator decision.

## Proposed work

1. Decide per script: revive as an active tool, absorb into a new tool, or delete.
2. Nothing in this folder is executed by the workspace. Scripts here are not in the tool catalog.
