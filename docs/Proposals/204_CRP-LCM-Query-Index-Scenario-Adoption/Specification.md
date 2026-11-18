# CRP-204: LCM Query Index Scenario Adoption

```yaml
CRP-ID: CRP-204
Priority: 3
Scope: LCM tool query contracts and index-assisted scenarios
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Affected-Repos:
  - LCM_Inventory
  - Git_Repositories
```

## Objective

Define common tool-research scenarios in the LCM Query Index and migrate the
appropriate internal tools to use the indexed scenario contract before falling
back to direct search.

## Requirements

1. Define each supported scenario with inputs, expected artifacts, preferred
   query provider, fallback provider, and result contract.
2. Use `es.exe` as the preferred discovery provider when a scenario can be
   resolved by indexed file attributes or indexed content.
3. Use `rg` as the defined fallback when `es.exe` cannot provide the required
   content coverage, query semantics, or availability.
4. Record provider selection, fallback reason, and result provenance in the
   scenario result.
5. Expose scenario contracts through the future LCM Query Index so tools can
   reuse them rather than repeating exploratory searches.
6. Preserve direct NTFS access as the authoritative data path; the index is a
   projection and scenario catalog, not a replacement data store.

## Non-Goals

- No replacement of Everything, `es.exe`, `rg`, or IDE semantic services.
- No implementation of a remote search service or HTTP artifact transport.
- No Control Hub lifecycle or presentation redesign work from CRP-196.
