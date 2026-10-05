<#
.SYNOPSIS
  Generates the refined Level 1 functional documentation traceability evidence report.
.DESCRIPTION
  Module: Invoke-Level1AnalysisRefinement
  Purpose: Classifies retained Level 1 branch evidence into public parameter gates,
           design-comment evidence, and internal control flow using an approved
           CON definition without modifying the source baseline evidence.
  Path: tools/Invoke-Level1AnalysisRefinement.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 1.1.0
  Date: 2026-10-05
#>

[CmdletBinding()]
param(
  [string]$DefinitionPath = '',
  [string]$OutputPath = '',
  [string]$RunId = '',
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptName = 'Invoke-Level1AnalysisRefinement'
$scriptVersion = '1.1.0'

if ($Help) {
  Write-Host '==========================================================================' 
  Write-Host " $scriptName (v$scriptVersion)"
  Write-Host '==========================================================================' 
  Write-Host 'SYNOPSIS:'
  Write-Host '  Creates a refined CON-001-L01 evidence run from its immutable R001 baseline.'
  Write-Host ''
  Write-Host 'USAGE:'
  Write-Host '  pwsh tools\Invoke-Level1AnalysisRefinement.ps1 [-DefinitionPath <path>] [-OutputPath <path>] [-RunId <CON-nnn-Lnn-Rnnn>] [-Help]'
  Write-Host ''
  Write-Host 'DEFAULTS:'
  Write-Host '  Definition: data\analysis\definitions\CON-001-L01.json'
  Write-Host '  Output:     next available immutable CON-001-L01-Rnnn.json'
  Write-Host '==========================================================================' 
  return
}

function Get-PropertyValue {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Object,
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [object]$Default = $null
  )

  if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) {
    return $Object.$Name
  }

  return $Default
}

function Add-RefinementProperty {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Object,
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [AllowNull()]
    [object]$Value
  )

  $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value -Force
}

function Get-ContainingFunction {
  param([Parameter(Mandatory = $true)][System.Management.Automation.Language.Ast]$Node)

  $current = $Node.Parent
  while ($null -ne $current) {
    if ($current -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
      return $current
    }
    $current = $current.Parent
  }

  return $null
}

function Get-ParameterNames {
  param([AllowNull()][System.Management.Automation.Language.ParamBlockAst]$ParamBlock)

  if ($null -eq $ParamBlock) {
    return @()
  }

  return @($ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
}

function Get-ExportedFunctionNames {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,
    [Parameter(Mandatory = $true)]
    [System.Management.Automation.Language.ScriptBlockAst]$Ast
  )

  $functionNames = @($Ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
      }, $true) | ForEach-Object { $_.Name })
  $source = Get-Content -LiteralPath $SourcePath -Raw -Encoding utf8
  $exportStatements = @([regex]::Matches($source, '(?im)^\s*Export-ModuleMember\b.*$'))

  if ($exportStatements.Count -eq 0) {
    return $functionNames
  }

  $exported = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($statement in $exportStatements) {
    $match = [regex]::Match($statement.Value, '(?i)-Function\s+(.+?)(?:\s+-\w+|$)')
    if (-not $match.Success) {
      continue
    }

    foreach ($name in [regex]::Matches($match.Groups[1].Value, '[A-Za-z][A-Za-z0-9-]*')) {
      $null = $exported.Add($name.Value)
    }
  }

  return @($functionNames | Where-Object { $exported.Contains($_) })
}

function Get-DocumentationFiles {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,
    [Parameter(Mandatory = $true)]
    [string]$Check
  )

  switch ($Check) {
    'check1' { return @(Join-Path $RepositoryRoot 'docs\Implementation.md') }
    'check2' { return @(Join-Path $RepositoryRoot 'docs\Requirements.md') }
    'check3' { return @(Join-Path $RepositoryRoot 'README.md') }
    'check4' {
      $proposalRoot = Join-Path $RepositoryRoot 'docs\Proposals'
      if (Test-Path -LiteralPath $proposalRoot -PathType Container) {
        return @(Get-ChildItem -LiteralPath $proposalRoot -Filter '*.md' -File -Recurse -ErrorAction Stop |
            Select-Object -ExpandProperty FullName)
      }
      return @()
    }
  }
}

