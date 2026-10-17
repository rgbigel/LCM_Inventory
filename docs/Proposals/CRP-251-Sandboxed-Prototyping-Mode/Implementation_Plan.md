# CRP-251 Implementation Plan

1. Define a versioned prototype manifest schema that distinguishes the
   `baseline-prototype` and `secure-sandbox` isolation tiers. Record identity,
   source hashes, mount and junction information, requested profile, lifecycle
   events, and the mandatory `non-production` label.
2. Establish the `F:` virtualized baseline as the first-tier prototype input.
   Verify the expected mounted baseline, its known repository basis, and the
   absence of a copy-on-demand operation from the live `D:` repository root.
3. Integrate controlled rule-junction relocation through
   `RelocateJunctions.ps1`, and define when `ReplaceByJunction` is permitted.
   Inventory and explicitly resolve internal-linkage exceptions, including
   trampolines, rather than claiming that junction relocation covers them.
4. Add the prototype-world admission controls: a governed-repository allow-list,
   clean/non-detached/synchronized base checks, exact base-commit capture, and
   explicit exclusion of live proposal-ledger, review-receipt, and ignored
   runtime data from prototype clones.
5. For every repository that a prototype changes, create an independent full
   clone and dedicated `crp-<id>` branch. Reject Git worktrees and shared
   clones. Permit junctions only for unchanged repositories, require a guarded
   junction-to-clone swap before a write, and trial the ACL and commit-gate
   safety nets on a scratch repository.
6. Generate a prototype-to-live rule-change map and per-repository drift
   report. Make both required review inputs for baseline-prototype acceptance,
   merge planning, and base-to-prototype synchronization.
7. Define `start`, `status`, `pause`, `terminate`, `archive`, and `promote`
   operations. Entry, status, and termination append immutable event evidence.
   Promotion proposes a normal CRP and never modifies, stages, commits, or
   publishes live files.
8. Define a guarded close operation that reviews/merges or PRs modified
   repositories, removes clones, restores base junctions, and verifies all
   rule links. On cleanup failure, restore production targets rather than
   retaining prototype links.
9. Create a secure-sandbox preflight that verifies the disposable Windows
   Sandbox capability and rejects a request when it cannot provide the
   declared security isolation. Do not use a branch-only or local-directory
   fallback for this tier.
10. Generate the Windows Sandbox configuration with only a read-only input
   bundle. Disable network, clipboard, printer, and host-folder mapping by
   default; permit a separately configured writable evidence export folder
   only when its path is outside governed repositories.
11. Validate both tiers. For the baseline tier, test the `D:`-drive boundary,
   mount identity, junction-rule map, internal-linkage exception reporting,
   cloned-repository admission, junction write protection, base drift,
   fail-safe cleanup, and non-mutating promotion. For the secure tier, add
   negative tests for live repository mapping, host registry mutation,
   production credentials, publishing tools, and writable governed paths.
   Validate manifest integrity and append-only lifecycle evidence for both
   tiers.
