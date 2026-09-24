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
        [string]$WalkthroughPath = '',
        [string]$AppId = '',
        [string]$PrimaryApp = '',
        [string[]]$AffectedApps = @(),
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
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

    # Active App Context Inheritance per RULE-LCM-019
    $activeCtx = Get-ActiveAppContext
    if ([string]::IsNullOrWhiteSpace($AppId) -and $activeCtx -and $activeCtx.app_id -and $activeCtx.app_id -ne 'Architecture') {
        $AppId = $activeCtx.app_id
    }

    # CRP-162 Proposal Bundle Directory Standard
    $cleanSlug = ($Title -replace '[^a-zA-Z0-9]', '-') -replace '-+', '-' -replace '^-|-$', ''
    if ($cleanSlug.Length -gt 50) { $cleanSlug = $cleanSlug.Substring(0, 50).TrimEnd('-') }
    $bundleDirName = "{0}-{1}" -f $canonicalId, $cleanSlug
    $bundleRelPath = "docs/Proposals/$bundleDirName"

    $targetRepoDir = if ($OriginRepo -and (Test-Path (Join-Path $WorkspaceRoot $OriginRepo))) {
        Join-Path $WorkspaceRoot $OriginRepo
    } else {
        Join-Path $WorkspaceRoot 'Workspace_Inventory'
    }

    $bundleFullPath = Join-Path $targetRepoDir "docs\Proposals\$bundleDirName"
    if (-not (Test-Path $bundleFullPath)) {
        New-Item -ItemType Directory -Path $bundleFullPath -Force | Out-Null
    }

    # 1. Specification.md
    $specPath = Join-Path $bundleFullPath 'Specification.md'
    if (-not (Test-Path $specPath)) {
        $appDisplay = if ($AppId) { $AppId } else { "None" }
        $specContent = @"
# Change Request Proposal: $canonicalId

```yaml
CRP-ID: $canonicalId
Title: $Title
Scope: $OriginRepo
Baseline-Version: v7.6.0
Author: $Author
Date: $timestamp
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: $appDisplay
```

---

## 1. Executive Summary & Intent
$Details

## 2. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.

"@
        Set-Content -Path $specPath -Value $specContent.Trim() -Encoding UTF8
    }

    # 2. Implementation_Plan.md
    $planFilePath = Join-Path $bundleFullPath 'Implementation_Plan.md'
    if (-not (Test-Path $planFilePath)) {
        $planContent = @"
# Implementation Plan: $canonicalId - $Title

## 1. Executive Summary & Problem Context
$Details

## 2. Proposed Changes
### Component 1: Initial Implementation
- Scaffolding baseline implementation for $Title.

## 3. Verification Plan
- Automated Pester tests and readiness quality gates.

"@
        Set-Content -Path $planFilePath -Value $planContent.Trim() -Encoding UTF8
    }

    # 3. Walkthrough.md
    $walkFilePath = Join-Path $bundleFullPath 'Walkthrough.md'
    if (-not (Test-Path $walkFilePath)) {
        $walkContent = @"
# Walkthrough: $canonicalId - $Title

## 1. Executive Summary
Implementation and verification records for $canonicalId.

## 2. Verification Evidence
- Pending implementation execution.

"@
        Set-Content -Path $walkFilePath -Value $walkContent.Trim() -Encoding UTF8
    }

    if ([string]::IsNullOrWhiteSpace($PlanPath)) {
        $PlanPath = "$bundleRelPath/Implementation_Plan.md"
    }
    if ([string]::IsNullOrWhiteSpace($WalkthroughPath)) {
        $WalkthroughPath = "$bundleRelPath/Walkthrough.md"
    }

    $proposal = [ordered]@{
        id               = $newId
        crp_id           = $canonicalId
        timestamp        = $timestamp
        title            = $Title
        origin_repo      = $OriginRepo
        cr_id            = $cleanCrId
        app_id           = if ($AppId) { $AppId } else { $null }
        primary_app      = if ($PrimaryApp) { $PrimaryApp } elseif ($isBug -and $AppId) { $AppId } else { $null }
        affected_apps    = if ($AffectedApps.Count -gt 0) { @($AffectedApps) } else { @() }
        state            = 'suggested'
        progress_state   = 'undecided'
        bundle_id        = $BundleId
        bundle_dir       = $bundleRelPath
        docs             = [ordered]@{
            specification = 'Specification.md'
            plan          = 'Implementation_Plan.md'
            walkthrough   = 'Walkthrough.md'
        }
        commit_sha       = $null
        github_url       = $null
        author           = if ($Author) { $Author } else { 'Rolf' }
        details          = $Details
        plan_path        = $PlanPath
        walkthrough_path = $WalkthroughPath
    }

    $list = [System.Collections.Generic.List[object]]::new(@($store.proposals))
    $list.Add([PSCustomObject]$proposal)
    $store.proposals = @($list)

    Set-ProposalStore -Store $store
    $appSuffix = if ($AppId) { " | App: $AppId" } else { "" }
    Write-Host ("Created Proposal #{0}: {1} (Plan State: suggested | Progress: undecided{2})" -f $newId, $Title, $appSuffix) -ForegroundColor Green
    return [PSCustomObject]$proposal
}

function Set-WorkspaceProposalState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet('bug', 'suggested', 'processed', 'approved', 'deferred', 'deleted', 'completed', 'rejected', 'pushed')]
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
        [ValidateSet('do', 'delete', 'defer', 'deferred', 'complete', 'completed', 'suggest', 'suggested', 'reject', 'rejected', 'approve', 'approved', 'bug', 'push', 'pushed')]
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
        'do'                                  { 'processed' }
        'delete'                              { 'deleted' }
        { $_ -in @('defer', 'deferred') }     { 'deferred' }
        { $_ -in @('complete', 'completed') } { 'completed' }
        { $_ -in @('suggest', 'suggested') }   { 'suggested' }
        { $_ -in @('reject', 'rejected') }    { 'rejected' }
        { $_ -in @('approve', 'approved') }   { 'approved' }
        'bug'                                 { 'bug' }
        { $_ -in @('push', 'pushed') }        { 'pushed' }
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
# CRP-162 Proposal Bundle Directory Architecture & Git Object Resolver
# =====================================================================

