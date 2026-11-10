<#
Module: LcmDisplayFreshness.Tests
Purpose: Verify dependency revisions, truthful publication and HTTP-only delivery.
Path: tests/LcmDisplayFreshness.Tests.ps1
Authors: Rolf, Copilot
Version: 10.2.1
Date: 2026-10-21
#>
BeforeAll {
  $root = Split-Path $PSScriptRoot -Parent
  Import-Module -Name (Join-Path $root 'modules\LcmDisplayDependencies.psm1') -Force
  Import-Module -Name (Join-Path $root 'modules\LcmDisplayCoordinator.psm1') -Force
  Import-Module -Name (Join-Path $root 'modules\LcmStandardDisplay.psm1') -Force
  Import-Module -Name (Join-Path $root 'modules\LcmDisplayHttp.psm1') -Force
  function New-TestDisplayResponse {
    $response = [pscustomobject]@{StatusCode=0; ContentType=''; Headers=[Collections.Specialized.NameValueCollection]::new(); ContentLength64=0; OutputStream=[IO.MemoryStream]::new()}
    $response | Add-Member -MemberType ScriptMethod -Name Close -Value {}
    $response
  }
}

Describe 'Standard Display dependencies' {
  It 'declares live displays without marking historical evidence as live' {
    $definitions = Get-LcmDisplayDefinitions
    @($definitions.Keys).Count | Should -Be 5
    $definitions.ContainsKey('failure-analysis') | Should -BeFalse
    $definitions.hub.Data | Should -Contain (Join-Path $root 'data\catalog\apps.json')
    $definitions.tools.Presentation | Should -Contain (Join-Path $root 'assets\lcm-display-freshness.js')
    $cachedDocument = Join-Path $root 'docs\Architecture.md'
    $definitions.inventory.Data | Should -Contain $cachedDocument
    $definitions.inventory.Source | Should -Contain $cachedDocument
  }

  It 'detects create edit rename and delete independently of file modification time' {
    $directory = Join-Path $TestDrive 'fingerprint'
    $null = New-Item -ItemType Directory $directory
    $pattern = Join-Path $directory '*.txt'
    $missing = Get-LcmDisplayFingerprint @($pattern)
    $file = Join-Path $directory 'one.txt'
    [IO.File]::WriteAllText($file, 'one')
    $created = Get-LcmDisplayFingerprint @($pattern)
    $time = (Get-Item $file).LastWriteTimeUtc
    [IO.File]::WriteAllText($file, 'two')
    (Get-Item $file).LastWriteTimeUtc = $time
    $edited = Get-LcmDisplayFingerprint @($pattern)
    Rename-Item $file 'two.txt'
    $renamed = Get-LcmDisplayFingerprint @($pattern)
    Remove-Item -LiteralPath (Join-Path $directory 'two.txt')
    $deleted = Get-LcmDisplayFingerprint @($pattern)
    @($missing,$created,$edited,$renamed | Sort-Object -Unique).Count | Should -Be 4
    $deleted | Should -Be $missing
  }

  It 'detects a new nested proposal document without requiring a flat document' {
    $directory = Join-Path $TestDrive 'recursive\docs\Proposals'
    $null = New-Item -ItemType Directory -Path (Join-Path $directory 'CRP-1') -Force
    $pattern = Join-Path $directory '*.md'
    $before = Get-LcmDisplayFingerprint @($pattern)
    [IO.File]::WriteAllText((Join-Path $directory 'CRP-1\Specification.md'), 'new evidence')
    Get-LcmDisplayFingerprint @($pattern) | Should -Not -Be $before
  }
}

