---
Proposal-ID: CRP-091
CR-ID: CR-2026-042
Scope: HaSSD06
Version: v7.1.1
Affected-Repos: [HaSSD06, HaSSD06_Inventory]
Status: Suggested
Date: 2026-08-30
Author: rgbig
Target Scope: HaSSD06 / templates / sensor.active_notification_count_fixed
Affected Version Range: v7.1.1
Impacted Repositories: [HaSSD06, HaSSD06_Inventory]
---

# CRP-091: Active Notification Count Template Sensor Default Value Fix

## 1. Executive Summary & Intent
Fix the template validator exception in Home Assistant logs:
```
Received invalid sensor state: unknown for entity sensor.active_notification_count_fixed, expected a number
```

## 2. Root Cause & Solution
* **Root Cause**: The Jinja template evaluating active persistent notifications returns string literal `'unknown'` or `None` during startup before notification components are initialized, which violates the `state_class: total` or numeric device class constraint.
* **Remediation**: Append `| int(0)` and `default(0)` to the sensor template filter so it deterministically outputs `0` when no notifications exist.

## 3. Verification Plan
* Reload template entities in Home Assistant.
* Confirm `sensor.active_notification_count_fixed` state is integer `0`.
* Confirm zero validation errors in `system_log/list`.

