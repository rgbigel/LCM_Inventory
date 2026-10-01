# Implementation Plan: BUG-205

1. Replace direct `toUpperCase()` calls on proposal priority values with nullish
   fallback plus string normalization.
2. Regenerate the Control Hub artifact from its source template.
3. Validate rendering with numeric priorities, including `0`, and confirm filter
   reset no longer throws.
