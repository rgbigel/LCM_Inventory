# BUG-205: Control Hub Numeric Priority Filter Crash

```yaml
Bug-ID: BUG-205
Priority: 10
Scope: LCM Control Hub v1.4.0 proposal filtering and rendering
Status: Active
Plan-State: approved
Progress-State: in_progress
Affected-Repos:
  - Workspace_Inventory
```

## Defect

The LCM Control Hub throws `TypeError: (intermediate value).toUpperCase is not
a function` when a proposal has a numeric priority. The exception stops table
rendering, including the Reset filters action.

## Root Cause

The generated client-side template assumes every `priority` value is a string.
The ledger now permits numeric priorities from $0$ through $10$.

## Fix Contract

Normalize `priority` with `String(value ?? 'M')` at every client-side filtering,
sorting, and rendering boundary. This preserves numeric zero and supports both
legacy letter priorities and the numeric priority model.
