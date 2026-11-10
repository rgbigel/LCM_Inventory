<#
.SYNOPSIS
  Generates immutable caller-intent reconciliation evidence for CON-001-L01.
.DESCRIPTION
  Module: Invoke-CallerIntentReconciliation
  Purpose: Derives source-linked caller-context documentation evidence from the
           immutable Level 1 baseline and published CRP-121 dependency indexes.
  Path: tools/Invoke-CallerIntentReconciliation.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-10-13
#>

[CmdletBinding()]
param(
  [string]$BaselinePath = '',
  [string]$ForwardIndexPath = '',
  [string]$ReverseIndexPath = '',
  [string]$OutputPath = '',
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptName = 'Invoke-CallerIntentReconciliation'
$scriptVersion = '10.0.0'

if ($Help) {
  Write-Host '=========================================================================='
  Write-Host " $scriptName (v$scriptVersion)"
  Write-Host '=========================================================================='
  Write-Host 'SYNOPSIS:'
  Write-Host '  Creates immutable CON-001-L01 caller-context reconciliation evidence.'
  Write-Host ''
  Write-Host 'USAGE:'
  Write-Host '  pwsh tools\Invoke-CallerIntentReconciliation.ps1 [-BaselinePath <path>]'
  Write-Host '    [-ForwardIndexPath <path>] [-ReverseIndexPath <path>]'
  Write-Host '    [-OutputPath <path>] [-Help]'
  Write-Host ''
  Write-Host 'The command refuses to overwrite retained evidence.'
  Write-Host '=========================================================================='
  return
}

function Get-ContainingFunctionName {
  param(
    [Parameter(Mandatory = $true)]
    [System.Management.Automation.Language.Ast]$Node
  )

  $current = $Node.Parent
  while ($null -ne $current) {
    if ($current -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
      return $current.Name
    }
    $current = $current.Parent
  }

  return $null
}

function Get-ReconciliationClassification {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FunctionName
  )

  switch ($FunctionName) {
    'Assert-IgnoredRepositories' {
      return [pscustomobject]@{
        Relevance = 'high'
        Confidence = 8
        Intent = 'Validates root-container inventory and non-Git repository safety checks.'
      }
    }
    'Assert-StabilizationPolicy' {
      return [pscustomobject]@{
        Relevance = 'high'
        Confidence = 9
        Intent = 'Validates stabilization state, off-limits paths, and disabled external writes.'
      }
    }
    'Assert-RealRepoTestPlan' {
      return [pscustomobject]@{
        Relevance = 'high'
        Confidence = 10
        Intent = 'Validates real-repository plan policy, read-only boundaries, and target-local ownership.'
      }
    }
    'Assert-StaleAuthorityReferences' {
      return [pscustomobject]@{
        Relevance = 'high'
        Confidence = 9
        Intent = 'Prevents stale authority references in governed workspace content.'
      }
    }
    'Expand-LCMTemplate' {
      return [pscustomobject]@{
        Relevance = 'high'
        Confidence = 9
        Intent = 'Instantiates governed repository templates with dry-run and overwrite safeguards.'
      }
    }
    'Get-CompactBCompareInclusion' {
      return [pscustomobject]@{
        Relevance = 'high'
        Confidence = 9
        Intent = 'Validates repository-relative inclusion inputs for scratch-only BCompare review projections.'
      }
    }
    'Get-RepoCMState' {
      return [pscustomobject]@{
        Relevance = 'medium'
        Confidence = 7
        Intent = 'Builds repository configuration-management state using an optional cached state when available.'
      }
    }
    'Get-WorkspaceAIState' {
      return [pscustomobject]@{
        Relevance = 'high'
        Confidence = 9
        Intent = 'Provides authoritative LCM_AI version and lifecycle state for inventory, baseline, and upgrade flows.'
      }
    }
    'New-LCMGovernanceLinks' {
      return [pscustomobject]@{
        Relevance = 'high'
        Confidence = 9
        Intent = 'Seeds governed repository instruction pointers under explicit dry-run control.'
      }
    }
    'Test-LCMIntegrity' {
      return [pscustomobject]@{
        Relevance = 'high'
        Confidence = 10
        Intent = 'Verifies onboarding file coverage and JSON integrity in simulated or physical verification modes.'
      }
    }
    'Test-LCMPreFlight' {
      return [pscustomobject]@{
        Relevance = 'high'
        Confidence = 10
        Intent = 'Validates onboarding targets before governance changes are attempted.'
      }
    }
    'Write-CMLog' {
      return [pscustomobject]@{
        Relevance = 'high'
        Confidence = 9
        Intent = 'Records configuration-management activity with durable push-date provenance.'
      }
    }
    default {
      return $null
    }
  }
}

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$analysisDirectory = Join-Path $repositoryRoot 'data\analysis'
$historyDirectory = Join-Path $analysisDirectory 'history'
$dependencyDirectory = Join-Path $repositoryRoot 'data\dependencies'

