# Implementation Plan: BUG-286 - [BUG] Control Hub daemon outage capture and automatic recovery

## 1. Executive Summary & Problem Context
BUG-286 repairs the missing accountable response to a Control Hub daemon outage and adds an operator-authorized BCR review identity to the active Beyond Compare window. It does not implement the separate CRP-284 foreground activation work.

## 2. Proposed Changes
### Component 1: Outage receipt and bounded recovery
- Add a structured `data/incidents/daemon-outage-*.json` receipt before starting recovery.
- Start the existing daemon once, wait for a bounded `/ping` verification window, and update the same receipt with `recovered` or `recovery_failed`.
- Use the live HTTP Hub only after successful verification; otherwise retain the local artifact fallback and disclose the receipt path.

### Component 2: Status command safety
- Retrieve the optional legacy Run-key property through the PowerShell property collection so an absent value is an expected status, not a StrictMode exception.

### Component 3: BCR review identity
- Append the resolved CRP, BUG, or COH identity to the `_LCM - Folder Compare` window title after either window reuse or launch.
- Preserve the `_LCM` prefix so existing review-window detection remains valid.

## 3. Verification Plan
- Run `ControlHubSafety.Tests.ps1`.
- Parse changed PowerShell scripts with the PowerShell AST parser.
- Verify `Register-LcmDesktopDaemon.ps1 -Status`.
- Verify the live daemon `/ping` endpoint and confirm the BUG-286 ledger record.
- Run `MacriumBcrReview.Tests.ps1` and confirm that an active `_LCM` window retains its identity suffix.
