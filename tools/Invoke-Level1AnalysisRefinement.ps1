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

function Find-HelpParameterDocumentation {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ParameterName,
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,
    [Parameter(Mandatory = $true)]
    [int]$DeclarationLine
  )

  $lines = @(Get-Content -LiteralPath $SourcePath -Encoding utf8)
  $startLine = [Math]::Max(1, $DeclarationLine - 40)
  $endLine = [Math]::Max(0, $DeclarationLine - 1)
  $pattern = '^\s*(?:\*\s*)?\.PARAMETER\s+{0}\s*$' -f [regex]::Escape($ParameterName)
  for ($lineNumber = $startLine; $lineNumber -le $endLine; $lineNumber++) {
    if ($lines[$lineNumber - 1] -match $pattern) {
      return [pscustomobject]@{
        check = 'help'
        document = $SourcePath
        line = $lineNumber
        text = $lines[$lineNumber - 1].Trim()
      }
    }
  }

  return $null
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

function Test-ParameterPresenceSafetyNet {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ConditionText,
    [Parameter(Mandatory = $true)]
    [string[]]$ParameterNames
  )

  $condition = $ConditionText.Trim()
  foreach ($parameterName in $ParameterNames) {
    $parameterPattern = '\$' + [regex]::Escape($parameterName) + '(?![A-Za-z0-9_])'
    $presencePatterns = @(
      "^(?i:$parameterPattern)$",
      "^(?i:-not\s+$parameterPattern)$",
      "^(?i:$parameterPattern\s+-eq\s+\`$null)$",
      "^(?i:$parameterPattern\s+-ne\s+\`$null)$",
      "^(?i:\`$null\s+-eq\s+$parameterPattern)$",
      "^(?i:\`$null\s+-ne\s+$parameterPattern)$",
      "^(?i:\[string\]::IsNullOrEmpty\($parameterPattern\))$",
      "^(?i:\[string\]::IsNullOrWhiteSpace\($parameterPattern\))$",
      "^(?i:-not\s+\[string\]::IsNullOrEmpty\($parameterPattern\))$",
      "^(?i:-not\s+\[string\]::IsNullOrWhiteSpace\($parameterPattern\))$"
    )
    if ($presencePatterns | Where-Object { $condition -match $_ }) {
      return $true
    }
  }
  return $false
}

function Resolve-IfAst {
  param(
    [AllowNull()]
    [object]$Cache,
    [Parameter(Mandatory = $true)]
    [int]$BaselineLine,
    [Parameter(Mandatory = $true)]
    [string]$ConditionText
  )

  if ($null -eq $Cache) {
    return $null
  }
  $exact = $Cache.if_by_line[$BaselineLine]
  if ($null -ne $exact) {
    return $exact
  }

  $candidates = @($Cache.ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.IfStatementAst] -and
        $node.Clauses[0].Item1.Extent.Text -eq $ConditionText
      }, $true) |
      Sort-Object { [math]::Abs($_.Extent.StartLineNumber - $BaselineLine) })
  if ($candidates.Count -eq 0) {
    $candidates = @($Cache.ast.FindAll({
          param($node)
          $node -is [System.Management.Automation.Language.IfStatementAst] -and
          [math]::Abs($node.Extent.StartLineNumber - $BaselineLine) -le 5
        }, $true) |
        Sort-Object { [math]::Abs($_.Extent.StartLineNumber - $BaselineLine) })
  }
  if ($candidates.Count -eq 0) {
    return $null
  }
  return $candidates[0]
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

