# Implementation Plan: BUG-352 - Tool Explorer Run Selection Admin Filter And ToolHelp Fail

## 1. Executive Summary & Problem Context
Tool Explorer defects found in the CRP-343 live tests 2026-11-17 (split from BUG-351 at its Gate 2, operator 2026-11-18).
(a) Run Selection posts {action:DO,target,parameters} to /api/action; the Go daemon needs a command string; no target resolution.
(b) Admin column filter options true/false vs filter code Admin/User.
(c) ToolHelp: no /tool_help route; fallback 2>&1 misses Write-Host (empty help file); Win11 Notepad opens a background tab in the existing non-elevated window.

## 2. Gate 0 Traceability
- Map each implementation component and verification activity to the accepted Gate 0 target-state clause.

## 3. Proposed Changes
### Component 1: Initial Implementation
- Scaffolding baseline implementation for Tool Explorer Run Selection Admin Filter And ToolHelp Fail.

## 4. Verification Plan
- Automated Pester tests and readiness quality gates.
