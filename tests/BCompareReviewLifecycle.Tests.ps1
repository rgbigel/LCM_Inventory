Describe 'BCompare review lifecycle contracts' {
  BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $reviewScriptPath = Join-Path $repositoryRoot 'tools\Invoke-BeyondCompareReview.ps1'
    $dispatcherScriptPath = Join-Path $repositoryRoot 'tools\Invoke-BcrDispatcher.ps1'
    $submitScriptPath = Join-Path $repositoryRoot 'tools\Submit-ReviewResult.ps1'
    $completeCohortScriptPath = Join-Path $repositoryRoot 'tools\Complete-ReviewCohort.ps1'
    $gateScriptPath = Join-Path $repositoryRoot 'tools\Test-ReviewCommitGate.ps1'
    $clearScriptPath = Join-Path $repositoryRoot 'tools\Clear-BCReviewSession.ps1'
    $reviewScript = Get-Content -LiteralPath $reviewScriptPath -Raw -Encoding UTF8
    $dispatcherScript = Get-Content -LiteralPath $dispatcherScriptPath -Raw -Encoding UTF8
    $submitScript = Get-Content -LiteralPath $submitScriptPath -Raw -Encoding UTF8
    $completeCohortScript = Get-Content -LiteralPath $completeCohortScriptPath -Raw -Encoding UTF8
    $gateScript = Get-Content -LiteralPath $gateScriptPath -Raw -Encoding UTF8
    $clearScript = Get-Content -LiteralPath $clearScriptPath -Raw -Encoding UTF8
  }

  It 'parses all review lifecycle scripts' {
    foreach ($scriptPath in @($reviewScriptPath, $dispatcherScriptPath, $submitScriptPath, $completeCohortScriptPath, $gateScriptPath, $clearScriptPath)) {
      $tokens = $null
      $parseErrors = $null
      [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
      $parseErrors | Should -BeNullOrEmpty
    }
  }

  It 'keeps BCR lifecycle-only without workspace review mode' {
    $reviewScript | Should -Not -Match '\[switch\]\$Workspace'
    $reviewScript | Should -Not -Match 'staged_workspace_review_'
    $reviewScript | Should -Not -Match 'WORKSPACE_\$repoName'
    $dispatcherScript | Should -Not -Match 'BCR workspace'
    $dispatcherScript | Should -Not -Match 'Workspace = \$true'
  }

  It 'normalizes single-line review directives to an array before Count checks' {
    $reviewScript | Should -Match '\$lines\s*=\s*@\(\$leftContent\.Trim\(\)\.Split\("`n"\)'
  }

  It 'leaves review materiality to Beyond Compare insignificant-difference rules' {
    $reviewScript | Should -Match ([regex]::Escape("& `$setAttr `$state 'InsigIgnored' 'True'"))
    $reviewScript | Should -Match ([regex]::Escape('Uncopied       = $uncopiedFiles'))
    $reviewScript | Should -Match ([regex]::Escape('Excluded       = $excludedFiles'))
    $reviewScript | Should -Match ([regex]::Escape('[EXCLUDED - NON-COMMITTABLE]'))
    $reviewScript | Should -Not -Match ([regex]::Escape('Get-BCompareFileSha256'))
  }

  It 'classifies standard transient paths as non-committable and stages only reviewed manifest paths' {
    $reviewScript | Should -Match 'function Test-StandardBcrExcludedPath'
    $reviewScript | Should -Match 'scratch\|logs\|work\|data'
    $submitScript | Should -Match 'function Test-StandardBcrExcludedPath'
    $submitScript | Should -Match ([regex]::Escape('git -C $targetRepoPath diff --cached --quiet'))
    $submitScript | Should -Match ([regex]::Escape('git -C $targetRepoPath add -- $completed.RelativePath'))
    $submitScript | Should -Match ([regex]::Escape('git -C $targetRepoPath add -- $relativePath'))
    $submitScript | Should -Not -Match ([regex]::Escape('git -C $targetRepoPath add -A'))
  }

  It 'discloses excluded paths separately and requires explicit inclusion for durable paths' {
    $completeCohortScript | Should -Match ([regex]::Escape('Excluded non-committable paths'))
    $completeCohortScript | Should -Match ([regex]::Escape('Test-StandardBcrExcludedPath -RelativePath $candidatePath'))
    $completeCohortScript | Should -Match ([regex]::Escape('-IncludeUnreviewed:$repositoryPlan.IncludeUnreviewed'))
    $submitScript | Should -Match ([regex]::Escape('Review staging manifest contains durable unreviewed paths. Re-run with -IncludeUnreviewed'))
    $submitScript | Should -Match ([regex]::Escape('Review manifest attempted to stage standard excluded path'))
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

  It 'creates a short-lived authorization bound to the reviewed staged diff' {
    $submitScript | Should -Match ([regex]::Escape('"pending_commit_${repoName}.json"'))
    $submitScript | Should -Match ([regex]::Escape('StagedDiffSha256    = Get-StagedDiffSha256 -Path $targetRepoPath'))
    $submitScript | Should -Match ([regex]::Escape('Remove-Item -LiteralPath $authorizationFile -Force -ErrorAction Stop'))
  }

  It 'blocks commits without a current authorization for the exact staged diff' {
    $gateScript | Should -Match ([regex]::Escape('REVIEW GATE BLOCKED: No current review authorization exists'))
    $gateScript | Should -Match ([regex]::Escape('The reviewed baseline no longer matches the current HEAD'))
    $gateScript | Should -Match ([regex]::Escape('The staged diff differs from the approved review selection'))
    $gateScript | Should -Match ([regex]::Escape('ExpiresAt'))
  }

  It 'invokes Clear-BCReviewSession post-commit to purge dynamic Beyond Compare sessions' {
    $submitScript | Should -Match ([regex]::Escape('Clear-BCReviewSession.ps1'))
    $submitScript | Should -Match ([regex]::Escape('& $cleanerScript -CRP $targetCRP -RepositoryName $repoName -WorkspaceRoot $workspaceRoot'))
    $submitScript | Should -Match ([regex]::Escape('[CLEANED] Removed dynamic BC session(s)'))
  }

  It 'Clear-BCReviewSession rejects invalid proposal identifiers' {
    { & $clearScriptPath -CRP 'INVALID-ID' } | Should -Throw
  }

  It 'Clear-BCReviewSession supports dry-run preview mode' {
    $res = & $clearScriptPath -CRP 'CRP-203' -DryRun
    $res | Should -Not -BeNullOrEmpty
    $res.DryRun | Should -BeTrue
    $res.CRP | Should -Be 'CRP-203'
  }
}