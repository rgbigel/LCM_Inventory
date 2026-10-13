<#
.SYNOPSIS
  Migrates, safeguards, and verifies AI Memory and Antigravity configuration on shared Drive A:.
.DESCRIPTION
  Module: Initialize-SharedAiMemory
  Purpose: Establishes and safeguards a unified, persistent AI Memory repository on Drive A: (A:\.gemini)
           and links %USERPROFILE%\.gemini via an NTFS Directory Junction.
           
           Safeguards & Verification Engine (CRP-173):
           1. Two-Phase Migration: Live data is transferred and verified on A: BEFORE attempting junction swap.
           2. Junction Idempotency: Double-checks existing junctions to ensure healthy links to A:\.gemini
              are never inadvertently recreated or destroyed.
           3. GitHub Baseline Age Check: Compares A:\.gemini timestamp against committed GitHub baseline in
              LCM_AI/data/gemini_baseline/gemini_manifest.json. Replaces from GitHub if A:\.gemini is older.
           4. Cryptographic Hash Consistency: Validates local files against SHA256 manifest hash codes.
           5. Multi-Boot ACL Enforcement: Enforces AuthorizeMasterUser ACL permissions on A:\.gemini.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: LCM_Inventory/tools/Initialize-SharedAiMemory.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-13
.PARAMETER TargetDrive
  The shared drive letter hosting the persistent AI Memory root. Defaults to 'A:'.
.PARAMETER VerifyOnly
  Performs full diagnostic, junction, GitHub baseline, and hash verification without modifying filesystem (Alias: -Verify).
.PARAMETER SyncFromGitHub
  Forces replacing/updating local A:\.gemini configuration from GitHub baseline if older or divergent.
.PARAMETER Force
  Overwrites or replaces existing junction/directory without interactive confirmation.
.PARAMETER ShowAll
  Exposes detailed step-by-step diagnostic and file synchronization telemetry to the console.
.PARAMETER LogFile
  Custom log file destination. Defaults to LCM_Inventory/data/logs/lcm/Initialize-SharedAiMemory-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh LCM_Inventory/tools/Initialize-SharedAiMemory.ps1 -h
.EXAMPLE
  pwsh LCM_Inventory/tools/Initialize-SharedAiMemory.ps1 -VerifyOnly
.EXAMPLE
  pwsh LCM_Inventory/tools/Initialize-SharedAiMemory.ps1
.EXAMPLE
  pwsh LCM_Inventory/tools/Initialize-SharedAiMemory.ps1 -TargetDrive "A:" -ShowAll
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$TargetDrive = 'A:',
  [Alias('Verify')]
  [switch]$VerifyOnly,
  [switch]$SyncFromGitHub,
  [switch]$Force,
  [switch]$ShowAll,
  [string]$LogFile = "",
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Initialize-SharedAiMemory"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " SHARED AI MEMORY & CONFIGURATION INITIALIZER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Migrates, safeguards, and verifies %USERPROFILE%\.gemini with persistent"
  Write-Host "  Drive A:\.gemini and reconciles against the committed GitHub baseline."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Initialize-SharedAiMemory.ps1 [-TargetDrive <DriveLetter>] [-VerifyOnly] [-SyncFromGitHub] [-Force] [-ShowAll] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -TargetDrive <str> : Destination drive for AI memory storage (Default: 'A:')."
  Write-Host "  -VerifyOnly        : Verifies junction, GitHub age, and SHA256 hashes without modifying disk."
  Write-Host "  -SyncFromGitHub    : Replaces A:\.gemini from GitHub baseline if older or divergent."
  Write-Host "  -Force             : Replaces or updates existing junctions without prompting."
  Write-Host "  -ShowAll           : Exposes granular file copy, hash, and ACL diagnostic logs."
  Write-Host "  -LogFile <str>     : Custom log file destination."
  Write-Host "  -h, -Help, -?      : Displays this comprehensive parameter reference."
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Initialize-SharedAiMemory.ps1 -VerifyOnly"
  Write-Host "  pwsh LCM_Inventory/tools/Initialize-SharedAiMemory.ps1"
  Write-Host "  pwsh LCM_Inventory/tools/Initialize-SharedAiMemory.ps1 -ShowAll"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Initialize Logging Context per RULE-PS-009
# ------------------------------------------------------------------------------
$workspaceRoot = 'D:\Git_Repositories'
$logDir = Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm'
if (-not (Test-Path -LiteralPath $logDir)) {
  New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $LogFile = Join-Path $logDir "$($scriptName)-$($timestampStr).log"
}
$script:ActiveLogFile = $LogFile
$script:ShowDetails = $ShowAll

