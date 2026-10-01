Describe 'BCompare review lifecycle contracts' {
  BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $reviewScriptPath = Join-Path $repositoryRoot 'tools\Invoke-BeyondCompareReview.ps1'
    $submitScriptPath = Join-Path $repositoryRoot 'tools\Submit-ReviewResult.ps1'
    $reviewScript = Get-Content -LiteralPath $reviewScriptPath -Raw -Encoding UTF8
    $submitScript = Get-Content -LiteralPath $submitScriptPath -Raw -Encoding UTF8
  }

  It 'parses both review lifecycle scripts' {
    foreach ($scriptPath in @($reviewScriptPath, $submitScriptPath)) {
      $tokens = $null
      $parseErrors = $null
      [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
      $parseErrors | Should -BeNullOrEmpty
    }
  }

  It 'normalizes single-line review directives to an array before Count checks' {
    $reviewScript | Should -Match '\$lines\s*=\s*@\(\$leftContent\.Trim\(\)\.Split\("`n"\)'
  }

  It 'leaves review materiality to Beyond Compare insignificant-difference rules' {
    $reviewScript | Should -Match ([regex]::Escape("& `$setAttr `$state 'InsigIgnored' 'True'"))
    $reviewScript | Should -Match ([regex]::Escape('Uncopied       = @()'))
    $reviewScript | Should -Not -Match ([regex]::Escape('Get-BCompareFileSha256'))
  }

  It 'uses one deterministic live-junction name per repository and CRP directory' {
    $reviewScript | Should -Match ([regex]::Escape('$liveJunctionStem = "Live_${repoName}"'))
    $reviewScript | Should -Match ([regex]::Escape('$_.Name -eq "Live_${repoName}"'))
    $reviewScript | Should -Not -Match ([regex]::Escape('"Live_${repoName}_*"'))
  }

  It 'opens the configured Beyond Compare named session without replaying command-line switches' {
    $reviewScript | Should -Match ([regex]::Escape('$bcArgString = "/solo `"$sessionName`""'))
    $reviewScript | Should -Match ([regex]::Escape("Start-Process -FilePath `$BeyondComparePath -ArgumentList @('/solo', `$sessionName)"))
    $reviewScript | Should -Not -Match ([regex]::Escape('/title1=`"$title1`" /title2=`"$title2`" /filters='))
  }

  It 'derives post-commit cleanup from BCR review metadata' {
    $submitScript | Should -Match ([regex]::Escape('".lcm_review.json"'))
    $submitScript | Should -Match ([regex]::Escape('$crpReviewDirToPurge = Join-Path $scratchBcReviewDir $meta.CRP'))
    $submitScript | Should -Match ([regex]::Escape('Where-Object { $_.LinkType -eq ''Junction'' }'))
    $submitScript | Should -Match ([regex]::Escape('[System.IO.Directory]::Delete($jn.FullName, $false)'))
    $submitScript | Should -Match ([regex]::Escape('Remove-Item -LiteralPath $crpReviewDirToPurge -Recurse -Force -ErrorAction SilentlyContinue'))
  }

  It 'keeps the baseline-directory fallback when CRP metadata is unavailable' {
    $submitScript | Should -Match ([regex]::Escape('elseif (Test-Path -LiteralPath $stagedManifest.TempReviewRoot)'))
  }

  It 'rejects completion without a current, matching BCompare staging manifest' {
    $submitScript | Should -Match ([regex]::Escape('No current review staging manifest exists'))
    $submitScript | Should -Match ([regex]::Escape('Review staging manifest does not match repository'))
    $submitScript | Should -Match ([regex]::Escape('Review staging manifest baseline does not match current HEAD'))
    $submitScript | Should -Match ([regex]::Escape('contains no approved actions'))
  }

  It 'creates receipts and purges scratch only after a real staged commit' {
    $submitScript | Should -Match ([regex]::Escape('git -C $targetRepoPath diff --cached --quiet'))
    $submitScript | Should -Match ([regex]::Escape('$commitCreated = $true'))
    $submitScript | Should -Match ([regex]::Escape('if ($commitCreated -and (Test-Path -LiteralPath $stagedManifestFile))'))
    $submitScript | Should -Match ([regex]::Escape('if ($commitCreated -and $stagedManifest -and $stagedManifest.TempReviewRoot)'))
  }
}