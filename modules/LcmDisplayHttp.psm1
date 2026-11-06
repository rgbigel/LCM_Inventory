<#
.SYNOPSIS
  Serves allowlisted Standard Displays through the existing port 9876 listener.
.NOTES
  Module: LcmDisplayHttp
  Purpose: Serve allowlisted display pages, revisions and retained evidence on port 9876.
  Path: modules/LcmDisplayHttp.psm1
  Authors: Rolf, Copilot
  Version: 10.0.1
  Date: 2026-10-21
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'LcmDisplayCoordinator.psm1')

function Send-LcmDisplayResponse {
  [CmdletBinding()]
  param([object]$Response, [byte[]]$Bytes, [string]$ContentType, [int]$StatusCode = 200)
  $Response.StatusCode = $StatusCode
  $Response.ContentType = $ContentType
  $Response.Headers['Cache-Control'] = 'no-store, no-cache, must-revalidate'
  $Response.Headers['X-Content-Type-Options'] = 'nosniff'
  if ($ContentType -like 'text/html*') {
    $Response.Headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'; font-src 'self'; img-src 'self' data:; frame-src 'self'; object-src 'none'; base-uri 'self'"
  }
  $Response.ContentLength64 = $Bytes.Length
  $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
  $Response.Close()
}

function Invoke-LcmDisplayHttpRequest {
  [CmdletBinding()]
  param([object]$Request, [object]$Response, [string]$WorkspaceRoot = 'D:\Git_Repositories')
  $path = $Request.Url.AbsolutePath.ToLowerInvariant().TrimEnd('/')
  $method = $Request.HttpMethod
  $root = Join-Path $WorkspaceRoot 'LCM_Inventory'
  $aliases = @{ '/tools'='tools'; '/rules'='rules'; '/inventory'='inventory'; '/hub'='hub'; '/control'='hub'; '/control_hub'='hub'; '/cm_control_hub.html'='hub'; '/dates'='dates'; '/cm_crp_dates'='dates'; '/cm_crp_dates.html'='dates' }
  $isDisplay = $aliases.ContainsKey($path) -or $path -like '/displays/*' -or $path -like '/assets/*' -or $path -like '/failure-analysis/*' -or $path -like '/snapshots/*'
  if (-not $isDisplay) { return $false }
  $bytes = $null; $contentType = 'application/json; charset=utf-8'; $code = 200
  try {
    if ($Request.LocalEndPoint.Port -ne 9876) { throw 'Standard Displays require port 9876.' }
    if ($method -eq 'GET' -and $path -match '^/assets/(?<name>[a-z0-9_.-]+)$') {
      $name = $Matches.name
      $allowed = @('standard-table-display.css','standardtabledisplay.css','lcmtoolcatalog.css','lcm-tool-explorer.js','lcm-table-engine.js','lcm-table-print-atom.js','lcm-display-freshness.js','failure-analysis.css','failure-analysis.js')
      if ($name -notin $allowed) { throw 'Unknown display asset.' }
      $leaf = if ($name -eq 'standard-table-display.css') { 'StandardTableDisplay.css' } else { $name }
      $file = Join-Path $root "assets\$leaf"
      $bytes = [IO.File]::ReadAllBytes($file)
      $contentType = if ($name.EndsWith('.css')) { 'text/css; charset=utf-8' } else { 'text/javascript; charset=utf-8' }
    } elseif ($method -eq 'GET' -and $path -match '^/(?<kind>failure-analysis|snapshots)/(?<id>[a-f0-9]{32})/(?<leaf>index\.html|report\.json|report\.md)$') {
      $file = Join-Path $root "data\artifacts\$($Matches.kind)\$($Matches.id)\$($Matches.leaf)"
      $leaf = $Matches.leaf
      $bytes = [IO.File]::ReadAllBytes($file)
      $contentType = switch ($leaf) { 'index.html' { 'text/html; charset=utf-8' }; 'report.json' { 'application/json; charset=utf-8' }; default { 'text/plain; charset=utf-8' } }
    } else {
      $kind = 'page'; $id = ''
      if ($aliases.ContainsKey($path) -and $method -eq 'GET') { $id = $aliases[$path] }
      elseif ($path -match '^/displays/(?<kind>status|content|data|refresh)/(?<id>tools|rules|inventory|hub|dates)$') {
        $kind = $Matches.kind; $id = $Matches.id
        if (($kind -eq 'refresh' -and $method -ne 'POST') -or ($kind -ne 'refresh' -and $method -ne 'GET')) { throw 'Invalid display request method.' }
      } else { throw 'Unknown display route.' }
      $state = Update-LcmDisplayPublication -DisplayId $id -Refresh:($kind -eq 'refresh') -WorkspaceRoot $WorkspaceRoot
      if ($kind -in @('status','refresh')) {
        $bytes = [Text.Encoding]::UTF8.GetBytes(((Get-LcmDisplayStatus -State $state) | ConvertTo-Json -Compress))
      } elseif ($kind -eq 'data' -and $state.State -ne 'Current') {
        $code = 409
        $bytes = [Text.Encoding]::UTF8.GetBytes(((Get-LcmDisplayStatus -State $state) | ConvertTo-Json -Compress))
      } elseif ($kind -eq 'data' -and $null -ne $state.Bytes) {
        $html = [Text.Encoding]::UTF8.GetString($state.Bytes)
        $payload = Get-LcmDisplayPayload -Html $html
        $Response.Headers['X-LCM-Display-Revision'] = $state.Revision
        $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
      } elseif ($null -ne $state.Bytes) {
        $Response.Headers['X-LCM-Display-Revision'] = $state.Revision
        $html = [Text.Encoding]::UTF8.GetString($state.Bytes)
        $marker = '<meta name="lcm-presentation-revision" content="' + $state.PresentationRevision + '">'
        $head = [regex]::new('(?i)<head(?:\s[^>]*)?>')
        $html = $head.Replace($html, ('$0' + $marker), 1)
        $bytes = [Text.Encoding]::UTF8.GetBytes($html); $contentType = 'text/html; charset=utf-8'
      } else {
        $code = 503
        $bytes = [Text.Encoding]::UTF8.GetBytes((@{ state=$state.State; error=$state.Error; statusUrl="/displays/status/$id" } | ConvertTo-Json -Compress))
      }
    }
  } catch {
    $cause = $_.Exception.GetBaseException()
    $code = if ($cause -is [IO.FileNotFoundException] -or $cause -is [IO.DirectoryNotFoundException]) { 404 } else { 500 }
    Write-Warning "Standard Display request '$path' failed: $($_.Exception.Message)"
    $bytes = [Text.Encoding]::UTF8.GetBytes((@{ error=$_.Exception.Message } | ConvertTo-Json -Compress))
  }
  Send-LcmDisplayResponse -Response $Response -Bytes $bytes -ContentType $contentType -StatusCode $code
  return $true
}

function Stop-LcmDisplayHttp {
  [CmdletBinding()]
  param()
  Stop-LcmDisplayPublication
}

Export-ModuleMember -Function Invoke-LcmDisplayHttpRequest, Stop-LcmDisplayHttp
