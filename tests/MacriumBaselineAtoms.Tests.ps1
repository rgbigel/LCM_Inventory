Describe 'Macrium baseline atomic tools' {
  BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $testTool = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Test-MacriumCurrentBaseline.ps1') -Raw -Encoding UTF8
    $dismountTool = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Dismount-MacriumCurrentBaseline.ps1') -Raw -Encoding UTF8
    $mountTool = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools\Mount-MacriumLatestBaseline.ps1') -Raw -Encoding UTF8
  }

  It 'keeps the current-baseline plausibility test read-only and evidence-focused' {
    $testTool | Should -Match ([regex]::Escape("@('F', 'G', 'H', 'I')"))
    $testTool | Should -Match ([regex]::Escape('SnapshotSavedAt'))
    $testTool | Should -Match ([regex]::Escape('GoodNightObserved'))
    $testTool | Should -Not -Match 'Reflect\.exe'
  }

  It 'requires confirmation for bounded baseline detachment' {
    $dismountTool | Should -Match ([regex]::Escape('[switch]$ConfirmDetach'))
    $dismountTool | Should -Match ([regex]::Escape("Detaching a writable Macrium baseline requires explicit -ConfirmDetach."))
    $dismountTool | Should -Match ([regex]::Escape('$detachExitCode = if (Test-Path variable:global:LASTEXITCODE)'))
    $dismountTool | Should -Match ([regex]::Escape("@('F', 'G', 'H', 'I')"))
  }

  It 'requires confirmation and delegates latest-image mounting to the canonical tool' {
    $mountTool | Should -Match ([regex]::Escape('[switch]$ConfirmMount'))
    $mountTool | Should -Match ([regex]::Escape("Mounting a writable Macrium baseline requires explicit -ConfirmMount."))
    $mountTool | Should -Match ([regex]::Escape('Invoke-MacriumDailyBcrBaseline.ps1'))
    $mountTool | Should -Match ([regex]::Escape('-WhatIf:$WhatIfPreference'))
  }
}
