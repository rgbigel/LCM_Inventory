<#
.SYNOPSIS
  Tests the LcmMacriumAtoms PowerShell module.
.DESCRIPTION
  Module: LcmMacriumAtoms.Tests
  Purpose: Verifies the exported automation atoms, candidate drive normalization,
  read-only baseline telemetry extraction, and backup status evaluations.
  Path: LCM_Inventory/tests/LcmMacriumAtoms.Tests.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-11-08 16:53:00
.NOTES
  Part of CRP-308 verification suite.
#>

Describe 'LcmMacriumAtoms module' {
  BeforeAll {
    $script:wsRoot = 'D:\Git_Repositories'
    $script:modulePath = Join-Path $script:wsRoot 'LCM_Inventory\modules\LcmMacriumAtoms.psm1'
    Import-Module -Name $script:modulePath -Force
  }

  It 'exports all expected modular automation atoms' {
    $commands = @(Get-Command -Module LcmMacriumAtoms | Select-Object -ExpandProperty Name)
    $commands | Should -Contain 'ConvertTo-LcmCandidateDrives'
    $commands | Should -Contain 'Get-MacriumBaselineState'
    $commands | Should -Contain 'Get-MacriumBackupStatus'
    $commands | Should -Contain 'Start-MacriumBackup'
    $commands | Should -Contain 'Mount-MacriumBaseline'
    $commands | Should -Contain 'Dismount-MacriumBaseline'
  }

  It 'normalizes candidate drive letters from various inputs' {
    $fromArray = ConvertTo-LcmCandidateDrives -Drives @('f:', 'G', 'h:\', ' i ')
    $fromArray | Should -Be @('F', 'G', 'H', 'I')

    $fromString = ConvertTo-LcmCandidateDrives -Drives 'F;G;H;I'
    $fromString | Should -Be @('F', 'G', 'H', 'I')

    $fromComma = ConvertTo-LcmCandidateDrives -Drives 'F, G, H'
    $fromComma | Should -Be @('F', 'G', 'H')

    $defaultDrives = ConvertTo-LcmCandidateDrives
    $defaultDrives | Should -Be @('F', 'G', 'H', 'I')
  }

  It 'evaluates active baseline state and extracts physical mount details' {
    $state = Get-MacriumBaselineState -CandidateDrives @('F', 'G', 'H', 'I') -ExpectedVolumeLabel 'D4P3-WDB850-D'
    $state | Should -Not -BeNullOrEmpty
    $state.CandidateDrives | Should -Be @('F', 'G', 'H', 'I')

    if ($state.Plausible) {
      $state.MountedDrive | Should -Match '^[F-I]:$'
      $state.VolumeLabel | Should -Be 'D4P3-WDB850-D'
      $state.WorkspacePath | Should -Match '^[F-I]:\\Git_Repositories$'
      Test-Path -LiteralPath $state.WorkspacePath | Should -Be $true
    }
  }

  It 'evaluates backup status gracefully when directories are missing or populated' {
    $status = Get-MacriumBackupStatus -BackupDirectory 'Z:\NonExistentBackupDir_Test_12345'
    $status | Should -Not -BeNullOrEmpty
    $status.CompletedToday | Should -Be $false
    $status.LatestImage | Should -BeNullOrEmpty
  }

  It 'exposes Start-MacriumDailyBackup.ps1 as a discrete decoupled backup atom with -Mount option' {
    $backupScriptPath = Join-Path $script:wsRoot 'LCM_Inventory\tools\Start-MacriumDailyBackup.ps1'
    Test-Path -LiteralPath $backupScriptPath | Should -Be $true

    $backupScript = Get-Content -LiteralPath $backupScriptPath -Raw -Encoding UTF8
    $backupScript | Should -Match '\[switch\]\$Mount'
    $backupScript | Should -Match '\[switch\]\$ForceNewBackup'
    $backupScript | Should -Match '\[string\]\$ReviewScope'
    $backupScript | Should -Match '\[switch\]\$NoLaunchReview'
    $backupScript | Should -Match 'MRMTimeStamp'
    $backupScript | Should -Match 'Mount-MacriumLatestBaseline\.ps1'

    # GoodMorning must be decoupled from backup creation (no -StartBackupIfMissing in GoodMorning)
    $morningScriptPath = Join-Path $script:wsRoot 'LCM_Inventory\tools\Invoke-LCM_GoodMorning.ps1'
    $morningScript = Get-Content -LiteralPath $morningScriptPath -Raw -Encoding UTF8
    $morningScript | Should -Not -Match '-StartBackupIfMissing'
  }
}

