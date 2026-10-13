# Architecture: CRP-266 - Standard Display Model Controller Architecture

## Purpose

Define the LCM_Inventory Standard Display Interface and migrate the Control Hub as its
reference implementation. The interface establishes a thin presentation client, typed
controller endpoints, deterministic display projections, and independently testable
domain atoms.

## App: 1 - Display Model Controller (APP-001)

APP-001 owns the mandatory Standard Display Interface for LCM_Inventory.

### Responsibilities

- Serve authoritative display state through typed controller endpoints.
- Accept typed display intents rather than shell command strings.
- Validate request shape, target identity, and expected state revision.
- Route requests to public domain contracts.
- Return refreshed state, impact previews, notices, and structured errors.
- Catalog public request and response contracts in data/catalog/contracts.json.

### Boundary

Displays render returned state, collect explicit operator input, and present confirmations.
They do not determine lifecycle eligibility, construct PowerShell commands, mutate proposal
data, or infer cohort feasibility.

## App: 2 - Status Control (APP-002)

APP-002 owns authoritative Configuration Management lifecycle behavior.

### Responsibilities

- Determine permitted proposal lifecycle transitions.
- Validate proposal and cohort targets.
- Validate flow-switch, FIX, retirement, and supersession requests.
- Evaluate cohort membership feasibility and transition guards.
- Produce deterministic action availability and status projections.

### Public Contract

APP-001 calls APP-002 through declared public contracts only. APP-001 must not access
APP-002 private functions or implicit global state.

## Reference Migration

The Control Hub is the reference migration. Its browser client becomes a presentation
layer that calls typed controller routes. The existing generic command-execution route
remains compatible for legacy callers but is not the Standard Display Interface.

## Rollout Boundary

This CRP defines the platform contract and Control Hub reference migration only. Other
LCM displays migrate through subsequent CRPs after the reference implementation is
validated.
