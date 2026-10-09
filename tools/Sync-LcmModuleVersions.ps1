<#
.SYNOPSIS
    Audits and synchronizes LCM module, rule, and documentation versions to enforce the LCM Major Version Alignment Invariant (RULE-DOC-005).
.DESCRIPTION
    Module: tools/Sync-LcmModuleVersions.ps1
    Authors: Rolf, LCM_AI Governance
    Version: 6.0.1
    Date: 2026-09-10
    Rule: RULE-DOC-005, RULE-PS-001 - RULE-PS-014
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Target major release number to enforce (e.g. 7)')]
    [int]$TargetMajor = 7,

    [Parameter(Mandatory = $false, HelpMessage = 'Target active release baseline version string (e.g. 7.5.0)')]
    [string]$TargetBaseline = '7.5.0',

    [Parameter(Mandatory = $false, HelpMessage = 'Apply live version string mutations to documentation and manifests')]
    [switch]$Apply,

    [Parameter(Mandatory = $false, HelpMessage = 'Perform audit only without writing any file changes (default read-only)')]
    [switch]$AuditOnly,

    [Parameter(Mandatory = $false, HelpMessage = 'Root workspace directory containing repository manifests')]
    [string]$RootPath = 'D:\Git_Repositories',

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LCM MODULE & DOC VERSION SYNCHRONIZATION (Sync-LcmModuleVersions)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Audits and synchronizes LCM module, rule, and doc versions (RULE-DOC-005)."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Sync-LcmModuleVersions.ps1 [-TargetMajor <int>] [-TargetBaseline <str>] [-Apply] [-AuditOnly] [-RootPath <str>] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -TargetMajor      : Target major release number (default: 7)"
    Write-Host "  -TargetBaseline   : Target baseline version string (default: 7.5.0)"
    Write-Host "  -Apply            : Apply live version mutations"
    Write-Host "  -AuditOnly        : Perform read-only audit (default)"
    Write-Host "  -RootPath         : Root workspace directory"
    Write-Host "  -Help (-h, -?)    : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM MODULE & DOCUMENTATION VERSION SYNCHRONIZATION (v6.0.0)" -ForegroundColor Cyan
Write-Host " Target Major Baseline: v$TargetMajor.x.x (Active Release: v$TargetBaseline)" -ForegroundColor Cyan
Write-Host " Execution Mode       : $(if ($Apply -and -not $AuditOnly) { 'APPLY (Mutating)' } else { 'AUDIT ONLY (Read-Only)' })" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$today = (Get-Date).ToString('yyyy-MM-dd')
$auditResults = [System.Collections.Generic.List[object]]::new()

function Update-VersionString {
    param(
        [string]$CurrentVersion,
        [int]$NewMajor
    )
    if ([string]::IsNullOrWhiteSpace($CurrentVersion)) { return "$NewMajor.0.0" }
    $clean = $CurrentVersion.Trim().TrimStart('v', 'V')
    $parts = $clean.Split('.')
    $minor = if ($parts.Count -gt 1) { $parts[1] } else { '0' }
    $patch = if ($parts.Count -gt 2) { $parts[2] } else { '0' }
    return "$NewMajor.$minor.$patch"
}

