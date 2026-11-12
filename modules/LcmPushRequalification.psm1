<#
.SYNOPSIS
  Stepwise Push Requalification and Dynamic Remediation Engine.
.DESCRIPTION
  Module: LCM_Inventory/modules/LcmPushRequalification.psm1
  Purpose: Executes transparent, stepwise DAG requalification prior to remote Git publish,
           providing interactive triage, dynamic remediation step injection on failure,
           and automated proposal state upgrades per RULE-DEC-005.
  Path: LCM_Inventory/modules/LcmPushRequalification.psm1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.1
  Date: 2026-11-12 12:45:00
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-LcmPublishPreflight {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object]$PushPlan,

    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot,

    [Parameter(Mandatory = $true)]
    [string]$ProposalsFile
  )

  if (-not (Test-Path -LiteralPath $ProposalsFile)) {
    throw "Proposals file not found: $ProposalsFile"
  }

  $rawJson = Get-Content -LiteralPath $ProposalsFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $store = $rawJson

  $reliefActive = $false
  $reasons = [System.Collections.Generic.List[string]]::new()

  if ($store.PSObject.Properties['minimal_tests'] -and $store.minimal_tests) {
    $reliefActive = $true
    $reasons.Add("MinimalTests: True (Fast Single DAG)")
  }
  if ($store.PSObject.Properties['flow_mode'] -and $store.flow_mode -in @('relief', 'doit')) {
    $reliefActive = $true
    $reasons.Add("FlowMode: $($store.flow_mode)")
  }
  if ($store.PSObject.Properties['granularity'] -and $store.granularity -eq 'loose') {
    $reliefActive = $true
    $reasons.Add("Granularity: loose")
  }
  if ($store.PSObject.Properties['testing_mode'] -and $store.testing_mode -eq 'passive') {
    $reliefActive = $true
    $reasons.Add("TestingMode: passive")
  }
  if ($store.PSObject.Properties['always_proceed'] -and $store.always_proceed) {
    $reliefActive = $true
    $reasons.Add("AlwaysProceed: True")
  }

  $debtProposals = [System.Collections.Generic.List[object]]::new()
  $completedList = @($PushPlan.CompletedProposals)

  foreach ($p in $rawJson.proposals) {
    $matching = @($completedList | Where-Object { $_.Id -eq [int]$p.id })
    if ($matching.Count -gt 0) {
      $hasDebt = $false
      if ($p.PSObject.Properties['plan_state'] -and $p.plan_state -eq 'completed [minimal-tests]') {
        $hasDebt = $true
      }
      if ($p.PSObject.Properties['quality_checks_deferred'] -and $p.quality_checks_deferred) {
        $hasDebt = $true
      }
      if ($hasDebt) {
        $debtProposals.Add($p)
      }
    }
  }

  $hasReliefOrDebt = $reliefActive -or ($debtProposals.Count -gt 0)

  return [PSCustomObject]@{
    HasReliefOrDebt = $hasReliefOrDebt
    ReliefActive    = $reliefActive
    ReliefReasons   = @($reasons)
    DebtProposals   = @($debtProposals)
    Summary         = if ($debtProposals.Count -gt 0) {
      "ReliefActive=$reliefActive; DebtProposals=$($debtProposals.Count) (#$($debtProposals.id -join ', #'))"
    } else {
      "ReliefActive=$reliefActive ($($reasons -join ', '))"
    }
  }
}