function Find-ParameterDocumentation {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ParameterName,
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,
    [Parameter(Mandatory = $true)]
    [string]$Check
  )

  $evidence = @()
  $pattern = '(?i)(?<![A-Za-z0-9_])(?:-|\$)?{0}(?![A-Za-z0-9_])' -f [regex]::Escape($ParameterName)
  foreach ($documentPath in (Get-DocumentationFiles -RepositoryRoot $RepositoryRoot -Check $Check)) {
    if (-not (Test-Path -LiteralPath $documentPath -PathType Leaf)) {
      continue
    }

    $match = Select-String -LiteralPath $documentPath -Pattern $pattern -Encoding utf8 | Select-Object -First 1
    if ($null -ne $match) {
      $evidence += [pscustomobject]@{
        check = $Check
        document = $documentPath
        line = $match.LineNumber
        text = $match.Line.Trim()
      }
    }
  }

  return @($evidence)
}

function Get-StrongNearbyComment {
  param(
    [Parameter(Mandatory = $true)]
    [System.Management.Automation.Language.Token[]]$Tokens,
    [Parameter(Mandatory = $true)]
    [int]$Line,
    [Parameter(Mandatory = $true)]
    [string[]]$Keywords
  )

  $commentTokens = @($Tokens | Where-Object {
      $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment -and
      $_.Extent.StartLineNumber -ge ($Line - 1) -and
      $_.Extent.StartLineNumber -le $Line
    })
  foreach ($comment in $commentTokens) {
    $text = $comment.Text.TrimStart('#').Trim()
    $pattern = '(?i)\b({0})\b' -f (($Keywords | ForEach-Object { [regex]::Escape($_) }) -join '|')
    if ($text -match $pattern) {
      return [pscustomobject]@{
        line = $comment.Extent.StartLineNumber
        text = $text
      }
    }
  }

  return $null
}

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$analysisDirectory = Join-Path $repositoryRoot 'data\analysis'
$definitionDirectory = Join-Path $analysisDirectory 'definitions'
$historyDirectory = Join-Path $analysisDirectory 'history'
$logDirectory = Join-Path $repositoryRoot 'data\logs\lcm'
$null = New-Item -ItemType Directory -Path $definitionDirectory -Force
$null = New-Item -ItemType Directory -Path $historyDirectory -Force
$null = New-Item -ItemType Directory -Path $logDirectory -Force

if ([string]::IsNullOrWhiteSpace($DefinitionPath)) {
  $DefinitionPath = Join-Path $definitionDirectory 'CON-001-L01.json'
}

if (-not (Test-Path -LiteralPath $DefinitionPath -PathType Leaf)) {
  throw "Analysis definition was not found: $DefinitionPath"
}

$definition = Get-Content -LiteralPath $DefinitionPath -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop
$definitionHash = (Get-FileHash -LiteralPath $DefinitionPath -Algorithm SHA256).Hash
if ($definition.status -ne 'approved') {
  throw "Analysis definition must be approved before execution: $DefinitionPath"
}

$baselinePath = Join-Path $analysisDirectory $definition.source_baseline
if (-not (Test-Path -LiteralPath $baselinePath -PathType Leaf)) {
  throw "Immutable baseline evidence was not found: $baselinePath"
}

$runIdPattern = '^{0}-R\d{{3}}$' -f [regex]::Escape([string]$definition.id)
if ([string]::IsNullOrWhiteSpace($RunId)) {
  $existingRunNumbers = @(
    Get-ChildItem -LiteralPath $analysisDirectory -Filter ('{0}-R*.json' -f $definition.id) -File -Recurse |
      ForEach-Object {
        $match = [regex]::Match($_.BaseName, ('^{0}-R(\d{{3}})$' -f [regex]::Escape([string]$definition.id)))
        if ($match.Success) { [int]$match.Groups[1].Value }
      }
  )
  [int]$nextRunNumber = if ($existingRunNumbers.Count -gt 0) { (($existingRunNumbers | Measure-Object -Maximum).Maximum + 1) } else { 1 }
  $RunId = '{0}-R{1:D3}' -f $definition.id, $nextRunNumber
} elseif ($RunId -notmatch $runIdPattern) {
  throw "RunId must match $($definition.id)-Rnnn: $RunId"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $historyDirectory ($RunId + '.json')
}