function Get-LcmProposalDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [int]$Id,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet('Specification', 'Plan', 'Walkthrough', 'All')]
        [string]$DocumentType = 'Specification',

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $store = Get-ProposalStore
    $proposal = $store.proposals | Where-Object { $_.id -eq $Id } | Select-Object -First 1

    if (-not $proposal) {
        Write-Warning "Proposal #$Id not found in proposals store."
        return $null
    }

    $repoName = if ($proposal.origin_repo -and (Test-Path (Join-Path $WorkspaceRoot $proposal.origin_repo))) {
        $proposal.origin_repo
    } else {
        'Workspace_Inventory'
    }
    $repoDir = Join-Path $WorkspaceRoot $repoName

    $docFileMap = @{
        'Specification' = 'Specification.md'
        'Plan'          = 'Implementation_Plan.md'
        'Walkthrough'   = 'Walkthrough.md'
    }

    $filesToFetch = if ($DocumentType -eq 'All') {
        @('Specification', 'Plan', 'Walkthrough')
    } else {
        @($DocumentType)
    }

    $results = @{}

    foreach ($dtype in $filesToFetch) {
        $fileName = $docFileMap[$dtype]
        $content = $null
        $sourceMode = 'None'
        $resolvedPath = ''

        # 1. Mode 1: Check live bundle directory on disk
        if ($proposal.PSObject.Properties['bundle_dir'] -and $proposal.bundle_dir) {
            $localBundleDir = Join-Path $repoDir $proposal.bundle_dir
            $localFilePath = Join-Path $localBundleDir $fileName
            if (Test-Path $localFilePath) {
                $content = Get-Content -Path $localFilePath -Raw -Encoding UTF8
                $sourceMode = 'LiveWorkingTree'
                $resolvedPath = $localFilePath
            }
        }

        # 2. Mode 2: If absent on disk, check local Git object database using commit_sha
        if ($null -eq $content -and $proposal.PSObject.Properties['commit_sha'] -and $proposal.commit_sha -and (Test-Path (Join-Path $repoDir '.git'))) {
            $bundleRel = if ($proposal.bundle_dir) { $proposal.bundle_dir.TrimStart('\', '/') } else { "docs/Proposals/$($proposal.crp_id)" }
            $gitPath = "$bundleRel/$fileName" -replace '\\', '/'
            $sha = $proposal.commit_sha

            try {
                $gitOutput = & git -C $repoDir show "${sha}:${gitPath}" 2>$null
                if ($LASTEXITCODE -eq 0 -and $gitOutput) {
                    $content = $gitOutput -join "`r`n"
                    $sourceMode = 'GitObject'
                    $resolvedPath = "git://${sha}:${gitPath}"
                }
            } catch {
                # Continue to next fallback
            }
        }

        # 3. Mode 3: Legacy flat file fallback
        if ($null -eq $content) {
            $legacyPath = switch ($dtype) {
                'Plan' { if ($proposal.PSObject.Properties['plan_path']) { $proposal.plan_path } else { '' } }
                'Walkthrough' { if ($proposal.PSObject.Properties['walkthrough_path']) { $proposal.walkthrough_path } else { '' } }
                'Specification' {
                    $propsDir = Join-Path $repoDir 'docs\Proposals'
                    if (Test-Path $propsDir) {
                        $match = Get-ChildItem -Path $propsDir -Filter "$($proposal.crp_id)*.md" | Select-Object -First 1
                        if ($match) { $match.FullName } else { '' }
                    } else { '' }
                }
            }

            if ($legacyPath) {
                $fullLegacyPath = if ([System.IO.Path]::IsPathRooted($legacyPath)) { $legacyPath } else { Join-Path $WorkspaceRoot $legacyPath }
                if (Test-Path $fullLegacyPath) {
                    $content = Get-Content -Path $fullLegacyPath -Raw -Encoding UTF8
                    $sourceMode = 'LegacyFlatDisk'
                    $resolvedPath = $fullLegacyPath
                }
            }
        }

        $results[$dtype] = [PSCustomObject]@{
            Id           = $Id
            CrpId        = $proposal.crp_id
            DocumentType = $dtype
            FileName     = $fileName
            SourceMode   = $sourceMode
            ResolvedPath = $resolvedPath
            Content      = if ($content) { $content } else { "<!-- Document not found for $dtype in Proposal #$Id -->" }
            Found        = ($null -ne $content)
        }
    }

    if ($DocumentType -eq 'All') {
        return $results
    } else {
        return $results[$DocumentType]
    }
}

function Remove-LcmProposalBundle {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [int]$Id,

        [Parameter(Mandatory = $false)]
        [string]$CommitSha = '',

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $store = Get-ProposalStore
    $proposal = $store.proposals | Where-Object { $_.id -eq $Id } | Select-Object -First 1

    if (-not $proposal) {
        Write-Warning "Proposal #$Id not found in proposals store."
        return $null
    }

    $repoName = if ($proposal.origin_repo -and (Test-Path (Join-Path $WorkspaceRoot $proposal.origin_repo))) {
        $proposal.origin_repo
    } else {
        'Workspace_Inventory'
    }
    $repoDir = Join-Path $WorkspaceRoot $repoName

    # 1. Capture commit SHA if not provided
    if ([string]::IsNullOrWhiteSpace($CommitSha) -and (Test-Path (Join-Path $repoDir '.git'))) {
        $capturedSha = & git -C $repoDir rev-parse HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $capturedSha) {
            $CommitSha = $capturedSha.Trim()
        }
    }

    # 2. Update proposal record in ledger
    if ($CommitSha) {
        $proposal | Add-Member -NotePropertyName "commit_sha" -NotePropertyValue $CommitSha -Force
        $bundleRel = if ($proposal.PSObject.Properties['bundle_dir'] -and $proposal.bundle_dir) { $proposal.bundle_dir } else { "docs/Proposals/$($proposal.crp_id)" }
        $shortSha = $CommitSha.Substring(0, [Math]::Min(7, $CommitSha.Length))
        $githubUrl = "https://github.com/rgbig/$repoName/tree/$shortSha/$bundleRel" -replace '\\', '/'
        $proposal | Add-Member -NotePropertyName "github_url" -NotePropertyValue $githubUrl -Force
    }

    # 3. Purge local working tree bundle directory
    $purged = $false
    if ($proposal.PSObject.Properties['bundle_dir'] -and $proposal.bundle_dir) {
        $localBundleDir = Join-Path $repoDir $proposal.bundle_dir
        if (Test-Path $localBundleDir) {
            if ($PSCmdlet.ShouldProcess($localBundleDir, "Purge pushed proposal bundle from working tree")) {
                Remove-Item -Path $localBundleDir -Recurse -Force | Out-Null
                $purged = $true
                Write-Host ("  [+] Purged local working tree bundle: {0}" -f $proposal.bundle_dir) -ForegroundColor Green
            }
        }
    }

    Set-ProposalStore -Store $store

    return [PSCustomObject]@{
        Id        = $Id
        CrpId     = $proposal.crp_id
        Repo      = $repoName
        CommitSha = $CommitSha
        GithubUrl = if ($proposal.PSObject.Properties['github_url']) { $proposal.github_url } else { $null }
        Purged    = $purged
    }
}