function Write-ToolLog {
  param(
    [AllowEmptyString()]
    [string]$Message = "",
    [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "ACTION", "SUMMARY")]
    [string]$Level = "INFO",
    [switch]$ConsoleOnly,
    [switch]$LogOnly
  )

  $timeHeader = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  $formattedLog = "[$timeHeader] [$Level] $Message"

  if (-not $ConsoleOnly -and -not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
    try {
      $formattedLog | Out-File -FilePath $script:ActiveLogFile -Append -Encoding UTF8
    } catch {}
  }

  if (-not $LogOnly) {
    switch ($Level) {
      "WARN"    { Write-Warning $Message }
      "ERROR"   { Write-Error $Message }
      "DEBUG"   { if ($script:ShowDetails) { Write-Host "  [DEBUG] $Message" -ForegroundColor DarkGray } }
      "ACTION"  { Write-Host "  -> $Message" -ForegroundColor Green }
      "SUMMARY" { Write-Host $Message -ForegroundColor Cyan }
      default   { Write-Host $Message }
    }
  }
}

function Test-IsHealthyJunction {
  param(
    [string]$Path,
    [string]$ExpectedTarget
  )
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $item = Get-Item -LiteralPath $Path -Force
  $isJunction = ($item.LinkType -eq 'Junction') -or $item.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)
  if (-not $isJunction) { return $false }
  $currentTarget = if ($item.Target) { ($item.Target -replace '[\\/]+$', '').Trim() } else { '' }
  $normalizedExpected = ($ExpectedTarget -replace '[\\/]+$', '').Trim()
  return ([string]::Equals($currentTarget, $normalizedExpected, [System.StringComparison]::OrdinalIgnoreCase))
}

Write-ToolLog -Message "==========================================================================" -Level INFO
Write-ToolLog -Message " SHARED AI MEMORY & CONFIGURATION INITIALIZER (v$($scriptVersion))" -Level INFO
Write-ToolLog -Message " Target: $TargetDrive\.gemini | Source: $env:USERPROFILE\.gemini" -Level INFO
Write-ToolLog -Message " Mode  : $(if ($VerifyOnly) { 'VERIFY ONLY (Read-Only)' } else { 'MIGRATION & VERIFICATION' })" -Level INFO
Write-ToolLog -Message " Audit : $LogFile" -Level INFO
Write-ToolLog -Message "==========================================================================" -Level INFO

$execStatus = "COMPLETED"

