# Bug Repair: BUG-286

```yaml
Bug-ID: BUG-286
Title: [BUG] Control Hub daemon outage capture and automatic recovery
Scope: LCM_Inventory
Version: 10.0.0
Author: rgbig
Date: 2026-10-17 20:33:52
Affected-Repos:
  - LCM_Inventory
Severity: High
Status: In-Progress
Root-Cause: Daemon availability was only represented by a subtle browser status label; local fallback retained cached proposal data without durable incident capture or automatic recovery. The active BCR window also had no visible CRP, BUG, or COH identity.
```

---

## 1. Defect and Intent
An unavailable Control Hub daemon on port 9876 was not converted into a durable, operator-visible repair event. The Hub fell back to stale local data, and the daemon registration status command itself failed under StrictMode when the legacy Run-key value was absent.

## 2. Repair Requirements
- Record a structured local outage receipt before recovery is attempted.
- Make exactly one bounded daemon start attempt for an interactive ShowCM launch.
- Verify recovery through `/ping`; on failure, retain the local fallback and name the receipt.
- Do not introduce polling, automatic browser reloads, or repeated restart loops.
- Make `Register-LcmDesktopDaemon.ps1 -Status` report an absent legacy Run-key value without a StrictMode failure.
- Preserve the `_LCM - Folder Compare` title prefix and append the resolved CRP, BUG, or COH identity to every active BCR window.
