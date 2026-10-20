Describe 'Control Hub rendered-artifact safety' {
  BeforeAll {
    $script:repositoryRoot = Split-Path $PSScriptRoot -Parent
    $script:templatePath = Join-Path $script:repositoryRoot 'assets\CM_CONTROL_HUB.html'
    $script:rendererPath = Join-Path $script:repositoryRoot 'tools\Show-LcmControl.ps1'
    $script:daemonPath = Join-Path $script:repositoryRoot 'tools\LcmDesktopDaemon.ps1'
    $script:proposalManagerPath = Join-Path $script:repositoryRoot 'modules\ProposalManager.psm1'
  }

  It 'disables daemon execution when the raw developer template is opened' {
    $template = Get-Content -LiteralPath $script:templatePath -Raw -Encoding UTF8

    $template | Should -Match 'Developer template detected'
    $template | Should -Match 'const IS_RENDERED_CONTROL_HUB = typeof RAW_PROPOSALS'
    $template | Should -Match 'Developer template is not executable; no daemon command was sent'
    $template | Should -Match '(?s)async function executeDaemonCommand.*?if \(!IS_RENDERED_CONTROL_HUB\).*?return;.*?fetch\(DAEMON_URL \+ "/execute"'
  }

  It 'records and automatically attempts one daemon recovery before local fallback' {
    $renderer = Get-Content -LiteralPath $script:rendererPath -Raw -Encoding UTF8

    $renderer | Should -Match '\[switch\]\$StartDaemon'
    $renderer | Should -Match 'function Write-LcmDaemonOutageIncident'
    $renderer | Should -Match "bug_id\s*=\s*'BUG-286'"
    $renderer | Should -Match 'recovery_state\s*=\s*\$RecoveryState'
    $renderer | Should -Match 'Write-LcmDaemonOutageIncident -DaemonPort \$daemonPort -RecoveryState ''detected'''
    $renderer | Should -Match 'action\s*=\s*''start-daemon-once'''
    $renderer | Should -Match 'for \(\$i = 0; \$i -lt 15; \$i\+\+\)'
    $renderer | Should -Match 'Launching local fallback; consult incident receipt'
  }

  It 'refreshes visible Hub lifecycle data from a daemon completion event' {
    $template = Get-Content -LiteralPath $script:templatePath -Raw -Encoding UTF8

    $template | Should -Match 'function connectHubRefreshEvents\(\)'
    $template | Should -Match 'new EventSource\(DAEMON_URL \+ "/hub-events"\)'
    $template | Should -Match 'hubRefreshEventSource\.addEventListener\("refresh", \(\) => \{\s*window\.location\.reload\(\);'
    $template | Should -Not -Match 'DAEMON_PROPOSAL_REFRESH_INTERVAL_MS'
    $template | Should -Not -Match 'window\.setInterval'
  }

  It 'publishes a daemon display refresh from lifecycle completion' {
    $daemon = Get-Content -LiteralPath $script:daemonPath -Raw -Encoding UTF8
    $proposalManager = Get-Content -LiteralPath $script:proposalManagerPath -Raw -Encoding UTF8

    $daemon | Should -Match 'class LcmControlHubRefreshBroker'
    $daemon | Should -Match "GET /hub-events"
    $daemon | Should -Match "POST /hub-refresh"
    $daemon | Should -Match 'Cache-Control"\] = "no-store, no-cache, must-revalidate"'
    $daemonActionController = Get-Content -LiteralPath (Join-Path $script:repositoryRoot 'modules\LcmDaemon\Classes\DaemonActionController.ps1') -Raw -Encoding UTF8
    $daemonActionController | Should -Match '\$wsh\.SendKeys\("\^\{F5\}"\)'
    $daemon | Should -Match '\[LcmControlHubRefreshBroker\]::Publish'
    $proposalManager | Should -Match 'function Update-LcmControlHubAfterCompletion'
    $proposalManager | Should -Match "Invoke-RestMethod -Uri 'http://127\.0\.0\.1:9876/hub-refresh'"
    $proposalManager | Should -Match 'if \(\$State -eq ''completed''\)'
    $proposalManager | Should -Match 'Update-LcmControlHubAfterCompletion -ProposalId \$Id'
    $proposalManager | Should -Match '\$completionBatch = \$mappedState -eq ''completed'' -and \$targetIds\.Count -gt 1'
    $proposalManager | Should -Match 'Set-ProposalStore -Store \$completionStore'
    $proposalManager | Should -Match 'Update-LcmControlHubAfterCompletion -ProposalId @\(\$updated'
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
    $template | Should -Match '\$\{crpTag\} Lifecycle Actions'
    $template | Should -Match 'lifecycleButton\("Do ITEM"'
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

    $actionsIndex = $template.IndexOf('<div class="show-dropdown-title">${crpTag} Lifecycle Actions</div>')
    $specificationIndex = $template.IndexOf('onclick="showProposalSpec(${p.id})"')
    $doIndex = $template.IndexOf('${lifecycleButton("Do ITEM"')
    $cohortIndex = $template.IndexOf('<div class="show-dropdown-title">Cohort Head / Member Management</div>')
    $documentsIndex = $template.IndexOf('<div class="show-dropdown-title">Documents (#${p.id})</div>')
    $switchesIndex = $template.IndexOf('id="workspaceSwitches"')

    $actionsIndex | Should -BeGreaterThan -1
    $specificationIndex | Should -BeGreaterThan $actionsIndex
    $doIndex | Should -BeGreaterThan $specificationIndex
    $cohortIndex | Should -BeGreaterThan $actionsIndex
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
    $template | Should -Match 'requestAnimationFrame\(\(\) => requestAnimationFrame\(\(\) => showDropdownById\(id\)\)\)'
    $template | Should -Match 'function formatDaemonSuccess'
    $template | Should -Match 'Review ready: \$\{driveSummary\}\$\{baseSummary\}; \$\{windowSummary\}\.'
    $template | Should -Match 'max-height: min\(65vh, 576px\)'
    $template | Should -Match '\.show-dropdown-menu\.open-upward'
    $template | Should -Match 'function positionDropdown\(menu\)'
    $template | Should -Match 'const spaceBelow = Math\.max\(0, window\.innerHeight - triggerBounds\.bottom - clearance\)'
    $template | Should -Match 'const openUpward = spaceAbove > spaceBelow'
    $template | Should -Match '\.show-dropdown-menu\.active \{ display: block; position: fixed; \}'
    $template | Should -Match 'const wizardInset = 32'
    $template | Should -Match 'table-layout: fixed'
    $template | Should -Match '<colgroup>'
    $template | Should -Match 'scrollbar-gutter: stable'
    $template | Should -Match 'id="rail-all"'
    $template | Should -Match 'function applyColumnFilters\(\)'
    $template | Should -Match 'activeRailFilter = "all"'
    $template | Should -Match 'function applyOpenWorkPresetSort\(preset\)'
    $template | Should -Match 'if \(preset !== "open"\) return;'
    $template | Should -Match 'activeSort = "prio-desc";'
    $template | Should -Match 'if \(prio === 0\) return false;'
    $template | Should -Match '\.proposal-table \{ width: 100%; table-layout: fixed;'
    $template | Should -Match 'const workspaceSwitchAtoms = Object\.freeze\('
    $template | Should -Match 'function invokeWorkspaceSwitchAtom\(atomName\)'
    $template | Should -Match 'function dispatchWorkspaceSwitch\('
    $template | Should -Match 'JSON\.stringify\(\{ command, sync: false, noExit: false \}\)'
    $template | Should -Match 'confirmed by the refreshed ledger'
    $template | Should -Match 'workspace-switch-button\.switch-pending'
    $template | Should -Match 'const confirmationDeadline = Date\.now\(\) \+ 15000'
    $template | Should -Match 'function getWorkspaceSwitchLedger\(\)'
    $template | Should -Match 'btnGlobalGranularity'
    $template | Should -Match 'btnGlobalAnalysis'
    $template | Should -Match 'btnGlobalDoit'
    $template | Should -Match 'btnGlobalMinimalTests'
    $template | Should -Match 'onclick="invokeWorkspaceSwitchAtom\(''lcm''\)"'
    $template | Should -Match 'onclick="invokeWorkspaceSwitchAtom\(''testing''\)"'
    $template | Should -Match 'onclick="invokeWorkspaceSwitchAtom\(''granularity''\)"'
    $template | Should -Match 'onclick="invokeWorkspaceSwitchAtom\(''analysis''\)"'
    $template | Should -Match 'onclick="invokeWorkspaceSwitchAtom\(''doit''\)"'
    $template | Should -Match 'onclick="invokeWorkspaceSwitchAtom\(''minimalTests''\)"'
    $template | Should -Match '-Action granularity -TargetExpression \$\{target\}'
    $template | Should -Match '-Action mode -Mode \$\{target\}'
    $template | Should -Match '-Action testing-mode -TestingMode \$\{target\}'
    $template | Should -Match '-Action doit-mode -SwitchState \$\{target \? "active" : "paused"\}'
    $template | Should -Match '-Action minimal-tests -SwitchState \$\{target \? "active" : "paused"\}'
    $template | Should -Match '\.control-row \{'
    $template | Should -Match 'min-height: 24px'
    $template | Should -Match '\.panel-heading > div:first-child'
    $template | Should -Match 'function getActiveSortLabel\(\)'
    $template | Should -Match '"prio-desc": "Priority high \\u2192 low"'
    $template | Should -Match 'getActiveSortLabel\(\)'
    $template | Should -Not -Match 'innerText = `\$\{workQueueCount\} result\$\{workQueueCount === 1 \? "" : "s"\} / CRP ID order`'
    $template | Should -Match 'Committed -\\nReady to Push'
    $template | Should -Match '\.plan-state-text \{ white-space: pre-line; \}'
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
    $template | Should -Match 'workspaceSwitchAtoms'
    $template | Should -Match 'invokeWorkspaceSwitchAtom\('
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

    $template | Should -Match 'function isLiveReviewCohort'
    $template | Should -Match '\["open", "held"\]\.includes'
    $template | Should -Match 'function getUnresolvedReviewObligations'
    $template | Should -Match 'function getReviewObligationEntries'
    $template | Should -Match 'return getReviewObligationEntries\(\)\.filter'
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

    $bug.state | Should -Be 'completed'
    $bug.status_note | Should -BeNullOrEmpty
    @($ledger.review_obligation_ledger.entries | Where-Object { $_.proposal_id -eq 276 -and $_.status -ne 'completed' }).Count | Should -Be 0
    $template = Get-Content -LiteralPath $script:templatePath -Raw -Encoding UTF8
    $template | Should -Match 'const obligationLedger = proposalsData\.review_obligation_ledger \|\| \{\};'
    $template | Should -Match 'Array\.isArray\(normalizedLedger\.entries\)'
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
