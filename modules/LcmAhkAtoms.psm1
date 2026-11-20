<#
.SYNOPSIS
  Modular automation atoms for AutoHotkey (AHK v2) execution and discovery in LCM.
.DESCRIPTION
  Module: LcmAhkAtoms
  Purpose: Provides reusable, governed automation atoms to discover the AutoHotkey v2
  runtime, locate Window Spy, execute registered AHK atoms with timeout safeguards,
  and surface structured execution results.
  Path: LCM_Inventory/modules/LcmAhkAtoms.psm1
  Authors: Rolf, LCM_AI Engine, Claude
  Version: 10.2.2
  Date: 2026-11-20
  Implementation Choices (CRP-345): AHK runs only as registered atoms. Invoke-LcmAhkAtom resolves
  the intent in the tool store (tools.db table tool_intents, CRP-358; executable AutoHotkey64.exe, script *.ahk) and refuses
  anything else with a log line; it also refuses an intent whose elevated flag differs from the
  caller's elevation (CRP-343 border rule: change elevation only through the DO). Inline AHK code
  is no longer accepted, and the file runner Invoke-LcmAhkScript is module-internal.
  Implementation Choices (CRP-358): the intents come from Get-LcmToolStoreDocument (modules/LcmToolCatalog.psm1);
  -Registry / -WorkspaceRoot replace -IntentsPath (tests pass an isolated registry, never a JSON file).
.NOTES
  Part of BUG-313 / LCM UI Automation Architecture.
#>

Set-StrictMode -Version Latest

function Get-LcmAhkPath {
  <#
  .SYNOPSIS
    Discovers the AutoHotkey v2 64-bit executable path.
  .DESCRIPTION
    Probes environment overrides, well-known system tool locations in D:\Tools,
    and falls back to Search-Everything.ps1 or PATH discovery.
  .NOTES
    Part of LcmAhkAtoms.
  #>
  [CmdletBinding()]
  param()

  if (-not [string]::IsNullOrWhiteSpace($env:LCM_AHK_PATH) -and (Test-Path -LiteralPath $env:LCM_AHK_PATH -PathType Leaf)) {
    return $env:LCM_AHK_PATH
  }

  $candidates = @(
    'D:\Tools\AutoHotkey\v2\AutoHotkey64.exe',
    'D:\Tools\AutoHotkey.AutoHotkey\v2\AutoHotkey64.exe',
    'D:\Tools\AutoHotkey\AutoHotkey64.exe',
    'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe',
    'C:\Program Files\AutoHotkey\AutoHotkey64.exe'
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }

  $cmd = Get-Command -Name 'AutoHotkey64.exe', 'AutoHotkey.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
    return $cmd.Source
  }

  $moduleDir = $PSScriptRoot
  $inventoryRoot = Split-Path $moduleDir -Parent
  $searchScript = Join-Path $inventoryRoot 'tools\Search-Everything.ps1'
  if (Test-Path -LiteralPath $searchScript -PathType Leaf) {
    try {
      $results = @(& $searchScript -Query 'AutoHotkey64.exe' -Path 'D:\Tools' -MaxResults 5)
      foreach ($item in $results) {
        if ($null -ne $item -and (Test-Path -LiteralPath $item.FullName -PathType Leaf)) {
          return $item.FullName
        }
      }
    } catch {
      # Non-critical fallback
    }
  }

  return $null
}

function Test-LcmAhkAvailable {
  <#
  .SYNOPSIS
    Returns true if AutoHotkey v2 is installed and reachable.
  .NOTES
    Part of LcmAhkAtoms.
  #>
  [CmdletBinding()]
  param()

  $ahkPath = Get-LcmAhkPath
  return ($null -ne $ahkPath -and (Test-Path -LiteralPath $ahkPath -PathType Leaf))
}

function Get-LcmWindowSpyPath {
  <#
  .SYNOPSIS
    Discovers the AutoHotkey Window Spy utility path.
  .NOTES
    Part of LcmAhkAtoms.
  #>
  [CmdletBinding()]
  param()

  $candidates = @(
    'D:\Tools\AutoHotkey\UX\WindowSpy.ahk',
    'D:\Tools\AutoHotkey.AutoHotkey\UX\WindowSpy.ahk',
    'D:\Tools\AutoHotkey\WindowSpy.ahk',
    'C:\Program Files\AutoHotkey\UX\WindowSpy.ahk'
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }

  return $null
}

