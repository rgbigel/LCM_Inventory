<#
.SYNOPSIS
  Verifies the external tools and Everything content-index settings declared in LCM_AI\docs\Requisites\external-tools.json.
.DESCRIPTION
  Reads Git_Root from the Machine environment (registry) only, loads the Requisites manifest and checks:
    1. every tool's probe executable exists in its install directory,
    2. every addToPath directory is present in the Machine PATH,
    3. es.exe answers a query,
    4. Everything.ini has content indexing enabled and covering the workspace and the required file types.
  Read-only. Exit code 0 = all checks passed, 1 = at least one failed.
.EXAMPLE
  pwsh LCM_Inventory/tools/Test-ExternalTools.ps1
.NOTES
  Version: 10.0.1
  Date: 2026-10-21
#>
[CmdletBinding()]
param(
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Usage: Test-ExternalTools.ps1 [-h]'
  Write-Host 'Checks external tools, Machine PATH entries, es.exe and Everything.ini content-index settings from LCM_AI\docs\Requisites\external-tools.json.'
  return
}

$gitRoot = [Environment]::GetEnvironmentVariable('Git_Root', 'Machine')
if ([string]::IsNullOrWhiteSpace($gitRoot)) { throw 'Machine environment value Git_Root is not set. Run SetGitRoot (elevated).' }
$manifestFile = Join-Path $gitRoot 'LCM_AI\docs\Requisites\external-tools.json'
if (-not (Test-Path -LiteralPath $manifestFile)) {
  $manifestFile = Join-Path $gitRoot 'docs\Requisites\external-tools.json'
}
if (-not (Test-Path -LiteralPath $manifestFile)) { throw "Requisites manifest not found: $manifestFile" }
$req = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json

$results = [System.Collections.Generic.List[object]]::new()
function Add-Result([string]$Check, [bool]$Ok, [string]$Detail) {
  $results.Add([pscustomobject]@{ Check = $Check; Status = $(if ($Ok) { 'OK' } else { 'FAIL' }); Detail = $Detail })
}

$machinePath = @([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' | ForEach-Object { $_.TrimEnd('\') })

foreach ($tool in @($req.tools)) {
  $probe = Join-Path $tool.dir $tool.probe
  Add-Result "tool:$($tool.name)" (Test-Path -LiteralPath $probe) $probe
  if ($tool.addToPath) {
    $onPath = $machinePath -contains $tool.dir.TrimEnd('\')
    Add-Result "path:$($tool.name)" $onPath $(if ($onPath) { 'in Machine PATH' } else { 'missing in Machine PATH (run SetGitRoot elevated)' })
  }
}

$esTool = @($req.tools) | Where-Object { $_.name -eq 'Everything' } | Select-Object -First 1
if ($esTool) {
  $es = Join-Path $esTool.dir 'es.exe'
  if (Test-Path -LiteralPath $es) {
    try {
      $hit = @(& $es -n 1 'AGENTS.md' 2>&1)
      Add-Result 'es.exe query' ($LASTEXITCODE -eq 0 -and $hit.Count -gt 0) $(if ($hit.Count) { [string]$hit[0] } else { 'no result' })
    } catch { Add-Result 'es.exe query' $false $_.Exception.Message }
  }
}

$ini = $req.everythingIni
if ($ini -and (Test-Path -LiteralPath $ini.file)) {
  $kv = @{}
  foreach ($line in Get-Content -LiteralPath $ini.file) {
    if ($line -match '^([A-Za-z0-9_]+)=(.*)$') { $kv[$Matches[1]] = $Matches[2] }
  }
  foreach ($p in $ini.required.PSObject.Properties) {
    $actual = if ($kv.ContainsKey($p.Name)) { $kv[$p.Name] } else { '(unset)' }
    Add-Result "ini:$($p.Name)" ($actual -eq $p.Value) "expected $($p.Value), found $actual"
  }
  $folders = @(($kv['content_indexing_include_only_folders']) -split ';' | ForEach-Object { $_.Trim().TrimEnd('*').TrimEnd('\') })
  $covered = $false
  foreach ($f in $folders) { if ($f -and $ini.includeFolderMustCover.TrimEnd('\') -like "$f*") { $covered = $true } }
  Add-Result 'ini:content folders' $covered "must cover $($ini.includeFolderMustCover)"
  # Everything accepts either ',' or ';' between patterns (locale dependent); both are read here
  $rawTypes = [string]$kv['content_indexing_include_only_files']
  $patterns = @($rawTypes -split '[;,]' | ForEach-Object { $_.Trim() })
  foreach ($need in $ini.includeFileTypesMustCover) {
    $ok = $false
    foreach ($pt in $patterns) { if ($pt -and $need -like $pt) { $ok = $true } }
    Add-Result "ini:content type $need" $ok 'covered by content_indexing_include_only_files'
  }
} else {
  Add-Result 'ini:file' $false "Everything.ini not found: $($ini.file)"
}

$results | Format-Table -AutoSize -Wrap
$failed = @($results | Where-Object Status -eq 'FAIL').Count
if ($failed -gt 0) { Write-Host "$failed check(s) failed." -ForegroundColor Red; exit 1 }
Write-Host 'All external-tool checks passed.' -ForegroundColor Green
