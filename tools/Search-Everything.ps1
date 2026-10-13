<#
.SYNOPSIS
  Instantaneous LCM file and content search powered by Everything 1.5a HTTP REST API & CLI.
.DESCRIPTION
  High-speed workspace and system-wide search tool integrating Voidtools Everything.
  Uses local HTTP REST API (http://127.0.0.1:8080) for instant sandbox-independent queries,
  with seamless fallback to es.exe CLI.
  Supports instant filename lookups, regex searches, and pre-indexed full-text content searches
  across repositories and documents without disk I/O bottlenecks.
  Adheres strictly to LCM non-mutation invariants (100% read-only, zero process mutation).
.PARAMETER Query
  Search term or pattern for filenames/paths.
.PARAMETER Content
  Search term for full-text content indexing (uses content: filter).
.PARAMETER Path
  Restrict search scope to a specific directory or drive (e.g. D:\Git_Repositories).
.PARAMETER Extension
  Filter results by file extension (e.g. ps1, md, json).
.PARAMETER Regex
  Enable regular expression matching.
.PARAMETER MaxResults
  Maximum number of search results to return (default: 50).
.PARAMETER CaseSensitive
  Enable case-sensitive search.
.PARAMETER Port
  HTTP Server port (default: 8080).
.PARAMETER Raw
  Pass raw search string directly.
.EXAMPLE
  pwsh tools/Search-Everything.ps1 -Query "AGENTS.md"
.EXAMPLE
  pwsh tools/Search-Everything.ps1 -Content "OverlayTestMode" -Path "D:\Git_Repositories"
.EXAMPLE
  pwsh tools/Search-Everything.ps1 -Query "Test-*" -Extension "ps1" -MaxResults 20
.NOTES
  Author: Rolf + Antigravity
  Date: 2026-10-13
  Version: 10.0.0
#>

[CmdletBinding(DefaultParameterSetName = 'Structured')]
param(
  [Parameter(Position = 0, ParameterSetName = 'Structured', HelpMessage = 'Search term or pattern for filenames and paths')]
  [string]$Query = '',

  [Parameter(ParameterSetName = 'Structured', HelpMessage = 'Search term for full-text content indexing (uses content: filter)')]
  [string]$Content = '',

  [Parameter(ParameterSetName = 'Structured', HelpMessage = 'Restrict search scope to a specific directory or drive (e.g. D:\Git_Repositories)')]
  [string]$Path = '',

  [Parameter(ParameterSetName = 'Structured', HelpMessage = 'Filter results by file extension (e.g. ps1, md, json)')]
  [string]$Extension = '',

  [Parameter(ParameterSetName = 'Structured', HelpMessage = 'Enable regular expression matching')]
  [switch]$Regex,

  [Parameter(ParameterSetName = 'Structured', HelpMessage = 'Maximum number of search results to return (default: 50)')]
  [int]$MaxResults = 50,

  [Parameter(ParameterSetName = 'Structured', HelpMessage = 'Enable case-sensitive search')]
  [switch]$CaseSensitive,

  [Parameter(ParameterSetName = 'Structured', HelpMessage = 'HTTP Server port for Everything 1.5a REST API (default: 8080)')]
  [int]$Port = 8080,

  [Parameter(Mandatory = $true, ParameterSetName = 'Raw', HelpMessage = 'Pass raw search query string directly to Everything')]
  [string]$Raw,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " EVERYTHING WORKSPACE SEARCH (Search-Everything)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Instantaneous file and content search powered by Everything 1.5a API."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Search-Everything.ps1 [[-Query] <str>] [-Content <str>] [-Path <str>] [-Extension <str>] [-Regex] [-MaxResults <int>] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Query         : Search term or pattern for filenames"
  Write-Host "  -Content       : Search term for full-text content indexing"
  Write-Host "  -Path          : Restrict search scope to directory or drive"
  Write-Host "  -Extension     : Filter results by file extension"
  Write-Host "  -Regex         : Enable regex matching"
  Write-Host "  -MaxResults    : Maximum search results (default: 50)"
  Write-Host "  -Raw           : Pass raw query string directly"
  Write-Host "  -Help (-h, -?) : Displays this help screen"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# Construct search query string
$searchTerms = [System.Collections.Generic.List[string]]::new()
# es.exe needs one argument per search token; content terms are grouped with <...>
$esTokens = [System.Collections.Generic.List[string]]::new()

if ($PSCmdlet.ParameterSetName -eq 'Raw') {
  $searchTerms.Add($Raw)
  $esTokens.Add($Raw)
} else {
  if ($CaseSensitive) {
    $searchTerms.Add("case:")
    $esTokens.Add("case:")
  }

  if ($Regex) {
    $searchTerms.Add("regex:")
    $esTokens.Add("regex:")
  }

  if (-not [string]::IsNullOrWhiteSpace($Path)) {
    $resolvedPath = $Path.Trim().Trim('"')
    $searchTerms.Add("path:`"$resolvedPath`"")
    $esTokens.Add($resolvedPath)
  }

  if (-not [string]::IsNullOrWhiteSpace($Extension)) {
    $ext = $Extension.Trim().TrimStart('.')
    $searchTerms.Add("ext:$ext")
    $esTokens.Add("ext:$ext")
  }

  if (-not [string]::IsNullOrWhiteSpace($Content)) {
    $searchTerms.Add("content:`"$Content`"")
    $esTokens.Add("content:<$Content>")
  }

  if (-not [string]::IsNullOrWhiteSpace($Query)) {
    $searchTerms.Add($Query)
    $esTokens.Add($Query)
  }

  if ($searchTerms.Count -eq 0) {
    Write-Warning "No query or filter specified. Please provide -Query, -Content, or -Path."
    return
  }
}

$finalQuery = $searchTerms -join ' '

# ------------------------------------------------------------------------------
# 1. Primary Transport: es.exe CLI (RULE-EFF-007). Resolved via PATH, then the
#    Requisites manifest (docs\Requisites\external-tools.json) under Machine Git_Root.
# ------------------------------------------------------------------------------
$esBin = $null
$esCmd = Get-Command -Name 'es.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($esCmd) { $esBin = $esCmd.Source }
if (-not $esBin) {
  $gitRoot = [Environment]::GetEnvironmentVariable('Git_Root', 'Machine')
  $manifest = if ($gitRoot) { Join-Path $gitRoot 'docs\Requisites\external-tools.json' } else { '' }
  if ($manifest -and (Test-Path -LiteralPath $manifest)) {
    $tool = @((Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).tools) | Where-Object { $_.name -eq 'Everything' } | Select-Object -First 1
    if ($tool -and (Test-Path -LiteralPath (Join-Path $tool.dir 'es.exe'))) { $esBin = Join-Path $tool.dir 'es.exe' }
  }
}

if ($esBin) {
  try {
    $cliOutput = @(& $esBin -n $MaxResults.ToString() @esTokens 2>&1)
    if ($LASTEXITCODE -eq 0) {
      return $cliOutput
    }
  } catch {}
}
# ------------------------------------------------------------------------------
# 2. Secondary Transport: Everything HTTP REST JSON API (only if enabled in Everything)
# ------------------------------------------------------------------------------
$encodedSearch = [System.Uri]::EscapeDataString($finalQuery)
$httpUri = "http://127.0.0.1:$Port/?search=$encodedSearch&json=1&path_column=1&size_column=1&date_modified_column=1&count=$MaxResults"

try {
  $response = Invoke-RestMethod -Uri $httpUri -TimeoutSec 2 -ErrorAction Stop
  if ($null -ne $response -and $null -ne $response.results) {
    $results = foreach ($item in $response.results) {
      $itemPath = if ($null -ne $item.path) { $item.path } else { '' }
      $fullName = if ($itemPath) { [System.IO.Path]::Combine($itemPath, $item.name) } else { $item.name }
      [PSCustomObject]@{
        Name         = $item.name
        Path         = $itemPath
        FullName     = $fullName
        Size         = $item.size
        Type         = $item.type
      }
    }
    return $results
  }
} catch {
  # HTTP API unavailable, proceed to CLI fallback
}

# ------------------------------------------------------------------------------
# 3. Fallback: rg.exe --files / Get-ChildItem under the workspace root
# ------------------------------------------------------------------------------
$fbRoot = if (-not [string]::IsNullOrWhiteSpace($Path)) { $Path.Trim().Trim('"') } else { [Environment]::GetEnvironmentVariable('Git_Root', 'Machine') }
if ($fbRoot -and (Test-Path -LiteralPath $fbRoot) -and -not [string]::IsNullOrWhiteSpace($Query)) {
  Write-Warning 'Everything not reachable (es.exe missing and HTTP off); falling back to a scoped file scan.'
  return Get-ChildItem -LiteralPath $fbRoot -Recurse -File -Filter $Query -ErrorAction SilentlyContinue | Select-Object -First $MaxResults -ExpandProperty FullName
}
Write-Warning 'Everything (es.exe or HTTP) is not reachable and no fallback scope was possible. Run Test-ExternalTools.ps1.'