if (Test-Path -LiteralPath $OutputPath -PathType Leaf) {
  throw "Immutable evidence run already exists: $OutputPath"
}

$logPath = Join-Path $logDirectory "$scriptName-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-AnalysisLog {
  param([string]$Message, [ValidateSet('INFO', 'PASS', 'WARN', 'ERROR')][string]$Level = 'INFO')
  Add-Content -LiteralPath $logPath -Value ('[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message) -Encoding utf8
}

$baseline = Get-Content -LiteralPath $baselinePath -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop
$baselineHash = (Get-FileHash -LiteralPath $baselinePath -Algorithm SHA256).Hash
if ($baseline.step0_rule_baseline.check0 -ne 'Check 0: OK') {
  throw "Baseline rule-equivalence gate is not OK: $($baseline.step0_rule_baseline.check0)"
}

$sourceCache = @{}
$parseLimitations = @()
foreach ($sourcePath in @($baseline.elements.source_file | Sort-Object -Unique)) {
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    Write-AnalysisLog -Message "Source file no longer exists and retains baseline-only evidence: $sourcePath" -Level WARN
    continue
  }

  $parseErrors = $null
  $tokens = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$parseErrors)
  $blockingParseErrors = @($parseErrors | Where-Object { $_.Message -notmatch '^Unable to find type ' })
  if ($blockingParseErrors.Count -gt 0) {
    throw "Source file failed PowerShell parsing: $sourcePath"
  }
  if (@($parseErrors).Count -gt 0) {
    Write-AnalysisLog -Message "Retaining AST analysis with unresolved cross-file type references: $sourcePath" -Level WARN
    $parseLimitations += [pscustomobject]@{
      source_file = $sourcePath
      limitation = 'unresolved-cross-file-type-reference'
      messages = @($parseErrors | ForEach-Object { $_.Message })
    }
  }

  $ifByLine = @{}
  foreach ($ifAst in @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.IfStatementAst] }, $true))) {
    $ifByLine[$ifAst.Extent.StartLineNumber] = $ifAst
  }
  $sourceCache[$sourcePath] = [pscustomobject]@{
    ast = $ast
    tokens = @($tokens)
    if_by_line = $ifByLine
    exported_functions = @(if ([System.IO.Path]::GetExtension($sourcePath) -eq '.psm1') {
        Get-ExportedFunctionNames -SourcePath $sourcePath -Ast $ast
      } else {
        @()
      })
  }
}

$counts = [ordered]@{
  public_parameter_gates = 0
  documented_parameter_gates = 0
  undocumented_parameter_gates = 0
  design_comment_gates = 0
  internal_control_flow = 0
  named_elements = 0
}

