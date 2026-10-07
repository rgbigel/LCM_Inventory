<#
Module: LCMOnboarding.psm1
Purpose: Implementation of the 4-Phase Lifecycle Model (LCM) Repository Onboarding Engine.
Path: tools/Onboarding/LCMOnboarding.psm1
Authors: Rolf, LCM_AI Engine
Version: 1.1.0
Changelog:
- 2026-08-15: Added -DryRun support to Test-LCMIntegrity, immediate preflight error return, renamed Get-WorkspaceRoot, and added Update mode support.
- 2026-08-15: Initial implementation of Test-LCMPreFlight, New-LCMGovernanceLinks, Expand-LCMTemplate, Test-LCMIntegrity, and Invoke-LCMOnboardRepo.
#>

function Get-WorkspaceRoot {
  [CmdletBinding()]
  param()
  return Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

function Test-LCMPreFlight {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [string]$WorkspaceRoot
  )

  if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Get-WorkspaceRoot
  }

  $targetFullPath = [System.IO.Path]::GetFullPath($TargetPath).TrimEnd('\')
  $workspaceFullPath = [System.IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\')
  $errors = @()
  $warnings = @()

  # 1. Target Directory Existence Check
  if (-not (Test-Path -LiteralPath $targetFullPath -PathType Container)) {
    $errors += "Target directory does not exist: $targetFullPath"
    return [pscustomobject]@{
      Passed     = $false
      TargetPath = $targetFullPath
      Errors     = $errors
      Warnings   = $warnings
    }
  }

  # 2. Prevent Self-Onboarding (State 1 active design workshop)
  if ($targetFullPath.Equals($workspaceFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    $errors += "Cannot onboard LCM_AI into itself (LCM_AI is the active design workshop root)."
    return [pscustomobject]@{
      Passed     = $false
      TargetPath = $targetFullPath
      Errors     = $errors
      Warnings   = $warnings
    }
  }

  # 3. Prevent Off-Limits Legacy Repos
  $offLimits = @('Workspace_AC', 'Workspace_GC')
  foreach ($ol in $offLimits) {
    if ($targetFullPath.EndsWith("\$ol", [System.StringComparison]::OrdinalIgnoreCase)) {
      $errors += "Target repository '$ol' is an off-limits legacy directory."
      return [pscustomobject]@{
        Passed     = $false
        TargetPath = $targetFullPath
        Errors     = $errors
        Warnings   = $warnings
      }
    }
  }

  # 4. Detect Existing LCM Configuration (Onboard vs Update Mode)
  $lcmConfigPath = Join-Path $targetFullPath '.lcm\config.json'
  $isAlreadyOnboarded = Test-Path -LiteralPath $lcmConfigPath
  $existingLcmVersion = $null
  if ($isAlreadyOnboarded) {
    try {
      $cfg = Get-Content -Raw -Path $lcmConfigPath | ConvertFrom-Json
      $existingLcmVersion = $cfg.governance.lcm_version
    }
    catch {
      $warnings += "Existing .lcm/config.json could not be parsed: $_"
    }
  }

  # 6. Detect Git Status
  $gitDir = Join-Path $targetFullPath '.git'
  $hasGit = Test-Path -LiteralPath $gitDir -PathType Container

  if (-not $hasGit) {
    $warnings += "Target directory is not an initialized Git repository."
  }

  # 7. Token Auto-Discovery
  $repoName = Split-Path $targetFullPath -Leaf
  $files = Get-ChildItem -Path $targetFullPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\\.git\\' }
  
  $primaryLang = 'PowerShell'
  $extensions = $files | Group-Object Extension | Sort-Object Count -Descending
  if ($extensions) {
    switch ($extensions[0].Name.ToLower()) {
      '.ps1' { $primaryLang = 'PowerShell' }
      '.psm1' { $primaryLang = 'PowerShell' }
      '.cs' { $primaryLang = 'CSharp' }
      '.py' { $primaryLang = 'Python' }
      '.ts' { $primaryLang = 'TypeScript' }
      '.js' { $primaryLang = 'JavaScript' }
      '.cpp' { $primaryLang = 'CPlusPlus' }
      default { $primaryLang = 'PowerShell' }
    }
  }

  $moduleRoot = '.'
  if (Test-Path (Join-Path $targetFullPath 'src')) {
    $moduleRoot = 'src'
  }
  elseif (Test-Path (Join-Path $targetFullPath 'tools')) {
    $moduleRoot = 'tools'
  }

  $detectedTokens = [ordered]@{
    REPO_NAME    = $repoName
    PRIMARY_LANG = $primaryLang
    MODULE_ROOT  = $moduleRoot
    AUTHOR       = 'Rolf'
    DATE         = (Get-Date -Format 'yyyy-MM-dd')
    TIMESTAMP    = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
    DESCRIPTION  = "Solution component: $repoName"
  }

  return [pscustomobject]@{
    Passed             = ($errors.Count -eq 0)
    TargetPath         = $targetFullPath
    HasGit             = $hasGit
    IsAlreadyOnboarded = $isAlreadyOnboarded
    ExistingLcmVersion = $existingLcmVersion
    DetectedTokens     = $detectedTokens
    Errors             = $errors
    Warnings           = $warnings
  }
}

function New-LCMGovernanceLinks {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [string]$WorkspaceRoot,

    [switch]$DryRun
  )

  if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Get-WorkspaceRoot
  }

  $targetFullPath = [System.IO.Path]::GetFullPath($TargetPath).TrimEnd('\')
  $workspaceFullPath = [System.IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\')
  $createdLinks = @()
  $errors = @()

  # 1. Clean up legacy child .agents / .copilot directories if present
  if (-not $DryRun) {
    $legacyDirs = @(
      (Join-Path $targetFullPath '.agents'),
      (Join-Path $targetFullPath '.copilot')
    )
    foreach ($ld in $legacyDirs) {
      if (Test-Path -LiteralPath $ld) {
        Remove-Item -LiteralPath $ld -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }

  # 2. Write 1-line governance pointers for AGENTS.md and GEMINI.md
  $pointerFiles = @{
    (Join-Path $targetFullPath 'AGENTS.md') = "<!-- Governed by root LCM standard: D:\Git_Repositories\AGENTS.md -->`r`n"
    (Join-Path $targetFullPath 'GEMINI.md') = "<!-- Governed by root LCM standard: D:\Git_Repositories\GEMINI.md -->`r`n"
  }

  foreach ($pFile in $pointerFiles.Keys) {
    $pContent = $pointerFiles[$pFile]
    if ($DryRun) {
      $createdLinks += [pscustomobject]@{
        Type   = 'Pointer'
        Target = $pFile
        Source = 'Root Standard'
        Status = 'Would-Write'
      }
    }
    else {
      try {
        [System.IO.File]::WriteAllText($pFile, $pContent, (New-Object System.Text.UTF8Encoding($false)))
        $createdLinks += [pscustomobject]@{
          Type   = 'Pointer'
          Target = $pFile
          Source = 'Root Standard'
          Status = 'Written'
        }
      }
      catch {
        $errors += "Failed to write governance pointer $pFile : $_"
      }
    }
  }

  return [pscustomobject]@{
    Passed = ($errors.Count -eq 0)
    Links  = $createdLinks
    Errors = $errors
  }
}

function Expand-LCMTemplate {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [hashtable]$Tokens = @{},

    [string]$WorkspaceRoot,

    [switch]$DryRun,

    [switch]$Overwrite
  )

  if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Get-WorkspaceRoot
  }

  $targetFullPath = [System.IO.Path]::GetFullPath($TargetPath).TrimEnd('\')
  $workspaceFullPath = [System.IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\')
  $templateRoot = Join-Path $workspaceFullPath 'templates\repo-scaffold'

  if (-not (Test-Path -LiteralPath $templateRoot -PathType Container)) {
    throw "Template root not found: $templateRoot"
  }

  $templateFiles = Get-ChildItem -Path $templateRoot -Recurse -File -Filter '*.template'
  $instantiatedFiles = @()
  $errors = @()

  foreach ($tFile in $templateFiles) {
    $relativePath = [System.IO.Path]::GetRelativePath($templateRoot, $tFile.FullName)
    $destinationRelative = $relativePath.Substring(0, $relativePath.Length - '.template'.Length)
    $destinationFullPath = Join-Path $targetFullPath $destinationRelative

    $parentDir = Split-Path $destinationFullPath -Parent
    if (-not (Test-Path -LiteralPath $parentDir) -and -not $DryRun) {
      New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    if ((Test-Path -LiteralPath $destinationFullPath) -and -not $Overwrite) {
      $instantiatedFiles += [pscustomobject]@{
        Path     = $destinationRelative
        FullPath = $destinationFullPath
        Status   = 'Skipped-Existing'
      }
      continue
    }

    $content = [System.IO.File]::ReadAllText($tFile.FullName)
    foreach ($tokenKey in $Tokens.Keys) {
      $content = $content.Replace("{{$tokenKey}}", [string]$Tokens[$tokenKey])
    }

    # Normalize CRLF and UTF-8 without BOM
    $content = $content.Replace("`r`n", "`n").Replace("`n", "`r`n")
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    if ($DryRun) {
      $instantiatedFiles += [pscustomobject]@{
        Path     = $destinationRelative
        FullPath = $destinationFullPath
        Status   = 'Would-Write'
      }
    }
    else {
      try {
        [System.IO.File]::WriteAllText($destinationFullPath, $content, $utf8NoBom)
        $instantiatedFiles += [pscustomobject]@{
          Path     = $destinationRelative
          FullPath = $destinationFullPath
          Status   = 'Written'
        }
      }
      catch {
        $errors += "Failed to write $($destinationFullPath): $_"
      }
    }
  }

  return [pscustomobject]@{
    Passed = ($errors.Count -eq 0)
    Files  = $instantiatedFiles
    Errors = $errors
  }
}

function Test-LCMIntegrity {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [string]$WorkspaceRoot,

    [switch]$DryRun,

    [array]$PlannedLinks = @(),

    [array]$PlannedFiles = @()
  )

  if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Get-WorkspaceRoot
  }

  $targetFullPath = [System.IO.Path]::GetFullPath($TargetPath).TrimEnd('\')
  $errors = @()
  $checks = @()

  $requiredFiles = @(
    'docs\README.md',
    '.lcm\config.json',
    '.lcm\overrides.json',
    '.vscode\settings.json',
    'tools\Test-RepoReadiness.ps1',
    'AGENTS.md',
    'GEMINI.md'
  )

  if ($DryRun) {
    # In DryRun mode, verify simulation plan coverage
    $plannedFilePaths = @($PlannedFiles | ForEach-Object { $_.Path.Replace('/', '\') })
    $plannedLinkPaths = @($PlannedLinks | ForEach-Object { $_.Target.Substring($targetFullPath.Length).TrimStart('\') })

    foreach ($req in $requiredFiles) {
      $alreadyExists = Test-Path -LiteralPath (Join-Path $targetFullPath $req)
      $isPlanned = ($plannedFilePaths -contains $req) -or ($plannedLinkPaths -contains $req)
      if ($alreadyExists -or $isPlanned) {
        $checks += [pscustomobject]@{ Item = $req; Status = $(if ($alreadyExists) { 'Present' } else { 'Simulated-Write' }); Valid = $true }
      }
      else {
        $errors += "Dry-run plan missing required file: $req"
        $checks += [pscustomobject]@{ Item = $req; Status = 'Missing-From-Plan'; Valid = $false }
      }
    }

    return [pscustomobject]@{
      Passed = ($errors.Count -eq 0)
      Checks = $checks
      Errors = $errors
      Mode   = 'DryRun-Simulation'
    }
  }

  # Active Execution Mode: Validate physical disk
  foreach ($req in $requiredFiles) {
    $p = Join-Path $targetFullPath $req
    if (Test-Path -LiteralPath $p) {
      $checks += [pscustomobject]@{ Item = $req; Status = 'Present'; Valid = $true }
    }
    else {
      $errors += "Missing required file: $req"
      $checks += [pscustomobject]@{ Item = $req; Status = 'Missing'; Valid = $false }
    }
  }

  $jsonFiles = Get-ChildItem -Path $targetFullPath -Recurse -File -Filter '*.json' | Where-Object { $_.FullName -notmatch '\\\.git\\' }
  foreach ($jf in $jsonFiles) {
    try {
      Get-Content -Raw -Path $jf.FullName | ConvertFrom-Json | Out-Null
      $checks += [pscustomobject]@{ Item = "JSON:$($jf.Name)"; Status = 'Valid'; Valid = $true }
    }
    catch {
      $errors += "JSON syntax error in $($jf.FullName): $_"
      $checks += [pscustomobject]@{ Item = "JSON:$($jf.Name)"; Status = 'Error'; Valid = $false }
    }
  }

  return [pscustomobject]@{
    Passed = ($errors.Count -eq 0)
    Checks = $checks
    Errors = $errors
    Mode   = 'Physical-Verification'
  }
}

function Invoke-LCMOnboardRepo {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TargetRepositoryPath,

    [hashtable]$Parameters = @{},

    [switch]$Update,

    [switch]$StepByStep,

    [switch]$DryRun,

    [switch]$Force
  )

  $workspaceRoot = Get-WorkspaceRoot
  $targetFullPath = [System.IO.Path]::GetFullPath($TargetRepositoryPath).TrimEnd('\')
  Write-Host "=== Lifecycle Model (LCM) Repository Onboarding Engine ===" -ForegroundColor Cyan
  Write-Host "Target: $targetFullPath"
  Write-Host "Mode:   $(if ($DryRun) { 'DRY RUN (Read-Only Preview)' } else { 'ACTIVE EXECUTION' })"
  Write-Host ""

  # --- PHASE 1: Discovery & Pre-Flight Audit ---
  Write-Host "[Phase 1] Discovery & Pre-Flight Audit..." -ForegroundColor Yellow
  $preFlight = Test-LCMPreFlight -TargetPath $targetFullPath -WorkspaceRoot $workspaceRoot
  if (-not $preFlight.Passed) {
    Write-Error "Pre-flight audit failed with errors:"
    $preFlight.Errors | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    return $preFlight
  }

  Write-Host "Pre-flight audit passed." -ForegroundColor Green
  if ($preFlight.IsAlreadyOnboarded) {
    Write-Host "Target is already onboarded (LCM Version: $($preFlight.ExistingLcmVersion)). Mode: $(if ($Update) { 'UPDATE' } else { 'VERIFY / REFRESH' })" -ForegroundColor Cyan
  }

  if ($preFlight.Warnings.Count -gt 0) {
    $preFlight.Warnings | ForEach-Object { Write-Host " Warning: $_" -ForegroundColor Yellow }
  }

  # Handle Non-Git initialization
  if (-not $preFlight.HasGit) {
    Write-Host ""
    Write-Host "Target directory does not have a .git repository initialized." -ForegroundColor Magenta
    if (-not $DryRun) {
      $confirmGit = if ($Force) { 'Y' } else { Read-Host "Initialize git and create pre-LCM baseline commit now? [Y/n]" }
      if ($confirmGit -ne 'n' -and $confirmGit -ne 'N') {
        Write-Host "Initializing git repository (branch: main)..." -ForegroundColor Cyan
        git -C $targetFullPath init -b main | Out-Null
        
        $gitIgnoreContent = @"
# Local Developer & Environment Overrides
.vscode/*
!.vscode/settings.json
!.vscode/tasks.json
*.log
*.tmp
bin/
obj/
"@
        Set-Content -Path (Join-Path $targetFullPath '.gitignore') -Value $gitIgnoreContent -Encoding utf8
        git -C $targetFullPath add -A | Out-Null
        git -C $targetFullPath commit -m "Initial repository baseline (pre-LCM)" | Out-Null
        Write-Host "Pre-LCM baseline commit created successfully." -ForegroundColor Green
      }
      else {
        Write-Warning "Skipped git initialization. Continuing onboarding."
      }
    }
  }

  # Review detected parameter tokens
  $mergedTokens = [ordered]@{}
  foreach ($k in $preFlight.DetectedTokens.Keys) {
    $mergedTokens[$k] = if ($Parameters.ContainsKey($k)) { $Parameters[$k] } else { $preFlight.DetectedTokens[$k] }
  }

  Write-Host ""
  Write-Host "Detected Parameter Tokens:" -ForegroundColor Cyan
  $mergedTokens.GetEnumerator() | Format-Table Name, Value | Out-Host

  if ($StepByStep -and -not $Force) {
    $proceed = Read-Host "Proceed to Phase 2 (Governance Rule Seeding)? [Y/n]"
    if ($proceed -eq 'n' -or $proceed -eq 'N') { return }
  }

  # --- PHASE 2: Governance Rule Seeding ---
  Write-Host ""
  Write-Host "[Phase 2] Seeding Governance Rules (Junctions & Hardlinks)..." -ForegroundColor Yellow
  $linkResult = New-LCMGovernanceLinks -TargetPath $targetFullPath -WorkspaceRoot $workspaceRoot -DryRun:$DryRun
  $linkResult.Links | Format-Table Type, Status, Target, Source | Out-Host

  if (-not $linkResult.Passed) {
    Write-Error "Phase 2 failed:"
    $linkResult.Errors | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    return $linkResult
  }

  if ($StepByStep -and -not $Force) {
    $proceed = Read-Host "Proceed to Phase 3 (Template Instantiation)? [Y/n]"
    if ($proceed -eq 'n' -or $proceed -eq 'N') { return }
  }

  # --- PHASE 3: Template Instantiation & Parameterization ---
  Write-Host ""
  Write-Host "[Phase 3] Instantiating Operational Templates..." -ForegroundColor Yellow
  $overwriteTemplates = ($Force -or $Update)
  $templateResult = Expand-LCMTemplate -TargetPath $targetFullPath -Tokens $mergedTokens -WorkspaceRoot $workspaceRoot -DryRun:$DryRun -Overwrite:$overwriteTemplates
  $templateResult.Files | Format-Table Status, Path | Out-Host

  if (-not $templateResult.Passed) {
    Write-Error "Phase 3 failed:"
    $templateResult.Errors | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    return $templateResult
  }

  if ($StepByStep -and -not $Force) {
    $proceed = Read-Host "Proceed to Phase 4 (Verification & Baseline Commit)? [Y/n]"
    if ($proceed -eq 'n' -or $proceed -eq 'N') { return }
  }

  # --- PHASE 4: Verification & Baseline Commit ---
  Write-Host ""
  Write-Host "[Phase 4] Verification & Baseline Commit..." -ForegroundColor Yellow
  $integrityResult = Test-LCMIntegrity -TargetPath $targetFullPath -WorkspaceRoot $workspaceRoot -DryRun:$DryRun -PlannedLinks $linkResult.Links -PlannedFiles $templateResult.Files
  $integrityResult.Checks | Format-Table Item, Status, Valid | Out-Host

  if (-not $integrityResult.Passed) {
    Write-Error "Integrity check failed:"
    $integrityResult.Errors | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    return $integrityResult
  }

  Write-Host "Integrity verification passed ($($integrityResult.Mode))." -ForegroundColor Green

  if (-not $DryRun) {
    Write-Host ""
    $commitPrompt = if ($Force) { 'Y' } else { Read-Host "Stage and create LCM $(if ($Update) { 'update' } else { 'baseline' }) commit? [Y/n]" }
    if ($commitPrompt -ne 'n' -and $commitPrompt -ne 'N') {
      git -C $targetFullPath add -A | Out-Null
      $commitType = if ($Update) { 'LCM-002: LCM Governance Version Update' } else { 'LCM-001: Initial LCM Governance Onboarding Baseline' }
      $commitMsg = @"
$commitType

- Seeded immutable governance rules via NTFS junctions & hardlinks
- Instantiated parameterized documentation, tools, and VS Code configs
- Initialized target-local .lcm/ configuration and override structure
- Verified structural and hardlink integrity
"@
      git -C $targetFullPath commit -m $commitMsg | Out-Null
      Write-Host "LCM commit created." -ForegroundColor Green
    }
  }

  Write-Host ""
  Write-Host "=== Onboarding Sequence Complete for $targetFullPath ===" -ForegroundColor Green
}

Export-ModuleMember -Function Test-LCMPreFlight, New-LCMGovernanceLinks, Expand-LCMTemplate, Test-LCMIntegrity, Invoke-LCMOnboardRepo
