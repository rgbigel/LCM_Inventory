# ==============================================================================
# TrampolineBanner.Tests.ps1 - Tests for CRP-316 Trampoline Identification Banner
# ==============================================================================
BeforeAll {
  $cmdDir = Join-Path $PSScriptRoot '..\Cmd'
}

Describe 'CRP-316: Trampoline Window Caller Context and Goal Identification Banner' {
  It 'Includes # [LCM Launcher] comment banner in generated trampolines' {
    $targetCmd = Join-Path $cmdDir 'ShowTools.cmd'
    (Test-Path -LiteralPath $targetCmd) | Should -BeTrue
    $content = Get-Content -LiteralPath $targetCmd -Raw
    $content | Should -Match 'echo # \[LCM Launcher\] %~nx0 - Goal:'
  }

  It 'Executes trampoline and displays comment header' {
    $targetCmd = Join-Path $cmdDir 'ShowTools.cmd'
    $output = cmd.exe /c "`"$targetCmd`" -h" 2>&1
    $outputString = $output -join "`n"
    $outputString | Should -Match '# \[LCM Launcher\] ShowTools\.cmd - Goal:'
    $LASTEXITCODE | Should -BeExactly 0
  }
}

