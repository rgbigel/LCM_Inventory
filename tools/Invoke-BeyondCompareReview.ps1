[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Name or path of the repository to review')]
    [string]$RepositoryName,

    [Parameter(Mandatory = $false, HelpMessage = 'Base Git commit or reference to compare against (e.g., HEAD~1, root, SHA, tag)')]
    [string]$BaseCommit,

    [Parameter(Mandatory = $false)]
    [string]$BeyondComparePath = 'D:\Tools\Beyond Compare 5\BCompare.exe'
)

<#
.SYNOPSIS
    Compares a repository's current state against any prior commit/baseline in Beyond Compare 5.
.DESCRIPTION
    Module: tools/Invoke-BeyondCompareReview.ps1
    Purpose: Compares a repository's current state against any prior commit/baseline in Beyond Compare 5 with automated content-based comparison, empty folder suppression, and out-of-scope filter exclusions.
    Path: Workspace_Inventory/tools/Invoke-BeyondCompareReview.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 1.4.0
    Date: 2026-08-21
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Update-BCReviewSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LeftPath,

        [Parameter(Mandatory = $true)]
        [string]$RightPath,

        [Parameter(Mandatory = $false)]
        [string]$FilterMask,

        [Parameter(Mandatory = $false)]
        [string]$SessionName = 'LCM_Review'
    )

    $bcSessionsPath = Join-Path $env:APPDATA 'Scooter Software\Beyond Compare 5\BCSessions.xml'
    if (-not (Test-Path -LiteralPath $bcSessionsPath)) {
        return
    }

    try {
        $xml = [xml](Get-Content -LiteralPath $bcSessionsPath -Raw)
        $itemsFolder = $xml.BCSessions.TSessionFolder.Items

        $sessionNode = $itemsFolder.SelectSingleNode("TDirCompareSession[@Value='$SessionName']")
        if (-not $sessionNode) {
            $sessionNode = $xml.CreateElement('TDirCompareSession')
            $sessionNode.SetAttribute('Value', $SessionName)
            $null = $itemsFolder.PrependChild($sessionNode)
        }

        # Specs (Left and Right)
        $specs = $sessionNode.SelectSingleNode('Specs')
        if (-not $specs) {
            $specs = $xml.CreateElement('Specs')
            $null = $sessionNode.AppendChild($specs)
        }
        $left = $specs.SelectSingleNode('Left')
        if (-not $left) {
            $left = $xml.CreateElement('Left')
            $null = $specs.AppendChild($left)
        }
        $left.SetAttribute('Value', $LeftPath)

        $right = $specs.SelectSingleNode('Right')
        if (-not $right) {
            $right = $xml.CreateElement('Right')
            $null = $specs.AppendChild($right)
        }
        $right.SetAttribute('Value', $RightPath)

        # Filters
        if ($FilterMask) {
            $filters = $sessionNode.SelectSingleNode('Filters')
            if (-not $filters) {
                $filters = $xml.CreateElement('Filters')
                $null = $sessionNode.AppendChild($filters)
            }
            $nf = $filters.SelectSingleNode('NameFilter')
            if (-not $nf) {
                $nf = $xml.CreateElement('NameFilter')
                $null = $filters.AppendChild($nf)
            }
            $nf.SetAttribute('Value', $FilterMask)
        }

        # Helper to set attributes
        $setAttr = {
            param($parent, $name, $val)
            $n = $parent.SelectSingleNode($name)
            if (-not $n) {
                $n = $parent.OwnerDocument.CreateElement($name)
                $null = $parent.AppendChild($n)
            }
            $n.SetAttribute('Value', $val)
        }

        # Rules (Content Comparison: Rules-Based)
        $rules = $sessionNode.SelectSingleNode('Rules')
        if (-not $rules) {
            $rules = $xml.CreateElement('Rules')
            $null = $sessionNode.AppendChild($rules)
        }
        & $setAttr $rules 'ContentCompareKind' 'ccRulesBased'
        & $setAttr $rules 'UseContentComparison' 'True'
        & $setAttr $rules 'UseSizeComparison' 'True'
        & $setAttr $rules 'UseTimestampComparison' 'True'

        # State (Ignore empty dirs, display differences/orphans, ignore unimportant)
        $state = $sessionNode.SelectSingleNode('State')
        if (-not $state) {
            $state = $xml.CreateElement('State')
            $null = $sessionNode.AppendChild($state)
        }
        & $setAttr $state 'ColAttributesVisible' 'True'
        & $setAttr $state 'ColCRCVisible' 'True'
        & $setAttr $state 'DirHandling' 'dirCompareFilesOnly'
        & $setAttr $state 'DisplayFilter' '[showLeftAdded, showRightAdded, showLeftChanged, showRightChanged, showConflict]'
        & $setAttr $state 'InsigIgnored' 'True'
        & $setAttr $state 'SortCol' 'colModified'

        # Also update default TDirCompareSession so standard launches benefit too
        $defaultSession = $itemsFolder.TDirCompareSession
        if ($defaultSession) {
            $defFilters = $defaultSession.SelectSingleNode('Filters')
            if (-not $defFilters) {
                $defFilters = $xml.CreateElement('Filters')
                $null = $defaultSession.AppendChild($defFilters)
            }
            $defNf = $defFilters.SelectSingleNode('NameFilter')
            if (-not $defNf) {
                $defNf = $xml.CreateElement('NameFilter')
                $null = $defFilters.AppendChild($defNf)
            }
            $defNf.SetAttribute('Value', '-*.inventory;-data\inventory.json;-inventory.json;-*\logs\;-*\scratch\;-*\work\;-*.log;-*.tmp;-*.bak;-*.swp;-*.lock;-node_modules\;-bin\;-obj\')

            $defRules = $defaultSession.SelectSingleNode('Rules')
            if (-not $defRules) {
                $defRules = $xml.CreateElement('Rules')
                $null = $defaultSession.AppendChild($defRules)
            }
            & $setAttr $defRules 'ContentCompareKind' 'ccRulesBased'
            & $setAttr $defRules 'UseContentComparison' 'True'
            & $setAttr $defRules 'UseSizeComparison' 'True'
            & $setAttr $defRules 'UseTimestampComparison' 'True'

            $defState = $defaultSession.SelectSingleNode('State')
            if (-not $defState) {
                $defState = $xml.CreateElement('State')
                $null = $defaultSession.AppendChild($defState)
            }
            & $setAttr $defState 'DirHandling' 'dirCompareFilesOnly'
            & $setAttr $defState 'InsigIgnored' 'True'
        }

        $xml.Save($bcSessionsPath)
    } catch {
        Write-Verbose "Could not update Beyond Compare session settings: $($_.Exception.Message)"
    }
}

$workspaceRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$resolvedTarget = if ($RepositoryName -in @('.', 'Root', 'Git_Repositories', 'WorkspaceRoot')) {
    $workspaceRoot
} elseif (Test-Path -LiteralPath $RepositoryName) {
    $RepositoryName
} else {
    Join-Path $workspaceRoot $RepositoryName
}

if (-not (Test-Path -LiteralPath $resolvedTarget)) {
    throw "Repository path not found: $resolvedTarget"
}

# ALWAYS resolve to fully-qualified absolute path (guarantees correct resolution when launched via schtasks/explorer)
$repoPath = (Get-Item -LiteralPath $resolvedTarget).FullName

if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) {
    throw "Directory is not a Git repository: $repoPath"
}

# Validate Beyond Compare executable
if (-not (Test-Path -LiteralPath $BeyondComparePath)) {
    throw "Beyond Compare executable not found at: $BeyondComparePath. Please verify the tool path."
}

# If BaseCommit is not specified, default to HEAD to review uncommitted working tree changes
if ([string]::IsNullOrWhiteSpace($BaseCommit)) {
    $BaseCommit = 'HEAD'
} elseif ($BaseCommit -eq 'root') {
    $logCommits = @(git -C $repoPath log --oneline | ForEach-Object { ($_ -split ' ')[0] })
    if ($logCommits.Count -gt 0) {
        $BaseCommit = $logCommits[-1]
    } else {
        $BaseCommit = 'HEAD'
    }
}

$commitSha = (git -C $repoPath rev-parse --short $BaseCommit 2>$null)
if (-not $commitSha) {
    throw "Invalid Git commit reference: $BaseCommit"
}

$commitMsg = (git -C $repoPath log -n 1 --pretty=format:"%s" $commitSha)
$repoName = Split-Path $repoPath -Leaf
$tempParent = Join-Path $env:TEMP "BC_Review"
if (-not (Test-Path -LiteralPath $tempParent)) {
    $null = New-Item -ItemType Directory -Path $tempParent -Force
}

