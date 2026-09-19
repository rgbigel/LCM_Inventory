# =====================================================================
# ProposalManager.psm1 - LCM Proposal & Two-Tier Review Governance Module
# =====================================================================
# Module: ProposalManager
# Purpose: Manages LCM proposal lifecycle (suggested -> processed -> deferred / completed / deleted),
#          batch operations, review granularity ('coarse' | 'tight'), repo review queue inspection,
#          and persistent ledger storage in Workspace_Inventory.
# Authors: Rolf, Workspace_AI Engine
# Version: 1.0.4
# Date: 2026-09-09
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
    $isBug = ($OriginRepo -eq 'bug') -or ($CrId -match '^BUG-') -or ($Title -match '\[BUG\]')
    $prefix = if ($isBug) { 'BUG' } else { 'CRP' }
    $canonicalId = "{0}-{1:D3}" -f $prefix, $newId
    $cleanCrId = if ($CrId) { $CrId } else { $canonicalId }
    $safeCrId = $cleanCrId -replace '[^a-zA-Z0-9_-]', '_'

    if ([string]::IsNullOrWhiteSpace($PlanPath)) {
        $PlanPath = "Workspace_Inventory/data/proposals/plans/Proposal-{0:D3}_{1}_Plan.md" -f $newId, $safeCrId
    }
    if ([string]::IsNullOrWhiteSpace($WalkthroughPath)) {
        $WalkthroughPath = "Workspace_Inventory/data/proposals/plans/Proposal-{0:D3}_{1}_Walkthrough.md" -f $newId, $safeCrId
    }

    $proposal = [ordered]@{
        id               = $newId
        crp_id           = $canonicalId
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
        $p = ($part.Trim() -replace '(?i)^#?(?:crp|bug)-?', '').TrimStart('#')
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

# =====================================================================
# CRP-135 Automated Regression & DAG Engine
# =====================================================================

function Test-RegressionTrigger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Proposal,
        [Parameter(Mandatory = $false)]
        [object[]]$AllProposals
    )

    $triggers = @()
    $isRegressionNeeded = $false

    # 1. Explicit Author Intent
    if ($Proposal.PSObject.Properties['regression_needed'] -and $Proposal.regression_needed -eq $true) {
        $triggers += 'Explicit author intent'
        $isRegressionNeeded = $true
    }

    # 2. Semantic Scope Filter (Global Workspace Scope)
    $scope = if ($Proposal.PSObject.Properties['origin_repo']) { $Proposal.origin_repo } else { '' }
    $title = if ($Proposal.PSObject.Properties['title']) { $Proposal.title } else { '' }
    $details = if ($Proposal.PSObject.Properties['details']) { $Proposal.details } else { '' }
    $combined = "$scope $title $details".ToLowerInvariant()

    if ($scope -in @('LCM', 'Workspace_AI') -or $combined -match '(all repositories|all child repos|workspace-wide|governance rule|\.agents/rules)') {
        $triggers += 'Global scope pattern detected'
        $isRegressionNeeded = $true
    }

    # 3. Active Dependency Overlap
    if ($AllProposals -and $AllProposals.Count -gt 0) {
        $activeProps = @($AllProposals | Where-Object { 
            $_.id -ne $Proposal.id -and $_.state -in @('bug', 'suggested', 'approved', 'processed') -and 
            $_.PSObject.Properties['regression_needed'] -and $_.regression_needed -eq $true 
        })
        if ($activeProps.Count -gt 0) {
            foreach ($ap in $activeProps) {
                if ($ap.origin_repo -eq $Proposal.origin_repo -and $Proposal.origin_repo -ne 'Workspace_Inventory') {
                    $triggers += "Active dependency overlap with CRP-$($ap.id) on repo '$($ap.origin_repo)'"
                    $isRegressionNeeded = $true
                }
            }
        }
    }

    return [PSCustomObject]@{
        ProposalId         = $Proposal.id
        RegressionNeeded   = $isRegressionNeeded
        RegressionTriggers = $triggers
    }
}

