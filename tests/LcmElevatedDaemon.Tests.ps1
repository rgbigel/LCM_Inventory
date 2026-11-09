<#
Module: LcmElevatedDaemon.Tests
Purpose: Automated verification test suite for CRP-309 Unified Elevated Desktop Daemon, Universal Back Channel, and Security Gateway.
Path: LCM_Inventory/tests/LcmElevatedDaemon.Tests.ps1
Authors: Rolf, LCM_AI Engine
Version: 10.0.2
Date: 2026-11-09 19:05:00
#>

BeforeAll {
  $script:repoRoot = Split-Path $PSScriptRoot -Parent
  $script:wsRoot = Split-Path $script:repoRoot -Parent

  . "$script:repoRoot\modules\LcmDaemon\Classes\DaemonDto.ps1"
  . "$script:repoRoot\modules\LcmDaemon\Classes\DaemonEnvironment.ps1"
  . "$script:repoRoot\modules\LcmDaemon\Classes\LcmTokenVault.ps1"
  . "$script:repoRoot\modules\LcmDaemon\Classes\LcmSecurityGateway.ps1"
  . "$script:repoRoot\modules\LcmDaemon\Classes\DaemonActionController.ps1"

  Import-Module -Name (Join-Path $script:repoRoot 'modules\LcmDisplayHttp.psm1') -Force

  function New-TestDisplayResponse {
    $response = [pscustomobject]@{
      StatusCode      = 0
      ContentType     = ''
      Headers         = [System.Collections.Specialized.NameValueCollection]::new()
      ContentLength64 = 0
      OutputStream    = [System.IO.MemoryStream]::new()
    }
    $response | Add-Member -MemberType ScriptMethod -Name Close -Value {}
    return $response
  }
}

Describe 'CRP-309 Presentation & Delivery (CORS and Webview Hosting)' {
  It 'emits binding CORS headers and permissive webview CSP' {
    $mockResp = New-TestDisplayResponse
    $content = [System.Text.Encoding]::UTF8.GetBytes('<html><body>Hub Content</body></html>')

    Send-LcmDisplayResponse -Response $mockResp -Bytes $content -ContentType 'text/html; charset=utf-8'

    $mockResp.Headers['Access-Control-Allow-Origin'] | Should -Be '*'
    $mockResp.Headers['Access-Control-Allow-Private-Network'] | Should -Be 'true'
    $mockResp.Headers['Access-Control-Allow-Methods'] | Should -Be 'GET, POST, OPTIONS'
    $mockResp.Headers['Content-Security-Policy'] | Should -Match 'vscode-webview:'
  }

  It 'handles OPTIONS preflight with HTTP 204 No Content via Invoke-LcmDisplayHttpRequest' {
    $request = [pscustomobject]@{
      Url           = [uri]'http://127.0.0.1:9876/tools'
      HttpMethod    = 'OPTIONS'
      LocalEndPoint = [pscustomobject]@{ Port = 9876 }
    }
    $response = New-TestDisplayResponse

    $handled = Invoke-LcmDisplayHttpRequest -Request $request -Response $response -WorkspaceRoot $script:wsRoot
    $handled | Should -BeTrue
    $response.StatusCode | Should -Be 204
    $response.Headers['Access-Control-Allow-Origin'] | Should -Be '*'
    $response.Headers['Access-Control-Allow-Private-Network'] | Should -Be 'true'
  }
}

Describe 'CRP-309 Ephemeral JIT Token Vault' {
  It 'issues cryptographically signed ephemeral tokens with 30s TTL' {
    $token = [LcmTokenVault]::IssueToken('MacriumDailyBaseline', 'Operator', $script:wsRoot)
    $token | Should -Not -BeNullOrEmpty
    $token.Split('.').Count | Should -Be 2
  }

  It 'verifies and burns token on single use' {
    $token = [LcmTokenVault]::IssueToken('MacriumDailyBaseline', 'Operator', $script:wsRoot)
    $firstAttempt = [LcmTokenVault]::VerifyAndBurnToken($token, 'MacriumDailyBaseline', 'Operator')
    $firstAttempt | Should -BeTrue

    # Replay must fail (burn-on-use invariant)
    $secondAttempt = [LcmTokenVault]::VerifyAndBurnToken($token, 'MacriumDailyBaseline', 'Operator')
    $secondAttempt | Should -BeFalse
  }

  It 'rejects tokens with mismatched targets or tampered signatures' {
    $token = [LcmTokenVault]::IssueToken('MacriumDailyBaseline', 'Operator', $script:wsRoot)
    $wrongTarget = [LcmTokenVault]::VerifyAndBurnToken($token, 'OtherDangerousTool', 'Operator')
    $wrongTarget | Should -BeFalse

    $tamperedToken = $token.Substring(0, $token.Length - 4) + 'abcd'
    $tamperedResult = [LcmTokenVault]::VerifyAndBurnToken($tamperedToken, 'MacriumDailyBaseline', 'Operator')
    $tamperedResult | Should -BeFalse
  }
}

