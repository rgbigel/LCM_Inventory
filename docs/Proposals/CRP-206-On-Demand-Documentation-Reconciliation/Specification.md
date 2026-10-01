# CRP-206: On-Demand Documentation Reconciliation

```yaml
CRP-ID: CRP-206
Priority: 6
Scope: LCM documentation reconciliation command
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Affected-Repos:
  - Workspace_AI
  - Workspace_Inventory
```

## Objective

Provide an operator-invoked `FixDocumentation <crp-scope>` flow that reconciles
selected CRP and BUG delivery knowledge into the authoritative LCM tripartite
documentation at any time.

## Command Contract

`FixDocumentation <crp-scope>` accepts one or more explicit CRP/BUG identifiers
or an explicitly resolved cohort. It derives proposed documentation updates from
only that scope's reviewed proposal bundles, walkthroughs, execution evidence,
and declared contracts.

Before modifying documentation, the flow presents a change manifest that
identifies target documents, source CRPs, proposed sections, and unresolved
conflicts. It must not infer or promote unrelated, unreviewed, superseded, or
ambiguous work.

## Payload Contract

A selected proposal declares an applicable update in any bundle Markdown file:

````markdown
## Documentation Updates

### Architecture
```markdown
## Example Target Section

Declared content only.
```
````

`Architecture`, `Requirements`, and `Implementation` are the supported target
documents. `FixDocumentation` treats fenced content as opaque, adds a
provenance marker on apply, and refuses different payloads for the same target
document in the selected scope.

## Safety Rules

1. The command changes documentation only; it never applies implementation or
   lifecycle transitions for the selected scope.
2. The resulting documentation diff requires BCompare review before local
   commit.
3. Conflicting source decisions stop the affected documentation section and are
   reported for operator resolution; they are never silently merged.
4. The run records selected scope, source evidence, changed documents,
   unresolved items, review receipt, and disposition.
5. A dry-run mode produces the same manifest and proposed diff without writing
   documentation.

## Non-Goals

- No automatic workspace-wide documentation rewrite.
- No replacement of proposal bundles or review evidence.
- No change to the meaning or completion state of any CRP or BUG.
