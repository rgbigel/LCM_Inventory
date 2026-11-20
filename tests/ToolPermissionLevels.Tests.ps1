<#
.SYNOPSIS
    Pester tests for the tool permission levels 0..3 (CRP-343 segment 2).
.DESCRIPTION
    Module: tests/ToolPermissionLevels.Tests.ps1
    Purpose: ConvertTo-LcmAdminLevel (generator, extracted by AST) and admin_level (sync script) map legacy booleans and
             levels; the policy export checks owners below level 3, controlled tools with listed / unlisted atoms and
             granted tools against a fixture tools.db; the live catalog carries the Macrium BCR levels and atom lists.
    Path: LCM_Inventory/tests/ToolPermissionLevels.Tests.ps1
    Authors: Rolf, Claude
    Version: 10.7.7
    Date: 2026-11-20
    Implementation Choices (CRP-366): Python runs on the registered interpreter (Get-LcmRuntimePath, RULE-PY-010).
#>

Describe 'Tool permission levels (CRP-343 segment 2)' {
  BeforeAll {
    $script:root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $gen = Join-Path $script:root 'tools\Update-ToolCatalog.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($gen, [ref]$null, [ref]$null)
    $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'ConvertTo-LcmAdminLevel' }, $true)
    . ([scriptblock]::Create($fn.Extent.Text))
  }

  It 'maps legacy booleans and levels in the generator' {
    ConvertTo-LcmAdminLevel $true | Should -Be 3
    ConvertTo-LcmAdminLevel $false | Should -Be 1
    ConvertTo-LcmAdminLevel 2 | Should -Be 2
    ConvertTo-LcmAdminLevel '0' | Should -Be 0
    ConvertTo-LcmAdminLevel 7 | Should -Be 0
    ConvertTo-LcmAdminLevel $null | Should -Be 0
  }

  It 'maps legacy booleans and levels in the sync script' {
    $code = "import importlib.util,sys; s=importlib.util.spec_from_file_location('s', r'$($script:root)\tools\sync_tool_catalog_db.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print([m.admin_level(v) for v in (True, False, 2, '3', 9, None)])"
    Import-Module -Name (Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\LcmRuntimeAtoms.psm1')
    (& (Get-LcmRuntimePath -Key 'python') -c $code) | Should -Be '[3, 1, 2, 3, 0, 0]'
  }

  It 'reports owners below level 3 and callers outside the call table' {
    $db = Join-Path $TestDrive 'tools.db'
    $ws = Join-Path $TestDrive 'ws'
    $null = New-Item -ItemType Directory -Path (Join-Path $ws 'T') -Force
    Set-Content -LiteralPath (Join-Path $ws 'T\Controlled.ps1') -Value "& `"`$PSScriptRoot\Atom.ps1`"`n& `"`$PSScriptRoot\Other.ps1`""
    Set-Content -LiteralPath (Join-Path $ws 'T\Granted.ps1') -Value "& `"`$PSScriptRoot\Atom.ps1`""
    $py = @"
import sqlite3
c = sqlite3.connect(r'$db')
c.execute('create table tools (relative_path text, admin integer, name text)')
c.execute('create table tool_intents (intent_key text, executable text, script text, parameters text, elevated integer)')
c.execute('create table tool_atom_permissions (tool_relative_path text, intent_key text)')
c.executemany('insert into tools values (?,?,?)', [('T\\Atom.ps1', 3, 'Atom'), ('T\\Other.ps1', 1, 'Other'), ('T\\Controlled.ps1', 2, 'Controlled'), ('T\\Granted.ps1', 1, 'Granted')])
c.executemany('insert into tool_intents values (?,?,?,?,?)', [('atom', 'pwsh', 'T/Atom.ps1', '', 1), ('other', 'pwsh', 'T/Other.ps1', '', 1)])
c.execute("insert into tool_atom_permissions values ('T\\Controlled.ps1', 'atom')")
c.commit()
"@
    $py | python -
    $code = "import importlib.util,json; s=importlib.util.spec_from_file_location('p', r'$($script:root)\tools\Export-LcmElevationPolicy.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); m.GIT_ROOT=r'$ws'; a,t=m.load(r'$db'); print(json.dumps(sorted((v['kind'], v.get('tool',''), v['atom']) for v in m.check(a,t))))"
    Import-Module -Name (Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\LcmRuntimeAtoms.psm1')
    $kinds = (& (Get-LcmRuntimePath -Key 'python') -c $code) | ConvertFrom-Json
    $flat = @($kinds | ForEach-Object { $_ -join '|' })
    $flat | Should -Contain 'elevated-atom-in-non-admin-tool||T/Other.ps1'
    $flat | Should -Contain 'controlled-tool-invokes-unlisted-atom|T\Controlled.ps1|T/Other.ps1'
    $flat | Should -Contain 'non-admin-tool-invokes-elevated-atom|T\Granted.ps1|T/Atom.ps1'
    $flat | Should -Not -Contain 'controlled-tool-invokes-unlisted-atom|T\Controlled.ps1|T/Atom.ps1'
  }

  It 'carries the Macrium BCR levels and atom lists in the live catalog' {
    Import-Module -Name (Join-Path $script:root 'modules\LcmToolCatalog.psm1') -Force  # CRP-358: tools.db
    $catalog = @(Get-LcmToolStoreDocument -Store catalog)
    $daily = @($catalog | Where-Object Name -eq 'Invoke-MacriumDailyBcrBaseline.ps1')[0]
    $daily.Admin | Should -Be 2
    @($daily.AllowedAtoms) | Should -Be @('invoke-macriummountworker', 'set-lcmmachineregistry')
    @(@($catalog | Where-Object Name -eq 'Mount-MacriumLatestBaseline.ps1')[0].AllowedAtoms) | Should -Be @('invoke-macriummountworker')
    @($catalog | Where-Object Name -eq 'Invoke-MacriumMountWorker.ps1')[0].Admin | Should -Be 3
    @($catalog | Where-Object { $_.Admin -is [bool] }).Count | Should -Be 0
  }
}
