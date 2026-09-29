# Implementation Plan: CRP-196

1. Define canonical states, transition metadata, fast-complete receipts, and
   legacy-state migration rules.
2. Refactor lifecycle services so they enforce the same transition contract.
3. Build status filters and valid-action menus from transition metadata.
4. Replace the sidecar with a contextual `Actions` dropdown and a global App
   focus control.
5. Implement the lifecycle rail, reverse routes, held route, and review tools.
6. Add migration, transition, and UI workflow tests.