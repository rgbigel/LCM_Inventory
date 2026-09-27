# Walkthrough: CRP-184 Tool Explorer Runtime Dropdown Column Dynamic Auto-Widening

## Overview
This walkthrough defines the verification checklist for runtime dynamic dropdown column widening in Tool Explorer once approved and implemented.

## Verification Checklist

1. **Initial Inspection**:
   - Open `SHOW_TOOLS.html`.
   - Observe columns `Group`, `Role`, `Category` are strictly compact (just fitting header labels).
2. **Dynamic Widening on Selection**:
   - In `Group` filter dropdown, select a long subsystem name.
   - Verify the `Group` column widens automatically so the selected option text is legible and unclipped.
3. **Reset Behavior**:
   - Click `↺ Reset`.
   - Verify the column smoothly returns to its minimal default width.
