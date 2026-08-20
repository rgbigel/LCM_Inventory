# =====================================================================
# ChangeRequestManager.psm1 - Multi-Repository Change Request Manager
# =====================================================================
# Module: ChangeRequestManager
# Purpose: Manages 1-file-per-CR Markdown documents mirrored via NTFS junctions,
#          CR bundling for batch test sequences, querying, and dashboard export.
# Authors: Rolf, Workspace_AI Engine
# Version: 2.0.0
# Date: 2026-08-15
# =====================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CRMirrorRoot {
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
    
    if ($item -ne $null) {
        if ($item.Name -eq 'Workspace_Inventory') {
            return (Join-Path $item.FullName 'change_requests')
        } elseif ($item.Name -eq 'Git_Repositories') {
            return (Join-Path $item.FullName 'Workspace_Inventory\change_requests')
        }
    }
    
    return 'D:\Git_Repositories\Workspace_Inventory\change_requests'
}

function Get-BundlesDir {
    [CmdletBinding()]
    param()
    
    $crRoot = Get-CRMirrorRoot
    $wiRoot = (Get-Item $crRoot).Parent.FullName
    $bundlesDir = Join-Path $wiRoot 'data\bundles'
    if (-not (Test-Path $bundlesDir)) {
        New-Item -ItemType Directory -Path $bundlesDir -Force | Out-Null
    }
    return $bundlesDir
}

function Sync-CRJunctions {
    [CmdletBinding()]
    param(
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )
    
    $crRoot = Get-CRMirrorRoot
    if (-not (Test-Path $crRoot)) {
        New-Item -ItemType Directory -Path $crRoot -Force | Out-Null
    }
    
    $childDirs = Get-ChildItem -Path $WorkspaceRoot -Directory
    $linkedCount = 0
    
    foreach ($dir in $childDirs) {
        $repoName = $dir.Name
        $targetProposals = Join-Path $dir.FullName 'Docs\Methods\Proposals'
        if (-not (Test-Path $targetProposals)) {
            $altProposals = Join-Path $dir.FullName 'docs\Proposals'
            if (Test-Path $altProposals) {
                $targetProposals = $altProposals
            }
        }
        
        if (Test-Path $targetProposals) {
            $junctionPath = Join-Path $crRoot $repoName
            if (-not (Test-Path $junctionPath)) {
                cmd /c mklink /J "$junctionPath" "$targetProposals" 2>$null | Out-Null
                $linkedCount++
            }
        }
    }
    
    return $linkedCount
}

function Parse-CRFrontmatter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$FilePath
    )
    
    $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
    $cr = [ordered]@{
        cr_id              = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
        legacy_id          = '-'
        origin_repo        = 'Unknown'
        title              = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
        status             = 'proposed'
        target_lcm_version = '4.1.0'
        bundle_id          = 'unassigned'
        affected_repos     = @()
        author             = 'Rolf'
        created_at         = (Get-Item $FilePath).CreationTime.ToString('yyyy-MM-dd')
        file_path          = $FilePath
    }
    
    if ($content -match '(?s)^---\r?\n(.*?)\r?\n---') {
        $yaml = $Matches[1]
        foreach ($line in ($yaml -split '\r?\n')) {
            if ($line -match '^\s*([^:]+)\s*:\s*(.*)$') {
                $k = $Matches[1].Trim().ToLowerInvariant()
                $v = $Matches[2].Trim().Trim('"').Trim("'")
                
                if ($k -eq 'cr_id') { $cr['cr_id'] = $v }
                elseif ($k -eq 'legacy_id') { $cr['legacy_id'] = $v }
                elseif ($k -eq 'origin_repo') { $cr['origin_repo'] = $v }
                elseif ($k -eq 'title') { $cr['title'] = $v }
                elseif ($k -eq 'status') { $cr['status'] = $v }
                elseif ($k -eq 'target_lcm_version') { $cr['target_lcm_version'] = $v }
                elseif ($k -eq 'bundle_id') { $cr['bundle_id'] = $v }
                elseif ($k -eq 'author') { $cr['author'] = $v }
                elseif ($k -eq 'created_at') { $cr['created_at'] = $v }
            }
        }
    }
    
    return [PSCustomObject]$cr
}

function Get-ChangeRequests {
    [CmdletBinding()]
    param()
    
    $crRoot = Get-CRMirrorRoot
    if (-not (Test-Path $crRoot)) {
        return @()
    }
    
    $dirs = @(Get-ChildItem -Path $crRoot -ErrorAction SilentlyContinue)
    $results = @()
    
    foreach ($d in $dirs) {
        if (-not (Test-Path -LiteralPath $d.FullName)) {
            continue
        }
        $files = @(Get-ChildItem -Path $d.FullName -Filter '*.md' -ErrorAction SilentlyContinue)
        foreach ($file in $files) {
            $parsed = Parse-CRFrontmatter -FilePath $file.FullName
            $results += $parsed
        }
    }
    
    return @($results | Sort-Object cr_id)
}

