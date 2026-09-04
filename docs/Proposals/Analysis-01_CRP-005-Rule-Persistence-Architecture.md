# Analysis-01_CRP-005-Rule-Persistence-Architecture.md

## 1. Metadata

- **CRP ID**: `CRP-005`
- **Author**: Rolf Bercht / Copilot-Gemini Collaboration
- **Date**: 2026-09-04
- **Target Environment**: Antigravity IDE Workspace / Gemini System Configuration
- **Status**: Ratified & Applied

---

## 2. Purpose

Establish a permanent, automated mechanism for enforcing the `TimestampHeaderRule` and strict deterministic behavioral rules globally across all agent interactions, bypassing the limitations of volatile chat session memory.

---

## 3. Current State vs. Target State

- **Current State**: The rule requires manual initialization (`@IRA`, `@THR`, `@TRH`, or `@tsr`) per chat session, leading to synchronization drift when moving between browser interfaces and IDE environments.
- **Target State**: Codification of the behavioral contract and timestamp header pattern into system-level project rules (`.agents/rules/`), ensuring native inheritance across all new sessions without manual prompting.

---

## 4. Implementation Specification

1. **Rule Placement**: Place structural configuration into the Antigravity workspace rules directory: `.agents/rules/InvariantRules.md` and `.agents/rules/macro-definitions.md`.
2. **Mandatory Output Header**: Enforce the output header format on every assistant response:
   ```
   YYYYMMDD_HHMM "<short-task-description>"
   ```
3. **Strict Constraints**:
   - **Zero conversational padding**: Direct technical output without greetings, conversational pleasantries, or non-technical wrap-up text.
   - **Explicit reasoning**: State facts, dependencies, and analytical deductions explicitly.
   - **Strict ASCII usage**: Pure ASCII default across all code, configuration, identifiers, and responses (excluding standard markdown symbols).
   - **No backticks in script generation**: Prohibition of backtick (`` ` ``) line continuation in favor of splatting, pipeline continuations, and parenthesized grouping.