# =====================================================================
# CRP-048 App-Centric Architecture, Active Context Engine & Catalog
# =====================================================================

function Get-ActiveAppContext {
    [CmdletBinding()]
    param()

    $store = Get-ProposalStore
    if ($store.PSObject.Properties['active_context'] -and $store.active_context) {
        return $store.active_context
    }
    return $null
}

function Set-ActiveAppContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Context = '',

        [Parameter(Mandatory = $false)]
        [string]$Repo = '',

        [Parameter(Mandatory = $false)]
        [string]$Details = '',

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $store = Get-ProposalStore
    $trimmed = if ($Context) { $Context.Trim() } else { '' }

    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed -in @('clear', 'reset', 'none', 'null')) {
        $store | Add-Member -NotePropertyName 'active_context' -NotePropertyValue $null -Force
        Set-ProposalStore -Store $store

        $wiDataDir = (Get-Item (Get-ProposalStorePath)).Directory.Parent.FullName
        $sessionDir = Join-Path $wiDataDir 'session_state'
        if (-not (Test-Path $sessionDir)) { New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null }
        $sessionFile = Join-Path $sessionDir 'active_session.json'
        @{
            active_context = $null
            updated_at     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        } | ConvertTo-Json -Depth 3 | Set-Content -Path $sessionFile -Encoding UTF8

        Write-Host "Active App Context cleared. Current focus: 🏛️ Master Architecture (Governing All Apps)." -ForegroundColor Green
        return $null
    }

    if ($trimmed -in @('Master', 'Architecture', 'Base', 'Root', '0', 'App: 0', 'A0')) {
        $targetRepo = if ($Repo) { $Repo } else { 'Workspace_AI' }
        $appId = if ($trimmed -eq 'Architecture') { 'Architecture' } else { 'Master' }
        $appTitle = if ($trimmed -eq 'Architecture') { 'Foundational Tripartite Architecture' } else { 'Master Tripartite Architecture (Governing All Apps)' }
        $ctxObj = [ordered]@{
            app_id     = $appId
            app_number = 0
            app_title  = $appTitle
            repo       = $targetRepo
            set_at     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            details    = $Details
        }
        $store | Add-Member -NotePropertyName 'active_context' -NotePropertyValue ([PSCustomObject]$ctxObj) -Force
        Set-ProposalStore -Store $store

        $wiDataDir = (Get-Item (Get-ProposalStorePath)).Directory.Parent.FullName
        $sessionDir = Join-Path $wiDataDir 'session_state'
        if (-not (Test-Path $sessionDir)) { New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null }
        $sessionFile = Join-Path $sessionDir 'active_session.json'
        @{
            active_context = $ctxObj
            updated_at     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        } | ConvertTo-Json -Depth 3 | Set-Content -Path $sessionFile -Encoding UTF8

        Write-Host ("Active App Context set to: 🏛️ Master Architecture (Governing All Apps) [{0}]" -f $targetRepo) -ForegroundColor Green
        return [PSCustomObject]$ctxObj
    }

    # Normalize App identifier: 'A1', '1', 'App: 1', 'App 1', 'App: 1 - Title'
    $appNum = $null
    $appTitle = ''
    if ($trimmed -match '^(?i)(?:App:?\s*|A)?(\d+)(?:\s*-\s*(.+))?$') {
        $appNum = [int]$Matches[1]
        if ($Matches.Count -ge 3 -and $Matches[2]) {
            $appTitle = $Matches[2].Trim()
        }
    }

    $appId = if ($appNum -ne $null) { "App: $appNum" } else { $trimmed }

    # If title wasn't passed in context string, look up in catalog or tripartite docs
    $targetRepo = if ($Repo) { $Repo } else { 'Workspace_AI' }
    if ([string]::IsNullOrWhiteSpace($appTitle) -and $appNum -ne $null) {
        $catalog = @(Get-LcmApps -Repo $targetRepo -WorkspaceRoot $WorkspaceRoot)
        $found = @($catalog | Where-Object { $_.number -eq $appNum })
        if ($found.Count -gt 0) {
            $appTitle = $found[0].title
        }
    }

    $ctxObj = [ordered]@{
        app_id     = $appId
        app_number = $appNum
        app_title  = $appTitle
        repo       = $targetRepo
        set_at     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        details    = $Details
    }

    $store | Add-Member -NotePropertyName 'active_context' -NotePropertyValue ([PSCustomObject]$ctxObj) -Force
    Set-ProposalStore -Store $store

    $wiDataDir = (Get-Item (Get-ProposalStorePath)).Directory.Parent.FullName
    $sessionDir = Join-Path $wiDataDir 'session_state'
    if (-not (Test-Path $sessionDir)) { New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null }
    $sessionFile = Join-Path $sessionDir 'active_session.json'
    @{
        active_context = $ctxObj
        updated_at     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    } | ConvertTo-Json -Depth 3 | Set-Content -Path $sessionFile -Encoding UTF8

    $displayTitle = if ($appTitle) { " - $appTitle" } else { '' }
    Write-Host ("Active App Context set to: {0}{1} [{2}]" -f $appId, $displayTitle, $targetRepo) -ForegroundColor Green
    return [PSCustomObject]$ctxObj
}

