---
Proposal-ID: CRP-025
CR-ID: CR-2026-036
Scope: LCM_Inventory
Version: 10.2.0
Affected-Repos: [LCM_Inventory, .lcm]
Status: OPEN (Bundled in BUNDLE-STD-DISPLAY-10.0.0)
Date: 2026-10-13
Author: rgbig
Target Scope: Global Standard Displays & LCM_Inventory
Affected Version Range: 10.0.0 -> 10.0.0
Impacted Repositories: [LCM_Inventory, .lcm]
Logical-Bundle: BUNDLE-STD-DISPLAY-10.0.0
---

# CRP-025: Single-Instance Control Hub Tab Lifecycle Coordination, Auto-Retirement, and Quiet Render Engine

## 1. Executive Summary & Intent
To prevent browser tab proliferation and clutter during repetitive development, review, and test cycles, establish an automated **Single-Instance Dashboard Tab Coordination Protocol**.
When launching or re-rendering the CM Control Hub dashboard (`CM_CONTROL_HUB.html`), all older, obsolete dashboard instances must automatically detect the new active tab, close themselves via `window.close()`, or retire to a minimal low-footprint banner.

Crucially, **documentation sub-tabs** (`openInNewBrowserTab` for Plans, Walkthroughs, CRP specs, and Tripartite docs) and **external desktop editors** (Notepad++, VS Code) must remain **unconditionally preserved** and exempted from auto-retirement.

---

## 2. Architectural Specification

### 2.1 Tab Lifecycle Policy Matrix

| Tab / Target | Channel / Domain | Policy | Lifecycle Behavior |
|:---|:---|:---|:---|
| **Control Hub Dashboard** (`CM_CONTROL_HUB.html`) | `LCM_CM_CONTROL_HUB_CHANNEL` | Single-Instance | **Auto-Retire**: Newer instance broadcasts `NEW_HUB_OPENED`; older instances call `window.close()` or render deactivation banner. |
| **Documentation Tabs** (`🌐 Show in New Tab`) | `LCM_DOCS_STANDALONE` | Multi-Instance Permitted | **Preserved Unconditionally**: Standalone reference documents remain open. |
| **External Editors** (Notepad++) | Desktop Process (Session 1) | Operator State | **Preserved Unconditionally**: Editor files persist until operator closes them. |

### 2.2 BroadcastChannel Protocol
1. On `DOMContentLoaded`, `CM_CONTROL_HUB.html` initializes `HUB_CHANNEL = new BroadcastChannel("LCM_CM_CONTROL_HUB_CHANNEL")`.
2. Generates a unique `INSTANCE_ID` (`hub_<timestamp>_<random>`).
3. Broadcasts `{ type: "NEW_HUB_OPENED", instanceId: INSTANCE_ID }`.
4. Peer dashboard tabs receiving the message verify `instanceId !== INSTANCE_ID` and execute graceful tab retirement.

### 2.3 Quiet Render Parameter (`-NoLaunch`)
* Updated [`LCM_Inventory/tools/Show-CmControlHub.ps1`](file:///d:/Git_Repositories/LCM_Inventory/tools/Show-CmControlHub.ps1) with `[switch]$NoLaunch`.
* Allows automated tasks, CI scripts, and background daemons to update the offline cache without spawning new browser windows.

---

## 3. Verification & Acceptance Criteria
1. **Single-Instance Test**: Launching `Show-CmControlHub.ps1` multiple times must result in exactly one active Control Hub dashboard tab.
2. **Docs Preservation**: Clicking `[ 🌐 Show in New Tab ]` on a Plan or CRP spec must open a standalone tab that is never auto-closed.
3. **Quiet Rendering**: `Show-CmControlHub.ps1 -NoLaunch` regenerates `scratch/CM_CONTROL_HUB.html` with zero browser activations.

