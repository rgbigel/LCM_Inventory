# Walkthrough: CRP-323

## Orthogonal Tool Taxonomy: SubSystem Unification, Role Absorption into Category, and Explorer Filter Presets

### Overview of Changes for the Operator

#### 1. Unified SubSystem Column (Replacing Group)
Previously, the concept of a subsystem was fragmented: `SystemConfiguration` (the PC) was treated partly as a category and partly as a group, `HaSSD06` was handled as a special category, and `Group` only listed arbitrary folder names.
- Now, **`SubSystem`** is the single authoritative dimension for target boundaries:
  - **`PC`**: Windows host, hardware controls, power/sleep, display, desktop setup.
  - **`LCM`**, **`LCM_Inventory`**, **`LCM_AI`**, **`LCM_Tools`**: Core and operational LCM components.
  - **`HaSSD06`**: Home Assistant OS subsystem.
  - **`Sandboxes`**: Isolated worktrees and testbed repositories.

#### 2. Elimination of the Redundant Role Column
The separate `Role` column had become superfluous. Its functional values (`QualityGate`, `Elevation`, `Recovery`, `Diagnostics`, `Gateway`, `Management`) are absorbed directly into the **`Category`** dimension.
- Tool Explorer table width is freed up, removing visual clutter.
- Descriptions and tool titles gain more breathing room.

#### 3. Nine Meaningful, Functional Categories
Instead of 40 fragmented categories plus vague labels like "Utility", every tool belongs to one of 9 clear functional categories:
1. `File System & Search`
2. `Backup & Recovery`
3. `Governance & Proposals`
4. `Review & Quality Gates`
5. `Elevation & Access`
6. `Diagnostics & Telemetry`
7. `Configuration & Customization`
8. `Environment & Runtimes`
9. `Execution Gateway`

#### 4. Focused Default View & Filter Presets
When opening **Tool Explorer** (`ToolExplorer` or `tools`), the default view presents only `Audience: User`:
- Clean list of the ~30 primary daily tools (`run`, `bcr`, `ShowRules`, `MountMacriumBaseline`, `RenameProposal`).
- One-click presets at the top let you switch instantly:
  - **`User` (Default)**: Daily operations (`Audience: User`).
  - **`Developer`**: Engineering view across all subsystems (`User` + `Maintenance`), defaulting to **`NoInternals`**. Internal daemons and runtime atoms can be toggled on/off in the orthogonal Audience column filter.
  - **`Maintenance`**: Invariant enforcers, parameter checkers, and system repairs (`Audience: Maintenance`).
  - **`All`**: Complete, unfiltered catalog.
