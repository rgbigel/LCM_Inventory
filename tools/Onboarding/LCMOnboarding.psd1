@{
  RootModule = 'LCMOnboarding.psm1'
  ModuleVersion = '1.0.0'
  GUID = 'd2e8b417-7c93-4a11-b762-3e289bf59d2a'
  Author = 'Rolf, LCM_AI Engine'
  CompanyName = 'Solution Workspace Engineering'
  Copyright = '(c) 2026. All rights reserved.'
  Description = 'Lifecycle Model (LCM) Modular Repository Onboarding Engine.'
  PowerShellVersion = '7.0'
  FunctionsToExport = @(
    'Test-LCMPreFlight',
    'New-LCMGovernanceLinks',
    'Expand-LCMTemplate',
    'Test-LCMIntegrity',
    'Invoke-LCMOnboardRepo'
  )
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
}
