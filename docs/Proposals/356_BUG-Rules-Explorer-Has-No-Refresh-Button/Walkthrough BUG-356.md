# Walkthrough: BUG-356 - Rules Explorer Has No Refresh Button

Date: 2026-11-18 21:38:57

## 1. Path taken
- Operator's badge finding merged into this BUG (same display frame, rule B22) instead of a new BUG.
- Badge: placed into `header.topbar` (Control Hub) or the first `header` (Tool Explorer, Rules, Dates); fallback fixed top right.
- Refresh button calls the existing `refreshRules()`.

## 2. Verification evidence (2026-11-18 21:32:48)

| Check                                         | Result                                              |
|:----------------------------------------------|:----------------------------------------------------|
| `node --check lcm-display-freshness.js`       | OK                                                  |
| Parse gate `Show-Rules.ps1`                   | 0 errors                                            |
| `LcmDisplayFreshness.Tests.ps1`               | 17/17                                               |
| Re-render `tools`, `rules` via the daemon     | Current; served page and script carry the change    |
| Headless Edge screenshot, Tool Explorer       | badge in header top right; bottom bar uncovered     |
| Headless Edge screenshot, Rules Explorer      | badge in header; "Refresh" first toolbar button     |

## 3. Gate 2 finding: badge acted as a clock (2026-11-18 21:38:57)

- Cause: the daemon's `/displays/status` reported `publishedAt` as the time of the query (`time.Now()`), while the revision came from the display file time; the page polls every 2.5 s.
- Fix: `publishedAt` = display file time (`src/do/daemon.go` 10.2.5 -> 10.2.6); daemon redeployed, rollback copy `scratch/do-before-bug356.exe`.

| Check                                      | Result                                              |
|:-------------------------------------------|:----------------------------------------------------|
| `go vet`, `go test`                        | clean, ok                                           |
| Before: 3 polls 4 s apart                  | publishedAt 21:37:17, 21:37:21, 21:37:25 (same rev) |
| After: 3 polls 3 s apart                   | publishedAt 21:31:55 each = display file time       |