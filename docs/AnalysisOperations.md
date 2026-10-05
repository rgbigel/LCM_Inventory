# LCM Consistency Analysis Operations

Module: docs/AnalysisOperations.md  
Purpose: Operator runbook for executing, viewing, retaining, and cleaning CON consistency analysis evidence.  
Path: D:/Git_Repositories/LCM_Inventory/docs/AnalysisOperations.md  
Authors: Rolf, LCM_AI Engine  
Version: 7.0.0  
Status: Operational Runbook  
Date: 2026-10-05  

---

## 1. Purpose

Consistency analyses compare LCM implementation evidence with the approved documentation and rule hierarchy. Each analysis has an operator-editable definition and a sequence of immutable evidence runs.

Level 1 is identified as `CON-001-L01`. It classifies named functional elements, public parameter gates, purpose/design-comment gates, and internal control flow.

## 2. Repeat Level 1

From the `LCM_Inventory` repository root, run:

```powershell
pwsh .\tools\Invoke-Level1AnalysisRefinement.ps1
pwsh .\tools\Show-LcmAnalysisViewer.ps1
```

The runner reads the approved definition at `data\analysis\definitions\CON-001-L01.json`, selects the next available immutable run ID, and writes the JSON evidence under `data\analysis\history\`. It never overwrites an existing run. The viewer selects the latest retained run by default and writes a regenerable HTML artifact under `data\artifacts\`.

To render a specific historical run:

```powershell
pwsh .\tools\Show-LcmAnalysisViewer.ps1 `
  -ReportPath .\data\analysis\history\CON-001-L01-R003.json
```

## 3. Before Repeating

1. Confirm the approved definition still expresses the intended goal, source scope, documentation order, classifications, and acceptance criteria.
2. Edit the definition only through an approved operator interview/change decision; do not edit JSON evidence to redefine the analysis.
3. Resolve a `Check 0: mismatch` or `Check 0: not found` result before relying on later documentation comparisons.
4. Review the new evidence in LCM Analysis Viewer and compare it with the prior retained run.

## 4. Immutable Evidence Content

Every retained run records:

- analysis/run identifiers and generation timestamp;
- definition path, version, and SHA-256;
- baseline evidence path and SHA-256;
- runner version and deterministic matching method;
- source scope, Step 0 rule-baseline evidence, and parser limitations;
- classification counts and complete per-element ordered documentation evidence.

This makes a historical result reproducible even after definitions or source code change.

## 5. Retention and Cleanup

| Artifact | Location | Retention |
|---|---|---|
| Approved definitions | `data\analysis\definitions\` | Retain active and versioned history. |
| Immutable evidence JSON | `data\analysis\history\` | Retain until superseded and outside the $M-2$ horizon; preserve any CRP/ledger-referenced run. |
| HTML and Markdown views | `data\artifacts\`, session workspace | Regenerate from JSON; remove after the canonical JSON is verified. |
| Analysis logs | `data\logs\lcm\` | Treat as transient operational logs under the standard $M-2$ cleanup policy. |

At each major release, remove only unreferenced transient views/logs and superseded, unreferenced evidence older than $M-2$. Never delete active definitions, current evidence, CRP-linked evidence, or permanent-evolution evidence.
