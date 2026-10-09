<#
.SYNOPSIS
  AI guardrail: evaluates a proposed tool call (hook mode), checks workspace structure, manages grants.
.DESCRIPTION
  Hook mode (default): reads the hook JSON from stdin (Copilot CLI {toolName,toolArgs} or
  VS Code/Claude {tool_name,tool_input}), evaluates config/guardrails.json and prints
  a permissionDecision (allow = silent, ask, deny). 'ask' makes the harness put the question
  to the operator; with askSupported=false it becomes a deny that tells the agent to ask first.
  A grant (Grant-by-rule, time limited) turns a matching ask/deny into allow.
  Fails open on internal errors (logged) so a broken guardrail never blocks the operator.
.PARAMETER Scan
  Check structure.lock.json invariants. Exit 1 on violations.
.PARAMETER Grant
  Rule id (or '*') to allow for -Minutes (default from config).
.PARAMETER Revoke
  Remove all grants.
.PARAMETER ListGrants
  Show active grants.
.PARAMETER TestPath
  Dry-run a write to this path.
.PARAMETER TestCommand
  Dry-run this shell command.
.PARAMETER Minutes
  Grant lifetime.
.EXAMPLE
  pwsh -File Test-Guardrail.ps1 -Scan
  pwsh -File Test-Guardrail.ps1 -TestPath D:\Git_Repositories\.lcm\x.ps1
  pwsh -File Test-Guardrail.ps1 -Grant G-030-destructive -Minutes 15
  $env:LCM_GUARDRAIL_MODE = 'warn'   # session-wide softening
#>
[CmdletBinding()]
param(
  [switch]$Scan,
  [string]$Grant,
  [switch]$Revoke,
  [switch]$ListGrants,
  [string]$TestPath,
  [string]$TestCommand,
  [int]$Minutes = 0,
  [Alias('h')][switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Usage: Test-Guardrail.ps1 [-Scan] [-Grant <rule|*> [-Minutes n]] [-Revoke] [-ListGrants] [-TestPath p] [-TestCommand c] [-h]'
  Write-Host 'Without parameters: hook mode (JSON on stdin).'
  return
}

$inventoryRoot = Split-Path $PSScriptRoot -Parent
$workspaceRoot = Split-Path $inventoryRoot -Parent
$policyPath = Join-Path $inventoryRoot 'config\guardrails.json'
$lockPath = Join-Path $inventoryRoot 'config\structure.lock.json'
$stateDir = Join-Path $inventoryRoot 'data\guardrails'
$grantsPath = Join-Path $stateDir 'grants.json'
$statePath = Join-Path $stateDir 'state.json'
$logPath = Join-Path $inventoryRoot 'data\logs\guardrails.log'

function Write-GuardLog {
  param([string]$Text)
  try {
    New-Item -ItemType Directory -Force -Path (Split-Path $logPath) | Out-Null
    Add-Content -LiteralPath $logPath -Value ('{0:s} {1}' -f (Get-Date), $Text)
  } catch { $null = $_ }
}

function Read-Json {
  param([string]$Path, $Default)
  if (-not (Test-Path -LiteralPath $Path)) { return $Default }
  $raw = Get-Content -LiteralPath $Path -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
  return $raw | ConvertFrom-Json
}

function Save-Json {
  param([string]$Path, $Value)
  New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
  [System.IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 6), [System.Text.UTF8Encoding]::new($false))
}

function Get-ActiveGrants {
  $g = @(Read-Json -Path $grantsPath -Default @())
  return @($g | Where-Object { [datetime]$_.expires -gt (Get-Date) })
}

$policy = Read-Json -Path $policyPath -Default $null

# ---- management modes ----
if ($Grant) {
  $mins = if ($Minutes -gt 0) { $Minutes } else { [int]$policy.grantMinutesDefault }
  $g = @(Get-ActiveGrants) + [pscustomobject]@{ rule = $Grant; expires = (Get-Date).AddMinutes($mins).ToString('s') }
  Save-Json -Path $grantsPath -Value $g
  Write-Host "Granted '$Grant' for $mins minutes."
  return
}
if ($Revoke) { Save-Json -Path $grantsPath -Value @(); Write-Host 'All grants revoked.'; return }
if ($ListGrants) { Get-ActiveGrants | Format-Table -AutoSize; return }

