# CRP-372 Preparation: Canonical Rule Hashes Over Normalized Content

Module: data/analysis/CRP-372/Preparation.md  
Purpose: CRP-372 Preparation: Canonical Rule Hashes Over Normalized Content  
Path: LCM_Inventory/data/analysis/CRP-372/Preparation.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Analysis (preparation, read-only; nothing implemented)  
Date: 2026-11-19 17:27:06

---

## 1. Inventory (places that compute or name the canonical hashes)

| File | Line | Text |
|:---|---:|:---|
| `LCM_AI/.claude/rules/process/RuleAuthority.md` | 14 | - **RULE-AUTH-001** `LCM_AI\.agents\rules\` is the single authoritative rule source; no fo |
| `LCM_AI/.claude/skills/goodmorning/SKILL.md` | 26 | - Compare the SHA-256 (first 16 hex) of every `.agents/rules/*.md` with `LCM_AI/.claude/tr |
| `LCM_AI/.claude/translation/CANONICAL_HASHES.md` | 1 | # File: CANONICAL_HASHES.md |
| `LCM_AI/.claude/translation/CANONICAL_HASHES.md` | 3 | Module: .claude/translation/CANONICAL_HASHES.md |
| `LCM_AI/.claude/translation/CANONICAL_HASHES.md` | 4 | Purpose: SHA-256 (first 16 hex) of every canonical rule file at the last Claude convergenc |
| `LCM_AI/.claude/translation/CANONICAL_HASHES.md` | 5 | Path: LCM_AI/.claude/translation/CANONICAL_HASHES.md |
| `LCM_AI/.claude/translation/CANONICAL_HASHES.md` | 26 | \| File \| SHA-256 (16) \| |
| `LCM_AI/.claude/translation/WORKPLAN.md` | 48 | \| D-05 \| Rule baseline: LCM_AI commit `2bebbaa` (2026-11-14 18:58:18, LCM 10.6.4) + CRP- |
| `LCM_AI/.claude/translation/WORKPLAN.md` | 64 | \| D-23 \| (2026-11-14) At every convergence Claude writes `translation/CANONICAL_HASHES.m |
| `LCM_AI/.claude/translation/WORKPLAN.md` | 76 | \| D-27 \| (2026-11-14; revised 2026-11-17, CRP-350) Claude good-morning: operator types ` |
| `LCM_Inventory/tools/Fix-Documentation.ps1` | 236 | content_sha256 = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([S |
| `LCM_Inventory/tools/Get-RealRepoActionPlan.ps1` | 157 | $sourceHash = (Get-FileHash -Path $sourcePath -Algorithm SHA256).Hash |
| `LCM_Inventory/tools/Get-RealRepoActionPlan.ps1` | 161 | $targetHash = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash |
| `LCM_Inventory/tools/Invoke-CallerIntentReconciliation.ps1` | 334 | baseline_sha256 = (Get-FileHash -LiteralPath $BaselinePath -Algorithm SHA256).Hash |
| `LCM_Inventory/tools/Invoke-CallerIntentReconciliation.ps1` | 336 | forward_index_sha256 = (Get-FileHash -LiteralPath $ForwardIndexPath -Algorithm SHA256).Has |
| `LCM_Inventory/tools/Invoke-CallerIntentReconciliation.ps1` | 338 | reverse_index_sha256 = (Get-FileHash -LiteralPath $ReverseIndexPath -Algorithm SHA256).Has |
| `LCM_Inventory/tools/Invoke-LcmMajorCleanup.ps1` | 133 | return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInv |
| `LCM_Inventory/tools/Invoke-Level1AnalysisRefinement.ps1` | 332 | $definitionHash = (Get-FileHash -LiteralPath $DefinitionPath -Algorithm SHA256).Hash |
| `LCM_Inventory/tools/Invoke-Level1AnalysisRefinement.ps1` | 372 | $baselineHash = (Get-FileHash -LiteralPath $baselinePath -Algorithm SHA256).Hash |
| `LCM_Inventory/tools/Submit-ReviewResult.ps1` | 87 | $hash = [System.Security.Cryptography.SHA256]::HashData($bytes) |
| `LCM_Inventory/tools/Test-ReviewCommitGate.ps1` | 33 | $hash = [System.Security.Cryptography.SHA256]::HashData($bytes) |
| `LCM_Inventory/tools/Update-Gemini.ps1` | 117 | Write-Host "`n[4/4] Synchronizing .gemini Configuration Baseline & Computing SHA256 Hashes |
| `LCM_Inventory/tools/Update-Gemini.ps1` | 137 | $sha256 = [System.Security.Cryptography.SHA256]::Create() |
| `LCM_Inventory/tools/Update-Gemini.ps1` | 157 | $rootHash = (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash |
| `LCM_Inventory/tools/Update-Gemini.ps1` | 174 | Write-Host "  -> Baseline synchronized: $($files.Count) files (Root SHA256: $($rootHash.Su |

The hash is computed inline in the goodmorning skill (Check 0) and, on rule changes, by ad-hoc scripts; no tool or gate
reads `CANONICAL_HASHES.md`.

## 2. Steps

1. Python helper (e.g. `LCM_AI/.claude/tools/` or `LCM_Inventory/tools/`, location per operator) with `check` and
   `update --reason` modes; normalization: line endings to LF, trailing spaces and tabs removed, then SHA-256 (16 hex).
2. Unit tests: a content change changes the hash; line-ending and trailing-space changes do not.
3. Goodmorning skill step 3 calls the helper; `CANONICAL_HASHES.md` states the method and is re-hashed once (one entry).
4. No canonical rule text changes (the adapter files and the skill are Claude host files).

## 3. Dependencies

First of the rule-touching CRPs: afterwards the rule changes of CRP-371 / CRP-374 and every formatting fix produce no
hash churn.

## 4. Operator Questions

1. Location of the helper: next to the Claude adapter (`LCM_AI/.claude/`) or in `LCM_Inventory/tools/` as a catalog tool?
