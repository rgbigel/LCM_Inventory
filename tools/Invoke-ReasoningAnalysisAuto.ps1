<#
.SYNOPSIS
  Host-neutral dispatcher for reasoning analysis with automatic active-host session export.
.DESCRIPTION
  Selects exactly one active IDE host provider:
    - Copilot only when COPILOT_AGENT_SESSION_ID is present.
    - Antigravity only when ANTIGRAVITY_CONVERSATION_ID (or ANTIGRAVITY_AGENT = '1') is present.
  Fails explicitly when no supported active host session is detected.
  Never probes or invokes an inactive host.
  Retains -TranscriptPath as the offline fallback.
  Cleans up temporary export files in a finally block.
#>
[CmdletBinding()]
param(
  [switch]$Auto,
  [string]$TranscriptPath,
  [Alias('Find')]
  [string]$From,
  [string]$Until,
  [switch]$ListMatches,
  [int]$Offset,
  [int]$Context,
  [string[]]$Include,
  [string]$OutputPath,
  [switch]$View,
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gitRoot = if (-not [string]::IsNullOrWhiteSpace($env:LCM_WORKSPACE_ROOT)) {
  $env:LCM_WORKSPACE_ROOT.TrimEnd('\', '/')
} elseif ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\LCM_Inventory'))) {
  (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} elseif (-not [string]::IsNullOrWhiteSpace($env:Git_Root)) {
  $env:Git_Root.TrimEnd('\', '/')
} else {
  'D:\Git_Repositories'
}
$analyzer = Join-Path $gitRoot 'LCM_Inventory\tools\Invoke-ReasoningAnalysis.ps1'
if (-not (Test-Path -LiteralPath $analyzer -PathType Leaf)) {
  throw "Reasoning analyzer was not found: $analyzer"
}

$forwardedParameters = @{}
foreach ($parameterName in $PSBoundParameters.Keys) {
  if ($parameterName -ne 'Auto') {
    $forwardedParameters[$parameterName] = $PSBoundParameters[$parameterName]
  }
}

# Offline fallback: if explicit transcript path is provided, invoke analyzer directly
if (-not [string]::IsNullOrWhiteSpace($TranscriptPath)) {
  & $analyzer @forwardedParameters
  return
}

# If not -Auto and not supplied TranscriptPath and no query parameters, let the analyzer display usage / guidance
if (-not $Auto -and [string]::IsNullOrWhiteSpace($From) -and $null -eq $Offset -and -not $Help) {
  & $analyzer @forwardedParameters
  return
}

# Active host provider selection (exactly one provider, never probe inactive host)
$isCopilot = -not [string]::IsNullOrWhiteSpace($env:COPILOT_AGENT_SESSION_ID)
$isAntigravity = -not [string]::IsNullOrWhiteSpace($env:ANTIGRAVITY_CONVERSATION_ID) -or ($env:ANTIGRAVITY_AGENT -eq '1')

if ($isCopilot -and -not $isAntigravity) {
  $provider = 'Copilot'
} elseif ($isAntigravity -and -not $isCopilot) {
  $provider = 'Antigravity'
} elseif ($isCopilot -and $isAntigravity) {
  if ($env:ANTIGRAVITY_AGENT -eq '1') {
    $provider = 'Antigravity'
  } else {
    $provider = 'Copilot'
  }
} else {
  throw "No active supported IDE host detected (neither COPILOT_AGENT_SESSION_ID nor ANTIGRAVITY_CONVERSATION_ID is set). Supply -TranscriptPath <path> for offline analysis."
}

$exporterScript = Join-Path $PSScriptRoot "Export-${provider}ReasoningTranscript.ps1"
if (-not (Test-Path -LiteralPath $exporterScript -PathType Leaf)) {
  throw "Transcript provider exporter for $provider was not found: $exporterScript"
}

$tempDir = Join-Path $env:TEMP 'LCM-ReasoningAnalysis'
if (-not (Test-Path -LiteralPath $tempDir -PathType Container)) {
  New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}
$temporaryPath = Join-Path $tempDir "${provider}-$([guid]::NewGuid().ToString('N')).jsonl"

try {
  & $exporterScript -OutputPath $temporaryPath
  $forwardedParameters['TranscriptPath'] = $temporaryPath
  & $analyzer @forwardedParameters
} finally {
  if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
    Remove-Item -LiteralPath $temporaryPath -Force
  }
}
