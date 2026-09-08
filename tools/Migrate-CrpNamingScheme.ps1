<#
.SYNOPSIS
    Migrates legacy CRP/BUG identifiers to the universal monotonic CRP/BUG-nnn naming scheme per CRP-119.
.DESCRIPTION
    Module: tools/Migrate-CrpNamingScheme.ps1
    Purpose: Renames proposal documents in Workspace_Inventory/docs/Proposals/ and change_requests/ to direct
             1:1 parity with their canonical proposals.json ID (CRP-nnn or BUG-nnn), updates document DOX
             headers, and normalizes crp_id, cr_id, and plan_path across proposals.json.
    Authors: Rolf, Workspace_AI Engine
    Version: 1.0.2
    Date: 2026-09-08
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " CRP/BUG-nnn UNIVERSAL MONOTONIC MIGRATION TOOL (CRP-119)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Normalizes all proposal records in proposals.json and renames proposal files"
    Write-Host "  in Workspace_Inventory/docs/Proposals/ using Git to match their canonical ID."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh Workspace_Inventory/tools/Migrate-CrpNamingScheme.ps1 [-WhatIf] [-Force]"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$workspaceRoot = 'D:\Git_Repositories'
$wiRoot = Join-Path $workspaceRoot 'Workspace_Inventory'
$proposalsJsonPath = Join-Path $wiRoot 'data\proposals\proposals.json'

if (-not (Test-Path -LiteralPath $proposalsJsonPath)) {
    throw "Proposals ledger not found at $proposalsJsonPath"
}

Write-Host "Loading proposals ledger: $proposalsJsonPath" -ForegroundColor Cyan
$rawJson = Get-Content -LiteralPath $proposalsJsonPath -Raw -Encoding UTF8
$store = $rawJson | ConvertFrom-Json

$proposals = @($store.proposals)

Write-Host "Auditing $($proposals.Count) proposals in ledger..." -ForegroundColor Cyan

$renamedFilesCount = 0
$updatedProposalsCount = 0

