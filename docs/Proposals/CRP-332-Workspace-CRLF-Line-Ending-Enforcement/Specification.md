# Specification: CRP-332

Module: docs/Proposals/CRP-332-Workspace-CRLF-Line-Ending-Enforcement/Specification.md  
Purpose: Enforce the operator's line-ending decision (Option A: CRLF everywhere, no mixed setup) across all governed LCM_* repositories and the workspace root; implemented by Claude in DOIT (operator 2026-11-15).  
Path: LCM_Inventory/docs/Proposals/CRP-332-Workspace-CRLF-Line-Ending-Enforcement/Specification.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4
Status: Draft (awaiting operator review before Antigravity instruction)  
Date: 2026-11-15 15:56:40

```yaml
CRP-ID: CRP-332
Title: Workspace CRLF Line-Ending Enforcement
Scope: LCM_Inventory
Target Scope: .gitattributes of LCM_Shared, LCM_Supervision, LCM_Tools; working-tree text files of all governed LCM_* repositories and the root; LCM support tool writers and checkers
Affected Version Range: 10.6.4
Impacted Repositories: [LCM_AI, LCM_Inventory, LCM_Shared, LCM_Supervision, LCM_Tools, Git_Repositories]
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-15 15:56:40
Status: Verified
Plan-State: verified
Progress-State: verification
Priority: 5
App-ID: None
```

---

## 0. Registration Note

Created and registered by Claude with the operator's authorization (2026-11-15, WORKPLAN D-29): ledger id 332 via `New-LCM_Proposal`. Id 332 was the next free id in `proposals.db` at creation (read-only check). `Implementation_Plan.md` and `Walkthrough.md` are tool placeholders, to be filled by Antigravity.

## 1. Gate 0 Contract (RULE-GOAL-002)

- **Target State**: Every text file in the governed LCM_* repositories and the workspace root has CRLF line endings on disk, no file is mixed, and new or rewritten files stay CRLF regardless of which host or tool writes them.
- **Binding Principle**: "Cause no havoc: ask rather than invent or infer, and avoid unnecessary complexity."
- **Exit Criteria**:
  1. All six repositories carry the same `.gitattributes` line-ending block (`* text=auto eol=crlf` plus explicit per-type `eol=crlf`).
  2. A scan of the LCM_* working trees (excluding `.git`, binaries, `*.sh`) reports 0 LF-only and 0 mixed text files.
  3. (Revised 2026-11-15, operator) LF is allowed as a transient state; it is converted to CRLF at the latest at completion: `Submit-ReviewResult.ps1` normalizes every committable path before staging. No blocking LF gate.
  4. (Revised 2026-11-15) Claude converts its own writes immediately (PostToolUse hook); Antigravity writes are converted at completion. A CRLF correction is never a change LCM reviews.
  5. (Added 2026-11-15) D-17 of the Claude WORKPLAN is amended as part of this CRP (WORKPLAN D-29: the host that writes a bundle registers it).
- **Explicit Non-Goals**: No blocking LF check in gates; no change of the rule `newline-crlf` (it stays as is); no switch to LF (Options B/C of `NOTE-LineEndings.md` rejected); no content changes mixed into the conversion commit; no changes to non-LCM repositories.

## 2. Operator Decision

- 2026-11-15: Option A of `LCM_AI/.claude/translation/NOTE-LineEndings.md` - CRLF it must be, no mixed setup.
- 2026-11-15: LF introduced by third-party writes is corrected to CRLF by the AI host that notices it, without involving the operator.
- 2026-11-15: "ACCEPT 332, DOIT": implemented by Claude (not Antigravity); D-17 amendment is part of this CRP.
- 2026-11-15: Line endings are not important as a transient state, but hooks must convert LF to CRLF at the latest at completion (otherwise CMD code may not run). Correcting to CRLF is never a change LCM cares about.

## 3. Facts (measured 2026-11-14 / 2026-11-15)

- Git stores text as LF and checks out CRLF in the repos with `.gitattributes` (root, LCM_AI, LCM_Inventory; verified with `git ls-files --eol`: `i/lf w/crlf`). GitHub holds LF blobs; it has no line-ending setting and plays no role.
- Git converts only at commit (to LF) and at checkout (to CRLF); it never rewrites a working file after a commit. LF on disk therefore comes from writers after the last checkout.
- Example: `.agents/ACTIVE_SESSION.md` was `i/lf w/lf` on 2026-11-15. `Save-AllSessionMemory.ps1` (lines 121-135) and Claude's Edit tool preserve existing line endings, so a host's whole-file rewrite (native write tools emit LF) introduced it and the preserving tools kept it.
- LCM_Shared, LCM_Supervision, LCM_Tools have no `.gitattributes`: files are stored as written (mixed).
- About 400 LCM_* text files are LF-only or mixed (`NOTE-LineEndings.md` section 2.2, incl. 18 LF and 3 mixed `*.cmd`/`*.bat` trampolines, which `cmd.exe` may mis-parse).

## 4. Requested Changes

1. **`.gitattributes`**: add the LCM line-ending block to LCM_Shared, LCM_Supervision, LCM_Tools (copy of the LCM_AI file).
2. **One-time conversion**: convert all LF-only and mixed text files to CRLF in one commit per repository, separate from content changes. Precondition: the BCR `_LCM` profile classifies line-ending differences as unimportant (RULE-REV-001: EOL diffs never create review candidates); confirm before converting.
3. **CRLF check**: one shared check (e.g. in `LCM_QualityGates.psm1`) for all text types, not only JSON (`Test-LCMIncrementalGovernance.ps1` `NEWLINE-CRLF` today), used by the readiness gate and the minimal tests.
4. **Writers**: tools that build whole-file content emit CRLF (most already do: 25 files hard-code `` `r`n ``); line-preserving tools stay as they are.
5. **AI hosts**: each host normalizes its own whole-file writes to CRLF (Claude: already required by its adapter, `newline-crlf` [Claude] note); a corrective normalization of LF found in third-party writes is allowed without operator involvement.

## 5. Open Points for Antigravity

- Where the one-time conversion runs (a tool such as `Fix-Documentation.ps1`-style dry run plus `-Apply`, or a dedicated atom).
- Whether a pre-commit check should block LF working files (Git would store LF anyway; the problem is only the working tree).
