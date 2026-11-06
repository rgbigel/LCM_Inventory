<#
Module: LcmStandardDisplay.Tests
Purpose: Verify HTTP launch arguments, daemon readiness and explicit failure behavior.
Path: tests/LcmStandardDisplay.Tests.ps1
Authors: Rolf, Copilot
Version: 10.0.1
Date: 2026-10-21
#>
BeforeAll {
  $fixture = Join-Path $TestDrive 'display-opener'
  $null = New-Item -ItemType Directory -Path (Join-Path $fixture 'modules'), (Join-Path $fixture 'tools')
  $source = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\LcmStandardDisplay.psm1'
  $module = Join-Path $fixture 'modules\LcmStandardDisplayFixture.psm1'
  Copy-Item -LiteralPath $source -Destination $module
  @'
param([switch]$Background,[int]$Port)
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'daemon-started.txt'), "$Port")
'@ | Set-Content -LiteralPath (Join-Path $fixture 'tools\LcmDesktopDaemon.ps1')
  @'
param($FilePath,$ArgumentList)
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'opened.txt'), "$FilePath|$ArgumentList")
'@ | Set-Content -LiteralPath (Join-Path $fixture 'tools\Invoke-InteractiveDesktop.ps1')
  Import-Module -Name $module -Force
}

AfterAll {
  Remove-Module -Name LcmStandardDisplayFixture -ErrorAction SilentlyContinue
}

Describe 'Standard Display HTTP opener' {
  BeforeEach {
    Mock Invoke-WebRequest -ModuleName LcmStandardDisplayFixture {
      [pscustomobject]@{ StatusCode = 200; Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' } }
    }
    Mock Invoke-RestMethod -ModuleName LcmStandardDisplayFixture {
      param($Uri)
      if ($Uri -like '*/ping') { return [pscustomobject]@{ standardDisplays = 1 } }
      [pscustomobject]@{ state = 'Current'; error = '' }
    }
  }

  It 'opens only HTTP and encodes launch filters without changing the renderer command' {
    Open-LcmStandardDisplay -DisplayId tools -Parameters @{ Filter = 'a& b'; Audience = 'Dev' }
    $opened = Get-Content -LiteralPath (Join-Path $fixture 'tools\opened.txt') -Raw
    $opened | Should -Be 'http://127.0.0.1:9876/tools?Audience=Dev&Filter=a%26%20b|'
    Should -Invoke Invoke-RestMethod -ModuleName LcmStandardDisplayFixture -Times 1 -ParameterFilter { $Uri -like '*/displays/refresh/tools' -and $Method -eq 'Post' }
  }

  It 'waits for a recovering daemon to answer rather than assuming process dispatch succeeded' {
    InModuleScope LcmStandardDisplayFixture { $script:PingAttempts = 0 }
    Mock Invoke-RestMethod -ModuleName LcmStandardDisplayFixture {
      param($Uri)
      if ($Uri -like '*/ping') {
        $script:PingAttempts++
        if ($script:PingAttempts -lt 3) { throw 'Connection refused during startup' }
        return [pscustomobject]@{ standardDisplays = 1 }
      }
      [pscustomobject]@{ state = 'Current'; error = '' }
    }
    Open-LcmStandardDisplay -DisplayId rules -WarningAction SilentlyContinue
    Get-Content -LiteralPath (Join-Path $fixture 'tools\daemon-started.txt') | Should -Be '9876'
    Get-Content -LiteralPath (Join-Path $fixture 'tools\opened.txt') | Should -Be 'http://127.0.0.1:9876/rules|'
  }

  It 'rejects an old daemon explicitly without requesting or opening a local-file fallback' {
    Mock Invoke-RestMethod -ModuleName LcmStandardDisplayFixture { [pscustomobject]@{ status = 'ONLINE' } }
    { Open-LcmStandardDisplay -DisplayId hub } | Should -Throw '*must be restarted*No file fallback*'
    Should -Invoke Invoke-WebRequest -ModuleName LcmStandardDisplayFixture -Times 0
  }

  It 'dispatches the HTTP URL itself through the real interactive-desktop fast path' {
    Mock Start-Process {}
    $dispatcher = Join-Path (Split-Path $PSScriptRoot -Parent) 'tools\Invoke-InteractiveDesktop.ps1'
    if ([Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0) {
      Set-ItResult -Skipped -Because 'Requires an interactive Windows session.'
      return
    }
    & $dispatcher -FilePath 'http://127.0.0.1:9876/tools?Audience=User&Filter=a%26b' -LogFile (Join-Path $TestDrive 'desktop.log')
    Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
      $FilePath -eq 'http://127.0.0.1:9876/tools?Audience=User&Filter=a%26b' -and -not $ArgumentList
    }
  }
}
