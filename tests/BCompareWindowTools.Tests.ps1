Describe 'BCompare window tools' {
  BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\BCompareWindowTools.psm1'
    Import-Module -Name $modulePath -Force
    $processes = @(
      [pscustomobject]@{ Id = 1; MainWindowTitle = 'Workspace_Inventory v8 <--> Live Workspace_Inventory' },
      [pscustomobject]@{ Id = 2; MainWindowTitle = 'Workspace_AI v8 <--> Live Workspace_AI' },
      [pscustomobject]@{ Id = 3; MainWindowTitle = 'Workspace_Inventory Text Compare' }
    )
  }

  It 'selects only repository-specific folder comparison windows' {
    $result = @(Get-SameRepositoryBCompareProcess -RepositoryName 'Workspace_Inventory' -Process $processes)

    $result.Count | Should -Be 1
    $result[0].Id | Should -Be 1
  }

  It 'is idempotent when no stale windows match' {
    $result = @(Get-SameRepositoryBCompareProcess -RepositoryName 'MissingRepository' -Process $processes)

    $result.Count | Should -Be 0
  }

  It 'accepts an empty process collection' {
    $result = @(Get-SameRepositoryBCompareProcess -RepositoryName 'Workspace_Inventory' -Process @())

    $result.Count | Should -Be 0
  }
}