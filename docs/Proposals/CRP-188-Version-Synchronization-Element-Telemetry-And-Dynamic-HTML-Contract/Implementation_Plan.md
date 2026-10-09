# Implementation Plan: CRP-188

## Metadata Header
* **Proposal ID**: `CRP-188`
* **Title**: Version Synchronization Invariant, Element Telemetry Logging, ShowXYZ View Density, and Dynamic HTML-JSON Runtime Contract
* **Bundle Directory**: `LCM_Inventory/docs/Proposals/CRP-188-Version-Synchronization-Element-Telemetry-And-Dynamic-HTML-Contract/`
* **Status**: Suggested (Preliminary)

---

## 1. Planned Component Impact

| Component | Target Location | Planned Action |
| :--- | :--- | :--- |
| **Quality Gate Check** | `LCM_Inventory/tools/Test-WorkspaceReadiness.ps1` | Add AST/regex check: fail gate if file content differs from Git HEAD but version string is identical |
| **Tool Explorer** | `LCM_Inventory/assets/lcm-tool-explorer.js`, `LCM_Inventory/tools/Show-ToolsExplorer.ps1` | Synchronize internal version header; implement dynamic JSON parameter loading |
| **Logging Atom** | `LCM_Shared/modules/Logging/` | Update `Write-LogMessage` to accept and enforce mandatory element version parameter |
| **ShowXYZ Dashboards** | `Show-Subsystems.ps1`, `Show-LCM.ps1`, `CM_CONTROL_HUB.html` | Implement Column Set A/B toggle switch or compound timestamp/version cells with sorting |
| **Daemon Contract** | `LCM_Shared/contracts/DaemonActionContract.json` | Specify lightweight parameter file messaging format over Port 9876 |
| **Governance Policies** | `.agents/rules/DocumentationStandardsPolicy.md`, `PowerShellStandardsPolicy.md` | Formalize version progression and log element version invariants |

---

## 2. Phased Implementation Sequence (Upon Approval)

1. **Phase 1: Decision on Open Question (Major Version Realignment)**:
   - Resolve Option A vs. Option B regarding child element version propagation on major push.
2. **Phase 2: Governance & Automated Gate Enforcement**:
   - Update `DocumentationStandardsPolicy.md` and `Test-WorkspaceReadiness.ps1` with the version-stagnation lint rule.
3. **Phase 3: Telemetry & Logging Modernization**:
   - Update `LCM_Shared` logging classes to prepend constituent version tags to log messages.
4. **Phase 4: ShowXYZ Column Density & Toggle Implementation**:
   - Add the Column Set A/B toggle mechanism to `Show-Subsystems.ps1` and test multi-column sorting.
5. **Phase 5: Port 9876 Daemon Contract & HTML Recompile Reduction**:
   - Define JSON parameter file exchange protocol; refactor HTML viewers to consume dynamic JSON configurations.
