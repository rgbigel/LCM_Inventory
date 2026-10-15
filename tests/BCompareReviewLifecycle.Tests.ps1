Describe 'BCompare review lifecycle contracts' {
  BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $reviewScriptPath = Join-Path $repositoryRoot 'tools\Invoke-BeyondCompareReview.ps1'
    $dispatcherScriptPath = Join-Path $repositoryRoot 'tools\Invoke-BcrDispatcher.ps1'
    $submitScriptPath = Join-Path $repositoryRoot 'tools\Submit-ReviewResult.ps1'
    $completeCohortScriptPath = Join-Path $repositoryRoot 'tools\Complete-ReviewCohort.ps1'
    $gateScriptPath = Join-Path $repositoryRoot 'tools\Test-ReviewCommitGate.ps1'
    $clearScriptPath = Join-Path $repositoryRoot 'tools\Clear-BCReviewSession.ps1'
    $clearTempScriptPath = Join-Path $repositoryRoot 'tools\Clear-BCReviewTemp.ps1'
    $reviewScript = Get-Content -LiteralPath $reviewScriptPath -Raw -Encoding UTF8
    $dispatcherScript = Get-Content -LiteralPath $dispatcherScriptPath -Raw -Encoding UTF8
    $submitScript = Get-Content -LiteralPath $submitScriptPath -Raw -Encoding UTF8
    $completeCohortScript = Get-Content -LiteralPath $completeCohortScriptPath -Raw -Encoding UTF8
    $gateScript = Get-Content -LiteralPath $gateScriptPath -Raw -Encoding UTF8
    $clearScript = Get-Content -LiteralPath $clearScriptPath -Raw -Encoding UTF8
    $clearTempScript = Get-Content -LiteralPath $clearTempScriptPath -Raw -Encoding UTF8
  }

  It 'parses all review lifecycle scripts' {
    foreach ($scriptPath in @($reviewScriptPath, $dispatcherScriptPath, $submitScriptPath, $completeCohortScriptPath, $gateScriptPath, $clearScriptPath, $clearTempScriptPath)) {
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

  It 'adds dirty canonical-rule authority to the affected repository review tabs' {
    $reviewScript | Should -Match ([regex]::Escape('$baselineDescriptor.RulesBaselineRepositoryPath'))
    $reviewScript | Should -Match ([regex]::Escape('$otherCandidates += (Split-Path -Leaf $rulesAuthorityPath)'))
    $reviewScript | Should -Match ([regex]::Escape('Opening additional tab for affected repository with physical changes'))
  }

  It 'registers durable cross-repository changes as lifecycle BCR obligations before launch' {
    $reviewScript | Should -Match ([regex]::Escape('function Register-DiscoveredCrossRepositoryReviewObligations'))
    $reviewScript | Should -Match ([regex]::Escape('Register-LcmCrossRepositoryReviewObligation -Id $proposal.id -Repository $candidate'))
    $reviewScript | Should -Match ([regex]::Escape('Register-DiscoveredCrossRepositoryReviewObligations -WorkspaceRoot $workspaceRoot'))
    $submitScript | Should -Match ([regex]::Escape('Complete-LcmCrossRepositoryReviewObligation -Id $matchingProposals[0].id'))
    $submitScript | Should -Match ([regex]::Escape('Primary proposal remains'))
    $submitScript | Should -Match ([regex]::Escape('no commit or lifecycle state was changed'))
  }

  It 'separates review acceptance from lifecycle completion in the Control Hub' {
    $controlHubPath = Join-Path $repositoryRoot 'assets\CM_CONTROL_HUB.html'
    $controlHub = Get-Content -LiteralPath $controlHubPath -Raw -Encoding UTF8

    $controlHub | Should -Match ([regex]::Escape('case "reviewed": {'))
    $controlHub | Should -Match ([regex]::Escape('case "complete":'))
    $controlHub | Should -Match ([regex]::Escape('Invoke-ProposalAction.ps1 -Action complete'))
    $controlHub | Should -Match ([regex]::Escape('await refreshHubData();'))
    $controlHub | Should -Match ([regex]::Escape('function formatDaemonError(rawError)'))
    $controlHub | Should -Match ([regex]::Escape('LIFECYCLE STATUS FAILURE REPORT'))
    $controlHub | Should -Match ([regex]::Escape('message = message.slice(reportStart);'))
  }

  It 'prioritizes a blocking synthetic 1 - REVIEW before its parent 2 - REVIEW' {
    $controlHubPath = Join-Path $repositoryRoot 'assets\CM_CONTROL_HUB.html'
    $controlHub = Get-Content -LiteralPath $controlHubPath -Raw -Encoding UTF8
    $actionScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-ProposalAction.ps1') -Raw -Encoding UTF8

    $controlHub | Should -Match ([regex]::Escape('function getBlockingReviewCohort(proposal)'))
    $controlHub | Should -Match ([regex]::Escape('1 - REVIEW / ${c.repositories[0]}'))
    $controlHub | Should -Match ([regex]::Escape('Continuation priority selected ${blockingCohort.id} — 1 - REVIEW'))
    $controlHub | Should -Match ([regex]::Escape('const effectiveAction = target.kind === "COH" && target.item.synthetic && ["do", "proceed"].includes(action)'))
    $controlHub | Should -Match ([regex]::Escape('Starting blocking 1 - REVIEW for ${targetLabel} before its parent 2 - REVIEW can complete.'))
    $actionScript | Should -Match ([regex]::Escape('Continuation priority: COH-$($proposal.id) — 1 - REVIEW'))
    $actionScript | Should -Match ([regex]::Escape('-ReviewObligationId $openObligation.id'))
  }

  It 'recreates the on-disk lifecycle BCR session metadata through the normal BCR action' {
    $reviewScript | Should -Match ([regex]::Escape('(Join-Path $tempReviewRoot ".lcm_review.json")'))
    $reviewScript | Should -Match ([regex]::Escape('(Join-Path $reviewStagingDir ".lcm_review.json")'))
    $reviewScript | Should -Match ([regex]::Escape("Lifecycle BCR session metadata was not materialized on disk"))
    $actionScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-ProposalAction.ps1') -Raw -Encoding UTF8
    $actionScript | Should -Match ([regex]::Escape('ReviewObligationId'))
    $actionScript | Should -Match ([regex]::Escape('Invoke-BeyondCompareReview.ps1'))
  }

  It 'isolates an artificial obligation BCR session from its primary review identity' {
    $reviewScript | Should -Match ([regex]::Escape("[string]`$ReviewIdentity = ''"))
    $reviewScript | Should -Match ([regex]::Escape('$reviewIdentity = if ([string]::IsNullOrWhiteSpace($ReviewIdentity)) { $CRP } else { $ReviewIdentity }'))
    $reviewScript | Should -Match ([regex]::Escape('$sessionName = "${reviewIdentity}_Review"'))
    $actionScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Invoke-ProposalAction.ps1') -Raw -Encoding UTF8
    $actionScript | Should -Match ([regex]::Escape('$isolatedReviewIdentity = "${identity}_$($obligation.repository)"'))
    $actionScript | Should -Match ([regex]::Escape('-ReviewIdentity $isolatedReviewIdentity'))
    $clearScript | Should -Match ([regex]::Escape('[string]$ReviewIdentity = '''))
    $clearScript | Should -Match ([regex]::Escape('$sessionName = "${cleanupIdentity}_Review"'))
    $clearScript | Should -Match ([regex]::Escape('TDirCompareSession[@Value=''$sessionName'']'))
  }

  It 'classifies standard transient paths as non-committable and stages only reviewed manifest paths' {
    $reviewScript | Should -Match 'function Test-StandardBcrExcludedPath'
    $reviewScript | Should -Match 'scratch\|logs\|work\|data'
    $submitScript | Should -Match 'function Test-StandardBcrExcludedPath'
    $submitScript | Should -Match ([regex]::Escape('git -C $targetRepoPath diff --cached --quiet'))
    $submitScript | Should -Match ([regex]::Escape('git -C $targetRepoPath add -- $completed.RelativePath'))
    $submitScript | Should -Match ([regex]::Escape('git -C $targetRepoPath add -f -- $relativePath'))
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
    $reviewScript | Should -Match ([regex]::Escape('command = "& `"$BeyondComparePath`" /solo `"$otherSession`""'))
    $reviewScript | Should -Match ([regex]::Escape('-ArgumentList "/solo `"$otherSession`""'))
    $reviewScript | Should -Match ([regex]::Escape("Start-Process -FilePath `$BeyondComparePath -ArgumentList @('/solo', `$otherSession)"))
    $reviewScript | Should -Not -Match ([regex]::Escape('/title1=`"$title1`" /title2=`"$title2`" /filters='))
  }

  It 'derives post-commit cleanup from BCR review metadata' {
    $submitScript | Should -Match ([regex]::Escape('".lcm_review.json"'))
    $submitScript | Should -Match ([regex]::Escape('$reviewIdentity = if (-not [string]::IsNullOrWhiteSpace($meta.ReviewIdentity)) { $meta.ReviewIdentity } else { $meta.CRP }'))
    $submitScript | Should -Match ([regex]::Escape('$crpReviewDirToPurge = Join-Path $scratchBcReviewDir $reviewIdentity'))
    $submitScript | Should -Match ([regex]::Escape('Where-Object { $_.LinkType -eq ''Junction'' }'))
    $submitScript | Should -Match ([regex]::Escape('[System.IO.Directory]::Delete($jn.FullName, $false)'))
    $submitScript | Should -Match ([regex]::Escape('Remove-Item -LiteralPath $crpReviewDirToPurge -Recurse -Force -ErrorAction SilentlyContinue'))
  }

  It 'preserves active named sessions and their exact isolated scratch bridges' {
    $clearScript | Should -Match ([regex]::Escape('if ($bcRunning)'))
    $clearScript | Should -Match ([regex]::Escape('Preserving exact review identity ''$cleanupIdentity'''))
    $submitScript | Should -Match ([regex]::Escape('Do not remove session definitions or scratch bridges while BCompare owns them.'))
    $submitScript | Should -Match ([regex]::Escape('if (-not $bcRunning -and (Test-Path -LiteralPath $cleanerScript))'))
    $clearTempScript | Should -Match ([regex]::Escape('if ($bcRunning)'))
    $clearTempScript | Should -Match ([regex]::Escape('No review directories or staging manifests were removed'))
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
    $submitScript | Should -Match ([regex]::Escape('& $cleanerScript -CRP $targetCRP -ReviewIdentity $targetReviewIdentity -RepositoryName $repoName -WorkspaceRoot $workspaceRoot'))
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