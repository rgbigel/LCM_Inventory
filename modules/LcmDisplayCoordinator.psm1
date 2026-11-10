<#
.SYNOPSIS
  Coordinates nonblocking standard display generation and verified publication.
.NOTES
  Module: LcmDisplayCoordinator
  Purpose: Publish only completed and validated display revisions without blocking rendering.
  Path: modules/LcmDisplayCoordinator.psm1
  Authors: Rolf, Copilot
  Version: 10.2.1
  Date: 2026-10-21
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'LcmDisplayDependencies.psm1')
$script:Displays = @{}

function Get-LcmDisplayPayload {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Html)
  $payload = [regex]::Match($Html, '(?is)<script\b(?=[^>]*\bid=["'']lcm-display-data["''])(?=[^>]*\btype=["'']application/json["''])[^>]*>(?<data>.*?)</script>')
  if (-not $payload.Success) { throw 'Rendered display has no structured data payload.' }
  $value = $payload.Groups['data'].Value | ConvertFrom-Json -AsHashtable -ErrorAction Stop
  if ($value -isnot [Collections.IDictionary]) { throw 'Rendered display payload must be a JSON object.' }
  return $payload.Groups['data'].Value
}

function Get-LcmDisplayState {
  [CmdletBinding()]
  param([string]$DisplayId, [string]$WorkspaceRoot = 'D:\Git_Repositories')
  if (-not $script:Displays.ContainsKey($DisplayId)) {
    $definitions = Get-LcmDisplayDefinitions -WorkspaceRoot $WorkspaceRoot
    if (-not $definitions.ContainsKey($DisplayId)) { throw "Unknown standard display: $DisplayId" }
    $script:Displays[$DisplayId] = @{
      Id = $DisplayId; Definition = $definitions[$DisplayId]; State = 'Stale'
      Revision = ''; DataRevision = ''; PresentationRevision = ''; Error = ''
      Job = $null; Bytes = $null; CheckedAt = [datetime]::MinValue; Requested = $true
      DataInput = ''; PresentationInput = ''; StartedInput = ''; StartedPresentation = ''
      OperationId = ''; LogPath = ''; PublishedAt = ''
      FailedInput = ''
      StartedAt = [datetime]::MinValue
    }
  }
  return $script:Displays[$DisplayId]
}

