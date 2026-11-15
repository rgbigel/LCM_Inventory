<#
.SYNOPSIS
  Exports the active Antigravity session as a normalized reasoning-analysis JSONL transcript.
.DESCRIPTION
  Reads only the session selected by ANTIGRAVITY_CONVERSATION_ID (or an explicit SessionId or DatabasePath).
  It exports user messages, assistant messages, and tool-call metadata into the reasoning-analysis event contract:
    id, timestamp, role, type, content, tool_name, arguments or tool-call metadata.
  It never reads another session or an inactive IDE host.
.PARAMETER SessionId
  Active Antigravity conversation identifier. Defaults to ANTIGRAVITY_CONVERSATION_ID.
.PARAMETER OutputPath
  Normalized JSONL destination.
.PARAMETER DatabasePath
  Test-only or explicit override for an Antigravity SQLite database path or JSON/JSONL event file.
.PARAMETER EventLogPath
  Alias for DatabasePath.
#>
[CmdletBinding()]
param(
  [string]$SessionId = $env:ANTIGRAVITY_CONVERSATION_ID,
  [Parameter(Mandatory = $true)]
  [string]$OutputPath,
  [Alias('EventLogPath')]
  [string]$DatabasePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($DatabasePath)) {
  if ([string]::IsNullOrWhiteSpace($SessionId)) {
    throw 'ANTIGRAVITY_CONVERSATION_ID is required for -Auto. Run this command only in an active Antigravity session.'
  }
  $antigravityHome = if ([string]::IsNullOrWhiteSpace($env:ANTIGRAVITY_HOME)) {
    Join-Path $env:USERPROFILE '.gemini\antigravity-ide'
  } else {
    $env:ANTIGRAVITY_HOME
  }
  $DatabasePath = Join-Path $antigravityHome "conversations\$SessionId.db"
}

if (-not (Test-Path -LiteralPath $DatabasePath -PathType Leaf)) {
  throw "Active Antigravity session database was not found: $DatabasePath"
}

$outputDirectory = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
  New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$ext = [System.IO.Path]::GetExtension($DatabasePath).ToLowerInvariant()

if ($ext -eq '.jsonl' -or $ext -eq '.json') {
  $raw = Get-Content -LiteralPath $DatabasePath -Raw -Encoding UTF8
  $writer = [System.IO.StreamWriter]::new($OutputPath, $false, [System.Text.UTF8Encoding]::new($false))
  try {
    $writer.NewLine = "`n"
    $events = @()
    if ($ext -eq '.jsonl') {
      foreach ($line in ($raw -split "`r?`n")) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
          $events += $line | ConvertFrom-Json -ErrorAction Stop
        }
      }
    } else {
      $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
      if ($parsed -is [System.Collections.IEnumerable]) {
        $events = @($parsed)
      } else {
        $events = @($parsed.events)
      }
    }

    $idx = 0
    foreach ($item in $events) {
      $idx++
      $id = if ($item.PSObject.Properties['id']) { [string]$item.id } else { "event-$idx" }
      $timestamp = if ($item.PSObject.Properties['timestamp']) { [string]$item.timestamp } else { (Get-Date -Format 'o') }
      $role = if ($item.PSObject.Properties['role']) { [string]$item.role } elseif ($item.PSObject.Properties['source'] -eq 'USER_EXPLICIT') { 'user' } else { 'assistant' }
      $type = if ($item.PSObject.Properties['type']) { [string]$item.type } else { 'message' }
      $content = if ($item.PSObject.Properties['content']) { [string]$item.content } elseif ($item.PSObject.Properties['text']) { [string]$item.text } else { '' }
      $toolName = if ($item.PSObject.Properties['tool_name']) { [string]$item.tool_name } else { $null }
      $arguments = if ($item.PSObject.Properties['arguments']) { $item.arguments } else { $null }

      $normalized = [ordered]@{
        id = $id
        timestamp = $timestamp
        role = $role
        type = $type
        content = $content
      }
      if ($null -ne $toolName) {
        $normalized['tool_name'] = $toolName
      }
      if ($null -ne $arguments) {
        $normalized['arguments'] = $arguments
      }
      $writer.WriteLine(($normalized | ConvertTo-Json -Depth 20 -Compress))
    }
  } finally {
    $writer.Dispose()
  }
} else {
  $pythonExe = if (Test-Path 'D:\Tools\Python314\python.exe') { 'D:\Tools\Python314\python.exe' } else { 'python.exe' }
  $extractorPy = Join-Path $PSScriptRoot 'Export-AntigravityExtractor.py'
  if (-not (Test-Path -LiteralPath $extractorPy -PathType Leaf)) {
    throw "Antigravity SQLite extractor was not found: $extractorPy"
  }
  & $pythonExe $extractorPy $DatabasePath $OutputPath
  if ($LASTEXITCODE -ne 0) {
    throw "Antigravity transcript extraction failed with exit code $LASTEXITCODE"
  }
}

if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
  throw "Antigravity transcript export was not created: $OutputPath"
}
