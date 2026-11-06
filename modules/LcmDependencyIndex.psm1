<#
.SYNOPSIS
  Extracts static LCM dependency evidence and reverse caller indexes.
.DESCRIPTION
  Module: LcmDependencyIndex
  Purpose: Implements the data-first phases of CRP-121 by extracting forward
           WIUD call evidence and inverting accepted production edges into WUD data.
  Path: modules/LcmDependencyIndex.psm1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.1
  Date: 2026-10-18
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LcmDependencySourceFiles {
  [CmdletBinding()]
  param(
    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $sourceRoots = @(
    (Join-Path $WorkspaceRoot 'LCM_Inventory\modules'),
    (Join-Path $WorkspaceRoot 'LCM_Inventory\tools'),
    (Join-Path $WorkspaceRoot 'LCM_Inventory\Cmd'),
    (Join-Path $WorkspaceRoot 'LCM_Inventory\assets'),
    (Join-Path $WorkspaceRoot 'LCM_Inventory\.githooks'),
    (Join-Path $WorkspaceRoot 'LCM_AI\modules'),
    (Join-Path $WorkspaceRoot 'LCM_AI\tools'),
    (Join-Path $WorkspaceRoot 'LCM_AI\.agents'),
    (Join-Path $WorkspaceRoot 'LCM_Shared\modules'),
    (Join-Path $WorkspaceRoot 'LCM_Shared\tools'),
    (Join-Path $WorkspaceRoot 'LCM_Supervision\modules'),
    (Join-Path $WorkspaceRoot 'LCM_Supervision\tools'),
    (Join-Path $WorkspaceRoot 'LCM_Supervision\tasks'),
    (Join-Path $WorkspaceRoot 'LCM_Supervision\assets'),
    (Join-Path $WorkspaceRoot 'LCM_Tools\modules'),
    (Join-Path $WorkspaceRoot 'LCM_Tools\tools')
  )

  return @($sourceRoots | Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
      ForEach-Object {
        Get-ChildItem -LiteralPath $_ -File -Recurse -Include '*.ps1', '*.psm1', '*.cmd', '*.bat', '*.html', '*.htm'
      } | Sort-Object FullName -Unique)
}

function Get-LcmDependencySourceClass {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $normalized = $Path.Replace('/', '\')
  if ($normalized -match '(?i)\\(tests?|fixtures?)\\' -or $normalized -match '(?i)\.Tests\.ps1$') {
    return 'test'
  }
  if ($normalized -match '(?i)\\(scratch|artifacts|temp|tmp|session-state|history)\\') {
    return 'temporary'
  }
  if ($normalized -match '(?i)(generated|\.g\.ps1)$') {
    return 'generated'
  }
  return 'production'
}

function Get-LcmDependencyCaller {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.Management.Automation.Language.Ast]$Node,
    [Parameter(Mandatory = $true)]
    [string]$Fallback
  )

  $current = $Node.Parent
  while ($null -ne $current) {
    if ($current -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
      return $current.Name
    }
    $current = $current.Parent
  }
  return $Fallback
}

function Get-LcmDependencySymbols {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.IO.FileInfo[]]$SourceFiles
  )

  $symbols = @()
  foreach ($file in $SourceFiles | Where-Object { $_.Extension -in @('.ps1', '.psm1') }) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    foreach ($function in @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
      $symbols += [pscustomobject]@{
        name = $function.Name
        source_file = $file.FullName
        line = $function.Extent.StartLineNumber
        kind = 'function'
        source_classification = Get-LcmDependencySourceClass -Path $file.FullName
      }
    }
    $symbols += [pscustomobject]@{
      name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
      source_file = $file.FullName
      line = 1
      kind = 'script-entrypoint'
      source_classification = Get-LcmDependencySourceClass -Path $file.FullName
    }
  }
  return @($symbols)
}

