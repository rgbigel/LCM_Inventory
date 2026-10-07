<#
.SYNOPSIS
  Generate native LCM_AI step and permanent governance logs.

.PARAMETER OutputPath
  Destination path for generated Workspace log.

.PARAMETER StepLogPath
  Destination path for step-oriented governance log.

.PARAMETER PermanentLogPath
  Destination path for permanent accepted-change governance log.

.PARAMETER ProposalLogPath
  Path to authoritative Proposals.json ledger.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Destination path for generated Workspace log.')]
  [string]$OutputPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Destination path for step-oriented governance log.')]
  [string]$StepLogPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Destination path for permanent accepted-change governance log.')]
  [string]$PermanentLogPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Path to authoritative Proposals.json ledger.')]
  [string]$ProposalLogPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Generate-Log.ps1 - Generate native LCM_AI step and permanent governance logs." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Generate-Log.ps1 [-OutputPath <path>] [-StepLogPath <path>] [-PermanentLogPath <path>] [-ProposalLogPath <path>] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -OutputPath       Path for Workspace.log output."
  Write-Host "  -StepLogPath      Path for Workspace.step.log output."
  Write-Host "  -PermanentLogPath Path for Workspace.accepted.log output."
  Write-Host "  -ProposalLogPath  Path to Proposals.json ledger."
  Write-Host "  -Help             (-h, -?) Displays this help message."
  exit 0
}

<#
Module: Generate-Log.ps1
Purpose: Generate native LCM_AI step and permanent governance logs.
Path: tools/Generate-Log.ps1
Authors: LCM_AI Engine
Version: 1.5.0
Caller Contract: Called from VS Code tasks or terminal; writes deterministic checkpoint and accepted-change governance logs.
Changelog:
- 2026-08-01: Added proposal disposition summary section.
- 2026-08-01: Grouped generated artifact changes separately from reviewable pending changes.
- 2026-08-01: Added generated-artifact section so logs are not treated as reviewable proposal files.
- 2026-08-01: Added normalized disposition detail output for step proposal records.
- 2026-08-01: Loaded step proposal records from Proposals.json instead of hardcoding entries.
- 2026-08-01: Added separate step-oriented and permanent accepted-change log outputs.
- 2026-08-01: Added native governance log generator for Gemini/Continue migration.
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$copilotRoot = Join-Path $workspaceRoot '.copilot'

if (-not $OutputPath) {
  $OutputPath = Join-Path $copilotRoot 'Logs\Workspace.log'
}

if (-not $StepLogPath) {
  $StepLogPath = Join-Path $copilotRoot 'Logs\Workspace.step.log'
}

if (-not $PermanentLogPath) {
  $PermanentLogPath = Join-Path $copilotRoot 'Logs\Workspace.accepted.log'
}

if (-not $ProposalLogPath) {
  $ProposalLogPath = Join-Path $copilotRoot 'History\Logs\Proposals.json'
}

$rulesPath = Join-Path $workspaceRoot '.github\agents\Workspace-Rules.md'
$agentIndexPath = Join-Path $workspaceRoot '.github\agents\WorkspaceAgentIndex.md'
$ruleAuthorityPath = Join-Path $copilotRoot 'Rules\RuleAuthority.md'

$requiredPaths = @($rulesPath, $agentIndexPath, $ruleAuthorityPath, $ProposalLogPath)
foreach ($requiredPath in $requiredPaths) {
  if (-not (Test-Path -LiteralPath $requiredPath)) {
    throw "Required governance input missing: $requiredPath"
  }
}

