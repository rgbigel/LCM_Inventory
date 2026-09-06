# =====================================================================
# ProposalManager.psm1 - LCM Proposal & Two-Tier Review Governance Module
# =====================================================================
# Module: ProposalManager
# Purpose: Manages LCM proposal lifecycle (suggested -> processed -> deferred / completed / deleted),
#          batch operations, review granularity ('coarse' | 'tight'), repo review queue inspection,
#          and persistent ledger storage in Workspace_Inventory.
# Authors: Rolf, Workspace_AI Engine
# Version: 1.0.2
# Date: 2026-09-06
# =====================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ProposalStorePath {
    [CmdletBinding()]
    param()

    $scriptRoot = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        $scriptRoot = (Get-Location).Path
    }

    $item = Get-Item $scriptRoot
    while ($item -ne $null -and $item.Name -ne 'Workspace_Inventory' -and $item.Name -ne 'Git_Repositories') {
        $item = $item.Parent
    }

    $wiRoot = if ($item -and $item.Name -eq 'Workspace_Inventory') {
        $item.FullName
    } elseif ($item -and $item.Name -eq 'Git_Repositories') {
        Join-Path $item.FullName 'Workspace_Inventory'
    } else {
        'D:\Git_Repositories\Workspace_Inventory'
    }

    $proposalsDir = Join-Path $wiRoot 'data\proposals'
    if (-not (Test-Path $proposalsDir)) {
        New-Item -ItemType Directory -Path $proposalsDir -Force | Out-Null
    }

    return (Join-Path $proposalsDir 'proposals.json')
}

function Get-ProposalStore {
    [CmdletBinding()]
    param()

    $path = Get-ProposalStorePath
    if (-not (Test-Path $path)) {
        $initStore = [ordered]@{
            '$schema'            = 'https://json-schema.org/draft/2020-12/schema'
            title                = 'LCM Workspace Proposals Ledger'
            updated_at           = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
            review_granularity   = 'coarse'
            lcm_mode             = 'active'
            last_proposal_id     = 0
            proposals            = @()
        }
        $initStore | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
        return [PSCustomObject]$initStore
    }

    $json = Get-Content -Path $path -Raw -Encoding UTF8
    return ($json | ConvertFrom-Json)
}

function Set-ProposalStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Store
    )

    $path = Get-ProposalStorePath
    $Store.updated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    $Store | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
}

function Get-WorkspaceProposals {
    [CmdletBinding()]
    param(
        [int[]]$Id,
        [string]$State,
        [string]$OriginRepo,
        [switch]$OpenOnly
    )

    $store = Get-ProposalStore
    $items = @($store.proposals)

    if ($OpenOnly) {
        $items = @($items | Where-Object { $_.state -in @('bug', 'suggested', 'approved', 'processed', 'deferred') })
    }

    if ($Id -and $Id.Count -gt 0) {
        $items = @($items | Where-Object { $Id -contains $_.id })
    }

    if (-not [string]::IsNullOrWhiteSpace($State)) {
        $s = $State.ToLowerInvariant()
        $items = @($items | Where-Object { $_.state.ToLowerInvariant() -eq $s })
    }

    if (-not [string]::IsNullOrWhiteSpace($OriginRepo)) {
        $r = $OriginRepo.ToLowerInvariant()
        $items = @($items | Where-Object { $_.origin_repo.ToLowerInvariant().Contains($r) })
    }

    return @($items | Sort-Object id)
}

