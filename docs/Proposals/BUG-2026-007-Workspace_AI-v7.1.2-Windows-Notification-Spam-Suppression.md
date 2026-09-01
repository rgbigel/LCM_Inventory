---
Bug-ID: BUG-2026-007
CR-ID: CR-2026-051
Scope: Workspace_AI
Version: v7.1.2
Status: Suggested
Date: 2026-08-31
Author: Rolf, Workspace_AI Engine
Target Scope: Antigravity IDE Integration & Notification Subsystem
---

# BUG-2026-007: Excessive Repetitive Windows Notifications during Project Rule Access

## 1. Symptom & Description
The Windows Notification Center accumulated 50+ identical notifications with the message: *"Antigravity IDE: Consulting Project Standards Documentation"*.

## 2. Root Cause Analysis
Every background tool execution or sub-query that touches governance rule files in `.agents/rules/` triggers an individual desktop notification event without debouncing or rate-limiting.

## 3. Remediation Strategy
1. Implement client-side notification debouncing / cooldown (minimum 60-second window for identical notification payloads).
2. Suppress background telemetry notifications for routine read-only rule validations.
