# Walkthrough: BUG-289 - [BUG] Control Hub governance switch does not reflect or apply backend state

## 1. Executive Summary
BUG-289 records an observed Governance control mismatch: the authoritative ledger was `paused` while the Hub presented Governance as `ON`.

## 2. Verification Evidence
- Confirmed at registration: `data/proposals/proposals.json` reported `lcm_mode: paused`.
- Confirmed at registration: the Hub source initializes its Governance control from `proposalsData.lcm_mode` but the observed UI did not communicate a successful or failed daemon request.
- Pending implementation and focused verification.