Describe 'Publication operations' {
  BeforeAll {
    $workspace = Join-Path $TestDrive 'workspace'
    $inventory = Join-Path $workspace 'LCM_Inventory'
    $null = New-Item -ItemType Directory -Path (Join-Path $inventory 'tools') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $inventory 'data\artifacts') -Force
    $worker = Join-Path $inventory 'tools\Invoke-LcmDisplayRender.ps1'
    $artifact = Join-Path $inventory 'data\artifacts\SHOW_RULES.html'
    @'
param($DisplayId,$LogPath)
$root = Split-Path $PSScriptRoot -Parent
Start-Sleep -Milliseconds 100
[IO.File]::WriteAllText((Join-Path $root 'data\artifacts\SHOW_RULES.html'), '<html><body>revision one</body><script id="lcm-display-data" type="application/json">{}</script></html>')
'@ | Set-Content -LiteralPath $worker
  }

  It 'rejects unknown identities rather than dispatching arbitrary commands' {
    { Get-LcmDisplayState -DisplayId 'untrusted' -WorkspaceRoot $workspace } | Should -Throw '*Unknown standard display*'
  }

  It 'requires a complete structured JSON object before publication' {
    { Get-LcmDisplayPayload -Html '<html></html>' } | Should -Throw '*no structured*'
    { Get-LcmDisplayPayload -Html '<html><script id="lcm-display-data" type="application/json">{broken}</script></html>' } | Should -Throw
    { Get-LcmDisplayPayload -Html '<html><script id="lcm-display-data" type="application/json">[]</script></html>' } | Should -Throw '*JSON object*'
  }

  It 'returns Updating promptly and publishes only after successful process completion' {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $state = Update-LcmDisplayPublication -DisplayId rules -WorkspaceRoot $workspace
    $state.State | Should -Be 'Updating'
    $state.Bytes | Should -BeNullOrEmpty
    $clock.Elapsed.TotalSeconds | Should -BeLessThan 5
    $deadline = [datetime]::UtcNow.AddSeconds(15)
    do {
      Start-Sleep -Milliseconds 100
      $state = Update-LcmDisplayPublication -DisplayId rules -WorkspaceRoot $workspace
    } while ($state.State -eq 'Updating' -and [datetime]::UtcNow -lt $deadline)
    $state.State | Should -Be 'Current'
    [Text.Encoding]::UTF8.GetString($state.Bytes) | Should -Match 'revision one'
    $state.Revision | Should -Not -BeNullOrEmpty
    (Get-LcmDisplayStatus $state).operationId | Should -Match '^[a-f0-9]{32}$'
  }

  It 'retains last valid bytes after failed regeneration and reports Failed' {
    'param($DisplayId,$LogPath); exit 7' | Set-Content -LiteralPath $worker
    $state = Update-LcmDisplayPublication -DisplayId rules -Refresh -WorkspaceRoot $workspace
    $deadline = [datetime]::UtcNow.AddSeconds(15)
    do {
      Start-Sleep -Milliseconds 100
      $state = Update-LcmDisplayPublication -DisplayId rules -WorkspaceRoot $workspace
    } while ($state.State -eq 'Updating' -and [datetime]::UtcNow -lt $deadline)
    $state.State | Should -Be 'Failed'
    $state.Error | Should -Match 'code 7'
    [Text.Encoding]::UTF8.GetString($state.Bytes) | Should -Match 'revision one'
  }

  It 'does not publish invalid file URL content as a successful revision' {
    @'
param($DisplayId,$LogPath)
$root = Split-Path $PSScriptRoot -Parent
[IO.File]::WriteAllText((Join-Path $root 'data\artifacts\SHOW_RULES.html'), '<html><link href="file:///C:/bad.css"></html>')
'@ | Set-Content -LiteralPath $worker
    $state = Update-LcmDisplayPublication -DisplayId rules -Refresh -WorkspaceRoot $workspace
    $deadline = [datetime]::UtcNow.AddSeconds(15)
    do {
      Start-Sleep -Milliseconds 100
      $state = Update-LcmDisplayPublication -DisplayId rules -WorkspaceRoot $workspace
    } while ($state.State -eq 'Updating' -and [datetime]::UtcNow -lt $deadline)
    $state.State | Should -Be 'Failed'
    $state.Error | Should -Match 'file URLs'
    [Text.Encoding]::UTF8.GetString($state.Bytes) | Should -Match 'revision one'
  }

  It 'rejects an obsolete presentation result and coalesces a new render' {
    @'
param($DisplayId,$LogPath)
$root = Split-Path $PSScriptRoot -Parent
Start-Sleep -Milliseconds 800
[IO.File]::WriteAllText((Join-Path $root 'data\artifacts\SHOW_RULES.html'), '<html><body>revision two</body><script id="lcm-display-data" type="application/json">{}</script></html>')
'@ | Set-Content -LiteralPath $worker
    $state = Update-LcmDisplayPublication -DisplayId rules -Refresh -WorkspaceRoot $workspace
    $oldOperation = $state.OperationId
    $source = Join-Path $inventory 'tools\Show-Rules.ps1'
    [IO.File]::WriteAllText($source, '# new renderer presentation')
    $deadline = [datetime]::UtcNow.AddSeconds(15)
    do {
      Start-Sleep -Milliseconds 150
      $state = Update-LcmDisplayPublication -DisplayId rules -WorkspaceRoot $workspace
    } while ($state.OperationId -eq $oldOperation -and [datetime]::UtcNow -lt $deadline)
    $state.OperationId | Should -Not -Be $oldOperation
    $state.State | Should -Be 'Updating'
    [Text.Encoding]::UTF8.GetString($state.Bytes) | Should -Match 'revision one'
    do {
      Start-Sleep -Milliseconds 150
      $state = Update-LcmDisplayPublication -DisplayId rules -WorkspaceRoot $workspace
    } while ($state.State -eq 'Updating' -and [datetime]::UtcNow -lt $deadline)
    $state.State | Should -Be 'Current'
    [Text.Encoding]::UTF8.GetString($state.Bytes) | Should -Match 'revision two'
  }
}

