# CRP-251: Sandboxed Prototyping Mode

> [!NOTE]
> **SUPERSEDED BY CRP-253**: The requirements, isolation tiers (Tier 1 baseline prototype on virtual drive, Tier 2 secure disposable sandbox), manifest lifecycle, and promotion protocols defined here have been formally absorbed and merged into **[`CRP-253`](file:///LCM_Inventory/docs/Proposals/CRP-253-LCM_Mode-World-Switch/Specification.md)** per operator instruction.

| Metadata Field | Value |
|---|---|
| **Proposal ID** | `CRP-251` |
| **Lifecycle State** | `SUPERSEDED` |
| **Superseded By** | `CRP-253` (Merged into CRP-253) |
| **Origin Repository** | `LCM_Inventory` |
| **Date** | 2026-11-09 (Superseded; originally 2026-10-13) |

## Objective

Define a Prototyping Mode that permits design and initial implementation in an
isolated sandbox rather than the live governed workspace. It intentionally
does not require a normal CRP or review while the work remains sandbox-only.

## Required Contract

- The prototype workspace must be isolated from live repositories, registries,
  credentials, publishing, and destructive tools.
- Prototype outputs must be labelled non-production.
- Prototyping Mode has explicit entry, status, and termination records.
- Promotion is optional. A promoted artifact becomes a normal CRP with
  proposal, review, validation, and commit requirements.

## Design Direction

CRP-251 is the successor to CRP-244's safe WHAT-IF trial goal. The prototype
boundary must be stronger than a Git branch or rollback checkpoint: those
mechanisms can still expose live repositories, host registry state, credentials,
and publishing tools.

### Existing Prototype-Baseline Capability

A stable prototype environment already exists as a dedicated second baseline in
the virtualized `F:` drive. It permits work inside a prototype copy without
copying the prototype on demand from the live repository root. Within its
declared mount and junction boundaries, it also acts as a practical gate
against unintended changes outside the `D:` drive.

The existing `RelocateJunctions.ps1` routine can adapt rules-junction targets
to the prototype copy, contributing to prototype consistency. It does not
replace internal linkage such as trampolines; that limitation remains an
explicit design concern. `ReplaceByJunction` is a useful complementary
mechanism where a path must be redirected by a controlled junction rather than
copied.

This baseline-backed environment is the preferred first prototype tier. It
provides a common, stable repository basis, makes a prototype-to-live merge
substantially simpler, and allows the proposed design to be assessed against
the precise rule changes it introduces.

### Isolation Tiers

The `F:` prototype baseline is not, by itself, a claim that host registry,
credential, networking, or destructive-tool isolation exists. CRP-251 must
define explicit tiers:

1. **Baseline prototype:** the dedicated `F:` virtualized baseline, with
   junction relocation and a rule-change map. It is suitable for controlled
   design and implementation work with a known merge path to the live `D:`
   repository.
2. **Disposable secure sandbox:** a Windows Sandbox session when the prototype
   requires isolation from host registry, credentials, network, publishing, or
   destructive tools.

The disposable secure sandbox is launched from an LCM-owned manifest:

1. The sandbox receives only a read-only, hash-recorded prototype input bundle.
   It does not mount `Git_Root`, live repositories, user-profile credentials,
   or the LCM operational data directories.
2. Networking, clipboard, printer, and host-folder exposure are disabled by
   default. A writable export folder, when explicitly needed, is outside the
   governed workspace and contains non-production evidence only.
3. The sandbox has its own disposable registry and process space. It is closed
   and discarded at termination; its host cannot be altered through a sandbox
   registry or repository write.
4. The launcher fails closed when the required isolation capability is
   unavailable. It must not fall back to an in-process, branch-only, or
   workspace-local prototype.

Every prototype has a manifest containing its identifier, purpose, source-input
hashes, isolation profile, entry/status/termination times, operator, and
non-production label. A status or termination operation appends evidence; it
does not rewrite prior records.

Promotion creates a new ordinary CRP referencing the immutable prototype
manifest and exported evidence. It does not copy sandbox changes into live
repositories, create a commit, or bypass proposal, validation, BCR, acceptance,
or commit gates.

For a baseline-prototype promotion, the evidence additionally contains a
rule-change map from the `F:` prototype baseline to the affected live `D:`
paths. Acceptance evaluates that map and the resulting content delta; it does
not treat the prototype mount or a matching branch as acceptance. After
acceptance, the common baseline and deliberate junction strategy make the
reviewed merge into the live repository a bounded operation rather than a
fresh copy-on-demand exercise.

### Prototype-World Controls Adopted from CRP-253

Where a baseline prototype needs a world spanning more than its initial
repository scope, it adopts these controls from CRP-253:

1. The manifest declares an explicit governed-repository allow-list. A
   prototype cannot add an undeclared or non-governed repository.
2. A repository may join only from a clean, non-detached, synchronized base.
   The manifest records its exact base commit; ignored runtime data, proposal
   ledger state, and review receipts remain in the live base.
3. Repositories changed by the prototype use independent full clones and a
   dedicated `crp-<id>` branch. Git worktrees and shared clones are prohibited
   because they retain unsafe links to the authoritative repository or can be
   invalidated by base garbage collection.
4. Unchanged governed repositories may be visible through junctions to the
   known base, but the design must treat every junction as write-through.
   The prototype tool must swap a junction for a clone before a governed write;
   a base-repository commit gate and a tested read-only ACL safety net provide
   additional protection.
5. Base fixes are committed in the base first, then explicitly fetched and
   merged into each affected prototype clone. A drift report identifies commits
   behind the base and overlapping files; conflicts stop reconciliation.
6. Closure is one guarded operation: review and merge or PR each modified
   repository, remove prototype clones, restore base junctions, and verify
   that no rule link targets a removed prototype. Failed cleanup falls back to
   the production target rather than leaving a broken link.

The canonical rule hub remains physically anchored in the live `LCM_AI`
repository. When a prototype legitimately changes rules, the prototype
`LCM_AI` clone becomes the temporary rule source only for explicitly switched
child `.agents\rules` junctions; the switch and restoration are recorded in
the prototype manifest.

## Non-Goals

- Do not bypass governance for changes in live repositories.
- Do not make sandbox output authoritative without explicit promotion.
- Do not provide a fallback that treats a local branch, temporary directory, or
  unreviewed workspace copy as an isolated prototype.
- Do not claim that the `F:` baseline provides secure-sandbox guarantees that
  require a disposable isolated session.