$analysisElements = @()
$expandedIfAsts = @{}
foreach ($baselineElement in @($baseline.elements)) {
  if ($baselineElement.kind -ne 'if') {
    $analysisElements += $baselineElement
    continue
  }

  $cache = $sourceCache[$baselineElement.source_file]
  $ifAst = Resolve-IfAst -Cache $cache -BaselineLine ([int]$baselineElement.line) -ConditionText ([string]$baselineElement.element)
  if ($null -eq $ifAst) {
    $analysisElements += $baselineElement
    continue
  }
  $ifAstKey = '{0}:{1}:{2}' -f $baselineElement.source_file, $ifAst.Extent.StartOffset, $ifAst.Extent.EndOffset
  if ($expandedIfAsts.ContainsKey($ifAstKey)) {
    continue
  }
  $expandedIfAsts[$ifAstKey] = $true

  for ($branchIndex = 0; $branchIndex -lt @($ifAst.Clauses).Count; $branchIndex++) {
    $branch = if ($branchIndex -eq 0) { $baselineElement } else { $baselineElement | Select-Object * }
    $condition = $ifAst.Clauses[$branchIndex].Item1
    Add-RefinementProperty -Object $branch -Name 'parent_if_line' -Value $ifAst.Extent.StartLineNumber
    Add-RefinementProperty -Object $branch -Name 'branch_kind' -Value $(if ($branchIndex -eq 0) { 'if' } else { 'elseif' })
    Add-RefinementProperty -Object $branch -Name 'branch_index' -Value $branchIndex
    Add-RefinementProperty -Object $branch -Name 'branch_condition' -Value $condition.Extent.Text
    Add-RefinementProperty -Object $branch -Name 'branch_body_start_line' -Value $ifAst.Clauses[$branchIndex].Item2.Extent.StartLineNumber
    Add-RefinementProperty -Object $branch -Name 'branch_body_end_line' -Value $ifAst.Clauses[$branchIndex].Item2.Extent.EndLineNumber
    if ($branchIndex -gt 0) {
      Add-RefinementProperty -Object $branch -Name 'kind' -Value 'elseif'
      Add-RefinementProperty -Object $branch -Name 'line' -Value $condition.Extent.StartLineNumber
      Add-RefinementProperty -Object $branch -Name 'element' -Value $condition.Extent.Text
    }
    $analysisElements += $branch
  }

  if ($null -ne $ifAst.ElseClause) {
    $fallback = $baselineElement | Select-Object *
    Add-RefinementProperty -Object $fallback -Name 'parent_if_line' -Value $ifAst.Extent.StartLineNumber
    Add-RefinementProperty -Object $fallback -Name 'branch_kind' -Value 'else'
    Add-RefinementProperty -Object $fallback -Name 'branch_index' -Value @($ifAst.Clauses).Count
    Add-RefinementProperty -Object $fallback -Name 'branch_condition' -Value $null
    Add-RefinementProperty -Object $fallback -Name 'branch_body_start_line' -Value $ifAst.ElseClause.Extent.StartLineNumber
    Add-RefinementProperty -Object $fallback -Name 'branch_body_end_line' -Value $ifAst.ElseClause.Extent.EndLineNumber
    Add-RefinementProperty -Object $fallback -Name 'kind' -Value 'else'
    Add-RefinementProperty -Object $fallback -Name 'line' -Value $ifAst.ElseClause.Extent.StartLineNumber
    Add-RefinementProperty -Object $fallback -Name 'element' -Value 'else'
    $analysisElements += $fallback
  }
}

$parameterHelpRecords = @()
foreach ($sourcePath in @($sourceCache.Keys | Sort-Object)) {
  $cache = $sourceCache[$sourcePath]
  $extension = [System.IO.Path]::GetExtension($sourcePath)
  $parameterScopes = @()
  if ($extension -eq '.ps1' -and $null -ne $cache.ast.ParamBlock) {
    $parameterScopes += [pscustomobject]@{
      Function = $null
      DeclarationLine = $cache.ast.ParamBlock.Extent.StartLineNumber
      Parameters = @(Get-ParameterNames -ParamBlock $cache.ast.ParamBlock)
    }
  } elseif ($extension -eq '.psm1') {
    foreach ($functionAst in @($cache.ast.FindAll({
          param($node)
          $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
          @($cache.exported_functions) -contains $node.Name
        }, $true))) {
      $parameterScopes += [pscustomobject]@{
        Function = $functionAst.Name
        DeclarationLine = $functionAst.Extent.StartLineNumber
        Parameters = @(Get-ParameterNames -ParamBlock $functionAst.Body.ParamBlock)
      }
    }
  }

  foreach ($parameterScope in $parameterScopes) {
    foreach ($parameterName in $parameterScope.Parameters) {
      $helpMatch = Find-HelpParameterDocumentation -ParameterName $parameterName -SourcePath $sourcePath -DeclarationLine $parameterScope.DeclarationLine
      $parameterHelpRecords += [pscustomobject]@{
        source_file = $sourcePath
        function = $parameterScope.Function
        parameter = $parameterName
        help_documented = $null -ne $helpMatch
        help_evidence = $helpMatch
      }
    }
  }
}

