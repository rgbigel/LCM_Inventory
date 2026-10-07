# CRP-249 Implementation Plan

1. Compare the existing `Update-Gemini.ps1` collision and retain the newer
   implementation.
2. Move the remaining `LCM_AI\tools` scripts and both module directories into
   `LCM_Inventory\tools`.
3. Retarget the 21 `LCM_Inventory\Cmd` launchers and all live PowerShell
   callers from `LCM_AI\tools` to `LCM_Inventory\tools`.
4. Update `Create-LcmTool.ps1`, `Update-ToolCatalog.ps1`, and
   `LcmDependencyIndex.psm1` so new tools and catalog scans use the canonical
   Inventory location.
5. Update active documentation and tool headers; regenerate derived catalog or
   documentation outputs only through their owning commands.
6. Update machine and user environment variables:
   - machine PATH: `LCM_Inventory\Cmd`;
   - user PATH: remove `LCM_AI\tools`;
   - machine `Git_Root`: preserve `D:\Git_Repositories`;
   - user `Git_Root`: remove if present.
7. Verify registry startup and scheduled tasks, parser validity, wrappers,
   command resolution, catalog coverage, and clean absence of live old-path
   references.