function Assert-RegressionSafety {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ParentProposalId,
        [Parameter(Mandatory = $false)]
        [int]$ProposedDepth = 1,
        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 2,
        [Parameter(Mandatory = $false)]
        [object[]]$AllProposals
    )

    if ($null -eq $AllProposals) {
        $store = Get-ProposalStore
        $AllProposals = @($store.proposals)
    }

    # 1. Max Regression Depth Guard (MaxRegressionDepth = 2)
    if ($ProposedDepth -gt $MaxDepth) {
        throw "MaxRegressionDepth limit ($MaxDepth) exceeded for Proposal #$ParentProposalId (Proposed Depth: $ProposedDepth). Regression cascade halted."
    }

    # 2. DAG Cycle Detection (A -> B -> A)
    $visited = New-Object 'System.Collections.Generic.HashSet[int]'
    $currId = $ParentProposalId
    [void]$visited.Add($currId)

    while ($currId -gt 0) {
        $parentProp = $AllProposals | Where-Object { $_.id -eq $currId }
        if ($null -eq $parentProp -or -not $parentProp.PSObject.Properties['parent_crp_id'] -or -not $parentProp.parent_crp_id) {
            break
        }
        
        $nextParentId = [int]$parentProp.parent_crp_id
        if ($visited.Contains($nextParentId)) {
            throw "Blocked_Cycle: Circular dependency detected in regression DAG between Proposal #$ParentProposalId and Parent #$nextParentId."
        }
        [void]$visited.Add($nextParentId)
        $currId = $nextParentId
    }

    return $true
}

function Get-RegressionDAGOrder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Proposals
    )

    if ($null -eq $Proposals) {
        $store = Get-ProposalStore
        $Proposals = @($store.proposals)
    }

    $nodes = @{}
    $inDegree = @{}
    $edges = @{}

    foreach ($p in $Proposals) {
        $nodes[$p.id] = $p
        $inDegree[$p.id] = 0
        $edges[$p.id] = @()
    }

    foreach ($p in $Proposals) {
        if ($p.PSObject.Properties['parent_crp_id'] -and $p.parent_crp_id) {
            $parentId = [int]$p.parent_crp_id
            if ($nodes.ContainsKey($parentId)) {
                $edges[$parentId] += $p.id
                $inDegree[$p.id] = $inDegree[$p.id] + 1
            }
        }
    }

    $queue = [System.Collections.Generic.Queue[int]]::new()
    foreach ($id in $nodes.Keys) {
        if ($inDegree[$id] -eq 0) {
            $queue.Enqueue($id)
        }
    }

    $topologicalOrder = @()
    while ($queue.Count -gt 0) {
        $curr = $queue.Dequeue()
        $topologicalOrder += $nodes[$curr]

        foreach ($dep in $edges[$curr]) {
            $inDegree[$dep] = $inDegree[$dep] - 1
            if ($inDegree[$dep] -eq 0) {
                $queue.Enqueue($dep)
            }
        }
    }

    if ($topologicalOrder.Count -ne $nodes.Count) {
        Write-Warning "Cycle detected in proposal graph. Some proposals have unresolved circular dependencies."
    }

    return $topologicalOrder
}

function New-ChildRegressionProposal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ParentProposalId,
        [Parameter(Mandatory = $true)]
        [string]$TargetRepo,
        [Parameter(Mandatory = $true)]
        [string]$Reason,
        [Parameter(Mandatory = $false)]
        [string]$Scope = 'tools',
        [Parameter(Mandatory = $false)]
        [int]$NegativePriorityIndex = -1,
        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 2
    )

    $store = Get-ProposalStore
    $allProps = @($store.proposals)
    $parentProp = $allProps | Where-Object { $_.id -eq $ParentProposalId }

    if (-not $parentProp) {
        throw "Parent proposal #$ParentProposalId not found."
    }

    $parentDepth = if ($parentProp.PSObject.Properties['regression_depth'] -and $parentProp.regression_depth) { [int]$parentProp.regression_depth } else { 0 }
    $childDepth = $parentDepth + 1

    Assert-RegressionSafety -ParentProposalId $ParentProposalId -ProposedDepth $childDepth -MaxDepth $MaxDepth -AllProposals $allProps

    $childTitle = "Regression: $TargetRepo for CRP-$ParentProposalId ($($parentProp.title))"
    $childDetails = "Automated downstream regression proposal for $TargetRepo. Triggered by CRP-${ParentProposalId}: $Reason"

    # Mint child proposal in 'suggested' state (OPEN progress state) per RULE-LCM-015
    $newProp = New-WorkspaceProposal -Title $childTitle -OriginRepo $TargetRepo -Details $childDetails -State 'suggested'

    # Set regression metadata
    $newProp | Add-Member -NotePropertyName 'parent_crp_id' -NotePropertyValue $ParentProposalId -Force
    $newProp | Add-Member -NotePropertyName 'regression_depth' -NotePropertyValue $childDepth -Force
    $newProp | Add-Member -NotePropertyName 'negative_priority' -NotePropertyValue $NegativePriorityIndex -Force
    $newProp | Add-Member -NotePropertyName 'max_regression_depth' -NotePropertyValue $MaxDepth -Force

    # Save to store
    $store = Get-ProposalStore
    $idx = $store.proposals.FindIndex([System.Predicate[object]]{ param($item) $item.id -eq $newProp.id })
    if ($idx -ge 0) {
        $store.proposals[$idx] = $newProp
    }
    Set-ProposalStore -Store $store

    Write-Host "Minted Child Regression Proposal #$($newProp.id) (Depth: $childDepth, Prio: $NegativePriorityIndex) for Parent CRP-$ParentProposalId on repo '$TargetRepo'." -ForegroundColor Green
    return $newProp
}