function Get-LcmApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Repo = '',

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $targetRepos = @()
    if ($Repo) {
        $rPath = Join-Path $WorkspaceRoot $Repo
        if (Test-Path $rPath) {
            $targetRepos += [PSCustomObject]@{ Name = $Repo; Path = $rPath }
        }
    } else {
        $dirs = Get-ChildItem -Path $WorkspaceRoot -Directory | Where-Object { 
            (Test-Path (Join-Path $_.FullName 'docs')) -or (Test-Path (Join-Path $_.FullName '.git'))
        }
        foreach ($d in $dirs) {
            $targetRepos += [PSCustomObject]@{ Name = $d.Name; Path = $d.FullName }
        }
    }

    $allApps = @()

    foreach ($r in $targetRepos) {
        $docsDir = Join-Path $r.Path 'docs'
        if (!(Test-Path $docsDir)) {
            continue
        }
        $archPath = Join-Path $docsDir 'Architecture.md'
        $implPath = Join-Path $docsDir 'Implementation.md'
        $reqPath  = Join-Path $docsDir 'Requirements.md'

        $archOk = Test-Path $archPath
        $implOk = Test-Path $implPath
        $reqOk  = Test-Path $reqPath

        # 0. Include Master Tripartite Architecture Entry for the repository
        if ($archOk -or $implOk -or $reqOk) {
            $masterTitle = "Master Tripartite Architecture (Governing All Apps)"
            if ($archOk) {
                $topLines = @(Get-Content -Path $archPath -TotalCount 5 -Encoding UTF8 | Where-Object { $_ -match '^#\s+' })
                if ($topLines.Count -gt 0 -and $topLines[0] -match '^#\s+(.+)$') {
                    $rawH1 = $Matches[1].Trim()
                    if ($rawH1 -notmatch '(?i)App:') {
                        $masterTitle = "Master Architecture - $rawH1"
                    }
                }
            }

            $masterEntry = [ordered]@{
                id           = 'Master'
                number       = 0
                title        = $masterTitle
                repo         = $r.Name
                doc_layout   = 'MasterRoot'
                directory    = 'docs/'
                arch_defined = $archOk
                req_defined  = $reqOk
                impl_defined = $implOk
                is_master    = $true
                constituents = @()
            }
            $allApps += [PSCustomObject]$masterEntry
        }

        $appMap = @{}

        # 1. Scan directory-separated App documents under docs/App#*/ or legacy docs/App-*/
        $appsSubDirs = @()
        if (Test-Path $docsDir) {
            $directAppDirs = @(Get-ChildItem -Path $docsDir -Directory | Where-Object { $_.Name -match '^(?i)App[#-]?\d+' -and $_.Name -ne 'apps' })
            $appsSubDirs += $directAppDirs
            $appsBaseDir = Join-Path $docsDir 'apps'
            if (Test-Path $appsBaseDir) {
                $appsSubDirs += @(Get-ChildItem -Path $appsBaseDir -Directory)
            }
        }

        foreach ($sd in $appsSubDirs) {
            $num = $null
            $folderTitle = ''
            if ($sd.Name -match '^(?i)App[#-]?(\d+)(?:-(.*))?$') {
                $num = [int]$Matches[1]
                if ($Matches.Count -ge 3 -and $Matches[2]) { $folderTitle = $Matches[2].Trim() }
            } elseif ($sd.Name -match '^\d+$') {
                $num = [int]$sd.Name
            }

            if ($num -ne $null) {
                $subArch = Join-Path $sd.FullName 'Architecture.md'
                $subReq  = Join-Path $sd.FullName 'Requirements.md'
                $subImpl = Join-Path $sd.FullName 'Implementation.md'

                $archOk = Test-Path $subArch
                $reqOk  = Test-Path $subReq
                $implOk = Test-Path $subImpl

                $title = if ($folderTitle) { $folderTitle } else { "App $num" }

                # Extract title from Architecture.md or Implementation.md if available
                if ($archOk) {
                    $firstLine = (Get-Content -Path $subArch -TotalCount 5 -Encoding UTF8 | Where-Object { $_ -match '^#\s+' } | Select-Object -First 1)
                    if ($firstLine -match '(?i)^#\s+(?:App:\s*\d+\s*-\s*)?(.+?)(?:\s+Architecture)?$') {
                        $title = $Matches[1].Trim()
                    }
                }

                $constituents = @()
                if ($implOk) {
                    $implContent = Get-Content -Path $subImpl -Raw -Encoding UTF8
                    $implLines = $implContent -split '\r?\n'
                    $inManifest = $false
                    foreach ($line in $implLines) {
                        if ($line -match '(?i)Constituent Manifest') {
                            $inManifest = $true
                        } elseif ($inManifest -and $line -match '^\|\s*([^\|]+)\|\s*([^\|]+)\|\s*([^\|]+)\|\s*([^\|]+)\|') {
                            $cPath = $Matches[1].Trim()
                            $cRole = $Matches[2].Trim()
                            $cEntry = $Matches[3].Trim()
                            $cTest = $Matches[4].Trim()
                            if ($cPath -notmatch '^:?-+:?$' -and $cPath -notmatch '(?i)Relative Path' -and $cPath -notmatch '^[\|\s:-]+$') {
                                $constituents += [PSCustomObject]@{
                                    Path        = $cPath
                                    Role        = $cRole
                                    Entrypoints = $cEntry
                                    TestSuite   = $cTest
                                }
                            }
                        } elseif ($line -match '^#{2,3}\s+' -and $inManifest) {
                            $inManifest = $false
                        }
                    }
                }

                $relDir = $sd.FullName.Substring($r.Path.Length).TrimStart('\', '/')
                $appMap[$num] = [ordered]@{
                    id           = "App: $num"
                    number       = $num
                    title        = $title
                    repo         = $r.Name
                    doc_layout   = 'Directory'
                    directory    = $relDir
                    arch_defined = $archOk
                    req_defined  = $reqOk
                    impl_defined = $implOk
                    constituents = $constituents
                }
            }
        }

        # 2. Scan in-document sections from root Architecture.md
        if (Test-Path $archPath) {
            $archLines = Get-Content -Path $archPath -Encoding UTF8
            foreach ($line in $archLines) {
                if ($line -match '(?i)^#{2,3}\s+App:\s*(\d+)\s*-\s*(.+)$') {
                    $num = [int]$Matches[1]
                    $title = $Matches[2].Trim()
                    if (-not $appMap.ContainsKey($num)) {
                        $appMap[$num] = [ordered]@{
                            id           = "App: $num"
                            number       = $num
                            title        = $title
                            repo         = $r.Name
                            doc_layout   = 'InDocument'
                            directory    = 'docs/'
                            arch_defined = $true
                            req_defined  = $false
                            impl_defined = $false
                            constituents = @()
                        }
                    } else {
                        $appMap[$num].arch_defined = $true
                    }
                }
            }
        }

        # 3. Scan in-document sections from root Requirements.md
        if (Test-Path $reqPath) {
            $reqLines = Get-Content -Path $reqPath -Encoding UTF8
            foreach ($line in $reqLines) {
                if ($line -match '(?i)^#{2,3}\s+App:\s*(\d+)') {
                    $num = [int]$Matches[1]
                    if ($appMap.ContainsKey($num)) {
                        $appMap[$num].req_defined = $true
                    } else {
                        $title = if ($line -match '(?i)^#{2,3}\s+App:\s*\d+\s*-\s*(.+)$') { $Matches[1].Trim() } else { "App $num" }
                        $appMap[$num] = [ordered]@{
                            id           = "App: $num"
                            number       = $num
                            title        = $title
                            repo         = $r.Name
                            doc_layout   = 'InDocument'
                            directory    = 'docs/'
                            arch_defined = $false
                            req_defined  = $true
                            impl_defined = $false
                            constituents = @()
                        }
                    }
                }
            }
        }

        # 4. Scan in-document sections from root Implementation.md
        if (Test-Path $implPath) {
            $implContent = Get-Content -Path $implPath -Raw -Encoding UTF8
            $implLines = $implContent -split '\r?\n'
            $currentAppNum = $null
            $inManifest = $false

            foreach ($line in $implLines) {
                if ($line -match '(?i)^#{2,3}\s+App:\s*(\d+)') {
                    $currentAppNum = [int]$Matches[1]
                    $inManifest = $false
                    if ($appMap.ContainsKey($currentAppNum)) {
                        $appMap[$currentAppNum].impl_defined = $true
                    } else {
                        $title = if ($line -match '(?i)^#{2,3}\s+App:\s*\d+\s*-\s*(.+)$') { $Matches[1].Trim() } else { "App $currentAppNum" }
                        $appMap[$currentAppNum] = [ordered]@{
                            id           = "App: $currentAppNum"
                            number       = $currentAppNum
                            title        = $title
                            repo         = $r.Name
                            doc_layout   = 'InDocument'
                            directory    = 'docs/'
                            arch_defined = $false
                            req_defined  = $false
                            impl_defined = $true
                            constituents = @()
                        }
                    }
                } elseif ($currentAppNum -ne $null -and $line -match '(?i)Constituent Manifest') {
                    $inManifest = $true
                } elseif ($inManifest -and $line -match '^\|\s*([^\|]+)\|\s*([^\|]+)\|\s*([^\|]+)\|\s*([^\|]+)\|') {
                    $cPath = $Matches[1].Trim()
                    $cRole = $Matches[2].Trim()
                    $cEntry = $Matches[3].Trim()
                    $cTest = $Matches[4].Trim()
                    if ($cPath -notmatch '^:?-+:?$' -and $cPath -notmatch '(?i)Relative Path' -and $cPath -notmatch '^[\|\s:-]+$') {
                        $appMap[$currentAppNum].constituents += [PSCustomObject]@{
                            Path        = $cPath
                            Role        = $cRole
                            Entrypoints = $cEntry
                            TestSuite   = $cTest
                        }
                    }
                } elseif ($line -match '^#{2,3}\s+') {
                    $inManifest = $false
                }
            }
        }

        # 5. Scan code files in repo for DOX header `App: App: # - <Title>`
        $codeFiles = @(Get-ChildItem -Path $r.Path -Recurse -Include *.ps1, *.psm1, *.js, *.py -ErrorAction SilentlyContinue | Where-Object {
            $_.FullName -notmatch '[\\/](\.git|\.agents|data|logs|scratch|node_modules)[\\/]'
        })
        foreach ($cf in $codeFiles) {
            $first20 = @(Get-Content -Path $cf.FullName -TotalCount 25 -ErrorAction SilentlyContinue)
            foreach ($line in $first20) {
                if ($line -match '(?i)\bApp:\s*(?:App:\s*)?(\d+)(?:\s*-\s*(.+))?') {
                    $num = [int]$Matches[1]
                    $rel = $cf.FullName.Substring($r.Path.Length).TrimStart('\', '/')
                    if ($appMap.ContainsKey($num)) {
                        $existingPaths = @($appMap[$num].constituents | ForEach-Object { $_.Path })
                        if ($existingPaths -notcontains $rel) {
                            $appMap[$num].constituents += [PSCustomObject]@{
                                Path        = $rel
                                Role        = 'Source / Asset'
                                Entrypoints = '-'
                                TestSuite   = '-'
                            }
                        }
                    }
                }
            }
        }

        foreach ($k in ($appMap.Keys | Sort-Object)) {
            $allApps += [PSCustomObject]$appMap[$k]
        }
    }

    return $allApps
}

function Sync-LcmAppCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Repo = '',

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $catalogDir = Join-Path $WorkspaceRoot 'Workspace_Inventory\data\catalog'
    if (-not (Test-Path $catalogDir)) {
        New-Item -ItemType Directory -Path $catalogDir -Force | Out-Null
    }

    $apps = @(Get-LcmApps -Repo $Repo -WorkspaceRoot $WorkspaceRoot)
    $catalogPath = Join-Path $catalogDir 'apps.json'

    $catalogObj = [ordered]@{
        '$schema'    = 'https://json-schema.org/draft/2020-12/schema'
        title        = 'LCM Workspace App-Centric Architecture Catalog'
        updated_at   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        total_apps   = $apps.Count
        apps         = $apps
    }

    $catalogObj | ConvertTo-Json -Depth 6 | Set-Content -Path $catalogPath -Encoding UTF8
    Write-Host ("Synchronized App Catalog ({0} App(s) indexed) -> {1}" -f $apps.Count, $catalogPath) -ForegroundColor Green
    return [PSCustomObject]$catalogObj
}