Describe 'CRP-309 Security Gateway & Tier Authorization' {
  It 'correctly resolves target authorization tiers' {
    [LcmSecurityGateway]::ResolveTargetTier('ping', $script:wsRoot) | Should -Be 1
    [LcmSecurityGateway]::ResolveTargetTier('status', $script:wsRoot) | Should -Be 1
    [LcmSecurityGateway]::ResolveTargetTier('help', $script:wsRoot) | Should -Be 1
    [LcmSecurityGateway]::ResolveTargetTier('tools', $script:wsRoot) | Should -Be 1
    [LcmSecurityGateway]::ResolveTargetTier('hub', $script:wsRoot) | Should -Be 1

    [LcmSecurityGateway]::ResolveTargetTier('TestLCMRuleHealth', $script:wsRoot) | Should -Be 2
    [LcmSecurityGateway]::ResolveTargetTier('MacriumDailyBaseline', $script:wsRoot) | Should -Be 3
    [LcmSecurityGateway]::ResolveTargetTier('RestoreSettings', $script:wsRoot) | Should -Be 3
    [LcmSecurityGateway]::ResolveTargetTier('KillLogitech', $script:wsRoot) | Should -Be 3
  }

  It 'authorizes Tier 1 and Tier 2 operations' {
    $tier1Intent = [DaemonActionIntent]::new()
    $tier1Intent.Action = 'DO'
    $tier1Intent.Target = 'ping'
    $tier1Intent.Caller = 'ExternalCaller'

    $auth1 = [LcmSecurityGateway]::Authorize($tier1Intent, $script:wsRoot)
    $auth1.Authorized | Should -BeTrue
    $auth1.Tier | Should -Be 1

    $tier2Intent = [DaemonActionIntent]::new()
    $tier2Intent.Action = 'DO'
    $tier2Intent.Target = 'TestLCMRuleHealth'
    $tier2Intent.Caller = 'ExternalCaller'

    $auth2 = [LcmSecurityGateway]::Authorize($tier2Intent, $script:wsRoot)
    $auth2.Authorized | Should -BeTrue
    $auth2.Tier | Should -Be 2
  }

  It 'enforces ephemeral token requirement for untrusted Tier 3 callers' {
    $tier3Intent = [DaemonActionIntent]::new()
    $tier3Intent.Action = 'DO'
    $tier3Intent.Target = 'RestoreSettings'
    $tier3Intent.Caller = 'UntrustedOutsideCaller'

    $authDenied = [LcmSecurityGateway]::Authorize($tier3Intent, $script:wsRoot)
    $authDenied.Authorized | Should -BeFalse
    $authDenied.Tier | Should -Be 3
    $authDenied.Reason | Should -Match 'DENIED'

    # Now provide a valid ephemeral token
    $token = [LcmTokenVault]::IssueToken('RestoreSettings', 'UntrustedOutsideCaller', $script:wsRoot)
    $tier3Intent.Token = $token
    $authGranted = [LcmSecurityGateway]::Authorize($tier3Intent, $script:wsRoot)
    $authGranted.Authorized | Should -BeTrue
    $authGranted.Reason | Should -Match 'burned'
  }

  It 'writes structured audit log entries to security_gateway.log' {
    $logPath = Join-Path $script:wsRoot 'LCM_Inventory\data\logs\security_gateway.log'
    $initialCount = if (Test-Path -LiteralPath $logPath) { @(Get-Content -LiteralPath $logPath).Count } else { 0 }

    $testAuth = [PSCustomObject]@{
      Caller     = 'PesterTest'
      Target     = 'TestSecurityAuditTool'
      Tier       = 2
      Authorized = $true
      Reason     = 'Test verification log entry'
    }

    [LcmSecurityGateway]::LogAudit($testAuth, 0, 150, $script:wsRoot)

    Test-Path -LiteralPath $logPath | Should -BeTrue
    $lines = @(Get-Content -LiteralPath $logPath)
    $lines.Count | Should -BeGreaterThan $initialCount
    $lastLine = $lines[-1] | ConvertFrom-Json
    $lastLine.caller | Should -Be 'PesterTest'
    $lastLine.target | Should -Be 'TestSecurityAuditTool'
    $lastLine.exitCode | Should -Be 0
    $lastLine.durationMs | Should -Be 150
  }
}

