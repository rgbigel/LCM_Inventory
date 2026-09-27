---
name: macro-definitions
description: Authoritative governance rule mirror for macro-definitions
globs: "*"
---
<!-- ===================================================================== -->
<!-- ANTIGRAVITY RULE MIRROR                                               -->
<!-- Source Authority: Workspace_Inventory/.agents/rules/macro-definitions.md -->
<!-- Activation: Workspace Automatic                                       -->
<!-- ===================================================================== -->
# macro-definitions.md
# version: 5.1.0
# date: 2026-09-27

# MACRO-DEFINITIONS-METADATA
# scope: durable-memory
# location: .agents/rules/macro-definitions.md
# update-policy: manual

## Syntax Convention: Antigravity IDE Bare-Word Standard
In the Antigravity IDE environment, typing the `@` character triggers the IDE's interactive context-attachment popup (`@Files`, `@Docs`, `@Git`). Therefore, bare-word command invocations (`ToolExplorer`, `ShowTools`, `tools`, `ar`, `bcr`, `ACCEPT`, `DO <#>`, etc.) are the primary and preferred syntax. The `@` prefix remains supported as a backward-compatible alias.

MACRO: technical
- description: enforce strict technical, ascii-only, deterministic output
- syntax: technical | @technical
- rules:
  - no prose
  - no decoration
  - no emojis
  - no unicode
  - explicit structures only

MACRO: user
- description: normal user-facing mode
- syntax: user | @user
- rules:
  - allow brief explanations
  - allow minimal formatting
  - keep responses concise

MACRO: S
- description: system-aligned mode
- syntax: S | @S
- rules:
  - follow workspace rules
  - follow copilot profile
  - respect durable-memory files

MACRO: profile status
- description: report current copilot profile state
- syntax: profile status | @profile status
- rules:
  - summarize durable-memory presence
  - summarize test-suite presence
  - summarize version alignment

MACRO: ToolExplorer
- description: generate and launch the authoritative LCM Tool Explorer interactive HTML application via Show-ToolsExplorer.ps1
- syntax: ToolExplorer [switches] | tools [switches] | ShowTools [switches]
- aliases: tools, ToolsExplorer, ShowTools
- primary target: .lcm/tools/internal/Show-ToolsExplorer.ps1 (trampolines: .lcm/Cmd/ToolExplorer.cmd, ToolsExplorer.cmd)
- parameters:
  - -Audience <User|Dev|All>: pre-filter audience category (defaults to 'User')
  - -Group <Name>: pre-filter by group or subsystem (e.g. 'HaSSD06', 'LCM', 'SystemConfiguration')
  - -Subsystem <Name>: direct filter for specific subsystem (e.g. 'HaSSD06', 'Workspace_Inventory')
  - -HaSSD06 (or -Ha): quick switch to filter directly to Home Assistant HaSSD06 tools
  - -Role <RoleName>: pre-filter by functional role (e.g. 'QualityGate', 'ReviewGate', 'Elevation', 'DesktopGUI')
  - -Tool <ToolName>: pre-select and highlight specific tool
  - -Env <PS1|CMD|PY|REG|LNK|All>: pre-filter by tool execution environment
  - -Filter <query>: initial text search keyword on startup (supports '!term' negation)
  - -NoBrowser (or -Cli, -Text): suppress browser and output catalog to terminal
  - -NoLaunch: generate HTML dashboard and cache without browser launch
  - -h (or -Help): display comprehensive parameter reference
- examples:
  - 'ToolExplorer' or 'tools' -> launches Tool Explorer filtered to Audience=User
  - 'ToolExplorer -Audience Dev' -> launches Tool Explorer filtered to internal developer tools
  - 'ToolExplorer -HaSSD06' -> launches Tool Explorer filtered to HaSSD06 subsystem
  - 'ToolExplorer -NoBrowser' -> renders tool catalog directly in console

MACRO: set-tool-audience
- description: configure whether a tool is User-exposed or Developer-only
- syntax: set-tool-audience | @set-tool-audience
- note: Tool audience, role, and metadata are maintained interactively directly within the ToolExplorer application (or via Update-ToolCatalog.ps1)

MACRO: log
- description: locate and open latest LCM log file and reveal full log history in File Explorer
- syntax: log [ToolName] | logs [ToolName]
- aliases: log, logs, lastlog
- rules:
  - 'log' or 'logs' -> executes 'pwsh -File tools/Show-LastLog.ps1'
  - 'log <ToolName>' -> executes 'pwsh -File tools/Show-LastLog.ps1 -ToolName <ToolName>'

MACRO: BCR
- description: launch Beyond Compare 5 visual review display for a repository against baseline commit
- syntax: bcr <repo> [commit] | BCR <repo> [commit]
- aliases: bcr, BCR, @bcr
- rules:
  - 'bcr <repo>' or 'BCR <repo>' -> executes 'pwsh -File Workspace_Inventory/tools/Invoke-BeyondCompareReview.ps1 -RepositoryName <repo>'
  - 'bcr <repo> <commit>' -> executes 'pwsh -File Workspace_Inventory/tools/Invoke-BeyondCompareReview.ps1 -RepositoryName <repo> -BaseCommit <commit>'

MACRO: ACCEPT
- description: submit review result as Accepted, close Beyond Compare review window, run quality gates, and commit
- syntax: accept [repo] | ACCEPT [repo]
- aliases: accept, ACCEPT, accepted
- rules:
  - 'accept <repo>' or 'ACCEPT <repo>' -> executes 'pwsh -File Workspace_Inventory/tools/Submit-ReviewResult.ps1 -RepositoryPath <repo> -Result Accepted'
  - automatically closes matching Beyond Compare review window

MACRO: tsr (Legacy / Automated)
- note: Superseded by persistent TimestampHeaderRule codified in InvariantRules.md. Automated on every turn; manual macro invocation is deprecated.

MACRO: ar
- description: generate retrospective execution trace and error triage diagnostics report analogous to BC5-Resolution-Analysis.md
- syntax: ar [offset] | AnalyzeReasoning [offset]
- aliases: ar, AR, AnalyzeReasoning
- rules:
  - 'ar', 'AR', or 'AnalyzeReasoning' -> executes 'pwsh -File Workspace_Inventory/tools/Invoke-ReasoningAnalysis.ps1 -Offset 0' (or .lcm/Cmd/ar.cmd)
  - 'ar <offset>' or 'AnalyzeReasoning <offset>' -> executes 'pwsh -File Workspace_Inventory/tools/Invoke-ReasoningAnalysis.ps1 -Offset <offset>'
  - generates a structured report in Workspace_Inventory/data/logs/ containing Execution Trace, Error Triage & Avoidance Matrix, and Decision Rationale
