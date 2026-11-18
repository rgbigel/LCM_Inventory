# Implementation: CRP-266 - Standard Display Model Controller Architecture

## App: 1 - Display Model Controller (APP-001)

1. Define typed DTOs and JSON schemas for display-state queries, action previews, action
   execution, successful results, and structured errors.
2. Create the Standard Display Interface contract catalog at
   data/catalog/contracts.json.
3. Add a dedicated Control Hub controller that exposes typed state, preview, and execution
   routes through the existing daemon.
4. Add revision-aware request handling so stale display state is rejected explicitly.
5. Refactor the Control Hub client to render controller state and submit typed requests.
6. Retain only presentation, local filtering, accessibility, menus, dialogs, and response
   rendering in the browser.

## App: 2 - Status Control (APP-002)

1. Extract lifecycle transition evaluation into a dedicated status-control atom.
2. Extract cohort membership validation into a dedicated atom.
3. Extract flow-switch and FIX validation into dedicated atoms.
4. Expose only explicit public contracts consumed by APP-001.
5. Preserve existing lifecycle and governance behavior while removing duplicate client-side
   policy decisions.

## Verification

1. Unit-test every status, cohort, flow-switch, and FIX atom independently.
2. Contract-test all controller requests and responses against their JSON schemas.
3. Verify that invalid actions return structured errors without changing state.
4. Verify that previewed multi-target impacts match the executed result.
5. Verify that the Control Hub reference migration does not send generic PowerShell command
   strings for Standard Display Interface actions.
6. Validate PowerShell AST syntax, JSON schemas, and focused UI behavior.