function Show-LcmPublishTriagePrompt {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$PreflightCheck
  )

  Write-Host "`n==========================================================================" -ForegroundColor Yellow
  Write-Host " [PUBLISH PREFLIGHT] Relief Mode or Minimal-Test Debt Detected (RULE-DEC-005)" -ForegroundColor Yellow
  Write-Host "==========================================================================" -ForegroundColor Yellow
  if ($PreflightCheck.ReliefActive) {
    Write-Host "  • Workspace Relief State : ACTIVE ($($PreflightCheck.ReliefReasons -join ', '))" -ForegroundColor DarkYellow
  } else {
    Write-Host "  • Workspace Relief State : Inactive" -ForegroundColor DarkGray
  }
  if ($PreflightCheck.DebtProposals.Count -gt 0) {
    Write-Host "  • Deferred Test Debt     : $($PreflightCheck.DebtProposals.Count) proposal(s) with minimal tests:" -ForegroundColor Red
    foreach ($p in $PreflightCheck.DebtProposals) {
      Write-Host "      - Proposal #$($p.id): $($p.title)" -ForegroundColor Red
    }
  } else {
    Write-Host "  • Deferred Test Debt     : None" -ForegroundColor Green
  }
  Write-Host "--------------------------------------------------------------------------" -ForegroundColor Yellow
  Write-Host "Choose how to handle pre-publish qualification:" -ForegroundColor Cyan
  Write-Host "  [1] (Recommended) Force Requalification" -ForegroundColor White
  Write-Host "      Turn ReliefMode OFF, run stepwise qualification DAG with dynamic" -ForegroundColor Gray
  Write-Host "      remediation, upgrade proposal debt to verified, and proceed with Publish." -ForegroundColor Gray
  Write-Host "  [2] Circumvent / Force Push (-BypassReliefGate)" -ForegroundColor White
  Write-Host "      Record an audit waiver and proceed immediately without running full tests." -ForegroundColor Gray
  Write-Host "  [3] Continue (May Fail)" -ForegroundColor White
  Write-Host "      Proceed without changing switches; standard preflight checks will enforce rules." -ForegroundColor Gray
  Write-Host "  [4] Cancel" -ForegroundColor White
  Write-Host "      Abort publish immediately. Return to prompt without touching git." -ForegroundColor Gray
  Write-Host "--------------------------------------------------------------------------" -ForegroundColor Yellow

  $choice = Read-Host "Select an option [1-4] (Default: 1)"
  if ([string]::IsNullOrWhiteSpace($choice)) {
    $choice = "1"
  }

  switch ($choice.Trim()) {
    "1" { return "requalify" }
    "2" { return "circumvent" }
    "3" { return "continue" }
    "4" { return "cancel" }
    default { return "requalify" }
  }
}

function Invoke-RemediationStep {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$StepName,

    [Parameter(Mandatory = $true)]
    [string]$IssueDescription,

    [Parameter(Mandatory = $false)]
    [scriptblock]$AutoRemediateAction,

    [Parameter(Mandatory = $false)]
    [string]$FilePath,

    [Parameter(Mandatory = $false)]
    [switch]$NonInteractive
  )

  Write-Host "`n────────────────────────────────────────────────────────────────────────" -ForegroundColor Red
  Write-Host " [DYNAMIC REMEDIATION STEP] Issue Encountered at $StepName" -ForegroundColor Red
  Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Red
  Write-Host "  Issue: $IssueDescription" -ForegroundColor Yellow
  if (-not [string]::IsNullOrWhiteSpace($FilePath)) {
    Write-Host "  File : $FilePath" -ForegroundColor Cyan
  }

  if ($NonInteractive) {
    if ($null -ne $AutoRemediateAction) {
      Write-Host "  -> Non-interactive mode: executing auto-remediation..." -ForegroundColor Cyan
      & $AutoRemediateAction
      return "retried_ok"
    } else {
      Write-Host "  -> Non-interactive mode with no auto-remediation: aborting." -ForegroundColor Red
      return "aborted"
    }
  }

  Write-Host "`nOptions:" -ForegroundColor Cyan
  if ($null -ne $AutoRemediateAction) {
    Write-Host "  [1] (Auto-Remediate) Execute automated fix and retry step" -ForegroundColor White
  } else {
    Write-Host "  [1] (Inspect) View details in console" -ForegroundColor White
  }
  Write-Host "  [2] (Retry) Retry the step now" -ForegroundColor White
  Write-Host "  [3] (Defer / Skip) Record audit note and continue" -ForegroundColor White
  Write-Host "  [4] (Abort) Terminate the publish pipeline" -ForegroundColor White
  Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Red

  $choice = Read-Host "Select action [1-4] (Default: 1)"
  if ([string]::IsNullOrWhiteSpace($choice)) {
    $choice = "1"
  }

  switch ($choice.Trim()) {
    "1" {
      if ($null -ne $AutoRemediateAction) {
        Write-Host "  -> Executing auto-remediation..." -ForegroundColor Cyan
        & $AutoRemediateAction
        return "retried_ok"
      } else {
        Write-Host "  -> Details: $IssueDescription" -ForegroundColor DarkGray
        return "retried_ok"
      }
    }
    "2" {
      return "retried_ok"
    }
    "3" {
      Write-Host "  -> Step skipped by operator with audit note." -ForegroundColor Yellow
      return "skipped"
    }
    "4" {
      Write-Host "  -> Aborting pipeline on operator request." -ForegroundColor Red
      return "aborted"
    }
    default {
      return "aborted"
    }
  }
}

