# Change Request Proposal: CRP-129
# Standard Desktop Editor Dispatch and Governance Advisory Hook

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-129` |
| **Lifecycle State** | `OPEN` (Awaiting Operator Review & PROCEED Trigger) |
| **Origin Repository** | `LCM` / Desktop Integration (`.lcm/assets`, `LCM_Inventory`) |
| **Target Scope** | `.lcm/tools/internal/LcmDesktopDaemon.ps1`, `CM_CONTROL_HUB.html`, `SHOW_TOOLS.html`, `Show-Rules.ps1` |
| **Author** | Rolf, LCM_AI Governance |
| **Date** | 2026-09-09 |
| **Priority** | `Medium` |
| **Version Impact** | `v7.5.0` |
| **Extracted From** | Extracted from `CRP-108` (Section 2.5) and `CRP-103` (Section 2.2 Edit Action) to separate desktop editor process dispatch from interactive table display bundling (`BUNDLE-STD-DISPLAY-v7.5.0`). |

---

## 1. Executive Summary & Intent
Extract and formalize the desktop editor dispatch mechanism and accompanying governance advisory hook from the general table display standard.
When operators click `[✏️ Edit]` on table rows representing authoritative rules or governed tool files, the system must dispatch directly to Notepad++ via the Session 1 desktop daemon, while displaying an immediate governance advisory regarding change request obligations.

---

## 2. Normative Specification

### 2.1 Session 1 Notepad++ Dispatch
- Editing source assets from any table row `MUST` dispatch directly to Notepad++ (`notepad++ "<path>"`) or the configured default desktop editor via the Session 1 daemon endpoint.
- If daemon communication is unreachable, fallback to clipboard path copying with explicit user notification.

### 2.2 Governance Advisory Hook
- When an authoritative rule (`.agents/rules/*.md`) or governed LCM tool is opened for editing, the system `MUST` display an immediate visual banner / dialog:
  `⚠️ Note: Changes to authoritative governance rules require a formal Change Request Proposal (CRP) per RULE-LCM-012.`

---

## 3. Affected Components
- `.lcm/tools/internal/LcmDesktopDaemon.ps1`
- `LCM_Inventory/docs/CM_CONTROL_HUB.html`
- `.lcm/tools/internal/SHOW_TOOLS.html`
- `.lcm/tools/internal/Show-Rules.ps1`
