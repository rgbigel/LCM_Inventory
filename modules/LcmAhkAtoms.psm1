<#
.SYNOPSIS
  Modular automation atoms for AutoHotkey (AHK v2) execution and discovery in LCM.
.DESCRIPTION
  Module: LcmAhkAtoms
  Purpose: Provides reusable, governed automation atoms to discover the AutoHotkey v2
  runtime, locate Window Spy, execute standalone or inline AHK scripts with timeout
  safeguards, and surface structured execution results.
  Path: LCM_Inventory/modules/LcmAhkAtoms.psm1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-11-10 14:25:00
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
    Executes an AutoHotkey script file or inline code with timeout and exit-code validation.
  .PARAMETER ScriptPath
    Path to an existing .ahk script file.
  .PARAMETER InlineScript
    Inline AutoHotkey script content to execute via a temporary file.
  .PARAMETER ArgumentList
    Optional arguments passed to the AutoHotkey script.
  .PARAMETER TimeoutSeconds
    Maximum wait time in seconds before terminating the script (default: 60).
  .NOTES
    Part of LcmAhkAtoms.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string]$ScriptPath = '',

    [Parameter(Mandatory = $false)]
    [string]$InlineScript = '',

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

  $tempFile = $null
  $targetPath = $ScriptPath

  if ([string]::IsNullOrWhiteSpace($targetPath)) {
    if ([string]::IsNullOrWhiteSpace($InlineScript)) {
      throw 'Either -ScriptPath or -InlineScript must be provided to Invoke-LcmAhkScript.'
    }
    $tempFile = Join-Path $env:TEMP ('lcm_ahk_{0}.ahk' -f [guid]::NewGuid().ToString('N'))
    Set-Content -LiteralPath $tempFile -Value $InlineScript -Encoding utf8
    $targetPath = $tempFile
  } elseif (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
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

    $startInfo = @{
      FilePath               = $ahkPath
      ArgumentList           = @($execArgs)
      PassThru               = $true
      RedirectStandardOutput = $outTemp
      RedirectStandardError  = $errTemp
    }

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
    $stderr = if (Test-Path -LiteralPath $errTemp) { Get-Content -LiteralPath $errTemp -Raw -ErrorAction SilentlyContinue } else { '' }

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
    if ($null -ne $tempFile -and (Test-Path -LiteralPath $tempFile)) {
      Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $outTemp) {
      Remove-Item -LiteralPath $outTemp -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $errTemp) {
      Remove-Item -LiteralPath $errTemp -Force -ErrorAction SilentlyContinue
    }
  }
}

Export-ModuleMember -Function @(
  'Get-LcmAhkPath',
  'Test-LcmAhkAvailable',
  'Get-LcmWindowSpyPath',
  'Start-LcmWindowSpy',
  'Invoke-LcmAhkScript'
)

