<#
Module: LcmDisplayVersion.Tests
Purpose: Verify authoritative display provenance across all Standard Display renderers.
Path: tests/LcmDisplayVersion.Tests.ps1
Authors: Rolf, Copilot
Version: 10.2.2
Date: 2026-11-09
#>
BeforeAll {
  $root = Split-Path $PSScriptRoot -Parent
  Import-Module -Name (Join-Path $root 'modules\LcmDisplayVersion.psm1') -Force
}

Describe 'Standard Display version metadata' {
  It 'reads only a metadata comment and ignores document payload versions' {
    $path = Join-Path $TestDrive 'template.html'
    [IO.File]::WriteAllText($path, "<!--`r`nVersion: v10.2.3`r`n-->`r`n<script>Version: 99.9.9</script>")
    Get-LcmDisplaySourceVersion $path | Should -Be '10.2.3'
    [IO.File]::WriteAllText($path, '<html>Version: 99.9.9</html>')
    { Get-LcmDisplaySourceVersion $path } | Should -Throw '*metadata*'
  }

  It 'rejects missing malformed and duplicate versions instead of inventing a default' {
    foreach ($metadata in @('Version: nope', "Version: 10.0.1`r`nVersion: 10.0.2")) {
      $path = Join-Path $TestDrive 'bad.ps1'
      [IO.File]::WriteAllText($path, "<#`r`n$metadata`r`n#>")
      { Get-LcmDisplaySourceVersion $path } | Should -Throw '*semantic Version*'
    }
  }

  It 'resolves independently maintained script and template axes for every display' {
    $pairs = @(
      @('Show-ToolsExplorer.ps1','modules\LcmToolCatalog.psm1'),
      @('Show-LcmControl.ps1','assets\CM_CONTROL_HUB.html'),
      @('Show-LcmControl.ps1','assets\CM_CRP_DATES_READONLY.html'),
      @('Show-Rules.ps1','tools\Show-Rules.ps1'),
      @('Show-LCM_InventoryApp.ps1','assets\LCM_INVENTORY_VIEWER.html'),
      @('Show-FailureAnalysis.ps1','modules\FailureAnalysisHtml.psm1'),
      @('Show-LcmAnalysisViewer.ps1','tools\Show-LcmAnalysisViewer.ps1'),
      @('Show-LCM_Readiness.ps1','tools\Show-LCM_Readiness.ps1')
    )
    foreach ($pair in $pairs) {
      $provenance = Get-LcmDisplayProvenance -ScriptPath (Join-Path $root "tools\$($pair[0])") -TemplatePath (Join-Path $root $pair[1])
      $provenance.Label | Should -Match '^LCM-Show: v\d+\.\d+\.\d+ Template: v\d+\.\d+\.\d+$'
    }
  }

  It 'does not accept a version buried inside an HTML payload as template metadata' {
    $path = Join-Path $TestDrive 'payload.html'
    [IO.File]::WriteAllText($path, '<!-- No metadata --><script>{"docs":"Version: 10.0.0"}</script>')
    { Get-LcmDisplaySourceVersion $path } | Should -Throw '*metadata*'
  }

  It 'renders provenance in retained CON analysis without collecting new evidence' {
    $report = Join-Path $TestDrive 'analysis.json'
    $output = Join-Path $TestDrive 'analysis.html'
    [IO.File]::WriteAllText($report, '{"run_id":"version-fixture","elements":[{"repository":"Fixture","check1":"OK","check2":"","check3":"","check4":"","public_parameters":[],"refinement_status":"parameter-gate-documented"}]}')
    & (Join-Path $root 'tools\Show-LcmAnalysisViewer.ps1') -ReportPath $report -OutputPath $output -NoLaunch | Out-Null
    [IO.File]::ReadAllText($output) | Should -Match '<span>LCM-Show: v10.0.1 Template: v10.0.1</span>'
  }

  It 'renders readiness provenance without executing readiness tests' {
    $workspace = Join-Path $TestDrive 'readiness'
    $null = New-Item -ItemType Directory -Path (Join-Path $workspace 'LCM_AI\.git') -Force
    & (Join-Path $root 'tools\Show-LCM_Readiness.ps1') -WorkspaceRoot $workspace -Repository LCM_AI -Html -NoLaunch | Out-Null
    $output = Join-Path $workspace 'LCM_Inventory\data\artifacts\LCM_READINESS.html'
    [IO.File]::ReadAllText($output) | Should -Match '<span class="badge badge-info">LCM-Show: v10.0.1 Template: v10.0.1</span>'
  }
}
