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

## 5. Generate Caller-Intent Reconciliation Evidence

CRP-247 introduces Step 2 caller-intent reconciliation as a new immutable
derived artifact. It does not modify the retained Step 1 baseline.

From the `LCM_Inventory` repository root, run:

```powershell
pwsh .\tools\Invoke-CallerIntentReconciliation.ps1
pwsh .\tools\Show-LcmAnalysisViewer.ps1 -NoLaunch
```

The reconciliation generator reads the newest retained Level 1 baseline and
the published CRP-121 forward/reverse indexes. It refuses to overwrite the
matching `<baseline-run>-S020-CallerIntentReconciliation.json` artifact.

The viewer automatically loads the matching Step 2 artifact when it is
available. Its coverage rail separates:

- direct documentation;
- caller-context documentation;
- total documented coverage; and
- still-unresolved parameter gates.

Caller-context coverage is source-linked evidence from resolved production
callers. It contributes to total documented coverage but is never presented as
direct Step 1 documentation.

## 6. Header/Help Compliance Evidence

The workspace-wide script-header rule requires parameter help. Level 1 keeps
that compliance result separate from branch-gate documentation coverage: a
public parameter can require help even when it is never used in a conditional.

For PowerShell sources using CmdletBinding, the runner records a
`powershell_parameter_help_summary` in each immutable run. It inventories every
public script parameter and exported-module-function parameter, then treats a
scoped `.PARAMETER <Name>` entry as the PowerShell evidence adapter for the
universal header/help requirement. The summary reports documented and missing
entries and preserves a per-parameter source record.

Language-specific adapters for other script languages may use their native
header/help forms, but they must report against the same universal rule rather
than create duplicate language-local policy.

## 7. Retention and Cleanup

| Artifact | Location | Retention |
|---|---|---|
| Approved definitions | `data\analysis\definitions\` | Retain active and versioned history. |
| Immutable evidence JSON | `data\analysis\history\` | Retain until superseded and outside the $M-2$ horizon; preserve any CRP/ledger-referenced run. |
| HTML and Markdown views | `data\artifacts\`, session workspace | Regenerate from JSON; remove after the canonical JSON is verified. |
| Analysis logs | `data\logs\lcm\` | Treat as transient operational logs under the standard $M-2$ cleanup policy. |

At each major release, remove only unreferenced transient views/logs and superseded, unreferenced evidence older than $M-2$. Never delete active definitions, current evidence, CRP-linked evidence, or permanent-evolution evidence.
