# Implementation Plan: BUG-289 - [BUG] Control Hub governance switch does not reflect or apply backend state

## 1. Executive Summary & Problem Context
The Hub's Governance control is out of sync with the authoritative `lcm_mode` ledger state and does not report the result of a request. The first repair is reliable backend-confirmed green/red governance display; bounded yellow recovery is a separately gated extension of that same state model.

## 2. Proposed Changes
### Component 1: Diagnose and repair the ON/OFF bridge
- Trace `toggleLcmMode()`, daemon command execution, and the ledger update route.
- Make the rendered state derive only from refreshed backend data.
- Render pending, success, unchanged, and failure outcomes in the action-result area.

### Component 2: Add the explicit governance-state model
- Define confirmed `on`, `off`, and scoped `bounded` state fields and audit metadata.
- Add red OFF display and an explicit authorization disclosure.
- Add yellow bounded display only after the normal bridge is reliable.

### Component 3: Enforce bounded recovery limits
- Require a declared target scope, operator authorization, reason, and timestamp.
- Route only the permitted recovery operation through the bounded state.
- Preserve Gate 2 and prevent unrelated actions until normal governance resumes.

## 3. Verification Plan
- Focused daemon/API and Hub-rendering tests for state transitions and failure disclosure.
- Cohort lifecycle tests proving scoped recovery cannot broaden to unrelated members.
- PowerShell AST validation and the applicable Control Hub safety suite.