function New-WorkspaceProposal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [string]$OriginRepo = 'Workspace_Inventory',
        [string]$Details = '',
        [string]$BundleId = 'unassigned',
        [string]$CrId = '',
        [string]$Author = $env:USERNAME,
        [string]$PlanPath = '',
        [string]$WalkthroughPath = ''
    )

    $store = Get-ProposalStore
    $newId = [int]$store.last_proposal_id + 1
    $store.last_proposal_id = $newId

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $cleanCrId = if ($CrId) { $CrId } else { "CR-PROP-$newId" }
    $safeCrId = $cleanCrId -replace '[^a-zA-Z0-9_-]', '_'

    if ([string]::IsNullOrWhiteSpace($PlanPath)) {
        $PlanPath = "Workspace_Inventory/data/proposals/plans/Proposal-{0:D3}_{1}_Plan.md" -f $newId, $safeCrId
    }
    if ([string]::IsNullOrWhiteSpace($WalkthroughPath)) {
        $WalkthroughPath = "Workspace_Inventory/data/proposals/plans/Proposal-{0:D3}_{1}_Walkthrough.md" -f $newId, $safeCrId
    }

    $proposal = [ordered]@{
        id               = $newId
        timestamp        = $timestamp
        title            = $Title
        origin_repo      = $OriginRepo
        cr_id            = $cleanCrId
        state            = 'suggested'
        progress_state   = 'undecided'
        bundle_id        = $BundleId
        author           = if ($Author) { $Author } else { 'Rolf' }
        details          = $Details
        plan_path        = $PlanPath
        walkthrough_path = $WalkthroughPath
    }

    $list = [System.Collections.Generic.List[object]]::new(@($store.proposals))
    $list.Add([PSCustomObject]$proposal)
    $store.proposals = @($list)

    Set-ProposalStore -Store $store
    Write-Host ("Created Proposal #{0}: {1} (Plan State: suggested | Progress: undecided)" -f $newId, $Title) -ForegroundColor Green
    return [PSCustomObject]$proposal
}

function Set-WorkspaceProposalState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet('suggested', 'processed', 'approved', 'deferred', 'deleted', 'completed')]
        [string]$State,

        [string]$Details
    )

    $store = Get-ProposalStore
    $found = $null

    foreach ($p in $store.proposals) {
        if ($p.id -eq $Id) {
            $p.state = $State
            if ($Details) {
                $p.details = $Details
            }
            $found = $p
            break
        }
    }

    if (-not $found) {
        Write-Error "Proposal #$Id not found in proposals store."
        return $null
    }

    Set-ProposalStore -Store $store
    Write-Host ("Updated Proposal #{0} state to '{1}'." -f $Id, $State) -ForegroundColor Green
    return $found
}

function Set-WorkspaceProposalProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet('undecided', 'queued', 'in_progress', 'verification', 'committed', 'completed', 'pushed', 'blocked', 'failed')]
        [string]$ProgressState,

        [string]$Details
    )

    $store = Get-ProposalStore
    $found = $null

    foreach ($p in $store.proposals) {
        if ($p.id -eq $Id) {
            $p | Add-Member -NotePropertyName "progress_state" -NotePropertyValue $ProgressState -Force
            if ($ProgressState -in @('in_progress', 'queued', 'verification') -and $p.state -in @('completed', 'pushed')) {
                $p.state = 'suggested'
            }
            if ($Details) {
                $p.details = $Details
            }
            $found = $p
            break
        }
    }

    if (-not $found) {
        Write-Error "Proposal #$Id not found in proposals store."
        return $null
    }

    Set-ProposalStore -Store $store
    Write-Host ("Updated Proposal #{0} progress state to '{1}'." -f $Id, $ProgressState) -ForegroundColor Green
    return $found
}

function Set-WorkspaceProposalPriority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet('C', 'H', 'M', 'L', 'D')]
        [string]$Priority,

        [string]$Details
    )

    $store = Get-ProposalStore
    $found = $null

    foreach ($p in $store.proposals) {
        if ($p.id -eq $Id) {
            $p | Add-Member -NotePropertyName "priority" -NotePropertyValue $Priority -Force
            if ($Details) {
                $p.details = $Details
            }
            $found = $p
            break
        }
    }

    if (-not $found) {
        Write-Error "Proposal #$Id not found in proposals store."
        return $null
    }

    Set-ProposalStore -Store $store
    Write-Host ("Updated Proposal #{0} priority to '{1}'." -f $Id, $Priority) -ForegroundColor Green
    return $found
}

