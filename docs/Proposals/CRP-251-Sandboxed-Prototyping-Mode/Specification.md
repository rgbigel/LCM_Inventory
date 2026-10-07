# CRP-251: Sandboxed Prototyping Mode

| Metadata Field | Value |
|---|---|
| **Proposal ID** | `CRP-251` |
| **Lifecycle State** | `SUGGESTED` |
| **Origin Repository** | `LCM_Inventory` |
| **Date** | 2026-10-07 |

## Objective

Define a Prototyping Mode that permits design and initial implementation in an
isolated sandbox rather than the live governed workspace. It intentionally
does not require a normal CRP or review while the work remains sandbox-only.

## Required Contract

- The prototype workspace must be isolated from live repositories, registries,
  credentials, publishing, and destructive tools.
- Prototype outputs must be labelled non-production.
- Prototyping Mode has explicit entry, status, and termination records.
- Promotion is optional. A promoted artifact becomes a normal CRP with
  proposal, review, validation, and commit requirements.

## Non-Goals

- Do not bypass governance for changes in live repositories.
- Do not make sandbox output authoritative without explicit promotion.