$latestCommit = git -C $workspaceRoot log -1 --oneline
$baselineCommit = git -C $workspaceRoot rev-list --max-parents=0 HEAD
$acceptedCommits = git -C $workspaceRoot log --reverse --format='%h %ad %s' --date=format:'%Y%m%d_%H%M%S' "$baselineCommit..HEAD"
$status = git -C $workspaceRoot status --short
$generatedAt = Get-Date -Format 'yyyyMMdd_HHmmss'
$proposalState = Get-Content -Raw -Path $ProposalLogPath | ConvertFrom-Json
$stepEntries = @($proposalState.proposals)
$dispositionValues = @('pending-review', 'accepted', 'rejected', 'modified')
$dispositionSummary = @{}
foreach ($dispositionValue in $dispositionValues) {
  $dispositionSummary[$dispositionValue] = 0
}

foreach ($stepEntry in $stepEntries) {
  $currentDisposition = [string]$stepEntry.disposition
  if (-not $dispositionSummary.ContainsKey($currentDisposition)) {
    $dispositionSummary[$currentDisposition] = 0
  }

  $dispositionSummary[$currentDisposition] += 1
}

function ConvertTo-RepoRelativePath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [string]$WorkspaceRoot
  )

  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $rootPath = [System.IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\')
  if ($fullPath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $fullPath.Substring($rootPath.Length).TrimStart('\').Replace('\', '/')
  }

  return $Path.Replace('\', '/')
}

function Split-GitStatusByArtifact {
  [CmdletBinding()]
  param(
    [string[]]$StatusLines,

    [string[]]$GeneratedArtifactPaths
  )

  $generatedChanges = @()
  $reviewableChanges = @()

  foreach ($statusLine in @($StatusLines)) {
    $currentStatusLine = $statusLine
    if (-not $currentStatusLine) {
      continue
    }

    $relativePath = $currentStatusLine.Substring(3).Trim().Trim('"').Replace('\', '/')
    if ($GeneratedArtifactPaths -contains $relativePath) {
      $generatedChanges += $currentStatusLine
    } else {
      $reviewableChanges += $currentStatusLine
    }
  }

  return [pscustomobject]@{
    Generated = $generatedChanges
    Reviewable = $reviewableChanges
  }
}

$generatedArtifactPaths = @(
  (ConvertTo-RepoRelativePath -Path $OutputPath -WorkspaceRoot $workspaceRoot),
  (ConvertTo-RepoRelativePath -Path $StepLogPath -WorkspaceRoot $workspaceRoot),
  (ConvertTo-RepoRelativePath -Path $PermanentLogPath -WorkspaceRoot $workspaceRoot)
)
$statusGroups = Split-GitStatusByArtifact -StatusLines @($status) -GeneratedArtifactPaths $generatedArtifactPaths

$content = @(
  'LCM_AI Governance Log',
  '===========================',
  '',
  '1. Header',
  '---------',
  'Workspace name: LCM_AI',
  "Generated at: $generatedAt",
  "Latest commit at generation: $latestCommit",
  '',
  '2. Rule Authority',
  '-----------------',
  "Rule authority: $ruleAuthorityPath",
  "Workspace rules: $rulesPath",
  "Agent index: $agentIndexPath",
  '',
  '3. Native Governance Status',
  '----------------------------',
  'Native Generate-Log.ps1: available',
  'Native Advance-Governance.ps1: available when this log is generated through the governance task',
  'Step-oriented log: .copilot/Logs/Workspace.step.log',
  'Permanent accepted log: .copilot/Logs/Workspace.accepted.log',
  'Proposal registry: .copilot/History/Logs/Proposals.json',
  '',
  '4. Proposal Disposition Summary',
  '-------------------------------'
)

foreach ($dispositionValue in $dispositionValues) {
  $content += "${dispositionValue}: $($dispositionSummary[$dispositionValue])"
}

$content += @(
  '',
  '5. Reviewable Git Status',
  '------------------------'
)

if ($statusGroups.Reviewable) {
  $content += $statusGroups.Reviewable
} else {
  $content += 'No reviewable changes.'
}

$content += @(
  '',
  '6. Generated Artifact Status',
  '----------------------------'
)

if ($statusGroups.Generated) {
  $content += $statusGroups.Generated
} else {
  $content += 'No generated artifact changes.'
}

$content += @(
  '',
  '7. Footer',
  '---------',
  'LCM_AI native governance log generation complete.'
)

$outputDirectory = Split-Path $OutputPath -Parent
if (-not (Test-Path -LiteralPath $outputDirectory)) {
  New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

Set-Content -Path $OutputPath -Value $content -Encoding utf8

$stepContent = @(
  'LCM_AI Step-Oriented Governance Log',
  '=========================================',
  '',
  '1. Header',
  '---------',
  'Purpose: Checkpoint log for proposed changes, reasons, and dispositions.',
  'Lifecycle: May be overwritten at checkpoint regeneration.',
  "Generated at: $generatedAt",
  "Latest commit at generation: $latestCommit",
  '',
  '2. Change Proposals',
  '-------------------'
)

foreach ($stepEntry in $stepEntries) {
  $currentStepEntry = $stepEntry
  $fileList = @($currentStepEntry.files) -join '; '
  $stepContent += @(
    "Id: $($currentStepEntry.id)",
    "Proposal: $($currentStepEntry.proposal)",
    "Reason: $($currentStepEntry.reason)",
    "Files: $fileList",
    "Disposition: $($currentStepEntry.disposition)"
  )

  if ($currentStepEntry.PSObject.Properties['disposition_reason']) {
    $stepContent += "Disposition reason: $($currentStepEntry.disposition_reason)"
  }

  if ($currentStepEntry.PSObject.Properties['final_result']) {
    $stepContent += "Final result: $($currentStepEntry.final_result)"
  }

  $stepContent += ''
}

$stepContent += @(
  '3. Proposal Disposition Summary',
  '-------------------------------'
)

foreach ($dispositionValue in $dispositionValues) {
  $stepContent += "${dispositionValue}: $($dispositionSummary[$dispositionValue])"
}

$stepContent += @(
  '',
  '4. Generated Artifacts',
  '----------------------',
  'Generated artifacts are implicit outputs. They are regenerated, committed with accepted checkpoints when needed, and do not receive accepted/rejected/modified dispositions.',
  "- $OutputPath",
  "- $StepLogPath",
  "- $PermanentLogPath",
  '',
  '5. Current Reviewable Git Status',
  '--------------------------------'
)

if ($statusGroups.Reviewable) {
  $stepContent += $statusGroups.Reviewable
} else {
  $stepContent += 'No reviewable changes.'
}

$stepContent += @(
  '',
  '6. Current Generated Artifact Status',
  '------------------------------------'
)

if ($statusGroups.Generated) {
  $stepContent += $statusGroups.Generated
} else {
  $stepContent += 'No generated artifact changes.'
}

$stepContent += @(
  '',
  '7. Footer',
  '---------',
  'LCM_AI step-oriented governance log generation complete.'
)

Set-Content -Path $StepLogPath -Value $stepContent -Encoding utf8

$permanentContent = @(
  'LCM_AI Permanent Accepted Change Log',
  '==========================================',
  '',
  '1. Header',
  '---------',
  'Purpose: Permanent log for accepted changes represented by local commits after the baseline.',
  'Lifecycle: Pushed accepted entries may be archived or reset to an initialized push reference.',
  "Generated at: $generatedAt",
  "Baseline commit: $baselineCommit",
  "Latest commit at generation: $latestCommit",
  '',
  '2. Accepted Local Commits Since Baseline',
  '---------------------------------------'
)

if ($acceptedCommits) {
  $permanentContent += $acceptedCommits
} else {
  $permanentContent += 'No accepted post-baseline commits recorded yet.'
}

$permanentContent += @(
  '',
  '3. Footer',
  '---------',
  'LCM_AI permanent accepted change log generation complete.'
)

Set-Content -Path $PermanentLogPath -Value $permanentContent -Encoding utf8
Write-Host "Generated governance log: $OutputPath"
Write-Host "Generated step governance log: $StepLogPath"
Write-Host "Generated permanent accepted log: $PermanentLogPath"