if ([string]::IsNullOrWhiteSpace($BaselinePath)) {
  $latestBaseline = Get-ChildItem -LiteralPath $historyDirectory -File |
    Where-Object { $_.Name -match '^CON-001-L01-R\d{3}\.json$' } |
    Sort-Object Name -Descending |
    Select-Object -First 1
  if ($null -eq $latestBaseline) {
    throw "No immutable CON-001-L01 baseline run was found in: $historyDirectory"
  }
  $BaselinePath = $latestBaseline.FullName
}
if ([string]::IsNullOrWhiteSpace($ForwardIndexPath)) {
  $ForwardIndexPath = Join-Path $dependencyDirectory 'forward-index.json'
}
if ([string]::IsNullOrWhiteSpace($ReverseIndexPath)) {
  $ReverseIndexPath = Join-Path $dependencyDirectory 'reverse-index.json'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $historyDirectory ((Split-Path -Path $BaselinePath -LeafBase) + '-S020-CallerIntentReconciliation.json')
}

foreach ($inputPath in @($BaselinePath, $ForwardIndexPath, $ReverseIndexPath)) {
  if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
    throw "Required reconciliation input was not found: $inputPath"
  }
}
if (Test-Path -LiteralPath $OutputPath) {
  throw "Immutable reconciliation evidence already exists and will not be overwritten: $OutputPath"
}

$baseline = Get-Content -LiteralPath $BaselinePath -Raw -Encoding utf8 | ConvertFrom-Json
$forwardIndex = Get-Content -LiteralPath $ForwardIndexPath -Raw -Encoding utf8 | ConvertFrom-Json
$reverseIndex = Get-Content -LiteralPath $ReverseIndexPath -Raw -Encoding utf8 | ConvertFrom-Json

if ([string]$baseline.run_id -notmatch '^CON-001-L01-R\d{3}$') {
  throw "Expected a CON-001-L01 immutable baseline run; received: $($baseline.run_id)"
}
if (-not $baseline.PSObject.Properties['elements']) {
  throw "Baseline evidence has no elements collection: $BaselinePath"
}
if (-not $forwardIndex.PSObject.Properties['edges']) {
  throw "Forward dependency evidence has no edges collection: $ForwardIndexPath"
}
if (-not $reverseIndex.PSObject.Properties['reverse_entries']) {
  throw "Reverse dependency evidence has no reverse_entries collection: $ReverseIndexPath"
}

$resolvedProductionEdges = @($forwardIndex.edges | Where-Object {
    $_.source_classification -eq 'production' -and $_.resolution -eq 'resolved'
  })
$astCache = @{}
$records = @()

