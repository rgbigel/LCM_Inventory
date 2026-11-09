<#
.SYNOPSIS
  Universal general readiness quality gate for LCM-governed repositories.
.DESCRIPTION
  Module: tools/Test-GeneralReadiness.ps1
  Purpose: Executes universal LCM quality gates against any target repository.
  Serves as Step 1 in the two-step repository readiness architecture, verifying
  reparse points, source file encoding, AST parser syntax, and secrets isolation.
  Path: LCM_Inventory/tools/Test-GeneralReadiness.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.1
  Date: 2026-11-09 12:30:00
.PARAMETER RepositoryPath
  Target repository root path to audit. Defaults to current working directory.
.PARAMETER Help
  Displays parameter documentation and usage syntax.
.NOTES
  Part of CRP-310 (Two-Step Readiness Architecture).
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Target repository root path to audit')]
  [string]$RepositoryPath = '',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Test-GeneralReadiness.ps1 [-RepositoryPath <path>] [-h]'
  Write-Host '  Universal general readiness quality gate check for any LCM repository.'
  return
}

$repoPath = if ([string]::IsNullOrWhiteSpace($RepositoryPath)) {
  (Get-Location).Path
} else {
  (Resolve-Path -LiteralPath $RepositoryPath).Path
}

$repoName = Split-Path $repoPath -Leaf
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " General LCM Quality Gate Readiness Check (Step 1/2)" -ForegroundColor Cyan
Write-Host " Target Repository: $repoName ($repoPath)" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$gateFailures = [System.Collections.Generic.List[string]]::new()

# Gate 1: .agents/rules Reparse Point
Write-Host "`n[Gate 1/6] Validating .agents/rules Reparse Point..." -ForegroundColor Yellow
$rulesPath = Join-Path $repoPath '.agents\rules'
if (-not (Test-Path -LiteralPath $rulesPath)) {
  $gateFailures.Add("Gate 1: .agents\rules path does not exist.")
  Write-Host "  FAILED: .agents\rules does not exist." -ForegroundColor Red
} else {
  $item = Get-Item -LiteralPath $rulesPath -Force
  $isJunction = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
  if ($repoName -eq 'LCM_AI') {
    Write-Host "  Passed: Canonical rule authority hub." -ForegroundColor Green
  } elseif ($isJunction) {
    Write-Host "  Passed: Reparse point active -> $($item.Target)" -ForegroundColor Green
  } else {
    $gateFailures.Add("Gate 1: .agents\rules is a physical directory instead of a junction.")
    Write-Host "  FAILED: .agents\rules is not a junction." -ForegroundColor Red
  }
}

# Gate 2: UTF-8 without BOM on source files
Write-Host "`n[Gate 2/6] Validating File Encodings (UTF-8 No-BOM)..." -ForegroundColor Yellow
$bomFiles = [System.Collections.Generic.List[string]]::new()
$codeFiles = @(Get-ChildItem -LiteralPath $repoPath -Include *.ps1,*.psm1,*.py,*.js,*.json -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(\.git|\.venv|scratch|node_modules|logs|data|docs\\Proposals)\\' })

foreach ($f in $codeFiles) {
  $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    # Exclude legacy tool explorer options if present
    if ($f.Name -ne 'tool_explorer_options.json') {
      $bomFiles.Add($f.FullName.Substring($repoPath.Length + 1))
    }
  }
}

if ($bomFiles.Count -gt 0) {
  $gateFailures.Add("Gate 2: Found $($bomFiles.Count) file(s) with UTF-8 BOM encoding.")
  Write-Host "  FAILED: Found $($bomFiles.Count) file(s) containing UTF-8 BOM." -ForegroundColor Red
  foreach ($b in ($bomFiles | Select-Object -First 3)) { Write-Host "    - $b" -ForegroundColor DarkYellow }
} else {
  Write-Host "  Passed: $($codeFiles.Count) source file(s) verified clean (No BOM)." -ForegroundColor Green
}

