# Walkthrough: BUG-349 - Push Bundle Check Ignores LCM Inventory Bundle Home

## 1. Executive Summary
Implementation and verification records for BUG-349.

## 2. Verification Evidence
- 2026-11-17 14:53 PUSH dry run refused CRP-331: `Test-LCM_ProposalBundlesInHead` looked in LCM_AI HEAD (origin repo); the bundle is committed in LCM_Inventory (RULE-LCM-034).
- Fix 1 (14:55): `Resolve-LCM_ProposalBundleRepository` (governed LCM_* -> LCM_Inventory), `BundleRepository` in the push plan, used by the HEAD check; new test. Pester 7/7.
- 14:55 real push (`-SkipGemini`): LCM_AI pushed (e258f1c..bf13206); LCM_Inventory refused by `.githooks/pre-push` (`proposals.sql` uncommitted after export); no proposal moved to `pushed`.
- Fix 2 (15:05, operator principle): bundle check warns instead of throwing (returns false); `Invoke-LCM_Push.ps1` 10.2.4 step 2a exports and commits the SQL projections before pushing; RULE-EFF-001/002 amended (MethodEfficiencyPolicy 10.2.2), synced to AGENTS.md, cross-reference, Claude adapter, CANONICAL_HASHES (27C8B34CFBF3E697). Parse gate 0 errors (3 scripts); Pester 7/7; dump determinism verified (two dumps, identical hashes).
