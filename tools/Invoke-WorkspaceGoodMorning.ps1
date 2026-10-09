<#
.SYNOPSIS
  GoodMorning: read-only start-of-session check (time gap, work in between, versions, context).
.DESCRIPTION
  Module: tools/Invoke-WorkspaceGoodMorning.ps1
  Purpose: Gives a fresh AI session facts instead of guesses. It changes nothing.
           1. Time gap: since the last activity (Save-All stamp or newest commit). With -Auto the
              check stays silent unless the gap exceeds -GapHours (default 7), which implies a good morning.
           2. Work in between: compares every repository with the Session Snapshot saved by
              Save-AllSessionMemory.ps1 (new commits, branch moves, uncommitted changes, behind upstream,
              new or missing repositories). The operator MUST be told about it.
           3. Versions: parity of the rule file versions and of the baseline claimed in ACTIVE_CONTEXT.md.
           4. Context: every path ACTIVE_CONTEXT.md points to must exist; its age; pending and accepted
              learned advice; guardrail scan.
           5. Prints the confirmation the AI must give before working.
  Path: LCM_Inventory/tools/Invoke-WorkspaceGoodMorning.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 1.0.0
  Date: 2026-10-09
  Rule: RULE-CTX-006
.PARAMETER Auto
  Session-start mode: silent (one line) when the gap is below -GapHours.
.PARAMETER GapHours
  Gap that implies a good morning. Default 7.
.PARAMETER Force
  Run the full check regardless of the gap.
.NOTES
  Exit code 0 = nothing needing attention, 3 = attention items found (the AI must report them).
#>

[CmdletBinding()]
param(
    [switch]$Auto,
    [double]$GapHours = 7,
    [switch]$Force,
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host 'Invoke-WorkspaceGoodMorning.ps1 [-Auto] [-GapHours <n>] [-Force] [-h]'
    Write-Host '  Read-only session-start check; exit code 3 when attention items exist.'
    return
}

$contextModule = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\LcmWorkspaceContext.psm1'
Import-Module -Name $contextModule -Force
$gitRoot = Get-LcmMachineGitRoot
$agentsDir = Join-Path $gitRoot 'LCM_AI\.agents'
$contextFile = Join-Path $agentsDir 'ACTIVE_CONTEXT.md'
$learnFile = Join-Path $agentsDir 'LEARNED_ADVICE.md'
$now = Get-Date
$attention = [System.Collections.Generic.List[string]]::new()

function Get-RepoList {
    $dirs = @($gitRoot) + @(Get-ChildItem -LiteralPath $gitRoot -Directory -Force | Where-Object { $_.Name -notlike '.*' } | ForEach-Object { $_.FullName })
    foreach ($d in $dirs) {
        if (Test-Path -LiteralPath (Join-Path $d '.git')) {
            [pscustomobject]@{ Name = $(if ($d -eq $gitRoot) { 'Git_Repositories' } else { Split-Path $d -Leaf }); Path = $d }
        }
    }
}

# --- 1. Time gap ---------------------------------------------------------------
$ctx = [System.IO.File]::ReadAllText($contextFile)
$repos = @(Get-RepoList)
$savedAt = $null
if ($ctx -match '(?m)^Saved: (\d{4}-\d{2}-\d{2} \d{2}:\d{2})') {
    $savedAt = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm', $null)
}
$lastCommit = $null
foreach ($r in $repos) {
    $ct = git -C $r.Path log -1 --format=%ct 2>$null
    if ($LASTEXITCODE -eq 0 -and $ct) {
        $t = [DateTimeOffset]::FromUnixTimeSeconds([long]$ct).LocalDateTime
        if ($null -eq $lastCommit -or $t -gt $lastCommit) { $lastCommit = $t }
    }
}
$lastActivity = @($savedAt, $lastCommit | Where-Object { $null -ne $_ } | Sort-Object -Descending)[0]
$gap = if ($null -eq $lastActivity) { [double]::PositiveInfinity } else { ($now - $lastActivity).TotalHours }

if ($Auto -and -not $Force -and $gap -lt $GapHours) {
    Write-Host ("GoodMorning not needed (gap {0:N1} h < {1} h)." -f $gap, $GapHours)
    return
}

Write-Host '==========================================================================' -ForegroundColor Cyan
Write-Host ' LCM GOODMORNING (read-only)' -ForegroundColor Cyan
Write-Host '==========================================================================' -ForegroundColor Cyan
Write-Host ("Now: {0:yyyy-MM-dd HH:mm}   Last activity: {1}   Gap: {2}" -f $now, $(if ($lastActivity) { $lastActivity.ToString('yyyy-MM-dd HH:mm') } else { 'unknown' }), $(if ([double]::IsInfinity($gap)) { 'unknown' } else { '{0:N1} h' -f $gap }))
if ($null -eq $savedAt) { $attention.Add('No Session Snapshot in ACTIVE_CONTEXT.md; "work in between" cannot be determined. Run Save-AllSessionMemory.ps1 at the end of each day.') }