function Start-LcmWindowSpy {
  <#
  .SYNOPSIS
    Launches AutoHotkey Window Spy on the interactive desktop.
  .NOTES
    Part of LcmAhkAtoms.
  #>
  [CmdletBinding()]
  param()

  $ahkPath = Get-LcmAhkPath
  if ($null -eq $ahkPath) {
    throw 'AutoHotkey executable was not found. Cannot launch Window Spy.'
  }

  $spyPath = Get-LcmWindowSpyPath
  if ($null -eq $spyPath) {
    throw 'WindowSpy.ahk was not found.'
  }

  $process = Start-Process -FilePath $ahkPath -ArgumentList @($spyPath) -PassThru
  return [pscustomobject]@{
    Launched = $true
    ProcessId = $process.Id
    Executable = $ahkPath
    Script = $spyPath
  }
}

function Invoke-LcmAhkScript {
  <#
  .SYNOPSIS
    Executes an AutoHotkey script file with timeout and exit-code validation (module-internal; CRP-345).
  .PARAMETER ScriptPath
    Path to an existing .ahk script file of a registered atom.
  .PARAMETER ArgumentList
    Optional arguments passed to the AutoHotkey script.
  .PARAMETER TimeoutSeconds
    Maximum wait time in seconds before terminating the script (default: 60).
  .NOTES
    Part of LcmAhkAtoms.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,

    [Parameter(Mandatory = $false)]
    [string[]]$ArgumentList = @(),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 600)]
    [int]$TimeoutSeconds = 60
  )

  $ahkPath = Get-LcmAhkPath
  if ($null -eq $ahkPath) {
    throw 'AutoHotkey executable was not found. Cannot execute AHK automation.'
  }

  $targetPath = $ScriptPath
  if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
    throw "The specified AutoHotkey script file was not found: $targetPath"
  }

  try {
    $execArgs = [System.Collections.Generic.List[string]]::new()
    $execArgs.Add($targetPath)
    if ($null -ne $ArgumentList -and $ArgumentList.Count -gt 0) {
      foreach ($arg in $ArgumentList) {
        $execArgs.Add($arg)
      }
    }

    $outTemp = Join-Path $env:TEMP ('lcm_ahk_out_{0}.txt' -f [guid]::NewGuid().ToString('N'))
    $errTemp = Join-Path $env:TEMP ('lcm_ahk_err_{0}.txt' -f [guid]::NewGuid().ToString('N'))
    # CRP-345: LCM_AHK_OUT gets its own file; sharing the stdout redirect file locked it (AHK error 32).
    $atomTemp = Join-Path $env:TEMP ('lcm_ahk_atom_{0}.txt' -f [guid]::NewGuid().ToString('N'))

    $startInfo = @{
      FilePath               = $ahkPath
      ArgumentList           = @($execArgs)
      PassThru               = $true
      RedirectStandardOutput = $outTemp
      RedirectStandardError  = $errTemp
    }

    $env:LCM_AHK_OUT = $atomTemp
    try {
      $process = Start-Process @startInfo
      $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

      while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 200
      }

      $timedOut = $false
      if (-not $process.HasExited) {
        $timedOut = $true
        try {
          Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        } catch {
          # Process may have exited during stop
        }
      }

      $exitCode = if ($timedOut) { -1 } else { $process.ExitCode }
      $stdout = if (Test-Path -LiteralPath $outTemp) { Get-Content -LiteralPath $outTemp -Raw -ErrorAction SilentlyContinue } else { '' }
      $atomOut = if (Test-Path -LiteralPath $atomTemp) { Get-Content -LiteralPath $atomTemp -Raw -ErrorAction SilentlyContinue } else { '' }
      if (-not [string]::IsNullOrWhiteSpace($atomOut)) { $stdout = ("$stdout".TrimEnd() + "`n" + $atomOut).Trim() }
      $stderr = if (Test-Path -LiteralPath $errTemp) { Get-Content -LiteralPath $errTemp -Raw -ErrorAction SilentlyContinue } else { '' }
    } finally {
      Remove-Item env:LCM_AHK_OUT -ErrorAction SilentlyContinue
    }

    if ($null -eq $stdout) { $stdout = '' }
    if ($null -eq $stderr) { $stderr = '' }

    return [pscustomobject]@{
      Succeeded  = ($exitCode -eq 0)
      ExitCode   = $exitCode
      TimedOut   = $timedOut
      Output     = $stdout.Trim()
      Error      = $stderr.Trim()
      ScriptPath = $targetPath
    }
  }
  finally {
    if (Test-Path -LiteralPath $atomTemp) {
      Remove-Item -LiteralPath $atomTemp -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $outTemp) {
      Remove-Item -LiteralPath $outTemp -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $errTemp) {
      Remove-Item -LiteralPath $errTemp -Force -ErrorAction SilentlyContinue
    }
  }
}