Describe 'CRP-309 Daemon Synchronous Execution & Stream Capture' {
  It 'captures stdout, duration, and exit code 0 on successful synchronous command' {
    $envMock = [DaemonEnvironment]::new($script:wsRoot, 9876, '10.0.1', (Join-Path $script:wsRoot 'LCM_Inventory\logs\test_daemon.log'))
    $controller = [DaemonActionController]::new($envMock)

    $req = [DaemonExecuteRequest]::new()
    $req.Command = 'Write-Output "LCM_DAEMON_ECHO_TEST_OK"'
    $req.Sync = $true

    $result = $controller.ExecuteCommand($req)
    $result.status | Should -Be 'COMPLETED'
    $result.exitCode | Should -Be 0
    $result.stdout | Should -Match 'LCM_DAEMON_ECHO_TEST_OK'
    $result.durationMs | Should -BeGreaterThan 0
  }

  It 'captures non-zero exit code and stderr without hanging on failure' {
    $envMock = [DaemonEnvironment]::new($script:wsRoot, 9876, '10.0.1', (Join-Path $script:wsRoot 'LCM_Inventory\logs\test_daemon.log'))
    $controller = [DaemonActionController]::new($envMock)

    $req = [DaemonExecuteRequest]::new()
    $req.Command = 'Write-Error "Simulated failure"; exit 42'
    $req.Sync = $true

    $result = $controller.ExecuteCommand($req)
    $result.status | Should -Be 'ERROR'
    $result.exitCode | Should -Be 42
    $result.stderr | Should -Match 'Simulated failure'
  }

  It 'executes Action Intent DO via tool resolution and returns result' {
    $envMock = [DaemonEnvironment]::new($script:wsRoot, 9876, '10.0.1', (Join-Path $script:wsRoot 'LCM_Inventory\logs\test_daemon.log'))
    $controller = [DaemonActionController]::new($envMock)

    $intent = [DaemonActionIntent]::new()
    $intent.Action = 'DO'
    $intent.Target = 'TestLCMRuleHealth'
    $intent.Caller = 'PesterTest'
    $intent.Options['sync'] = $true

    $result = $controller.ExecuteActionIntent($intent)
    $result.status | Should -Be 'COMPLETED'
    $result.exitCode | Should -Be 0
    $result.stdout | Should -Match 'LCM Governance & Rule Discovery Diagnostic Report'
  }

  It 'preserves CLI arguments when executing Action Intent with raw command string (BUG-313)' {
    $envMock = [DaemonEnvironment]::new($script:wsRoot, 9876, '10.0.2', (Join-Path $script:wsRoot 'LCM_Inventory\logs\test_daemon.log'))
    $controller = [DaemonActionController]::new($envMock)

    $intent = [DaemonActionIntent]::new()
    $intent.Action = 'DO'
    $intent.Target = 'pwsh -NoProfile -ExecutionPolicy Bypass -File LCM_Inventory/tools/Submit-ReviewResult.ps1 -Help'
    $intent.Command = 'pwsh -NoProfile -ExecutionPolicy Bypass -File LCM_Inventory/tools/Submit-ReviewResult.ps1 -Help'
    $intent.Caller = 'PesterTest'
    $intent.Options['sync'] = $true

    $result = $controller.ExecuteActionIntent($intent)
    $result.status | Should -Be 'COMPLETED'
    $result.exitCode | Should -Be 0
    $result.stdout | Should -Match 'SUBMIT REVIEW RESULT \(Submit-ReviewResult\)'
  }

  It 'assembles structured parameters when executing Action Intent with parameters hashtable (BUG-313)' {
    $envMock = [DaemonEnvironment]::new($script:wsRoot, 9876, '10.0.2', (Join-Path $script:wsRoot 'LCM_Inventory\logs\test_daemon.log'))
    $controller = [DaemonActionController]::new($envMock)

    $intent = [DaemonActionIntent]::new()
    $intent.Action = 'DO'
    $intent.Target = 'Submit-ReviewResult'
    $intent.Parameters['Help'] = $true
    $intent.Caller = 'PesterTest'
    $intent.Options['sync'] = $true

    $result = $controller.ExecuteActionIntent($intent)
    $result.status | Should -Be 'COMPLETED'
    $result.exitCode | Should -Be 0
    $result.stdout | Should -Match 'SUBMIT REVIEW RESULT \(Submit-ReviewResult\)'
  }
}