function New-LcmApp {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [string]$Repo = 'Workspace_AI',

        [Parameter(Mandatory = $false)]
        [string]$Description = '',

        [Parameter(Mandatory = $false)]
        [switch]$SplitDocs = $false,

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $targetRepoDir = Join-Path $WorkspaceRoot $Repo
    if (-not (Test-Path $targetRepoDir)) {
        throw "Target repository '$Repo' does not exist at: $targetRepoDir"
    }

    # Find existing App IDs across the repo
    $existingApps = @(Get-LcmApps -Repo $Repo -WorkspaceRoot $WorkspaceRoot)
    $maxNum = 0
    foreach ($a in $existingApps) {
        if ($a.number -gt $maxNum) {
            $maxNum = $a.number
        }
    }

    $newNum = $maxNum + 1
    $appId = "App: $newNum"
    $fullTitle = "$appId - $Title"
    $cleanModName = ($Title -replace '[^a-zA-Z0-9]', '')
    $docsDir = Join-Path $targetRepoDir 'docs'
    if (-not (Test-Path $docsDir)) {
        New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
    }

    if ($SplitDocs) {
        $folderName = "App#$newNum-$cleanModName"
        $appTargetDir = Join-Path $docsDir $folderName

        if ($PSCmdlet.ShouldProcess($appTargetDir, "Scaffold directory-separated tripartite documents for '$fullTitle'")) {
            if (-not (Test-Path $appTargetDir)) {
                New-Item -ItemType Directory -Path $appTargetDir -Force | Out-Null
            }

            # 1. Architecture.md
            $archSnippet = @"
# $fullTitle Architecture

## 1. Architectural Concept & End-User Perspective
$Description

## 2. User Mental Model & Topology
<!-- Add Mermaid topology or functional diagram -->

"@
            Set-Content -Path (Join-Path $appTargetDir 'Architecture.md') -Value $archSnippet.Trim() -Encoding UTF8

            # 2. Requirements.md
            $reqSnippet = @"
# $fullTitle Requirements

## 1. Technical Invariants & Prerequisites
- Invariant 1: Must conform to LCM governance standards.

## 2. Safety & Error Handling Boundaries
- Boundary 1: Clean degradation and zero-state recovery.

"@
            Set-Content -Path (Join-Path $appTargetDir 'Requirements.md') -Value $reqSnippet.Trim() -Encoding UTF8

            # 3. Implementation.md
            $implSnippet = @"
# $fullTitle Implementation

## 1. Constituent Manifest Table
| Relative Path | Role / Layer | Primary Cmdlets / Entrypoints | Pester Test Suite |
|:---|:---|:---|:---|
| `modules/$($cleanModName).psm1` | Core Logic | `Get-$($cleanModName)` | `tests/$($cleanModName).Tests.ps1` |

## 2. Exported Interfaces & Public Contracts
- Cmdlet / API contracts defined in `data/catalog/contracts.json`.

"@
            Set-Content -Path (Join-Path $appTargetDir 'Implementation.md') -Value $implSnippet.Trim() -Encoding UTF8

            Write-Host ("Successfully scaffolded {0} in docs/{1}/ and set as active context." -f $fullTitle, $folderName) -ForegroundColor Green
        }
    } else {
        # Flat in-document scaffolding (default)
        $archFile = Join-Path $docsDir 'Architecture.md'
        $reqFile  = Join-Path $docsDir 'Requirements.md'
        $implFile = Join-Path $docsDir 'Implementation.md'

        if ($PSCmdlet.ShouldProcess("$Repo/docs/", "Scaffold in-document section for '$fullTitle'")) {
            # Scaffold in Architecture.md
            if (Test-Path $archFile) {
                $archSnippet = @"


---

## $fullTitle

### 1. Architectural Concept & End-User Perspective
$Description

### 2. User Mental Model & Topology
<!-- Add Mermaid topology or functional diagram -->

"@
                Add-Content -Path $archFile -Value $archSnippet -Encoding UTF8
            }

            # Scaffold in Requirements.md
            if (Test-Path $reqFile) {
                $reqSnippet = @"


---

## $fullTitle

### 1. Technical Invariants & Prerequisites
- Invariant 1: Must conform to LCM governance standards.

### 2. Safety & Error Handling Boundaries
- Boundary 1: Clean degradation and zero-state recovery.

"@
                Add-Content -Path $reqFile -Value $reqSnippet -Encoding UTF8
            }

            # Scaffold in Implementation.md
            if (Test-Path $implFile) {
                $implSnippet = @"


---

## $fullTitle

### 1. Constituent Manifest Table
| Relative Path | Role / Layer | Primary Cmdlets / Entrypoints | Pester Test Suite |
|:---|:---|:---|:---|
| `modules/$($cleanModName).psm1` | Core Logic | `Get-$($cleanModName)` | `tests/$($cleanModName).Tests.ps1` |

### 2. Exported Interfaces & Public Contracts
- Cmdlet / API contracts defined in `data/catalog/contracts.json`.

"@
                Add-Content -Path $implFile -Value $implSnippet -Encoding UTF8
            }

            Write-Host ("Successfully scaffolded {0} across {1}/docs/ and set as active context." -f $fullTitle, $Repo) -ForegroundColor Green
        }
    }

    # Set active context to newly minted App
    Set-ActiveAppContext -Context "A$newNum" -Repo $Repo -Details $Title -WorkspaceRoot $WorkspaceRoot | Out-Null

    # Sync catalog
    Sync-LcmAppCatalog -Repo $Repo -WorkspaceRoot $WorkspaceRoot | Out-Null

    return [PSCustomObject]@{
        Id          = $appId
        Number      = $newNum
        Title       = $Title
        FullTitle   = $fullTitle
        Repo        = $Repo
        Description = $Description
        DocLayout   = if ($SplitDocs) { 'Directory' } else { 'InDocument' }
        Directory   = if ($SplitDocs) { "docs/$folderName" } else { 'docs/' }
    }
}

