---
Proposal-ID: CRP-101
CR-ID: CR-2026-052
Scope: LCM Platform (.lcm)
Version: v2.2.2
Affected-Repos: [.lcm, LCM_Inventory, HaSSD06_Inventory]
Status: Suggested
Date: 2026-08-31
Author: Rolf, LCM_AI Engine
Target Scope: .lcm / assets / lcm-dashboard-theme.css & Shared Web Dashboards
Affected Version Range: v2.2.1 -> v2.2.2
Impacted Repositories: [.lcm, LCM_Inventory, HaSSD06_Inventory]
---

# CRP-101: Universal Light/Dark Theme Standardization & High-Contrast Design Hardening

## 1. Executive Summary & Intent
Harden the visual design system across all LCM dashboards to ensure WCAG AAA high-contrast compliance in Light Mode (eliminating blurry text and low-contrast pale badges), and propagate the Light/Dark theme switch universally across all workspace HTML viewers.

## 2. Defects & Issues Identified
1. **Light Mode Contrast Deficiency**: In Light Mode, table badges (especially Category tags with pale gray text on white backgrounds) lack contrast, appearing washed out and difficult to read.
2. **Theme Inconsistency**: The Light/Dark theme toggle is currently only implemented in the LCM Tool Explorer, but missing from:
   * LCM Workspace Inventory Explorer (`WORKSPACE_INVENTORY_VIEWER.html`).
   * CM Control Hub (`CM_CONTROL_HUB.html`).
   * Home Assistant Subsystem Inventory Viewer (`SHOW_HA_INVENTORY.html`).

## 3. Proposed Enhancements
1. **High-Contrast Light Theme Palette**:
   * Category badges: Solid dark text (`#1f2328`) with high-contrast tinted border (`#d0d7de`) and distinct background fill (`#eaeef2`).
   * Remove text-shadow blur and enhance font rendering sharpness.
2. **Universal Theme Atom**: Extract the theme engine into a modular shared asset (`lcm-dashboard-theme.css` + `theme-atom.js`) and embed across all 4 major workspace dashboards with shared `localStorage` state synchronization.


