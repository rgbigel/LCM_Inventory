# CRP-260 Implementation Plan

Implement a shared, read-only cohort resolver before enabling COMPLETE ALL or PUSH ALL. The
resolver must support exact proposal, repository, declared-cohort, and bounded default BCR scope;
emit a deterministic receipt; classify member readiness; and require explicit selection rather
than silently broadening a cohort.

Integrate the resolver with CRP-261 without duplicating lifecycle authority: BCR launch may
transition only verified members after successful handoff, in-review members refresh their
existing session, and in-progress members remain pending verification. ShowCM must display
declared cohorts and the current bounded default proposal, including exclusions and blockers.

Then add Git overlap/merge, baseline compatibility, evidence, and stale-receipt checks before
enabling COMPLETE ALL or PUSH ALL.
