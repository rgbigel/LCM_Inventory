# Implementation Plan: CRP-298 - Formalize LCM Repository and App Onboarding Modes

## 1. Executive Summary & Problem Context
Formally define LCM onboarding and distinguish three onboarding capabilities:
1. Onboarding entirely new repositories that originate outside the workspace and are not yet governed by LCM.
2. Updating existing governed repositories so they conform to the current LCM structure ("LCM Shape") without treating them as ungoverned repositories.
3. Onboarding new Apps into LCM_Tools, where the app source and documentation are physically maintained in LCM_Tools and the app is governed within the LCM_Tools collection scope, while LCM_Inventory remains the central administrative inventory and command-trampoline owner.

The CRP must define the purpose, eligibility, scope boundaries, expected outcomes, and completion criteria for each capability, including how each path relates to existing governance and repository structures. Keep the three paths distinct; do not implement or assume a single onboarding workflow before the specification is accepted.

## 2. Gate 0 Traceability

| Work Component | Target-State Clause | Verification Evidence |
|---|---|---|
| Define new external repository onboarding | 1 | Eligibility, governance establishment, outputs, and completion criteria are explicit. |
| Define existing governed repository update path | 2 | The specification distinguishes modernization into current LCM Shape from first-time governance. |
| Define LCM_Tools App onboarding | 3 | Source/documentation ownership and central LCM_Inventory administration are explicit. |
| Reconcile specifications and safeguards | All | Architecture, requirements, implementation mapping, and applicable governance references agree and pass required review. |

## 3. Proposed Changes
### Component 1: Formal onboarding model
- Specify eligibility, boundaries, expected outputs, and exit criteria for all three onboarding capabilities.

### Component 2: Governance alignment
- Map each capability to its applicable governance status, safeguards, and authoritative documentation.
- Identify affected existing onboarding tools and references without changing them before acceptance.

## 4. Verification Plan
- Verify that the three paths are distinct, complete against their Gate 0 criteria, and consistent across affected authoritative documentation.
- Run applicable documentation/schema and readiness checks after the specification is accepted and implementation scope is authorized.
- Preserve required proposal review gates; this plan does not authorize implementation before acceptance.
