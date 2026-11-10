<#
Module: LcmDisplayVersion
Purpose: Read authoritative constructing-script and template semantic versions.
Path: modules/LcmDisplayVersion.psm1
Authors: Rolf, Copilot
Version: 10.2.1
Date: 2026-10-21
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LcmDisplaySourceVersion {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)
  $text = [IO.File]::ReadAllText($Path)
  $header = [regex]::Match($text, '(?:<#|<!--)(?<header>(?:(?!(?:#>|-->)).)*?^\s*Version:[^\r\n]*(?:(?!(?:#>|-->)).)*?)(?:#>|-->)', 'Singleline,Multiline')
  if (-not $header.Success) { throw "Missing source metadata header: $Path" }
  $semverMatches = [regex]::Matches($header.Groups['header'].Value, '(?m)^\s*Version:\s*v?(\d+\.\d+\.\d+)\s*\r?$')
  if ($semverMatches.Count -ne 1) { throw "Expected one semantic Version field in source metadata: $Path" }
  $semverMatches[0].Groups[1].Value
}

function Get-LcmDisplayProvenance {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$ScriptPath,
    [Parameter(Mandatory)][string]$TemplatePath
  )
  $tool = Get-LcmDisplaySourceVersion -Path $ScriptPath
  $template = Get-LcmDisplaySourceVersion -Path $TemplatePath
  [pscustomobject]@{
    ToolVersion = "v$tool"
    TemplateVersion = "v$template"
    Label = "LCM-Show: v$tool Template: v$template"
  }
}

Export-ModuleMember -Function Get-LcmDisplaySourceVersion, Get-LcmDisplayProvenance
