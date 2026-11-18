# Implementation Plan: CRP-359 - Bundle Document File Names Carry The Item ID

Date: 2026-11-18 16:11:42

## Changes per file
- `modules/ProposalSpecificationState.psm1` (10.2.2 -> 10.2.3): `Get-LcmBundleDocumentName`, `Resolve-LcmBundleDocumentPath` (new name, legacy fallback, single `<Kind> *.md` file when no ID is known); the lifecycle mirror resolves the Specification.
- `modules/ProposalManager.psm1` (10.2.7 -> 10.2.8): scaffold names and ledger fields; placeholder check; document fetch map; implementation-eligibility check.
- `tools/Invoke-ProposalAction.ps1` (10.2.5 -> 10.2.6): merge finding and rename use the resolver.
- `tools/Absorb-LcmContextRemark.ps1`, `tools/Link-LcmLearnedAdvice.ps1` (10.2.0 -> 10.2.1), `tools/Fix-Documentation.ps1` (10.2.0 -> 10.2.1): resolver.
- `assets/CM_CONTROL_HUB.html` (template 10.2.6 -> 10.2.7): "Show CRP" picks `<Kind> <ID>.md`, else the legacy name.
- Migration (one-time, scratch script): 18 open bundles, 54 files renamed; `Module:` / `Path:` header lines and ledger fields updated through `Get-ProposalStore` / `Set-ProposalStore`.
- Rules: `.agents/rules/ProposalReviewFlowPolicy.md` RULE-LCM-009 / -011, adapter RULE-LCM-009, `CANONICAL_HASHES.md`; `docs/Requirements.md` REQ-WINV-014.
- Tests: `ProposalScaffold.Tests.ps1`, `ProposalManager.Tests.ps1` (CRP-162 case) expect the new names.