# Gate 3: PowerShell AST Syntax Validation (RULE-PS-021)
Write-Host "`n[Gate 3/6] Validating PowerShell AST Syntax..." -ForegroundColor Yellow
$psFiles = @(Get-ChildItem -LiteralPath $repoPath -Include *.ps1,*.psm1,*.psd1 -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(\.git|\.venv|scratch|node_modules|logs|data)\\' })

# Preload OOP module classes if present in dependency order
$classDirs = @(Get-ChildItem -LiteralPath $repoPath -Directory -Recurse -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -like '*\modules\*\Classes' -or $_.FullName -like '*/modules/*/Classes' })
foreach ($cd in $classDirs) {
  $orderedClasses = @('DaemonDto.ps1', 'DaemonEnvironment.ps1', 'LcmTokenVault.ps1', 'LcmSecurityGateway.ps1', 'DaemonActionController.ps1')
  foreach ($cls in $orderedClasses) {
    $cp = Join-Path $cd.FullName $cls
    if (Test-Path -LiteralPath $cp) {
      try { . $cp } catch {}
    }
  }
}

$psErrors = [System.Collections.Generic.List[string]]::new()
foreach ($psf in $psFiles) {
  $rawContent = [System.IO.File]::ReadAllText($psf.FullName)
  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseInput($rawContent, [ref]$tokens, [ref]$parseErrors)
  if ($null -ne $parseErrors -and $parseErrors.Length -gt 0) {
    foreach ($err in $parseErrors) {
      $psErrors.Add("$($psf.Name):$($err.Extent.StartLineNumber) - $($err.Message)")
    }
  }
}

if ($psErrors.Count -gt 0) {
  $gateFailures.Add("Gate 3: PowerShell parser reported $($psErrors.Count) syntax error(s).")
  Write-Host "  FAILED: $($psErrors.Count) syntax error(s) found." -ForegroundColor Red
  foreach ($e in ($psErrors | Select-Object -First 5)) { Write-Host "    - $e" -ForegroundColor DarkYellow }
} else {
  Write-Host "  Passed: $($psFiles.Count) PowerShell file(s) parsed with 0 syntax errors." -ForegroundColor Green
}

