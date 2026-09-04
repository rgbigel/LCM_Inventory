# Implementation Plan: Proposal 67 (CR-PROP-67 / CRP-2026-021)

## Summary
Implement Port 9876 REST communication channel compliance for LCD display table Print / PDF export and fix button unresponsiveness.

## Proposed Changes
1. `.lcm/modules/LcmDaemon/Classes/DaemonDto.ps1`: Add `DaemonPrintRequest` DTO.
2. `.lcm/modules/LcmDaemon/Classes/DaemonActionController.ps1`: Add `HandlePrint` action controller method.
3. `.lcm/tools/internal/LcmDesktopDaemon.ps1`: Add `POST /print` endpoint.
4. `.lcm/assets/lcm-table-print-atom.js`: Export `openPrintPreview` and add async daemon dispatch to `http://127.0.0.1:9876/print`.
5. `.lcm/modules/LcmToolCatalog.psm1`: Align button trigger markup.
6. Recompile `User_Tools_Explorer_LCM.html`.
7. Restart daemon and verify endpoint.