function Find-ChangeRequest {
    [CmdletBinding()]
    param(
        [string]$Query,
        [string]$Repository,
        [string]$Status,
        [string]$BundleId,
        [string]$Author
    )
    
    $records = Get-ChangeRequests
    
    if (-not [string]::IsNullOrWhiteSpace($Query)) {
        $q = $Query.ToLowerInvariant()
        $records = @($records | Where-Object {
            ($_.cr_id -and $_.cr_id.ToLowerInvariant().Contains($q)) -or
            ($_.title -and $_.title.ToLowerInvariant().Contains($q)) -or
            ($_.origin_repo -and $_.origin_repo.ToLowerInvariant().Contains($q)) -or
            ($_.legacy_id -and $_.legacy_id.ToLowerInvariant().Contains($q)) -or
            ($_.bundle_id -and $_.bundle_id.ToLowerInvariant().Contains($q))
        })
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Repository)) {
        $r = $Repository.ToLowerInvariant()
        $records = @($records | Where-Object {
            $_.origin_repo -and $_.origin_repo.ToLowerInvariant().Contains($r)
        })
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Status)) {
        $s = $Status.ToLowerInvariant()
        $records = @($records | Where-Object {
            $_.status -and $_.status.ToLowerInvariant() -eq $s
        })
    }
    
    if (-not [string]::IsNullOrWhiteSpace($BundleId)) {
        $b = $BundleId.ToLowerInvariant()
        $records = @($records | Where-Object {
            $_.bundle_id -and $_.bundle_id.ToLowerInvariant().Contains($b)
        })
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Author)) {
        $a = $Author.ToLowerInvariant()
        $records = @($records | Where-Object {
            $_.author -and $_.author.ToLowerInvariant().Contains($a)
        })
    }
    
    return $records
}

function New-ChangeRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$Title,
        [Parameter(Mandatory=$true)] [string]$OriginRepo,
        [string]$Status = 'proposed',
        [string]$TargetLCMVersion = '4.1.0',
        [string]$BundleId = 'unassigned',
        [string]$Author = 'Rolf',
        [string]$Summary = '',
        [string]$LegacyId = '-'
    )
    
    $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $crId = "CR-$timestamp"
    
    $targetProposals = "D:\Git_Repositories\$OriginRepo\Docs\Methods\Proposals"
    if (-not (Test-Path $targetProposals)) {
        New-Item -ItemType Directory -Path $targetProposals -Force | Out-Null
    }
    
    Sync-CRJunctions | Out-Null
    
    $filePath = Join-Path $targetProposals "$crId.md"
    $dateStr = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    
    $content = @"
---
cr_id: $crId
legacy_id: $LegacyId
origin_repo: $OriginRepo
title: $Title
status: $Status
target_lcm_version: $TargetLCMVersion
bundle_id: $BundleId
author: $Author
created_at: $dateStr
---

# ${crId}: $Title

- **Origin Repository**: ``$OriginRepo``
- **Target LCM Version**: ``v$TargetLCMVersion``
- **Status**: **$Status**
- **Bundle**: ``$BundleId``

## Summary
$Summary
"@
    Set-Content -Path $filePath -Value $content -Encoding UTF8
    Write-Host "Created single-file Change Request: $filePath" -ForegroundColor Green
    
    return Parse-CRFrontmatter -FilePath $filePath
}

function Get-CRBundles {
    [CmdletBinding()]
    param()
    
    $bDir = Get-BundlesDir
    $files = @(Get-ChildItem -Path $bDir -Filter '*.json')
    $bundles = @()
    
    foreach ($f in $files) {
        try {
            $data = Get-Content -Path $f.FullName -Raw | ConvertFrom-Json
            $bundles += $data
        } catch { }
    }
    
    return $bundles
}

