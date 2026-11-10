<#
Module: ToolExplorerVersion.Tests
Purpose: Verify source-derived Tool Explorer version provenance.
Path: tests/ToolExplorerVersion.Tests.ps1
Authors: Rolf, Copilot
Version: 10.2.2
Date: 2026-11-09
#>
BeforeAll {
  $root = Split-Path $PSScriptRoot -Parent
  $fixture = Join-Path $TestDrive 'versions'
  $tools = Join-Path $fixture 'LCM_Inventory\tools'
  $modulePath = Join-Path $fixture 'LCM_Inventory\modules\ToolVersionFixture.psm1'
  $null = New-Item -ItemType Directory -Path $tools, (Split-Path $modulePath), (Join-Path $fixture 'LCM_Inventory\config') -Force
  $moduleText = [IO.File]::ReadAllText((Join-Path $root 'modules\LcmToolCatalog.psm1'))
  [IO.File]::WriteAllText($modulePath, ([regex]::Replace($moduleText, 'Version:\s*\d+\.\d+\.\d+', 'Version: 10.7.9', 1)))
  Copy-Item -LiteralPath (Join-Path $root 'modules\LcmDisplayVersion.psm1') -Destination (Split-Path $modulePath)
  Import-Module -Name $modulePath -Force
  Import-Module -Name (Join-Path $root 'modules\LcmDisplayDependencies.psm1') -Force
  $catalog = @([pscustomobject]@{
    Name='Example.ps1'; Audience='User'; Group='LCM'; Role='Test'; Domain='LCM'
    Category='Test'; Admin=$false; NoExit=$false
  })
}
AfterAll { Remove-Module ToolVersionFixture -ErrorAction SilentlyContinue }

Describe 'Tool Explorer source versions' {
  BeforeEach {
    [IO.File]::WriteAllText((Join-Path $tools 'Show-ToolsExplorer.ps1'), "<#`r`nVersion: v10.8.2`r`n#>`r`n")
  }

  It 'renders independent source versions in the badge title and JSON payload' {
    $path = Build-LcmToolIndexHtml -RawJson ($catalog | ConvertTo-Json -AsArray) -Catalog $catalog -WorkspaceRoot $fixture -ToolsDir $tools -Version v10.8.2
    $html = [IO.File]::ReadAllText($path)
    $html | Should -Match '<title>LCM Tool Explorer LCM-Show: v10.8.2 Template: v10.7.9</title>'
    $html | Should -Match 'vertical-align: middle;">LCM-Show: v10.8.2 Template: v10.7.9</span>'
    $html | Should -Match '"ToolVersion":"v10.8.2"'
    $html | Should -Match '"TemplateVersion":"v10.7.9"'
    $html | Should -Not -Match 'vv10'
  }

  It 'reads changed source metadata on the next render without a baseline change' {
    [IO.File]::WriteAllText((Join-Path $tools 'Show-ToolsExplorer.ps1'), "<#`r`nVersion: 10.8.3`r`n#>`r`n")
    $path = Build-LcmToolIndexHtml -RawJson '[]' -Catalog $catalog -WorkspaceRoot $fixture -ToolsDir $tools
    [IO.File]::ReadAllText($path) | Should -Match 'LCM-Show: v10.8.3 Template: v10.7.9'
  }

  It 'rejects stale explicit versions and missing source metadata' {
    { Build-LcmToolIndexHtml -RawJson '[]' -Catalog $catalog -WorkspaceRoot $fixture -ToolsDir $tools -Version 10.0.0 } | Should -Throw '*disagrees*'
    [IO.File]::WriteAllText((Join-Path $tools 'Show-ToolsExplorer.ps1'), '# No version')
    { Build-LcmToolIndexHtml -RawJson '[]' -Catalog $catalog -WorkspaceRoot $fixture -ToolsDir $tools } | Should -Throw '*Missing source metadata*'
  }

  It 'declares the constructing script and renderer as presentation dependencies' {
    $definitions = Get-LcmDisplayDefinitions -WorkspaceRoot $fixture
    $definitions.tools.Presentation | Should -Contain (Join-Path $tools 'Show-ToolsExplorer.ps1')
    $definitions.tools.Presentation | Should -Contain (Join-Path $fixture 'LCM_Inventory\modules\LcmToolCatalog.psm1')
  }
}