# --- 2. Work in between --------------------------------------------------------
Write-Host "`n[WORK IN BETWEEN] since the last saved snapshot" -ForegroundColor Yellow
$snap = @{}
foreach ($m in [regex]::Matches($ctx, '(?m)^\| ([^|]+?) \| ([^|]+?) \| ([^|]+?) \| (.+?) \|\s*$')) {
    if ($m.Groups[1].Value -in 'Repository', '---') { continue }
    $snap[$m.Groups[1].Value] = [pscustomobject]@{ Branch = $m.Groups[2].Value; Head = $m.Groups[3].Value; State = $m.Groups[4].Value }
}
$between = 0
foreach ($r in $repos) {
    $branch = (git -C $r.Path rev-parse --abbrev-ref HEAD 2>$null)
    $head = (git -C $r.Path rev-parse --short HEAD 2>$null)
    if (-not $head) { $head = 'none' }
    $skipCtx = @('--', '.', ':(exclude).agents/ACTIVE_CONTEXT.md')
    $dirty = @(git -C $r.Path status --short @skipCtx 2>$null).Count
    $behind = (git -C $r.Path rev-list --count 'HEAD..@{u}' 2>$null)
    if ($LASTEXITCODE -ne 0) { $behind = 0 }
    $notes = [System.Collections.Generic.List[string]]::new()
    if (-not $snap.ContainsKey($r.Name)) {
        if ($snap.Count -gt 0) { $notes.Add('new repository (not in snapshot)') }
    } else {
        $s = $snap[$r.Name]
        if ($s.Branch -ne $branch) { $notes.Add("branch $($s.Branch) -> $branch") }
        if ($s.Head -ne $head) {
            $log = @(git -C $r.Path log --format='%h %an: %s' "$($s.Head)..HEAD" @skipCtx 2>$null)
            if ($LASTEXITCODE -eq 0 -and $log.Count -eq 0) {
                # only the final snapshot commit moved HEAD
            } elseif ($LASTEXITCODE -eq 0) {
                $notes.Add("$($log.Count) new commit(s) since snapshot")
                foreach ($l in ($log | Select-Object -First 3)) { $notes.Add("    $l") }
            } else {
                $notes.Add("HEAD $($s.Head) -> $head (history rewritten or snapshot commit unknown)")
            }
        }
        if ($dirty -gt 0 -and $s.State -notmatch '^uncommitted') { $notes.Add("$dirty uncommitted change(s) (snapshot said: $($s.State))") }
    }
    if ([int]$behind -gt 0) { $notes.Add("behind upstream by $behind commit(s) (local refs; no fetch done)") }
    if ($notes.Count -gt 0) {
        $between++
        Write-Host "  $($r.Name):" -ForegroundColor White
        foreach ($n in $notes) { Write-Host "    - $n" -ForegroundColor DarkYellow }
    }
}
foreach ($k in $snap.Keys) {
    if (-not ($repos | Where-Object { $_.Name -eq $k })) { $between++; Write-Host "  ${k}: in snapshot but not present now" -ForegroundColor DarkYellow }
}
if ($between -eq 0) { Write-Host '  Nothing changed since the snapshot.' -ForegroundColor Green }
else { $attention.Add("Work in between found in $between repository/repositories (listed above); tell the operator before continuing.") }

# --- 3. Versions ---------------------------------------------------------------
Write-Host "`n[VERSIONS]" -ForegroundColor Yellow
$ruleVersions = @{}
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $agentsDir 'rules') -Filter *.md -File) {
    $head = (Get-Content -LiteralPath $f.FullName -TotalCount 25) -join "`n"
    if ($head -match '(?m)^\s*(?:#\s*)?[Vv]ersion:\s*(\d+)\.(\d+)\.(\d+)') { $ruleVersions[$f.Name] = [version]"$($Matches[1]).$($Matches[2]).$($Matches[3])" }
}
if ($ruleVersions.Count -gt 0) {
    $majors = @($ruleVersions.Values | ForEach-Object { $_.Major } | Sort-Object -Unique)
    $top = ($ruleVersions.Values | Measure-Object -Maximum).Maximum
    Write-Host ("  Rules: {0} file(s), majors {1}, highest {2}" -f $ruleVersions.Count, ($majors -join '/'), $top)
    if ($majors.Count -gt 1) {
        $attention.Add("Rule files disagree on the major version ($($majors -join ', ')).")
        foreach ($k in ($ruleVersions.Keys | Where-Object { $ruleVersions[$_].Major -ne $top.Major })) { Write-Host "    - $k $($ruleVersions[$k])" -ForegroundColor DarkYellow }
    }
    if ($ctx -match 'LCM V(\d+)\.(\d+)\.(\d+)' -and [int]$Matches[1] -ne $top.Major) {
        $attention.Add("ACTIVE_CONTEXT.md claims LCM V$($Matches[1]).$($Matches[2]).$($Matches[3]) but the rules are at major $($top.Major).")
    }
}
foreach ($r in $repos | Where-Object { $_.Name -like 'LCM_*' }) {
    $tag = (git -C $r.Path describe --tags --abbrev=0 2>$null)
    Write-Host ("  {0}: last tag {1}" -f $r.Name, $(if ($LASTEXITCODE -eq 0) { $tag } else { 'none' }))
}

