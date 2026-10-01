[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Explicit CRP/BUG scope, for example CRP-196,BUG-205')]
    [Alias('Scope')]
    [string]$CrpScope,

    [Parameter(Mandatory = $false, HelpMessage = 'Write declared documentation updates after validation. The default is dry run.')]
    [switch]$Apply,

    [Parameter(Mandatory = $false, HelpMessage = 'Fallback repository for unqualified documentation payloads')]
    [string]$TargetRepo = 'LCM_AI',

    [Parameter(Mandatory = $false, HelpMessage = 'Workspace root path')]
    [string]$WorkspaceRoot = 'D:\Git_Repositories',

    [Parameter(Mandatory = $false, HelpMessage = 'Optional path for the reconciliation manifest')]
    [string]$OutputPath,

    [Parameter(Mandatory = $false, HelpMessage = 'Open Beyond Compare after an applied documentation update')]
    [switch]$OpenReview,

    [Parameter(Mandatory = $false, HelpMessage = 'Emit selected scopes and proposed changes')]
    [Alias('t')]
    [switch]$Trace,

    [Alias('h', '?')]
    [switch]$Help
)

<#
.SYNOPSIS
    Reconciles explicit CRP and BUG documentation payloads into tripartite LCM documents.
.DESCRIPTION
    Module: tools/Fix-Documentation.ps1
    Version: 1.0.0
    Purpose: Provides the review-gated FixDocumentation <crp-scope> workflow.
    Caller Contract: Bundles must declare updates in a Documentation Updates section.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptName = 'Fix-Documentation'
$scriptVersion = '1.0.0'

function Write-DocumentationTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )

    if ($Enabled) {
        Write-Host "[$scriptName v$scriptVersion] $Message" -ForegroundColor DarkGray
    }
}

function Get-ScopedProposalIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Scope
    )

    $ids = [System.Collections.Generic.List[int]]::new()
    foreach ($token in ($Scope -split '[,;\s]+' | Where-Object { $_ })) {
        if ($token -match '^(?:CRP|BUG)-?(\d+)$') {
            $ids.Add([int]$Matches[1])
            continue
        }
        if ($token -match '^\d+$') {
            $ids.Add([int]$token)
            continue
        }
        throw "Invalid CRP scope token '$token'. Use explicit identifiers such as CRP-196 or BUG-205."
    }

    if ($ids.Count -eq 0) {
        throw 'At least one explicit CRP or BUG identifier is required.'
    }
    return @($ids | Select-Object -Unique)
}

function Get-BundleDocumentationUpdates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BundlePath,

        [Parameter(Mandatory = $true)]
        [string]$ProposalId,

        [Parameter(Mandatory = $true)]
        [string]$DefaultTargetRepo
    )

    $updates = [System.Collections.Generic.List[object]]::new()
    foreach ($fileName in @('Specification.md', 'Implementation_Plan.md', 'Walkthrough.md')) {
        $sourcePath = Join-Path $BundlePath $fileName
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            continue
        }

        $content = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
        if ($content -notmatch '(?m)^##[ \t]+Documentation Updates[ \t]*\r?$') {
            continue
        }

        foreach ($match in [regex]::Matches($content, '(?ms)^###[ \t]+(?:(?<repository>[A-Za-z_][A-Za-z0-9_]*)/)?(?<document>Architecture|Requirements|Implementation)[ \t]*\r?\n```markdown[ \t]*\r?\n(?<payload>.*?)^```[ \t]*\r?$')) {
            $updates.Add([PSCustomObject]@{
                ProposalId = $ProposalId
                Repository = if ($match.Groups['repository'].Success) { $match.Groups['repository'].Value } else { $DefaultTargetRepo }
                Document = $match.Groups['document'].Value
                Content = $match.Groups['payload'].Value.Trim()
                SourcePath = $sourcePath
            })
        }
    }
    return @($updates)
}

