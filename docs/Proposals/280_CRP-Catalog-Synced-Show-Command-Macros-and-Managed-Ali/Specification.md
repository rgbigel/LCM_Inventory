# Change Request Proposal: CRP-280

```yaml
CRP-ID: CRP-280
Title: Catalog-Synced Show Command Macros and Managed Alias Maintenance
Scope: LCM_Inventory
Baseline-Version: 10.2.0
Author: rgbig
Date: 2026-10-15 18:03:28
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Make existing, catalogued `Show*` tool commands durable bare-word macros through
a deterministic synchronization path. Provide a separate explicit maintenance
action for every non-`Show*` macro and legacy Gemini `@` alias.

## 2. Technical Requirements & Invariants

### 2.1 Catalog-Synced `Show*` Commands

- Only an existing tool-catalog entry with an executable, validated target is
  eligible for automatic macro synchronization.
- An eligible command must have a `Show*` primary command name and declared
  syntax, target, and description metadata.
- Every standard display command must prefer an IDE-hosted display when the
  invoking host supports it. It must not automatically open an external
  browser merely because the IDE host cannot render the display.
- A separate-window browser view remains operator-controlled through an
  existing browser bookmark or an explicit browser action. It is not the
  fallback behavior of a bare standard-display command.
- When IDE hosting is unavailable, a standard-display command must report
  that limitation and its local display URL without launching a browser.
- Synchronization must generate or update only a managed `Show*` section in
  `macro-definitions.md`; manually maintained macro entries remain untouched.
- Every generated entry must expose its bare-word command as the primary
  syntax and may retain `@Command` as a backward-compatible alias.
- Missing targets, duplicate command names, duplicate aliases, malformed
  syntax, or a conflict with an unmanaged entry must fail closed with a
  diagnostic report and make no partial update.

### 2.2 Explicit Macro and Alias Maintenance

- Provide a named sub-action for adding, changing, retiring, listing, and
  validating non-`Show*` macros and legacy Gemini `@` aliases.
- The sub-action must require explicit command name, intended target or
  behavior, syntax, aliases, and a short operator-facing description.
- It must reject a definition inferred only from natural-language chat text,
  a one-time tool use, or an unverified filesystem match.
- Legacy Gemini aliases remain backward-compatible metadata only; they must
  never be treated as a replacement for the primary bare-word syntax.
- Every mutation must report the exact affected definition and validation
  result before it is persisted.

### 2.3 Shared Validation

- Validate macro names and aliases case-insensitively across generated and
  manually managed entries.
- Verify declared script targets exist and that declared command parameters
  agree with the target's help contract where introspection is available.
- Preserve UTF-8 without BOM, CRLF line endings, deterministic ordering, and
  the current macro-definition document structure.
- A dry-run mode must render proposed changes without writing the canonical
  file.
- The process must not modify an IDE attachment binding or assume that `@`
  syntax is executable in every IDE.

## 3. Acceptance Criteria

- Synchronizing the current catalog adds valid `Show*` definitions such as
  `ShowCM` without modifying manual definitions.
- Bare standard-display commands do not launch an external browser when IDE
  hosting is unavailable; an explicit browser action remains available
  separately.
- A missing target or name/alias collision makes no file change and returns
  actionable diagnostics.
- A non-`Show*` definition can be added only through the explicit maintenance
  sub-action and is visible in a list/validation result.
- Dry-run output is deterministic and write-free.
- Focused tests cover generated definitions, manual maintenance, collisions,
  target validation, legacy aliases, and dry-run behavior.