function Save-ProposalPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [string]$PlanContent = '',
        [string]$SourceFilePath = ''
    )

    $store = Get-ProposalStore
    $target = $store.proposals | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $target) {
        throw "Proposal #$Id not found."
    }

    $wiRoot = (Get-Item (Get-ProposalStorePath)).Directory.Parent.FullName
    $relPath = if ($target.plan_path) { $target.plan_path } else { "Workspace_Inventory/data/proposals/plans/Proposal-{0:D3}_Plan.md" -f $Id }
    $fullPath = Join-Path $wiRoot ($relPath -replace '^Workspace_Inventory[\\\/]', '')

    $dir = [System.IO.Path]::GetDirectoryName($fullPath)
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (-not [string]::IsNullOrWhiteSpace($SourceFilePath) -and (Test-Path -LiteralPath $SourceFilePath)) {
        Copy-Item -LiteralPath $SourceFilePath -Destination $fullPath -Force
    } elseif (-not [string]::IsNullOrWhiteSpace($PlanContent)) {
        Set-Content -LiteralPath $fullPath -Value $PlanContent -Encoding UTF8
    } else {
        throw "Either -PlanContent or -SourceFilePath must be provided."
    }

    Write-Host "Archived Proposal #$Id Implementation Plan to CM: $fullPath" -ForegroundColor Green
    return $fullPath
}

function Save-ProposalWalkthrough {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [string]$WalkthroughContent = '',
        [string]$SourceFilePath = ''
    )

    $store = Get-ProposalStore
    $target = $store.proposals | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $target) {
        throw "Proposal #$Id not found."
    }

    $wiRoot = (Get-Item (Get-ProposalStorePath)).Directory.Parent.FullName
    $relPath = if ($target.walkthrough_path) { $target.walkthrough_path } else { "Workspace_Inventory/data/proposals/plans/Proposal-{0:D3}_Walkthrough.md" -f $Id }
    $fullPath = Join-Path $wiRoot ($relPath -replace '^Workspace_Inventory[\\\/]', '')

    $dir = [System.IO.Path]::GetDirectoryName($fullPath)
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (-not [string]::IsNullOrWhiteSpace($SourceFilePath) -and (Test-Path -LiteralPath $SourceFilePath)) {
        Copy-Item -LiteralPath $SourceFilePath -Destination $fullPath -Force
    } elseif (-not [string]::IsNullOrWhiteSpace($WalkthroughContent)) {
        Set-Content -LiteralPath $fullPath -Value $WalkthroughContent -Encoding UTF8
    } else {
        throw "Either -WalkthroughContent or -SourceFilePath must be provided."
    }

    Write-Host "Archived Proposal #$Id Walkthrough to CM: $fullPath" -ForegroundColor Green
    return $fullPath
}

function Resolve-ProposalIdExpression {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Expression
    )

    $cleaned = $Expression.Trim().TrimStart('#').ToLowerInvariant()
    $store = Get-ProposalStore

    if ($cleaned -eq 'all') {
        return @($store.proposals | Where-Object { $_.state -in @('suggested', 'processed', 'deferred') } | Select-Object -ExpandProperty id)
    }

    $targetIds = [System.Collections.Generic.List[int]]::new()

    # Split by comma or space
    $parts = $cleaned -split '[, ]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($part in $parts) {
        $p = ($part.Trim() -replace '(?i)^#?crp-?', '').TrimStart('#')
        if ($p -match '^(\d+)-(\d+)$') {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]
            if ($start -le $end) {
                for ($i = $start; $i -le $end; $i++) {
                    if (-not $targetIds.Contains($i)) { $targetIds.Add($i) }
                }
            } else {
                for ($i = $start; $i -ge $end; $i--) {
                    if (-not $targetIds.Contains($i)) { $targetIds.Add($i) }
                }
            }
        } elseif ($p -match '^\d+$') {
            $id = [int]$p
            if (-not $targetIds.Contains($id)) { $targetIds.Add($id) }
        }
    }

    return @($targetIds)
}

function Invoke-ProposalBatchAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('do', 'delete', 'defer', 'complete', 'suggest')]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$TargetExpression,

        [string]$Details = ''
    )

    $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
    if ($targetIds.Count -eq 0) {
        Write-Warning ("No valid proposal IDs resolved from expression: '{0}'" -f $TargetExpression)
        return @()
    }

    $mappedState = switch ($Action) {
        'do'       { 'processed' }
        'delete'   { 'deleted' }
        'defer'    { 'deferred' }
        'complete' { 'completed' }
        'suggest'  { 'suggested' }
    }

    $updated = @()
    foreach ($id in $targetIds) {
        try {
            $res = Set-WorkspaceProposalState -Id $id -State $mappedState -Details $Details
            if ($Action -eq 'complete') {
                $res = Set-WorkspaceProposalProgress -Id $id -ProgressState 'completed' -Details $Details
            } elseif ($Action -eq 'do') {
                $res = Set-WorkspaceProposalProgress -Id $id -ProgressState 'in_progress' -Details $Details
            }
            $updated += $res
        } catch {
            Write-Warning $_.Exception.Message
        }
    }

    return $updated
}

