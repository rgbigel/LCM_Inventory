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

## 3. Verification Plan
- PowerShell AST parsing and a successful review submission with durable
  unreviewed paths validates the helper-scope correction.
- Automated coverage must prove that dirty canonical-rule authority is added to
  the affected-repository review tabs rather than silently omitted.
