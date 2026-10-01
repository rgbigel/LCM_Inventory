# CRP-208: LCM Repository Naming Migration

```yaml
CRP-ID: CRP-208
Priority: 10
Scope: Workspace-wide governed repository naming cutover
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Affected-Repos:
  - Git_Repositories
  - AuthorizeMasterUser
  - BackgroundModifier
  - BGMSAMVInv
  - BootEntryManager
  - HaSSD06
  - HaSSD06_Inventory
  - Installation_LCD
  - One2Md
  - PowerBGInfo
  - LCM_Shared
  - SystemConfiguration
  - VolumeInventory
  - LCM_AI
  - LCM_Inventory
  - LCM_Supervision
```

## Objective

Replace the live operational repository identities `Workspace_AI`,
`Workspace_Inventory`, and `Workspace_Supervision` with `LCM_AI`,
`LCM_Inventory`, and `LCM_Supervision`. Rename `SharedModules` to `LCM_Shared`,
and rename the root tool hub `tools` to `LCM_Tools`. Update all live references
in every LCM-governed repository and the root container in the same migration.

## Naming Contract

| Current name | Target name |
| --- | --- |
| `Workspace_AI` | `LCM_AI` |
| `Workspace_Inventory` | `LCM_Inventory` |
| `Workspace_Supervision` | `LCM_Supervision` |
| `SharedModules` | `LCM_Shared` |
| `tools` (root tool hub only) | `LCM_Tools` |

## Requirements

1. The migration must discover its repository cohort from local `.lcm/config.json`
   metadata and include the two central LCM repositories even though they do not
   currently have local configuration files.
2. All live operational source, scripts, launchers, configuration, assets,
   documentation, VS Code metadata, and root governance links must resolve only
   to the target names after cutover.
3. The root `.agents` junction must target `LCM_AI\.agents` after the directory
   move. The root tool hub must be `LCM_Tools`; repository-local `tools`
   directories retain their existing names. During the transition, root legacy
   names remain as junction aliases described by
   `.lcm/config/LegacyRepositoryNames.json`; their retirement is explicitly TBD.
4. The implementation must produce a preflight report, a deterministic mapping
   manifest, and a rollback command before it changes directories or content.
5. The migration must preserve Git object history, remote configuration, and
   immutable review/audit evidence. Historical Git objects and receipt content
   are not rewritten.
6. A repository fails the cutover if its post-migration Git root, LCM config,
   PowerShell parsing, or required launcher resolution fails.
7. A final reference audit must report zero references to the retired names in
   live governed source and configuration, excluding `.git`, immutable receipts,
   and archived Git-object evidence.

## Non-Goals

- Renaming `D:\Git_Repositories` itself.
- Rewriting Git history or remote repository names.
- Changing the functional behavior of governed applications beyond their path
  and identity references.