# Walkthrough: CRP-280 - Catalog-Synced Show Command Macros and Managed Alias Maintenance

## 1. Feasibility and Scope Decision

Feasible. The tool catalog already records the command name, target, and
operator-facing metadata required to derive safe `Show*` entries.

The design deliberately has two paths:

1. Existing eligible `Show*` tools synchronize automatically through catalog
   metadata and validation.
2. Every other command, including legacy Gemini `@` aliases, is maintained by
   an explicit sub-action.
3. Every standard display command prefers an IDE-hosted display. Browser
   bookmarks are the operator-controlled separate-window route; IDE-host
   unavailability reports a limitation and does not silently launch a browser.

This prevents a temporary agent interpretation or arbitrary chat phrase from
becoming permanent workspace behavior.

## 2. Verification Evidence

- CRP intake and initial specification completed.
- Implementation and validation are pending.