function Set-ReviewGranularity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('coarse', 'tight')]
        [string]$Granularity
    )

    $store = Get-ProposalStore
    $store.review_granularity = $Granularity.ToLowerInvariant()
    Set-ProposalStore -Store $store
    Write-Host "Review granularity configured to: $($store.review_granularity)" -ForegroundColor Green
    return $store.review_granularity
}

function Get-ReviewGranularity {
    [CmdletBinding()]
    param()

    $store = Get-ProposalStore
    if ($store.review_granularity) {
        return $store.review_granularity
    }
    return 'coarse'
}

function Set-LCMMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('active', 'paused')]
        [string]$Mode
    )

    $store = Get-ProposalStore
    $store.lcm_mode = $Mode.ToLowerInvariant()
    Set-ProposalStore -Store $store
    Write-Host "LCM Mode configured to: $($store.lcm_mode)" -ForegroundColor Green
    return $store.lcm_mode
}

function Get-LCMMode {
    [CmdletBinding()]
    param()

    $store = Get-ProposalStore
    if ($store.lcm_mode) {
        return $store.lcm_mode
    }
    return 'active'
}

function Get-ReposUnderReview {
    [CmdletBinding()]
    param(
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $openProposals = Get-WorkspaceProposals -OpenOnly
    $repos = @(Get-ChildItem -Path $WorkspaceRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName '.git') })
    $results = @()

    $reviewsDir = Join-Path $WorkspaceRoot 'Workspace_Inventory\data\reviews'

    foreach ($r in $repos) {
        $repoPath = $r.FullName
        $repoName = $r.Name

        if ($repoName -eq 'Workspace_Inventory') {
            continue # Workspace_Inventory is exempt from visual BC reviews
        }

        $dirtyFiles = @(git -C $repoPath status --porcelain 2>$null)
        $isDirty = ($dirtyFiles.Count -gt 0)

        # Match proposals associated with this repo
        $matchingProps = @($openProposals | Where-Object { $_.origin_repo -eq $repoName })
        $propIds = if ($matchingProps.Count -gt 0) { ($matchingProps | ForEach-Object { "#$($_.id)" }) -join ', ' } else { '-' }

        # Check latest review record if available
        $latestReview = 'Pending Review'
        if (Test-Path $reviewsDir) {
            $revFiles = @(Get-ChildItem -Path $reviewsDir -Filter "REVIEW-$repoName-*.json" | Sort-Object LastWriteTime -Descending)
            if ($revFiles.Count -gt 0) {
                try {
                    $revData = Get-Content -Path $revFiles[0].FullName -Raw | ConvertFrom-Json
                    $latestReview = $revData.ReviewResult
                } catch { }
            }
        }

        if ($isDirty -or $matchingProps.Count -gt 0) {
            $commitStatus = if ($latestReview -eq 'Accepted' -or $latestReview -eq 'AcceptedWithEdits') {
                'Ready to Commit'
            } elseif ($latestReview -eq 'Deferred') {
                'Commit Deferred'
            } else {
                'Waiting for BC5 Review'
            }

            $results += [PSCustomObject]@{
                Repository        = $repoName
                DirtyFileCount    = $dirtyFiles.Count
                DirtyFiles        = $dirtyFiles
                Proposals         = $propIds
                BC5ReviewStatus   = $latestReview
                CommitStatus      = $commitStatus
                Path              = $repoPath
            }
        }
    }

    return $results
}

