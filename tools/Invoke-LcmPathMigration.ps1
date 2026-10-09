<#
.SYNOPSIS
  Mass-replaces retired '.lcm' folder paths using config\lcm-path-map.json.
.DESCRIPTION
  Dry-run by default; use -Apply to write. Replaces only whole-token '.lcm'
  (never '.lcm_review.json', '.lcm_mode', etc.), preserves slash style,
  encoding, BOM and line endings. Works on the literal text, so
  Join-Path $root '.lcm\modules' becomes Join-Path $root 'LCM_Inventory\modules'.
  No root path is hard-coded: the workspace root is the parent of LCM_Inventory.
.PARAMETER Roots
  Repository folder names (relative to the workspace root) to scan.
.PARAMETER Apply
  Write changes. Without it, only a report is printed.
.EXAMPLE
  pwsh -File Invoke-LcmPathMigration.ps1
  pwsh -File Invoke-LcmPathMigration.ps1 -Apply
#>
[CmdletBinding()]
param(
  [string[]]$Roots = @('LCM_Inventory', 'LCM_Tools', 'LCM_AI', 'LCM_Shared'),
  [string[]]$Extensions = @('.ps1', '.psm1', '.psd1', '.cmd', '.bat', '.py', '.json'),
  [switch]$Apply,
  [Alias('h')][switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Usage: Invoke-LcmPathMigration.ps1 [-Roots <names>] [-Extensions <list>] [-Apply]'
  return
}

$inventoryRoot = Split-Path $PSScriptRoot -Parent
$workspaceRoot = Split-Path $inventoryRoot -Parent
$mapPath = Join-Path $inventoryRoot 'config\lcm-path-map.json'
$map = Get-Content -LiteralPath $mapPath -Raw | ConvertFrom-Json

$entries = @($map.map | Sort-Object { $_.from.Length } -Descending)
$skip = @($map.skipFiles | ForEach-Object { ($_ -replace '/', '\').ToLowerInvariant() })
$excludeDirs = '\scratch\', '\data\', '\logs\', '\Archives\', '\Proposals\', '\.git\', '\.venv\', '\node_modules\', '\__pycache__\'

# Whole-token '.lcm' followed by a separator, quote, whitespace, bracket or end
$tail = '(?=[\\/''"\s,;)\]]|$)'
$compiled = foreach ($e in $entries) {
  $parts = ($e.from -split '/') | ForEach-Object { [regex]::Escape($_) }
  [pscustomobject]@{
    Regex = [regex]('(?<![\w.-])' + ($parts -join '[\\/]') + $tail)
    To    = $e.to
  }
}

function Convert-LcmText {
  param([string]$Text)
  foreach ($c in $compiled) {
    $Text = $c.Regex.Replace($Text, {
        param($m)
        $useBack = $m.Value.Contains('\')
        if ($useBack) { $c.To -replace '/', '\' } else { $c.To }
      }.GetNewClosure())
  }
  return $Text
}

$report = @()
foreach ($root in $Roots) {
  $rootPath = Join-Path $workspaceRoot $root
  if (-not (Test-Path -LiteralPath $rootPath)) { continue }
  $files = Get-ChildItem -LiteralPath $rootPath -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object {
      $full = $_.FullName
      $Extensions -contains $_.Extension.ToLowerInvariant() -and
      -not ($excludeDirs | Where-Object { $full.Contains($_) })
    }
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($workspaceRoot.Length).TrimStart('\')
    if ($skip -contains $rel.ToLowerInvariant()) { continue }
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $text = [System.Text.UTF8Encoding]::new($false).GetString($bytes, $(if ($hasBom) { 3 } else { 0 }), $bytes.Length - $(if ($hasBom) { 3 } else { 0 }))
    if (-not $text.Contains('.lcm')) { continue }
    $new = Convert-LcmText -Text $text
    if ($new -ceq $text) { continue }
    $count = ([regex]::Matches($text, '\.lcm')).Count - ([regex]::Matches($new, '\.lcm')).Count
    $report += [pscustomobject]@{ File = $rel; Replaced = $count }
    if ($Apply) {
      [System.IO.File]::WriteAllText($f.FullName, $new, [System.Text.UTF8Encoding]::new($hasBom))
    }
  }
}

$report | Format-Table -AutoSize
$mode = if ($Apply) { 'APPLIED' } else { 'DRY-RUN' }
Write-Host ("{0}: {1} files, {2} replacements" -f $mode, @($report).Count, ($report | Measure-Object Replaced -Sum).Sum)
