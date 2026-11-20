<#
.SYNOPSIS
    Tests the Macrium-backed lifecycle BCR review contract.
.DESCRIPTION
    Module: MacriumBcrReview.Tests
    Purpose: Verifies the governed Macrium BCR wrapper, baseline reuse, and lifecycle routing contracts.
    Path: LCM_Inventory/tests/MacriumBcrReview.Tests.ps1
    Authors: Rolf, LCM_AI Engine, Claude
    Version: 10.2.3
    Date: 2026-11-20
#>

Describe 'Macrium-backed lifecycle BCR review' {
  BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $reviewScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumBcrReview.ps1') -Raw -Encoding UTF8
    $actionScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-ProposalAction.ps1') -Raw -Encoding UTF8
  }

  It 'uses the Macrium baseline tool and the operator-owned _LCM profile' {
    $reviewScript | Should -Match ([regex]::Escape("Invoke-MacriumDailyBcrBaseline.ps1"))
    $reviewScript | Should -Match ([regex]::Escape("ReviewScope = `$CRP"))
    $reviewScript | Should -Match ([regex]::Escape('Confirm = $false'))
    $reviewScript | Should -Match ([regex]::Escape("Profile = '_LCM'"))
    $reviewScript | Should -Match ([regex]::Escape("BaselineKind = 'MacriumReflect'"))
  }

  It 'does not recreate Git-export or dynamic Beyond Compare session behavior' {
    $reviewScript | Should -Not -Match 'Export-BCompareBaseline'
    $reviewScript | Should -Not -Match 'Update-BCReviewSession'
    $reviewScript | Should -Not -Match 'BCSessions\.xml'
    $reviewScript | Should -Not -Match 'Start-Process.*BCompare'
  }

  It 'captures the Macrium detach exit code without assuming LASTEXITCODE exists' {
    $baselineScript = (@('tools\Invoke-MacriumDailyBcrBaseline.ps1', 'tools\Invoke-MacriumMountWorker.ps1', 'modules\LcmMacriumAtoms.psm1') | ForEach-Object { Get-Content -LiteralPath (Join-Path $repositoryRoot $_) -Raw -Encoding UTF8 }) -join "`n" # CRP-343: worker moved to the mount atom, helpers to the shared module

    $baselineScript | Should -Match ([regex]::Escape('$detachExitCode = if (Test-Path variable:global:LASTEXITCODE)'))
    $baselineScript | Should -Not -Match 'if \(\$LASTEXITCODE -ne 0\)'
  }

  It 'records detach, reappearance, and snapshot corroboration as mount evidence' {
    $baselineScript = (@('tools\Invoke-MacriumDailyBcrBaseline.ps1', 'tools\Invoke-MacriumMountWorker.ps1', 'modules\LcmMacriumAtoms.psm1') | ForEach-Object { Get-Content -LiteralPath (Join-Path $repositoryRoot $_) -Raw -Encoding UTF8 }) -join "`n" # CRP-343: worker moved to the mount atom, helpers to the shared module

    $baselineScript | Should -Match ([regex]::Escape('[int]$MountTimeoutSeconds = 120'))
    $baselineScript | Should -Match ([regex]::Escape('$detachedDrives.Add("$letter`:")'))
    $baselineScript | Should -Match ([regex]::Escape('Get-MountedBaselineEvidence -MountedBaseline $mountedBaseline -DetachedDrives @($detachedDrives)'))
    $baselineScript | Should -Match ([regex]::Escape('GoodNightObserved'))
    $baselineScript | Should -Match ([regex]::Escape('SnapshotSavedAt'))
    $baselineScript | Should -Match ([regex]::Escape('MountEvidence = $mountEvidence'))
  }

  It 'opens the completed image directly in Macrium browse mode' {
    $baselineScript = (@('tools\Invoke-MacriumDailyBcrBaseline.ps1', 'tools\Invoke-MacriumMountWorker.ps1', 'modules\LcmMacriumAtoms.psm1') | ForEach-Object { Get-Content -LiteralPath (Join-Path $repositoryRoot $_) -Raw -Encoding UTF8 }) -join "`n" # CRP-343: worker moved to the mount atom, helpers to the shared module

    $baselineScript | Should -Match ([regex]::Escape("Start-Process -FilePath `$reflectPath -ArgumentList @('-b', `$ImagePath)"))
    $baselineScript | Should -Not -Match ([regex]::Escape("ArgumentList @(`$ImagePath, '-b')"))
  }

  It 'limits automatic baseline creation to one local calendar day and preserves an explicit override' {
    $baselineScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1') -Raw -Encoding UTF8

    $baselineScript | Should -Match ([regex]::Escape('macrium-automatic-backup-start.json'))
    $baselineScript | Should -Match ([regex]::Escape('Automatic baseline creation is limited to once per local calendar day'))
    $baselineScript | Should -Match ([regex]::Escape('if ($Automatic -and (Test-AutomaticBackupAlreadyStartedToday))'))
    $baselineScript | Should -Match ([regex]::Escape('[switch]$ForceNewBackup'))
    $baselineScript | Should -Match ([regex]::Escape('$completedImage = Start-MacriumBackupAndWait -Automatic'))
  }

  It 'honors WhatIf without requiring an interactive confirmation callback' {
    $baselineScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1') -Raw -Encoding UTF8

    $baselineScript | Should -Match ([regex]::Escape('if ($WhatIfPreference)'))
    $baselineScript | Should -Not -Match ([regex]::Escape('$PSCmdlet.ShouldProcess'))
  }

  It 'reuses the mounted writable baseline for BCR and defers automatic workday replacement' {
    $baselineScript = (@('tools\Invoke-MacriumDailyBcrBaseline.ps1', 'tools\Invoke-MacriumMountWorker.ps1', 'modules\LcmMacriumAtoms.psm1') | ForEach-Object { Get-Content -LiteralPath (Join-Path $repositoryRoot $_) -Raw -Encoding UTF8 }) -join "`n" # CRP-343: worker moved to the mount atom, helpers to the shared module
    $morningScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-LCM_GoodMorning.ps1') -Raw -Encoding UTF8

    $baselineScript | Should -Match ([regex]::Escape('[switch]$NewBaseline'))
    $baselineScript | Should -Match ([regex]::Escape('function Find-MountedMacriumBaselineCandidates'))
    $baselineScript | Should -Match ([regex]::Escape('CandidateDrives'))
    $baselineScript | Should -Match ([regex]::Escape('ConvertTo-LcmCandidateDrives'))
    $baselineScript | Should -Match ([regex]::Escape('Normalize-LcmCandidateDrives'))
    $baselineScript | Should -Match ([regex]::Escape('VolumeName -ne $ExpectedVolumeLabel'))
    $baselineScript | Should -Match ([regex]::Escape('Reused writable $($mountedBaseline.MountedDrive) Macrium baseline'))
    $baselineScript | Should -Match ([regex]::Escape('function Get-LcmReviewWindows'))
    # CRP-346: the recorded own window is reused (matched by start time), else one legacy window with the _LCM tab
    $baselineScript | Should -Match ([regex]::Escape('function Find-LcmReusableReviewWindow'))
    $baselineScript | Should -Match ([regex]::Escape('Test-LcmSameProcessStart -Recorded $record.StartTime -Actual $window.StartTime'))
    $baselineScript | Should -Match ([regex]::Escape('function Invoke-LcmReviewWindowRefresh'))
    $baselineScript | Should -Match ([regex]::Escape('$reusedReviewWindow = $windowResult.Reused'))
    $baselineScript | Should -Match ([regex]::Escape('ReusedExistingReviewWindow = $reusedReviewWindow'))
    $baselineScript | Should -Match ([regex]::Escape('function Set-LcmReviewWindowTitle'))
    $baselineScript | Should -Match ([regex]::Escape('$baseTitle = $Window.MainWindowTitle -replace'))
    $baselineScript | Should -Match ([regex]::Escape('Set-LcmReviewWindowTitle -Window $existing -Scope $Scope'))
    $baselineScript | Should -Match ([regex]::Escape('Set-LcmReviewWindowTitle -Window $window -Scope $Scope'))
    $baselineScript | Should -Not -Match ([regex]::Escape('TemporaryReviewTitle'))
    $baselineScript | Should -Match ([regex]::Escape('$directoryHandlingNode = $session.SelectSingleNode(''./State/DirHandling'')'))
    $baselineScript | Should -Match ([regex]::Escape('$null -ne $directoryHandlingNode -and $directoryHandling -ne ''dirCompareFilesOnly'''))
    $reviewScript | Should -Match ([regex]::Escape('NewBaseline = $NewBaseline'))
    $reviewScript | Should -Match ([regex]::Escape('[switch]$LifecycleManaged'))
    $reviewScript | Should -Match ([regex]::Escape('Direct BCR review for $CRP requires lifecycle state ''verified'' or ''in_review'''))
    $reviewScript | Should -Match ([regex]::Escape('Move-LcmProposalLifecycleState -Id $proposal.id -State ''in_review'''))
    $reviewScript | Should -Match ([regex]::Escape('Macrium BCR review reused for $CRP.'))
    $reviewScript | Should -Match ([regex]::Escape('-Store $store -SkipPersist'))
    $reviewScript | Should -Match ([regex]::Escape("Set-ProposalStore -Store $store"))
    $reviewScript | Should -Match ([regex]::Escape('ReusedExistingReviewWindow = $baseline.ReusedExistingReviewWindow -eq $true'))
    $reviewScript | Should -Match ([regex]::Escape('$existingMetadata = if (Test-Path -LiteralPath $metadataPath)'))
    $reviewScript | Should -Match ([regex]::Escape('$baselineImage = if (-not [string]::IsNullOrWhiteSpace([string]$baseline.ImagePath))'))
    $morningScript | Should -Match ([regex]::Escape('$automaticMorning = $Auto -and -not $Force -and $gap -ge $GapHours'))
    $morningScript | Should -Match ([regex]::Escape('writable baseline is not replaced automatically during the workday'))
  }

  It 'confines the elevated mount to the atom dispatched by the admin tool (CRP-343)' {
    $bcr = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1') -Raw -Encoding UTF8
    $mount = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Mount-MacriumLatestBaseline.ps1') -Raw -Encoding UTF8
    $bcr | Should -Not -Match 'function Invoke-ElevatedBaselineWorker'
    $bcr | Should -Match ([regex]::Escape('$mountTool = Join-Path $PSScriptRoot ''Mount-MacriumLatestBaseline.ps1'''))
    $bcr | Should -Match ([regex]::Escape('Set-LcmMachineRegistry.ps1'))
    $mount | Should -Match ([regex]::Escape('Invoke-LcmDaemonCommand -Command $command -Sync -Elevated'))
    Test-Path -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumMountWorker.ps1') | Should -BeTrue
  }

  It 'routes lifecycle BCR actions to the canonical Macrium review wrapper' {
    $actionScript | Should -Match ([regex]::Escape("Invoke-MacriumBcrReview.ps1"))
    $actionScript | Should -Not -Match ([regex]::Escape("Invoke-BeyondCompareReview.ps1"))
  }

  It 'binds Macrium dialog and detach deadlines to MountTimeoutSeconds and expands Beyond Compare launch window detection (BUG-299)' {
    $baselineScript = (@('tools\Invoke-MacriumDailyBcrBaseline.ps1', 'tools\Invoke-MacriumMountWorker.ps1', 'modules\LcmMacriumAtoms.psm1') | ForEach-Object { Get-Content -LiteralPath (Join-Path $repositoryRoot $_) -Raw -Encoding UTF8 }) -join "`n" # CRP-343: worker moved to the mount atom, helpers to the shared module

    $baselineScript | Should -Not -Match 'did not become ready within 30 seconds'
    $baselineScript | Should -Not -Match 'did not detach \$\{letter\}: within 30 seconds'
    $baselineScript | Should -Match ([regex]::Escape('$deadline = (Get-Date).AddSeconds($MountTimeoutSeconds)'))
    $baselineScript | Should -Match ([regex]::Escape('candidateProcessIds'))
    $baselineScript | Should -Match ([regex]::Escape('$deadline = (Get-Date).AddSeconds(60)'))
  }

  It 'configures candidate drive list, inverted NewBaseline switch, and registry telemetry (BUG-307)' {
    $baselineScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1') -Raw -Encoding UTF8
    $bcrScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumBcrReview.ps1') -Raw -Encoding UTF8
    $pushScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-LCM_Push.ps1') -Raw -Encoding UTF8

    $baselineScript | Should -Match '\[object\]\$CandidateDrives = @\(''F'', ''G'', ''H'', ''I''\)'
    $baselineScript | Should -Match '\[switch\]\$NewBaseline'
    $baselineScript | Should -Match 'HKLM:\\SOFTWARE\\LCM\\MacriumBaseline'
    $baselineScript | Should -Match 'ActMTimeStamp'
    $baselineScript | Should -Match 'MRMTimeStamp'
    $baselineScript | Should -Match 'MRPushTimeStamp'
    $baselineScript | Should -Match 'FastPath = \$true'

    $bcrScript | Should -Match '\[switch\]\$NewBaseline'
    $bcrScript | Should -Match '\[object\]\$CandidateDrives = @\(''F'', ''G'', ''H'', ''I''\)'

    $pushScript | Should -Match 'HKLM:\\SOFTWARE\\LCM'
    $pushScript | Should -Match 'MRPushTimeStamp'
  }

  It 'records, logs, and surfaces the Macrium image filename and full path (CRP-328)' {
    $baselineScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1') -Raw -Encoding UTF8
    $bcrScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumBcrReview.ps1') -Raw -Encoding UTF8
    $morningScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-LCM_GoodMorning.ps1') -Raw -Encoding UTF8

    $baselineScript | Should -Match 'MRMImagePath'
    $baselineScript | Should -Match 'MRMImageLeaf'
    $baselineScript | Should -Match 'ImageFileName = \$resolvedImageLeaf'
    $baselineScript | Should -Match '\[BASELINE\] Reusing mounted Macrium baseline'
    $baselineScript | Should -Match '\[BASELINE\] Mounted Macrium baseline image'

    $bcrScript | Should -Match '\[BCR\] Macrium Baseline Image:'
    $bcrScript | Should -Match 'BaselineImageFileName ='

    $morningScript | Should -Match 'Baseline image file\s*:'
  }

  It 'decides baseline currency by evidence from the mounted image before the log-date heuristic (BUG-341, BUG-348 item 6)' {
    $baselineScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1') -Raw -Encoding UTF8

    $baselineScript | Should -Match ([regex]::Escape('Test-MountedBaselineCurrency -MountedBaseline $chosen'))
    $baselineScript | Should -Not -Match ([regex]::Escape("`$mountedImagePath = [string](Get-LcmRegistryValue -KeyPath `$MacriumRegistryKey -Name 'MRMImagePath')"))
    $identityIndex = $baselineScript.IndexOf('if ($null -ne $currency -and $currency.IsCurrent) {')
    $heuristicIndex = $baselineScript.IndexOf('} elseif ($null -ne $completedToday -and $null -ne $chosen.NewestLogDate) {')
    $identityIndex | Should -BeGreaterThan 0
    $heuristicIndex | Should -BeGreaterThan $identityIndex
  }

  It 'launches exactly one joint BCR for a declared cohort (BUG-341)' {
    $actionScript | Should -Match ([regex]::Escape('$isDeclaredCohort = -not [string]::IsNullOrWhiteSpace($resolution.DeclaredCohortId)'))
    $actionScript | Should -Match ([regex]::Escape('$launchReview = -not $cohortLaunchDone'))
    $actionScript | Should -Match ([regex]::Escape('if ($isDeclaredCohort -and $cohortLaunchDone) { $reviewArgs.NoLaunch = $true }'))
    $actionScript | Should -Not -Match ([regex]::Escape("-RepositoryName `$member.Repository -CRP `$member.Identity -BaseCommit `$BaseCommit -LifecycleManaged"))
  }
}
