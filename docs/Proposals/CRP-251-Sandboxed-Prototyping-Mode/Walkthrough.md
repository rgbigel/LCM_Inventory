# CRP-251 Walkthrough

No implementation has started. This proposal records the requested design
boundary before any sandbox or policy behavior is introduced.

## Design Refinement

The proposal now formally succeeds CRP-244's WHAT-IF trial objective. Its
design now recognizes the operational `F:` virtualized baseline as the first
prototype tier. The existing `RelocateJunctions.ps1` routine can relocate rules
junctions to that prototype copy, while its known inability to replace
internal links such as trampolines remains a required design item.
`ReplaceByJunction` is recorded as a complementary controlled redirection
mechanism.

The `F:` tier avoids copy-on-demand from the live repository root, contributes
to the `D:`-drive change boundary, supports rule-change-based acceptance, and
provides a simpler reviewed merge path into the live repository. The separate
Windows Sandbox tier remains for prototypes requiring security isolation from
the host. Its host-capability verification requires elevation and remains an
implementation preflight, not an assumed environment fact.

CRP-253 contributes the prototype-world controls adopted by this design:
explicit governed-repository admission, clean synchronized bases, independent
clones for changed repositories, junctions only for unchanged scope,
write-through protection, base-drift reporting, and fail-safe closure that
restores production links. These controls improve CRP-251 without importing
CRP-253's unrelated Git World migration and governance-mode switch scope.
