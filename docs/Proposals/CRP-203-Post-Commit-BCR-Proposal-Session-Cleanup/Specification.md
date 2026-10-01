# CRP-203: Post-Commit BCR Proposal Session Cleanup

```yaml
CRP-ID: CRP-203
Priority: Low
Scope: LCM_Inventory BCompare review lifecycle cleanup
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Affected-Repos:
  - LCM_Inventory
```

## Objective

Provide a dedicated tool that clears the dynamic Beyond Compare review session
and review artifacts associated with a committed CRP or BUG. Invoke it
automatically after a successful local commit so completed review work does not
accumulate stale BCR state.

## Requirements

1. The tool must target one explicit CRP or BUG identifier and repository.
2. It must remove only the matching dynamic BCompare named session, its BCR
   review cache, and its live/baseline junction artifacts.
3. It must preserve unrelated Beyond Compare saved sessions, open windows, and
   review artifacts for other proposals.
4. It must support a dry-run or equivalent preview before destructive cleanup.
5. `Submit-ReviewResult.ps1` must invoke the tool only after a successful local
   commit has been created and recorded.
6. Cleanup failures must be recorded as operational evidence without reversing
   a successful commit or publication state.

## Non-Goals

- No change to BCompare display filters, review materiality, or the `Peek`
  control.
- No cleanup of arbitrary user-created Beyond Compare sessions.
- No lifecycle or Control Hub redesign work from CRP-196.
- No retroactive removal of historical proposal, review, or Git evidence.