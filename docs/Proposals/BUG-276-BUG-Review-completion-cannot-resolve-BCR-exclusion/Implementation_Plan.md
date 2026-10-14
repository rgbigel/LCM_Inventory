# Implementation Plan: BUG-276 - [BUG] Review completion cannot resolve BCR exclusions

## 1. Executive Summary & Problem Context
Submit-ReviewResult.ps1 defines Test-StandardBcrExcludedPath inside Get-StagedDiffSha256, but invokes it from the acceptance path. Any review manifest containing durable unreviewed paths fails before recording acceptance. Move the helper to script scope and validate the exact BUG review completion path.

## 2. Proposed Changes
### Component 1: Initial Implementation
- Move `Test-StandardBcrExcludedPath` to script scope so the review acceptance
  path can evaluate BCR manifests reliably.

### Component 2: Cross-Repository Review Accountability
- Detect durable en-route source changes in repositories declared as affected
  by the proposal and in the authoritative LCM_AI rules repository.
- Preserve exact per-repository BCR identity and require every affected
  repository, including LCM_AI rule changes, to be reviewed in its own next
  BCR cycle.
- Record the related repository review identity in the originating proposal or
  review receipt; never treat a BCR in one repository as acceptance for
  another.

### Component 3: Revision 2 Lifecycle Obligation Binding
- Add minimal ProposalManager ledger helpers for registering, enumerating, and
  resolving entries in the dedicated `review_obligation_ledger`, bound to a
  primary proposal.
- Bind Beyond Compare review discovery to register durable dirty sibling
  repositories before launch, including no-launch preparation.
- Resolve an obligation only when its own repository's accepted BCR receipt is
  written; retain the primary proposal's normal BCR completion path.
- Render unresolved obligations in ShowCM as `COH-<proposal-id>` synthetic
  Work Queue cohorts immediately after their BUG head in the active sort
  order. Include them in the normal cohort filter, retain their reason on the
  cohort row, and handle them through the existing normal cohort BCR action;
  provide a Review pending reason/hint, recreate missing session metadata under an isolated
  `<identity>_<repository>` review identity, and reject primary completion
  until the ledger is clear.
- Treat the isolated identity as the cleanup boundary: never delete its named
  Beyond Compare session definition or its scratch bridge while BCompare is
  active, and never let an obligation cleanup target the parent BUG bridge.

## 3. Verification Plan
- PowerShell AST parsing and a successful review submission with durable
  unreviewed paths validates the helper-scope correction.
- Automated coverage must prove that dirty canonical-rule authority is added to
  the affected-repository review tabs rather than silently omitted.
- Focused lifecycle tests must prove an unresolved obligation blocks primary
  completion and that an exact repository receipt resolves only that obligation.
- Focused lifecycle tests must prove active BCompare process guards preserve
  the exact named session and isolated scratch bridge.
