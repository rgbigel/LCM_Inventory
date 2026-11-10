<#
Module: InvokeLcmDisplayRender.Tests
Purpose: Verify worker completion reflects renderer failures and preserves audit output.
Path: tests/InvokeLcmDisplayRender.Tests.ps1
Authors: Rolf, Copilot
Version: 10.2.1
Date: 2026-10-21
#>
BeforeAll {
  $fixture = Join-Path $TestDrive 'worker'
  $null = New-Item -ItemType Directory -Path (Join-Path $fixture 'tools'), (Join-Path $fixture 'modules')
  $worker = Join-Path $fixture 'tools\Invoke-LcmDisplayRender.ps1'
  Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'tools\Invoke-LcmDisplayRender.ps1') -Destination $worker
  $renderer = Join-Path $fixture 'tools\renderer.ps1'
  @'
function Get-LcmDisplayDefinitions {
  param($WorkspaceRoot)
  @{ rules = @{ Renderer = Join-Path (Split-Path $PSScriptRoot -Parent) 'tools\renderer.ps1' } }
}
Export-ModuleMember -Function Get-LcmDisplayDefinitions
'@ | Set-Content -LiteralPath (Join-Path $fixture 'modules\LcmDisplayDependencies.psm1')
}

Describe 'Allowlisted renderer worker completion' {
  It 'prints help without dispatching a renderer or requiring operation arguments' {
    & pwsh -NoProfile -File $worker -h | Out-Null
    $LASTEXITCODE | Should -Be 0
    Test-Path -LiteralPath $renderer | Should -BeFalse
  }

  It 'records successful completion with tool version, status, log path and second-precision time' {
    'param([switch]$NoLaunch); Write-Output "Renderer evidence"' | Set-Content -LiteralPath $renderer
    $log = Join-Path $fixture 'success.log'
    & pwsh -NoProfile -File $worker -DisplayId rules -LogPath $log | Out-Null
    $LASTEXITCODE | Should -Be 0
    $text = Get-Content -LiteralPath $log -Raw
    $text | Should -Match 'Renderer evidence'
    $text | Should -Match '\[SUMMARY\] Invoke-LcmDisplayRender.ps1 v10.0.1 Status=COMPLETED Log=.+ Time=\d{4}-\d\d-\d\d \d\d:\d\d:\d\d'
  }

  It 'does not turn an explicit nonzero renderer exit into completed publication' {
    'param([switch]$NoLaunch); exit 7' | Set-Content -LiteralPath $renderer
    $log = Join-Path $fixture 'failure.log'
    & pwsh -NoProfile -File $worker -DisplayId rules -LogPath $log | Out-Null
    $LASTEXITCODE | Should -Be 1
    Get-Content -LiteralPath $log -Raw | Should -Match 'Status=FAILED'
    Get-Content -LiteralPath $log -Raw | Should -Match 'unsuccessful exit'
  }

  It 'stops before rendering when catalog synchronization exits unsuccessfully' {
    'param([switch]$Silent); exit 9' | Set-Content -LiteralPath (Join-Path $fixture 'tools\Update-ToolCatalog.ps1')
    $log = Join-Path $fixture 'catalog-failure.log'
    & pwsh -NoProfile -File $worker -DisplayId tools -LogPath $log | Out-Null
    $LASTEXITCODE | Should -Be 1
    Get-Content -LiteralPath $log -Raw | Should -Match 'Catalog synchronization failed'
    Get-Content -LiteralPath $log -Raw | Should -Match 'Status=FAILED'
  }
}
