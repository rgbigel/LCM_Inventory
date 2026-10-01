---
Bug-ID: BUG-097
CR-ID: CR-2026-050
Scope: LCM Platform (.lcm)
Version: v2.2.1
Status: Suggested
Date: 2026-08-31
Author: Rolf, LCM_AI Engine
Target Scope: .lcm / assets / lcm-tool-explorer.js
---

# BUG-097: Tool Explorer '@nn-' Prefix Tool Disappearance on Filter Reset

## 1. Symptom & Description
In the initial rendered view of the LCM Tool Explorer, legacy alias tools prefixed with `@nn-` (such as `@20-KillLogitechUpdateFull.ps1` and `@21-FixMouseFlickerInvariants.ps1`) were visible. However, after resetting or clearing all table filters, the `@nn-` prefixed items unexpectedly disappeared and could no longer be filtered or selected.

## 2. Root Cause Analysis
In `lcm-tool-explorer.js`, the search and filter normalization logic treats leading `@` symbols as command macros or internal metadata filters. When the filter reset function executes, it applies an internal sanitation routine that excludes tools with non-alphanumeric leading symbols unless explicitly matched in macro mode. Additionally, transient unhandled JS exceptions during table rebuild caused popup toasts to close abruptly.

## 3. Remediation Strategy
1. Update `lcm-tool-explorer.js` filtering regex to treat `@` as standard literal characters during global search and reset operations.
2. Fix error toast auto-close timeout so that error diagnostics remain inspectable.


