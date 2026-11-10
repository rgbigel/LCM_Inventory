<#
.SYNOPSIS
  Review of the learned-advice candidates in LEARNED_ADVICE.md (list, accept, reject, promote).
.DESCRIPTION
  Module: tools/Invoke-LearnedAdviceReview.ps1
  Purpose: Candidates are lines "- [ ] text (date, author)" under "## Candidates".
           -Accept moves a candidate to the Accepted section (binding for all AIs).
           -Promote does the same and tags it [->rule], meaning it is to be written into the rules.
           -Reject deletes it. Without an action the pending candidates are listed.
           -Check exits with code 1 when candidates are pending (used as the push gate).
  Path: LCM_Inventory/tools/Invoke-LearnedAdviceReview.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-13
  Rule: RULE-CTX-005
.PARAMETER Accept
  Candidate numbers (as listed) to accept.
.PARAMETER Promote
  Candidate numbers to accept and tag for promotion into the rules.
.PARAMETER Reject
  Candidate numbers to delete (requires -ProposalId to document the active CRP correcting/retiring the entry).
.PARAMETER RetireAccepted
  Retires/purges an accepted advice entry matching -TextMatch or -Index (requires -ProposalId).
.PARAMETER PurgeResolved
  Alias for -RetireAccepted.
.PARAMETER TextMatch
  Substring or regex pattern to locate the accepted advice entry to retire.
.PARAMETER ProposalId
  Active CRP or BUG identifier (e.g. CRP-310, BUG-311) required when rejecting or retiring learned advice.
.PARAMETER Check
  Only report; exit 1 if candidates are pending.
#>

[CmdletBinding()]
param(
    [int[]]$Accept = @(),
    [int[]]$Promote = @(),
    [int[]]$Reject = @(),
    [Alias('PurgeResolved')]
    [switch]$RetireAccepted,
    [string]$TextMatch = '',
    [string]$ProposalId = '',
    [switch]$Check,
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host 'Invoke-LearnedAdviceReview.ps1 [-Accept <n,..>] [-Promote <n,..>] [-Reject <n,..> -ProposalId <CRP>] [-RetireAccepted -TextMatch <pattern> -ProposalId <CRP>] [-Check] [-h]'
    Write-Host '  Lists pending candidates of LEARNED_ADVICE.md, or applies the given decisions.'
    Write-Host '  Rejection/removal requires an explicit -ProposalId per RULE-CTX-005.'
    return
}

if (($Reject.Count -gt 0 -or $RetireAccepted) -and [string]::IsNullOrWhiteSpace($ProposalId)) {
    throw 'RULE-CTX-005 Invariant: Rejecting or retiring learned advice requires an active -ProposalId (CRP/BUG) documenting why the advice is retired or superseded.'
}

$contextModule = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\LCM_Context.psm1'
Import-Module -Name $contextModule -Force
$file = Join-Path (Get-LcmMachineGitRoot) 'LCM_AI\.agents\LEARNED_ADVICE.md'
$lines = [System.Collections.Generic.List[string]]::new()
$lines.AddRange([string[]]@([System.IO.File]::ReadAllLines($file)))

# Handle -RetireAccepted / -PurgeResolved
if ($RetireAccepted) {
    if ([string]::IsNullOrWhiteSpace($TextMatch)) {
        throw 'Retiring accepted advice requires -TextMatch to identify the entry to remove.'
    }

    $accHeader = $lines.FindIndex({ param($l) $l -like '## Accepted*' })
    if ($accHeader -lt 0) { throw 'Section "## Accepted" not found in LEARNED_ADVICE.md' }

    $removedCount = 0
    for ($i = $lines.Count - 1; $i -ge $accHeader; $i--) {
        $curLine = $lines[$i]
        if ($curLine.StartsWith('- ') -and ($curLine -match [regex]::Escape($TextMatch) -or $curLine -like "*$TextMatch*")) {
            Write-Host "Retiring accepted advice entry (authorized by $ProposalId):" -ForegroundColor Yellow
            Write-Host "  $curLine" -ForegroundColor DarkGray
            $lines.RemoveAt($i)
            $removedCount++
        }
    }

    if ($removedCount -eq 0) {
        Write-Host "No accepted entries found matching '$TextMatch'." -ForegroundColor Yellow
        return
    }

    [System.IO.File]::WriteAllText($file, (($lines -join "`r`n") + "`r`n"), [System.Text.UTF8Encoding]::new($false))
    Write-Host "Successfully retired $removedCount accepted entry/entries under $ProposalId." -ForegroundColor Green
    return
}

$candHeader = $lines.FindIndex({ param($l) $l -like '## Candidates*' })
if ($candHeader -lt 0) { throw 'Section "## Candidates" not found in LEARNED_ADVICE.md' }
$pending = @(for ($i = $candHeader + 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^- \[ \] ') { $i } })

if ($Check) {
    if ($pending.Count -gt 0) {
        Write-Host "$($pending.Count) learned-advice candidate(s) pending review (Invoke-LearnedAdviceReview.ps1)." -ForegroundColor Yellow
        exit 1
    }
    return
}

if (($Accept.Count + $Promote.Count + $Reject.Count) -eq 0) {
    if ($pending.Count -eq 0) { Write-Host 'No pending candidates.'; return }
    for ($n = 0; $n -lt $pending.Count; $n++) { Write-Host ("{0,3}  {1}" -f ($n + 1), ($lines[$pending[$n]] -replace '^- \[ \] ', '')) }
    return
}

$decisions = @{}
foreach ($n in $Accept) { $decisions[$n] = 'accept' }
foreach ($n in $Promote) { $decisions[$n] = 'promote' }
foreach ($n in $Reject) { $decisions[$n] = 'reject' }
foreach ($n in $decisions.Keys) { if ($n -lt 1 -or $n -gt $pending.Count) { throw "No candidate number $n" } }

$acceptedText = [System.Collections.Generic.List[string]]::new()
$remove = [System.Collections.Generic.List[int]]::new()
foreach ($n in ($decisions.Keys | Sort-Object)) {
    $idx = $pending[$n - 1]
    $text = $lines[$idx] -replace '^- \[ \] ', ''
    if ($decisions[$n] -eq 'promote') { $text = "[->rule] $text" }
    if ($decisions[$n] -ne 'reject') { $acceptedText.Add("- $text") }
    $remove.Add($idx)
}
foreach ($idx in ($remove | Sort-Object -Descending)) { $lines.RemoveAt($idx) }

if ($acceptedText.Count -gt 0) {
    # New advice is always added at the top per RULE-CTX-005
    $targetHeader = $lines.FindIndex({ param($l) $l -like '### Working agreement*' })
    $at = if ($targetHeader -ge 0) {
        $targetHeader + 1
    } else {
        $accHeader = $lines.FindIndex({ param($l) $l -like '## Accepted*' })
        if ($accHeader -ge 0) { $accHeader + 1 } else { 0 }
    }
    $lines.InsertRange($at, [string[]]$acceptedText.ToArray())
}
[System.IO.File]::WriteAllText($file, (($lines -join "`r`n") + "`r`n"), [System.Text.UTF8Encoding]::new($false))
Write-Host "Applied: $($acceptedText.Count) accepted/promoted, $(@($decisions.Values | Where-Object { $_ -eq 'reject' }).Count) rejected."
