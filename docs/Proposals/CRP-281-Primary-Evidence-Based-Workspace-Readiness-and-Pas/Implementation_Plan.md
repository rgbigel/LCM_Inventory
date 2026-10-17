# Implementation Plan: CRP-281 - Primary Evidence-Based Workspace Readiness and Passive Legacy Checks

## 1. Design Cycles
1. Define the evidence receipt schema and required input fingerprints.
2. Build documentation, rule, flow, and implementation evidence providers.
3. Bind proposal progress to current applicable receipt evidence.
4. Add passive adapters for broad readiness, topology, and dashboard checks.
5. Compare primary and legacy coverage over accepted CRPs before retirement.

## 2. Verification
- Unit-test each provider against known evidence and known discrepancies.
- Verify changed inputs invalidate the matching receipt.
- Verify passive providers cannot mutate lifecycle state or block design.
- Demonstrate coverage parity before a legacy primary check is retired.
