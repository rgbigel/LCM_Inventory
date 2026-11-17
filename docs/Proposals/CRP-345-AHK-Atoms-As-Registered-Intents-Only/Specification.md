# Specification: CRP-345

Module: docs/Proposals/CRP-345-AHK-Atoms-As-Registered-Intents-Only/Specification.md  
Purpose: AHK Atoms As Registered Intents Only  
Path: LCM_Inventory/docs/Proposals/CRP-345-AHK-Atoms-As-Registered-Intents-Only/Specification.md  
Authors: Rolf, Claude  
Version: 10.6.4
Status: Suggested  
Date: 2026-11-17 13:40:14

```yaml
CRP-ID: CRP-345
Title: AHK Atoms As Registered Intents Only
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-17 13:40:14
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 6
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-17: AHK actions only through registered AHK atoms (intents, each with its own elevation flag); undefined AHK intents are refused. Depends on the intent-level elevation CRP.

## 2. Gate 0 Contract
### Target State
- Every AutoHotkey action is an AHK atom registered as its own intent in `tool_intents` (with its own `elevated` flag); the AHK runner executes only registered atoms and refuses any undefined AHK intent (logged).
- First atoms: the existing Macrium Browse Image dialog atom (`tools/automation/Mount-MacriumBrowseDialog.ahk`) and a Beyond Compare tab-listing atom (reads tab names; read-only) for CRP-346.
- AHK normally runs non-elevated; an atom runs elevated only when its intent says so (CRP-343).

### Invariants and Exit Criteria
- No ad-hoc AHK script execution path remains (search for direct `AutoHotkey*.exe` calls outside the runner returns none).
- Exit: listing the registered AHK atoms from the catalog; an unregistered AHK request is refused with a log line; the Macrium dialog atom still mounts (live BCR).

### Explicit Non-Goals
- AHK automation outside BCR (operator: the only current use case is within BCR).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.

## 4. External Tool Documentation (amendment, operator 2026-11-17)

Finding (2026-11-17): AutoHotkey is used but documented nowhere.
- Not in `.copilot/CopilotTools.md` (the tool paths list named in `ACTIVE_CONTEXT.md`), not in the LCM docs or install runbooks, and not in `tools.db` (the `tools` table holds no executable type; its types are PowerShell, Python, Batch, Registry, Shortcut, Instruction).
- In use: `LCM_Inventory/modules/LcmAhkAtoms.psm1` (BUG-313) probes `D:\Tools\AutoHotkey\v2\AutoHotkey64.exe` and four further paths, offers Window Spy, and `Invoke-LcmAhkScript`; installed: `D:\Tools\AutoHotkey\v2\` and `D:\Tools\AutoHotkey.AutoHotkey\v2\`.
- `Invoke-LcmAhkScript -InlineScript` executes arbitrary AHK code through a temporary file; this contradicts "only registered atoms" and is removed or restricted to registered atoms by this CRP.

Target state additions:
1. AutoHotkey is documented as an external tool (path, version, purpose, which atoms use it) in the external tool list and in the install prerequisites.
2. Audit: every external executable that LCM code invokes is documented; one check lists invoked external tools (from code and `tool_intents.executable`) against the documented list and reports undocumented ones (operator: "we must check that all tools we used are documented").
3. Exit criterion addition: the audit reports zero undocumented external tools, or each remaining one is registered for documentation.
## Absorbed Operator Remarks

Shared operator remark of 2026-11-17, quoted verbatim in CRP-343 `Specification.md`.

> i will do refresh on BCR tabs myself until we have this sortedout, no problem.
> your remark "I didn't port the CRP-309 tokens. They wouldn't stop a web page: most actions need no token, the admin tier accepts a caller name the page writes itself, and /api/token gives a token to anyone. Real caller authentication belongs to CRP-343."
> required that 343 is amended accordingly.
> What will happen now when i refresh an existing ShowXXX window? will it fail?
> more questions to the AHK crp:
> - is it mentioned in the list of external tools? we must check that all tools we used are documented.

(Operator, 2026-11-17; amends CRP-343 section 6 and CRP-345 section 4.)