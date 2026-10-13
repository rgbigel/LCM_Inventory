# CRP-254: Go Implementation Path for Inefficient Scripts

| Metadata Field | Value |
|---|---|
| **Proposal ID** | `CRP-254` |
| **Lifecycle State** | `SUGGESTED` |
| **Origin Repository** | `LCM_AI` |
| **Date** | 2026-10-13 |
| **Governing Rule** | `GoRules.md` (`LCM-RULE-GO-001`) |

## Objective

Provide an evidence-driven path for migrating selected slow or heavy
PowerShell and Python tools to Go executables, without a blanket rewrite.

## Required Contract

- Candidates are chosen by measurement (startup time, runtime on large trees,
  memory), not by preference. Typical candidates: workspace scans, junction and
  hash audits, log and archive flushing, catalog generation, path migration.
- Every Go tool follows `GoRules.md` and lives in LCM_AI with its source,
  tests and a built binary location defined by the registry-authoritative root.
- The existing PowerShell entry point stays as a thin wrapper that calls the
  binary, so short names, the Tool Explorer catalog and callers do not change.
- Parity is proven by running old and new implementation on the same input and
  comparing outputs before the script body is retired.
- Go toolchain installation, module layout, build and release flow are
  defined once and reused by all Go tools.

## Phases

1. Inventory and measure: rank existing tools by cost; pick 2-3 pilots.
2. Toolchain and scaffold: module layout, build script, test gate.
3. Pilot migration with parity evidence.
4. Roll out remaining candidates, one CRP-sized step each.

## Non-Goals

- Do not rewrite tools that are fast enough or rarely run.
- Do not introduce Go for interactive GUI tools.
- Do not change tool names, catalog entries or governance behaviour.
