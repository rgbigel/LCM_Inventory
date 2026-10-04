<#
.SYNOPSIS
  Internal runner for Update-Gemini pipeline.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Forces full clean export of knowledge base files')]
  [switch]$Force,

  [Parameter(Mandatory = $false, HelpMessage = 'Copies the consolidated governance rules to clipboard')]
  [Alias('c', 'CopyToClipboard')]
  [switch]$ToClipboard,

  [Alias('h', '?')]
  [switch]$Help
)
& "$PSScriptRoot\..\..\..\LCM_AI\tools\Update-Gemini.ps1" @PSBoundParameters
