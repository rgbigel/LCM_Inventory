<#
.SYNOPSIS
  Provides reusable validation for temporary PowerShell tools.
.DESCRIPTION
  Module: ToolValidation
  Purpose: Validates PowerShell syntax and repeat-run idempotence before a
           temporary tool is executed.
  Path: LCM_Inventory/modules/ToolValidation.psm1
  Authors: LCM_AI Governance
  Version: 10.0.0
  Caller Contract: Import the module and call the exported Test-* functions.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-ToolScriptSyntax {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ScriptPath
  )

  if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
    throw "Tool script was not found: $ScriptPath"
  }

  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    $ScriptPath,
    [ref]$tokens,
    [ref]$parseErrors
  )

  return [pscustomobject]@{
    ScriptPath = $ScriptPath
    IsValid    = ($parseErrors.Count -eq 0)
    Errors     = @($parseErrors | ForEach-Object { $_.Message })
  }
}

function Test-ToolIdempotence {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock]$Transform,

    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [object]$InputObject
  )

  $firstResult = & $Transform $InputObject
  $secondResult = & $Transform $firstResult
  $firstJson = $firstResult | ConvertTo-Json -Depth 20 -Compress
  $secondJson = $secondResult | ConvertTo-Json -Depth 20 -Compress

  return [pscustomobject]@{
    IsIdempotent = ($firstJson -eq $secondJson)
    FirstResult  = $firstResult
    SecondResult = $secondResult
  }
}

Export-ModuleMember -Function Test-ToolScriptSyntax, Test-ToolIdempotence