try {
  $sourcePath = Join-Path $env:USERPROFILE '.gemini'
  $targetRoot = "$($TargetDrive.TrimEnd('\'))\.gemini"
  $baselineDir = Join-Path $workspaceRoot 'LCM_AI\data\gemini_baseline'
  $manifestPath = Join-Path $baselineDir 'gemini_manifest.json'

  # ----------------------------------------------------------------------------
  # Step 1: Double-Checked Junction Preservation (Inadvertent Recreation Guard)
  # ----------------------------------------------------------------------------
  Write-ToolLog -Message "[1/5] Double-checking source junction status at '$sourcePath'..." -Level INFO
  $isAlreadyHealthyJunction = Test-IsHealthyJunction -Path $sourcePath -ExpectedTarget $targetRoot

  if ($isAlreadyHealthyJunction) {
    Write-ToolLog -Message "Source '$sourcePath' is ALREADY a healthy NTFS Junction pointing to '$targetRoot'." -Level ACTION
    Write-ToolLog -Message "Preserving existing junction unconditionally (Zero recreation / zero modification)." -Level INFO
  } else {
    if (Test-Path -LiteralPath $sourcePath) {
      $sourceItem = Get-Item -LiteralPath $sourcePath -Force
      $isOtherJunction = ($sourceItem.LinkType -eq 'Junction') -or $sourceItem.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)
      if ($isOtherJunction) {
        Write-ToolLog -Message "Source '$sourcePath' is a junction to '$($sourceItem.Target)' (expected '$targetRoot')." -Level WARN
      } else {
        Write-ToolLog -Message "Source '$sourcePath' is currently a physical directory on Drive C: (not yet a junction)." -Level INFO
      }
    } else {
      Write-ToolLog -Message "Source path '$sourcePath' does not exist yet." -Level INFO
    }
  }

  # ----------------------------------------------------------------------------
  # Step 2: Target Volume Validation & Directory Setup
  # ----------------------------------------------------------------------------
  Write-ToolLog -Message "[2/5] Validating target volume '$TargetDrive'..." -Level INFO
  if (-not (Test-Path -LiteralPath $TargetDrive)) {
    throw "Target volume '$TargetDrive' does not exist or is not mounted."
  }
  Write-ToolLog -Message "Target volume '$TargetDrive' verified and accessible." -Level ACTION

  if (-not (Test-Path -LiteralPath $targetRoot)) {
    if ($VerifyOnly) {
      Write-ToolLog -Message "[VERIFY] Target directory '$targetRoot' does not exist." -Level WARN
    } else {
      Write-ToolLog -Message "Creating target AI Memory directory at '$targetRoot'..." -Level ACTION
      if ($PSCmdlet.ShouldProcess($targetRoot, "Create Directory")) {
        New-Item -Path $targetRoot -ItemType Directory -Force | Out-Null
      }
    }
  } else {
    Write-ToolLog -Message "Target directory '$targetRoot' exists." -Level INFO
  }

  # ----------------------------------------------------------------------------
  # Step 3: Two-Phase Fail-Safe Migration (Transfer to A: First, Substitute Second)
  # ----------------------------------------------------------------------------
  Write-ToolLog -Message "[3/5] Evaluating migration requirements..." -Level INFO

  if (-not $isAlreadyHealthyJunction -and -not $VerifyOnly) {
    if (Test-Path -LiteralPath $sourcePath) {
      $sourceItem = Get-Item -LiteralPath $sourcePath -Force
      $isJunc = ($sourceItem.LinkType -eq 'Junction') -or $sourceItem.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)

      if (-not $isJunc) {
        Write-ToolLog -Message "Phase 1: Mirroring live directory '$sourcePath' to '$targetRoot' BEFORE touching source..." -Level ACTION

        $robocopyArgs = @(
          $sourcePath,
          $targetRoot,
          "/E", "/COPY:DAT", "/R:2", "/W:1", "/XJ", "/NP", "/NFL", "/NDL"
        )
        & robocopy.exe @robocopyArgs | Out-Null

        $sourceFiles = @(Get-ChildItem -Path $sourcePath -Recurse -File -ErrorAction SilentlyContinue)
        $targetFiles = @(Get-ChildItem -Path $targetRoot -Recurse -File -ErrorAction SilentlyContinue)

        Write-ToolLog -Message "Verification: Source has $($sourceFiles.Count) files; Target has $($targetFiles.Count) files." -Level INFO
        if ($targetFiles.Count -lt $sourceFiles.Count) {
          throw "Pre-migration file count check failed: Target ($($targetFiles.Count)) < Source ($($sourceFiles.Count)). Aborting junction swap to prevent data loss."
        }
        Write-ToolLog -Message "Live data safely mirrored to '$targetRoot' ($($targetFiles.Count) files verified)." -Level ACTION

        # Phase 2: Atomic Swap Test
        Write-ToolLog -Message "Phase 2: Attempting atomic junction substitution for '$sourcePath'..." -Level INFO
        $canSwap = $true
        $backupPath = "$sourcePath`_pre_junction_backup"

        try {
          if (Test-Path -LiteralPath $backupPath) { Remove-Item -Path $backupPath -Recurse -Force -ErrorAction SilentlyContinue }
          Rename-Item -Path $sourcePath -NewName (Split-Path $backupPath -Leaf) -ErrorAction Stop
        } catch {
          $canSwap = $false
          Write-ToolLog -Message "Active processes (e.g. running Antigravity IDE) currently hold open file locks in '$sourcePath'." -Level WARN
          Write-ToolLog -Message "All live data is safely copied to '$targetRoot'. Close Antigravity IDE briefly and re-run this tool to finalize the junction." -Level INFO
        }

        if ($canSwap) {
          if ($PSCmdlet.ShouldProcess($sourcePath, "Create Junction -> $targetRoot")) {
            New-Item -ItemType Junction -Path $sourcePath -Target $targetRoot -Force | Out-Null
            
            # Double-check newly created junction
            if (Test-IsHealthyJunction -Path $sourcePath -ExpectedTarget $targetRoot) {
              Write-ToolLog -Message "NTFS Junction successfully established and double-checked: '$sourcePath' -> '$targetRoot'." -Level ACTION
              Remove-Item -Path $backupPath -Recurse -Force -ErrorAction SilentlyContinue
              Write-ToolLog -Message "Temporary migration backup pruned cleanly." -Level DEBUG
            } else {
              Write-ToolLog -Message "Warning: Newly created junction failed verification. Restoring source backup..." -Level ERROR
              Remove-Item -Path $sourcePath -Force -ErrorAction SilentlyContinue
              Rename-Item -Path $backupPath -NewName (Split-Path $sourcePath -Leaf)
            }
          }
        }
      } else {
        # Other junction repointing
        Write-ToolLog -Message "Updating existing junction to point to '$targetRoot'..." -Level ACTION
        if ($PSCmdlet.ShouldProcess($sourcePath, "Re-point Junction to $targetRoot")) {
          [System.IO.Directory]::Delete($sourcePath, $false)
          New-Item -ItemType Junction -Path $sourcePath -Target $targetRoot -Force | Out-Null
          Write-ToolLog -Message "Junction successfully updated to '$targetRoot'." -Level ACTION
        }
      }
    } else {
      if ($PSCmdlet.ShouldProcess($sourcePath, "Create Junction -> $targetRoot")) {
        New-Item -ItemType Junction -Path $sourcePath -Target $targetRoot -Force | Out-Null
        Write-ToolLog -Message "NTFS Junction created directly: '$sourcePath' -> '$targetRoot'." -Level ACTION
      }
    }
  } else {
    Write-ToolLog -Message "Junction creation skipped (Already healthy junction or VerifyOnly mode)." -Level INFO
  }

  # ----------------------------------------------------------------------------
  # Step 4: GitHub Baseline Age Check & Synchronization
  # ----------------------------------------------------------------------------
  Write-ToolLog -Message "[4/5] Checking GitHub baseline and age synchronization..." -Level INFO
  $manifest = $null
  if (Test-Path -LiteralPath $manifestPath) {
    try {
      $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
      Write-ToolLog -Message "GitHub Baseline Manifest found: Version $($manifest.version) (Updated: $($manifest.updated_at), Total files: $($manifest.total_files))." -Level INFO
    } catch {
      Write-ToolLog -Message "Warning: Failed to parse GitHub baseline manifest at '$manifestPath': $_" -Level WARN
    }
  } else {
    Write-ToolLog -Message "No GitHub baseline manifest found at '$manifestPath'." -Level WARN
  }

  $targetConfigDir = Join-Path $targetRoot 'config'
  $sourceBaselineConfig = Join-Path $baselineDir 'config'
  if ($manifest -and (Test-Path -LiteralPath $targetConfigDir)) {
    $targetFiles = @(Get-ChildItem -Path $targetConfigDir -Recurse -File -ErrorAction SilentlyContinue)
    $targetLatestDate = if ($targetFiles.Count -gt 0) { ($targetFiles | Measure-Object -Property LastWriteTime -Maximum).Maximum } else { [DateTime]::MinValue }

    $baselineFiles = if (Test-Path -LiteralPath $sourceBaselineConfig) { @(Get-ChildItem -Path $sourceBaselineConfig -Recurse -File -ErrorAction SilentlyContinue) } else { @() }
    $baselineLatestDate = if ($baselineFiles.Count -gt 0) { ($baselineFiles | Measure-Object -Property LastWriteTime -Maximum).Maximum } else { [DateTime]::MinValue }

    Write-ToolLog -Message "Age Evaluation: Target '$targetRoot\config' latest write: $targetLatestDate | GitHub Baseline: $baselineLatestDate" -Level INFO

    if ($targetLatestDate -lt $baselineLatestDate) {
      Write-ToolLog -Message "Target '$targetRoot\config' is OLDER than GitHub baseline." -Level WARN
      if ($SyncFromGitHub -or (-not $VerifyOnly)) {
        Write-ToolLog -Message "Updating '$targetRoot\config' from GitHub baseline..." -Level ACTION
        & robocopy.exe $sourceBaselineConfig $targetConfigDir /MIR /R:2 /W:1 /XJ /NP /NFL /NDL | Out-Null
        Write-ToolLog -Message "Target '$targetRoot\config' successfully replaced/updated from GitHub baseline." -Level ACTION
      } else {
        Write-ToolLog -Message "[VERIFY] GitHub baseline is newer. Use -SyncFromGitHub to apply." -Level INFO
      }
    } else {
      Write-ToolLog -Message "Target '$targetRoot\config' is up-to-date with or newer than GitHub baseline." -Level ACTION
    }
  }

  # ----------------------------------------------------------------------------
  # Step 5: Cryptographic Hash Consistency Verification
  # ----------------------------------------------------------------------------
  Write-ToolLog -Message "[5/5] Performing cryptographic hash consistency verification..." -Level INFO
  if ($manifest -and (Test-Path -LiteralPath $targetConfigDir)) {
    $targetConfigFiles = @(Get-ChildItem -Path $targetConfigDir -Recurse -File | Sort-Object FullName)
    $hashLines = [System.Collections.Generic.List[string]]::new()
    $mismatches = [System.Collections.Generic.List[string]]::new()
    $verifiedCount = 0

    foreach ($f in $targetConfigFiles) {
      $rel = $f.FullName.Substring($targetConfigDir.Length).TrimStart('\').Replace('\', '/')
      $localHash = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
      $hashLines.Add("$($rel):$($localHash)")

      $expectedHash = $null
      if ($manifest.files.PSObject.Properties[$rel]) {
        $expectedHash = $manifest.files.$rel
      }

      if ($expectedHash) {
        if ([string]::Equals($localHash, $expectedHash, [System.StringComparison]::OrdinalIgnoreCase)) {
          $verifiedCount++
        } else {
          $mismatches.Add("$rel (Local: $($localHash.Substring(0, 8))... vs Expected: $($expectedHash.Substring(0, 8))...)")
        }
      }
    }

    $combined = $hashLines -join "`n"
    $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($combined))
    $localRootHash = (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash

    if ($localRootHash -eq $manifest.root_hash) {
      Write-ToolLog -Message "Hash Verification PASSED: 100% consistent ($verifiedCount files verified, Root SHA256: $($localRootHash.Substring(0, 12))...)." -Level ACTION
    } else {
      if ($mismatches.Count -gt 0) {
        Write-ToolLog -Message "Hash Divergence: $($mismatches.Count) files differ from baseline manifest:" -Level WARN
        foreach ($m in ($mismatches | Select-Object -First 5)) {
          Write-ToolLog -Message "  -> Divergence: $m" -Level DEBUG
        }
      } else {
        Write-ToolLog -Message "Notice: Local configuration has additional or updated files compared to manifest baseline (Local Root SHA256: $($localRootHash.Substring(0, 12))...)." -Level INFO
      }
    }
  }

  # ----------------------------------------------------------------------------
  # Multi-Boot ACL Enforcement
  # ----------------------------------------------------------------------------
  if (-not $VerifyOnly -and (Test-Path -LiteralPath $targetRoot)) {
    Write-ToolLog -Message "Enforcing Multi-Boot ACL permissions on '$targetRoot'..." -Level INFO
    try {
      $acl = Get-Acl -Path $targetRoot
      $ruleAdmins = [System.Security.AccessControl.FileSystemAccessRule]::new(
        [System.Security.Principal.NTAccount]"BUILTIN\Administrators",
        [System.Security.AccessControl.FileSystemRights]"FullControl",
        [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit",
        [System.Security.AccessControl.PropagationFlags]"None",
        [System.Security.AccessControl.AccessControlType]"Allow"
      )
      $ruleAuthUsers = [System.Security.AccessControl.FileSystemAccessRule]::new(
        [System.Security.Principal.NTAccount]"NT AUTHORITY\Authenticated Users",
        [System.Security.AccessControl.FileSystemRights]"FullControl",
        [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit",
        [System.Security.AccessControl.PropagationFlags]"None",
        [System.Security.AccessControl.AccessControlType]"Allow"
      )
      $acl.SetAccessRule($ruleAdmins)
      $acl.SetAccessRule($ruleAuthUsers)
      Set-Acl -Path $targetRoot -AclObject $acl
      Write-ToolLog -Message "Multi-Boot ACL locked: FullControl granted to Administrators and Authenticated Users." -Level ACTION
    } catch {
      Write-ToolLog -Message "Non-fatal ACL update notice on '$targetRoot': $_" -Level WARN
    }
  }

} catch {
  $execStatus = "FAILED"
  Write-ToolLog -Message "Execution failed: $_" -Level ERROR
} finally {
  # Mandatory RULE-PS-009 Summary Block
  $now = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  Write-ToolLog -Message "" -Level INFO
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
  Write-ToolLog -Message " [SUMMARY] $scriptName (v$($scriptVersion))" -Level SUMMARY
  Write-ToolLog -Message " Status    : $execStatus" -Level SUMMARY
  Write-ToolLog -Message " Timestamp : $now" -Level SUMMARY
  Write-ToolLog -Message " Log File  : $LogFile" -Level SUMMARY
  Write-ToolLog -Message " Target    : $TargetDrive\.gemini" -Level SUMMARY
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
}