foreach ($element in @($baseline.elements | Where-Object { $_.refinement_status -eq 'parameter-gate-not-found' })) {
  $sourcePath = [string]$element.source_file
  if (-not $astCache.ContainsKey($sourcePath)) {
    $tokens = $null
    $parseErrors = $null
    $astCache[$sourcePath] = [System.Management.Automation.Language.Parser]::ParseFile(
      $sourcePath,
      [ref]$tokens,
      [ref]$parseErrors
    )
    if (@($parseErrors).Count -gt 0) {
      throw "Cannot reconcile parameter gate because source parsing failed: $sourcePath"
    }
  }

  $ifAst = @($astCache[$sourcePath].FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.IfStatementAst] -and
        $node.Extent.StartLineNumber -le [int]$element.line -and
        $node.Extent.EndLineNumber -ge [int]$element.line
      }, $true) |
      Sort-Object { $_.Extent.EndOffset - $_.Extent.StartOffset } |
      Select-Object -First 1)
  if ($ifAst.Count -eq 0) {
    $conditionText = [string]$element.element
    $ifAst = @($astCache[$sourcePath].FindAll({
          param($node)
          if ($node -isnot [System.Management.Automation.Language.IfStatementAst]) {
            return $false
          }
          return @($node.Clauses | ForEach-Object { $_.Item1.Extent.Text }) -contains $conditionText
        }, $true) |
        Sort-Object { $_.Extent.StartLineNumber } |
        Select-Object -First 1)
  }
  if ($ifAst.Count -eq 0) {
    throw "Cannot locate parameter-gate AST at ${sourcePath}:$($element.line)"
  }

  $functionName = Get-ContainingFunctionName -Node $ifAst[0]
  if ([string]::IsNullOrWhiteSpace($functionName)) {
    continue
  }

  $callers = @($resolvedProductionEdges | Where-Object {
      [System.IO.Path]::GetFileNameWithoutExtension([string]$_.callee_target) -eq $functionName
    })
  if ($callers.Count -eq 0) {
    continue
  }

  $reverseEntry = @($reverseIndex.reverse_entries | Where-Object {
      $_.callee_name -eq $functionName -and $_.classification -eq 'referenced'
    } | Select-Object -First 1)
  if ($reverseEntry.Count -eq 0) {
    throw "Resolved forward callers have no referenced reverse evidence for: $functionName"
  }

  $classification = Get-ReconciliationClassification -FunctionName $functionName
  if ($null -eq $classification) {
    continue
  }
  $records += [pscustomobject]@{
    baseline_source_file = $sourcePath
    baseline_line = [int]$element.line
    repository = [string]$element.repository
    function = $functionName
    public_parameters = @($element.public_parameters)
    baseline_status = 'parameter-gate-not-found'
    reconciliation_status = 'documented-by-caller-contract'
    documentation_tier = 'caller-context'
    relevance = $classification.Relevance
    confidence = $classification.Confidence
    intent = $classification.Intent
    disposition = 'retain-entrypoint'
    deletion_eligibility = $false
    reverse_classification = [string]$reverseEntry[0].classification
    caller_evidence = @($callers | Sort-Object caller_file, caller_line | ForEach-Object {
        [pscustomobject]@{
          caller_file = [string]$_.caller_file
          caller_line = [int]$_.caller_line
          caller_symbol = [string]$_.caller_symbol
          supplied_arguments = [string]$_.supplied_arguments
        }
      })
  }
}

$expectedRecordCount = switch ($baseline.run_id) {
  'CON-001-L01-R004' { 23 }
  'CON-001-L01-R007' { 23 }
  default { $null }
}
if ($null -ne $expectedRecordCount -and $records.Count -ne $expectedRecordCount) {
  throw "Expected $expectedRecordCount approved caller-context reconciliation records for $($baseline.run_id); found $($records.Count)."
}

$publicParameterGates = [int]$baseline.refinement_summary.public_parameter_gates
$directDocumented = [int]$baseline.refinement_summary.documented_parameter_gates
$unresolved = [int]$baseline.refinement_summary.undocumented_parameter_gates
if (($directDocumented + $unresolved) -ne $publicParameterGates) {
  throw 'Baseline public parameter-gate statistics are internally inconsistent.'
}

$result = [ordered]@{
  analysis_id = 'CON-001-L01'
  baseline_run_id = $baseline.run_id
  derived_step_id = 'CON-001-L01-S020'
  artifact_id = ((Split-Path -Path $BaselinePath -LeafBase) + '-S020-CallerIntentReconciliation')
  generated_at = (Get-Date).ToString('o')
  generator = [ordered]@{
    name = $scriptName
    version = $scriptVersion
  }
  inputs = [ordered]@{
    baseline_path = $BaselinePath
    baseline_sha256 = (Get-FileHash -LiteralPath $BaselinePath -Algorithm SHA256).Hash
    forward_index_path = $ForwardIndexPath
    forward_index_sha256 = (Get-FileHash -LiteralPath $ForwardIndexPath -Algorithm SHA256).Hash
    reverse_index_path = $ReverseIndexPath
    reverse_index_sha256 = (Get-FileHash -LiteralPath $ReverseIndexPath -Algorithm SHA256).Hash
  }
  reconciliation_rules = [ordered]@{
    accepted_forward_edge = 'source_classification=production AND resolution=resolved'
    baseline_status = 'parameter-gate-not-found'
    derived_status = 'documented-by-caller-contract'
    documentation_tier = 'caller-context'
    deletion_action_supported = $false
    expected_record_count = $expectedRecordCount
  }
  statistics = [ordered]@{
    public_parameter_gates = $publicParameterGates
    direct_documented = $directDocumented
    caller_context_documented = $records.Count
    total_documented = $directDocumented + $records.Count
    still_unresolved = $unresolved - $records.Count
  }
  records = @($records | Sort-Object baseline_source_file, baseline_line)
}

$outputDirectory = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
  $null = New-Item -ItemType Directory -Path $outputDirectory -Force
}
$json = $result | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($OutputPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
Write-Host "Created immutable caller-intent reconciliation evidence: $OutputPath" -ForegroundColor Green
