# =====================================================================
# WorkspaceCM.psm1 - Configuration Management (CM) Core Engine Module
# =====================================================================
# Module: WorkspaceCM
# Purpose: Deep multi-repository state auditing, classification, Git inspection,
#          LCM version tracking, baseline management, and drift detection.
# Authors: Rolf, Workspace_AI Engine
# Version: 1.0.0
# Date: 2026-08-15
# =====================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-WorkspaceRoot {
    [CmdletBinding()]
    param()
    
    $scriptRoot = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        $scriptRoot = (Get-Location).Path
    }
    
    # Climb up to Git_Repositories root
    $parent = (Get-Item $scriptRoot).Parent
    while ($parent -ne $null -and $parent.Name -ne 'Git_Repositories') {
        $parent = $parent.Parent
    }
    
    if ($parent -ne $null -and $parent.Name -eq 'Git_Repositories') {
        return $parent.FullName
    }
    
    return 'D:\Git_Repositories'
}

function Write-CMLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$Action,
        [Parameter(Mandatory=$true)] [string]$TargetRepo,
        [Parameter(Mandatory=$true)] [string]$Details,
        [string]$Status = 'INFO'
    )
    
    $root = Get-WorkspaceRoot
    $logDir = Join-Path $root 'Workspace_Inventory\logs'
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $logFile = Join-Path $logDir 'cm_activity.log'
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $entry = "[$timestamp] [$Status] [$TargetRepo] $Action - $Details"
    
    Add-Content -Path $logFile -Value $entry -Encoding UTF8
}

function Get-WorkspaceAIState {
    [CmdletBinding()]
    param(
        [string]$WorkspacePath = (Join-Path (Get-WorkspaceRoot) 'Workspace_AI')
    )
    
    if (-not (Test-Path $WorkspacePath)) {
        return [PSCustomObject]@{
            Status = 'Missing'
            Version = 'Unknown'
            LifecycleState = 'Unknown'
        }
    }
    
    $lcmVersion = '4.3.0'
    $reqDoc = Join-Path $WorkspacePath 'docs\Requirements.md'
    if (Test-Path $reqDoc) {
        $match = Select-String -Path $reqDoc -Pattern '^Version:\s*(\S+)' | Select-Object -First 1
        if ($match -and $match.Matches.Groups.Count -gt 1) {
            $lcmVersion = $match.Matches.Groups[1].Value
        }
    }
    
    $gitBranch = 'main'
    $headSha = 'unknown'
    if (Test-Path (Join-Path $WorkspacePath '.git')) {
        try {
            $b = (git -C $WorkspacePath branch --show-current 2>$null)
            if ($b) { $gitBranch = $b.Trim() }
            $h = (git -C $WorkspacePath rev-parse --short HEAD 2>$null)
            if ($h) { $headSha = $h.Trim() }
        } catch { }
    }
    
    return [PSCustomObject]@{
        Status = 'Active'
        GlobalLCMVersion = $lcmVersion
        LifecycleState = 'Governed'
        Branch = $gitBranch
        HeadCommit = $headSha
        Path = $WorkspacePath
    }
}

function Get-RepoClassification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$DirectoryPath
    )
    
    $dirItem = Get-Item $DirectoryPath
    $repoName = $dirItem.Name
    $isGit = Test-Path (Join-Path $DirectoryPath '.git')
    
    # Classifications
    $retiredList = @('Workspace_AC', 'Workspace_GC')
    $parentInfraList = @('.agents', '.copilot', '.github', '.venv', '.vscode')
    $nonGitIgnored = @('AuthorizeMasterUser', 'BootOpsHub', 'CommandHub', 'DeviceInventory',
                       'DiskAssignmentStatus_AC', 'DiskAssignmentStatus_S1', 'EnvironmentTools',
                       'FileUtilities', 'GitTools', 'SystemConfiguration')
    if ($repoName -eq 'Workspace_AI') { return 'active-design-workshop' }
    if ($repoName -eq 'Workspace_Inventory') { return 'configuration-management' }
    if ($retiredList -contains $repoName) { return 'legacy-retired' }
    if ($parentInfraList -contains $repoName) { return 'parent-infra' }
    if (-not $isGit -or ($nonGitIgnored -contains $repoName)) { return 'non-git' }
    return 'standard-git'
}

