# Implementation Plan: CRP-204

1. Inventory common internal tool-research scenarios and their current search
   behavior.
2. Define a versioned scenario contract and index projection for provider
   preference, fallback, provenance, and result shape.
3. Implement `es.exe` first-path adapters for eligible scenarios.
4. Implement `rg` fallback adapters for incomplete indexed content, unavailable
   Everything service, or query requirements not covered by `es.exe`.
5. Migrate a small representative tool cohort and add scenario-level tests.
6. Measure search-selection behavior and document unsupported scenarios before
   widening adoption.