# 1. Scan and process .agents/rules/*.md
$ruleFiles = @(Get-ChildItem -Path (Join-Path $RootPath '.agents\rules\*.md') -ErrorAction SilentlyContinue)
foreach ($rf in $ruleFiles) {
    $content = Get-Content -LiteralPath $rf.FullName -Raw -Encoding UTF8
    $relPath = $rf.FullName.Replace("$RootPath\", '')
    
    $verMatch = [regex]::Match($content, '(?m)^Version:\s*(\S+)')
    if ($verMatch.Success) {
        $oldVer = $verMatch.Groups[1].Value
        $newVer = Update-VersionString -CurrentVersion $oldVer -NewMajor $TargetMajor
        $isAligned = ($oldVer.Split('.')[0] -eq "$TargetMajor")
        
        $auditResults.Add([PSCustomObject]@{
            File     = $relPath
            Category = 'Canonical Rule'
            Current  = $oldVer
            Target   = $newVer
            Aligned  = $isAligned
            Action   = if (-not $isAligned -and $Apply) { 'UPDATED' } elseif ($isAligned) { 'CONFORMANT' } else { 'NEEDS_UPDATE' }
        })

        if ($Apply -and -not $isAligned) {
            $content = [regex]::Replace($content, '(?m)^Version:\s*\S+', "Version: $newVer")
            $content = [regex]::Replace($content, '(?m)^Date:\s*\S+', "Date: $today")
            Set-Content -LiteralPath $rf.FullName -Value $content -Encoding UTF8
        }
    }
}

# 2. Scan and process .github/agents and .copilot
$agentConfigFiles = @(
    (Join-Path $RootPath '.github\agents\Config.json'),
    (Join-Path $RootPath '.github\agents\agent.json'),
    (Join-Path $RootPath '.github\agents\copilot365-agent.json'),
    (Join-Path $RootPath '.copilot\copilot365-agent.json'),
    (Join-Path $RootPath '.vscode\settings.json')
)

foreach ($cf in $agentConfigFiles) {
    if (Test-Path -LiteralPath $cf) {
        $relPath = $cf.Replace("$RootPath\", '')
        $content = Get-Content -LiteralPath $cf -Raw -Encoding UTF8
        $json = $content | ConvertFrom-Json
        
        $currentVer = $null
        if ($json.PSObject.Properties['meta'] -and $json.meta.PSObject.Properties['version']) {
            $currentVer = [string]$json.meta.version
        } elseif ($json.PSObject.Properties['version']) {
            $currentVer = [string]$json.version
        }

        if ($currentVer) {
            $newVer = Update-VersionString -CurrentVersion $currentVer -NewMajor $TargetMajor
            $isAligned = ($currentVer.Split('.')[0] -eq "$TargetMajor")
            
            $auditResults.Add([PSCustomObject]@{
                File     = $relPath
                Category = 'Config / Profile'
                Current  = $currentVer
                Target   = $newVer
                Aligned  = $isAligned
                Action   = if (-not $isAligned -and $Apply) { 'UPDATED' } elseif ($isAligned) { 'CONFORMANT' } else { 'NEEDS_UPDATE' }
            })

            if ($Apply -and -not $isAligned) {
                if ($json.PSObject.Properties['meta'] -and $json.meta.PSObject.Properties['version']) {
                    $json.meta.version = $newVer
                } elseif ($json.PSObject.Properties['version']) {
                    $json.version = $newVer
                }
                $json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cf -Encoding UTF8
            }
        }
    }
}

# 3. Scan .github/agents/*.md and .copilot/*.md
$agentMdFiles = @(
    Get-ChildItem -Path (Join-Path $RootPath '.github\agents\*.md') -ErrorAction SilentlyContinue
    Get-ChildItem -Path (Join-Path $RootPath '.copilot\*.md') -ErrorAction SilentlyContinue
)
foreach ($mf in $agentMdFiles) {
    $content = Get-Content -LiteralPath $mf.FullName -Raw -Encoding UTF8
    $relPath = $mf.FullName.Replace("$RootPath\", '')
    $verMatch = [regex]::Match($content, '(?m)^(?:#\s*)?Version:\s*(\S+)')
    if ($verMatch.Success) {
        $oldVer = $verMatch.Groups[1].Value
        $newVer = Update-VersionString -CurrentVersion $oldVer -NewMajor $TargetMajor
        $isAligned = ($oldVer.Split('.')[0] -eq "$TargetMajor")
        
        $auditResults.Add([PSCustomObject]@{
            File     = $relPath
            Category = 'Agent Template/Rule'
            Current  = $oldVer
            Target   = $newVer
            Aligned  = $isAligned
            Action   = if (-not $isAligned -and $Apply) { 'UPDATED' } elseif ($isAligned) { 'CONFORMANT' } else { 'NEEDS_UPDATE' }
        })

        if ($Apply -and -not $isAligned) {
            $content = [regex]::Replace($content, '(?m)^(?:#\s*)?Version:\s*\S+', "Version: $newVer")
            Set-Content -LiteralPath $mf.FullName -Value $content -Encoding UTF8
        }
    }
}

# 4. Scan LCM_AI/docs/*.md
$waiDocs = @(Get-ChildItem -Path (Join-Path $RootPath 'LCM_AI\docs\*.md') -ErrorAction SilentlyContinue)
foreach ($doc in $waiDocs) {
    $content = Get-Content -LiteralPath $doc.FullName -Raw -Encoding UTF8
    $relPath = $doc.FullName.Replace("$RootPath\", '')
    $verMatch = [regex]::Match($content, '(?m)^(?:#\s*)?Version:\s*(\S+)')
    if ($verMatch.Success) {
        $oldVer = $verMatch.Groups[1].Value
        $newVer = Update-VersionString -CurrentVersion $oldVer -NewMajor $TargetMajor
        $isAligned = ($oldVer.Split('.')[0] -eq "$TargetMajor")
        
        $auditResults.Add([PSCustomObject]@{
            File     = $relPath
            Category = 'LCM_AI Doc'
            Current  = $oldVer
            Target   = $newVer
            Aligned  = $isAligned
            Action   = if (-not $isAligned -and $Apply) { 'UPDATED' } elseif ($isAligned) { 'CONFORMANT' } else { 'NEEDS_UPDATE' }
        })

        if ($Apply -and -not $isAligned) {
            $content = [regex]::Replace($content, '(?m)^(?:#\s*)?Version:\s*\S+', "Version: $newVer")
            Set-Content -LiteralPath $doc.FullName -Value $content -Encoding UTF8
        }
    }
}

# 5. Render Audit Table
$auditList = @($auditResults)
$misalignedCount = @($auditList | Where-Object { -not $_.Aligned }).Count
$totalCount = $auditList.Count

Write-Host "`n Audit Summary: $totalCount items checked | $(if ($misalignedCount -eq 0) { 'ALL CONFORMANT (0 misaligned)' } else { "$misalignedCount OUTDATED / MISALIGNED" })`n" -ForegroundColor $(if ($misalignedCount -eq 0) { 'Green' } else { 'Yellow' })

$auditList | Format-Table -AutoSize -Property File, Category, Current, Target, Action

if (-not $Apply) {
    Write-Host "`nTo apply version alignment across all targets, run with -Apply:" -ForegroundColor Cyan
    Write-Host "  pwsh -File tools/Sync-LcmModuleVersions.ps1 -Apply`n" -ForegroundColor Yellow
}
