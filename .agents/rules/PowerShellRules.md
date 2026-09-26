---
name: PowerShellRules
description: Authoritative governance rule mirror for PowerShellRules
globs: "*"
---
<!-- ===================================================================== -->
<!-- ANTIGRAVITY RULE MIRROR                                               -->
<!-- Source Authority: Workspace_AI/.agents/rules/PowerShellRules.md  -->
<!-- Activation: Workspace Automatic                                       -->
<!-- ===================================================================== -->
# File: PowerShellRules.md

Module: PowerShellRules
Purpose: Authoritative rules for PowerShell script generation and normalization.
Path: .agents/rules/PowerShellRules.md
Authors: Rolf
Version: 8.6.0
Changelog:
- 2026-09-26: Standardized on PS7 (pwsh) runtime exclusively; parity for intermediate code.
- 2026-07-27: Split unified rule file; clarified ASCII constraints; stabilized PS rules.

POWERSHELL-RULES
- ps7-exclusive: pwsh (PS7) is mandatory workspace-wide; legacy powershell.exe (5.1) is forbidden
- intermediate-parity: rules apply equally to permanent scripts and inline pwsh -Command blocks
- ascii-default: ASCII required; umlauts allowed in literal strings and comments
- utf8-without-bom: scripts must be UTF-8 without BOM
- newline-crlf: scripts must end with CRLF
- no-backticks: forbidden
- no-interpolated-calls: forbid method calls inside interpolated strings
- assign-$_-first: always assign $_ to a variable before use
- no-non-ascii-identifiers: identifiers must be ASCII-only
- no-hidden-state: forbid hidden pipeline or implicit variable usage
- deterministic-output: identical input → identical output

POWERSHELL-METADATA
- scope: durable-memory
- location: .agents/rules/PowerShellRules.md


