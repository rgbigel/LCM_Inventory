# Workspace & Subsystem Tooling Index

Module: LCM_Inventory/docs/README.md  
Purpose: Authoritative index of all Lifecycle Model (LCM) and Subsystem tools with Role, ShortName, and User vs Developer classification.  
Path: LCM_Inventory/docs/README.md  
Authors: Rolf, LCM_AI Engine  
Version: 10.0.1  
Status: Authoritative Reference  
Updated: 2026-10-17 20:24:18  

---

## Workspace Readiness
`TestWorkspaceReadiness` is the required workspace quality gate, not an example
command. Run it from any terminal before a governed handoff:
```cmd
TestWorkspaceReadiness
```

---

## 1. User & Operator Exposed Commands (Daily Operations)

| Short Name | Source Tool | Role | Group | Type | Category | Description | Command |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **ShowHaAuthDialog** | [Show-HaAuthDialog.ps1](file:///HaSSD06/tools/subsystem/Show-HaAuthDialog.ps1) | Auth | HaSSD06 | PowerShell | JIT Authentication | WPF desktop dialog for secure ephemeral credentials with password reveal (RULE-SUB-003). | ShowHaAuthDialog |
| **GetSystemPortInventory** | [Get-SystemPortInventory.ps1](file:///LCM_Inventory/tools/Get-SystemPortInventory.ps1) | Diagnostics | LCM_Inventory | PowerShell | Network Diagnostics | Scans and audits all active local listening TCP/UDP ports and verifies port 9876 availability. | GetSystemPortInventory |
| **ShowDaemon** | [Show-LcmDaemon.ps1](file:///LCM_Inventory/tools/Show-LcmDaemon.ps1) | Diagnostics | LCM_Inventory | PowerShell | Desktop Bridge | Displays live telemetry, runtime status, and log tailing for the LCM Desktop REST Bridge Daemon. | ShowDaemon |
| **ShowLastLog** | [Show-LastLog.ps1](file:///LCM_Inventory/tools/Show-LastLog.ps1) | Diagnostics | LCM_Inventory | PowerShell | Log Diagnostics | Displays the most recently updated audit log in the workspace with live tail and level filtering. | ShowLastLog |
| **TestMacriumBaseline** | [Test-MacriumCurrentBaseline.ps1](file:///LCM_Inventory/tools/Test-MacriumCurrentBaseline.ps1) | Diagnostics | LCM_Inventory | PowerShell | Macrium BCR Baseline | Read-only plausibility and snapshot-evidence check for the current F:-I: Macrium BCR baseline. | TestMacriumBaseline |
| **ShowCM** | [Show-LcmControl.ps1](file:///LCM_Inventory/tools/Show-LcmControl.ps1) | GUI | LCM_Inventory | PowerShell | Configuration Management | Unified LCM Control Hub dashboard and proposal lifecycle manager. | ShowCM |
| **ShowCmdAnalysis** | [Show-CmdFolderAnalysis.ps1](file:///LCM_Inventory/tools/Show-CmdFolderAnalysis.ps1) | GUI | LCM_Inventory | PowerShell | Tool Analysis | Interactive HTML viewer analyzing all legacy batch scripts and modern PowerShell tool equivalents. | ShowCmdAnalysis |
| **ShowHaInventory** | [Show-HaInventory.ps1](file:///LCM_Inventory/tools/Show-HaInventory.ps1) | GUI | LCM_Inventory | PowerShell | Subsystem GUI | Generates and launches the authoritative Home Assistant HaSSD06 Subsystem Viewer dashboard. | ShowHaInventory |
| **SuperController** | [Show-SuperController.ps1](file:///LCM_Inventory/tools/Show-SuperController.ps1) | GUI | LCM | PowerShell | Navigation | Workspace AI Super-Controller unified navigation dispatcher for ToolsExplorer and ShowCM. | SuperController |
| **ToolsExplorer** | [Show-ToolsExplorer.ps1](file:///LCM_Inventory/tools/Show-ToolsExplorer.ps1) | GUI | LCM_Inventory | PowerShell | Tool Discovery | Opens the modern interactive LCM Tool Explorer dashboard in the browser or terminal. | ToolsExplorer |
| **RestoreSystemSettings** | [Restore-SystemSettings.ps1](file:///LCM_Inventory/tools/Restore-SystemSettings.ps1) | Invariants | LCM_Inventory | PowerShell | System Invariants | Authoritative LCM system restore tool restoring background services while enforcing anti-flicker invariants. | RestoreSystemSettings |
| **ManageSupervisionTask** | [Manage-SupervisionTask.ps1](file:///LCM_Supervision/tools/Manage-SupervisionTask.ps1) | Management | LCM_Supervision | PowerShell | Supervision & Health | CM Task Controller to Start, Stop, Pause, Resume, Add, Delete, and Run supervision tasks. | ManageSupervisionTask |
| **HaUpdateGate** | [Invoke-HaUpdateGate.ps1](file:///HaSSD06_Inventory/tools/Invoke-HaUpdateGate.ps1) | QualityGate | HaSSD06 | PowerShell | Subsystem Update Gate | 5-stage update runner (RULE-SUB-006): changelog review, CRP extraction, backup & execution. | HaUpdateGate |
| **TestWorkspaceReadiness** | [Test-WorkspaceReadiness.ps1](file:///LCM_Inventory/tools/Test-WorkspaceReadiness.ps1) | QualityGate | LCM_Inventory | PowerShell | Quality Gate | Executes the 5-stage automated LCM readiness quality gate across all repositories. | TestWorkspaceReadiness |
| **DismountMacriumBaseline** | [Dismount-MacriumCurrentBaseline.ps1](file:///LCM_Inventory/tools/Dismount-MacriumCurrentBaseline.ps1) | Recovery | LCM_Inventory | PowerShell | Macrium BCR Baseline | Explicitly detaches only the label-matched F:-I: Macrium BCR baseline after confirmation. | DismountMacriumBaseline |
| **MountMacriumBaseline** | [Mount-MacriumLatestBaseline.ps1](file:///LCM_Inventory/tools/Mount-MacriumLatestBaseline.ps1) | Recovery | LCM_Inventory | PowerShell | Macrium BCR Baseline | Explicitly mounts the latest completed same-day Macrium image through the canonical baseline workflow. | MountMacriumBaseline |
| **BCR** | [Invoke-MacriumBcrReview.ps1](file:///LCM_Inventory/tools/Invoke-MacriumBcrReview.ps1) | ReviewGate | LCM_Inventory | PowerShell | Proposal Review | Opens the exact CRP/BUG Macrium BCR review using the writable baseline and the _LCM Beyond Compare profile. | BCR |
| **ShowActions** | [Show-Actions.ps1](file:///LCM_Inventory/tools/Show-Actions.ps1) | Telemetry | LCM_Inventory | PowerShell | Audit Logs | Fast lightweight terminal reader displaying recent operational actions and tool execution step summaries. | ShowActions |
| **UpdateHaInventory** | [Update-HaInventory.ps1](file:///HaSSD06_Inventory/tools/Update-HaInventory.ps1) | Telemetry | HaSSD06 | PowerShell | Subsystem Telemetry | Pulls live WebSocket registry & REST data to reconcile all entities, devices, & integrations. | UpdateHaInventory |
| **SearchEverything** | [Search-Everything.ps1](file:///LCM_Inventory/tools/Search-Everything.ps1) | Utility | LCM_Inventory | PowerShell | File Search | CLI search interface utilizing Voidtools Everything command line utility (es.exe). | SearchEverything |

---

## 2. Developer & Diagnostic Plumbing Tools

| Short Name | Source Tool | Role | Group | Type | Category | Description | Command |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **LcmDaemon** | [LcmDesktopDaemon.ps1](file:///LCM_Inventory/tools/LcmDesktopDaemon.ps1) | Elevation | LCM_Inventory | PowerShell | Desktop Bridge | Lightweight high-performance HTTP/REST bridge daemon running in Session 1 for cross-session GUI dispatch. | LcmDaemon |
| **RegisterDaemon** | [Register-LcmDesktopDaemon.ps1](file:///LCM_Inventory/tools/Register-LcmDesktopDaemon.ps1) | Elevation | LCM_Inventory | PowerShell | Desktop Bridge | Registers the persistent LCM Desktop REST Bridge Daemon in Task Scheduler with automatic startup. | RegisterDaemon |
| **ShowToolIndex** | [Show-ToolIndex.ps1](file:///LCM_Inventory/tools/Show-ToolIndex.ps1) | GUI | LCM_Inventory | PowerShell | Tool Discovery | Underlying generation engine for the interactive LCM Tool Explorer HTML application. | ShowToolIndex |
| **InvokeSupervisionRunner** | [Invoke-SupervisionRunner.ps1](file:///LCM_Supervision/tools/Invoke-SupervisionRunner.ps1) | Management | LCM_Supervision | PowerShell | Supervision & Health | Unified task dispatcher executing supervision cycles and logging observation telemetry. | InvokeSupervisionRunner |
| **AdvanceGovernance** | [Advance-Governance.ps1](file:///LCM_Inventory/tools/Advance-Governance.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Advance-Governance execution tool. | AdvanceGovernance |
| **analyzelcmcomponents** | [analyze_lcm_components.py](file:///HaSSD06/analyze_lcm_components.py) | Utility | HaSSD06 | Python | Utility | analyze_lcm_components execution tool. | analyzelcmcomponents |
| **APPLY** | [APPLY.ps1](file:///LCM_Inventory/tools/APPLY.ps1) | Utility | LCM_Inventory | PowerShell | Utility | APPLY execution tool. | APPLY |
| **ArchiveLcmDaemonLogs** | [Archive-LcmDaemonLogs.ps1](file:///LCM_Inventory/tools/Archive-LcmDaemonLogs.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Archive-LcmDaemonLogs execution tool. | ArchiveLcmDaemonLogs |
| **AuthorizeMasterUser** | [AuthorizeMasterUser.ps1](file:///LCM_Inventory/tools/AuthorizeMasterUser.ps1) | Utility | LCM_Inventory | PowerShell | Utility | AuthorizeMasterUser execution tool. | AuthorizeMasterUser |
| **BcrDispatcher** | [Invoke-BcrDispatcher.ps1](file:///LCM_Inventory/tools/Invoke-BcrDispatcher.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-BcrDispatcher execution tool. | BcrDispatcher |
| **BuildHaInventoryViewer** | [Build-HaInventoryViewer.ps1](file:///HaSSD06_Inventory/tools/Build-HaInventoryViewer.ps1) | Utility | HaSSD06 | PowerShell | Utility | Build-HaInventoryViewer execution tool. | BuildHaInventoryViewer |
| **buildmatrix** | [build_matrix.py](file:///HaSSD06/build_matrix.py) | Utility | HaSSD06 | Python | Utility | build_matrix execution tool. | buildmatrix |
| **buildofflinedocs** | [build_offline_docs.py](file:///LCM_Inventory/tools/build_offline_docs.py) | Utility | LCM_Inventory | Python | Utility | build_offline_docs execution tool. | buildofflinedocs |
| **CallerIntentReconciliation** | [Invoke-CallerIntentReconciliation.ps1](file:///LCM_Inventory/tools/Invoke-CallerIntentReconciliation.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-CallerIntentReconciliation execution tool. | CallerIntentReconciliation |
| **checkspecific** | [check_specific.py](file:///HaSSD06/check_specific.py) | Utility | HaSSD06 | Python | Utility | check_specific execution tool. | checkspecific |
| **ClearBCReviewTemp** | [Clear-BCReviewTemp.ps1](file:///LCM_Inventory/tools/Clear-BCReviewTemp.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Clear-BCReviewTemp execution tool. | ClearBCReviewTemp |
| **CompactBCompareReview** | [Invoke-CompactBCompareReview.ps1](file:///LCM_Inventory/tools/Invoke-CompactBCompareReview.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-CompactBCompareReview execution tool. | CompactBCompareReview |
| **comparetuyaintegrations** | [compare_tuya_integrations.py](file:///HaSSD06/compare_tuya_integrations.py) | Utility | HaSSD06 | Python | Utility | compare_tuya_integrations execution tool. | comparetuyaintegrations |
| **CompleteReviewCohort** | [Complete-ReviewCohort.ps1](file:///LCM_Inventory/tools/Complete-ReviewCohort.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Complete-ReviewCohort execution tool. | CompleteReviewCohort |
| **CompleteToolDocumentation** | [Complete-ToolDocumentation.ps1](file:///LCM_Inventory/tools/Complete-ToolDocumentation.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Complete-ToolDocumentation execution tool. | CompleteToolDocumentation |
| **CreateTool** | [Create-LcmTool.ps1](file:///LCM_Inventory/tools/Create-LcmTool.ps1) | Utility | LCM_Inventory | PowerShell | Tool Scaffolding | Scaffolds new LCM PowerShell tools, derives short names, and generates trampolines in LCM_Inventory/Cmd/. | CreateTool |
| **CreateWorkspaceBaseline** | [Create-WorkspaceBaseline.ps1](file:///LCM_Inventory/tools/Create-WorkspaceBaseline.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Create-WorkspaceBaseline execution tool. | CreateWorkspaceBaseline |
| **deepdevicescan** | [deep_device_scan.py](file:///HaSSD06/deep_device_scan.py) | Utility | HaSSD06 | Python | Utility | deep_device_scan execution tool. | deepdevicescan |
| **deeptuyascan** | [deep_tuya_scan.py](file:///HaSSD06/deep_tuya_scan.py) | Utility | HaSSD06 | Python | Utility | deep_tuya_scan execution tool. | deeptuyascan |
| **DisableWakeDevices** | [Disable-WakeDevices.ps1](file:///LCM_Inventory/tools/Disable-WakeDevices.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Disable-WakeDevices execution tool. | DisableWakeDevices |
| **ExportLcmKnowledgeBase** | [Export-LcmKnowledgeBase.ps1](file:///LCM_Inventory/tools/Export-LcmKnowledgeBase.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Export-LcmKnowledgeBase execution tool. | ExportLcmKnowledgeBase |
| **ExportLCMRules** | [Export-LCMRules.ps1](file:///LCM_Inventory/tools/Export-LCMRules.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Export-LCMRules execution tool. | ExportLCMRules |
| **extracthacentralregistry** | [extract_ha_central_registry.py](file:///HaSSD06_Inventory/tools/extract_ha_central_registry.py) | Utility | HaSSD06 | Python | Utility | extract_ha_central_registry execution tool. | extracthacentralregistry |
| **extracthaupdatecrps** | [extract_ha_update_crps.py](file:///HaSSD06/extract_ha_update_crps.py) | Utility | HaSSD06 | Python | Utility | extract_ha_update_crps execution tool. | extracthaupdatecrps |
| **FindChangeRequest** | [Find-ChangeRequest.ps1](file:///LCM_Inventory/tools/Find-ChangeRequest.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Find-ChangeRequest execution tool. | FindChangeRequest |
| **FixDocumentation** | [Fix-Documentation.ps1](file:///LCM_Inventory/tools/Fix-Documentation.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Fix-Documentation execution tool. | FixDocumentation |
| **FormatLcmMarkdownDiagrams** | [Format-LcmMarkdownDiagrams.ps1](file:///LCM_Inventory/tools/Format-LcmMarkdownDiagrams.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Format-LcmMarkdownDiagrams execution tool. | FormatLcmMarkdownDiagrams |
| **GenerateLog** | [Generate-Log.ps1](file:///LCM_Inventory/tools/Generate-Log.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Generate-Log execution tool. | GenerateLog |
| **generatesystemdocs** | [generate_system_docs.py](file:///HaSSD06/generate_system_docs.py) | Utility | HaSSD06 | Python | Utility | generate_system_docs execution tool. | generatesystemdocs |
| **GetLcmTablePrintAtom** | [Get-LcmTablePrintAtom.ps1](file:///LCM_Inventory/tools/Get-LcmTablePrintAtom.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Get-LcmTablePrintAtom execution tool. | GetLcmTablePrintAtom |
| **GetOpenProposals** | [Get-OpenProposals.ps1](file:///LCM_Inventory/tools/Get-OpenProposals.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Get-OpenProposals execution tool. | GetOpenProposals |
| **GetRealRepoActionPlan** | [Get-RealRepoActionPlan.ps1](file:///LCM_Inventory/tools/Get-RealRepoActionPlan.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Get-RealRepoActionPlan execution tool. | GetRealRepoActionPlan |
| **GetRealRepoTargetProfile** | [Get-RealRepoTargetProfile.ps1](file:///LCM_Inventory/tools/Get-RealRepoTargetProfile.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Get-RealRepoTargetProfile execution tool. | GetRealRepoTargetProfile |
| **GetRealRepoTestPlan** | [Get-RealRepoTestPlan.ps1](file:///LCM_Inventory/tools/Get-RealRepoTestPlan.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Get-RealRepoTestPlan execution tool. | GetRealRepoTestPlan |
| **GetReposUnderReview** | [Get-ReposUnderReview.ps1](file:///LCM_Inventory/tools/Get-ReposUnderReview.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Get-ReposUnderReview execution tool. | GetReposUnderReview |
| **GetWorkspaceRepositories** | [Get-WorkspaceRepositories.ps1](file:///LCM_Inventory/tools/Get-WorkspaceRepositories.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Get-WorkspaceRepositories execution tool. | GetWorkspaceRepositories |
| **HaAudit** | [run_audit.py](file:///HaSSD06/run_audit.py) | Utility | HaSSD06 | Python | Utility | run_audit execution tool. | HaAudit |
| **habackup** | [invoke_ha_backup.py](file:///HaSSD06/tools/invoke_ha_backup.py) | Utility | HaSSD06 | Python | Utility | invoke_ha_backup execution tool. | habackup |
| **hacoreupdate** | [invoke_ha_core_update.py](file:///HaSSD06/tools/invoke_ha_core_update.py) | Utility | HaSSD06 | Python | Utility | invoke_ha_core_update execution tool. | hacoreupdate |
| **hainventorycollector** | [ha_inventory_collector.py](file:///HaSSD06/ha_inventory_collector.py) | Utility | HaSSD06 | Python | Utility | ha_inventory_collector execution tool. | hainventorycollector |
| **HaListUpdates** | [list_all_updates.py](file:///HaSSD06/list_all_updates.py) | Utility | HaSSD06 | Python | Utility | list_all_updates execution tool. | HaListUpdates |
| **HaLogs** | [inspect_ha_logs.py](file:///HaSSD06/inspect_ha_logs.py) | Utility | HaSSD06 | Python | Utility | inspect_ha_logs execution tool. | HaLogs |
| **HaRenameCascade** | [Invoke-HaRenameCascade.ps1](file:///HaSSD06_Inventory/tools/Invoke-HaRenameCascade.ps1) | Utility | HaSSD06 | PowerShell | Utility | Invoke-HaRenameCascade execution tool. | HaRenameCascade |
| **HaService** | [Invoke-HaService.ps1](file:///HaSSD06_Inventory/tools/Invoke-HaService.ps1) | Utility | HaSSD06 | PowerShell | Utility | Invoke-HaService execution tool. | HaService |
| **InitializeAdminMode** | [Initialize-AdminMode.ps1](file:///LCM_Inventory/tools/Initialize-AdminMode.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Initialize-AdminMode execution tool. | InitializeAdminMode |
| **InitializeGitWorld** | [Initialize-GitWorld.ps1](file:///LCM_Inventory/tools/Initialize-GitWorld.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Initialize-GitWorld execution tool. | InitializeGitWorld |
| **InitializeRealRepoMethodInstance** | [Initialize-RealRepoMethodInstance.ps1](file:///LCM_Inventory/tools/Initialize-RealRepoMethodInstance.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Initialize-RealRepoMethodInstance execution tool. | InitializeRealRepoMethodInstance |
| **InteractiveDesktop** | [Invoke-InteractiveDesktop.ps1](file:///LCM_Inventory/tools/Invoke-InteractiveDesktop.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-InteractiveDesktop execution tool. | InteractiveDesktop |
| **LcmGiantReview** | [Invoke-LcmGiantReview.ps1](file:///LCM_Inventory/tools/Invoke-LcmGiantReview.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-LcmGiantReview execution tool. | LcmGiantReview |
| **LcmPathMigration** | [Invoke-LcmPathMigration.ps1](file:///LCM_Inventory/tools/Invoke-LcmPathMigration.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-LcmPathMigration execution tool. | LcmPathMigration |
| **LcmProtocol** | [Invoke-LcmProtocol.ps1](file:///LCM_Inventory/tools/Invoke-LcmProtocol.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-LcmProtocol execution tool. | LcmProtocol |
| **LearnedAdviceReview** | [Invoke-LearnedAdviceReview.ps1](file:///LCM_Inventory/tools/Invoke-LearnedAdviceReview.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-LearnedAdviceReview execution tool. | LearnedAdviceReview |
| **Level1AnalysisRefinement** | [Invoke-Level1AnalysisRefinement.ps1](file:///LCM_Inventory/tools/Invoke-Level1AnalysisRefinement.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-Level1AnalysisRefinement execution tool. | Level1AnalysisRefinement |
| **LoadAtoms** | [LoadAtoms.ps1](file:///LCM_Inventory/tools/LoadAtoms.ps1) | Utility | LCM_Inventory | PowerShell | Utility | LoadAtoms execution tool. | LoadAtoms |
| **LoadFixes** | [LoadFixes.ps1](file:///LCM_Inventory/tools/LoadFixes.ps1) | Utility | LCM_Inventory | PowerShell | Utility | LoadFixes execution tool. | LoadFixes |
| **LoadMethods** | [LoadMethods.ps1](file:///LCM_Inventory/tools/LoadMethods.ps1) | Utility | LCM_Inventory | PowerShell | Utility | LoadMethods execution tool. | LoadMethods |
| **LoadRules** | [LoadRules.ps1](file:///LCM_Inventory/tools/LoadRules.ps1) | Utility | LCM_Inventory | PowerShell | Utility | LoadRules execution tool. | LoadRules |
| **MacriumDailyBcrBaseline** | [Invoke-MacriumDailyBcrBaseline.ps1](file:///LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-MacriumDailyBcrBaseline execution tool. | MacriumDailyBcrBaseline |
| **MakeAdmin** | [Make-Admin.ps1](file:///LCM_Inventory/tools/Make-Admin.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Make-Admin execution tool. | MakeAdmin |
| **mcphareadonly** | [mcp_ha_readonly.py](file:///HaSSD06/mcp_ha_readonly.py) | Utility | HaSSD06 | Python | Utility | mcp_ha_readonly execution tool. | mcphareadonly |
| **PrivilegedTool** | [Invoke-PrivilegedTool.ps1](file:///LCM_Inventory/tools/Invoke-PrivilegedTool.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-PrivilegedTool execution tool. | PrivilegedTool |
| **ProposalAction** | [Invoke-ProposalAction.ps1](file:///LCM_Inventory/tools/Invoke-ProposalAction.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-ProposalAction execution tool. | ProposalAction |
| **PublishWorkspaceProposalBundles** | [Publish-WorkspaceProposalBundles.ps1](file:///LCM_Inventory/tools/Publish-WorkspaceProposalBundles.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Publish-WorkspaceProposalBundles execution tool. | PublishWorkspaceProposalBundles |
| **RealRepoDryRun** | [Invoke-RealRepoDryRun.ps1](file:///LCM_Inventory/tools/Invoke-RealRepoDryRun.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-RealRepoDryRun execution tool. | RealRepoDryRun |
| **ReasoningAnalysis** | [Invoke-ReasoningAnalysis.ps1](file:///LCM_Inventory/tools/Invoke-ReasoningAnalysis.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-ReasoningAnalysis execution tool. | ReasoningAnalysis |
| **RegisterBleSupervisionTask** | [Register-BleSupervisionTask.ps1](file:///HaSSD06/tools/Register-BleSupervisionTask.ps1) | Utility | HaSSD06 | PowerShell | Utility | Register-BleSupervisionTask execution tool. | RegisterBleSupervisionTask |
| **RemoveLcmShortName** | [Remove-LcmShortName.ps1](file:///LCM_Inventory/tools/Remove-LcmShortName.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Remove-LcmShortName execution tool. | RemoveLcmShortName |
| **RepairLCMRules** | [Repair-LCMRules.ps1](file:///LCM_Inventory/tools/Repair-LCMRules.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Repair-LCMRules execution tool. | RepairLCMRules |
| **RepairVolumeAcl** | [Repair-VolumeAcl.ps1](file:///LCM_Inventory/tools/Repair-VolumeAcl.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Repair-VolumeAcl execution tool. | RepairVolumeAcl |
| **SafeCopy** | [Safe-Copy.ps1](file:///LCM_Inventory/tools/Safe-Copy.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Safe-Copy execution tool. | SafeCopy |
| **SaveAllSessionMemory** | [Save-AllSessionMemory.ps1](file:///LCM_Inventory/tools/Save-AllSessionMemory.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Save-AllSessionMemory execution tool. | SaveAllSessionMemory |
| **SaveLCMRules** | [Save-LCMRules.ps1](file:///LCM_Inventory/tools/Save-LCMRules.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Save-LCMRules execution tool. | SaveLCMRules |
| **scancommunityissues** | [scan_community_issues.py](file:///HaSSD06/scan_community_issues.py) | Utility | HaSSD06 | Python | Utility | scan_community_issues execution tool. | scancommunityissues |
| **searchsyssensors** | [search_sys_sensors.py](file:///HaSSD06/search_sys_sensors.py) | Utility | HaSSD06 | Python | Utility | search_sys_sensors execution tool. | searchsyssensors |
| **SetGitFileTimes** | [Set-GitFileTimes.ps1](file:///LCM_Tools/tools/Set-GitFileTimes.ps1) | Utility | LCM_Tools | PowerShell | Git Utilities | Sets tracked file modification times to each file's latest Git commit author timestamp. | SetGitFileTimes |
| **SetGitRoot** | [Set-GitRoot.ps1](file:///LCM_Inventory/tools/Set-GitRoot.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Set-GitRoot execution tool. | SetGitRoot |
| **SetLcmActionProgress** | [Set-LcmActionProgress.ps1](file:///LCM_Inventory/tools/Set-LcmActionProgress.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Set-LcmActionProgress execution tool. | SetLcmActionProgress |
| **SetRealRepoTestPlan** | [Set-RealRepoTestPlan.ps1](file:///LCM_Inventory/tools/Set-RealRepoTestPlan.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Set-RealRepoTestPlan execution tool. | SetRealRepoTestPlan |
| **ShowFailureDiagnostic** | [Show-LcmFailureDiagnostic.ps1](file:///LCM_Inventory/tools/Show-LcmFailureDiagnostic.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Show-LcmFailureDiagnostic execution tool. | ShowFailureDiagnostic |
| **ShowHaInventoryApp** | [Show-HaInventoryApp.ps1](file:///HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1) | Utility | HaSSD06 | PowerShell | Utility | Show-HaInventoryApp execution tool. | ShowHaInventoryApp |
| **ShowLcmActiveLauncher** | [Show-LcmActiveLauncher.ps1](file:///LCM_Inventory/tools/Show-LcmActiveLauncher.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Show-LcmActiveLauncher execution tool. | ShowLcmActiveLauncher |
| **ShowLcmAnalysisViewer** | [Show-LcmAnalysisViewer.ps1](file:///LCM_Inventory/tools/Show-LcmAnalysisViewer.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Show-LcmAnalysisViewer execution tool. | ShowLcmAnalysisViewer |
| **ShowRepos** | [Show-Repos.ps1](file:///LCM_Inventory/tools/Show-Repos.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Show-Repos execution tool. | ShowRepos |
| **ShowRules** | [Show-Rules.ps1](file:///LCM_Inventory/tools/Show-Rules.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Show-Rules execution tool. | ShowRules |
| **ShowSupervision** | [Show-Supervision.ps1](file:///LCM_Supervision/tools/Show-Supervision.ps1) | Utility | LCM_Supervision | PowerShell | Utility | Show-Supervision execution tool. | ShowSupervision |
| **ShowWorkspaceInventoryApp** | [Show-WorkspaceInventoryApp.ps1](file:///LCM_Inventory/tools/Show-WorkspaceInventoryApp.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Show-WorkspaceInventoryApp execution tool. | ShowWorkspaceInventoryApp |
| **ShowWorkspaceReadiness** | [Show-WorkspaceReadiness.ps1](file:///LCM_Inventory/tools/Show-WorkspaceReadiness.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Show-WorkspaceReadiness execution tool. | ShowWorkspaceReadiness |
| **SplitTextFile** | [Split-TextFile.ps1](file:///LCM_Inventory/tools/Split-TextFile.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Split-TextFile execution tool. | SplitTextFile |
| **StartRemoteBridge** | [Start-RemoteBridge.ps1](file:///LCM_Inventory/tools/Start-RemoteBridge.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Start-RemoteBridge execution tool. | StartRemoteBridge |
| **SubmitReviewResult** | [Submit-ReviewResult.ps1](file:///LCM_Inventory/tools/Submit-ReviewResult.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Submit-ReviewResult execution tool. | SubmitReviewResult |
| **SyncGeminiInbox** | [Sync-GeminiInbox.ps1](file:///LCM_Inventory/tools/Sync-GeminiInbox.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Sync-GeminiInbox execution tool. | SyncGeminiInbox |
| **SyncLcmAppCatalog** | [Sync-LcmAppCatalog.ps1](file:///LCM_Inventory/tools/Sync-LcmAppCatalog.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Sync-LcmAppCatalog execution tool. | SyncLcmAppCatalog |
| **SyncLcmModuleVersions** | [Sync-LcmModuleVersions.ps1](file:///LCM_Inventory/tools/Sync-LcmModuleVersions.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Sync-LcmModuleVersions execution tool. | SyncLcmModuleVersions |
| **SyncLCMResearchSnapshot** | [Sync-LCMResearchSnapshot.ps1](file:///LCM_Tools/tools/Sync-LCMResearchSnapshot.ps1) | Utility | LCM_Tools | PowerShell | Research Snapshot | Mirrors selected LCM workspace research and governance files to a configured snapshot destination. | SyncLCMResearchSnapshot |
| **SyncToolSymlinks** | [Sync-ToolSymlinks.ps1](file:///LCM_Inventory/tools/Sync-ToolSymlinks.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Sync-ToolSymlinks execution tool. | SyncToolSymlinks |
| **TestExternalTools** | [Test-ExternalTools.ps1](file:///LCM_Inventory/tools/Test-ExternalTools.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Test-ExternalTools execution tool. | TestExternalTools |
| **TestGuardrail** | [Test-Guardrail.ps1](file:///LCM_Inventory/tools/Test-Guardrail.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Test-Guardrail execution tool. | TestGuardrail |
| **TestHaRepoReady** | [Test-RepoReadiness.ps1](file:///HaSSD06_Inventory/tools/Test-RepoReadiness.ps1) | Utility | HaSSD06 | PowerShell | Utility | Test-RepoReadiness execution tool. | TestHaRepoReady |
| **TestLCMRuleHealth** | [Test-LCMRuleHealth.ps1](file:///LCM_Inventory/tools/Test-LCMRuleHealth.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Test-LCMRuleHealth execution tool. | TestLCMRuleHealth |
| **TestRealRepoProposalCleanup** | [Test-RealRepoProposalCleanup.ps1](file:///LCM_Inventory/tools/Test-RealRepoProposalCleanup.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Test-RealRepoProposalCleanup execution tool. | TestRealRepoProposalCleanup |
| **TestRepoReadiness** | [Test-RepoReadiness.ps1](file:///HaSSD06/tools/Test-RepoReadiness.ps1) | Utility | HaSSD06 | PowerShell | Utility | Test-RepoReadiness execution tool. | TestRepoReadiness |
| **TestReviewCommitGate** | [Test-ReviewCommitGate.ps1](file:///LCM_Inventory/tools/Test-ReviewCommitGate.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Test-ReviewCommitGate execution tool. | TestReviewCommitGate |
| **TestWorkspaceDrift** | [Test-WorkspaceDrift.ps1](file:///LCM_Inventory/tools/Test-WorkspaceDrift.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Test-WorkspaceDrift execution tool. | TestWorkspaceDrift |
| **UpdateGemini** | [Update-Gemini.ps1](file:///LCM_Inventory/tools/Update-Gemini.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Update-Gemini execution tool. | UpdateGemini |
| **UpdateProposal** | [Update-Proposal.ps1](file:///LCM_Inventory/tools/Update-Proposal.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Update-Proposal execution tool. | UpdateProposal |
| **UpdateToolCatalog** | [Update-ToolCatalog.ps1](file:///LCM_Inventory/tools/Update-ToolCatalog.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Update-ToolCatalog execution tool. | UpdateToolCatalog |
| **ValidateCopilotProfile** | [Validate-CopilotProfile.ps1](file:///LCM_Inventory/tools/Validate-CopilotProfile.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Validate-CopilotProfile execution tool. | ValidateCopilotProfile |
| **ValidateRules** | [ValidateRules.ps1](file:///LCM_Inventory/tools/ValidateRules.ps1) | Utility | LCM_Inventory | PowerShell | Utility | ValidateRules execution tool. | ValidateRules |
| **WorkspaceAudit** | [Invoke-WorkspaceAudit.ps1](file:///LCM_Inventory/tools/Invoke-WorkspaceAudit.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-WorkspaceAudit execution tool. | WorkspaceAudit |
| **WorkspaceGoodMorning** | [Invoke-WorkspaceGoodMorning.ps1](file:///LCM_Inventory/tools/Invoke-WorkspaceGoodMorning.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-WorkspaceGoodMorning execution tool. | WorkspaceGoodMorning |
| **WorkspaceGoodNight** | [Invoke-WorkspaceGoodNight.ps1](file:///LCM_Inventory/tools/Invoke-WorkspaceGoodNight.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-WorkspaceGoodNight execution tool. | WorkspaceGoodNight |
| **WorkspaceMaintenance** | [Invoke-WorkspaceMaintenance.ps1](file:///LCM_Inventory/tools/Invoke-WorkspaceMaintenance.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-WorkspaceMaintenance execution tool. | WorkspaceMaintenance |
| **WorkspacePush** | [Invoke-WorkspacePush.ps1](file:///LCM_Inventory/tools/Invoke-WorkspacePush.ps1) | Utility | LCM_Inventory | PowerShell | Utility | Invoke-WorkspacePush execution tool. | WorkspacePush |
