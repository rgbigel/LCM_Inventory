# CRP-250 Implementation Plan

1. Validate the shared machine-registry Git-root resolver and adopt it in the
   GoodNight prototype first.
2. Complete the active PowerShell tool/module migration away from `.lcm` and
   inherited `Git_Root`.
3. Replace every active Inventory CMD launcher preamble with the
   machine-registry query.
4. Move derived catalog/config state to its decided Inventory-owned location
   and regenerate it.
5. Finalize the GoodNight archive-before-publish integration and document the
   separate publish-owned maintenance behavior.
6. Define, but do not implement, the GoodMorning converse.
7. Validate PowerShell AST parsing, wrapper resolution, zero active retired
   runtime paths, and archive behavior without destructive test cleanup.
