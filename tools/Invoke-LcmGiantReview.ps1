<#
.SYNOPSIS
  Builds one composite Beyond Compare review across all repositories.
.DESCRIPTION
  Left  = each repository at its base ref (default: upstream, i.e. what is on GitHub).
  Right = each repository at HEAD (what is committed locally).
  Both sides are exported with 'git archive' into <Out>\left\<repo> and
  <Out>\right\<repo> and opened in a single Beyond Compare folder compare.
  The workspace root is the parent of LCM_Inventory; nothing is hard-coded.
.PARAMETER Repos
  Repository folder names. Default: every folder under the workspace root with a .git.
.PARAMETER BaseRef
  Ref for the left side. Default '@{u}' (the tracked upstream branch).
.PARAMETER Out
  Export folder. Default: %TEMP%\LCM_GiantBCR.
.PARAMETER NoLaunch
  Only build the trees; do not start Beyond Compare.
.EXAMPLE
  pwsh -File Invoke-LcmGiantReview.ps1
  pwsh -File Invoke-LcmGiantReview.ps1 -BaseRef origin/main -NoLaunch
#>
[CmdletBinding()]
param(
  [string[]]$Repos,
  [string]$BaseRef = '@{u}',
  [string]$Out = (Join-Path $env:TEMP 'LCM_GiantBCR'),
  [switch]$NoLaunch,
  [Alias('h')][switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Usage: Invoke-LcmGiantReview.ps1 [-Repos <names>] [-BaseRef <ref>] [-Out <dir>] [-NoLaunch]'
  return
}

$workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $Repos) {
  $Repos = @(Get-ChildItem -LiteralPath $workspaceRoot -Directory |
      Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.git') } |
      ForEach-Object { $_.Name })
  $Repos = @('.') + $Repos
}

if (Test-Path -LiteralPath $Out) { Remove-Item -LiteralPath $Out -Recurse -Force }
$left = Join-Path $Out 'left'
$right = Join-Path $Out 'right'
New-Item -ItemType Directory -Force -Path $left, $right | Out-Null

function Export-RepoRef {
  param([string]$Path, [string]$Ref, [string]$Dest)
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  $tar = Join-Path $Out ([guid]::NewGuid().ToString('N') + '.tar')
  git -C $Path archive --format=tar -o $tar $Ref
  if ($LASTEXITCODE -ne 0) { throw "git archive failed for $Path at $Ref" }
  tar -xf $tar -C $Dest
  Remove-Item -LiteralPath $tar -Force
}

$summary = foreach ($r in $Repos) {
  $path = if ($r -eq '.') { $workspaceRoot } else { Join-Path $workspaceRoot $r }
  $label = if ($r -eq '.') { '_root' } else { $r }
  $base = (git -C $path rev-parse --verify --quiet $BaseRef) 2>$null
  if (-not $base) { Write-Warning "$label : base ref '$BaseRef' not found, skipped"; continue }
  $head = git -C $path rev-parse HEAD
  Export-RepoRef -Path $path -Ref $base -Dest (Join-Path $left $label)
  Export-RepoRef -Path $path -Ref $head -Dest (Join-Path $right $label)
  [pscustomobject]@{ Repo = $label; Base = $base.Substring(0, 8); Head = $head.Substring(0, 8); Same = ($base -eq $head) }
}
$summary | Format-Table -AutoSize

$bc = 'C:\Program Files\Beyond Compare 5\BCompare.exe'
if ($NoLaunch) { Write-Host "Trees ready: $left  |  $right"; return }
Start-Process -FilePath $bc -ArgumentList @($left, $right, '/fv="Folder Compare"', '/title1="GitHub (base)"', '/title2="Local HEAD"')
