@echo off
if "%~1"=="" (
  echo Usage: RenameProposal.cmd ^<ProposalId^> "^<New Title^>"
  exit /b 1
)
if "%~2"=="" (
  echo Usage: RenameProposal.cmd ^<ProposalId^> "^<New Title^>"
  exit /b 1
)
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\tools\Invoke-ProposalAction.ps1" -Action rename -TargetExpression "%~1" -Title "%~2"

