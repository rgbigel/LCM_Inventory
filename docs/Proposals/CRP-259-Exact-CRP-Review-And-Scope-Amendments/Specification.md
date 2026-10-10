# CRP-259: Exact CRP Review and Scope Amendments

| Metadata Field | Value |
|---|---|
| Proposal ID | `CRP-259` |
| Lifecycle State | `IN_PROGRESS` (`DOIT`) |
| Target Scope | Review lifecycle rules, macros, and completion tools |
| Impacted Repositories | `LCM_Inventory`, `LCM_AI` |
| Priority | `10` |

## Required Corrections

1. `COMPLETE <CRP-ID>` must target exactly one staged CRP; repository-only completion must
   refuse when the CRP is absent or ambiguous.
2. A review manifest must carry and validate the exact CRP identity before completion.
3. Supporting changes outside a CRP's declared files must be recorded as a scope amendment or
   linked BUG and disclosed before modification, even in DOIT mode.
4. COMPLETE must run and report a final exact changed-file/commit-scope check before committing.

