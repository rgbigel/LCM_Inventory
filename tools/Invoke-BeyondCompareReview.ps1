[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Name or path of the repository to review')]
    [string]$RepositoryName,

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Base Git commit or reference to compare against (e.g., HEAD~1, root, SHA, tag)')]
    [string]$BaseCommit,

    [Parameter(Mandatory = $false, HelpMessage = 'Additional directory or file exclusions to filter from review display')]
    [Alias('Exclude', 'Filters')]
    [string[]]$Exclusions = @(),

    [Parameter(Mandatory = $false)]
    [string]$BeyondComparePath = 'D:\Tools\Beyond Compare 5\BCompare.exe',

    [Alias('h', '?')]
    [switch]$Help
)

<#
.SYNOPSIS
    Compares a repository's current state against any prior commit/baseline in Beyond Compare 5 with configurable exclusions.
.DESCRIPTION
    Module: tools/Invoke-BeyondCompareReview.ps1
    Purpose: Compares a repository's current state against any prior commit/baseline in Beyond Compare 5 with automated content-based comparison, empty folder suppression, and out-of-scope filter exclusions (.git, logs, scratch, __pycache__, binaries).
    Path: Workspace_Inventory/tools/Invoke-BeyondCompareReview.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 1.5.0
    Date: 2026-08-28
.PARAMETER RepositoryName
    The name or directory path of the Git repository to review (e.g. 'AuthorizeMasterUser', 'Git_Repositories', '.').
.PARAMETER BaseCommit
    The base Git commit to compare against (e.g. 'HEAD~1', 'HEAD', 'root', SHA). Defaults to 'HEAD'.
.PARAMETER Exclusions
    Additional file or directory exclusion masks (Aliases: -Exclude, -Filters). Standard LCM exclusions (.git, __pycache__, scratch, logs, node_modules, temp files) are always included.
.PARAMETER BeyondComparePath
    Path to BCompare.exe executable. Defaults to 'D:\Tools\Beyond Compare 5\BCompare.exe'.
.PARAMETER Help
    Displays this parameter reference (Aliases: -h, -?).
.EXAMPLE
    pwsh tools/Invoke-BeyondCompareReview.ps1 -RepositoryName AuthorizeMasterUser -BaseCommit HEAD~1
.EXAMPLE
    pwsh tools/Invoke-BeyondCompareReview.ps1 -RepositoryName Git_Repositories -Exclusions @('custom_dir\', '*.bak')
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "1.5.0"
$scriptName = "Invoke-BeyondCompareReview"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help -or [string]::IsNullOrWhiteSpace($RepositoryName)) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " BEYOND COMPARE 5 REPOSITORY REVIEW LAUNCHER (v$scriptVersion)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Exports the specified Git baseline to a temporary inspection tree and opens"
    Write-Host "  Beyond Compare 5 on your interactive desktop with out-of-scope filter exclusions."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Invoke-BeyondCompareReview.ps1 -RepositoryName <repo> [-BaseCommit <commit>] [-Exclusions <array>] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -RepositoryName <str> : Name or path of repository (e.g. 'AuthorizeMasterUser', '.')."
    Write-Host "  -BaseCommit <str>     : Git commit to compare against (Default: 'HEAD')."
    Write-Host "  -Exclusions <arr>     : Additional exclusion masks (Aliases: -Exclude, -Filters)."
    Write-Host "  -BeyondComparePath    : Path to BCompare.exe (Default: 'D:\Tools\Beyond Compare 5\BCompare.exe')."
    Write-Host "  -h, -Help, -?         : Displays this parameter reference."
    Write-Host ""
    Write-Host "STANDARD BASELINE EXCLUSIONS (ALWAYS APPLIED):" -ForegroundColor Yellow
    Write-Host "  - Version Control    : .git\, *\.git\*, .git*"
    Write-Host "  - Python Bytecode    : __pycache__\, *\.pyc, *\.pyo"
    Write-Host "  - Scratch & Logs     : scratch\, logs\, work\, *.log, *.tmp, *.bak, *.swp, *.lock"
    Write-Host "  - Inventory/Telemetry: inventory.json, *.inventory, data\inventory.json"
    Write-Host "  - Dependencies/Build : node_modules\, bin\, obj\"
    Write-Host "  - Container Scope    : Child repositories excluded when reviewing root container"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Invoke-BeyondCompareReview.ps1 -RepositoryName AuthorizeMasterUser -BaseCommit HEAD~1"
    Write-Host "  pwsh tools/Invoke-BeyondCompareReview.ps1 -RepositoryName Git_Repositories -Exclude @('build\')"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

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
            $defNf.SetAttribute('Value', $FilterMask)

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

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
    $workspaceRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
}

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

