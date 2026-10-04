<#
.SYNOPSIS
  Pass-through alias for Show-Tools.ps1.
.DESCRIPTION
  Converged into Show-Tools.ps1 per LCM tool unification directive.
  Delegates all invocation parameters directly to Show-Tools.ps1.
  Path: tools/Show-ToolIndex.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 3.3.0
  Date: 2026-09-05
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Pre-filter by audience category: 'User', 'Dev', or 'All' (default: User)")]
    [ValidateSet('User', 'Developer', 'Dev', 'All')]
    [string]$Audience = 'User',

    [Parameter(Mandatory = $false, HelpMessage = 'Pre-filter by group or repository name (default: All)')]
    [string]$Group = 'All',

    [Parameter(Mandatory = $false, HelpMessage = 'Direct pre-filter for specific subsystem (default: All)')]
    [string]$Subsystem = 'All',

    [Parameter(Mandatory = $false, HelpMessage = 'Quick switch to filter directly to Home Assistant HaSSD06 tools')]
    [Alias('Ha', 'HomeAssistant')]
    [switch]$HaSSD06,

    [Parameter(Mandatory = $false, HelpMessage = 'Pre-filter by functional role (default: All)')]
    [string]$Role = 'All',

    [Parameter(Mandatory = $false, HelpMessage = 'Pre-select a specific tool name to highlight on startup (default: All)')]
    [string]$Tool = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Pre-filter by tool environment: 'PS1', 'CMD', 'PY', 'REG', 'LNK', 'All'")]
    [string]$Env = 'All',

    [Parameter(Mandatory = $false, HelpMessage = 'Initial search keyword or !term query to apply on dashboard startup')]
    [string]$Filter = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Outputs tool catalog directly as formatted text in terminal without launching browser')]
    [Alias('Cli', 'Text', 'Console')]
    [switch]$NoBrowser,

    [Parameter(Mandatory = $false, HelpMessage = 'Generates HTML dashboard without launching browser window')]
    [switch]$NoLaunch,

    [Parameter(Mandatory = $false, HelpMessage = 'Display all tools without audience filtering')]
    [switch]$All,

    [Parameter(Mandatory = $false, HelpMessage = 'Filter to User-facing operational tools')]
    [switch]$User,

    [Parameter(Mandatory = $false, HelpMessage = 'Filter to Developer / maintenance tools')]
    [Alias('Developer')]
    [switch]$Dev,

    [Parameter(Mandatory = $false, HelpMessage = 'Custom log file destination path')]
    [string]$LogFile = "",

    [Alias('h', '?')]
    [switch]$Help
)

$targetScript = Join-Path $PSScriptRoot 'Show-Tools.ps1'
& pwsh -File $targetScript @PSBoundParameters
