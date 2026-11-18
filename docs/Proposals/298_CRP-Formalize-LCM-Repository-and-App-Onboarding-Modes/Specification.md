# Change Request Proposal: CRP-298

```yaml
CRP-ID: CRP-298
Title: Formalize LCM Repository and App Onboarding Modes
Scope: LCM_AI
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-10-20 19:08:00
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Formally define LCM onboarding and distinguish three onboarding capabilities:
1. Onboarding entirely new repositories that originate outside the workspace and are not yet governed by LCM.
2. Updating existing governed repositories so they conform to the current LCM structure ("LCM Shape") without treating them as ungoverned repositories.
3. Onboarding new Apps into LCM_Tools, where the app source and documentation are physically maintained in LCM_Tools and the app is governed within the LCM_Tools collection scope, while LCM_Inventory remains the central administrative inventory and command-trampoline owner.

The CRP must define the purpose, eligibility, scope boundaries, expected outcomes, and completion criteria for each capability, including how each path relates to existing governance and repository structures. Keep the three paths distinct; do not implement or assume a single onboarding workflow before the specification is accepted.

## 2. Gate 0 Contract
### Target State
The authoritative LCM specifications distinguish and formally define three onboarding capabilities:
1. **New external repositories:** eligibility, intake, governance establishment, and completion criteria for repositories originating outside the workspace that have not previously been governed by LCM.
2. **Existing governed repositories:** eligibility, assessment, and completion criteria for bringing repositories already governed by LCM into the current LCM Shape without treating them as ungoverned.
3. **Apps in LCM_Tools:** eligibility, source and documentation placement, collection-scoped governance, and completion criteria for adding an App to LCM_Tools, with administrative inventory and command trampolines remaining centrally owned by LCM_Inventory.

### Invariants and Exit Criteria
The proposal is complete only when its accepted specifications:
- Define the purpose, entry conditions, scope boundary, expected outputs, and exit criteria for each of the three capabilities.
- Explain the distinct governance state and treatment of new external repositories versus existing governed repositories.
- Define the LCM_Tools App source/documentation boundary and its relationship to central LCM_Inventory administration.
- Identify applicable governance safeguards and explain how each onboarding path preserves them.
- Are consistent across the authoritative architecture, requirements, implementation documentation, and any central administrative references affected by the accepted design.
- Pass the verification and review gates required by LCM governance.

### Explicit Non-Goals
This proposal does not authorize onboarding, migrating, or restructuring any specific repository or App. It does not authorize implementing or changing onboarding scripts, templates, catalogs, launchers, or governance engines before the design is accepted. It does not merge the three capabilities into one undifferentiated workflow or presume implementation details not established by the accepted specification.

## 3. Technical Requirements & Invariants
- The three onboarding capabilities MUST remain separately identifiable, with explicit eligibility and scope.
- Updating an already governed repository MUST NOT classify it as a new, ungoverned external repository.
- An App onboarded into LCM_Tools MUST keep its source and App documentation in LCM_Tools; central administrative records and command trampolines remain in LCM_Inventory.
- Implementation work MUST NOT proceed beyond the proposal's authorized lifecycle gate or bypass review safeguards.
