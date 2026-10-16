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
    $baselineScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1') -Raw -Encoding UTF8

    $baselineScript | Should -Match ([regex]::Escape('$detachExitCode = if (Test-Path variable:global:LASTEXITCODE)'))
    $baselineScript | Should -Not -Match 'if \(\$LASTEXITCODE -ne 0\)'
  }

  It 'records detach, reappearance, and snapshot corroboration as mount evidence' {
    $baselineScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1') -Raw -Encoding UTF8

    $baselineScript | Should -Match ([regex]::Escape('[int]$MountTimeoutSeconds = 120'))
    $baselineScript | Should -Match ([regex]::Escape('$detachedDrives.Add("$letter`:")'))
    $baselineScript | Should -Match ([regex]::Escape('Get-MountedBaselineEvidence -MountedBaseline $mountedBaseline -DetachedDrives @($detachedDrives)'))
    $baselineScript | Should -Match ([regex]::Escape('GoodNightObserved'))
    $baselineScript | Should -Match ([regex]::Escape('SnapshotSavedAt'))
    $baselineScript | Should -Match ([regex]::Escape('MountEvidence = $mountEvidence'))
  }

  It 'opens the completed image directly in Macrium browse mode' {
    $baselineScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1') -Raw -Encoding UTF8

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
    $baselineScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1') -Raw -Encoding UTF8
    $morningScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-WorkspaceGoodMorning.ps1') -Raw -Encoding UTF8

    $baselineScript | Should -Match ([regex]::Escape('[switch]$ReuseMountedBaseline'))
    $baselineScript | Should -Match ([regex]::Escape('function Find-MountedMacriumBaseline'))
    $baselineScript | Should -Match ([regex]::Escape("foreach (`$letter in @('F', 'G', 'H', 'I'))"))
    $baselineScript | Should -Match ([regex]::Escape('VolumeName -ne $ExpectedVolumeLabel'))
    $baselineScript | Should -Match ([regex]::Escape('Reused writable $($mountedBaseline.MountedDrive) Macrium baseline'))
    $baselineScript | Should -Match ([regex]::Escape('function Get-LcmReviewWindows'))
    $baselineScript | Should -Match ([regex]::Escape('Multiple _LCM Folder Compare windows are open'))
    $baselineScript | Should -Match ([regex]::Escape('$reusedReviewWindow = $true'))
    $baselineScript | Should -Match ([regex]::Escape('ReusedExistingReviewWindow = $reusedReviewWindow'))
    $baselineScript | Should -Match ([regex]::Escape('$directoryHandlingNode = $session.SelectSingleNode(''./State/DirHandling'')'))
    $baselineScript | Should -Match ([regex]::Escape('$null -ne $directoryHandlingNode -and $directoryHandling -ne ''dirCompareFilesOnly'''))
    $reviewScript | Should -Match ([regex]::Escape('ReuseMountedBaseline = $true'))
    $reviewScript | Should -Match ([regex]::Escape('[switch]$LifecycleManaged'))
    $reviewScript | Should -Match ([regex]::Escape('Direct BCR review for $CRP requires lifecycle state ''verified'' or ''in_review'''))
    $reviewScript | Should -Match ([regex]::Escape('Move-LcmProposalLifecycleState -Id $proposal.id -State ''in_review'''))
    $reviewScript | Should -Match ([regex]::Escape('ReusedExistingReviewWindow = $baseline.ReusedExistingReviewWindow -eq $true'))
    $reviewScript | Should -Match ([regex]::Escape('$existingMetadata = if (Test-Path -LiteralPath $metadataPath)'))
    $reviewScript | Should -Match ([regex]::Escape('$baselineImage = if (-not [string]::IsNullOrWhiteSpace([string]$baseline.ImagePath))'))
    $morningScript | Should -Match ([regex]::Escape('$automaticMorning = $Auto -and -not $Force -and $gap -ge $GapHours'))
    $morningScript | Should -Match ([regex]::Escape('writable baseline is not replaced automatically during the workday'))
  }

  It 'routes lifecycle BCR actions to the canonical Macrium review wrapper' {
    $actionScript | Should -Match ([regex]::Escape("Invoke-MacriumBcrReview.ps1"))
    $actionScript | Should -Not -Match ([regex]::Escape("Invoke-BeyondCompareReview.ps1"))
  }
}