Describe 'HTTP-only opening' {
  It 'rejects missing snapshot identity before making any network or launch request' {
    Mock Invoke-RestMethod { throw 'Network must not be reached' } -ModuleName LcmStandardDisplay
    $source = Get-Content -LiteralPath (Join-Path $root 'modules\LcmStandardDisplay.psm1') -Raw
    $source | Should -Match 'http://127.0.0.1:9876'
    $source | Should -Not -Match "AbsoluteUri|file://|Start-Process"
    { Open-LcmStandardDisplay -DisplayId failure-analysis } | Should -Throw '*snapshot ID is required*'
    Should -Invoke Invoke-RestMethod -ModuleName LcmStandardDisplay -Times 0 -Exactly
  }

  Describe 'Allowlisted Standard Display HTTP delivery' {
    BeforeAll {
      $httpRoot = Join-Path $TestDrive 'http'
      $assets = Join-Path $httpRoot 'LCM_Inventory\assets'
      $null = New-Item -Path $assets -ItemType Directory -Force
      [IO.File]::WriteAllText((Join-Path $assets 'StandardTableDisplay.css'), 'body { color: black; }')
      $snapshot = Join-Path $httpRoot 'LCM_Inventory\data\artifacts\snapshots\01234567890123456789012345678901'
      $null = New-Item -Path $snapshot -ItemType Directory -Force
      [IO.File]::WriteAllText((Join-Path $snapshot 'index.html'), '<html>Historical evidence</html>')
    }
    It 'serves CSS through 9876 with no-store headers' {
      $request = [pscustomobject]@{Url=[uri]'http://127.0.0.1:9876/assets/standard-table-display.css';HttpMethod='GET';LocalEndPoint=[pscustomobject]@{Port=9876}}
      $response = New-TestDisplayResponse
      (Invoke-LcmDisplayHttpRequest $request $response $httpRoot) | Should -BeTrue
      $response.StatusCode | Should -Be 200
      $response.ContentType | Should -Match 'text/css'
      $response.Headers['Cache-Control'] | Should -Match 'no-store'
    }
    It 'reports an absent retained snapshot as an explicit 404 without another delivery path' {
      $request = [pscustomobject]@{Url=[uri]'http://127.0.0.1:9876/snapshots/00000000000000000000000000000000/index.html';HttpMethod='GET';LocalEndPoint=[pscustomobject]@{Port=9876}}
      $response = New-TestDisplayResponse
      $null = Invoke-LcmDisplayHttpRequest $request $response $httpRoot -WarningAction SilentlyContinue
      $response.StatusCode | Should -Be 404
      $body = [Text.Encoding]::UTF8.GetString($response.OutputStream.ToArray()) | ConvertFrom-Json
      $body.error | Should -Not -BeNullOrEmpty
    }
    It 'serves only explicitly retained opaque snapshot IDs' {
      $request = [pscustomobject]@{Url=[uri]'http://127.0.0.1:9876/snapshots/01234567890123456789012345678901/index.html';HttpMethod='GET';LocalEndPoint=[pscustomobject]@{Port=9876}}
      $response = New-TestDisplayResponse
      $null = Invoke-LcmDisplayHttpRequest $request $response $httpRoot
      $response.StatusCode | Should -Be 200
      [Text.Encoding]::UTF8.GetString($response.OutputStream.ToArray()) | Should -Match 'Historical evidence'
    }
    It 'does not expose arbitrary assets or alternate ports' {
      $request = [pscustomobject]@{Url=[uri]'http://127.0.0.1:9876/assets/secrets.json';HttpMethod='GET';LocalEndPoint=[pscustomobject]@{Port=9876}}
      $response = New-TestDisplayResponse
      $null = Invoke-LcmDisplayHttpRequest $request $response $httpRoot -WarningAction SilentlyContinue
      $response.StatusCode | Should -Be 500
      $request.Url = [uri]'http://127.0.0.1:9999/assets/standard-table-display.css'
      $request.LocalEndPoint.Port = 9999
      $response = New-TestDisplayResponse
      $null = Invoke-LcmDisplayHttpRequest $request $response $httpRoot -WarningAction SilentlyContinue
      $response.StatusCode | Should -Be 500
    }
    It 'delivers decoupled JSON data with the exact published revision' {
      Mock Update-LcmDisplayPublication -ModuleName LcmDisplayHttp {
        @{State='Current';Revision='data.presentation';Bytes=[Text.Encoding]::UTF8.GetBytes('<html><script id="lcm-display-data" type="application/json">{"tools":[{"Name":"Example.ps1"}]}</script></html>')}
      }
      $request = [pscustomobject]@{Url=[uri]'http://127.0.0.1:9876/displays/data/tools';HttpMethod='GET';LocalEndPoint=[pscustomobject]@{Port=9876}}
      $response = New-TestDisplayResponse
      $null = Invoke-LcmDisplayHttpRequest $request $response $httpRoot
      $response.StatusCode | Should -Be 200
      $response.Headers['X-LCM-Display-Revision'] | Should -Be 'data.presentation'
      $payload = [Text.Encoding]::UTF8.GetString($response.OutputStream.ToArray()) | ConvertFrom-Json
      $payload.tools[0].Name | Should -Be 'Example.ps1'
    }
    It 'does not serve retained data as Current while a newer publication is Updating' {
      Mock Update-LcmDisplayPublication -ModuleName LcmDisplayHttp { @{State='Updating';Bytes=[byte[]]@(1)} }
      Mock Get-LcmDisplayStatus -ModuleName LcmDisplayHttp { @{state='Updating';revision='old.presentation'} }
      $request = [pscustomobject]@{Url=[uri]'http://127.0.0.1:9876/displays/data/tools';HttpMethod='GET';LocalEndPoint=[pscustomobject]@{Port=9876}}
      $response = New-TestDisplayResponse
      $null = Invoke-LcmDisplayHttpRequest $request $response $httpRoot
      $response.StatusCode | Should -Be 409
      $response.Headers['X-LCM-Display-Revision'] | Should -BeNullOrEmpty
    }
    It 'inserts presentation metadata into only the actual first head element' {
      Mock Update-LcmDisplayPublication -ModuleName LcmDisplayHttp {
        @{State='Current';Revision='d.p';PresentationRevision='p';Bytes=[Text.Encoding]::UTF8.GetBytes('<html><head></head><script id="lcm-display-data" type="application/json">{"document":"literal <head> example"}</script></html>')}
      }
      $request = [pscustomobject]@{Url=[uri]'http://127.0.0.1:9876/hub';HttpMethod='GET';LocalEndPoint=[pscustomobject]@{Port=9876}}
      $response = New-TestDisplayResponse
      $null = Invoke-LcmDisplayHttpRequest $request $response $httpRoot
      $response.StatusCode | Should -Be 200
      $html = [Text.Encoding]::UTF8.GetString($response.OutputStream.ToArray())
      ([regex]::Matches($html, 'name="lcm-presentation-revision"')).Count | Should -Be 1
      (Get-LcmDisplayPayload $html | ConvertFrom-Json).document | Should -Be 'literal <head> example'
    }
  }
}
