<#
.SYNOPSIS
  GoodMorning: start-of-session check (time gap, work in between, versions, context, host blocks, DO front-end).
.DESCRIPTION
  Module: tools/Invoke-LCM_GoodMorning.ps1
  Purpose: Gives a fresh AI session facts instead of guesses. Its default path changes only what
           RULE-LCM-030 (5) allows: section 1 Status / Resumption Timestamp of ACTIVE_SESSION.md and,
           if needed, the start of the DO front-end; the -PrepareBcrBaseline option delegates daily
           Macrium baseline preparation to a separate tool.
           1. Time gap: the workspace gap is measured from the section 1 GoodNight Timestamp of
              ACTIVE_SESSION.md (fallback: last save, then newest commit, each labelled). With -Auto the
              check stays silent unless the activity gap exceeds -GapHours (default 7).
           2. Work in between: compares every repository with the Session Snapshot saved by
              Save-AllSessionMemory.ps1 (new commits, branch moves, uncommitted changes, behind upstream,
              new or missing repositories). The operator MUST be told about it.
           3. Versions: parity of the rule file versions and of the baseline claimed in ACTIVE_CONTEXT.md.
           4. Context: every path ACTIVE_CONTEXT.md points to must exist; its age; pending and accepted
              learned advice; guardrail scan.
           5. Prints the confirmation the AI must give before working.
  Path: LCM_Inventory/tools/Invoke-LCM_GoodMorning.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.6
  Date: 2026-11-17 15:40:19
  Rule: RULE-CTX-006, RULE-LCM-030 (4)-(6)
  Implementation Choices (CRP-350): one GoodNight source (section 1 GoodNight Timestamp) for every host;
           host blocks parsed with the full field list by LcmSessionStateAtoms.psm1 and checked against the
           schema vocabulary; DO front-end checked on /health and started via the LCM_DesktopDaemon_<user>
           logon task; the run records Status Active and Resumption Timestamp in section 1 (not with -WhatIf).
.PARAMETER Auto
  Session-start mode: silent (one line) when the gap is below -GapHours and -NoBaseline is specified.
.PARAMETER GapHours
  Gap that implies a good morning. Default 7.
.PARAMETER Force
  Run the full check regardless of the gap.
.PARAMETER PrepareBcrBaseline
  After the existing GoodMorning report, verifies or reuses today's Macrium baseline
  without initiating backup creation (Default: $true). Backup generation is a separate
  atom (Start-MacriumDailyBackup.ps1) executed at operator discretion.
.PARAMETER NoBaseline
  Suppresses Macrium baseline preparation while retaining unconditional baseline inspection.
.PARAMETER ReviewScope
  Active CRP or BUG identifier to associate with the Beyond Compare window title.
.PARAMETER WhatIf
  Simulates baseline preparation without executing background tasks.
.PARAMETER Help
  Displays this parameter documentation and usage syntax.
.NOTES
  Exit code 0 = nothing needing attention, 3 = attention items found (the AI must report them).
  Caveats: may be run by the operator or, on explicit operator instruction, by an AI host (RULE-CTX-006).
           Starting the DO front-end needs no elevation (own logon task).
#>

