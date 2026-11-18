# Walkthrough: CRP-305 - Coordinated standard display freshness contract

## 1. Executive Summary
Implementation and verification records for CRP-305.

## 2. Verification Evidence
- Operator selected Option B after read-only analysis of standard displays.
- Active rule baseline equivalence verified: junction to canonical authority,
  20 Markdown filenames/hashes compared, zero mismatches.
- Confirmed ShowTools obsolete target, fixed-delay dispatch refresh in Rules
  and Workspace Inventory, and existing but display-specific Control Hub SSE.
- Specification accepted through "doIT 304, 305" at
  2026-10-21 22:03:44 +02:00; canonical lifecycle activation and acceptance
  evidence recorded before implementation.
- Operator clarified exclusive port-9876 Standard Display communication at
  2026-10-21 22:02:03 +02:00. Verified ShowTools normally launches a file URL;
  ShowCM normally uses HTTP but also contains an invalid daemon-offline file
  fallback. Specification now excludes both paths and direct local asset reads.

## 3. Implementation Evidence

- Shared discovery definitions drive catalog scanning and tool invalidation.
- Small dependency, coordinator, HTTP and launcher modules now provide
  allowlisted delivery, nonblocking child rendering, validated JSON/HTML,
  revision identities, retained valid bytes and explicit failure status.
- The shared browser client applies data without resetting filters, checks
  publication identity and reloads presentation changes with saved view state.
- Historical functional-analysis/readiness HTML launches now publish retained
  snapshots through the same daemon; opening them never reruns their producers.
- Existing daemon PID 10168 was gracefully stopped through `/stop`. Its
  replacement PID 23724 runs in interactive session 1 and responds on port 9876
  with `standardDisplays: 1`. The shared JavaScript asset returns HTTP 200,
  JavaScript content type and no-store headers. Missing retained evidence
  returns HTTP 404 with an explicit JSON error and no fallback.

## 4. Verification Progress

- Integrated analyzer/viewer/shared-publication/launcher/worker/hub Pester run: 71 passed,
  zero failed. Includes recovered-daemon readiness, encoded launch filters,
  old-daemon refusal, malformed publication rejection and retained bytes.
- Shared browser-client and launch-filter Node tests: 17 passed, zero failed. Includes initial
  presentation races, data revision races, state preservation, disconnection,
  wrong-port rejection and snapshot isolation.
- Changed PowerShell AST parsing: 23 files passed at the integration checkpoint.
- Canonical native workspace readiness command passed, exit code 0.
- Already-open ShowTools verified a newly created fixture, edited parameter,
  renamed fixture, and deletion without manual refresh or executing that
  fixture. Search `Failure` and audience `All` were preserved. The exact
  temporary source and generated launchers were removed afterward.
- A temporary shared-script comment changed the presentation revision. The
  already-open HTTP page reloaded itself and restored search/audience state;
  pending saved state was consumed. The temporary comment was removed.
- ShowTools lists both AnalyzeFailures and ShowFailureAnalysis. Its browser
  resources have only the port-9876 origin.
- ShowCM initially failed JSON parsing because presentation-meta insertion
  touched literal `<head>` inside cached document data. The generator now
  escapes `<` in the JSON envelope, and the HTTP handler inserts metadata
  into only the first head element. Both layers have regression tests.
  Live ShowCM subsequently rendered 562 rows, valid payload and Current
  status with no resource origins outside port 9876.
- Rules browser verified Current, initial filter `RULE-PS-021`, and three
  matching rows with only same-origin resources. Dates browser verified
  exact comma-separated IDs 304 and 305, two rows, and Current.
- Inventory browser uncovered adapter registration nested inside the Docs
  modal callback. Registration was moved to top-level initialization with
  an execution regression (not merely syntax parsing). Live verification
  now shows an available adapter, 28 rows, Current and only port-9876 resources.
- Canonical macro synchronization is recorded as cross-repository review
  obligations CRP-304::LCM_AI and CRP-305::LCM_AI; no rule forks were created.
- Recursive proposal and plan documents, cross-repository cached documents,
  root rule directives and the cross-reference matrix are explicit inputs.
  Native file enumeration/content hashing reduced measured Hub fingerprint
  time from 3.031 seconds to 0.301 seconds and Dates from 1.627 to 0.186,
  without replacing content hashes with timestamp assumptions.
- Final daemon PID 24716, session 1, loaded the integrated modules. All five
  live displays subsequently reached Current. A ping while views remained
  open completed in 0.024 seconds. Port-9876 recovery was verified after
  graceful shutdown; no offline file fallback was used.
- Latest combined checkpoint: 71 Pester tests and 18 Node execution tests
  (including inventory initialization and Dates launch state).
- No review disposition, implementation commit or push has been performed.