if ($Scan) {
  $lock = Read-Json -Path $lockPath -Default $null
  $violations = New-Object System.Collections.Generic.List[string]
  $scopes = @($workspaceRoot) + @(Get-ChildItem -LiteralPath $workspaceRoot -Directory -Force |
      Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.git') } | ForEach-Object { $_.FullName })
  foreach ($s in $scopes) {
    foreach ($f in @($lock.forbiddenFolders)) {
      if (Test-Path -LiteralPath (Join-Path $s $f)) { $violations.Add("FORBIDDEN folder present: $(Join-Path $s $f)") }
    }
  }
  foreach ($f in @($lock.requiredFolders)) {
    if (-not (Test-Path -LiteralPath (Join-Path $workspaceRoot $f) -PathType Container)) { $violations.Add("REQUIRED folder missing: $f") }
  }
  foreach ($f in @($lock.requiredFiles)) {
    if (-not (Test-Path -LiteralPath (Join-Path $workspaceRoot $f))) { $violations.Add("REQUIRED file missing: $f") }
  }
  # .gitignore never limits the blast radius: ignored files inside it are violations,
  # and the content scan walks the file system directly.
  $radius = @($lock.blastRadius.folders)
  foreach ($s in $scopes) {
    if (-not (Test-Path -LiteralPath (Join-Path $s '.git'))) { continue }
    $ign = @(git -C $s ls-files -oi --exclude-standard -- @($radius) 2>$null | Where-Object { $_ -notmatch '__pycache__|\.pyc$' })
    foreach ($i in $ign) {
      $full = Join-Path $s $i
      $viaLink = $false
      $cur = Split-Path $full -Parent
      while ($cur.Length -gt $s.Length) {
        if ((Get-Item -LiteralPath $cur -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { $viaLink = $true; break }
        $cur = Split-Path $cur -Parent
      }
      if (-not $viaLink) { $violations.Add("IGNORED in blast radius: $full") }
    }
  }
  $extRx = '(?i)\.(' + ((@($lock.blastRadius.contentExtensions) | ForEach-Object { $_.TrimStart('.') }) -join '|') + ')$'
  $tokenRx = [regex]$lock.blastRadius.forbiddenTokenRegex
  $allowed = @($lock.blastRadius.allowTokenFiles | ForEach-Object { ($_ -replace '/', '\').ToLowerInvariant() })
  foreach ($s in $scopes) {
    foreach ($d in $radius) {
      $dir = Join-Path $s $d
      if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
      foreach ($f in Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue) {
        if ($f.FullName -notmatch $extRx) { continue }
        $rel = $f.FullName.Substring($workspaceRoot.Length).TrimStart('\').ToLowerInvariant()
        if ($allowed -contains $rel) { continue }
        if ($tokenRx.IsMatch([IO.File]::ReadAllText($f.FullName))) { $violations.Add("FORBIDDEN token in: $($f.FullName)") }
      }
    }
  }
  foreach ($j in @($lock.requiredJunctions)) {
    $p = Join-Path $workspaceRoot $j
    if (-not (Test-Path -LiteralPath $p)) { $violations.Add("REQUIRED link missing: $j") }
    elseif (-not ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { $violations.Add("NOT a link: $j") }
  }
  if ($violations.Count) { $violations | ForEach-Object { Write-Host $_ -ForegroundColor Red }; Write-GuardLog "SCAN violations=$($violations.Count)"; exit 1 }
  Write-Host 'Structure OK.' -ForegroundColor Green
  return
}

# ---- evaluation ----
function Get-StringValues {
  param($Node)
  if ($null -eq $Node) { return }
  if ($Node -is [string]) { $Node; return }
  if ($Node -is [System.Collections.IEnumerable]) { foreach ($i in $Node) { Get-StringValues $i }; return }
  if ($Node -is [psobject]) { foreach ($p in $Node.PSObject.Properties) { Get-StringValues $p.Value } }
}

function Get-Decision {
  param([string]$ToolName, $ToolInput, [string]$SessionId)
  $kind = if ($ToolName -match '(?i)powershell|bash|shell|terminal|command|exec') { 'shell' }
  elseif ($ToolName -match '(?i)create|edit|write|replace|patch|insert|delete|rename|move') { 'write' }
  else { 'other' }
  if ($kind -eq 'other') { return $null }

  $paths = @(); $command = ''
  if ($kind -eq 'shell') {
    $command = (@(Get-StringValues $ToolInput) -join "`n")
  } else {
    foreach ($k in 'path', 'file_path', 'filePath', 'filepath', 'new_path', 'target') {
      if ($ToolInput -and $ToolInput.PSObject.Properties[$k] -and $ToolInput.$k -is [string]) { $paths += $ToolInput.$k }
    }
    # apply_patch style payloads carry paths in their text
    foreach ($t in @(Get-StringValues $ToolInput)) {
      foreach ($m in [regex]::Matches($t, '(?m)^\*\*\* (?:Add|Update|Delete) File:\s*(.+)$')) { $paths += $m.Groups[1].Value.Trim() }
    }
  }

  $hit = $null
  foreach ($r in @($policy.rules)) {
    if ($r.applies -ne $kind) { continue }
    if ($kind -eq 'write' -and ($paths | Where-Object { $_ -match $r.pathRegex })) { $hit = $r; break }
    if ($kind -eq 'shell' -and $command -match $r.commandRegex) { $hit = $r; break }
  }

  if (-not $hit -and $kind -eq 'write' -and $policy.budget) {
    $state = Read-Json -Path $statePath -Default ([pscustomobject]@{})
    $count = 0
    if ($state.PSObject.Properties[$SessionId]) { $count = [int]$state.$SessionId }
    $count++
    $state | Add-Member -NotePropertyName $SessionId -NotePropertyValue $count -Force
    Save-Json -Path $statePath -Value $state
    $limit = [int]$policy.budget.editsPerSession
    if ($count -gt $limit -and (($count - $limit) % $limit) -eq 1) {
      $hit = [pscustomobject]@{ id = 'G-900-budget'; action = $policy.budget.action; reason = "$($policy.budget.reason) (edit #$count)" }
    }
  }
  return $hit
}

try {
  if (-not $policy) { return }
  $mode = if ($env:LCM_GUARDRAIL_MODE) { $env:LCM_GUARDRAIL_MODE } else { [string]$policy.mode }
  if ($mode -eq 'off') { return }

  if ($TestPath -or $TestCommand) {
    $toolName = if ($TestPath) { 'edit' } else { 'powershell' }
    $in = if ($TestPath) { [pscustomobject]@{ path = $TestPath } } else { [pscustomobject]@{ command = $TestCommand } }
    $sid = 'dryrun'
  } else {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { return }
    $evt = $raw | ConvertFrom-Json
    $toolName = ''
    foreach ($k in 'toolName', 'tool_name') { if ($evt.PSObject.Properties[$k]) { $toolName = [string]$evt.$k } }
    $in = $null
    foreach ($k in 'tool_input', 'toolArgs') { if ($evt.PSObject.Properties[$k]) { $in = $evt.$k } }
    if ($in -is [string]) { try { $in = $in | ConvertFrom-Json } catch { $in = [pscustomobject]@{ command = $in } } }
    $sid = 'default'
    foreach ($k in 'sessionId', 'session_id') { if ($evt.PSObject.Properties[$k]) { $sid = [string]$evt.$k } }
  }

  $hit = Get-Decision -ToolName $toolName -ToolInput $in -SessionId $sid
  if (-not $hit) { if ($TestPath -or $TestCommand) { Write-Host 'allow' }; return }

  $action = [string]$hit.action
  if ($mode -eq 'warn') { $action = 'warn' }
  elseif ($mode -eq 'ask' -and $action -eq 'deny') { $action = 'ask' }

  if (@(Get-ActiveGrants | Where-Object { $_.rule -in @($hit.id, '*') }).Count -gt 0) { $action = 'allow' }

  Write-GuardLog "$($hit.id) tool=$toolName action=$action"
  if ($action -in 'allow', 'warn') { if ($TestPath -or $TestCommand) { Write-Host "$action ($($hit.id))" }; return }

  $reason = "[$($hit.id)] $($hit.reason)"
  if ($action -eq 'ask' -and -not $policy.askSupported) {
    $action = 'deny'
    $reason += " Ask the operator (ask_user) first; if approved run: pwsh LCM_Inventory\tools\Test-Guardrail.ps1 -Grant $($hit.id)"
  } elseif ($action -eq 'deny') {
    $reason += " To override deliberately: Test-Guardrail.ps1 -Grant $($hit.id)"
  }
  $out = [ordered]@{
    permissionDecision = $action
    permissionDecisionReason = $reason
    hookSpecificOutput = [ordered]@{ hookEventName = 'PreToolUse'; permissionDecision = $action; permissionDecisionReason = $reason }
  }
  $out | ConvertTo-Json -Depth 4 -Compress
} catch {
  Write-GuardLog "ERROR fail-open: $($_.Exception.Message)"
}
