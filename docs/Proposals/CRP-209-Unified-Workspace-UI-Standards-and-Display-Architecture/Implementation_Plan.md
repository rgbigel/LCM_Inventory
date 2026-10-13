# CRP-209: Implementation Plan - Unified Workspace UI Standards and Display Architecture

```yaml
CRP-ID: CRP-209
Plan-State: suggested
Progress-State: undecided
Target-Repos:
  - LCM_Inventory
  - LCM_AI
  - LCM_Tools
  - LCM_Supervision
  - HaSSD06
  - HaSSD06_Inventory
  - RollingCalendar
  - NextBootTray
  - BootEntryManager
```

## 1. Technical Strategy

Transform the current HTML-only [`DisplayStandardsPolicy.md`](file:///d:/Git_Repositories/.agents/rules/DisplayStandardsPolicy.md) into a comprehensive, multi-framework workspace UI governance standard. Implement automated AST/CSS quality gate verifiers to ensure zero hardcoded styling, token parity, and desktop dispatch adherence across all repositories.

---

## 2. Phase Breakdown

### Phase 1: Policy Synthesis & Rule Authority Alignment
- [x] Expand `.agents/rules/DisplayStandardsPolicy.md` to version 10.0.0 with `RULE-DSP-001` through `RULE-DSP-015`.
- [x] Incorporate `CM_CONTROL_HUB_IMPLEMENTATION_0.html` architecture, Lucide SVG vector iconography, IBM Plex typography, native Windows Desktop GUIs (WPF, WinForms), NotifyIcon System Tray lifecycles, and Print-to-PDF CSS paged media standards.
- [x] Synchronize discovery surfaces:
  - Update root [`AGENTS.md`](file:///d:/Git_Repositories/AGENTS.md) Quick-Reference table.
  - Update [`LCM_AI/docs/LCM-Rules-Cross-Reference.md`](file:///d:/Git_Repositories/LCM_AI/docs/LCM-Rules-Cross-Reference.md).

### Phase 2: Design Token & Shared Asset Consolidation
- [ ] Reconcile `StandardTableDisplay.css` and `lcm-dashboard-theme.css` in `LCM_Inventory/assets/` and `LCM_Inventory/assets/`.
- [ ] Define standardized CSS custom properties for Paged Media (`@page`, `@media print`).
- [ ] Create a shared WPF ResourceDictionary snippet (`WpfThemeTokens.xaml` in `LCM_Shared`) mapping standard LCM dark/light hex codes to XAML brushes.

### Phase 3: Automated Quality Gate Verification
- [ ] Implement `Assert-WorkspaceUiCompliance` in `LCM_AI/modules/WorkspaceQualityGates.psm1`:
  - Static regex scan across `.html` and `.css` files detecting hardcoded color strings (flags violations of `RULE-UI-014`).
  - Detection of bare `Start-Process` on HTML/GUI files without `Invoke-InteractiveDesktop.ps1` routing (`RULE-UI-006`).
  - AST verification for WinForms/WPF tools verifying DPI awareness and modal escape handling.

### Phase 4: Subsystem & Candidate Repository Alignment
- [ ] `RollingCalendar`: Reconcile embedded CSS print styles with canonical LCM font and margin tokens.
- [ ] `NextBootTray`: Verify single-instance mutex and clean shell notify icon deregistration.
- [ ] `HaSSD06`: Validate `Show-HaAuthDialog.ps1` WPF styling parity with `StandardTableDisplay.css`.
- [ ] `CM_CONTROL_HUB.html`: Harden numeric priority and column negation filter matching.

---

## 3. Verification Strategy

1. **Rule Discovery Verification**:
   - Execute `Test-LCMRuleHealth.cmd` / `ValidateRules.cmd` to confirm zero rule link drift.
2. **Quality Gate Execution**:
   - Run `Test-WorkspaceReadiness.ps1` across all governed repositories.
3. **Visual Review Gating (Gate 2)**:
   - Launch `bcr LCM_Inventory` and `bcr LCM_AI` to inspect all synthesized documentation and policy diffs prior to operator acceptance.
