# CRP-190: Antigravity Temporary Tool Guardrails and Preflight Rules

```yaml
CRP-ID: CRP-190
Scope: Temporary Antigravity IDE tools and transient PowerShell automation
Status: Completed
Plan-State: completed
Progress-State: completed
Maturity: Preliminary design record
Target-Repositories:
	- LCM_AI
	- Git_Repositories
```

## Problem

The failure-mode catalog identifies repeatable errors in transient automation: quote expansion corrupts PowerShell variables, StrictMode exposes undeclared variables, shared runtime files are mutated while locked, unsafe elevation paths fail late, and repeated prefix normalization is not idempotent. These are preventable before execution.

## Proposed Rules

1. **Managed Scratch Tool Boundary**: Multi-line or stateful temporary PowerShell must be created below `%TEMP%\Git_Repositories\Antigravity\Scratch\` with a unique `yyyyMMdd_HHmmss` name. Inline `pwsh -Command` is limited to simple single-expression probes.
2. **Command Transport Rule**: A command containing `$`, `$_`, assignment, a pipeline, redirection, or a script block must use a scratch `.ps1` file. When inline use is unavoidable, the outer transport must be single-quoted and variable expansion must be preserved.
3. **Temporary Script Preflight**: Before execution, a temporary `.ps1` must parse without PowerShell AST errors. Scripts using StrictMode must initialize every variable before a conditional or loop can read it.
4. **Shared Resource Mutation Check**: Before replacing, deleting, or truncating a daemon-owned catalog, log, or cache file, the tool must identify the owning process and either use the supported coordination path or stop without mutation.
5. **Privilege Dispatch Rule**: Temporary tools requiring Task Scheduler, cross-session desktop dispatch, protected paths, or machine-wide settings must delegate to the existing elevation runner rather than attempting direct privileged operations.
6. **Idempotence Rule**: A temporary transformer that normalizes names, prefixes, generated files, or configuration must include a repeat-run assertion proving the second run does not change the first result.

## Non-Duplication

The proposal extends, rather than replaces, current elevation policy and the atomic single-edit/editor review safeguards. It does not alter permanent-tool authoring standards.

## Current Rebaseline

The goals remain unchanged. The review accounts for current temporary-tool
practice: PowerShell 7 and managed scratch scripts for stateful commands. This
CRP remains the design and verification contract for a future guard helper; it
does not claim that helper has already been implemented.

## Success Criteria

- A guard helper rejects unsafe command transport before execution.
- AST, resource, privilege, and idempotence checks return actionable failures.
- Regression tests reproduce each cataloged failure category and prove the guard prevents it.