# Gate 4: Python Compilation Syntax Check (RULE-PY-001)
Write-Host "`n[Gate 4/6] Validating Python Source Syntax..." -ForegroundColor Yellow
$pyFiles = @(Get-ChildItem -LiteralPath $repoPath -Filter *.py -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(\.git|\.venv|scratch|node_modules|logs|data)\\' })

if ($pyFiles.Count -gt 0) {
  $pyFailures = [System.Collections.Generic.List[string]]::new()
  foreach ($pyf in $pyFiles) {
    $out = python -m py_compile $pyf.FullName 2>&1
    if ($LASTEXITCODE -ne 0) {
      $pyFailures.Add("$($pyf.Name): $out")
    }
  }
  if ($pyFailures.Count -gt 0) {
    $gateFailures.Add("Gate 4: Python syntax compilation failed for $($pyFailures.Count) file(s).")
    Write-Host "  FAILED: $($pyFailures.Count) Python file(s) failed compilation." -ForegroundColor Red
  } else {
    Write-Host "  Passed: $($pyFiles.Count) Python file(s) compiled with 0 syntax errors." -ForegroundColor Green
  }
} else {
  Write-Host "  Skipped: No Python source files in repository." -ForegroundColor Gray
}

# Gate 5: Git Secrets & Ignore Isolation Check
Write-Host "`n[Gate 5/6] Validating Git Secrets & Ignore Isolation..." -ForegroundColor Yellow
$gitignorePath = Join-Path $repoPath '.gitignore'
if (-not (Test-Path -LiteralPath $gitignorePath)) {
  $gateFailures.Add("Gate 5: Missing .gitignore file.")
  Write-Host "  FAILED: Missing .gitignore file." -ForegroundColor Red
} else {
  $untrackedSecrets = (git -C $repoPath ls-files '**/secrets.json' 2>$null)
  if (-not [string]::IsNullOrWhiteSpace($untrackedSecrets)) {
    $gateFailures.Add("Gate 5: secrets.json is tracked in git index!")
    Write-Host "  FAILED: secrets.json tracked in git index!" -ForegroundColor Red
  } else {
    Write-Host "  Passed: Git-ignore rules and secrets isolation verified." -ForegroundColor Green
  }
}

# Gate 6: Elevated Operations & Immutability Governance (RULE-ELEV-007)
Write-Host "`n[Gate 6/6] Validating Elevated Operations & Immutability Governance (RULE-ELEV-007)..." -ForegroundColor Yellow
$elevatedCheckFailures = [System.Collections.Generic.List[string]]::new()
$catalogJsonPath = Join-Path $repoPath 'config\tool_catalog.json'
if (-not (Test-Path -LiteralPath $catalogJsonPath)) {
  $catalogJsonPath = 'D:\Git_Repositories\LCM_Inventory\config\tool_catalog.json'
}
$catalogMap = @{}
if (Test-Path -LiteralPath $catalogJsonPath) {
  try {
    $rawCat = [System.IO.File]::ReadAllText($catalogJsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $items = if ($rawCat.tools) { $rawCat.tools } else { @($rawCat) }
    foreach ($item in $items) {
      if ($item.Name) { $catalogMap[$item.Name] = $item }
    }
  } catch {}
}

foreach ($psf in $psFiles) {
  if ($psf.Name -eq 'Test-GeneralReadiness.ps1') { continue }
  $content = [System.IO.File]::ReadAllText($psf.FullName, [System.Text.Encoding]::UTF8)
  if ($content -match '\$ElevatedOperations|New-Variable\s+-Name\s+ElevatedOperations') {
    $leaf = $psf.Name
    # 1. Verify New-Variable with ReadOnly or Constant
    if ($content -notmatch '(?s)New-Variable\s+-Name\s+ElevatedOperations\s+.*?-Option\s+(?:ReadOnly|Constant)') {
      $elevatedCheckFailures.Add("$leaf declares ElevatedOperations without immutable -Option ReadOnly/Constant.")
    }
    # 2. Verify comment-based help .NOTES has Elevated Operations:
    if ($content -notmatch '(?i)Elevated\s+Operations:') {
      $elevatedCheckFailures.Add("$leaf does not document 'Elevated Operations:' in comment-based help (.NOTES).")
    }
    # 3. Verify anti-poisoning (no GUI tools like BCompare)
    if ($content -match '(?i)ElevatedOperations.*BCompare') {
      $elevatedCheckFailures.Add("$leaf attempts to declare GUI tool BCompare as elevated, violating RULE-ELEV-007.")
    }
    # 4. If catalog entry exists, verify catalog parity
    if ($catalogMap.ContainsKey($leaf)) {
      $catEntry = $catalogMap[$leaf]
      if (-not ($catEntry.PSObject.Properties['ElevatedOperations']) -or $null -eq $catEntry.ElevatedOperations) {
        $elevatedCheckFailures.Add("$leaf defines ElevatedOperations in code, but tool_catalog.json lacks matching 'ElevatedOperations'.")
      }
    }
  }
}

if ($elevatedCheckFailures.Count -gt 0) {
  $gateFailures.Add("Gate 6: Elevated operations governance check failed for $($elevatedCheckFailures.Count) issue(s).")
  Write-Host "  FAILED: $($elevatedCheckFailures.Count) elevated operations governance issue(s) found." -ForegroundColor Red
  foreach ($f in ($elevatedCheckFailures | Select-Object -First 5)) { Write-Host "    - $f" -ForegroundColor DarkYellow }
} else {
  Write-Host "  Passed: Elevated operations immutability and catalog parity verified (RULE-ELEV-007)." -ForegroundColor Green
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
if ($gateFailures.Count -eq 0) {
  Write-Host " All General LCM Quality Gates PASSED (Readiness: OK)" -ForegroundColor Green
  Write-Host "=================================================================" -ForegroundColor Cyan
  return [pscustomobject]@{
    Repository = $repoName
    RepositoryPath = $repoPath
    Passed = $true
    Failures = @()
    AuditedFiles = ($codeFiles.Count)
  }
} else {
  Write-Host " General LCM Quality Gates FAILED ($($gateFailures.Count) Failure(s))" -ForegroundColor Red
  Write-Host "=================================================================" -ForegroundColor Cyan
  throw "General readiness quality gate failed for '$repoName': $($gateFailures -join '; ')"
}
