# Change Request Proposal (CRP): Google Drive Gemini Inbox Watcher & Security Intake Queue

Module: LCM_Inventory/docs/Proposals/CRP-021-Gemini-Inbox-Watcher.md  
Purpose: Change Request Proposal for controlled intake of Google Gemini cloud instructions, mandatory timestamping, and proposal ledger routing.  
Path: LCM_Inventory/docs/Proposals/CRP-021-Gemini-Inbox-Watcher.md  
Authors: Rolf, LCM_AI Engine  
Version: 1.0.0 (LCM Baseline: 7.0.0)  
Status: ACCEPTED / COMPLETED  
Date: 2026-08-30  

---

## 1. Executive Summary & Impact Classification

* **Proposal ID**: `CRP-021` (`CR-2026-032` / `Proposal #21`)
* **Target Domain**: `LCM_AI & .lcd Tooling Hub`
* **Impact Level**: `LOW` (Non-breaking security intake layer and tool catalog addition).
* **Target Milestone**: `LCM v7.0.0`

---

## 2. Problem Statement & Motivation

Cloud-based Google Gemini (Web, Apps, Gems) operates inside Google's cloud boundary and cannot make direct inbound calls to local developer machines. When Gemini produces diagnostic findings, BUG reports, or tasks in Google Drive, the workspace requires:
1. **Security Isolation**: External instructions must never execute directly without operator authorization.
2. **Standardized Proposal Intake**: All items must be converted into standard LCM proposals (`state: suggested`, `progress_state: undecided`) for operator batch management (`do`, `defer`, `delete`).
3. **Mandatory Timestamping Invariant**: Gemini must supply explicit timestamps (ISO 8601 or local datetime) for auditability.
4. **Clean Inbox Invariant**: Processed files must be moved to `D:\GDrive\LCM\INBOX/archive/` to keep the active inbox clear.

---

## 3. Implemented Components

1. **Intake Specification**: [`LCM_AI/docs/GEMINI_INBOX_SPECIFICATION.md`](file:///LCM_AI/docs/GEMINI_INBOX_SPECIFICATION.md) defining markdown and JSON templates with mandatory headers.
2. **Core Intake Tool**: [`.lcm/tools/internal/Sync-GeminiInbox.ps1`](file:///.lcm/tools/internal/Sync-GeminiInbox.ps1) implementing parsing, proposal registration via `ProposalManager.psm1`, archive relocation, and structured logging.
3. **Command Trampoline**: [`.lcm/Cmd/SyncGeminiInbox.cmd`](file:///.lcm/Cmd/SyncGeminiInbox.cmd) for short-name CLI dispatch (`SyncGeminiInbox`).
4. **Tool Catalog Synchronization**: Catalog entry in `.lcm/config/tool_catalog.json` (142 tools synchronized).
5. **GDrive Mirror Synchronization**: Automatic mirroring of specifications and tools to `D:\GDrive\LCM\` via `Export-LCMRules.ps1` and `Export-LcmKnowledgeBase.ps1`.

---

## 4. Verification & Quality Gates

* **Unit / Round-Trip Test**: Simulated BUG drop into `D:\GDrive\LCM\INBOX/` verified end-to-end ingestion, proposal plan creation, and archive movement.
* **Health & Rule Compliance**: Validated under `RULE-PS-001` through `RULE-PS-014`, `RULE-LCM-001`, and `RULE-REV-001`.