$tempReviewRoot = Join-Path $tempParent "$repoName-$commitSha"

if (Test-Path -LiteralPath $tempReviewRoot) {
    Remove-Item -LiteralPath $tempReviewRoot -Recurse -Force -ErrorAction SilentlyContinue
}
$null = New-Item -ItemType Directory -Path $tempReviewRoot -Force

Write-Host ("Exporting baseline commit [{0}: {1}] to temp review directory..." -f $commitSha, $commitMsg) -ForegroundColor Cyan

# Export git archive of the base commit
$tarPath = Join-Path $env:TEMP "BC_Review_$repoName-$commitSha.tar"
git -C $repoPath archive -o $tarPath $commitSha
tar -xf $tarPath -C $tempReviewRoot
Remove-Item -LiteralPath $tarPath -Force -ErrorAction SilentlyContinue

# Construct exclusion filter list
$filterList = [System.Collections.Generic.List[string]]::new()

# If reviewing the Root Container, exclude all child repositories that are not the root itself
if ($repoPath -eq $workspaceRoot) {
    $childRepos = @(Get-ChildItem -LiteralPath $workspaceRoot -Directory | Where-Object { 
        (Test-Path -LiteralPath (Join-Path $_.FullName '.git')) -and ($_.FullName -ne $workspaceRoot)
    })
    foreach ($child in $childRepos) {
        $filterList.Add("-.\$($child.Name)\")
    }
}

# Standard LCM exclusions
$filterList.Add("-*.inventory")
$filterList.Add("-data\inventory.json")
$filterList.Add("-inventory.json")
$filterList.Add("-*\logs\")
$filterList.Add("-*\scratch\")
$filterList.Add("-*\work\")
$filterList.Add("-*.log")
$filterList.Add("-*.tmp")
$filterList.Add("-*.bak")
$filterList.Add("-*.swp")
$filterList.Add("-*.lock")
$filterList.Add("-node_modules\")
$filterList.Add("-bin\")
$filterList.Add("-obj\")

$filterMask = ($filterList -join ';')

# Dynamically configure Beyond Compare LCM_Review session
Update-BCReviewSession -LeftPath $tempReviewRoot -RightPath $repoPath -FilterMask $filterMask -SessionName 'LCM_Review'

# Record immutable review session metadata
$sessionMeta = [ordered]@{
    RepositoryName   = $repoName
    RepositoryPath   = $repoPath
    BaseCommit       = $commitSha
    CommitMessage    = $commitMsg
    CommitDate       = (git -C $repoPath log -n 1 --pretty=format:"%cI" $commitSha)
    SessionStartedAt = (Get-Date).ToString("o")
    FilterMask       = $filterMask
}
$sessionMeta | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $tempReviewRoot ".lcm_review.json") -Encoding utf8

Write-Host "Launching Beyond Compare 5 on interactive desktop..." -ForegroundColor Green
Write-Host ("  Left (Baseline {0}): {1}" -f $commitSha, $tempReviewRoot)
Write-Host ("  Right (Current Live):       {0}" -f $repoPath)
Write-Host ("  Filters Applied:            {0}" -f $filterMask)

$title1 = "Baseline ($commitSha)"
$title2 = "Current Live ($repoName)"
$taskName = "LCM_BeyondCompare_Review"
$actionCmd = "`"$BeyondComparePath`" /title1=`"$title1`" /title2=`"$title2`" /filters=`"$filterMask`" `"$tempReviewRoot`" `"$repoPath`""

try {
    # Method 1: Launch via interactive Windows Task Scheduler (forces GUI into active user Session 1)
    schtasks.exe /create /tn $taskName /tr $actionCmd /sc once /st "23:59" /it /f 2>&1 | Out-Null
    schtasks.exe /run /tn $taskName 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500
    schtasks.exe /delete /tn $taskName /f 2>&1 | Out-Null
}
catch {
    # Method 2: Standard Start-Process fallback
    Start-Process -FilePath $BeyondComparePath -ArgumentList @("/title1=$title1", "/title2=$title2", "/filters=$filterMask", "`"$tempReviewRoot`"", "`"$repoPath`"")
}