function Get-RepoCMState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DirectoryPath,
        
        [Parameter(Mandatory=$false)]
        [string]$GlobalLCMVersion = '4.2.0',
        
        [Parameter(Mandatory=$false)]
        [PSCustomObject]$CachedRepoState = $null
    )
    
    $repoName = Split-Path $DirectoryPath -Leaf
    $gitDir = Join-Path $DirectoryPath '.git'
    $isGit = Test-Path $gitDir
    
    $classification = Get-RepoClassification -DirectoryPath $DirectoryPath
    $gitStatus = if ($isGit) { 'Git' } else { 'Non-Git' }
    $branch = '-'
    $headCommit = '-'
    $dirtyState = 'clean'
    $aheadBehind = 'synced'
    $hasUnpushed = $false
    
    if ($isGit) {
        try {
            $branch = (git -C $DirectoryPath rev-parse --abbrev-ref HEAD 2>$null)
            $headCommit = (git -C $DirectoryPath rev-parse --short HEAD 2>$null)
            $statusLines = @(git -C $DirectoryPath status --porcelain 2>$null)
            if ($statusLines.Count -gt 0) {
                $dirtyState = "modified ($($statusLines.Count) files)"
            }
            
            $remoteStatus = (git -C $DirectoryPath status -sb 2>$null | Select-Object -First 1)
            if ($remoteStatus -match '\[ahead (\d+)\]') {
                $aheadCount = $Matches[1]
                $aheadBehind = "ahead $aheadCount"
                $hasUnpushed = $true
            } elseif ($remoteStatus -match '\[behind (\d+)\]') {
                $aheadBehind = "behind $($Matches[1])"
            }
        } catch { }
    }
    
    $lcmStatus = 'not-lcm'
    $absorbedVersion = $null
    $currentVersion = $null
    $lcmConfigFile = Join-Path $DirectoryPath '.lcm\config.json'
    $junctionsHealthy = $true
    
    if ($classification -eq 'active-design-workshop' -or $classification -eq 'configuration-management') {
        $lcmStatus = 'governed'
        $absorbedVersion = $GlobalLCMVersion
        $currentVersion = $GlobalLCMVersion
    } elseif (Test-Path $lcmConfigFile) {
        $classification = 'lcm-governed'
        $lcmStatus = 'governed'
        try {
            $cfg = Get-Content -Path $lcmConfigFile -Raw | ConvertFrom-Json
            $currentVersion = if ($cfg.governance.lcm_version) { [string]$cfg.governance.lcm_version } else { [string]$cfg.lcm_version }
            $absorbedVersion = if ($cfg.governance.absorbed_lcm_version) { [string]$cfg.governance.absorbed_lcm_version } else { if ($cfg.absorbed_lcm_version) { [string]$cfg.absorbed_lcm_version } else { $currentVersion } }
        } catch { }
        
        $agentJunction = Join-Path $DirectoryPath '.agents\rules\core'
        $copilotJunction = Join-Path $DirectoryPath '.copilot\Rules\core'
        if ((-not (Test-Path $agentJunction)) -or (-not (Test-Path $copilotJunction))) {
            $junctionsHealthy = $false
        }
        
        if ($currentVersion -ne $GlobalLCMVersion) {
            $lcmStatus = 'outdated'
        }
    }
    
    $elevationRequired = $false
    $elevationReason = ''
    $minPrivilege = 'User'
    $elevationDetermined = $false
    
    if (Test-Path $lcmConfigFile) {
        try {
            $cfg = Get-Content -Path $lcmConfigFile -Raw | ConvertFrom-Json
            if ($cfg.execution_context -and ($null -ne $cfg.execution_context.elevation_required)) {
                $elevationRequired = [bool]$cfg.execution_context.elevation_required
                $minPrivilege = if ($cfg.execution_context.minimum_privilege) { [string]$cfg.execution_context.minimum_privilege } else { if ($elevationRequired) { 'Administrator' } else { 'User' } }
                $elevationReason = if ($cfg.execution_context.reason) { [string]$cfg.execution_context.reason } else { 'Configured in .lcm/config.json' }
                $elevationDetermined = $true
            }
        } catch { }
    }
    
    if (-not $elevationDetermined -and $CachedRepoState -and ($null -ne $CachedRepoState.ElevationRequired)) {
        $elevationRequired = [bool]$CachedRepoState.ElevationRequired
        $minPrivilege = if ($CachedRepoState.MinimumPrivilege) { [string]$CachedRepoState.MinimumPrivilege } else { if ($elevationRequired) { 'Administrator' } else { 'User' } }
        $elevationReason = if ($CachedRepoState.ElevationReason) { [string]$CachedRepoState.ElevationReason } else { 'Known in Workspace_Inventory' }
        $elevationDetermined = $true
    }
    
    if (-not $elevationDetermined) {
        $srcDir = Join-Path $DirectoryPath 'src'
        if (-not (Test-Path $srcDir)) { $srcDir = Join-Path $DirectoryPath 'Source' }
        if (-not (Test-Path $srcDir)) { $srcDir = $DirectoryPath }
        
        $privilegedPatterns = @('bcdedit', 'fltmc', 'fsutil\s+fsinfo', 'DiskPart', 'Start-Process.*-Verb\s+RunAs', 'Get-Partition\b', 'Add-BitLockerKeyProtector')
        $codeFiles = Get-ChildItem -Path $srcDir -Include '*.ps1', '*.psm1', '*.cs', '*.cpp' -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\\.git\\' }
        foreach ($cf in $codeFiles) {
            $text = Get-Content -Path $cf.FullName -Raw -ErrorAction SilentlyContinue
            if ($text) {
                foreach ($pattern in $privilegedPatterns) {
                    if ($text -match "(?im)$pattern") {
                        $elevationRequired = $true
                        $minPrivilege = 'Administrator'
                        $elevationReason = "Auto-detected privileged pattern '$pattern' in $($cf.Name)"
                        break
                    }
                }
            }
            if ($elevationRequired) { break }
        }
    }
    
    return [PSCustomObject]@{
        RepositoryName        = $repoName
        Path                  = $DirectoryPath
        Classification        = $classification
        GitStatus             = $gitStatus
        Branch                = $branch
        HeadCommit            = $headCommit
        DirtyState            = $dirtyState
        AheadBehind           = $aheadBehind
        HasUnpushed           = $hasUnpushed
        LCMStatus             = $lcmStatus
        AbsorbedLCMVersion    = $absorbedVersion
        CurrentLCMVersion     = $currentVersion
        ElevationRequired     = $elevationRequired
        MinimumPrivilege      = $minPrivilege
        ElevationReason       = $elevationReason
        JunctionsHealthy      = $junctionsHealthy
        LastAuditTimestamp    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
}