foreach ($p in $proposals) {
    $id = [int]$p.id
    
    $currentCrpId = if ($null -ne $p.PSObject.Properties['crp_id']) { [string]$p.crp_id } else { '' }
    $currentCrId = if ($null -ne $p.PSObject.Properties['cr_id']) { [string]$p.cr_id } else { '' }
    $currentState = if ($null -ne $p.PSObject.Properties['state']) { [string]$p.state } else { '' }
    $currentTitle = if ($null -ne $p.PSObject.Properties['title']) { [string]$p.title } else { '' }
    $currentBundle = if ($null -ne $p.PSObject.Properties['bundle_id']) { [string]$p.bundle_id } else { '' }
    $currentPlanPath = if ($null -ne $p.PSObject.Properties['plan_path']) { [string]$p.plan_path } else { '' }

    # Determine canonical prefix: BUG or CRP
    $isBug = ($currentState -eq 'bug') -or 
             ($currentCrId -match '^BUG-') -or 
             ($currentCrpId -match '^BUG-') -or 
             ($currentTitle -match '\[BUG\]')
    
    $prefix = if ($isBug) { 'BUG' } else { 'CRP' }
    $canonicalId = "{0}-{1:D3}" -f $prefix, $id
    
    # Update crp_id and cr_id
    if ($currentCrpId -ne $canonicalId) {
        $p | Add-Member -NotePropertyName "crp_id" -NotePropertyValue $canonicalId -Force
        $updatedProposalsCount++
    }
    if ($currentCrId -ne $canonicalId) {
        $p | Add-Member -NotePropertyName "cr_id" -NotePropertyValue $canonicalId -Force
        $updatedProposalsCount++
    }
    if ($currentBundle -and ($currentBundle -match '^(?:CRP|BUG)-')) {
        $p.bundle_id = $canonicalId
    }

    # Inspect plan_path to see if it points to a markdown document under Workspace_Inventory
    if ($currentPlanPath -and ($currentPlanPath -match '^(Workspace_Inventory/(?:docs/Proposals|change_requests/[^/]+))/([^/]+)$')) {
        $parentRelDir = $Matches[1]
        $currentFileName = $Matches[2]
        $parentFullDir = Join-Path $workspaceRoot $parentRelDir.Replace('/', '\')
        $currentFullPath = Join-Path $parentFullDir $currentFileName
        
        # Check if the file needs renaming:
        # e.g., begins with CRP-2026-yyy- or BUG-2026-yyy- or CRP-yyy- where yyy != canonicalId
        if ($currentFileName -match '^(?:CRP|BUG)-(?:2026-)?(\d{3})-(.+)$') {
            $existingNum = $Matches[1]
            $slug = $Matches[2]
            $expectedFileName = "{0}-{1}" -f $canonicalId, $slug
            
            if ($currentFileName -ne $expectedFileName) {
                $targetFullPath = Join-Path $parentFullDir $expectedFileName
                
                Write-Host ("Renaming Proposal #{0} document:" -f $id) -ForegroundColor Yellow
                Write-Host ("  From: {0}" -f $currentFileName) -ForegroundColor Gray
                Write-Host ("  To  : {0}" -f $expectedFileName) -ForegroundColor Green
                
                if ($PSCmdlet.ShouldProcess("$currentFileName -> $expectedFileName", "Rename proposal document")) {
                    if (Test-Path -LiteralPath $currentFullPath) {
                        # Check if tracked by git
                        $isGitTracked = $false
                        $relToWi = ($currentFullPath.Substring($wiRoot.Length + 1)).Replace('\', '/')
                        $gitStatus = & git -C $wiRoot ls-files "$relToWi" 2>$null
                        if ($gitStatus -and $gitStatus.Trim().Length -gt 0) {
                            $isGitTracked = $true
                        }

                        $targetRelToWi = ($targetFullPath.Substring($wiRoot.Length + 1)).Replace('\', '/')
                        if ($isGitTracked) {
                            & git -C $wiRoot mv "$relToWi" "$targetRelToWi"
                        } else {
                            Move-Item -LiteralPath $currentFullPath -Destination $targetFullPath -Force
                        }

                        # Update internal Markdown header and metadata in target file
                        if (Test-Path -LiteralPath $targetFullPath) {
                            $docContent = Get-Content -LiteralPath $targetFullPath -Raw -Encoding UTF8
                            # Replace old title / header e.g. "CRP-2026-032 (CRP-118)" -> "CRP-118"
                            $docContent = [regex]::Replace($docContent, '(?i)(?:CRP|BUG)-(?:2026-)?\d{3}\s*\((?:CRP|BUG)-\d{3}\)', $canonicalId)
                            $oldIdPattern = '(?i)\b(?:CRP|BUG)-(?:2026-)?' + [regex]::Escape($existingNum) + '\b'
                            $docContent = [regex]::Replace($docContent, $oldIdPattern, $canonicalId)
                            # Also clean up `CRP-118 / CRP-2026-032` or similar in metadata table
                            $docContent = [regex]::Replace($docContent, '`' + [regex]::Escape($canonicalId) + '`\s*/\s*`[^`]+`', '`' + $canonicalId + '`')
                            Set-Content -LiteralPath $targetFullPath -Value $docContent -Encoding UTF8
                        }

                        $renamedFilesCount++
                    } else {
                        Write-Warning "Source file does not exist on disk: $currentFullPath"
                    }
                }

                # Update plan_path in proposal
                $p.plan_path = "$parentRelDir/$expectedFileName"
                $updatedProposalsCount++
            }
        }
    }
}

# Also update proposals 37..44 whose plan_path pointed to files that were renamed
$proposals37to44 = @($proposals | Where-Object { $_.id -ge 37 -and $_.id -le 44 })
foreach ($pOld in $proposals37to44) {
    $planP = if ($null -ne $pOld.PSObject.Properties['plan_path']) { [string]$pOld.plan_path } else { '' }
    if ($planP -and ($planP -match 'Workspace_Inventory/docs/Proposals/([^/]+)$')) {
        $oldFile = $Matches[1]
        $matchedNew = $proposals | Where-Object { $_.id -ge 88 -and $_.title -eq $pOld.title } | Select-Object -First 1
        if ($matchedNew -and $matchedNew.plan_path) {
            $pOld.plan_path = $matchedNew.plan_path
        }
    }
}

# Write updated proposals.json
if ($PSCmdlet.ShouldProcess($proposalsJsonPath, "Save normalized proposals ledger")) {
    $store.updated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    $newJson = $store | ConvertTo-Json -Depth 6
    Set-Content -LiteralPath $proposalsJsonPath -Value $newJson -Encoding UTF8
    Write-Host "Saved updated proposals ledger to $proposalsJsonPath" -ForegroundColor Green
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host (" Migration completed. Files renamed: {0} | Proposal records updated: {1}" -f $renamedFilesCount, $updatedProposalsCount) -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
