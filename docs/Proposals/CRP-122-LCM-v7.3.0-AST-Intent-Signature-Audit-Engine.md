# CRP-122: AST-Powered CRP Intent Signature and Semantic Integrity Engine

```yaml
id: CRP-122
title: AST-Powered CRP Intent Signature and Semantic Integrity Engine
scope: LCM / Audit & Governance
status: suggested
progress_state: open
priority: Medium
authors: Rolf, LCM_AI Engine
created_at: 2026-09-08T15:45:00+02:00
target_scope: LCM Core Governance & Multi-Repo Tooling
affected_version_range: 10.0.0+
impacted_repositories:
  - LCM_Inventory
  - Git_Repositories
  - LCM_AI
```

---

## 1. Executive Summary

During system crash recovery, emergency restorations, rollbacks, and rapid hotfixes, Git commit histories and file hashes become decoupled from functional reality. A file may appear "clean" or "dirty" in Git while its underlying implementation has suffered an accidental rollback or silent overwriting of prior Change Request Proposals (CRPs).

**CRP-122** establishes a formal, automated **AST-Powered Intent Signature Audit Engine** (`Test-LcmIntentSignatures.ps1` and associated module `LcmIntentAudit.psm1`). Instead of brittle text matching or Git diff scanning, this engine performs semantic AST inspection (`[System.Management.Automation.Language.Parser]`) to probe the living codebase for explicit "intent markers" (function signatures, AST parameter blocks, class definitions, and critical logic patterns) defined across proposals, classifying each into:
1. **Fully Integrated**: Target AST symbols and logic are active and intact.
2. **Partially Overwritten / Regressed**: Target AST symbols were wiped out or broken during subsequent edits or rollbacks.
3. **Never Reached**: Target AST symbols were never introduced into the file.

---

## 2. Architecture & Design Principles

### 2.1 AST Traversal vs Brittle Regex
PowerShell script analysis is performed strictly through the official PowerShell Abstract Syntax Tree (AST):
- **`FunctionDefinitionAst`**: Verifies existence and signatures of declared functions and cmdlets.
- **`ParamBlockAst`**: Verifies declared parameter switches, types, and attributes.
- **`TypeDefinitionAst`**: Verifies strongly typed PowerShell classes and enums.
- **`CommandAst`**: Verifies invocations of critical external boundaries (e.g. Session 1 daemon bridge, Beyond Compare 5 launcher).

This completely eliminates false positives caused by commented-out code, multiline formatting differences, and string literals.

### 2.2 Intent Signature Registry
Each CRP specification may optionally define a structured `intent_signatures` YAML block or be probed via a standardized registry:
```yaml
intent_signatures:
  target_file: LCM_Inventory/tools/Invoke-PrivilegedTool.ps1
  required_functions:
    - Invoke-PrivilegedTool
  required_parameters:
    - ToolName
    - Session1Bridge
  required_ast_calls:
    - LcmDesktopDaemon
```

### 2.3 Synergy with CRP-121 (AST Tool Dependency Engine)
CRP-122 directly shares and extends the AST parser infrastructure established in CRP-121 (`WIUD` forward dependencies and `WUD` reverse callers). The same AST compilation pass that extracts dependencies also extracts export signatures and param blocks, ensuring zero duplicate parsing overhead.

---

## 3. Governance Integration & Review Invariants

1. **Non-Waivable Review Gate**: In accordance with [`RULE-REV-001`](file:///d:/Git_Repositories/.agents/rules/ReviewCommitGovernancePolicy.md), an automated finding of `Fully Integrated` **does not waive** visual Beyond Compare 5 diff reviews. It qualifies the component for review and confirms that no regressions occurred during crash recovery.
2. **Crash Recovery Reconciliation**: Enables rapid, authoritative audit of the Configuration Management ledger ([`proposals.json`](file:///d:/Git_Repositories/LCM_Inventory/data/proposals/proposals.json)) against ground truth, flagging accidental rollbacks before commits or pushes occur.

---

## 4. Implementation Specification

### 4.1 Deliverables
- `LCM_Inventory/tools/Test-LcmIntentSignatures.ps1`: CLI tool to probe target repositories or specific CRP IDs.
- `LCM_Inventory/modules/LcmIntentAudit.psm1`: Core AST signature extraction and comparison module.
- `LCM_Inventory/data/proposals/intent_signatures.json`: Cached and verified signature registry.

### 4.2 Verification & Test Gates
- Unit test suite `tests/LcmIntentAudit.Tests.ps1` verifying detection of stubbed vs complete functions.
- Integration pass over `LCM_Inventory/` verifying signatures for CRP-107 through CRP-120.