[CmdletBinding()]
param(
    [switch]$Auto,
    [double]$GapHours = 7,
    [switch]$Force,
    [switch]$PrepareBcrBaseline,
    [switch]$NoBaseline,
    [string]$ReviewScope = '',
    [switch]$WhatIf,
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Default baseline preparation is $true unless -NoBaseline is passed or -PrepareBcrBaseline is explicitly $false
if ($NoBaseline) {
    $PrepareBcrBaseline = $false
} elseif (-not $PSBoundParameters.ContainsKey('PrepareBcrBaseline')) {
    $PrepareBcrBaseline = $true
}

if ($Help) {
    Write-Host 'Invoke-LCM_GoodMorning.ps1 [-Auto] [-GapHours <n>] [-Force] [-PrepareBcrBaseline] [-NoBaseline] [-ReviewScope <CRP|BUG>] [-WhatIf] [-h]'
    Write-Host '  Session-start check; writes only section 1 Status / Resumption Timestamp of ACTIVE_SESSION.md'
    Write-Host '  and starts the DO front-end when it does not answer (not with -WhatIf); exit code 3 when attention items exist.'
    return
}

$inventoryRoot = Split-Path $PSScriptRoot -Parent
$contextModule = Join-Path $inventoryRoot 'modules\LCM_Context.psm1'
Import-Module -Name $contextModule -Force

$macriumAtomsModule = Join-Path $inventoryRoot 'modules\LcmMacriumAtoms.psm1'
if (Test-Path -LiteralPath $macriumAtomsModule) {
    Import-Module -Name $macriumAtomsModule -Force
}
$gitRoot = Get-LcmMachineGitRoot
$agentsDir = Join-Path $gitRoot 'LCM_AI\.agents'
$contextFile = Join-Path $agentsDir 'ACTIVE_CONTEXT.md'
$learnFile = Join-Path $agentsDir 'LEARNED_ADVICE.md'
$sessionFile = Join-Path $agentsDir 'ACTIVE_SESSION.md'
Import-Module -Name (Join-Path $inventoryRoot 'modules\LcmSessionStateAtoms.psm1') -Force
$now = Get-Date
$attention = [System.Collections.Generic.List[string]]::new()

function Get-ShortText {
    param([AllowNull()][string]$Text, [int]$Max = 220)
    if ($null -eq $Text) { return '' }
    if ($Text.Length -le $Max) { return $Text }
    $Text.Substring(0, $Max) + ' ...'
}

function Test-LcmDoFrontEnd {
    try {
        $resp = Invoke-WebRequest -Uri 'http://127.0.0.1:9876/health' -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
        return (200 -eq [int]$resp.StatusCode)
    } catch {
        return $false
    }
}

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
if ($ctx -match '(?m)^Saved: (\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?)') {
    $savedAt = [datetime]::Parse($Matches[1])
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

if ($Auto -and -not $Force -and -not $PrepareBcrBaseline -and $gap -lt $GapHours) {
    Write-Host ("GoodMorning not needed (gap {0:N1} h < {1} h)." -f $gap, $GapHours)
    return
}

Write-Host '==========================================================================' -ForegroundColor Cyan
Write-Host ' LCM GOODMORNING' -ForegroundColor Cyan
Write-Host '==========================================================================' -ForegroundColor Cyan
$sessRaw = if (Test-Path -LiteralPath $sessionFile) { [System.IO.File]::ReadAllText($sessionFile) } else { '' }
$goodNightAt = ConvertTo-LcmSessionTimestamp -Text (Get-LcmSessionWorkspaceField -Content $sessRaw -Name 'GoodNight Timestamp')
$refAt = $null
$refLabel = 'Good Night'
if ($null -ne $goodNightAt) {
    $refAt = $goodNightAt
} elseif ($null -ne $savedAt) {
    $refAt = $savedAt
    $refLabel = 'last save (no GoodNight recorded)'
} elseif ($null -ne $lastCommit) {
    $refAt = $lastCommit
    $refLabel = 'last commit (no GoodNight recorded)'
}
$goodNightDisplay = if ($null -ne $refAt) { $refAt.ToString('yyyy-MM-dd HH:mm:ss') } else { 'unknown' }
$gapDisplay = if ($null -ne $refAt) { '{0:N1} h' -f ($now - $refAt).TotalHours } else { 'unknown' }
$savedDisplay = if ($null -ne $savedAt) { $savedAt.ToString('yyyy-MM-dd HH:mm:ss') } else { 'none' }
Write-Host ("Now: {0:yyyy-MM-dd HH:mm:ss}   Last GoodNight: {1}   Workspace gap: {2}   Last save: {3}" -f $now, $goodNightDisplay, $gapDisplay, $savedDisplay)
Write-Host ("☀️ Good Morning! Resuming from {0} at {1} (Gap: {2})." -f $refLabel, $goodNightDisplay, $gapDisplay) -ForegroundColor Green
if ($null -eq $goodNightAt) { $attention.Add('ACTIVE_SESSION.md section 1 has no GoodNight Timestamp; the gap is measured from the last save or commit instead.') }
if ($null -eq $savedAt) { $attention.Add('No Session Snapshot in ACTIVE_CONTEXT.md; "work in between" cannot be determined. Run Save-AllSessionMemory.ps1 at the end of each day.') }

# Remote Push Synchronization Telemetry check
$lastPushStr = try {
    (Get-ItemProperty -Path 'HKLM:\SOFTWARE\LCM' -Name 'MRPushTimeStamp' -ErrorAction SilentlyContinue).MRPushTimeStamp
} catch { $null }
if (-not [string]::IsNullOrWhiteSpace($lastPushStr)) {
    $lastPushDate = [datetime]::MinValue
    if ([datetime]::TryParse($lastPushStr, [ref]$lastPushDate)) {
        $pushDays = (Get-Date).Subtract($lastPushDate).TotalDays
        Write-Host ("Last remote push: {0} ({1:N1} days ago)" -f $lastPushStr, $pushDays) -ForegroundColor Gray
        if ($pushDays -ge 3.0) {
            $attention.Add(("Remote repositories have not been pushed in {0:N1} days (last push: {1}). Run Invoke-LCM_Push.ps1 to synchronize." -f $pushDays, $lastPushStr))
        }
    }
}

# --- 1a. Multi-Host Session Registry (RULE-LCM-030 (5)) ----------------------
if (-not [string]::IsNullOrEmpty($sessRaw)) {
    Write-Host "`n[HOST SESSIONS] Registered AI host blocks (ACTIVE_SESSION.md section 2)" -ForegroundColor Yellow
    $hostBlocks = Get-LcmSessionHostBlocks -Content $sessRaw
    foreach ($hb in $hostBlocks) {
        $hStat = if ($hb.Fields.Contains('Status')) { $hb.Fields['Status'] } else { 'missing' }
        $hLast = if ($hb.Fields.Contains('Last Activity')) { $hb.Fields['Last Activity'] } else { 'missing' }
        $hGap = if ($null -ne $hb.LastActivity) { '{0:N1} h' -f ($now - $hb.LastActivity).TotalHours } else { 'unknown' }
        Write-Host ("  * {0,-20}: [{1}] (Last Activity: {2}, host gap {3})" -f $hb.Name, $hStat, $hLast, $hGap) -ForegroundColor Cyan
        foreach ($fn in 'Current Task', 'Next Step', 'Open Operator Decisions') {
            if ($hb.Fields.Contains($fn)) { Write-Host ("    {0}: {1}" -f $fn, (Get-ShortText -Text $hb.Fields[$fn])) -ForegroundColor Gray }
        }
        $aItems = @(if ($hb.Items.ContainsKey('Attention Items')) { $hb.Items['Attention Items'] })
        $aInline = if ($hb.Fields.Contains('Attention Items')) { [string]$hb.Fields['Attention Items'] } else { '' }
        Write-Host ("    Attention Items: {0}{1}" -f $aItems.Count, $(if ($aInline) { ' (' + $aInline + ')' } else { '' })) -ForegroundColor Gray
        foreach ($ai in $aItems) { Write-Host ("      - {0}" -f (Get-ShortText -Text $ai -Max 200)) -ForegroundColor Gray }
        foreach ($finding in @(Get-LcmSessionHostFinding -HostBlock $hb -GoodNight $goodNightAt)) {
            $attention.Add(("Host block '{0}': {1}." -f $hb.Name, $finding))
        }
    }
}

# --- 1c. DO front-end liveness (RULE-LCM-030 (5)) ----------------------------
Write-Host "`n[DO FRONT-END] daemon on 127.0.0.1:9876" -ForegroundColor Yellow
$doTask = 'LCM_DesktopDaemon_{0}' -f $env:USERNAME
if (Test-LcmDoFrontEnd) {
    Write-Host '  Running (health 200).' -ForegroundColor Green
} elseif ($WhatIf -or $WhatIfPreference) {
    Write-Host ('  Not answering; would start logon task {0} (WhatIf).' -f $doTask) -ForegroundColor DarkYellow
} else {
    Write-Host ('  Not answering; starting logon task {0} ...' -f $doTask) -ForegroundColor DarkYellow
    $doStarted = $false
    try {
        Start-ScheduledTask -TaskName $doTask -ErrorAction Stop
        for ($i = 0; $i -lt 10 -and -not $doStarted; $i++) {
            Start-Sleep -Seconds 1
            $doStarted = Test-LcmDoFrontEnd
        }
    } catch {
        Write-Host ('  Start failed: {0}' -f $_.Exception.Message) -ForegroundColor Red
    }
    if ($doStarted) {
        Write-Host '  Started (health 200).' -ForegroundColor Green
    } else {
        $attention.Add(('DO front-end does not answer on 127.0.0.1:9876 and could not be started via task {0}.' -f $doTask))
    }
}

# --- 1b. Baseline Telemetry (Unconditional) -----------------------------------
Write-Host "`n[BASELINE] Macrium BCR baseline telemetry & physical mount" -ForegroundColor Yellow
$baselineState = if (Get-Command -Name Get-MacriumBaselineState -ErrorAction SilentlyContinue) {
    Get-MacriumBaselineState
} else {
    $null
}

if ($null -ne $baselineState) {
    if ($baselineState.Plausible) {
        Write-Host ("  Mounted baseline drive : {0} (Volume: {1})" -f $baselineState.MountedDrive, $baselineState.VolumeLabel) -ForegroundColor Green
        if (-not [string]::IsNullOrWhiteSpace($baselineState.ImageFileName)) {
            Write-Host ("  Baseline image file    : {0}" -f $baselineState.ImageFileName) -ForegroundColor Green
        }
        Write-Host ("  Snapshot saved at      : {0}" -f $(if ($baselineState.SnapshotSavedAt) { $baselineState.SnapshotSavedAt } else { 'unknown' }))
        Write-Host ("  GoodNight observed     : {0}" -f $(if ($baselineState.GoodNightObserved) { 'Yes' } else { 'No' }))
    } else {
        Write-Host ("  Mounted baseline drive : None (searched {0})" -f ($baselineState.CandidateDrives -join ', ')) -ForegroundColor DarkYellow
    }
    $regStamp = if ($baselineState.RegistryMRMTimeStamp) { $baselineState.RegistryMRMTimeStamp } else { 'none' }
    $regDrive = if ($baselineState.RegistryMRMdrive) { $baselineState.RegistryMRMdrive } else { 'none' }
    $regLeaf = if ($baselineState.RegistryMRMImageLeaf) { " (" + $baselineState.RegistryMRMImageLeaf + ")" } else { '' }
    Write-Host ("  Registry registered    : {0} on {1}{2}" -f $regStamp, $regDrive, $regLeaf) -ForegroundColor Gray
} else {
    Write-Host '  Baseline telemetry module unavailable.' -ForegroundColor DarkYellow
}

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
    # LCM_Inventory data/ and logs/ change by nature of GoodNight; they are not work in between.
    if ($r.Name -eq 'LCM_Inventory') { $skipCtx += @(':(exclude)data', ':(exclude)logs') }
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

# --- 6. Section 1 resumption record (RULE-LCM-030 (5)) -------------------------
if (-not [string]::IsNullOrEmpty($sessRaw) -and -not ($WhatIf -or $WhatIfPreference)) {
    $resumeStamp = $now.ToString('yyyy-MM-dd HH:mm:ss')
    $gnText = if ($null -ne $goodNightAt) { $goodNightAt.ToString('yyyy-MM-dd HH:mm:ss') } else { 'none recorded' }
    $fresh = [System.IO.File]::ReadAllText($sessionFile)
    $fresh = Set-LcmSessionWorkspaceField -Content $fresh -Name 'Status' -Value ('Active (resumed at {0}; last GoodNight {1})' -f $resumeStamp, $gnText) -After 'Last Updated'
    $fresh = Set-LcmSessionWorkspaceField -Content $fresh -Name 'Resumption Timestamp' -Value $resumeStamp -After 'GoodNight Timestamp'
    [System.IO.File]::WriteAllText($sessionFile, $fresh, [System.Text.UTF8Encoding]::new($false))
    Write-Host ('ACTIVE_SESSION.md section 1: Status Active, Resumption Timestamp {0}.' -f $resumeStamp) -ForegroundColor Gray
}
if ($PrepareBcrBaseline) {
    $baselineTool = Join-Path $PSScriptRoot 'Invoke-MacriumDailyBcrBaseline.ps1'
    if (-not (Test-Path -LiteralPath $baselineTool)) {
        throw "Daily BCR baseline tool was not found: $baselineTool"
    }
    $automaticMorning = $Auto -and -not $Force -and $gap -ge $GapHours
    if ($Auto -and -not $Force -and -not $automaticMorning) {
        Write-Host ("Macrium baseline preparation deferred (gap {0:N1} h < {1} h); the writable baseline is not replaced automatically during the workday." -f $gap, $GapHours)
    } else {
        try {
            if ($WhatIf -or $WhatIfPreference) {
                & $baselineTool -ReviewScope $ReviewScope -WhatIf -Confirm:$false
            } else {
                & $baselineTool -ReviewScope $ReviewScope -Confirm:$false
            }
        } catch {
            Write-Host "`n[BASELINE STATUS] $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "                 Backup generation is decoupled from GoodMorning." -ForegroundColor Cyan
            Write-Host "                 Run 'Start-MacriumDailyBackup.ps1 [-Mount]' at your discretion after GoodMorning.`n" -ForegroundColor Cyan
        }
    }
}
if ($attention.Count -gt 0) { exit 3 }