foreach ($element in @($baseline.elements)) {
  Add-RefinementProperty -Object $element -Name 'classification' -Value 'named-functional-element'
  Add-RefinementProperty -Object $element -Name 'checkability' -Value 'legacy-documentation-traceability'
  Add-RefinementProperty -Object $element -Name 'refinement_status' -Value 'not-applicable'
  Add-RefinementProperty -Object $element -Name 'public_parameters' -Value @()
  Add-RefinementProperty -Object $element -Name 'comment_evidence' -Value $null
  Add-RefinementProperty -Object $element -Name 'documentation_evidence' -Value @()

  if ($element.kind -ne 'if') {
    $counts.named_elements++
    continue
  }

  $cache = $sourceCache[$element.source_file]
  $ifAst = if ($null -ne $cache) { $cache.if_by_line[[int]$element.line] } else { $null }
  if ($null -eq $ifAst) {
    Add-RefinementProperty -Object $element -Name 'classification' -Value 'requires-semantic-review'
    Add-RefinementProperty -Object $element -Name 'checkability' -Value 'source-location-unavailable'
    Add-RefinementProperty -Object $element -Name 'refinement_status' -Value 'requires-semantic-review'
    continue
  }

  $function = Get-ContainingFunction -Node $ifAst
  $parameterNames = @()
  $isPublicScope = $false
  if ($null -ne $function -and [System.IO.Path]::GetExtension($element.source_file) -eq '.psm1') {
    if (@($cache.exported_functions) -contains $function.Name) {
      $parameterNames = Get-ParameterNames -ParamBlock $function.Body.ParamBlock
      $isPublicScope = $true
    }
  } elseif ([System.IO.Path]::GetExtension($element.source_file) -eq '.ps1') {
    $parameterNames = Get-ParameterNames -ParamBlock $cache.ast.ParamBlock
    $isPublicScope = $true
  }

  $conditionText = $ifAst.Clauses[0].Item1.Extent.Text
  $referencedParameters = @($parameterNames | Where-Object {
      $conditionText -match ('(?i)\$' + [regex]::Escape($_) + '(?![A-Za-z0-9_])')
    })

  if ($isPublicScope -and $referencedParameters.Count -gt 0) {
    $counts.public_parameter_gates++
    $allEvidence = @()
    foreach ($check in @('check1', 'check2', 'check3', 'check4')) {
      foreach ($parameterName in $referencedParameters) {
        $allEvidence += Find-ParameterDocumentation -ParameterName $parameterName -RepositoryRoot (Split-Path $element.source_file -Parent | Split-Path -Parent) -Check $check
      }
      if (@($allEvidence | Where-Object { $_.check -eq $check }).Count -gt 0) {
        break
      }
    }
    $status = if ($allEvidence.Count -gt 0) { 'parameter-gate-documented' } else { 'parameter-gate-not-found' }
    if ($status -eq 'parameter-gate-documented') { $counts.documented_parameter_gates++ } else { $counts.undocumented_parameter_gates++ }
    Add-RefinementProperty -Object $element -Name 'classification' -Value 'public-parameter-gate'
    Add-RefinementProperty -Object $element -Name 'checkability' -Value 'documentation-traceable'
    Add-RefinementProperty -Object $element -Name 'refinement_status' -Value $status
    Add-RefinementProperty -Object $element -Name 'public_parameters' -Value $referencedParameters
    Add-RefinementProperty -Object $element -Name 'documentation_evidence' -Value @($allEvidence)
    continue
  }

  $comment = Get-StrongNearbyComment -Tokens $cache.tokens -Line $element.line -Keywords @($definition.branch_refinement.design_comment_gate.keywords)
  if ($null -ne $comment) {
    $counts.design_comment_gates++
    Add-RefinementProperty -Object $element -Name 'classification' -Value 'purpose-design-comment-gate'
    Add-RefinementProperty -Object $element -Name 'checkability' -Value 'semantic-consistency-review'
    Add-RefinementProperty -Object $element -Name 'refinement_status' -Value 'requires-semantic-review'
    Add-RefinementProperty -Object $element -Name 'comment_evidence' -Value $comment
    continue
  }

  $counts.internal_control_flow++
  Add-RefinementProperty -Object $element -Name 'classification' -Value 'internal-control-flow'
  Add-RefinementProperty -Object $element -Name 'checkability' -Value 'informational-excluded'
  Add-RefinementProperty -Object $element -Name 'refinement_status' -Value 'internal-control-flow'
}

$report = [ordered]@{
  analysis_id = $definition.id
  run_id = $RunId
  generated_at = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
  definition_path = $DefinitionPath
  definition_version = $definition.version
  definition_sha256 = $definitionHash
  baseline_evidence_path = $baselinePath
  baseline_evidence_sha256 = $baselineHash
  runner_version = $scriptVersion
  goal = $definition.goal
  matching = 'Deterministic public-parameter reference detection and literal parameter-name documentation evidence. Design comments are retained for semantic review; internal control flow is excluded from top-level documentation completeness.'
  source_scope = $baseline.source_scope
  open_proposals = $baseline.open_proposals
  step0_rule_baseline = $baseline.step0_rule_baseline
  parse_limitations = @($parseLimitations)
  refinement_summary = $counts
  elements = @($baseline.elements)
}

$outputDirectory = Split-Path -Path $OutputPath -Parent
$null = New-Item -ItemType Directory -Path $outputDirectory -Force
[System.IO.File]::WriteAllText($OutputPath, ($report | ConvertTo-Json -Depth 16), [System.Text.UTF8Encoding]::new($false))
Write-AnalysisLog -Message "Generated $($definition.run_id) with $($counts.public_parameter_gates) public parameter gates." -Level PASS

Write-Host "[SUMMARY] Tool: $scriptName"
Write-Host "[SUMMARY] Version: $scriptVersion"
Write-Host '[SUMMARY] Status: COMPLETED'
Write-Host "[SUMMARY] Log: $logPath"
Write-Host "[SUMMARY] Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