function Get-DocumentationMarker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$ProposalId,

        [Parameter(Mandatory = $true)]
        [string]$Document
    )

    $start = "<!-- FixDocumentation: $ProposalId $Document -->"
    $end = '<!-- /FixDocumentation -->'
    $match = [regex]::Match($Content, "(?ms)$([regex]::Escape($start))\r?\n(.*?)\r?\n$([regex]::Escape($end))")
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return $null
}

function Add-DocumentationUpdate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Update
    )

    $existing = Get-Content -LiteralPath $TargetPath -Raw -Encoding UTF8
    $prior = Get-DocumentationMarker -Content $existing -ProposalId $Update.ProposalId -Document $Update.Document
    if ($null -ne $prior) {
        if ($prior -ne $Update.Content) {
            throw "Existing FixDocumentation marker for $($Update.ProposalId) in '$TargetPath' conflicts with its declared update."
        }
        return $false
    }

    $marker = "<!-- FixDocumentation: $($Update.ProposalId) $($Update.Document) -->"
    $newContent = "$($existing.TrimEnd())`r`n`r`n$marker`r`n$($Update.Content)`r`n<!-- /FixDocumentation -->`r`n"
    Set-Content -LiteralPath $TargetPath -Value $newContent -Encoding UTF8
    return $true
}

if ($Help) {
    Write-Host "$scriptName v$scriptVersion" -ForegroundColor Cyan
    Write-Host 'Usage: FixDocumentation <CRP/BUG scope> [-Apply] [-TargetRepo <name>] [-OpenReview] [-t]'
    Write-Host 'Default behavior is dry run: it writes a manifest but does not alter documentation.'
    return
}

Write-Host "$scriptName v$scriptVersion" -ForegroundColor Cyan

$ledgerPath = Join-Path $WorkspaceRoot 'LCM_Inventory\data\proposals\proposals.json'
if (-not (Test-Path -LiteralPath $ledgerPath)) {
    throw "Proposal ledger was not found at '$ledgerPath'."
}

$selectedIds = @(Get-ScopedProposalIds -Scope $CrpScope)
$ledger = Get-Content -LiteralPath $ledgerPath -Raw -Encoding UTF8 | ConvertFrom-Json
$selected = @($ledger.proposals | Where-Object { $selectedIds -contains [int]$_.id })
if ($selected.Count -ne $selectedIds.Count) {
    $foundIds = @($selected | ForEach-Object { [int]$_.id })
    $missing = @($selectedIds | Where-Object { $_ -notin $foundIds })
    throw "No proposal ledger record exists for: $($missing -join ', ')."
}

$updates = [System.Collections.Generic.List[object]]::new()
foreach ($proposal in $selected) {
    $proposalId = if ($proposal.crp_id) { [string]$proposal.crp_id } else { [string]$proposal.cr_id }
    $bundlePath = Join-Path $WorkspaceRoot ([string]$proposal.bundle_dir)
    if (-not (Test-Path -LiteralPath $bundlePath)) {
        $bundlePath = Join-Path (Join-Path $WorkspaceRoot 'LCM_Inventory') ([string]$proposal.bundle_dir)
    }
    if (-not (Test-Path -LiteralPath $bundlePath)) {
        throw "Bundle for $proposalId was not found at '$bundlePath'."
    }
    Write-DocumentationTrace -Message "Reading declared documentation updates from $proposalId." -Enabled $Trace
    foreach ($update in @(Get-BundleDocumentationUpdates -BundlePath $bundlePath -ProposalId $proposalId -DefaultTargetRepo $TargetRepo)) {
        $updates.Add($update)
    }
    Write-DocumentationTrace -Message "Collected $($updates.Count) declared update(s) through $proposalId." -Enabled $Trace
}

$conflicts = [System.Collections.Generic.List[string]]::new()
foreach ($group in @($updates | Group-Object Repository, Document, ProposalId)) {
    if (@($group.Group | Select-Object -ExpandProperty Content -Unique).Count -gt 1) {
        $conflicts.Add("$($group.Name): conflicting payloads declared in one proposal bundle.")
    }
}
foreach ($group in @($updates | Group-Object Repository, Document)) {
    if (@($group.Group | Select-Object -ExpandProperty Content -Unique).Count -gt 1) {
        $conflicts.Add("$($group.Name): selected proposals declare different updates for the same target document.")
    }
}

