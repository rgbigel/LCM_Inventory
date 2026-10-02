# CRP-210: Implementation Plan - Minimal Tests Switch and Single-Cycle State Modifier

```yaml
CRP-ID: CRP-210
Plan-State: suggested
Progress-State: undecided
Target-Repos:
  - LCM_Inventory
  - LCM_AI
  - LCM_Shared
```

## 1. Technical Strategy

Implement the `-MinimalTests` switch across repository readiness runners, review submission scripts, and governance policy rules. Guarantee that minimal testing auto-resets after a single implementation cycle, records mandatory audit evidence, and annotates the `state` attribute in `proposals.json`.

---

## 2. Phase Breakdown

### Phase 1: Quality Gate Runner Updates (`-MinimalTests`)
- [ ] Update `Test-RepoReadiness.ps1` in `LCM_Shared` and child repositories:
  - Add `[switch]$MinimalTests` parameter.
  - When `$MinimalTests` is set, execute `Assert-RepoStructure`, `Assert-RepoFormatting`, `Assert-RepoGovernanceLinks`, and AST syntax validation, but bypass `Invoke-ElevatedTest.ps1` and heavy integration Pester suites.
- [ ] Update `LCM_AI/tools/Test-WorkspaceReadiness.ps1`:
  - Propagate `-MinimalTests` into child repo runners.

### Phase 2: Review Submission & Lifecycle State Annotation
- [ ] Update `LCM_Inventory/tools/Submit-ReviewResult.ps1`:
  - Accept `-MinimalTests` switch.
  - When active, set `"state": "completed [minimal-tests]"` in `proposals.json` and record `"test_scope": "minimal"` in the review receipt (`REVIEW-*.json`).
  - Emit an audit log entry in `LCM_Inventory/logs/cm_activity.log`.
  - Enforce immediate auto-reset of the testing mode back to `full`.

### Phase 3: Governance Policy Codification
- [ ] Update `.agents/rules/ProposalReviewFlowPolicy.md`:
  - Codify `RULE-LCM-023` (Minimal Tests Single-Cycle Execution Switch & State Reflection Invariant).
- [ ] Update `.agents/rules/ReviewCommitGovernancePolicy.md`:
  - Codify `completed [minimal-tests]` state handling under `RULE-REV-001` and `RULE-REV-002`.
- [ ] Update root `AGENTS.md` and `LCM_AI/docs/LCM-Rules-Cross-Reference.md` per `RULE-AUTH-002`.

### Phase 4: UI & Control Hub State Reflection
- [ ] Update `LCM_Inventory/assets/CM_CONTROL_HUB.html`:
  - Add visual chip styling for `completed [minimal-tests]` state pills (amber background with `⚠️ Minimal`).
  - Add quick `-MinimalTests` checkbox in the action execution drawer.

---

## 3. Verification Strategy

1. **Syntax & Unit Test**:
   - Verify `Test-RepoReadiness.ps1 -MinimalTests` executes in < 3 seconds while catching syntax errors.
2. **Auto-Reset Verification**:
   - Verify that running a subsequent readiness test without `-MinimalTests` immediately defaults back to full suite execution.
3. **State Reflection Audit**:
   - Inspect `proposals.json` to verify `state` is recorded as `completed [minimal-tests]`.
4. **Visual Review Gating (Gate 2)**:
   - Visual inspection of policy diffs in Beyond Compare 5 prior to commit.