function Update-WorkspaceInventory {
    [CmdletBinding()]
    param(
        [string]$WorkspaceRoot = (Get-WorkspaceRoot)
    )
    
    Write-Host "Scanning workspace repositories under $WorkspaceRoot..." -ForegroundColor Cyan
    $aiState = Get-WorkspaceAIState
    $globalLCM = $aiState.GlobalLCMVersion
    
    $invDir = Join-Path $WorkspaceRoot 'Workspace_Inventory\data'
    $invPath = Join-Path $invDir 'inventory.json'
    $cachedRepos = @{}
    if (Test-Path $invPath) {
        try {
            $existingInv = Get-Content -Path $invPath -Raw | ConvertFrom-Json
            if ($existingInv.repositories) {
                foreach ($r in $existingInv.repositories) {
                    $cachedRepos[$r.RepositoryName] = $r
                }
            }
        } catch { }
    }
    
    $childDirs = Get-ChildItem -Path $WorkspaceRoot -Directory | Sort-Object Name
    $results = @()
    
    foreach ($dir in $childDirs) {
        $cached = if ($cachedRepos.ContainsKey($dir.Name)) { $cachedRepos[$dir.Name] } else { $null }
        $repoState = Get-RepoCMState -DirectoryPath $dir.FullName -GlobalLCMVersion $globalLCM -CachedRepoState $cached
        $results += $repoState
    }
    
    if (-not (Test-Path $invDir)) {
        New-Item -ItemType Directory -Path $invDir -Force | Out-Null
    }
    
    $jsonObj = [ordered]@{
        '$schema'             = 'https://json-schema.org/draft/2020-12/schema'
        title                 = 'Workspace Repository Inventory & CM State'
        generated_at          = (Get-Date).ToString('o')
        workspace_ai_baseline = $aiState
        total_directories     = @($results).Count
        governed_count        = @($results | Where-Object { $_.LCMStatus -eq 'governed' }).Count
        outdated_count        = @($results | Where-Object { $_.LCMStatus -eq 'outdated' }).Count
        candidate_count       = @($results | Where-Object { $_.LCMStatus -eq 'candidate' }).Count
        standard_git_count    = @($results | Where-Object { $_.Classification -eq 'standard-git' }).Count
        non_git_count         = @($results | Where-Object { $_.Classification -eq 'non-git' }).Count
        elevation_required_count = @($results | Where-Object { $_.ElevationRequired -eq $true }).Count
        repositories          = $results
    }
    
    $jsonPath = Join-Path $invDir 'inventory.json'
    $jsonObj | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Host "Updated inventory JSON: $jsonPath" -ForegroundColor Green
    
    # Generate Markdown Dashboard
    $dashDir = Join-Path $WorkspaceRoot 'Workspace_Inventory\docs'
    if (-not (Test-Path $dashDir)) {
        New-Item -ItemType Directory -Path $dashDir -Force | Out-Null
    }
    
    $totalCount = @($results).Count
    $govCandCount = @($results | Where-Object { $_.LCMStatus -in @('governed', 'candidate') }).Count
    $stdGitCount = @($results | Where-Object { $_.Classification -eq 'standard-git' }).Count
    $nonGitCount = @($results | Where-Object { $_.Classification -eq 'non-git' }).Count
    $elevCount = @($results | Where-Object { $_.ElevationRequired -eq $true }).Count

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Workspace Configuration Management (CM) Inventory Dashboard')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Module: docs/INVENTORY_DASHBOARD.md")
    [void]$sb.AppendLine("Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
    [void]$sb.AppendLine("Global Baseline Version: **v$globalLCM** (Source: `Workspace_AI`)")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## 1. Summary Statistics')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("| Metric | Count | Description |")
    [void]$sb.AppendLine("| :--- | :---: | :--- |")
    [void]$sb.AppendLine("| **Total Directories Audited** | **$totalCount** | All child directories under `D:\Git_Repositories\` |")
    [void]$sb.AppendLine("| **Active Design Workshop** | **1** | `Workspace_AI` (v$globalLCM) |")
    [void]$sb.AppendLine("| **CM Repository** | **1** | `Workspace_Inventory` |")
    [void]$sb.AppendLine("| **LCM Governed / Candidates** | **$govCandCount** | Actively governed under LCM |")
    [void]$sb.AppendLine("| **Elevation Required Repositories** | **$elevCount** | Repositories requiring Administrator privileges |")
    [void]$sb.AppendLine("| **Standard Git Repositories** | **$stdGitCount** | Un-onboarded Git repos |")
    [void]$sb.AppendLine("| **Non-Git Component Folders** | **$nonGitCount** | Non-Git folders (`git.ignoredRepositories`) |")
    [void]$sb.AppendLine("| **Retired Legacy Baselines** | **2** | `Workspace_AC`, `Workspace_GC` |")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## 2. Comprehensive Repository CM Matrix')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Repository Name | Git Status | Branch | HEAD SHA | Working Copy | LCM Status | Absorbed Ver | Current Ver | Elevation | Classification |')
    [void]$sb.AppendLine('| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |')
    
    foreach ($r in $results) {
        $absVer = if ($r.AbsorbedLCMVersion) { "v$($r.AbsorbedLCMVersion)" } else { '-' }
        $curVer = if ($r.CurrentLCMVersion) { "v$($r.CurrentLCMVersion)" } else { '-' }
        $codeName = '`' + $r.RepositoryName + '`'
        $codeBranch = '`' + $r.Branch + '`'
        $codeHead = '`' + $r.HeadCommit + '`'
        $rDirty = $r.DirtyState
        $rLcm = $r.LCMStatus
        $rClass = $r.Classification
        $rGit = $r.GitStatus
        $rElev = if ($r.ElevationRequired) { "**Admin**" } else { "User" }
        [void]$sb.AppendLine("| **$codeName** | $rGit | $codeBranch | $codeHead | $rDirty | **$rLcm** | $absVer | $curVer | $rElev | $rClass |")
    }
    
    $dashPath = Join-Path $dashDir 'INVENTORY_DASHBOARD.md'
    $sb.ToString() | Set-Content -Path $dashPath -Encoding UTF8
    Write-Host "Updated Dashboard Markdown: $dashPath" -ForegroundColor Green
    
    Write-CMLog -Action 'AUDIT_COMPLETE' -TargetRepo 'ALL' -Details "Audited $totalCount repositories. Governed: $($jsonObj.governed_count)"
    
    return $results
}

function Test-WorkspaceDrift {
    [CmdletBinding()]
    param(
        [string]$WorkspaceRoot = (Get-WorkspaceRoot)
    )
    
    $invPath = Join-Path $WorkspaceRoot 'Workspace_Inventory\data\inventory.json'
    if (-not (Test-Path $invPath)) {
        Update-WorkspaceInventory -WorkspaceRoot $WorkspaceRoot | Out-Null
    }
    
    $data = Get-Content -Path $invPath -Raw | ConvertFrom-Json
    $globalVer = $data.workspace_ai_baseline.GlobalLCMVersion
    
    $dirtyRepos = @($data.repositories | Where-Object { $_.DirtyState -ne 'clean' })
    $outdatedRepos = @($data.repositories | Where-Object { $_.LCMStatus -eq 'outdated' })
    $unpushedRepos = @($data.repositories | Where-Object { $_.HasUnpushed -eq $true })
    $brokenJunctions = @($data.repositories | Where-Object { $_.JunctionsHealthy -eq $false -and $_.LCMStatus -eq 'governed' })
    
    $isDrifted = ($dirtyRepos.Count -gt 0 -or $outdatedRepos.Count -gt 0 -or $brokenJunctions.Count -gt 0)
    
    return [PSCustomObject]@{
        Status             = if ($isDrifted) { 'DRIFT_DETECTED' } else { 'CLEAN' }
        GlobalLCMVersion   = $globalVer
        DirtyRepoCount     = $dirtyRepos.Count
        DirtyRepositories  = @($dirtyRepos | Select-Object -ExpandProperty RepositoryName)
        OutdatedRepoCount  = $outdatedRepos.Count
        OutdatedRepositories = @($outdatedRepos | Select-Object -ExpandProperty RepositoryName)
        UnpushedRepoCount  = $unpushedRepos.Count
        UnpushedRepositories = @($unpushedRepos | Select-Object -ExpandProperty RepositoryName)
        BrokenJunctionCount = $brokenJunctions.Count
    }
}

function New-WorkspaceBaseline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$BaselineId,
        [string]$Description = "Baseline snapshot $BaselineId",
        [string]$WorkspaceRoot = (Get-WorkspaceRoot)
    )
    
    $inv = Update-WorkspaceInventory -WorkspaceRoot $WorkspaceRoot
    $aiState = Get-WorkspaceAIState
    
    $baselineObj = [ordered]@{
        '$schema'            = 'https://json-schema.org/draft/2020-12/schema'
        baseline_id          = $BaselineId
        created_at           = (Get-Date).ToString('o')
        description          = $Description
        global_lcm_version   = $aiState.GlobalLCMVersion
        design_workshop      = $aiState
        repositories         = $inv
    }
    
    $baselineDir = Join-Path $WorkspaceRoot 'Workspace_Inventory\data\baselines'
    if (-not (Test-Path $baselineDir)) {
        New-Item -ItemType Directory -Path $baselineDir -Force | Out-Null
    }
    
    $outPath = Join-Path $baselineDir "$BaselineId.json"
    $baselineObj | ConvertTo-Json -Depth 5 | Set-Content -Path $outPath -Encoding UTF8
    
    Write-CMLog -Action 'BASELINE_CREATED' -TargetRepo 'ALL' -Details "Created baseline snapshot: $BaselineId"
    Write-Host "Created baseline snapshot: $outPath" -ForegroundColor Green
    return $outPath
}

function Invoke-BeyondCompareReview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$RepositoryName,
        [string]$BaseCommit,
        [string]$BeyondComparePath = 'D:\Tools\Beyond Compare 5\BCompare.exe'
    )

    $toolScript = Join-Path (Get-WorkspaceRoot) "Workspace_Inventory\tools\Invoke-BeyondCompareReview.ps1"
    & $toolScript -RepositoryName $RepositoryName -BaseCommit $BaseCommit -BeyondComparePath $BeyondComparePath
}

Export-ModuleMember -Function Get-WorkspaceRoot, Write-CMLog, Get-WorkspaceAIState, Get-RepoCMState, Update-WorkspaceInventory, Test-WorkspaceDrift, New-WorkspaceBaseline, Invoke-BeyondCompareReview
