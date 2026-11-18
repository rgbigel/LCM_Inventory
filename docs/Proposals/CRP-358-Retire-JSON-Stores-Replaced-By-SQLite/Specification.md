# Specification: CRP-358

Module: docs/Proposals/CRP-358-Retire-JSON-Stores-Replaced-By-SQLite/Specification.md  
Purpose: Retire JSON Stores Replaced By SQLite  
Path: LCM_Inventory/docs/Proposals/CRP-358-Retire-JSON-Stores-Replaced-By-SQLite/Specification.md  
Authors: Rolf  
Version: 10.7.4
Status: Suggested  
Date: 2026-11-18 15:41:02

```yaml
CRP-ID: CRP-358
Title: Retire JSON Stores Replaced By SQLite
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 15:41:02
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Analysis 2026-11-18 (topic C): JSON is the authority in practice although RULE-LCM-001 names proposals.db. Retire in order: strategies.json, tool_intents.json, tool_catalog.json, proposals.json (last; cohorts, obligations and settings are missing in the DB). Each step: read-only reconciliation report (key sets, field comparison, settings) under data/analysis, operator decision, schema additions, store accessor switched to SQLite, JSON deleted in the same change set as its writers.
- Review: this Specification only (Plan and Walkthrough not written yet).

## 2. Gate 0 Contract
### Target State
Define the observable completed state this proposal will achieve.

### Invariants and Exit Criteria
Define the evidence that proves the target state while preserving applicable governance safeguards.

### Explicit Non-Goals
Define work intentionally excluded from this proposal. When this is ordinary,
evidently scoped work, the default Non-Goal applies: Cause no havoc; ask rather
than invent or infer, and avoid unnecessary complexity.
