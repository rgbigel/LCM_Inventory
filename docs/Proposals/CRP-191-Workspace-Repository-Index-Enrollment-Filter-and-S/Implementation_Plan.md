# Implementation Plan: CRP-191

## Planned Components

1. Extract governed-repository discovery from the existing `WorkspaceCM` scanner into a reusable `WorkspaceRepositoryIndex` module owned by `LCM_Inventory`.
2. Generate the scanner-owned index and merge its records with the user-owned metadata overlay.
3. Add `Show-Repos.ps1` with a `ShowRepos` launcher entry, console matrix, filters, and optional HTML report.
4. Add explicit metadata-only mutation commands with schema validation and audit logging.
5. Add an all-changes view or panel consuming the index, with repository grouping as a filter rather than a visibility boundary.

## Safety Boundaries

- Discovery is read-only.
- The index refresh does not initialize Git repositories or alter `.git` state.
- Metadata commands modify only the LCM_Inventory overlay.
- A physical repository rename or deletion remains outside `ShowRepos` and requires a separately governed workflow.

## Verification Plan

- Fixture workspace containing root Git, nested Git, and junction-backed repositories.
- One-row-per-canonical-governed-repository and no-hidden-repository assertions.
- Filter tests for `All` and `Governed`.
- Metadata set, display-name rename, attribute removal, and metadata deletion tests proving the source directory is unchanged.
- HTML/console parity test for computed version and state columns.
- AST, JSON schema, and workspace readiness checks.

## Open Design Decisions

- Whether `.git` files used by linked worktrees qualify as `Governed` alongside `.git` directories.
- Which root infrastructure directories are discoverable by default versus listed as `Excluded` with rationale.
- Whether change data refreshes on demand, through the existing daemon, or both.

<!-- FUTURE OPTION 1 - NOT IMPLEMENTED IN THIS CRP INCREMENT
Add non-Git directory discovery and enable the NotOnboarded, Excluded, and Missing enrollment filters. Use the initial index and metadata overlay without changing their governed-repository contract.
-->
