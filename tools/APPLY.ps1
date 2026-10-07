<#
.SYNOPSIS
  Run native LCM_AI fix descriptor validation from PowerShell 7.

.PARAMETER FixName
  Name or ID of the fix module to validate.

.PARAMETER NoLog
  Suppresses writing audit telemetry logs.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Name or ID of the fix module to validate.')]
  [string]$FixName,

  [Parameter(Mandatory = $false, HelpMessage = 'Suppresses writing audit telemetry logs.')]
  [switch]$NoLog,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "APPLY.ps1 - Run native LCM_AI fix descriptor validation." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File APPLY.ps1 -FixName <string> [-NoLog] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -FixName Name or ID of the fix module."
  Write-Host "  -NoLog   Do not write to validation log."
  Write-Host "  -Help    (-h, -?) Displays this help message."
  exit 0
}

if (-not $FixName) {
  throw "Parameter -FixName is required."
}

<#
Module: APPLY.ps1
Purpose: Run native LCM_AI fix descriptor validation from PowerShell 7.
Path: tools/APPLY.ps1
Authors: LCM_AI Engine
Version: 1.0.0
Caller Contract: Called with a fix module name or id; validates declared rules, atoms, methods, and quality-check actions without modifying target content.
Changelog:
- 2026-08-01: Replaced loader stub with native fix descriptor validation for Gemini/Continue migration.
#>

function Resolve-WorkspaceRoot {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$MethodsRoot
  )

  return Split-Path $MethodsRoot -Parent
}

function Test-RequiredFiles {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [pscustomobject]$FixModule,

    [Parameter(Mandatory=$true)]
    [string]$CopilotRoot,

    [Parameter(Mandatory=$true)]
    [string]$MethodsRoot
  )

  $missingItems = @()

  if ($FixModule.PSObject.Properties['requires']) {
    $requires = $FixModule.requires

    foreach ($atom in @($requires.atoms)) {
      $atomName = [string]$atom
      $atomPath = Join-Path $CopilotRoot (Join-Path 'Atoms' $atomName)
      if (-not (Test-Path -LiteralPath $atomPath)) {
        $missingItems += $atomPath
      }
    }

    foreach ($method in @($requires.methods)) {
      $methodName = [string]$method
      $methodPath = Join-Path $MethodsRoot $methodName
      if (-not (Test-Path -LiteralPath $methodPath)) {
        $missingItems += $methodPath
      }
    }

    foreach ($rule in @($requires.rules)) {
      $ruleName = [string]$rule
      $rulePath = Join-Path $CopilotRoot (Join-Path 'Rules' $ruleName)
      if (-not (Test-Path -LiteralPath $rulePath)) {
        $missingItems += $rulePath
      }
    }
  }

  foreach ($rule in @($FixModule.rules)) {
    $ruleName = [string]$rule
    $rulePath = Join-Path $CopilotRoot $ruleName
    if (-not (Test-Path -LiteralPath $rulePath)) {
      $missingItems += $rulePath
    }
  }

  if ($missingItems.Count -gt 0) {
    throw ('Missing required files: ' + ($missingItems -join '; '))
  }
}

function Invoke-JsonQualityCheck {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceRoot
  )

  $jsonFiles = Get-ChildItem -Path $WorkspaceRoot -Filter '*.json' -File -Recurse | Sort-Object -Property FullName
  foreach ($jsonFile in $jsonFiles) {
    $currentJsonFile = $jsonFile
    Get-Content -Raw -Path $currentJsonFile.FullName | ConvertFrom-Json | Out-Null
  }

  return "JSON parse OK ($($jsonFiles.Count) files)"
}

function Invoke-PowerShellQualityCheck {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceRoot
  )

  $scriptFiles = Get-ChildItem -Path $WorkspaceRoot -Filter '*.ps1' -File -Recurse | Sort-Object -Property FullName
  foreach ($scriptFile in $scriptFiles) {
    $currentScriptFile = $scriptFile
    $parseErrors = @()
    [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw -Path $currentScriptFile.FullName), [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
      throw "PowerShell parse failed: $($currentScriptFile.FullName)"
    }
  }

  return "PowerShell parse OK ($($scriptFiles.Count) files)"
}

