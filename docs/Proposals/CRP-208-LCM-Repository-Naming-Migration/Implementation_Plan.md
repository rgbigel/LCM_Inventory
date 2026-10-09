# CRP-208 Implementation Plan

## Preconditions

1. Record every affected repository's `HEAD`, branch, status, remotes, and
   current physical path in a timestamped, read-only preflight manifest.
2. Stop or close active BCompare sessions that reference the four source paths.
3. Refuse execution if any affected repository has unreviewed or unstaged work
   unless the manifest explicitly records the operator-approved exception.

## Phase 1: Migration Tooling

1. Add an external-rooted migration runner that relaunches from `%TEMP%` before
   moving the root tool hub that initially contains the runner.
2. Derive the 15-repository LCM cohort from `LCM_Inventory/config.json` plus `LCM_AI` and
   `LCM_Inventory` identities during cutover.
3. Generate a mapping manifest for directory names, absolute paths, relative
   paths, junction targets, launchers, generated artifacts, and text files.
4. Provide `-WhatIf`, `-ValidateOnly`, and `-Rollback` modes. `-WhatIf` must
   make no filesystem or Git changes.

## Phase 2: Content Preparation

1. Rewrite live textual references using the mapping manifest across the root
   container and every governed repository.
2. Update each `LCM_Inventory/config.json`, command launcher, PowerShell module/script,
   documentation path, Control Hub asset, VS Code workspace path, and root tool
   hub path affected by the five identities.
3. Keep Git metadata and immutable audit evidence untouched.

## Phase 3: Directory Cutover

1. Move `LCM_Shared` to `LCM_Shared`, the three `Workspace_*` repositories to
   their `LCM_*` targets, and the root `tools` hub to `LCM_Tools` as one ordered
   operation.
2. Recreate the root `.agents` junction to target `LCM_AI\.agents`.
3. Ensure no retired-name compatibility junctions, folders, or operational
   launchers remain.

## Phase 4: Verification and Recovery

1. Run Git-root, remote, branch, and status checks for all 15 repositories.
2. Parse every changed PowerShell script/module and execute focused launcher and
   configuration-resolution checks.
3. Run the final live-reference audit and record excluded immutable evidence.
4. On any failed critical verification, run the generated rollback in reverse
   order and report the exact unrecovered item.

## Review Boundary

The migration tool and every changed repository require automated validation,
then Beyond Compare review by repository before any local commits are created.