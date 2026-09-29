# Walkthrough: CRP-191

## Gate 1 Record

The proposal was created after confirming that the existing inventory scanner detects Git and non-Git directories but has no explicit enrollment state, durable user metadata overlay, or `ShowRepos` interface.

The operator selected the governed-repository-first rollout. The initial implementation will index only `.git` repositories; the broader all-directory discovery design is retained as commented future work in the specification and plan.

## Implementation Status

No index schema, command, dashboard, metadata, or discovery behavior has been
introduced by this CRP. The operator confirmed that its goals remain active and
requested a current-design review. The preliminary design record is approved
and complete; future implementation remains separate work.
