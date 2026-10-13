<#
.SYNOPSIS
    Audits and synchronizes LCM module, rule, and documentation versions to enforce the LCM Major Version Alignment Invariant (RULE-DOC-005).
.DESCRIPTION
    Module: tools/Sync-LcmModuleVersions.ps1
    Authors: Rolf, LCM_AI Governance
    Version: 10.0.0
    Date: 2026-10-13
    Rule: RULE-DOC-005, RULE-PS-001 - RULE-PS-014
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Target major release number to enforce (e.g. 10)')]
    [int]$TargetMajor = 10,

    [Parameter(Mandatory = $false, HelpMessage = 'Target active release baseline version string (e.g. 10.0.0)')]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$TargetBaseline = '10.0.0',

    [Parameter(Mandatory = $false, HelpMessage = 'Apply live version string mutations to documentation and manifests')]
    [switch]$Apply,

    [Parameter(Mandatory = $false, HelpMessage = 'Perform audit only without writing any file changes (default read-only)')]
    [switch]$AuditOnly,

    [Parameter(Mandatory = $false, HelpMessage = 'Root workspace directory containing repository manifests')]
    [string]$RootPath = 'D:\Git_Repositories',

    [Parameter(Mandatory = $false, HelpMessage = 'Normalize all LCM-owned semantic versions to TargetBaseline and metadata dates to the release date.')]
    [switch]$FullBaseline,

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
    Write-Host "  pwsh LCM_Inventory/tools/Sync-LcmModuleVersions.ps1 [-TargetMajor <int>] [-TargetBaseline <str>] [-FullBaseline] [-Apply] [-AuditOnly] [-RootPath <str>] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -TargetMajor      : Target major release number (default: 10)"
    Write-Host "  -TargetBaseline   : Target baseline version string (default: 10.0.0)"
    Write-Host "  -FullBaseline     : Normalize LCM-owned semantic versions to TargetBaseline exactly."
    Write-Host "  -Apply            : Apply live version mutations"
    Write-Host "  -AuditOnly        : Perform read-only audit (default)"
    Write-Host "  -RootPath         : Root workspace directory"
    Write-Host "  -Help (-h, -?)    : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM MODULE & DOCUMENTATION VERSION SYNCHRONIZATION (10.0.0)" -ForegroundColor Cyan
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