# --- 4. Context ----------------------------------------------------------------
Write-Host "`n[CONTEXT] ACTIVE_CONTEXT.md and learned advice" -ForegroundColor Yellow
$missing = [System.Collections.Generic.List[string]]::new()
$targets = [System.Collections.Generic.HashSet[string]]::new()
foreach ($m in [regex]::Matches($ctx, '\]\((file:///[^)\s]+|\./[^)\s#]+)\)')) {
    $v = [uri]::UnescapeDataString($m.Groups[1].Value)
    if ($v -like 'file:///*') { $v = $v.Substring(8) } else { $v = Join-Path $agentsDir $v }
    [void]$targets.Add(($v -replace '/', '\'))
}
foreach ($m in [regex]::Matches($ctx, '`([A-Za-z]:\\[^`*]+)`')) { [void]$targets.Add($m.Groups[1].Value.TrimEnd('\')) }
foreach ($t in $targets) { if (-not (Test-Path -LiteralPath $t)) { $missing.Add($t) } }
Write-Host "  Paths referenced: $($targets.Count), missing: $($missing.Count)"
foreach ($x in $missing) { Write-Host "    - $x" -ForegroundColor DarkYellow }
if ($missing.Count -gt 0) { $attention.Add("ACTIVE_CONTEXT.md refers to $($missing.Count) path(s) that do not exist; it is partly stale and must not be trusted for those.") }

if ($ctx -match '\*\*Last Updated:\*\* (\d{4}-\d{2}-\d{2})') {
    $age = ($now.Date - [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null)).Days
    Write-Host "  Last Updated stamp: $($Matches[1]) ($age day(s) ago)"
}

$learn = [System.IO.File]::ReadAllLines($learnFile)
$ci = [array]::FindIndex($learn, [Predicate[string]] { param($l) $l -like '## Candidates*' })
$accepted = @($learn[0..($ci - 1)] | Where-Object { $_ -match '^- ' }).Count
$pendingN = @($learn[$ci..($learn.Count - 1)] | Where-Object { $_ -match '^- \[ \] ' }).Count
Write-Host "  Learned advice: $accepted accepted (binding), $pendingN candidate(s) pending review"
if ($pendingN -gt 0) { $attention.Add("$pendingN learned-advice candidate(s) await review (needed before any push).") }

$guard = Join-Path $PSScriptRoot 'Test-Guardrail.ps1'
if (Test-Path -LiteralPath $guard) {
    $g = (& pwsh -NoProfile -File $guard -Scan 2>&1 | Out-String).Trim()
    $gl = ($g -split "`r?`n" | Select-Object -Last 1)
    Write-Host "  Guardrail scan: $gl"
    if ($gl -notmatch 'Structure OK') { $attention.Add("Guardrail scan did not report 'Structure OK': $gl") }
}

# --- 5. Verdict and confirmation -----------------------------------------------
Write-Host "`n==========================================================================" -ForegroundColor Cyan
if ($attention.Count -eq 0) {
    Write-Host ' ATTENTION: none' -ForegroundColor Green
} else {
    Write-Host " ATTENTION ($($attention.Count)) - report these to the operator:" -ForegroundColor Red
    foreach ($a in $attention) { Write-Host "  * $a" -ForegroundColor Red }
}
Write-Host '--------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host ' AI CONFIRMATION (state in your first reply):' -ForegroundColor Cyan
Write-Host '  1. I have read ACTIVE_CONTEXT.md and LEARNED_ADVICE.md and can follow them;'
Write-Host '     name anything in them that is unclear, contradictory or stale (see above).'
Write-Host '  2. Work in between and version findings, summarised for the operator.'
Write-Host '  3. Where I will start (the last Next/open item) and what I will not touch.'
Write-Host '==========================================================================' -ForegroundColor Cyan
if ($attention.Count -gt 0) { exit 3 }
