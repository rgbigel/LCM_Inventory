# Implementation Plan: BUG-338 - Repository Agents Folders Not Junctioned

Module: docs/Proposals/BUG-338-Repository-Agents-Folders-Not-Junctioned/Implementation_Plan.md  
Purpose: Steps taken to replace the real `.agents` folders by junctions to `LCM_AI\.agents` (DOIT, executed 2026-11-16).  
Path: LCM_Inventory/docs/Proposals/BUG-338-Repository-Agents-Folders-Not-Junctioned/Implementation_Plan.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.7.4
Status: Executed  
Date: 2026-11-16 17:16:26

---

| Step | Content | Serves (Specification section 1) |
|:---|:---|:---|
| 1. Inventory | List `.agents` of every repository directly under `D:\Git_Repositories` (except `LCM_AI`): link type, target, items. | Target State |
| 2. Guarded conversion | Per real folder: proceed only if it holds nothing but the `rules` junction (LCM_Inventory: plus the stale `ACTIVE_SESSION.md`); remove junction links with `[IO.Directory]::Delete(path, false)` (link only); delete the stale file; create junction `.agents` -> `D:\Git_Repositories\LCM_AI\.agents`. Existing junctions with another target are repointed. | Target State |
| 3. Git | LCM_Inventory `.gitignore`: `.agents/rules/` -> `.agents/`; `git rm --cached .agents/ACTIVE_SESSION.md` (git reads through the junction). | Exit criterion 3 |
| 4. Verify | Link type and target per repository; `.agents\rules\RuleAuthority.md` resolves; git status of all repositories. | Exit criteria 1-3 |

Rollback: daily Macrium baseline (restore folders), then Git for the tracked file.