function New-CRBundle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$BundleId,
        [Parameter(Mandatory=$true)] [string]$Name,
        [string[]]$CRIds = @(),
        [string]$TestSuite = 'Test-WorkspaceReadiness.ps1',
        [string]$TargetLCMVersion = '4.1.0',
        [string]$Status = 'draft'
    )
    
    $bDir = Get-BundlesDir
    $bundlePath = Join-Path $bDir "$BundleId.json"
    
    $bObj = [ordered]@{
        '$schema'            = 'https://json-schema.org/draft/2020-12/schema'
        bundle_id            = $BundleId
        name                 = $Name
        status               = $Status
        target_lcm_version   = $TargetLCMVersion
        test_suite           = $TestSuite
        created_at           = (Get-Date).ToString('o')
        change_request_ids   = $CRIds
    }
    
    $bObj | ConvertTo-Json -Depth 5 | Set-Content -Path $bundlePath -Encoding UTF8
    Write-Host "Created CR Bundle: $BundleId ($Name)" -ForegroundColor Green
    return [PSCustomObject]$bObj
}

function Add-CRToBundle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$BundleId,
        [Parameter(Mandatory=$true)] [string[]]$CRIds
    )
    
    $bDir = Get-BundlesDir
    $bundlePath = Join-Path $bDir "$BundleId.json"
    if (-not (Test-Path $bundlePath)) {
        throw "Bundle $BundleId not found at $bundlePath"
    }
    
    $bObj = Get-Content -Path $bundlePath -Raw | ConvertFrom-Json
    $list = [System.Collections.Generic.List[string]]::new(@($bObj.change_request_ids))
    
    foreach ($id in $CRIds) {
        if (-not $list.Contains($id)) {
            $list.Add($id)
        }
    }
    
    $bObj.change_request_ids = @($list)
    $bObj | ConvertTo-Json -Depth 5 | Set-Content -Path $bundlePath -Encoding UTF8
    Write-Host "Updated Bundle $BundleId with $($CRIds.Count) CR(s)." -ForegroundColor Green
}

function Export-ChangeRequestDashboard {
    [CmdletBinding()]
    param()
    
    Sync-CRJunctions | Out-Null
    $records = Get-ChangeRequests
    $bundles = Get-CRBundles
    
    $crRoot = Get-CRMirrorRoot
    $wiRoot = (Get-Item $crRoot).Parent.FullName
    $dashPath = Join-Path $wiRoot 'docs\CHANGE_REQUEST_INDEX.md'
    
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Master Change Request (CR) & Bundle Index')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Module: docs/CHANGE_REQUEST_INDEX.md")
    [void]$sb.AppendLine("Updated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
    [void]$sb.AppendLine("Storage Architecture: **NTFS Junction Mirrored (1 File per CR)**")
    [void]$sb.AppendLine("Total Tracked CRs: **$(@($records).Count)** | Bundles: **$(@($bundles).Count)**")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## 1. Change Request Bundles (Batch Test Suites)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Bundle ID | Bundle Name | Target Ver | Test Suite | Status | Included CRs |')
    [void]$sb.AppendLine('| :--- | :--- | :---: | :--- | :---: | :--- |')
    
    foreach ($b in $bundles) {
        $codeBId = '`' + $b.bundle_id + '`'
        $codeSuite = '`' + $b.test_suite + '`'
        $crList = ($b.change_request_ids | ForEach-Object { '`' + $_ + '`' }) -join ', '
        [void]$sb.AppendLine("| **$codeBId** | $($b.name) | v$($b.target_lcm_version) | $codeSuite | **$($b.status)** | $crList |")
    }
    
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## 2. Individual Change Requests (1 File per CR)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| CR ID | Origin Repo | Bundle | Title | Status | Target Ver | Author | Created |')
    [void]$sb.AppendLine('| :--- | :--- | :---: | :--- | :---: | :---: | :--- | :--- |')
    
    foreach ($cr in $records) {
        $codeCrId = '`' + $cr.cr_id + '`'
        $codeOrig = '`' + $cr.origin_repo + '`'
        $codeBundle = if ($cr.bundle_id -and $cr.bundle_id -ne 'unassigned') { '`' + $cr.bundle_id + '`' } else { '-' }
        $title = $cr.title
        $stat = $cr.status
        $tVer = $cr.target_lcm_version
        $author = $cr.author
        $created = if ($cr.created_at) { $cr.created_at } else { '-' }
        [void]$sb.AppendLine("| **$codeCrId** | $codeOrig | $codeBundle | $title | **$stat** | v$tVer | $author | $created |")
    }
    
    $sb.ToString() | Set-Content -Path $dashPath -Encoding UTF8
    Write-Host "Exported Change Request Dashboard: $dashPath" -ForegroundColor Green
    return $dashPath
}

Export-ModuleMember -Function Get-CRMirrorRoot, Get-BundlesDir, Sync-CRJunctions, Parse-CRFrontmatter, Get-ChangeRequests, Find-ChangeRequest, New-ChangeRequest, Get-CRBundles, New-CRBundle, Add-CRToBundle, Export-ChangeRequestDashboard