function Get-ReposUnderReview {
    [CmdletBinding()]
    param(
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $openProposals = Get-WorkspaceProposals -OpenOnly
    $repos = @()
    if (Test-Path (Join-Path $WorkspaceRoot '.git')) {
        $repos += (Get-Item $WorkspaceRoot)
    }
    $repos += @(Get-ChildItem -Path $WorkspaceRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName '.git') })
    $results = @()

    $reviewsDir = Join-Path $WorkspaceRoot 'Workspace_Inventory\data\reviews'

    foreach ($r in $repos) {
        $repoPath = $r.FullName
        $repoName = $r.Name

        $rawDirty = @(git -C $repoPath status --porcelain 2>$null)
        $dirtyFiles = @($rawDirty | Where-Object {
            $filePath = $_.Substring(3).Trim()
            -not ($filePath -like "data/logs/*" -or $filePath -like "data\logs\*" -or
                  $filePath -like "logs/*" -or $filePath -like "logs\*" -or
                  $filePath -like ".lcm/logs/*" -or $filePath -like ".lcm\logs\*" -or
                  $filePath -like "scratch/*" -or $filePath -like "scratch\*" -or
                  $filePath -like ".lcm/scratch/*" -or $filePath -like ".lcm\scratch\*")
        })

        # Path-aware review discrimination for Workspace_Inventory per CRP-054 / RULE-LCM-004
        if ($repoName -eq 'Workspace_Inventory') {
            # Filter out auto-accepted dynamic data (data/, logs/, scratch/) per RULE-EFF-001
            $dirtyFiles = @($dirtyFiles | Where-Object {
                $filePath = $_.Substring(3).Trim()
                -not ($filePath -like "data/*" -or $filePath -like "data\*")
            })
        }

        $isDirty = ($dirtyFiles.Count -gt 0)

        # Match proposals associated with this repo
        $matchingProps = @($openProposals | Where-Object { $_.origin_repo -eq $repoName })
        $propIds = if ($matchingProps.Count -gt 0) { ($matchingProps | ForEach-Object { "#$($_.id)" }) -join ', ' } else { '-' }

        if ($repoName -eq 'Workspace_Inventory' -and -not $isDirty -and $matchingProps.Count -eq 0) {
            continue
        }

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
            $commitStatus = if ($latestReview -in @('Accepted', 'AcceptedWithEdits', 'AcceptedAll')) {
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

        $idStr = if ($null -ne $p.PSObject.Properties['crp_id'] -and $p.crp_id) { $p.crp_id } else { if (($null -ne $p.PSObject.Properties['state'] -and $p.state -eq 'bug') -or ($null -ne $p.PSObject.Properties['cr_id'] -and $p.cr_id.StartsWith('BUG-'))) { "BUG-{0:D3}" -f [int]$p.id } else { "CRP-{0:D3}" -f [int]$p.id } }
        $prog = if ($null -ne $p.PSObject.Properties['progress_state'] -and $p.progress_state) { $p.progress_state } else { 'undecided' }
        $prio = if ($null -ne $p.PSObject.Properties['priority'] -and $p.priority) { $p.priority } else { 'M' }
        $ts = if ($null -ne $p.PSObject.Properties['timestamp'] -and $p.timestamp) { $p.timestamp } elseif ($null -ne $p.PSObject.Properties['dates'] -and $null -ne $p.dates.PSObject.Properties['created']) { $p.dates.created } else { '-' }
        $scope = if ($null -ne $p.PSObject.Properties['origin_repo'] -and $p.origin_repo) { $p.origin_repo } else { 'LCM' }
        $pState = if ($null -ne $p.PSObject.Properties['state'] -and $p.state) { $p.state } else { 'suggested' }
        $title = if ($null -ne $p.PSObject.Properties['title'] -and $p.title) { $p.title } else { '' }
        Write-Host (" {0,-7} | {1,-4} | {2,-19} | {3,-11} | {4,-13} | {5,-20} | {6}" -f $idStr, $prio, $ts, $pState, $prog, $scope, $title) -ForegroundColor $color
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

    if ($null -eq $Repos -or @($Repos).Length -eq 0 -or (@($Repos).Length -eq 1 -and $null -eq @($Repos)[0])) {
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
    Test-RegressionTrigger, Assert-RegressionSafety, Get-RegressionDAGOrder, New-ChildRegressionProposal, `
    Get-ReposUnderReview, Format-ProposalsTable, Format-ReposUnderReviewTable `
    -Alias Parse-ProposalIdExpression