function Get-LcmReleaseTextFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot
    )

    $extensions = @(
        '.md', '.ps1', '.psm1', '.psd1', '.json', '.jsonc', '.yml', '.yaml',
        '.xml', '.html', '.js', '.ts', '.py', '.csproj', '.props', '.targets'
    )
    $componentDirectories = @(
        'LCM_AI', 'LCM_Backup', 'LCM_Inventory', 'LCM_Shared', 'LCM_Supervision', 'LCM_Tools'
    )
    $excludedDirectoryNames = @('.git', 'logs', 'scratch', 'node_modules', 'bin', 'obj')
    $excludedRelativePrefixes = @(
        'data\analysis\history\', 'data\baselines\', 'data\gemini_baseline\',
        'data\logs\', 'data\reviews\', 'data\session_state\'
    )
    $files = [System.Collections.Generic.List[string]]::new()

    foreach ($component in $componentDirectories) {
        $componentPath = Join-Path $WorkspaceRoot $component
        if (-not (Test-Path -LiteralPath $componentPath -PathType Container)) {
            continue
        }

        $directories = [System.Collections.Generic.Stack[string]]::new()
        $directories.Push($componentPath)
        while ($directories.Count -gt 0) {
            $directory = $directories.Pop()
            foreach ($entry in [System.IO.Directory]::EnumerateFileSystemEntries($directory)) {
                $attributes = [System.IO.File]::GetAttributes($entry)
                if (($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    continue
                }

                if (($attributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
                    if ([System.IO.Path]::GetFileName($entry) -notin $excludedDirectoryNames) {
                        $directories.Push($entry)
                    }
                    continue
                }

                $relativePath = $entry.Substring($componentPath.Length).TrimStart('\')
                if ($excludedRelativePrefixes.Where({ $relativePath.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) {
                    continue
                }

                if ([System.IO.Path]::GetExtension($entry).ToLowerInvariant() -in $extensions) {
                    $files.Add($entry)
                }
            }
        }
    }

    return @($files | Sort-Object -Unique)
}

function ConvertTo-LcmReleaseBaseline {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Baseline,

        [Parameter(Mandatory = $true)]
        [string]$ReleaseDate,

        [Parameter(Mandatory = $true)]
        [bool]$PreserveChangeHistory
    )

    $releaseLines = [System.Collections.Generic.List[string]]::new()
    $inChangeHistory = $false
    foreach ($line in ($Content -split "`r?`n", 0, 'RegexMatch')) {
        if ($PreserveChangeHistory -and $line -match '^\s*(?:#\s*)?(?:Change\s*History|Change\s*Log|Changelog|Release\s*History|Version\s*History)\s*:?\s*$') {
            $inChangeHistory = $true
            $releaseLines.Add($line)
            continue
        }

        if ($inChangeHistory -and $line -match '^\s*(?:#\s*)?[-*]\s+\d{4}-\d{2}-\d{2}\b') {
            $releaseLines.Add($line)
            continue
        }

        if ($inChangeHistory) {
            $inChangeHistory = $false
        }

        $normalizedLine = [regex]::Replace($line, '(?<![\d.])v?\d+\.\d+\.\d+(?![\d.])', $Baseline)
        $normalizedLine = [regex]::Replace($normalizedLine, '\b20\d{2}-\d{2}-\d{2}\b', $ReleaseDate)
        $isReleaseMetadata = $line -match '(?i)^\s*(?:#\s*)?(?:LCM\s+)?(?:Release\s+)?(?:Version|Date|Last Updated|Modified Date)\s*[:=]'
        if ($normalizedLine -ne $line -or $isReleaseMetadata) {
            $normalizedLine = $normalizedLine.TrimEnd()
        }
        $releaseLines.Add($normalizedLine)
    }

    return ($releaseLines -join "`r`n")
}

function Invoke-LcmFullBaselineSynchronization {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,

        [Parameter(Mandatory = $true)]
        [string]$Baseline,

        [Parameter(Mandatory = $true)]
        [bool]$WriteChanges
    )

    $releaseDate = (Get-Date).ToString('yyyy-MM-dd')
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($file in (Get-LcmReleaseTextFiles -WorkspaceRoot $WorkspaceRoot)) {
        $content = [System.IO.File]::ReadAllText($file)
        if ($content.IndexOf([char]0) -ge 0) {
            continue
        }

        $preserveChangeHistory = $file -match '\\modules\\'
        $normalizedContent = ConvertTo-LcmReleaseBaseline -Content $content -Baseline $Baseline -ReleaseDate $releaseDate -PreserveChangeHistory $preserveChangeHistory
        if ($normalizedContent -eq $content) {
            continue
        }

        $relativePath = $file.Substring($WorkspaceRoot.Length).TrimStart('\')
        $results.Add([PSCustomObject]@{
                File = $relativePath
                Action = if ($WriteChanges) { 'UPDATED' } else { 'NEEDS_UPDATE' }
            })
        if ($WriteChanges) {
            [System.IO.File]::WriteAllText($file, $normalizedContent, $utf8WithoutBom)
        }
    }

    $resultList = @($results)
    $actionSummary = if ($WriteChanges) { 'updated' } else { 'requiring update' }
    Write-Host "`n Full baseline release synchronization: $($resultList.Count) file(s) $actionSummary." -ForegroundColor Cyan
    if ($resultList.Count -gt 0) {
        $resultList | Format-Table -AutoSize -Property File, Action
    }
}

if ($FullBaseline) {
    if ($TargetBaseline -ne '10.0.0') {
        throw 'FullBaseline requires TargetBaseline 10.0.0 for the approved LCM Beta 10 release.'
    }
    Invoke-LcmFullBaselineSynchronization -WorkspaceRoot $RootPath -Baseline $TargetBaseline -WriteChanges ($Apply -and -not $AuditOnly)
    return
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
