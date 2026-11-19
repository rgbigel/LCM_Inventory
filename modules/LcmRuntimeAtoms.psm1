<#
.SYNOPSIS
  Runtime atoms: resolve an interpreter path from the registry table runtimes in tools.db.
.DESCRIPTION
  Module: LcmRuntimeAtoms
  Purpose: The one way PowerShell code obtains the executable that runs LCM Python code (RULE-PY-010).
  Path: LCM_Inventory/modules/LcmRuntimeAtoms.psm1
  Authors: Rolf, Claude (Anthropic)
  Version: 10.7.5
  Date: 2026-11-19

  Implementation Choices (CRP-366):
  - PowerShell has no SQLite driver here, so the table is read by tools/Get-LcmRuntime.py. The interpreter that runs
    this reader is a bootstrap only (python or py on PATH): the answer comes from the table and is the same whichever
    Python reads it.
  - Results are cached per session; an unknown key or a missing executable throws, there is no silent fallback.
.NOTES
  Caveats: needs at least one Python on PATH for the bootstrap read. No elevation required.
#>

Set-StrictMode -Version Latest

$script:LcmRuntimeCache = @{}

function Get-LcmRuntimePath {
  <#
  .SYNOPSIS
    Returns the registered executable path for a runtime key (default 'python').
  #>
  [CmdletBinding()]
  param([string]$Key = 'python')
  if ($script:LcmRuntimeCache.ContainsKey($Key)) { return $script:LcmRuntimeCache[$Key] }
  $resolver = Join-Path $PSScriptRoot '..\tools\Get-LcmRuntime.py'
  $bootstrap = @(Get-Command -Name 'python', 'py' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
  if (0 -eq $bootstrap.Count) { throw 'Get-LcmRuntimePath: no Python on PATH to read the runtimes table of tools.db.' }
  $output = @(& $bootstrap[0] -I $resolver 'get' $Key 2>$null)
  $exitCode = $LASTEXITCODE
  if (0 -ne $exitCode -or 0 -eq $output.Count) {
    throw ('Get-LcmRuntimePath: runtime {0} is not usable (Get-LcmRuntime.py exit {1}).' -f $Key, $exitCode)
  }
  $path = ([string]$output[-1]).Trim()
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Get-LcmRuntimePath: registered executable missing: {0}' -f $path) }
  $script:LcmRuntimeCache[$Key] = $path
  return $path
}

Export-ModuleMember -Function Get-LcmRuntimePath
