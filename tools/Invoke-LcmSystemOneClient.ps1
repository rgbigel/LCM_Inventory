<#
.SYNOPSIS
  System-1 decider client (/v1/systemone) for rapid heuristic evaluation (Stage 1).
.DESCRIPTION
  Module: tools/Invoke-LcmSystemOneClient.ps1
  Purpose: Encapsulates the /v1/systemone HTTP contract (noul, choice, score primitives).
           Checks connectivity with a strict timeout (<= 1500ms), evaluates response,
           and flags whether fallback to System-2 evaluation is required.
  Path: LCM_AI/tools/Invoke-LcmSystemOneClient.ps1
  Authors: rgbig, LCM_AI Engine
  Version: 10.2.1
  Date: 2026-11-12 08:50:00
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Path to proposal specification markdown file.')]
  [string]$ProposalPath = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Payload text if ProposalPath is omitted.')]
  [string]$PayloadText = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Minimum confidence score required to avoid fallback.')]
  [double]$ConfidenceThreshold = 0.85,

  [Parameter(Mandatory = $false, HelpMessage = 'Decider service endpoint URL. Defaults to $env:LCM_DECIDER_URL.')]
  [string]$DeciderUrl = $env:LCM_DECIDER_URL,

  [Parameter(Mandatory = $false, HelpMessage = 'Maximum request timeout in milliseconds.')]
  [int]$TimeoutMs = 1500,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host '==========================================================================' -ForegroundColor Cyan
  Write-Host ' SYSTEM-1 DECIDER CLIENT (Invoke-LcmSystemOneClient)' -ForegroundColor Green
  Write-Host '==========================================================================' -ForegroundColor Cyan
  Write-Host 'SYNOPSIS:' -ForegroundColor Yellow
  Write-Host '  Invokes the /v1/systemone endpoint (noul, choice, score primitives).'
  Write-Host ''
  Write-Host 'USAGE:' -ForegroundColor Yellow
  Write-Host '  pwsh LCM_AI/tools/Invoke-LcmSystemOneClient.ps1 [-ProposalPath <file>] [-ConfidenceThreshold 0.85] [-h]'
  Write-Host '==========================================================================' -ForegroundColor Cyan
  return
}

$timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')

# ------------------------------------------------------------------------------
# 1. Unconfigured Decider Guard
# ------------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($DeciderUrl)) {
  return [PSCustomObject]@{
    Availability     = 'Unconfigured'
    Decision         = 'None'
    Confidence       = 0.0
    RequiresFallback = $true
    LatencyMs        = 0
    RawResponse      = ''
    Reason           = 'LCM_DECIDER_URL is not configured.'
    Timestamp        = $timestamp
  }
}

# ------------------------------------------------------------------------------
# 2. Extract Context Payload
# ------------------------------------------------------------------------------
$contentToSend = $PayloadText
$proposalId = ''

if (-not [string]::IsNullOrWhiteSpace($ProposalPath) -and (Test-Path -LiteralPath $ProposalPath)) {
  $raw = Get-Content -LiteralPath $ProposalPath -Raw -Encoding UTF8
  $contentToSend = $raw
  if ($raw -match '(?m)^(?:CRP-ID|Proposal-ID|BUG-ID):\s*(.+)$') {
    $proposalId = $matches[1].Trim()
  }
}

$requestBody = @{
  proposal_id = $proposalId
  context     = if ($contentToSend.Length -gt 8192) { $contentToSend.Substring(0, 8192) } else { $contentToSend }
  intent      = 'system_one_evaluation'
  timestamp   = $timestamp
} | ConvertTo-Json -Compress

# ------------------------------------------------------------------------------
# 3. Invocation with Strict Timeout (<= 1500ms)
# ------------------------------------------------------------------------------
$cleanUrl = $DeciderUrl.TrimEnd('/') + '/v1/systemone'
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$client = $null
$responseBody = ''
$isOnline = $false
$decision = 'None'
$confidence = 0.0
$reason = ''

try {
  $handler = [System.Net.Http.SocketsHttpHandler]::new()
  $client = [System.Net.Http.HttpClient]::new($handler)
  $client.Timeout = [System.TimeSpan]::FromMilliseconds($TimeoutMs)

  $httpContent = [System.Net.Http.StringContent]::new($requestBody, [System.Text.Encoding]::UTF8, 'application/json')
  $task = $client.PostAsync($cleanUrl, $httpContent)
  $response = $task.GetAwaiter().GetResult()

  $stopwatch.Stop()
  $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

  if ($response.IsSuccessStatusCode) {
    $isOnline = $true
    $parsed = $responseBody | ConvertFrom-Json
    if ($parsed.PSObject.Properties['choice']) {
      $decision = [string]$parsed.choice
    } elseif ($parsed.PSObject.Properties['decision']) {
      $decision = [string]$parsed.decision
    }

    if ($parsed.PSObject.Properties['score']) {
      $confidence = [double]$parsed.score
    } elseif ($parsed.PSObject.Properties['confidence']) {
      $confidence = [double]$parsed.confidence
    }

    if ($parsed.PSObject.Properties['noul']) {
      $reason = [string]$parsed.noul
    } elseif ($parsed.PSObject.Properties['reason']) {
      $reason = [string]$parsed.reason
    } else {
      $reason = 'System-1 decision produced with confidence ' + $confidence.ToString('0.00')
    }
  } else {
    $reason = "HTTP $($response.StatusCode): $responseBody"
  }
} catch [System.OperationCanceledException] {
  $stopwatch.Stop()
  $reason = "Decider timeout exceeded ($($TimeoutMs)ms)."
} catch {
  $stopwatch.Stop()
  $reason = "Decider unreachable: $($_.Exception.Message)"
} finally {
  if ($null -ne $client) { $client.Dispose() }
}

$availability = if ($isOnline) { 'Online' } else { 'Offline' }
$requiresFallback = (-not $isOnline) -or ($confidence -lt $ConfidenceThreshold)

[PSCustomObject]@{
  Availability     = $availability
  Decision         = $decision
  Confidence       = [math]::Round($confidence, 4)
  RequiresFallback = $requiresFallback
  LatencyMs        = [int]$stopwatch.ElapsedMilliseconds
  RawResponse      = $responseBody
  Reason           = $reason
  Timestamp        = $timestamp
}

