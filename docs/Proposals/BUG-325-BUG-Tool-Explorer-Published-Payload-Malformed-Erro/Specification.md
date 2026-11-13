# Change Request Proposal: BUG-325

```yaml
CRP-ID: BUG-325
Title: [BUG] Tool Explorer Published Payload Malformed Error Due to Attribute Order in Tag Parser
Scope: LCM_Inventory
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-13 12:38:22
Status: Verified
Plan-State: verified
Progress-State: verification
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
On startup or browser freshness reconciliation, the LCM Tool Explorer surfaced a red badge:
`Failed - published tool payload malformed`.
This was caused by an attribute ordering mismatch between the generator template in `LcmToolCatalog.psm1` (`type` preceding `id`) and the Go HTTP daemon `do.exe` parser in `src/do/daemon.go` (`strings.Index` looking strictly for `id` preceding `type`). The daemon returned an empty JSON dictionary `{}` with HTTP 200, which failed the array assertion in `assets/lcm-tool-explorer.js`.

The intent of BUG-325 is to:
1. Standardize the tag declaration in `modules/LcmToolCatalog.psm1` to `<script id="lcm-display-data" type="application/json">`.
2. Harden `src/do/daemon.go` to match both attribute orders (`id` before `type` or `type` before `id`).
3. Re-render `SHOW_TOOLS.html` and recompile `do.exe`.
4. Re-verify with Pester test suite `tests/LcmDisplayFreshness.Tests.ps1`.

## 2. Gate 0 Contract
### Target State
- `/displays/data/tools` returns `{ "tools": [...] }` containing all 317 tools.
- `/displays/status/tools` reports `state: Current`.
- The Tool Explorer UI loads and reconciles without displaying a malformed payload error.

### Invariants and Exit Criteria
- `LcmToolCatalog.psm1` preserved in UTF-8 without BOM.
- Pester suite `tests/LcmDisplayFreshness.Tests.ps1` passes 17/17 tests.
- Recompiled `do.exe` runs elevated under the single-owner task `LCM_DesktopDaemon_rgbig`.

### Explicit Non-Goals
- Altering the Tool Explorer UI layout or filter engine.
- Modifying other standard display routes or schemas.

## 3. Technical Requirements & Invariants
- Conforms to `RULE-DSP-001` through `RULE-DSP-016` (Display Standards).
- Conforms to `RULE-PS-008` (Metadata Headers & Timestamps).
- Conforms to `RULE-REV-001` (Review & Commit Governance).
