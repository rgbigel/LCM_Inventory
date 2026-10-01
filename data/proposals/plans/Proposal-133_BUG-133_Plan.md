# Implementation Plan: Proposal-133 (BUG-133)
# LCM Tool Explorer UI Regressions, Parameter/Help Execution Defects, Navigation Fixes, and Preset Filter Engine

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `BUG-133` / `#133` |
| **Target Repositories** | `LCM`, `LCM_Inventory`, `LCM_AI` |
| **Target Version** | `v7.5.0` |
| **Status** | `IN_PROGRESS` |
| **Date** | 2026-09-10 |

## 1. Technical Scope
Resolves 12 defects and enhancements across Tool Explorer and standard displays:
1. Model A linked static CSS architecture in `LCM_Inventory/assets/` (`StandardTableDisplay.css` base + `LCMToolCatalog.css` cascade).
2. Dynamic version header and subtitle, eliminating hardcoded `V6.1.0`.
3. Dynamic Subsystem metric card binding to dropdown selection (clicking is a No-OP).
4. Smart parameter gating: execute immediately unless mandatory non-default parameters exist.
5. Strict `Boolean(tool.NoExit)` evaluation to ensure `May Exit` tools close console windows.
6. Static script path resolution from LCM catalog data (`tool.RelativePath`) for Notepad help display.
7. Restore on-screen `[🔄 Refresh]` button.
8. Clean legacy `LCD` entry from Subsystem dropdown and catalog seeds.
9. Safe Back button navigation fallback.
10. Workspace-wide `-h` / `-Help` audit per `RULE-PS-010`.
11. Alternative B structured negative search query tokens (`!Column:Value`).
12. Filter presets dropdown engine with interactive Add / Replace / Delete `#n` custom preset manager.