function New-LcmDependencyEdge {
  [CmdletBinding()]
  param(
    [string]$SourceFile,
    [int]$Line,
    [string]$Caller,
    [string]$Target,
    [string]$InvocationType,
    [string]$Arguments,
    [string]$SourceClassification,
    [string]$Resolution
  )

  return [pscustomobject]@{
    caller_file = $SourceFile
    caller_line = $Line
    caller_symbol = $Caller
    callee_target = $Target
    invocation_type = $InvocationType
    supplied_arguments = $Arguments
    source_classification = $SourceClassification
    resolution = $Resolution
  }
}

function Get-LcmPowerShellDependencyEdges {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.IO.FileInfo]$SourceFile,
    [Parameter(Mandatory = $true)]
    [hashtable]$KnownNameCounts
  )

  $tokens = $null
  $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($SourceFile.FullName, [ref]$tokens, [ref]$errors)
  $classification = Get-LcmDependencySourceClass -Path $SourceFile.FullName
  $fallback = [System.IO.Path]::GetFileNameWithoutExtension($SourceFile.Name)
  $edges = @()
  foreach ($command in @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))) {
    $commandName = $command.GetCommandName()
    $text = $command.Extent.Text.Trim()
    $target = $commandName
    $invocationType = 'powershell-command'
    if ([string]::IsNullOrWhiteSpace($target)) {
      $target = $text
      $invocationType = 'dynamic-unresolved'
    } elseif ($commandName -in @('Import-Module', 'ipmo')) {
      $target = (@($command.CommandElements | Select-Object -Skip 1 | Where-Object { $_.Extent.Text -notmatch '^-' } | Select-Object -First 1).Extent.Text).Trim('"', "'")
      $invocationType = 'module-import'
    } elseif ($commandName -in @('pwsh', 'powershell', 'powershell.exe', 'pwsh.exe') -and $text -match '(?i)-File\s+([^\s]+)') {
      $target = $Matches[1].Trim('"', "'")
      $invocationType = 'script-host'
    } elseif ($command.InvocationOperator -ne [System.Management.Automation.Language.TokenKind]::Unknown) {
      $invocationType = 'script-invocation'
    }

    if ([string]::IsNullOrWhiteSpace($target)) {
      continue
    }
    $targetName = [System.IO.Path]::GetFileNameWithoutExtension($target)
    $resolution = if ($KnownNameCounts.ContainsKey($targetName) -and $KnownNameCounts[$targetName] -eq 1) { 'resolved' } elseif ($KnownNameCounts.ContainsKey($targetName)) { 'ambiguous-symbol' } elseif ($invocationType -eq 'dynamic-unresolved') { 'dynamic-unresolved' } else { 'external-or-unresolved' }
    $edges += New-LcmDependencyEdge -SourceFile $SourceFile.FullName -Line $command.Extent.StartLineNumber -Caller (Get-LcmDependencyCaller -Node $command -Fallback $fallback) -Target $target -InvocationType $invocationType -Arguments $text -SourceClassification $classification -Resolution $resolution
  }
  return @($edges)
}

function Get-LcmTextDependencyEdges {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.IO.FileInfo]$SourceFile,
    [Parameter(Mandatory = $true)]
    [hashtable]$KnownNameCounts
  )

  $classification = Get-LcmDependencySourceClass -Path $SourceFile.FullName
  $fallback = [System.IO.Path]::GetFileNameWithoutExtension($SourceFile.Name)
  $edges = @()
  $lineNumber = 0
  foreach ($line in Get-Content -LiteralPath $SourceFile.FullName -Encoding utf8) {
    $lineNumber++
    $regexMatches = @()
    if ($SourceFile.Extension -in @('.cmd', '.bat')) {
      $regexMatches += [regex]::Matches($line, '(?i)(?:call\s+)?([A-Za-z0-9_.-]+\.ps1|[A-Za-z0-9_.-]+\.cmd)')
    } else {
      $regexMatches += [regex]::Matches($line, '(?i)(?:data-(?:action|command)|href)\s*=\s*["'']([^"''#]+)')
      $regexMatches += [regex]::Matches($line, '(?i)127\.0\.0\.1:9876/([A-Za-z0-9_./-]+)')
    }
    foreach ($match in $regexMatches) {
      $target = if ($match.Groups.Count -gt 1) { $match.Groups[1].Value } else { $match.Value }
      if ([string]::IsNullOrWhiteSpace($target)) { continue }
      $name = [System.IO.Path]::GetFileNameWithoutExtension($target)
      $resolution = if ($KnownNameCounts.ContainsKey($name) -and $KnownNameCounts[$name] -eq 1) { 'resolved' } elseif ($KnownNameCounts.ContainsKey($name)) { 'ambiguous-symbol' } else { 'external-or-unresolved' }
      $type = if ($SourceFile.Extension -in @('.cmd', '.bat')) { 'cmd-wrapper' } else { 'dashboard-or-daemon' }
      $edges += New-LcmDependencyEdge -SourceFile $SourceFile.FullName -Line $lineNumber -Caller $fallback -Target $target -InvocationType $type -Arguments $line.Trim() -SourceClassification $classification -Resolution $resolution
    }
  }
  return @($edges)
}

