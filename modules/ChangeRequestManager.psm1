# =====================================================================
# ChangeRequestManager.psm1 - Multi-Repository Change Request Manager
# =====================================================================
# Module: ChangeRequestManager
# Purpose: Indexing, registering, searching, and managing Change Requests
#          and proposal lifecycles across the entire workspace.
# Authors: Rolf, Workspace_AI Engine
# Version: 1.0.0
# Date: 2026-08-15
# =====================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ChangeRequestsFile {
    [CmdletBinding()]
    param()
    
    $scriptRoot = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        $scriptRoot = (Get-Location).Path
    }
    
    # Climb up to find Workspace_Inventory root
    $item = Get-Item $scriptRoot
    while ($item -ne $null -and $item.Name -ne 'Workspace_Inventory' -and $item.Name -ne 'Git_Repositories') {
        $item = $item.Parent
    }
    
    if ($item -ne $null) {
        if ($item.Name -eq 'Workspace_Inventory') {
            return (Join-Path $item.FullName 'data\change_requests.json')
        } elseif ($item.Name -eq 'Git_Repositories') {
            return (Join-Path $item.FullName 'Workspace_Inventory\data\change_requests.json')
        }
    }
    
    return 'D:\Git_Repositories\Workspace_Inventory\data\change_requests.json'
}

function Get-ChangeRequests {
    [CmdletBinding()]
    param()
    
    $file = Get-ChangeRequestsFile
    if (-not (Test-Path $file)) {
        return @()
    }
    
    $data = Get-Content -Path $file -Raw | ConvertFrom-Json
    return @($data.change_requests)
}

function Find-ChangeRequest {
    [CmdletBinding()]
    param(
        [string]$Query,
        [string]$Repository,
        [string]$Status,
        [string]$Author
    )
    
    $records = Get-ChangeRequests
    
    if (-not [string]::IsNullOrWhiteSpace($Query)) {
        $q = $Query.ToLowerInvariant()
        $records = @($records | Where-Object {
            ($_.cr_id -and $_.cr_id.ToLowerInvariant().Contains($q)) -or
            ($_.title -and $_.title.ToLowerInvariant().Contains($q)) -or
            ($_.origin_repo -and $_.origin_repo.ToLowerInvariant().Contains($q)) -or
            ($_.legacy_id -and $_.legacy_id.ToLowerInvariant().Contains($q))
        })
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Repository)) {
        $r = $Repository.ToLowerInvariant()
        $records = @($records | Where-Object {
            ($_.origin_repo -and $_.origin_repo.ToLowerInvariant().Contains($r)) -or
            ($_.affected_repos -and ($_.affected_repos | ForEach-Object { $_.ToLowerInvariant() }) -contains $r)
        })
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Status)) {
        $s = $Status.ToLowerInvariant()
        $records = @($records | Where-Object {
            $_.status -and $_.status.ToLowerInvariant() -eq $s
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

function Register-ChangeRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$Title,
        [Parameter(Mandatory=$true)] [string]$OriginRepo,
        [string]$Status = 'proposed',
        [string]$TargetLCMVersion = '4.1.0',
        [string[]]$AffectedRepos = @($OriginRepo),
        [string]$Author = 'Rolf',
        [string]$DocumentationPath,
        [string]$LegacyId
    )
    
    $file = Get-ChangeRequestsFile
    $data = if (Test-Path $file) {
        Get-Content -Path $file -Raw | ConvertFrom-Json
    } else {
        [PSCustomObject]@{
            '$schema' = 'https://json-schema.org/draft/2020-12/schema'
            title = 'Workspace Change Requests Index'
            generated_at = (Get-Date).ToString('o')
            total_records = 0
            change_requests = @()
        }
    }
    
    $existing = [System.Collections.Generic.List[PSObject]]::new(@($data.change_requests))
    $nextNum = $existing.Count + 1
    $crId = "CR-$((Get-Date).ToString('yyyy'))-$($nextNum.ToString('000'))"
    
    $newCR = [ordered]@{
        cr_id              = $crId
        legacy_id          = $LegacyId
        origin_repo        = $OriginRepo
        title              = $Title
        status             = $Status
        target_lcm_version = $TargetLCMVersion
        affected_repos     = $AffectedRepos
        created_at         = (Get-Date).ToString('o')
        closed_at          = if ($Status -in @('closed', 'implemented', 'verified')) { (Get-Date).ToString('o') } else { $null }
        author             = $Author
        documentation_path = $DocumentationPath
    }
    
    $existing.Add([PSCustomObject]$newCR)
    
    $outObj = [ordered]@{
        '$schema'         = 'https://json-schema.org/draft/2020-12/schema'
        title             = 'Workspace Change Requests Index'
        generated_at      = (Get-Date).ToString('o')
        total_records     = $existing.Count
        change_requests   = $existing
    }
    
    $outObj | ConvertTo-Json -Depth 5 | Set-Content -Path $file -Encoding UTF8
    Write-Host "Registered Change Request: $crId ($Title)" -ForegroundColor Green
    
    return [PSCustomObject]$newCR
}

function Export-ChangeRequestDashboard {
    [CmdletBinding()]
    param()
    
    $records = Get-ChangeRequests
    $file = Get-ChangeRequestsFile
    $dir = (Get-Item $file).Directory.Parent.FullName
    $outPath = Join-Path $dir 'docs\CHANGE_REQUEST_INDEX.md'
    
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Master Change Request (CR) Index')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Module: docs/CHANGE_REQUEST_INDEX.md")
    [void]$sb.AppendLine("Updated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
    [void]$sb.AppendLine("Total Tracked CRs: **$($records.Count)**")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| CR ID | Legacy ID | Origin Repo | Title | Status | Target Ver | Author | Created |')
    [void]$sb.AppendLine('| :--- | :--- | :--- | :--- | :---: | :---: | :--- | :--- |')
    
    foreach ($cr in $records) {
        $codeCrId = '`' + $cr.cr_id + '`'
        $leg = if ($cr.legacy_id) { '`' + $cr.legacy_id + '`' } else { '-' }
        $codeOrig = '`' + $cr.origin_repo + '`'
        $title = $cr.title
        $stat = $cr.status
        $tVer = $cr.target_lcm_version
        $author = $cr.author
        $created = if ($cr.created_at) { $cr.created_at.Substring(0,10) } else { '-' }
        [void]$sb.AppendLine("| **$codeCrId** | $leg | $codeOrig | $title | **$stat** | v$tVer | $author | $created |")
    }
    
    $sb.ToString() | Set-Content -Path $outPath -Encoding UTF8
    Write-Host "Exported CR Index to: $outPath" -ForegroundColor Green
    return $outPath
}

Export-ModuleMember -Function Get-ChangeRequestsFile, Get-ChangeRequests, Find-ChangeRequest, Register-ChangeRequest, Export-ChangeRequestDashboard