function Write-LcmAhkRefusal {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message
  )

  $logDir = Join-Path $PSScriptRoot '..\logs'
  if (Test-Path -LiteralPath $logDir) {
    $line = '[{0}] [WARN] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath (Join-Path $logDir ('LcmAhkAtoms-{0}.log' -f (Get-Date -Format 'yyyyMMdd'))) -Value $line -Encoding UTF8
  }
}

function Get-LcmAhkAtomIntents {
  <#
  .SYNOPSIS
    Lists the registered AHK atoms (intents with an AutoHotkey executable and an .ahk script).
  .PARAMETER Registry
    Intents document ({ intents = { key = { executable, script, elevated, goal } } }); default: the tool store.
  #>
  [CmdletBinding()]
  param(
    [object]$Registry = $null
  )

  $registry = $Registry
  if ($null -eq $registry) {
    Import-Module -Name (Join-Path $PSScriptRoot 'LcmToolCatalog.psm1')
    $registry = Get-LcmToolStoreDocument -Store intents
  }
  if ($registry -is [System.Collections.IDictionary]) { $registry = [pscustomobject]$registry }
  $intentsNode = $registry.intents
  if ($intentsNode -is [System.Collections.IDictionary]) { $intentsNode = [pscustomobject]$intentsNode }
  $registry = [pscustomobject]@{ intents = $intentsNode }
  $atoms = foreach ($property in $registry.intents.PSObject.Properties) {
    $value = $property.Value
    if ([string]$value.executable -match '(?i)autohotkey' -and [string]$value.script -match '(?i)\.ahk$') {
      [pscustomobject]@{ Intent = $property.Name; Script = [string]$value.script; Elevated = [bool]$value.elevated; Goal = [string]$value.goal }
    }
  }
  return @($atoms)
}

function Invoke-LcmAhkAtom {
  <#
  .SYNOPSIS
    Runs one registered AHK atom by its intent name (CRP-345); unregistered AHK requests are refused and logged.
  .PARAMETER Intent
    Intent key of the atom in the tool store (e.g. select-beyondcomparetab).
  .PARAMETER ArgumentList
    Arguments passed to the atom.
  .PARAMETER TimeoutSeconds
    Maximum wait time in seconds (default: 60).
  .PARAMETER Registry
    Intents document (default: the tool store).
  .PARAMETER WorkspaceRoot
    Git root the atom scripts are relative to (default: two levels above this module).
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Intent,

    [string[]]$ArgumentList = @(),

    [ValidateRange(1, 600)]
    [int]$TimeoutSeconds = 60,

    [object]$Registry = $null,

    [string]$WorkspaceRoot = (Join-Path $PSScriptRoot '..\..')
  )

  $key = $Intent.ToLowerInvariant()
  $atom = @(Get-LcmAhkAtomIntents -Registry $Registry | Where-Object { $_.Intent -eq $key }) | Select-Object -First 1
  if ($null -eq $atom) {
    Write-LcmAhkRefusal -Message "Refused AHK intent '$Intent': not a registered AHK atom (CRP-345)."
    throw "AHK intent '$Intent' is not a registered AHK atom; refused (CRP-345)."
  }

  $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
  $callerElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if ($atom.Elevated -ne $callerElevated) {
    Write-LcmAhkRefusal -Message "Refused AHK intent '$Intent': atom elevated=$($atom.Elevated), caller elevated=$callerElevated (CRP-343 border rule)."
    throw "AHK intent '$Intent' runs with elevated=$($atom.Elevated) but the caller has elevated=$callerElevated; change elevation only through the DO (CRP-343)."
  }

  $workspaceRoot = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
  $scriptPath = Join-Path $workspaceRoot $atom.Script.Replace('/', '\')
  return Invoke-LcmAhkScript -ScriptPath $scriptPath -ArgumentList $ArgumentList -TimeoutSeconds $TimeoutSeconds
}

Export-ModuleMember -Function @(
  'Get-LcmAhkPath',
  'Test-LcmAhkAvailable',
  'Get-LcmWindowSpyPath',
  'Start-LcmWindowSpy',
  'Get-LcmAhkAtomIntents',
  'Invoke-LcmAhkAtom'
)