# ALWAYS resolve to fully-qualified absolute path
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
    $hasAnyCommit = (git -C $repoPath rev-parse --verify HEAD 2>$null)
    if (-not $hasAnyCommit) {
        $commitSha = 'unborn'
        $commitMsg = 'Initial Onboarding Baseline (Empty)'
    } else {
        throw "Invalid Git commit reference: $BaseCommit"
    }
} else {
    $commitMsg = (git -C $repoPath log -n 1 --pretty=format:"%s" $commitSha)
}

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

if ($commitSha -ne 'unborn') {
    $tarPath = Join-Path $tempReviewRoot "archive.tar"
    git -C $repoPath archive $commitSha -o $tarPath
    tar -xf $tarPath -C $tempReviewRoot
    Remove-Item -LiteralPath $tarPath -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------------------
# Construct Authoritative Exclusion Filter List
# ------------------------------------------------------------------------------
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

# Standard Baseline LCM Exclusions
$standardExclusions = @(
    '-.git\', '-*\.git\*', '-.git*',
    '-__pycache__\', '-*\__pycache__\*', '-*.pyc', '-*.pyo',
    '-scratch\', '-*\scratch\*',
    '-logs\', '-*\logs\*',
    '-work\', '-*\work\*',
    '-*.inventory', '-data\inventory.json', '-inventory.json',
    '-*.log', '-*.tmp', '-*.bak', '-*.swp', '-*.lock',
    '-node_modules\', '-*\node_modules\*',
    '-bin\', '-*\bin\*',
    '-obj\', '-*\obj\*'
)

foreach ($ex in $standardExclusions) {
    if (-not $filterList.Contains($ex)) {
        $filterList.Add($ex)
    }
}

# Append User-Specified Custom Exclusions
if ($Exclusions -and $Exclusions.Count -gt 0) {
    foreach ($userEx in $Exclusions) {
        if (-not [string]::IsNullOrWhiteSpace($userEx)) {
            $formatted = $userEx.Trim()
            if (-not $formatted.StartsWith('-') -and -not $formatted.StartsWith('+')) {
                $formatted = "-$formatted"
            }
            if (-not $filterList.Contains($formatted)) {
                $filterList.Add($formatted)
            }
        }
    }
}

$filterMask = ($filterList -join ';')

# Dynamically configure Beyond Compare LCM_Review session
Update-BCReviewSession -LeftPath $tempReviewRoot -RightPath $repoPath -FilterMask $filterMask -SessionName 'LCM_Review'

# Record immutable review session metadata
$sessionMeta = [ordered]@{
    RepositoryName   = $repoName
    RepositoryPath   = $repoPath
    BaseCommit       = $commitSha
    CommitMessage    = $commitMsg
    CommitDate       = if ($commitSha -ne 'unborn') { (git -C $repoPath log -n 1 --pretty=format:"%cI" $commitSha) } else { (Get-Date).ToString("o") }
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

# Format full folder comparison arguments including titles and LCM exclusion filters
$bcArgs = "`"$tempReviewRoot`" `"$repoPath`" `"/title1=$title1`" `"/title2=$title2`" `"/filters=$filterMask`""

$taskName = "LCM_BC_Review_$(Get-Random)"
try {
    # Method 1 (Authoritative): Launch via Task Scheduler Interactive Dispatch (Session 1 desktop)
    $action = New-ScheduledTaskAction -Execute $BeyondComparePath -Argument $bcArgs
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Milliseconds 600
}
catch {
    # Method 2: Fallback to ShellExecute / Start-Process
    try {
        $shellApp = New-Object -ComObject Shell.Application
        $shellApp.ShellExecute($BeyondComparePath, $bcArgs, "", "open", 1)
        Start-Sleep -Milliseconds 500
    }
    catch {
        Start-Process -FilePath $BeyondComparePath -ArgumentList @("`"$tempReviewRoot`"", "`"$repoPath`"", "`"/title1=$title1`"", "`"/title2=$title2`"", "`"/filters=$filterMask`"")
    }
}
finally {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
