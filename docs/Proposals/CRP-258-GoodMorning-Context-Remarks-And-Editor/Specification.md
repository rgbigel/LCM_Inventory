# CRP-258: GoodMorning Context Remarks and Editor

| Metadata Field | Value |
|---|---|
| Proposal ID | `CRP-258` |
| Lifecycle State | `SUGGESTED` |
| Target Scope | `LCM_Inventory` GoodMorning and context-viewing tools |
| Affected Version Range | `Invoke-WorkspaceGoodMorning` v1.x |
| Impacted Repositories | `LCM_Inventory` |
| Priority | `8` |

## Requirements

1. GoodMorning must output timestamped file identities for the two durable context sources:
   `LEARNED_ADVICE.md` and the `Operator Remarks` section of `ACTIVE_CONTEXT.md`.
2. Add `Show-GoodMorningContext.ps1` to open the relevant file or files in the configured editor.
3. Support `-Both` (or `-All`) as the default, plus `-Learned` and `-Operator`.
4. Reject mutually exclusive selection flags explicitly.
5. Add focused Pester coverage for output identification, selection, and invalid flags.
6. The Flag -Delete should delete the selected files (both, learned or operator), instead of opening them
7. All created (timestamped) files are delete at GoodNight