foreach ($branch in @($analysisElements | Where-Object {
      $_.PSObject.Properties['branch_kind'] -and
      $_.branch_kind -in @('if', 'elseif', 'else') -and
      $null -ne $_.branch_body_start_line -and
      $null -ne $_.branch_body_end_line
    })) {
  $enclosedCount = @($analysisElements | Where-Object {
      $_.source_file -eq $branch.source_file -and
      $_.line -ge [int]$branch.branch_body_start_line -and
      $_.line -le [int]$branch.branch_body_end_line -and
      -not ($_.source_file -eq $branch.source_file -and
        $_.line -eq $branch.line -and
        $_.PSObject.Properties['branch_index'] -and
        $_.branch_index -eq $branch.branch_index)
    }).Count
  Add-RefinementProperty -Object $branch -Name 'enclosed_element_count' -Value $enclosedCount
}

$counts = [ordered]@{
  public_parameter_gates = 0
  documented_parameter_gates = 0
  undocumented_parameter_gates = 0
  design_comment_gates = 0
  fallback_branches = 0
  internal_control_flow = 0
  named_elements = 0
}

foreach ($element in @($analysisElements)) {
  Add-RefinementProperty -Object $element -Name 'classification' -Value 'named-functional-element'
  Add-RefinementProperty -Object $element -Name 'checkability' -Value 'legacy-documentation-traceability'
  Add-RefinementProperty -Object $element -Name 'refinement_status' -Value 'not-applicable'
  Add-RefinementProperty -Object $element -Name 'public_parameters' -Value @()
  Add-RefinementProperty -Object $element -Name 'help_evidence' -Value @()
  Add-RefinementProperty -Object $element -Name 'comment_evidence' -Value $null
  Add-RefinementProperty -Object $element -Name 'documentation_evidence' -Value @()
  Add-RefinementProperty -Object $element -Name 'branch_kind' -Value $(if ($element.PSObject.Properties['branch_kind']) { $element.branch_kind } elseif ($element.kind -eq 'if') { 'if' } else { 'not-applicable' })
  Add-RefinementProperty -Object $element -Name 'branch_index' -Value $(if ($element.PSObject.Properties['branch_index']) { $element.branch_index } else { $null })
  Add-RefinementProperty -Object $element -Name 'branch_condition' -Value $(if ($element.PSObject.Properties['branch_condition']) { $element.branch_condition } elseif ($element.kind -eq 'if') { $element.element } else { $null })
  Add-RefinementProperty -Object $element -Name 'branch_body_start_line' -Value $(if ($element.PSObject.Properties['branch_body_start_line']) { $element.branch_body_start_line } else { $null })
  Add-RefinementProperty -Object $element -Name 'branch_body_end_line' -Value $(if ($element.PSObject.Properties['branch_body_end_line']) { $element.branch_body_end_line } else { $null })
  Add-RefinementProperty -Object $element -Name 'enclosed_element_count' -Value $(if ($element.PSObject.Properties['enclosed_element_count']) { $element.enclosed_element_count } else { 0 })

  if ($element.kind -eq 'else') {
    $counts.fallback_branches++
    Add-RefinementProperty -Object $element -Name 'classification' -Value 'alternative-fallback-branch'
    Add-RefinementProperty -Object $element -Name 'checkability' -Value 'informational-excluded'
    Add-RefinementProperty -Object $element -Name 'refinement_status' -Value 'fallback-branch'
    continue
  }

  if ($element.kind -notin @('if', 'elseif')) {
    $counts.named_elements++
    continue
  }

  $cache = $sourceCache[$element.source_file]
  $parentIfLine = if ($element.PSObject.Properties['parent_if_line']) { [int]$element.parent_if_line } else { [int]$element.line }
  $ifAst = Resolve-IfAst -Cache $cache -BaselineLine $parentIfLine -ConditionText ([string]$element.branch_condition)
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

  $conditionText = [string]$element.branch_condition
  $referencedParameters = @($parameterNames | Where-Object {
      $conditionText -match ('(?i)\$' + [regex]::Escape($_) + '(?![A-Za-z0-9_])')
    })

  if ($isPublicScope -and $referencedParameters.Count -gt 0) {
    if (Test-ParameterPresenceSafetyNet -ConditionText $conditionText -ParameterNames $referencedParameters) {
      Add-RefinementProperty -Object $element -Name 'classification' -Value 'parameter-presence-safety-net'
      Add-RefinementProperty -Object $element -Name 'checkability' -Value 'informational-excluded'
      Add-RefinementProperty -Object $element -Name 'refinement_status' -Value 'parameter-presence-safety-net'
      Add-RefinementProperty -Object $element -Name 'public_parameters' -Value $referencedParameters
      continue
    }
    $counts.public_parameter_gates++
    $declarationLine = if ($null -ne $function) { $function.Extent.StartLineNumber } else { $cache.ast.ParamBlock.Extent.StartLineNumber }
    $helpEvidence = @()
    foreach ($parameterName in $referencedParameters) {
      $helpMatch = Find-HelpParameterDocumentation -ParameterName $parameterName -SourcePath $element.source_file -DeclarationLine $declarationLine
      if ($null -ne $helpMatch) {
        $helpEvidence += $helpMatch
      }
    }

    $allEvidence = @($helpEvidence)
    if ($allEvidence.Count -eq 0) {
      foreach ($check in @('check1', 'check2', 'check3', 'check4')) {
        foreach ($parameterName in $referencedParameters) {
          $allEvidence += Find-ParameterDocumentation -ParameterName $parameterName -RepositoryRoot (Split-Path $element.source_file -Parent | Split-Path -Parent) -Check $check
        }
        if (@($allEvidence | Where-Object { $_.check -eq $check }).Count -gt 0) {
          break
        }
      }
    }
    $status = if ($allEvidence.Count -gt 0) { 'parameter-gate-documented' } else { 'parameter-gate-not-found' }
    if ($status -eq 'parameter-gate-documented') { $counts.documented_parameter_gates++ } else { $counts.undocumented_parameter_gates++ }
    Add-RefinementProperty -Object $element -Name 'classification' -Value 'public-parameter-gate'
    Add-RefinementProperty -Object $element -Name 'checkability' -Value 'documentation-traceable'
    Add-RefinementProperty -Object $element -Name 'refinement_status' -Value $status
    Add-RefinementProperty -Object $element -Name 'public_parameters' -Value $referencedParameters
    Add-RefinementProperty -Object $element -Name 'help_evidence' -Value @($helpEvidence)
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
  matching = 'Deterministic public-parameter reference detection across if and elseif conditions, explicit else fallback retention, and literal parameter-name documentation evidence. Design comments are retained for semantic review; internal control flow and fallback branches are excluded from top-level documentation completeness.'
  source_scope = $baseline.source_scope
  open_proposals = $baseline.open_proposals
  step0_rule_baseline = $baseline.step0_rule_baseline
  parse_limitations = @($parseLimitations)
  refinement_summary = $counts
  powershell_parameter_help_summary = [ordered]@{
    public_parameters = $parameterHelpRecords.Count
    help_documented = @($parameterHelpRecords | Where-Object { $_.help_documented }).Count
    help_missing = @($parameterHelpRecords | Where-Object { -not $_.help_documented }).Count
    records = @($parameterHelpRecords)
  }
  elements = @($analysisElements)
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
