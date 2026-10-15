Describe 'Control Hub rendered-artifact safety' {
  BeforeAll {
    $script:repositoryRoot = Split-Path $PSScriptRoot -Parent
    $script:templatePath = Join-Path $script:repositoryRoot 'assets\CM_CONTROL_HUB.html'
    $script:rendererPath = Join-Path $script:repositoryRoot 'tools\Show-LcmControl.ps1'
    $script:daemonPath = Join-Path $script:repositoryRoot 'tools\LcmDesktopDaemon.ps1'
  }

  It 'disables daemon execution when the raw developer template is opened' {
    $template = Get-Content -LiteralPath $script:templatePath -Raw -Encoding UTF8

    $template | Should -Match 'Developer template detected'
    $template | Should -Match 'const IS_RENDERED_CONTROL_HUB = typeof RAW_PROPOSALS'
    $template | Should -Match 'Developer template is not executable; no daemon command was sent'
    $template | Should -Match '(?s)async function executeDaemonCommand.*?if \(!IS_RENDERED_CONTROL_HUB\).*?return;.*?fetch\(DAEMON_URL \+ "/execute"'
  }

  It 'requires an explicit request before reviving the desktop daemon' {
    $renderer = Get-Content -LiteralPath $script:rendererPath -Raw -Encoding UTF8

    $renderer | Should -Match '\[switch\]\$StartDaemon'
    $renderer | Should -Match 'if \(-not \$daemonOnline -and \$StartDaemon\)'
    $renderer | Should -Match 'Not starting a background session; opening local artifact fallback'
    $renderer | Should -Not -Match 'if \(-not \$daemonOnline\) \{\s*\$daemonScript'
  }

  It 'validates stale CRP and COH targets before command construction' {
    $template = Get-Content -LiteralPath $script:templatePath -Raw -Encoding UTF8

    $template | Should -Match 'function validateCurrentProposalTargets'
    $template | Should -Match 'function validateCurrentCohortTarget'
    $template | Should -Match 'function reconcileActiveItemTarget'
    $template | Should -Match 'if \(!validateCurrentProposalTargets\(ids\)\) return;'
    $template | Should -Match 'if \(!validateCurrentCohortTarget\(cohortId\)\) return;'
  }

  It 'routes row wizard lifecycle actions through the explicit active ITEM target' {
    $template = Get-Content -LiteralPath $script:templatePath -Raw -Encoding UTF8

    $template | Should -Match 'function getTargetActionLabel'
    $template | Should -Match 'id="itemActionSelect"'
    $template | Should -Match 'function dispatchSelectedItemMenuAction'
    $template | Should -Match 'container\.innerHTML = getSelectedItemLifecycleMarkup\(target\.item\);'
    $template | Should -Match 'container\.innerHTML = status;'
    $template | Should -Match 'ITEM explicitly switched from'
    $template | Should -Match 'ACTIONS: ITEM \$\{crpTag\}'
    $template | Should -Match 'Do ITEM</button>'
    $template | Should -Not -Match 'Do ITEM \(Doit\)'
    $template | Should -Match 'dispatchTargetAction\(''do''\)'
    $template | Should -Match 'dispatchTargetAction\(''proceed''\)'
    $template | Should -Match 'dispatchTargetAction\(''bcr''\)'
    $template | Should -Match 'COH ITEM to act on its full membership'
    $template | Should -Not -Match 'onclick="dispatchStandardAction\(''do'', \[\$\{p\.id\}\], ''''\)"'
    $template | Should -Not -Match 'onclick="dispatchStandardAction\(''proceed'', \[\$\{p\.id\}\], ''''\)"'
  }

  It 'orders row action groups and keeps proposal documents discoverable' {
    $template = Get-Content -LiteralPath $script:templatePath -Raw -Encoding UTF8
    $renderer = Get-Content -LiteralPath $script:rendererPath -Raw -Encoding UTF8

    $lifecycleIndex = $template.IndexOf('<div class="show-dropdown-title">Lifecycle</div>')
    $cohortIndex = $template.IndexOf('<div class="show-dropdown-title">Cohort Head / Member Management</div>')
    $documentsIndex = $template.IndexOf('<div class="show-dropdown-title">Documents (#${p.id})</div>')
    $switchesIndex = $template.IndexOf('id="workspaceSwitches"')

    $lifecycleIndex | Should -BeGreaterThan -1
    $cohortIndex | Should -BeGreaterThan $lifecycleIndex
    $documentsIndex | Should -BeGreaterThan $cohortIndex
    $switchesIndex | Should -BeGreaterThan -1
    $template | Should -Not -Match '<div class="show-dropdown-title">Flow Switches</div>'
    $template | Should -Match 'openOriginalProposalInEditor\(\$\{p\.id\}\)'
    $template | Should -Match 'function showReviewReceipt'
    $template | Should -Match 'function getOriginalProposalDocumentKey'
    $template | Should -Match 'function renderMermaidPreviews'
    $template | Should -Match 'openTargetActionModal\(''reinstate''\)'
    $template | Should -Match 'id="targetActionChanges"'
    $template | Should -Match '-Action reinstate -TargetExpression'
    $template | Should -Match '-Changes "\$\{safeChanges\}"'
    $renderer | Should -Match 'RAW_REVIEW_RECEIPTS'
    $renderer | Should -Match 'LCM_Inventory\\data\\reviews'
  }

  It 'renders colored workspace switches beside Work Queue instead of in item actions' {
    $template = Get-Content -LiteralPath $script:templatePath -Raw -Encoding UTF8

    $template | Should -Match 'id="workspaceSwitches"'
    $template | Should -Match 'workspace-switch-label">Workspace'
    $template | Should -Match 'id="btnGlobalLcm"'
    $template | Should -Match 'id="btnGlobalTesting"'
    $template | Should -Match 'id="btnGlobalGranularity"'
    $template | Should -Match 'id="btnGlobalAnalysis"'
    $template | Should -Match 'id="btnGlobalDoit"'
    $template | Should -Match 'id="btnGlobalMinimalTests"'
    $template | Should -Match 'function toggleGlobalDoit'
    $template | Should -Match 'function toggleGlobalMinimalTests'
    $template | Should -Match 'renderTable\(\);\s*updateInternalSwitchesDisplay\(null\);'
    $template | Should -Match 'workspace-switch-button \$\{isLcmOn \? "switch-on" : "switch-off"\}'
    $template | Should -Not -Match 'workspace-switch-label">Selected ITEM'
    $template | Should -Not -Match 'btnItemDoit'
    $template | Should -Not -Match 'btnItemMinimalTests'
    $template | Should -Not -Match 'toggleActiveProposalDoit'
    $template | Should -Not -Match 'toggleActiveProposalMinimalTests'
    $template | Should -Not -Match '<div class="show-dropdown-title">Flow Switches</div>'
  }

  It 'renders unresolved cross-repository BCR obligations as normal filtered cohorts beside their head' {
    $template = Get-Content -LiteralPath $script:templatePath -Raw -Encoding UTF8

    $template | Should -Match 'function getUnresolvedReviewObligations'
    $template | Should -Match 'function getObligationWorkQueueCohorts'
    $template | Should -Match 'filter\(obligation => String\(obligation\.status \|\| "open"\)\.toLowerCase\(\) !== "completed"\)'
    $template | Should -Match 'id: `COH-\$\{proposal\.id\}`'
    $template | Should -Match 'head_identity: proposal\.crp_id'
    $template | Should -Match 'function getProposalDisplayTitle'
    $template | Should -Match 'replace\(/\^\\s\*\\\[BUG\\\]\\s\*/i, ""\)'
    $template | Should -Match 'getProposalWorkQueueCohorts\(p\.id\)'
    $template | Should -Match 'getWorkQueueCohorts\(\)\.sort'
    $template | Should -Match 'ReviewObligationId'
    $template | Should -Match 'function getProposalWorkQueueCohorts'
    $template | Should -Match 'proposal-title">\$\{esc\(cohort\.repositories\[0\]\)\}'
    $template | Should -Match 'container\.innerHTML = proposalRows;'
    $template | Should -Match 'state-badge state-review">REVIEW'
    $template | Should -Match '>1 - REVIEW</span>'
    $template | Should -Not -Match 'Review pending —'
    $template | Should -Not -Match 'role = cohort\.synthetic \? "OBLIGATION"'
    $template | Should -Not -Match 'function openExactRepositoryBcr'
  }

  It 'clears the BUG-276 obligation warning after the LCM_AI review resolves' {
    $ledgerPath = Join-Path $script:repositoryRoot 'data\proposals\proposals.json'
    $ledger = Get-Content -LiteralPath $ledgerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $bug = @($ledger.proposals | Where-Object { $_.id -eq 276 })[0]

    $bug.state | Should -Be 'in_review'
    $bug.status_note | Should -BeNullOrEmpty
    @($ledger.review_obligation_ledger.entries | Where-Object { $_.proposal_id -eq 276 -and $_.status -ne 'completed' }).Count | Should -Be 0
  }

  It 'renders a token-free artifact and never serves the source template as the Hub' {
    & $script:rendererPath -NoLaunch
    $artifactPath = Join-Path $script:repositoryRoot 'data\artifacts\CM_CONTROL_HUB.html'
    $artifact = Get-Content -LiteralPath $artifactPath -Raw -Encoding UTF8
    $daemon = Get-Content -LiteralPath $script:daemonPath -Raw -Encoding UTF8

    $artifact | Should -Not -Match '\{\{[^}]+\}\}'
    $artifact | Should -Match 'const RAW_PROPOSALS ='
    $daemon | Should -Not -Match "LCM_Inventory\\assets\\CM_CONTROL_HUB\.html"
    $daemon | Should -Match 'generated Control Hub artifact is unavailable'
  }
}
