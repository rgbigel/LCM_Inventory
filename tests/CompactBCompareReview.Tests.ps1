Describe 'Compact BCompare review projection' {
  BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\CompactBCompareReview.psm1'
    Import-Module -Name $modulePath -Force
  }

  It 'returns normalized repository-relative manifest paths' {
    $manifest = Join-Path $TestDrive 'include.json'
    Set-Content -LiteralPath $manifest -Value '{"include":["tools/example.ps1","docs/readme.md"]}' -Encoding UTF8

    $result = @(Get-CompactBCompareInclusion -InclusionManifest $manifest)

    $result | Should -Be @('tools\example.ps1', 'docs\readme.md')
  }

  It 'rejects rooted and parent-traversal paths' {
    $manifest = Join-Path $TestDrive 'invalid.json'
    Set-Content -LiteralPath $manifest -Value '{"include":["..\\outside.ps1"]}' -Encoding UTF8

    { Get-CompactBCompareInclusion -InclusionManifest $manifest } | Should -Throw
  }

  It 'preserves repository-relative hierarchy in scratch-only baseline and working roots' {
    $repository = Join-Path $TestDrive 'ExampleRepo'
    $sourceFile = Join-Path $repository 'tools\example.ps1'
    $manifest = Join-Path $TestDrive 'tree-include.json'
    $scratch = Join-Path $TestDrive 'scratch'
    $null = New-Item -ItemType Directory -Path (Split-Path $sourceFile -Parent) -Force
    Set-Content -LiteralPath $sourceFile -Value 'baseline content' -Encoding UTF8
    & git -C $repository init --quiet
    & git -C $repository add tools/example.ps1
    & git -C $repository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'baseline'
    Set-Content -LiteralPath $sourceFile -Value 'working content' -Encoding UTF8
    Set-Content -LiteralPath $manifest -Value '{"include":["tools/example.ps1"]}' -Encoding UTF8

    $result = New-CompactBCompareReviewTree -RepositoryPath $repository -BaseCommit 'HEAD' -InclusionManifest $manifest -ScratchRoot $scratch

    (Get-Content -LiteralPath (Join-Path $result.BaselinePath 'tools\example.ps1') -Raw).Trim() | Should -Be 'baseline content'
    (Get-Content -LiteralPath (Join-Path $result.WorkingPath 'tools\example.ps1') -Raw).Trim() | Should -Be 'working content'
    (Get-Content -LiteralPath $sourceFile -Raw).Trim() | Should -Be 'working content'
  }
}