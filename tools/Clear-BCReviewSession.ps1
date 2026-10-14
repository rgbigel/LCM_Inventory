<#
.SYNOPSIS
    Clears the dynamic Beyond Compare review session and review artifacts for a committed CRP or BUG.
.DESCRIPTION
    Module: tools/Clear-BCReviewSession.ps1
    Purpose: Dedicated tool invoked post-commit to purge dynamic Beyond Compare named sessions and
             scratchpad artifacts associated with a specific CRP or BUG per CRP-203.
    Authors: Rolf, LCM_AI Engine
    Version: 10.0.0
    Date: 2026-10-13
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Target CRP or BUG identifier (e.g. CRP-203, BUG-245)')]
    [string]$CRP,

    [Parameter(Mandatory = $false, HelpMessage = 'Target repository name')]
    [string]$RepositoryName = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Exact isolated review identity (for example BUG-276_LCM_AI); defaults to CRP')]
    [ValidatePattern('^[A-Za-z0-9_.-]+$')]
    [string]$ReviewIdentity = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Workspace root path')]
    [string]$WorkspaceRoot = 'D:\Git_Repositories',

    [Parameter(Mandatory = $false, HelpMessage = 'Preview cleanup operations without deleting')]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = 'Force cleanup only after Beyond Compare is closed')]
    [switch]$Force,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " CLEAR BEYOND COMPARE REVIEW SESSION (Clear-BCReviewSession)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Clears the dynamic BCompare session and scratchpad review cache for a committed CRP or BUG."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Clear-BCReviewSession.ps1 -CRP <string> [-RepositoryName <string>] [-DryRun] [-Force] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -CRP            : Target CRP or BUG identifier (e.g. CRP-203, BUG-245)"
    Write-Host "  -RepositoryName : Target repository name"
    Write-Host "  -DryRun         : Preview cleanup operations without deleting"
    Write-Host "  -Force          : Request cleanup after Beyond Compare is closed"
    Write-Host "  -Help (-h, -?)  : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

# ------------------------------------------------------------------------------
# 1. Parameter Validation
# ------------------------------------------------------------------------------
$cleanCRP = $CRP.Trim().ToUpperInvariant()
if ($cleanCRP -notmatch '^(CRP|BUG)-\d+') {
    throw "Invalid proposal identifier '$CRP'. Expected format: CRP-### or BUG-###."
}
$cleanupIdentity = if ([string]::IsNullOrWhiteSpace($ReviewIdentity)) { $cleanCRP } else { $ReviewIdentity.Trim() }
$sessionName = "${cleanupIdentity}_Review"

if (-not (Test-Path -LiteralPath $WorkspaceRoot)) {
    $WorkspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$sessionsRemoved = [System.Collections.Generic.List[string]]::new()
$foldersPurged = [System.Collections.Generic.List[string]]::new()
$bcRunning = @(Get-CimInstance Win32_Process -Filter "Name = 'BCompare.exe'" -ErrorAction SilentlyContinue).Count -gt 0

if ($bcRunning) {
    Write-Verbose "Beyond Compare is active. Preserving exact review identity '$cleanupIdentity' and its session bridge."
}

# ------------------------------------------------------------------------------
# 2. Beyond Compare BCSessions.xml Cleanup
# ------------------------------------------------------------------------------
$bcSessionsPath = Join-Path $env:APPDATA 'Scooter Software\Beyond Compare 5\BCSessions.xml'
if (-not $bcRunning) {
if (Test-Path -LiteralPath $bcSessionsPath) {
    try {
        $xml = [xml](Get-Content -LiteralPath $bcSessionsPath -Raw -Encoding UTF8)
        $rootNode = $xml.SelectSingleNode('/BCSessions')
        if ($rootNode) {
            $matchingNodes = @($rootNode.SelectNodes("TDirCompareSession[@Value='$sessionName']"))
            foreach ($node in $matchingNodes) {
                $sessionVal = $node.GetAttribute('Value')
                $sessionsRemoved.Add($sessionVal)
                if (-not $DryRun) {
                    if ($PSCmdlet.ShouldProcess("BCSessions.xml", "Remove session node '$sessionVal'")) {
                        [void]$rootNode.RemoveChild($node)
                    }
                }
            }
            if (-not $DryRun -and $matchingNodes.Count -gt 0) {
                $xml.Save($bcSessionsPath)
                Write-Verbose "Updated ${bcSessionsPath}: removed $($matchingNodes.Count) session(s)."
            }
        }
    } catch {
        Write-Warning "Could not update BCSessions.xml: $($_.Exception.Message)"
    }
}
}

# ------------------------------------------------------------------------------
# 3. Scratchpad Review Cache Cleanup
# ------------------------------------------------------------------------------
$scratchBcReviewDir = Join-Path $WorkspaceRoot 'LCM_Inventory\scratch\BC_Review'
if (Test-Path -LiteralPath $scratchBcReviewDir) {
    $candidates = @(Get-ChildItem -LiteralPath $scratchBcReviewDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $cleanupIdentity })

    if ($bcRunning) {
        Write-Verbose "Beyond Compare is actively running. Preserving scratchpad folders and named session to avoid fast-refresh errors."
    } else {
        foreach ($candidate in $candidates) {
            $foldersPurged.Add($candidate.FullName)
            if (-not $DryRun) {
                if ($PSCmdlet.ShouldProcess($candidate.FullName, "Purge BCR scratch review directory")) {
                    # Safely unlink all NTFS directory junctions first
                    $junctions = @(Get-ChildItem -LiteralPath $candidate.FullName -Directory -Force -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.LinkType -eq 'Junction' })
                    foreach ($jn in $junctions) {
                        try { [System.IO.Directory]::Delete($jn.FullName, $false) } catch {}
                    }
                    Remove-Item -LiteralPath $candidate.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

# ------------------------------------------------------------------------------
# 4. Result Structure
# ------------------------------------------------------------------------------
$result = [PSCustomObject]@{
    CRP             = $cleanCRP
    ReviewIdentity  = $cleanupIdentity
    RepositoryName  = $RepositoryName
    SessionsRemoved = @($sessionsRemoved)
    FoldersPurged   = @($foldersPurged)
    DryRun          = [bool]$DryRun
    Success         = $true
}

if ($DryRun) {
    Write-Host "[DRY RUN] Clear-BCReviewSession for ${cleanCRP}:" -ForegroundColor Cyan
    Write-Host ("  Sessions that would be removed: {0}" -f ($sessionsRemoved -join ', ')) -ForegroundColor DarkGray
    Write-Host ("  Folders that would be purged:   {0}" -f ($foldersPurged -join ', ')) -ForegroundColor DarkGray
}

return $result
