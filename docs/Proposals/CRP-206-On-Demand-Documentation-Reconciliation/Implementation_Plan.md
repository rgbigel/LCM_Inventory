# Implementation Plan: CRP-206

1. Define `FixDocumentation <crp-scope>` parsing, scope resolution, and
   dry-run output contract.
2. Build a source-evidence collector for proposal bundles, walkthroughs,
   execution receipts, and declared contracts.
3. Generate a section-level change manifest and conflict report before edits.
4. Apply approved documentation updates only to the authoritative tripartite
   target documents.
5. Record a reconciliation receipt and open BCompare for the generated diff.
6. Add tests for isolated scope, mixed CRP/BUG cohorts, dry run, ambiguity,
   conflicts, and no implementation/lifecycle mutation.
