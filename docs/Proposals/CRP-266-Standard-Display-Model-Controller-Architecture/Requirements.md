# Requirements: CRP-266 - Standard Display Model Controller Architecture

## App: 1 - Display Model Controller (APP-001)

1. LCM_Inventory standard displays MUST obtain authoritative state through the Standard
   Display Interface.
2. Standard displays MUST submit typed target, action, parameter, and expected-revision
   requests. They MUST NOT assemble or execute PowerShell command strings.
3. Controller results MUST include a refreshed authoritative state or a structured error.
4. The controller MUST expose deterministic impact previews before destructive,
   exceptional, or multi-member actions are applied.
5. Display state MUST identify the target kind and identity explicitly. Supported target
   kinds are CRP, COH, and workspace.
6. Public request, response, and error contracts MUST be cataloged in
   data/catalog/contracts.json.

## App: 2 - Status Control (APP-002)

1. Status Control MUST be the sole authority for lifecycle transition eligibility.
2. Status Control MUST validate cohort membership proposals atomically. Failed validation
   MUST NOT create partial membership changes.
3. Status Control MUST preserve existing governance restrictions for reviews, testing,
   exact CRP identity, readiness, and push preflight.
4. Status Control MUST return explicit rejection reasons for unavailable lifecycle,
   cohort, flow-switch, FIX, retirement, and supersession actions.
5. Status Control MUST support unit tests without browser, daemon, or desktop dependencies.

## Compatibility

1. The existing Port 9876 daemon remains the transport host.
2. The generic execution route remains available for legacy callers during migration.
3. The Control Hub reference migration MUST not alter governed proposal data except through
   the same validated domain actions exposed by Status Control.
