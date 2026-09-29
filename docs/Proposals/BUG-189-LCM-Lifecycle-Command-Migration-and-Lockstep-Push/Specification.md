# BUG-189: LCM Lifecycle Command Migration and Lockstep Push Guard

```yaml
BUG-ID: BUG-189
Scope: Lifecycle command and multi-repository publication contract
Affected-Repos:
	- Git_Repositories
	- Workspace_AI
	- Workspace_Inventory
Status: In Progress
Severity: High
```

## Problem

The lifecycle contract exposed `ACCEPT` as both review completion and remote publication, while the runtime implementations disagreed. The former push engine could dispatch repositories without completed proposals and could begin remote pushes before validating all lockstep members.

### Publication Integrity Gap

The repaired `PUSH` preflight still checks proposal state and repository readiness without proving that a proposal bundle is present in a commit being pushed. Proposal directories can remain untracked while their ledger records transition to `pushed`. In addition, no proposal-only publication path exists for draft or in-progress proposal documents that must be visible on GitHub without publishing unrelated repository changes.

## Resolution

- Replaced lifecycle command usage with local-only `COMPLETE` and remote-only `PUSH`.
- Reworked review staging, enforcement, macro definitions, policies, progress help, and catalog metadata to use `COMPLETED` terminology.
- Added completed-only push planning with a non-mutating cohort preflight that requires `Workspace_Inventory` and all affected repositories to be Git-backed, remotely configured, and ahead.
- Prevented proposal state transitions and post-push cleanup after a partial remote dispatch failure.

## Active Remediation

- Add a proposal-bundle publication command that discovers governed repositories containing `docs/Proposals`, stages only proposal bundle files, creates proposal-only commits, and pushes only those repositories.
- Require lifecycle `PUSH` to verify every completed proposal bundle exists in the repository `HEAD` before remote dispatch and before any `pushed` state transition.
- Keep proposal-document publication separate from lifecycle completion: a suggested or in-progress proposal document may be published, but its ledger state must not become `pushed` unless its completed lifecycle cohort is successfully dispatched.

## Invariants

- `COMPLETE` creates a local review commit and never invokes a remote push.
- `PUSH` only dispatches a fully preflighted completed cohort.
- A proposal may name `affected_repos`; every named repository joins its push cohort.
- A completed proposal cannot transition to `pushed` unless its bundle is tracked in the local `HEAD` that will be pushed.
- Proposal-document publication stages only `docs/Proposals` content, plus `Workspace_Inventory/data/proposals/proposals.json`, and never stages unrelated working-tree files.