function Split-LcmAppDocs {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Repo,

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $targetRepoDir = Join-Path $WorkspaceRoot $Repo
    if (-not (Test-Path $targetRepoDir)) {
        throw "Target repository '$Repo' does not exist at: $targetRepoDir"
    }

    $docsDir = Join-Path $targetRepoDir 'docs'
    if (-not (Test-Path $docsDir)) {
        throw "Documentation directory 'docs' does not exist at: $docsDir"
    }

    $archPath = Join-Path $docsDir 'Architecture.md'
    $reqPath  = Join-Path $docsDir 'Requirements.md'
    $implPath = Join-Path $docsDir 'Implementation.md'

    # 1. Parse existing in-document Apps from Architecture.md, Requirements.md, Implementation.md
    $archContent = if (Test-Path $archPath) { Get-Content -Path $archPath -Raw -Encoding UTF8 } else { '' }
    $reqContent  = if (Test-Path $reqPath)  { Get-Content -Path $reqPath -Raw -Encoding UTF8 } else { '' }
    $implContent = if (Test-Path $implPath) { Get-Content -Path $implPath -Raw -Encoding UTF8 } else { '' }

    # Helper function to split markdown content into preamble and per-App sections
    $splitSections = {
        param([string]$Content)
        $lines = $Content -split '\r?\n'
        $preamble = @()
        $sections = @{}
        $currNum = $null
        $currTitle = ''
        $currLines = @()

        foreach ($line in $lines) {
            if ($line -match '(?i)^#{2,3}\s+App:\s*(\d+)(?:\s*-\s*(.+))?$') {
                if ($currNum -ne $null) {
                    $sections[$currNum] = @{
                        Number = $currNum
                        Title  = $currTitle
                        Body   = ($currLines -join "`r`n").Trim()
                    }
                }
                $currNum = [int]$Matches[1]
                $currTitle = if ($Matches.Count -ge 3 -and $Matches[2]) { $Matches[2].Trim() } else { "App $currNum" }
                $currLines = @()
            } elseif ($currNum -eq $null) {
                $preamble += $line
            } else {
                $currLines += $line
            }
        }

        if ($currNum -ne $null) {
            $sections[$currNum] = @{
                Number = $currNum
                Title  = $currTitle
                Body   = ($currLines -join "`r`n").Trim()
            }
        }

        return @{
            Preamble = ($preamble -join "`r`n").TrimEnd()
            Sections = $sections
        }
    }

    $archSplit = & $splitSections $archContent
    $reqSplit  = & $splitSections $reqContent
    $implSplit = & $splitSections $implContent

    $allAppNums = @($archSplit.Sections.Keys + $reqSplit.Sections.Keys + $implSplit.Sections.Keys | Sort-Object -Unique)

    if ($allAppNums.Count -eq 0) {
        Write-Host "No in-document '## App: #' sections found in $Repo/docs/ to split." -ForegroundColor Yellow
        return @()
    }

    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host (" SPLITTING APP DOCUMENTATION FOR REPOSITORY: {0}" -f $Repo) -ForegroundColor Green
    Write-Host (" Discovered {0} in-document App slice(s): {1}" -f $allAppNums.Count, ($allAppNums -join ', ')) -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan

    $migrated = @()

    foreach ($num in $allAppNums) {
        $title = if ($archSplit.Sections.ContainsKey($num) -and $archSplit.Sections[$num].Title) {
            $archSplit.Sections[$num].Title
        } elseif ($reqSplit.Sections.ContainsKey($num) -and $reqSplit.Sections[$num].Title) {
            $reqSplit.Sections[$num].Title
        } elseif ($implSplit.Sections.ContainsKey($num) -and $implSplit.Sections[$num].Title) {
            $implSplit.Sections[$num].Title
        } else {
            "App $num"
        }

        $cleanSlug = ($title -replace '[^a-zA-Z0-9]', '')
        $folderName = "App#$num-$cleanSlug"
        $appTargetDir = Join-Path $docsDir $folderName

        $fullAppTitle = "App: $num - $title"

        if ($PSCmdlet.ShouldProcess($appTargetDir, "Extract $fullAppTitle tripartite docs")) {
            if (-not (Test-Path $appTargetDir)) {
                New-Item -ItemType Directory -Path $appTargetDir -Force | Out-Null
            }

            # 1. Architecture.md
            $archBody = if ($archSplit.Sections.ContainsKey($num)) { $archSplit.Sections[$num].Body } else { "### 1. Architectural Concept`n$title capability slice." }
            $archDocContent = @"
# $fullAppTitle Architecture

$archBody

"@
            Set-Content -Path (Join-Path $appTargetDir 'Architecture.md') -Value $archDocContent.Trim() -Encoding UTF8

            # 2. Requirements.md
            $reqBody = if ($reqSplit.Sections.ContainsKey($num)) { $reqSplit.Sections[$num].Body } else { "### 1. Technical Invariants`n- Invariant: Conforms to LCM governance standards." }
            $reqDocContent = @"
# $fullAppTitle Requirements

$reqBody

"@
            Set-Content -Path (Join-Path $appTargetDir 'Requirements.md') -Value $reqDocContent.Trim() -Encoding UTF8

            # 3. Implementation.md
            $implBody = if ($implSplit.Sections.ContainsKey($num)) { $implSplit.Sections[$num].Body } else { "### 1. Constituent Manifest Table`n| Relative Path | Role / Layer | Primary Cmdlets / Entrypoints | Test Suite |`n|:---|:---|:---|:---|`n| modules/$cleanSlug.psm1 | Core Logic | Get-$cleanSlug | tests/$cleanSlug.Tests.ps1 |" }
            $implDocContent = @"
# $fullAppTitle Implementation

$implBody

"@
            Set-Content -Path (Join-Path $appTargetDir 'Implementation.md') -Value $implDocContent.Trim() -Encoding UTF8

            $migrated += [PSCustomObject]@{
                Number    = $num
                Title     = $title
                Directory = "docs/$folderName"
            }
            Write-Host ("  [+] Migrated {0} -> docs/{1}/" -f $fullAppTitle, $folderName) -ForegroundColor Green
        } else {
            Write-Host ("  [WhatIf] Would migrate {0} -> docs/{1}/" -f $fullAppTitle, $folderName) -ForegroundColor Yellow
        }
    }

    # 4. Clean up root Architecture.md, Requirements.md, Implementation.md
    if ($PSCmdlet.ShouldProcess("$Repo/docs/", "Clean up root tripartite documents and add App index")) {
        # Build App Index table for root Architecture.md
        $indexRows = @()
        foreach ($m in $migrated) {
            $indexRows += "| App: $($m.Number) | $($m.Title) | [``$($m.Directory)/``](file:///$($m.Directory)) | [Arch](file:///$($m.Directory)/Architecture.md) · [Req](file:///$($m.Directory)/Requirements.md) · [Impl](file:///$($m.Directory)/Implementation.md) |"
        }

        $appIndexSection = @"


---

## App Subsystems & Sliced Specifications
The following modular App slices are documented in dedicated subdirectories per RULE-DOC-007:

| App ID | Title | Directory | Sliced Specifications |
|:---|:---|:---|:---|
$($indexRows -join "`r`n")
"@

        # Write clean root files
        $cleanArch = ($archSplit.Preamble.TrimEnd() -replace '(?s)\n---\s*$', '') + $appIndexSection
        Set-Content -Path $archPath -Value $cleanArch.Trim() -Encoding UTF8

        $cleanReq = $reqSplit.Preamble.TrimEnd() -replace '(?s)\n---\s*$', ''
        Set-Content -Path $reqPath -Value $cleanReq.Trim() -Encoding UTF8

        $cleanImpl = $implSplit.Preamble.TrimEnd() -replace '(?s)\n---\s*$', ''
        Set-Content -Path $implPath -Value $cleanImpl.Trim() -Encoding UTF8

        # 5. Re-synchronize App catalog
        Sync-LcmAppCatalog -Repo $Repo -WorkspaceRoot $WorkspaceRoot | Out-Null
        Write-Host "`n[SUCCESS] SplitDocs completed for repository '$Repo'." -ForegroundColor Green
        Format-LcmAppsTable -WorkspaceRoot $WorkspaceRoot
    }

    return $migrated
}

