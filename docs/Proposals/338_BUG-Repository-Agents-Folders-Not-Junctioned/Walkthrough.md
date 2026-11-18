# Walkthrough: BUG-338 - Repository Agents Folders Not Junctioned

## 1. Executive Summary
Implementation and verification records for BUG-338.

## 2. Verification Evidence
- Pending implementation execution.

## Claude Verification (2026-11-16 16:29:36)

- Converted 20 real `.agents` folders (each held only the `rules` junction; LCM_Inventory also the stale `ACTIVE_SESSION.md`) to junctions `-> D:\Git_Repositories\LCM_AI\.agents`; OneDriveMaintenance repointed from the root junction. Junction links removed with `[IO.Directory]::Delete(path, false)` (link only, target untouched).
- Check: all 21 report `LinkType Junction`, target `D:\Git_Repositories\LCM_AI\.agents`, and `.agents\rules\RuleAuthority.md` resolves; 21 canonical rule files present.
- Git: git follows the junction, so the tracked `LCM_Inventory/.agents/ACTIVE_SESSION.md` appeared modified with the live content; removed from the index with `git rm --cached` (staged deletion, no commit). LCM_Inventory `.gitignore`: `.agents/rules/` -> `.agents/`. Other repositories: no git change (`.agents/` already ignored).
- Not checked under this BUG: scaffold templates that create `.agents` for new repositories.
