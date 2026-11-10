<#
Module: LcmPackageVersion
Purpose: Validate LCM_AI package metadata against the highest owned component version.
Path: modules/LcmPackageVersion.psm1
Authors: Rolf, Copilot
Version: 10.2.1
Date: 2026-10-21
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-LcmPackageVersion {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$RepositoryPath,
    [switch]$WorkingTree
  )
  $arguments = @('-C', $RepositoryPath, 'grep', '-n', '-I', '-E')
  if (-not $WorkingTree) { $arguments += '--cached' }
  $arguments += @(
    '^[[:space:]#*]*"?[Vv]ersion"?[[:space:]]*:', '--', '.',
    ':!data', ':!templates', ':!docs/Proposals', ':!docs/Optimizations',
    ':!docs/Logs', ':!docs/LCM_Rules*', ':!logs', ':!scratch',
    ':!.copilot/History', ':!.copilot/Logs'
  )
  $lines = @(& git @arguments)
  if ($LASTEXITCODE -gt 1) { throw "Unable to scan component versions in '$RepositoryPath'." }
  $maximum = [version]'0.0.0'
  $count = 0
  foreach ($line in $lines) {
    if ($line -notmatch '^(?<path>.+):(?<line>\d+):(?<text>.*)$') { continue }
    if ([int]$Matches.line -gt 30) { continue }
    $metadata = $Matches.text
    if ($metadata -notmatch '^\s*(?:#\s*)?["*]*[Vv]ersion["*]*\s*:\s*["''`vV]*(?<version>\d+\.\d+\.\d+)(?:["''`]*\s*,?\s*)$') {
      throw "Invalid component version metadata: $line"
    }
    $version = [version]$Matches.version
    if ($version -gt $maximum) { $maximum = $version }
    $count++
  }
  if (-not $count) { throw "No component version metadata found in '$RepositoryPath'." }
  foreach ($path in @('docs/Architecture.md','docs/Requirements.md','docs/Implementation.md','README.md')) {
    if ($WorkingTree) {
      $text = [IO.File]::ReadAllText((Join-Path $RepositoryPath $path.Replace('/', '\')))
    } else {
      $content = @(& git -C $RepositoryPath show ":$path")
      if ($LASTEXITCODE -ne 0) { throw "Missing staged package metadata: $path" }
      $text = $content -join "`n"
    }
    $pattern = if ($path -eq 'README.md') {
      '(?m)^\- \*\*LCM Governance Baseline\*\*:\s*`(?<version>\d+\.\d+\.\d+)`'
    } else { '(?m)^Version:\s*(?<version>\d+\.\d+\.\d+)\s*\r?$' }
    $match = [regex]::Match($text, $pattern)
    if (-not $match.Success -or [version]$match.Groups['version'].Value -ne $maximum) {
      throw "LCM_AI VERSION GATE BLOCKED: '$path' must declare $maximum, the maximum owned component version. Align package metadata before review; no automatic post-review edits are permitted."
    }
  }
  [pscustomobject]@{ Version=$maximum.ToString(); ComponentCount=$count; Source=if ($WorkingTree) { 'WorkingTree' } else { 'Index' } }
}

Export-ModuleMember -Function Assert-LcmPackageVersion
