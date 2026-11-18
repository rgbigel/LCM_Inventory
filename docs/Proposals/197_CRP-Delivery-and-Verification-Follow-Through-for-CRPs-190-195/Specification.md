# CRP-197: Delivery and Verification Follow-Through for CRPs 190-195

```yaml
CRP-ID: CRP-197
Scope: Delivery and verification debt from CRPs 190 through 195
Status: Review
Plan-State: review
Progress-State: verification
Affected-Repos:
  - Git_Repositories
  - LCM_AI
  - LCM_Inventory
```

## Extracted Scope

1. **CRP-190**: Implement and test the temporary-tool guard helper and its
   PowerShell 7 command-transport, AST, resource, privilege, and idempotence
   checks.
2. **CRP-191**: Implement the repository index, metadata overlay, and
   `ShowRepos` command with discovery and metadata-safety tests.
3. **CRP-192**: Implement the opt-in compact BCompare review mode with explicit
   inclusion manifests, preserved repository-relative hierarchy, deterministic
   filters, and read-only behavior.
4. **BUG-195**: Add durable automated verification for same-repository stale
   BCompare review-window replacement, including safe process-selection rules.

## Exclusions

CRP-193 and BUG-194 have focused regression coverage and no unresolved
implementation obligation is extracted by this CRP.

## Delivery Rule

Published preliminary documentation is not evidence of feature delivery. Each
extracted component requires its own implementation evidence and focused tests
before it can be marked complete.