function New-LcmForwardDependencyIndex {
  [CmdletBinding()]
  param(
    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $sourceFiles = Get-LcmDependencySourceFiles -WorkspaceRoot $WorkspaceRoot
  $symbols = Get-LcmDependencySymbols -SourceFiles $sourceFiles
  $knownNameCounts = @{}
  foreach ($group in @($symbols | Group-Object name)) {
    $knownNameCounts[$group.Name] = @($group.Group).Count
  }
  $edges = @()
  foreach ($sourceFile in $sourceFiles) {
    if ($sourceFile.Extension -in @('.ps1', '.psm1')) {
      $edges += Get-LcmPowerShellDependencyEdges -SourceFile $sourceFile -KnownNameCounts $knownNameCounts
    } else {
      $edges += Get-LcmTextDependencyEdges -SourceFile $sourceFile -KnownNameCounts $knownNameCounts
    }
  }
  return [ordered]@{
    schema_version = '10.0.0'
    generated_at = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
    workspace_root = $WorkspaceRoot
    symbols = @($symbols | Sort-Object name, source_file, line)
    edges = @($edges | Sort-Object caller_file, caller_line, callee_target)
  }
}

function New-LcmReverseDependencyIndex {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [psobject]$ForwardIndex
  )

  $productionEdges = @($ForwardIndex.edges | Where-Object {
      $_.source_classification -eq 'production' -and $_.resolution -eq 'resolved'
    })
  $reverse = foreach ($symbol in @($ForwardIndex.symbols | Where-Object { $_.source_classification -eq 'production' })) {
    $callers = @($productionEdges | Where-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.callee_target) -eq $symbol.name })
    [pscustomobject]@{
      callee_name = $symbol.name
      callee_file = $symbol.source_file
      callee_line = $symbol.line
      callee_kind = $symbol.kind
      production_callers = $callers
      classification = if ($symbol.kind -eq 'script-entrypoint') { 'entrypoint' } elseif ($callers.Count -eq 0) { 'candidate-dead-code' } else { 'referenced' }
    }
  }
  return [ordered]@{
    schema_version = '10.0.0'
    generated_at = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
    forward_generated_at = $ForwardIndex.generated_at
    reverse_entries = @($reverse | Sort-Object callee_name, callee_file, callee_line)
    excluded_edge_counts = [ordered]@{
      test = @($ForwardIndex.edges | Where-Object { $_.source_classification -eq 'test' }).Count
      temporary = @($ForwardIndex.edges | Where-Object { $_.source_classification -eq 'temporary' }).Count
      generated = @($ForwardIndex.edges | Where-Object { $_.source_classification -eq 'generated' }).Count
      unresolved = @($ForwardIndex.edges | Where-Object { $_.resolution -ne 'resolved' }).Count
    }
  }
}

Export-ModuleMember -Function Get-LcmDependencySourceFiles, New-LcmForwardDependencyIndex, New-LcmReverseDependencyIndex