$manifestEntries = foreach ($update in $updates) {
    $targetPath = Join-Path $WorkspaceRoot "$($update.Repository)\docs\$($update.Document).md"
    if (-not (Test-Path -LiteralPath $targetPath)) {
        $conflicts.Add("$($update.ProposalId): target document '$targetPath' does not exist.")
    }
    [ordered]@{
        proposal_id = $update.ProposalId
        repository = $update.Repository
        document = $update.Document
        source_path = $update.SourcePath
        target_path = $targetPath
        content_sha256 = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($update.Content))).ToLowerInvariant()
    }
}

$logRoot = Join-Path $env:TEMP 'LCM_Inventory\FixDocumentation\Logs'
if (-not (Test-Path -LiteralPath $logRoot)) {
    $null = New-Item -ItemType Directory -Path $logRoot -Force
}
$timeTag = Get-Date -Format 'yyyyMMdd_HHmmss'
$manifestPath = if ($OutputPath) { $OutputPath } else { Join-Path $logRoot "FixDocumentation_$timeTag.json" }
$manifest = [ordered]@{
    tool = $scriptName
    version = $scriptVersion
    timestamp = $timeTag
    mode = if ($Apply) { 'apply' } else { 'dry-run' }
    target_repos = @($updates | Select-Object -ExpandProperty Repository -Unique)
    selected_proposals = @($selected | ForEach-Object { $_.crp_id ?? $_.cr_id })
    updates = @($manifestEntries)
    conflicts = @($conflicts)
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

if ($conflicts.Count -gt 0) {
    Write-Host "$scriptName v$scriptVersion FAILURE" -ForegroundColor Red
    throw "Documentation reconciliation stopped: $($conflicts -join '; ')"
}

if ($updates.Count -eq 0) {
    Write-Host "No explicit Documentation Updates payloads were declared for the selected scope. Manifest: $manifestPath" -ForegroundColor Yellow
    Write-Host "$scriptName v$scriptVersion SUCCESS" -ForegroundColor Green
    return
}

if (-not $Apply) {
    Write-Host "Dry run complete. Proposed updates: $($updates.Count). Manifest: $manifestPath" -ForegroundColor Yellow
    Write-Host "$scriptName v$scriptVersion SUCCESS" -ForegroundColor Green
    return
}

$changedPaths = [System.Collections.Generic.List[string]]::new()
foreach ($update in $updates) {
    $targetPath = Join-Path $WorkspaceRoot "$($update.Repository)\docs\$($update.Document).md"
    if (Add-DocumentationUpdate -TargetPath $targetPath -Update $update) {
        $changedPaths.Add($targetPath)
    }
}

$receiptPath = Join-Path $logRoot "FixDocumentation_receipt_$timeTag.json"
[ordered]@{
    tool = $scriptName
    version = $scriptVersion
    timestamp = $timeTag
    selected_proposals = $manifest.selected_proposals
    changed_documents = @($changedPaths)
    manifest_path = $manifestPath
    review_required = $true
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $receiptPath -Encoding UTF8

Write-Host "Applied documentation updates: $($changedPaths.Count). Receipt: $receiptPath" -ForegroundColor Green
$changedRepos = @($changedPaths | ForEach-Object { Split-Path (Split-Path $_ -Parent) -Parent | Split-Path -Leaf } | Select-Object -Unique)
Write-Host "BCompare review is required before local commit for: $($changedRepos -join ', ')" -ForegroundColor Yellow
if ($OpenReview -and $changedPaths.Count -gt 0) {
    $reviewTool = Join-Path $WorkspaceRoot 'LCM_Inventory\tools\Invoke-BeyondCompareReview.ps1'
    foreach ($repository in $changedRepos) {
        & $reviewTool -RepositoryName $repository -BaseCommit HEAD -CRP $CrpScope
    }
}
Write-Host "$scriptName v$scriptVersion SUCCESS" -ForegroundColor Green