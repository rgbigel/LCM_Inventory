# Specification: CRP-339

Module: docs/Proposals/339_CRP-Single-Compact-Canonical-Rule-Set-with-Host-Bindin/Specification CRP-339.md  
Purpose: Replace the per-host rule projections by one compact canonical rule set in `LCM_AI/.agents/rules` (one MUST/MUST NOT line per rule, rationale and examples moved to `docs/`), loaded directly by every AI host, with host mechanics confined to one binding file per host.  
Path: LCM_Inventory/docs/Proposals/339_CRP-Single-Compact-Canonical-Rule-Set-with-Host-Bindin/Specification CRP-339.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-16 17:16:26

```yaml
CRP-ID: CRP-339
Title: Single Compact Canonical Rule Set with Host Bindings
Scope: LCM_AI
Target Scope: LCM_AI/.agents/rules (21 files), LCM_AI/docs (rule rationale), LCM_AI/.agents/hosts (new), LCM_AI/.claude (adapter retired to a junction), AGENTS.md, CLAUDE.md, LCM_AI/docs/LCM-Rules-Cross-Reference.md, rule export and health tools
Affected Version Range: 10.7.4
Impacted Repositories: [LCM_AI, LCM_Inventory, Git_Repositories]
Baseline-Version: 10.7.4
Author: Rolf, Claude
Date: 2026-11-16 17:16:26
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 8
App-ID: None
```

---

## 0. Registration Note

Created and registered by Claude (WORKPLAN D-29) on the operator's decision of 2026-11-16 (convergence question, option A): "keeping the rules short is something both .claude and .agents would profit from"; the low-quality parts of the canonical rules move into the docs. Fallback on trouble: daily Macrium backups, then Git.

## 1. Problem (measured 2026-11-16)

| | Files | Size | Loaded always |
|:---|---:|---:|---:|
| `LCM_AI/.agents/rules` (canonical) | 21 | 264 KB | 14 files, 206 KB (~50k tokens) |
| `LCM_AI/.claude/rules` (Claude projection) | 21 | 71 KB | 57 KB (~14k tokens) |

- The canonical files mix normative statements with rationale, history and examples; their size is the reason a condensed per-host projection exists.
- The projection causes the convergence overhead: baseline pinning, hash register (`CANONICAL_HASHES.md`), re-mapping, drift checks, the `translation/` folder, 43 `[Claude]` annotations scattered over 21 files, and paraphrase risk (two texts for one rule).
- Rule fixes are asymmetric: only one host edits `.agents/rules`.

## 2. Gate 0 Contract (RULE-GOAL-002)

- **Target State**:
  1. `LCM_AI/.agents/rules` is the only rule text for every AI host: each rule is one compact normative line (MUST / MUST NOT, rule ID kept), host-neutral.
  2. Rationale, history, examples and explanations live in `LCM_AI/docs/` (proposal: `docs/Rules/<PolicyName>.md`), linked by rule ID; nothing normative there.
  3. Each canonical file carries both frontmatter keys: `globs:` (Antigravity) and `paths:` (Claude Code) with the same patterns.
  4. Host mechanics live in one binding file per host, keyed by rule ID, same structure for all hosts (proposal: `LCM_AI/.agents/hosts/Claude.md`, `LCM_AI/.agents/hosts/Antigravity.md`); referenced from the host entry point (`CLAUDE.md`, `AGENTS.md`), not loaded as rules by the other host.
  5. `LCM_AI/.claude/rules` is a junction to `LCM_AI/.agents/rules` (no copy); `.claude/` keeps only host plumbing (settings, hooks, skills) that calls shared LCM tools.
- **Invariants**:
  - No normative content is lost: a mapping table (old section -> compact rule line or docs location) is part of the Walkthrough; RULE-DOC-008 removal approval is given by this contract, RULE-DOC-009 comment preservation applies to the moved text.
  - Rule IDs stay stable (1:1); no new or retired rule without an explicit line in this CRP.
  - Rule changes under ADMINMODE (RULE-REV-011) and BCR (RULE-REV-001); same route for every host.
  - Binding core invariant: "Cause no havoc: ask rather than invent or infer, and avoid unnecessary complexity."
- **Exit Criteria**:
  1. Always-loaded canonical rule text <= 60 KB (target; operator may adjust after the pilot).
  2. Every rule ID of the current baseline is present exactly once in `.agents/rules`; mapping table complete.
  3. Fresh session tests: Antigravity loads the rules unchanged in behaviour; Claude (`claude -p`) loads the always-on rules and a path-scoped language rule through the junction.
  4. `CANONICAL_HASHES.md`, the drift check and the Claude projection files are retired; `translation/` holds nothing that is still needed.
  5. `AGENTS.md` quick reference, `LCM-Rules-Cross-Reference.md`, `Update-Gemini.ps1` export and `Test-LCMRuleHealth.ps1` match the new layout (RULE-AUTH-002).
  6. Antigravity loading (unknown `paths:` key, ignoring `.agents/hosts/`) is checked in the operator's Gate 2 live test; if Antigravity rejects or ignores the rules, the repair is decided in that review (operator 2026-11-16).
- **Explicit Non-Goals**: no change of rule meaning (any semantic change is a separate CRP or an explicit line here); no change of the lifecycle or tools beyond the export/health/loading wiring; no work before the open cohort (CRP-331..336) is completed.

## 3. Procedure

See `Implementation_Plan.md` (moved there 2026-11-16; the Specification states what, the plan how).

## 4. Open Points

- Location and naming of the rationale docs (`LCM_AI/docs/Rules/` proposed).
- Who writes which part: pilot by Claude; canonical edits require ADMINMODE (operator account).
- `Update-Gemini.ps1` exports "21 files": does the Gemini mirror need the docs part too?

## 5. Acceptance

- 2026-11-16 17:16:26: Specification ACCEPTED by the operator (Rolf) in the baseline review (Gate 0 / RULE-LCM-014). Ledger state stays `suggested` until `do` / `Proceed`; work starts after the open cohort is completed.
