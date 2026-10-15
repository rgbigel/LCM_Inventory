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

  It 'limits automatic baseline creation to one local calendar day and preserves an explicit override' {
    $baselineScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1') -Raw -Encoding UTF8

    $baselineScript | Should -Match ([regex]::Escape('macrium-automatic-backup-start.json'))
    $baselineScript | Should -Match ([regex]::Escape('Automatic baseline creation is limited to once per local calendar day'))
    $baselineScript | Should -Match ([regex]::Escape('if ($Automatic -and (Test-AutomaticBackupAlreadyStartedToday))'))
    $baselineScript | Should -Match ([regex]::Escape('[switch]$ForceNewBackup'))
    $baselineScript | Should -Match ([regex]::Escape('$completedImage = Start-MacriumBackupAndWait -Automatic'))
  }

  It 'reuses the mounted writable baseline for BCR and defers automatic workday replacement' {
    $baselineScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1') -Raw -Encoding UTF8
    $morningScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-WorkspaceGoodMorning.ps1') -Raw -Encoding UTF8

    $baselineScript | Should -Match ([regex]::Escape('[switch]$ReuseMountedBaseline'))
    $baselineScript | Should -Match ([regex]::Escape('function Find-MountedMacriumBaseline'))
    $baselineScript | Should -Match ([regex]::Escape("foreach (`$letter in @('F', 'G', 'H', 'I'))"))
    $baselineScript | Should -Match ([regex]::Escape('VolumeName -ne $ExpectedVolumeLabel'))
    $baselineScript | Should -Match ([regex]::Escape('Reused writable $($mountedBaseline.MountedDrive) Macrium baseline'))
    $reviewScript | Should -Match ([regex]::Escape('ReuseMountedBaseline = $true'))
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