function Format-LcmAppsTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Apps,

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    if ($null -eq $Apps) {
        $Apps = Get-LcmApps -WorkspaceRoot $WorkspaceRoot
    }

    $activeCtx = Get-ActiveAppContext
    $activeId = if ($activeCtx) { 
        if ($activeCtx.app_id -in @('Master', 'Architecture', 'Base')) {
            "🏛️ Master Architecture (Governing All Apps) [$($activeCtx.repo)]"
        } else {
            "$($activeCtx.app_id) [$($activeCtx.repo)]"
        }
    } else { 
        '🏛️ Master Architecture (Governing All Apps)' 
    }

    Write-Host "==========================================================================================" -ForegroundColor Cyan
    Write-Host (" LCM Workspace App Catalog (Active Focus: {0})" -f $activeId) -ForegroundColor Cyan
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    if (@($Apps).Count -eq 0) {
        Write-Host " No modular Apps currently registered across workspace repositories." -ForegroundColor Gray
        Write-Host "==========================================================================================" -ForegroundColor Cyan
        return
    }

    Write-Host (" {0,-10} | {1,-22} | {2,-7} | {3,-13} | {4}" -f 'App ID', 'Repository', 'Docs', 'Constituents', 'Title') -ForegroundColor Yellow
    Write-Host "-----------+------------------------+---------+---------------+----------------------------------" -ForegroundColor DarkGray

    foreach ($a in $Apps) {
        $isMasterEntry = ($a.id -eq 'Master' -or $a.number -eq 0)
        $isActive = if ($isMasterEntry) {
            ($null -eq $activeCtx -or $activeCtx.app_id -in @('Master', 'Architecture', 'Base'))
        } else {
            ($activeCtx -and $activeCtx.app_id -eq $a.id -and $activeCtx.repo -eq $a.repo)
        }

        $color = if ($isActive) { 
            [ConsoleColor]::Green 
        } elseif ($isMasterEntry) {
            [ConsoleColor]::Cyan
        } else { 
            [ConsoleColor]::White 
        }

        $docsFlag = ""
        $docsFlag += if ($a.arch_defined) { "A" } else { "-" }
        $docsFlag += if ($a.req_defined)  { "R" } else { "-" }
        $docsFlag += if ($a.impl_defined) { "I" } else { "-" }

        $constCount = if ($isMasterEntry) { "Master Specs" } else { "$(@($a.constituents).Count) file(s)" }
        $idDisplay = if ($isActive) { "*$($a.id)" } else { " $($a.id)" }

        Write-Host (" {0,-10} | {1,-22} | {2,-7} | {3,-13} | {4}" -f $idDisplay, $a.repo, $docsFlag, $constCount, $a.title) -ForegroundColor $color
    }

    Write-Host "==========================================================================================" -ForegroundColor Cyan
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
    $activeCtx = Get-ActiveAppContext
    $activeId = if ($activeCtx) { $activeCtx.app_id } else { 'None (Base)' }

    Write-Host "==========================================================================================" -ForegroundColor Cyan
    Write-Host (" LCM Workspace Proposals Ledger (Mode: {0} | Granularity: {1} | Active Focus: {2})" -f $mode.ToUpper(), $granularity.ToUpper(), $activeId) -ForegroundColor Cyan
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    if (@($Proposals).Count -eq 0) {
        Write-Host " No open proposals currently tracked." -ForegroundColor Gray
        Write-Host "==========================================================================================" -ForegroundColor Cyan
        return
    }

    Write-Host (" {0,-7} | {1,-4} | {2,-8} | {3,-19} | {4,-11} | {5,-13} | {6,-18} | {7}" -f 'CRP ID', 'Prio', 'App', 'Timestamp', 'Plan State', 'STATUS', 'Origin Repo', 'Title') -ForegroundColor Yellow
    Write-Host "---------+------+----------+---------------------+-------------+---------------+--------------------+-----------------------" -ForegroundColor DarkGray

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
        $appTag = if ($null -ne $p.PSObject.Properties['app_id'] -and $p.app_id) { $p.app_id -replace '(?i)^App:\s*', 'A' } else { '-' }
        $ts = if ($null -ne $p.PSObject.Properties['timestamp'] -and $p.timestamp) { $p.timestamp } elseif ($null -ne $p.PSObject.Properties['dates'] -and $null -ne $p.dates.PSObject.Properties['created']) { $p.dates.created } else { '-' }
        $scope = if ($null -ne $p.PSObject.Properties['origin_repo'] -and $p.origin_repo) { $p.origin_repo } else { 'LCM' }
        $pState = if ($null -ne $p.PSObject.Properties['state'] -and $p.state) { $p.state } else { 'suggested' }
        $title = if ($null -ne $p.PSObject.Properties['title'] -and $p.title) { $p.title } else { '' }
        Write-Host (" {0,-7} | {1,-4} | {2,-8} | {3,-19} | {4,-11} | {5,-13} | {6,-18} | {7}" -f $idStr, $prio, $appTag, $ts, $pState, $prog, $scope, $title) -ForegroundColor $color
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
Set-Alias -Name Workon -Value Set-ActiveAppContext
Set-Alias -Name Apps -Value Format-LcmAppsTable
Set-Alias -Name App -Value New-LcmApp
Set-Alias -Name SplitDocs -Value Split-LcmAppDocs
Set-Alias -Name Purge-LcmPushedProposalBundle -Value Remove-LcmProposalBundle
Set-Alias -Name Purge-Bundle -Value Remove-LcmProposalBundle
Set-Alias -Name Get-Doc -Value Get-LcmProposalDocument

Export-ModuleMember -Function Get-ProposalStorePath, Get-ProposalStore, Set-ProposalStore, `
    Get-WorkspaceProposals, New-WorkspaceProposal, Set-WorkspaceProposalState, Set-WorkspaceProposalProgress, `
    Set-WorkspaceProposalPriority, Save-ProposalPlan, Save-ProposalWalkthrough, `
    Resolve-ProposalIdExpression, Invoke-ProposalBatchAction, `
    Set-ReviewGranularity, Get-ReviewGranularity, Set-LCMMode, Get-LCMMode, `
    Get-ActiveAppContext, Set-ActiveAppContext, Get-LcmApps, Sync-LcmAppCatalog, New-LcmApp, Split-LcmAppDocs, Format-LcmAppsTable, `
    Get-LcmProposalDocument, Remove-LcmProposalBundle, `
    Test-RegressionTrigger, Assert-RegressionSafety, Get-RegressionDAGOrder, New-ChildRegressionProposal, `
    Get-ReposUnderReview, Format-ProposalsTable, Format-ReposUnderReviewTable `
    -Alias Parse-ProposalIdExpression, Workon, Apps, App, SplitDocs, Purge-LcmPushedProposalBundle, Purge-Bundle, Get-Doc