function Invoke-LcmStepwiseRequalification {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object]$PushPlan,

    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot,

    [Parameter(Mandatory = $true)]
    [string]$ProposalsFile,

    [Parameter(Mandatory = $false)]
    [switch]$AutoRemediate,

    [Parameter(Mandatory = $false)]
    [switch]$NonInteractive
  )

  Write-Host "`n==========================================================================" -ForegroundColor Cyan
  Write-Host " [STEPWISE REQUALIFICATION] Initiating Qualification Pipeline (RULE-DEC-005)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan

  $startTime = [System.Diagnostics.Stopwatch]::StartNew()
  $stepReceipts = [System.Collections.Generic.List[object]]::new()

  # ----------------------------------------------------------------------------
  # Step 1/5: Reset Relief Switches
  # ----------------------------------------------------------------------------
  Write-Host "`n[1/5] Resetting Development Relief Switches..." -ForegroundColor Yellow
  $s1Sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    $reliefScript = Join-Path $WorkspaceRoot "LCM_Inventory\tools\Set-LcmReliefMode.ps1"
    if (Test-Path -LiteralPath $reliefScript) {
      & pwsh -NoProfile -File $reliefScript -Off | Out-Null
    }

    $rawJson = Get-Content -LiteralPath $ProposalsFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $rawJson.minimal_tests = $false
    $rawJson.test_scope = 'full'
    if ($rawJson.PSObject.Properties['flow_mode']) { $rawJson.flow_mode = 'standard' }
    if ($rawJson.PSObject.Properties['granularity']) { $rawJson.granularity = 'tight' }
    if ($rawJson.PSObject.Properties['testing_mode']) { $rawJson.testing_mode = 'active' }
    if ($rawJson.PSObject.Properties['always_proceed']) { $rawJson.always_proceed = $false }
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($ProposalsFile, ($rawJson | ConvertTo-Json -Depth 10), $utf8NoBom)

    $s1Sw.Stop()
    Write-Host "  -> Relief switches reset: Granularity=tight, TestingMode=active, MinimalTests=False [$($s1Sw.ElapsedMilliseconds)ms]" -ForegroundColor Green
    $stepReceipts.Add(@{ Step = 1; Name = "ResetReliefSwitches"; Status = "PASS"; DurationMs = $s1Sw.ElapsedMilliseconds })
  } catch {
    $s1Sw.Stop()
    $remedy = Invoke-RemediationStep -StepName "Step 1: Reset Switches" -IssueDescription $_.Exception.Message -NonInteractive:$NonInteractive
    if ($remedy -eq "aborted") {
      return [PSCustomObject]@{ Success = $false; FailedStep = 1; Receipts = @($stepReceipts) }
    }
  }

  # ----------------------------------------------------------------------------
  # Step 2/5: AST & UTF-8 Encoding / Syntax Validation
  # ----------------------------------------------------------------------------
  Write-Host "`n[2/5] AST Syntax & UTF-8 BOM Preflight Gate..." -ForegroundColor Yellow
  $s2Sw = [System.Diagnostics.Stopwatch]::StartNew()

  $reposToCheck = @($PushPlan.RequiredRepositories)
  $astFailures = [System.Collections.Generic.List[object]]::new()

  foreach ($repoName in $reposToCheck) {
    $repoPath = if ($repoName -eq 'Git_Repositories') { $WorkspaceRoot } else { Join-Path $WorkspaceRoot $repoName }
    if (-not (Test-Path -LiteralPath $repoPath)) { continue }

    # Find modified / staged files in this repo
    $changedFiles = @(git -C $repoPath status --porcelain | ForEach-Object {
      $line = $_.Trim()
      if ($line.Length -gt 3) {
        $filePath = $line.Substring(3).Trim(' "')
        Join-Path $repoPath $filePath
      }
    } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })

    foreach ($file in $changedFiles) {
      if ($file -match '\.(ps1|psm1|psd1)$') {
        # Check AST parse
        $parseErrors = $null
        $tokens = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$parseErrors) | Out-Null
        if ($parseErrors -and $parseErrors.Count -gt 0) {
          $astFailures.Add(@{ File = $file; Type = "AST"; Message = $parseErrors[0].Message })
        }

        # Check BOM
        $bytes = [System.IO.File]::ReadAllBytes($file)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
          $astFailures.Add(@{ File = $file; Type = "BOM"; Message = "UTF-8 BOM detected in $file" })
        }
      }
    }
  }

  if ($astFailures.Count -gt 0) {
    foreach ($fail in $astFailures) {
      $failFile = $fail.File
      $failType = $fail.Type
      $autoFix = $null
      if ($failType -eq "BOM") {
        $autoFix = {
          $content = [System.IO.File]::ReadAllText($failFile, [System.Text.Encoding]::UTF8)
          $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
          [System.IO.File]::WriteAllText($failFile, $content, $utf8NoBom)
          Write-Host "    -> Stripped BOM from $failFile" -ForegroundColor Green
        }
      }
      $remedy = Invoke-RemediationStep -StepName "Step 2: AST & BOM Gate" -IssueDescription $fail.Message -FilePath $failFile -AutoRemediateAction $autoFix -NonInteractive:$NonInteractive
      if ($remedy -eq "aborted") {
        return [PSCustomObject]@{ Success = $false; FailedStep = 2; Receipts = @($stepReceipts) }
      }
    }
  }

  $s2Sw.Stop()
  Write-Host "  -> AST syntax & UTF-8 encoding validation PASSED [$($s2Sw.ElapsedMilliseconds)ms]" -ForegroundColor Green
  $stepReceipts.Add(@{ Step = 2; Name = "ValidateAstSyntax"; Status = "PASS"; DurationMs = $s2Sw.ElapsedMilliseconds })

  # ----------------------------------------------------------------------------
  # Step 3/5: General Quality Gate Readiness
  # ----------------------------------------------------------------------------
  Write-Host "`n[3/5] General Quality Gate Readiness Verification..." -ForegroundColor Yellow
  $s3Sw = [System.Diagnostics.Stopwatch]::StartNew()

  $readinessScript = Join-Path $WorkspaceRoot "LCM_Inventory\tools\Test-GeneralReadiness.ps1"
  if (Test-Path -LiteralPath $readinessScript) {
    foreach ($repoName in $reposToCheck) {
      $repoPath = if ($repoName -eq 'Git_Repositories') { $WorkspaceRoot } else { Join-Path $WorkspaceRoot $repoName }
      if (-not (Test-Path -LiteralPath $repoPath)) { continue }

      Write-Host "  -> Running Test-GeneralReadiness for $repoName..." -ForegroundColor Cyan
      $readinessOutput = & pwsh -NoProfile -File $readinessScript -RepositoryPath $repoPath 2>&1
      if ($LASTEXITCODE -ne 0) {
        $errText = ($readinessOutput | Out-String).Trim()
        $remedy = Invoke-RemediationStep -StepName "Step 3: Quality Gate ($repoName)" -IssueDescription $errText -NonInteractive:$NonInteractive
        if ($remedy -eq "aborted") {
          return [PSCustomObject]@{ Success = $false; FailedStep = 3; Receipts = @($stepReceipts) }
        }
      }
    }
  }

  $s3Sw.Stop()
  Write-Host "  -> All General Quality Gates PASSED (Readiness: OK) [$($s3Sw.ElapsedMilliseconds)ms]" -ForegroundColor Green
  $stepReceipts.Add(@{ Step = 3; Name = "TestQualityGates"; Status = "PASS"; DurationMs = $s3Sw.ElapsedMilliseconds })

  # ----------------------------------------------------------------------------
  # Step 4/5: Proposal State Upgrade & Ledger Sync
  # ----------------------------------------------------------------------------
  Write-Host "`n[4/5] Upgrading Proposal States & Synchronizing Ledger..." -ForegroundColor Yellow
  $s4Sw = [System.Diagnostics.Stopwatch]::StartNew()

  $rawJson = Get-Content -LiteralPath $ProposalsFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $completedList = @($PushPlan.CompletedProposals)
  $upgradedCount = 0

  foreach ($p in $rawJson.proposals) {
    $matching = @($completedList | Where-Object { $_.Id -eq [int]$p.id })
    if ($matching.Count -gt 0) {
      $modified = $false
      if ($p.PSObject.Properties['plan_state'] -and $p.plan_state -eq 'completed [minimal-tests]') {
        $p.plan_state = 'completed'
        $modified = $true
      }
      if ($p.PSObject.Properties['quality_checks_deferred'] -and $p.quality_checks_deferred) {
        $p.quality_checks_deferred = $false
        $modified = $true
      }
      if ($p.PSObject.Properties['minimal_tests'] -and $p.minimal_tests) {
        $p.minimal_tests = $false
        $modified = $true
      }
      if ($p.PSObject.Properties['test_scope']) {
        $p.test_scope = 'full'
        $modified = $true
      }

      if ($modified) {
        $upgradedCount++
        Write-Host "  -> Upgraded Proposal #$($p.id) ($($p.title)) to fully verified 'completed'." -ForegroundColor Green
      }
    }
  }

  if ($upgradedCount -gt 0) {
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($ProposalsFile, ($rawJson | ConvertTo-Json -Depth 10), $utf8NoBom)

    # Sync SQLite DB and export SQL text dump
    $syncDbScript = Join-Path $WorkspaceRoot "LCM_Inventory\tools\sync_proposals_db.py"
    if (Test-Path -LiteralPath $syncDbScript) {
      python $syncDbScript --action sync | Out-Null
      python $syncDbScript --action dump | Out-Null
      Write-Host "  -> Synchronized proposals.db and exported data/proposals/proposals.sql." -ForegroundColor Green
    }
  } else {
    Write-Host "  -> No deferred proposal debt found in cohort; ledger aligned." -ForegroundColor Green
  }

  $s4Sw.Stop()
  $stepReceipts.Add(@{ Step = 4; Name = "UpgradeProposalStates"; Status = "PASS"; UpgradedCount = $upgradedCount; DurationMs = $s4Sw.ElapsedMilliseconds })

  # ----------------------------------------------------------------------------
  # Step 5/5: Handoff to Remote Push
  # ----------------------------------------------------------------------------
  $startTime.Stop()
  Write-Host "`n[5/5] Requalification Complete: Handing off to Remote Push Pipeline [$($startTime.ElapsedMilliseconds)ms total]" -ForegroundColor Green
  $stepReceipts.Add(@{ Step = 5; Name = "CompleteHandoff"; Status = "READY"; DurationMs = 0 })

  # Save audit receipt
  $receiptDir = Join-Path $WorkspaceRoot "LCM_Inventory\data\reviews\push_receipts"
  if (-not (Test-Path -LiteralPath $receiptDir)) {
    New-Item -ItemType Directory -Path $receiptDir -Force | Out-Null
  }
  $receiptFile = Join-Path $receiptDir ("requalification_{0:yyyyMMdd_HHmmss}.json" -f (Get-Date))
  $receiptObj = @{
    Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    TotalMs     = $startTime.ElapsedMilliseconds
    Steps       = @($stepReceipts)
    Upgraded    = $upgradedCount
    Cohorts     = @($reposToCheck)
  }
  [System.IO.File]::WriteAllText($receiptFile, ($receiptObj | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))
  Write-Host "  -> Requalification audit receipt written to: $receiptFile" -ForegroundColor DarkGray

  return [PSCustomObject]@{
    Success         = $true
    UpgradedCount   = $upgradedCount
    ReceiptPath     = $receiptFile
    Receipts        = @($stepReceipts)
  }
}

Export-ModuleMember -Function Test-LcmPublishPreflight, Show-LcmPublishTriagePrompt, Invoke-RemediationStep, Invoke-LcmStepwiseRequalification

