# Change Request Proposal: CRP-283

`yaml
CRP-ID: CRP-283
Title: Machine-Registry-Only CMD Launcher Authority
Scope: LCM_Inventory
Baseline-Version: 10.0.0
Author: rgbig
Date: 2026-10-16 20:49:31
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
`

---

## 1. Goal
Make the machine `Git_Root` registry value the sole workspace-root authority
for active CMD launchers and Git-root configuration.

## 2. Scope
- Replace active inherited `%Git_Root%`, `%~dp0` root discovery, and hard-coded
  `D:\Git_Repositories` recovery authority in LCM_Inventory CMD launchers.
- Establish one shared registry-query preamble with explicit unavailable/invalid
  registry diagnostics.
- Align Set-GitRoot so User and Process values are not runtime authority.
- Preserve explicit tool-specific paths where they are not workspace-root
  discovery.

## 3. Success Conditions
- Every active launcher resolves `Git_Root` from the machine registry only.
- Invalid/missing authority fails explicitly and does not silently substitute a
  workspace path.
- Wrapper tests cover registry resolution, invalid authority, and command
  target resolution.
