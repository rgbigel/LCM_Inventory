# Implementation Plan: CRP-190

## Planned Components

1. Add a narrowly scoped temporary-tool policy section to the authoritative LCM_AI rules.
2. Add a reusable preflight command or module that accepts a temporary script path and optional shared-resource targets.
3. Create the managed scratch directory contract and retention behavior.
4. Add Pester coverage for command transport, AST failure, StrictMode initialization, resource contention detection, elevation routing, and idempotence.
5. Integrate the preflight into temporary-tool generation paths without changing permanent tool behavior.

## Verification Plan

- Parser tests for malformed temporary scripts.
- Negative tests for double-quoted transport containing PowerShell variables.
- Tests simulating an owned shared resource and a privilege-required operation.
- A repeat-run test for generated-name normalization.
- Existing workspace readiness and rule-health checks.

## Deferred Decisions

- Whether the guard is a PowerShell module command, a pre-tool hook extension, or both.
- Scratch artifact retention duration and whether failed scripts are preserved for diagnosis.
