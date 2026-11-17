# Implementation Plan: CRP-350 - Session Continuity Schema Convergence

Module: docs/Proposals/CRP-350-Session-Continuity-Schema-Convergence/Implementation_Plan.md  
Purpose: Steps and Gate 0 traceability for CRP-350.  
Path: LCM_Inventory/docs/Proposals/CRP-350-Session-Continuity-Schema-Convergence/Implementation_Plan.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: Suggested  
Date: 2026-11-17 15:28:03

---

## 1. Executive Summary & Problem Context

See `Specification.md` sections 1 and 3. One host (Claude) carries out every step, including Antigravity's adapter (target item 9).

## 2. Steps and Gate 0 Traceability

| Step | Change | Target item |
|:---|:---|:---|
| 1 | Add the schema as a canonical section of RULE-LCM-030 (`LCM_AI/.agents/rules/ProposalReviewFlowPolicy.md`), with ADMINMODE. In the same change set, amend RULE-LCM-030 (1) (cross-host adapter changes for accepted CRPs) and RULE-CTX-006 / macro table (operator exclusivity removed). RULE-AUTH-002 sync: `AGENTS.md`, `LCM-Rules-Cross-Reference.md`, `CLAUDE.md`, `.claude/rules/`, `GEMINI.md`. | 1-6, 8, 9 |
| 2 | `Save-AllSessionMemory.ps1`: anchor the replacements to section 1 explicitly instead of the first match. Touch `GoodNight Timestamp` / `Status: Quiescent` only with `-Quiescent`. | 1, 3, 5 |
| 3 | `Invoke-LCM_GoodMorning.ps1`: section 1 `GoodNight Timestamp` becomes the primary source, with `Saved:` as a labelled fallback. Print the workspace gap and each host's gap. Parse the full field list. Flag any host block older than the last GoodNight as stale. Add the DO liveness check and start. | 1, 4, 6, 7 |
| 4 | Claude skills: `goodnight` writes `Closed (<ts>)` and the full field list, and may run `Invoke-LCM_GoodNight.ps1 [-Push]` on operator instruction. `goodmorning` reports the workspace GoodNight and Claude's own close separately, runs the DO liveness check, and may run `Invoke-LCM_GoodMorning.ps1` on operator instruction. Update WORKPLAN D-26 / D-27. | 2, 4, 7, 8 |
| 5 | Antigravity adapter (`GEMINI.md`, `.agents/skills/workspace-governance`): Antigravity writes its own block at its close, takes "Resuming from" from section 1, stops copying host-block times, and loses the exclusivity note. Claude makes these changes and announces them in its block. | 2, 4, 8, 9 |
| 6 | LEARNED_ADVICE: remove "Operator exclusivity for GoodMorning", citing CRP-350, and keep its envelope intent. Add one candidate: "Workspace GoodNight = section 1 GoodNight Timestamp only; host close != GoodNight." | 1, 8 |

## 3. Verification Plan

- Parse gate on `Save-AllSessionMemory.ps1` and `Invoke-LCM_GoodMorning.ps1`. Pester against a temp copy of `.agents` only.
- Exits 1-5 of the Specification. Exits 1 and 2 need one Antigravity session, which the operator starts. This is a test step, not an Antigravity-only work item.
- BCR / Gate 2.
