# Change Request Proposal: LCD Browser Table Port 9876 Channel Compliance & Print/PDF Bridge

- **Proposal ID**: `BUG-067`
- **Target Repository**: `LCM` (`Git_Repositories/.lcm`)
- **Target Version**: `v6.2.1`
- **Domain**: `Desktop REST Bridge & Interactive UI/UX`
- **Author**: Rolf, LCM_AI Engine
- **Status**: `IN_PROGRESS`
- **Created**: `2026-09-04 20:50:00`
- **Priority**: `HIGH`

---

## 1. Objective & Scope

Resolve the unresponsiveness defect in the LCM Tool Explorer ("Print / PDF" button) and enforce architectural compliance with the **Lifecycle Control Dashboard (LCD)** standard, which mandates that all display table operations and communications with the host environment route through the **Port 9876 REST Bridge Daemon** (`http://127.0.0.1:9876`).

---

## 2. Root Cause & Architectural Gap

1. **Missing Channel Interop**: The "Print / PDF" feature in the browser table was implemented as an uncoordinated client-side script (`LcmTablePrintAtom`) that did not register with or dispatch telemetry/audit receipts to the Port 9876 REST daemon.
2. **Export Method Mismatch**: The button markup invoked `LcmTablePrintAtom.openPrintPreview()`, but `lcm-table-print-atom.js` exported only `openModal()` and `enterLivePreview()`, causing an unhandled `TypeError` in the browser console.
3. **Daemon Route Absence**: `LcmDesktopDaemon.ps1` lacked a dedicated endpoint (`POST /print`) to accept, audit, and coordinate print/PDF requests.

---

## 3. Deliverables & Remediation

1. **DTO Definition**: Add `DaemonPrintRequest` class to `LCM_Inventory/modules/LcmDaemon/Classes/DaemonDto.ps1`.
2. **Daemon Controller Action**: Implement `HandlePrint([DaemonPrintRequest]$req)` in `LCM_Inventory/modules/LcmDaemon/Classes/DaemonActionController.ps1` to log structured audit events per `RULE-PS-009`.
3. **Daemon Route**: Add `POST /print` endpoint handling in `LCM_Inventory/tools/LcmDesktopDaemon.ps1`.
4. **Print Engine Alignment**:
   - Update `LCM_Inventory/assets/lcm-table-print-atom.js` to export `openPrintPreview` (aliased to `openModal`).
   - Wire asynchronous dispatch to `http://127.0.0.1:9876/print` during print configuration and execution.
5. **Catalog HTML Generator**: Align button invocation in `LCM_Inventory/modules/LcmToolCatalog.psm1` and recompile scratch HTML artifacts.

---

## 4. Verification Plan

1. **Daemon Endpoint Test**: Verify `POST http://127.0.0.1:9876/print` returns HTTP 200 with status `OK`.
2. **Browser Interactive Test**: Confirm clicking "Print / PDF" in `User_Tools_Explorer_LCM.html` opens the modal and live preview bar without JavaScript exceptions.
3. **Audit Log Verification**: Verify `LcmDesktopDaemon-*.log` captures the print dispatch event.
4. **BCR Review Gate**: Launch `Invoke-BeyondCompareReview.ps1` for operator visual inspection.

