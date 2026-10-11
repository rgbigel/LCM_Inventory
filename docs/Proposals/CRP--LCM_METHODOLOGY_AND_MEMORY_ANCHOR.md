# \[URGENT & COMPREHENSIVE\] LCM Master Recovery Plan & Regression Cleanup

## 1\. Executive Summary & Objective

This document serves as the authoritative, comprehensive remediation specification for the IDE to systematically clean up recent regressions, restore critical safeguards, and establish balanced governance rules across the LCM (Lifecycle Management) framework.

The primary goals are:

- Revert paranoid, blocking IDE regressions in `Submit-ReviewResult.ps1` and macro definitions while preserving genuine configuration management (CM) flow simplifications.  
- Soften dogmatic DOX (Docs-over-Code) rules to ensure review workflows are never deadlocked by pure documentation states.  
- Re-introduce mandatory interactive safeguards and robust object-based status mapping.

---

## 2\. Core Remediation Items

### Task A: Status Mapping & Separation of Major State and Reason

* **Problem:** Previous refactoring risked status-information loss by collapsing sub-states (`blocked`, `failed`, `deferred`) into generic strings.  
* **Requirement:** Distinctly separate the Major State name from the State's change reason. Use the external Major State name as an internal name (mapping blanks to `_`). Visibly show the reason using an object-based pattern to preserve sub-states.  
* **Implementation Guideline:** Update status conversion logic within `LCM_Inventory` modules to return an explicit PSCustomObject containing both `State` and `Reason` according to the lifecycle mapping matrix, ensuring legacy values throw only when truly undefined.

### Task B: Soften DOX Philosophy for CRP Reviews

* **Problem:** Strict DOX philosophy places documentation at the top of the food chain, blocking CRP reviews when a CRP consists solely of docs and a required code change is identified.  
* **Rule Update:** A required code change is considered a required implementation, and documentation must be updated to match. A pure docs state cannot totally impede or block a necessary code change during a CRP review workflow.

### Task C: Cleanup Regressions in `Submit-ReviewResult.ps1`

* **Problem:** The IDE introduced overly rigid guard checks, brittle hard-throw validations, and stripped the interactive uncopied files prompt.  
* **Required Actions:**  
  1. **Restore Ledger Reading:** Ensure `Invoke-workspacePush.ps1` and review scripts correctly read the proposal ledger:  
       
     \$ledgerJson \= Get-Content \-LiteralPath \$proposalsFile \-Raw \-Encoding UTF8 | ConvertFrom-Json  
       
  2. **Remove Brittle Hard-Throws:** Remove overly restrictive checks like `if (-not $stagedManifest.PSObject.Properties['CRP'] -or $stagedManifest.CRP -ne $CRP) { throw "..." }` and rigid proposal state guards forcing strict `state -ne 'in_review'`.  
  3. **Restore Interactive Safeguards:** Re-introduce the interactive operator prompt for uncopied files during review completion rather than failing silently or throwing hard exceptions.

### Task D: Refine Macro Definitions & CRP-261 Transition Compatibility Rule

* **Goal:** Retain streamlined configuration management (CM) flow improvements while restoring repository-level autonomy (`bcr <repo>` / `complete <repo>`) alongside explicit CRP intent. Prevent IDEs from enforcing rigid CRP-ID-only invocation blocks that break repository-level workflows.  
* **CRP-261 Transition Compatibility Rule:** `state` is the sole lifecycle authority (`suggested`, `in_progress`, `verified`, `in_review`, `completed`, `held`, `pushed`, `withdrawn`, `rejected`, `superseded`). Legacy terms (`Scoped`, `Decided`, `Approved`, `Committed`, `Published`, `processed`, `deferred`) are compatibility vocabulary only and must not create a second lifecycle authority.

| Authoritative `state` | Valid actions | Valid next states |
| :---- | :---- | :---- |
| `suggested` | `edit`, `do`, `hold`, `withdraw`, `supersede` | `in_progress`, `held`, `withdrawn`, `superseded` |
| `in_progress` | `edit`, `verify`, `hold`, `reset`, `withdraw`, `supersede` | `verified`, `held`, `suggested`, `withdrawn`, `superseded` |
| `verified` | `bcr`, `reopen`, `hold`, `supersede` | `in_review`, `in_progress`, `held`, `superseded` |
| `in_review` | `complete`, `commit`, `reject`, `reopen`, `hold` | `completed`, `rejected`, `in_progress`, `held` |
| `completed` | `push`, `hold` | `pushed`, `held` |
| `held` | `continue`, `edit`, `withdraw` | the recorded `resume_state`, `withdrawn` |
| `pushed`, `withdrawn`, `rejected`, `superseded` | view-only actions defined by the lifecycle model | terminal except documented supersession |

---

## 3\. Governance Rule for IDEs

* **Mandatory Protocol:** Automated tools and IDEs must never strip critical safety logic, remove interactive prompts, or introduce blind `throw` roadblocks without performing a formal, documented **ANALYSIS** step first and obtaining operator sign-off.