# Walkthrough: CRP-324

## Strategy Mapping Relational Engine, Referential Integrity Validation, and ShowStrategies UI

### Overview
CRP-324 introduces the formal **Strategy Mapping Architecture** to LCM, connecting distinct, decoupled CRPs into cohesive architectural horizons without combining them into monolithic, high-risk proposals.

---

### Key Capabilities Introduced

#### 1. Relational Strategy Model in `proposals.db`
- `strategies`: Stores strategy metadata, overall lifecycle state, and ownership.
- `strategy_crps`: Relational mapping table binding strategies to their constituent CRPs with goal roles (`delivers`, `aligns`, `prerequisite`).

#### 2. Referential Consistency Guard (`Test-LcmStrategyConsistency.ps1`)
- Guarantees referential integrity: every referenced CRP must exist and cannot be `rejected`, `cancelled`, or `superseded`.
- Prevents stale or broken strategies from silently misleading operators.

#### 3. Operator Interface (`ShowStrategies` & `ShowCM`)
- **`ShowStrategies`** (`ShowStrategies` command): Provides an executive-level overview of workspace strategies, completion progress, and constituent CRP statuses.
- **`ShowCM` Integration**: One-click navigation pill in `CM_CONTROL_HUB.html` connecting proposals directly to their parent strategies.

---

### Verification Strategy
- **AST Hygiene**: Validates syntax across all PowerShell scripts and modules.
- **Database Parity**: Asserts 3-way synchronization between `strategies.json`, `proposals.db`, and `strategies.sql`.
- **Integrity Gate**: Executes `Test-LcmStrategyConsistency.ps1` to ensure zero broken references across seed strategies.

