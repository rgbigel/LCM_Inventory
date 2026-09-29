Describe 'Repository index manager' {
  BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\RepositoryIndexManager.psm1'
    Import-Module -Name $modulePath -Force
    $workspace = Join-Path $TestDrive 'workspace'
    $repo = Join-Path $workspace 'ExampleRepo'
    $null = New-Item -ItemType Directory -Path (Join-Path $repo '.git') -Force
  }

  It 'discovers direct child repositories without writing metadata' {
    $result = @(Get-RepositoryIndex -WorkspaceRoot $workspace -MetadataPath (Join-Path $workspace 'missing.json'))

    $result.Count | Should -Be 1
    $result[0].Name | Should -Be 'ExampleRepo'
    $result[0].Metadata | Should -BeNullOrEmpty
  }

  It 'overlays metadata by repository name' {
    $metadataPath = Join-Path $workspace 'repositories.json'
    Set-Content -LiteralPath $metadataPath -Value '{"repositories":[{"name":"ExampleRepo","owner":"Rolf"}]}' -Encoding UTF8

    $result = @(Get-RepositoryIndex -WorkspaceRoot $workspace -MetadataPath $metadataPath)

    $result[0].Metadata.owner | Should -Be 'Rolf'
  }
}