# CRP-191: Workspace Repository Index, Enrollment Filter, and ShowRepos Command

```yaml
CRP-ID: CRP-191
Scope: LCM_Inventory repository discovery, metadata, and change visibility
Status: Completed
Plan-State: completed
Progress-State: completed
Maturity: Preliminary design record
Owner: LCM_Inventory
```

## Problem

The workspace is intentionally split into repositories with distinct ownership, but repository boundaries currently fragment change visibility. Existing inventory output discovers Git and non-Git directories, yet it does not provide a durable enrollment distinction, a user-editable metadata layer, or a workspace-wide repository management command.

## Current Rebaseline

The goal remains unchanged. Review must confirm that a future index respects
strict repository ownership while still presenting a workspace-wide view, and
that its metadata operations remain read-only with respect to physical
repositories.

## Core Invariant

Every discoverable directory under the workspace root must be visible in the workspace repository index. Repository ownership controls responsibility and commit boundaries; it must not hide a workspace resource from the inventory.

## Enrollment States

| State | Detection | Meaning |
| :--- | :--- | :--- |
| `Governed` | Directory has a `.git` entry | The directory is independently versioned and participates in repository-level change tracking. |
| `NotOnboarded` | Discoverable directory has no `.git` entry | The directory is a workspace resource but has not entered repository governance. |
| `Excluded` | Explicit user metadata rule | The directory remains visible, with its exclusion reason, but is omitted from default operational action lists. |
| `Missing` | Indexed path no longer exists | Retained as a visible stale record pending user removal. |

### Initial Delivery Scope: Governed Repositories Only

The initial delivery indexes only directories with a `.git` entry. Every initial row therefore has `EnrollmentState: Governed`. The default view is `All`, with an available `Governed` filter that remains explicit for future parity.

<!-- FUTURE OPTION 1 - DISCOVER ALL WORKSPACE DIRECTORIES
Expand discovery to every eligible directory below the workspace root and activate the NotOnboarded, Excluded, and Missing filters. This extension must preserve the same index schema and metadata overlay; it must not change the governed-repository behavior delivered first.
-->

## Index Ownership and Data Model

`LCM_Inventory` owns two separate files:

1. `data/repositories/repository_index.json`: generated scanner facts. Fields include canonical workspace-relative path, `EnrollmentState`, Git branch, head SHA, dirty and ahead/behind state, detected version, scan time, and junction canonical target.
2. `data/repositories/repository_metadata.json`: user-owned overlay. Fields include `display_name`, `owner`, `tags`, `visibility`, `lifecycle`, `notes`, `pinned`, and `exclusion_reason`.

Generated facts are never manually editable. The overlay is merged at read time, preserving user edits across inventory refreshes. Physical paths, Git state, and detected version remain scanner-owned facts.

## ShowRepos Contract

`ShowRepos` is a `LCM_Inventory` command patterned after existing `Show-*` tools. It displays a console matrix and optional HTML table containing version, enrollment state, Git state, dirty-file count, ahead/behind state, owner, tags, lifecycle, visibility, and notes.

Proposed interface:

```text
ShowRepos [-Enrollment <All|Governed|NotOnboarded|Excluded|Missing>]
		  [-Repository <name-or-path>] [-Tag <tag>] [-State <state>]
		  [-Html] [-NoLaunch]
		  [-SetAttribute <repo> <name> <value>]
		  [-RenameDisplayName <repo> <display-name>]
		  [-RemoveAttribute <repo> <name>]
		  [-DeleteMetadata <repo> -Confirm]
```

`RenameDisplayName`, `RemoveAttribute`, and `DeleteMetadata` modify only `repository_metadata.json`. They must never rename, delete, move, initialize, clone, commit, or push a physical repository.

## Acceptance Criteria

- Every governed repository has exactly one canonical index row.
- The all-repositories view cannot hide a governed repository because it is nested, untracked, or ignored by a parent repository.
- The enrollment filter displays `Governed` without changing any directory.
- `ShowRepos` exposes computed version/state and safely manages only user metadata.
- The workspace change view can group by repository while retaining a default all-changes feed.