function Format-ProposalsTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Proposals
    )

    if ($null -eq $Proposals) {
        $Proposals = Get-WorkspaceProposals -OpenOnly
    }

    $granularity = Get-ReviewGranularity
    $mode = Get-LCMMode

    Write-Host "==========================================================================================" -ForegroundColor Cyan
    Write-Host (" LCM Workspace Proposals Ledger (Mode: {0} | Granularity: {1})" -f $mode.ToUpper(), $granularity.ToUpper()) -ForegroundColor Cyan
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    if (@($Proposals).Count -eq 0) {
        Write-Host " No open proposals currently tracked." -ForegroundColor Gray
        Write-Host "==========================================================================================" -ForegroundColor Cyan
        return
    }

    Write-Host (" {0,-7} | {1,-4} | {2,-19} | {3,-11} | {4,-13} | {5,-20} | {6}" -f 'CRP ID', 'Prio', 'Timestamp', 'Plan State', 'STATUS', 'Origin Repo', 'Title') -ForegroundColor Yellow
    Write-Host "---------+------+---------------------+-------------+---------------+----------------------+-----------------------" -ForegroundColor DarkGray

    foreach ($p in $Proposals) {
        $color = switch ($p.state) {
            'bug'       { [ConsoleColor]::Red }
            'suggested' { [ConsoleColor]::White }
            'processed' { [ConsoleColor]::Green }
            'approved'  { [ConsoleColor]::Green }
            'deferred'  { [ConsoleColor]::Yellow }
            'completed' { [ConsoleColor]::Cyan }
            'deleted'   { [ConsoleColor]::DarkGray }
            default     { [ConsoleColor]::Gray }
        }

        $idStr = "CRP-{0:D3}" -f [int]$p.id
        $prog = if ($p.progress_state) { $p.progress_state } else { 'undecided' }
        $prio = if ($p.priority) { $p.priority } else { 'M' }
        Write-Host (" {0,-7} | {1,-4} | {2,-19} | {3,-11} | {4,-13} | {5,-20} | {6}" -f $idStr, $prio, $p.timestamp, $p.state, $prog, $p.origin_repo, $p.title) -ForegroundColor $color
    }

    Write-Host "==========================================================================================" -ForegroundColor Cyan
}

function Format-ReposUnderReviewTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Repos
    )

    if ($null -eq $Repos) {
        $Repos = Get-ReposUnderReview
    }

    Write-Host "==========================================================================================" -ForegroundColor Cyan
    Write-Host " Repositories Under Review Queue" -ForegroundColor Cyan
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    if (@($Repos).Count -eq 0) {
        Write-Host " No repositories currently pending review or commit." -ForegroundColor Gray
        Write-Host "==========================================================================================" -ForegroundColor Cyan
        return
    }

    Write-Host (" {0,-22} | {1,-11} | {2,-12} | {3,-18} | {4}" -f 'Repository', 'Dirty Files', 'Proposals', 'BC5 Review Status', 'Commit Status') -ForegroundColor Yellow
    Write-Host "-----------------------+-------------+--------------+--------------------+----------------" -ForegroundColor DarkGray

    foreach ($r in $Repos) {
        $color = switch ($r.CommitStatus) {
            'Ready to Commit'       { [ConsoleColor]::Green }
            'Commit Deferred'       { [ConsoleColor]::Yellow }
            'Waiting for BC5 Review'{ [ConsoleColor]::Cyan }
            default                 { [ConsoleColor]::Gray }
        }

        Write-Host (" {0,-22} | {1,-11} | {2,-12} | {3,-18} | {4}" -f $r.Repository, "$($r.DirtyFileCount) file(s)", $r.Proposals, $r.BC5ReviewStatus, $r.CommitStatus) -ForegroundColor $color
    }

    Write-Host "==========================================================================================" -ForegroundColor Cyan
}

Set-Alias -Name Parse-ProposalIdExpression -Value Resolve-ProposalIdExpression

Export-ModuleMember -Function Get-ProposalStorePath, Get-ProposalStore, Set-ProposalStore, `
    Get-WorkspaceProposals, New-WorkspaceProposal, Set-WorkspaceProposalState, Set-WorkspaceProposalProgress, `
    Set-WorkspaceProposalPriority, Save-ProposalPlan, Save-ProposalWalkthrough, `
    Resolve-ProposalIdExpression, Invoke-ProposalBatchAction, `
    Set-ReviewGranularity, Get-ReviewGranularity, Set-LCMMode, Get-LCMMode, `
    Get-ReposUnderReview, Format-ProposalsTable, Format-ReposUnderReviewTable `
    -Alias Parse-ProposalIdExpression