function Update-LcmDisplayPublication {
  [CmdletBinding()]
  param([string]$DisplayId, [switch]$Refresh, [string]$WorkspaceRoot = 'D:\Git_Repositories')
  $state = Get-LcmDisplayState -DisplayId $DisplayId -WorkspaceRoot $WorkspaceRoot
  if ($Refresh) { $state.Requested = $true }
  if ($null -ne $state.Job -and -not $state.Job.HasExited -and ([datetime]::UtcNow - $state.StartedAt).TotalSeconds -gt 120) {
    $state.Job.Kill($true)
    $state.Job.WaitForExit()
    $state.Job.Dispose(); $state.Job = $null
    $state.State = 'Failed'; $state.Error = "Renderer exceeded 120 seconds. Log: $($state.LogPath)"
    $state.FailedInput = "$($state.DataInput).$($state.PresentationInput)"; $state.Requested = $false
    return $state
  }
  if ($Refresh -or ([datetime]::UtcNow - $state.CheckedAt).TotalSeconds -ge 2) {
    $state.DataInput = Get-LcmDisplayFingerprint -Paths $state.Definition.Data
    $state.PresentationInput = Get-LcmDisplayFingerprint -Paths $state.Definition.Presentation
    $state.CheckedAt = [datetime]::UtcNow
  }
  if ($null -ne $state.Job -and $state.Job.HasExited) {
    $exitCode = $state.Job.ExitCode
    $state.Job.Dispose()
    $state.Job = $null
    if ($exitCode -ne 0) {
      $state.State = 'Failed'
      $state.Error = "Renderer exited with code $exitCode. Log: $($state.LogPath)"
      $state.Requested = $false; $state.FailedInput = "$($state.DataInput).$($state.PresentationInput)"
      return $state
    }
    # Recheck after completion: never label an obsolete input revision as current.
    $dataNow = Get-LcmDisplayFingerprint -Paths $state.Definition.Data
    $presentationNow = Get-LcmDisplayFingerprint -Paths $state.Definition.Presentation
    $sourceNow = Get-LcmDisplayFingerprint -Paths $state.Definition.Source
    $artifact = $state.Definition.Artifact
    if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
      $state.State = 'Failed'; $state.Error = "Renderer did not produce $artifact"
      $state.FailedInput = "$($state.DataInput).$($state.PresentationInput)"; $state.Requested = $false
      return $state
    }
    $html = [IO.File]::ReadAllText($artifact)
    if ($html -notmatch '(?i)<html\b' -or $html -match '(?i)(?:src|href)\s*=\s*["'']file:') {
      $state.State = 'Failed'; $state.Error = 'Rendered page is invalid or contains browser-facing file URLs.'
      $state.FailedInput = "$($state.DataInput).$($state.PresentationInput)"; $state.Requested = $false
      return $state
    }
    try { $null = Get-LcmDisplayPayload -Html $html } catch {
      $state.State = 'Failed'; $state.Error = "Invalid rendered data: $($_.Exception.Message)"
      $state.FailedInput = "$($state.DataInput).$($state.PresentationInput)"; $state.Requested = $false
      return $state
    }
    if ($presentationNow -ne $state.StartedPresentation -or $sourceNow -ne $state.StartedInput) {
      $state.Requested = $true
    } else {
      $state.Bytes = [Text.UTF8Encoding]::new($false).GetBytes($html)
      $state.DataRevision = $dataNow
      $state.PresentationRevision = $presentationNow
      $state.Revision = "$dataNow.$presentationNow"
      $state.PublishedAt = [datetime]::UtcNow.ToString('o')
      $state.State = 'Current'; $state.Error = ''; $state.Requested = $false
    }
    $state.DataInput = $dataNow; $state.PresentationInput = $presentationNow
  }
  $changed = $state.DataRevision -ne $state.DataInput -or $state.PresentationRevision -ne $state.PresentationInput
  $newInput = "$($state.DataInput).$($state.PresentationInput)" -ne $state.FailedInput
  if ($null -eq $state.Job -and ($state.Requested -or ($changed -and ($state.State -ne 'Failed' -or $newInput)))) {
    $state.OperationId = [guid]::NewGuid().ToString('N')
    $logDir = Join-Path $WorkspaceRoot 'LCM_Inventory\data\logs\lcm\displays'
    $null = [IO.Directory]::CreateDirectory($logDir)
    $state.LogPath = Join-Path $logDir "$DisplayId-$([datetime]::Now.ToString('yyyyMMdd_HHmmss'))-$($state.OperationId).log"
    $worker = Join-Path $WorkspaceRoot 'LCM_Inventory\tools\Invoke-LcmDisplayRender.ps1'
    $psi = [Diagnostics.ProcessStartInfo]::new('pwsh.exe')
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    foreach ($argument in @('-NoProfile','-File',$worker,'-DisplayId',$DisplayId,'-LogPath',$state.LogPath)) { $psi.ArgumentList.Add($argument) }
    $state.StartedInput = Get-LcmDisplayFingerprint -Paths $state.Definition.Source
    $state.StartedPresentation = $state.PresentationInput
    $state.Job = [Diagnostics.Process]::Start($psi)
    $state.StartedAt = [datetime]::UtcNow
    $state.State = 'Updating'; $state.Error = ''; $state.Requested = $false
  }
  return $state
}

function Get-LcmDisplayStatus {
  [CmdletBinding()]
  param([hashtable]$State)
  @{
    id = $State.Id; state = $State.State; revision = $State.Revision
    dataRevision = $State.DataRevision; presentationRevision = $State.PresentationRevision
    operationId = $State.OperationId; publishedAt = $State.PublishedAt; error = $State.Error
  }
}

function Stop-LcmDisplayPublication {
  [CmdletBinding()]
  param()
  foreach ($state in $script:Displays.Values) {
    if ($null -ne $state.Job) {
      if (-not $state.Job.HasExited) { $state.Job.Kill($true); $state.Job.WaitForExit() }
      $state.Job.Dispose(); $state.Job = $null
    }
  }
}

$ExecutionContext.SessionState.Module.OnRemove = { Stop-LcmDisplayPublication }
Export-ModuleMember -Function Get-LcmDisplayState, Update-LcmDisplayPublication, Get-LcmDisplayStatus, Stop-LcmDisplayPublication, Get-LcmDisplayPayload