function Invoke-CmdQualityCheck {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceRoot
  )

  $cmdFiles = Get-ChildItem -Path $WorkspaceRoot -Filter '*.cmd' -File -Recurse | Sort-Object -Property FullName
  return "CMD discovery OK ($($cmdFiles.Count) files)"
}

function Invoke-InvariantQualityCheck {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceRoot
  )

  $trackedFiles = git -C $WorkspaceRoot ls-files
  if (-not $trackedFiles) {
    throw 'Invariant check requires a git-tracked workspace.'
  }

  return "Invariant tracked-file discovery OK ($($trackedFiles.Count) files)"
}

function Invoke-FixActions {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [pscustomobject]$FixModule,

    [Parameter(Mandatory=$true)]
    [string]$WorkspaceRoot
  )

  $results = @()

  foreach ($action in @($FixModule.actions)) {
    $currentAction = $action

    if ($currentAction -is [string]) {
      switch ($currentAction) {
        'load_rules' { $results += 'load_rules action declared' }
        'validate_rules' { $results += 'validate_rules action declared' }
        default { throw "Unsupported string action: $currentAction" }
      }

      continue
    }

    if (-not $currentAction.PSObject.Properties['type']) {
      throw 'Action is missing type.'
    }

    if ($currentAction.type -ne 'quality-check') {
      throw "Unsupported action type: $($currentAction.type)"
    }

    switch ([string]$currentAction.target) {
      '*.json' { $results += Invoke-JsonQualityCheck -WorkspaceRoot $WorkspaceRoot }
      '*.ps1' { $results += Invoke-PowerShellQualityCheck -WorkspaceRoot $WorkspaceRoot }
      '*.cmd' { $results += Invoke-CmdQualityCheck -WorkspaceRoot $WorkspaceRoot }
      '**/*' { $results += Invoke-InvariantQualityCheck -WorkspaceRoot $WorkspaceRoot }
      default { throw "Unsupported quality-check target: $($currentAction.target)" }
    }
  }

  return $results
}

function Write-FixLog {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [pscustomobject]$FixModule,

    [Parameter(Mandatory=$true)]
    [string[]]$Results,

    [Parameter(Mandatory=$true)]
    [string]$CopilotRoot
  )

  $fixId = if ($FixModule.PSObject.Properties['id']) { $FixModule.id } else { 'Fix_Unknown' }
  $logPath = Join-Path $CopilotRoot (Join-Path 'Logs' ($fixId + '.native.log'))

  if ($FixModule.PSObject.Properties['logging'] -and $FixModule.logging.PSObject.Properties['path']) {
    $logPath = Join-Path (Split-Path $CopilotRoot -Parent) $FixModule.logging.path
  }

  $logDirectory = Split-Path $logPath -Parent
  if (-not (Test-Path -LiteralPath $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
  }

  $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $content = @(
    "Fix: $fixId",
    "Timestamp: $timestamp",
    'Native APPLY result: OK',
    'Results:'
  )

  foreach ($result in $Results) {
    $currentResult = $result
    $content += "- $currentResult"
  }

  Set-Content -Path $logPath -Value $content -Encoding utf8
  return $logPath
}

$workspaceRoot = Resolve-WorkspaceRoot -MethodsRoot $PSScriptRoot
$copilotRoot = Join-Path $workspaceRoot '.copilot'
$loadFixesPath = Join-Path $PSScriptRoot 'LoadFixes.ps1'

if (-not (Test-Path -LiteralPath $loadFixesPath)) {
  throw "LoadFixes.ps1 not found: $loadFixesPath"
}

$fixes = & $loadFixesPath
if (-not $fixes.ContainsKey($FixName)) {
  throw "Unknown fix module: $FixName"
}

$fixModule = $fixes[$FixName]
Test-RequiredFiles -FixModule $fixModule -CopilotRoot $copilotRoot -MethodsRoot $PSScriptRoot
$results = Invoke-FixActions -FixModule $fixModule -WorkspaceRoot $workspaceRoot

Write-Host "APPLY native validation OK: $FixName"
foreach ($result in $results) {
  $currentResult = $result
  Write-Host $currentResult
}

if (-not $NoLog) {
  $writtenLogPath = Write-FixLog -FixModule $fixModule -Results $results -CopilotRoot $copilotRoot
  Write-Host "Fix log: $writtenLogPath"
}
