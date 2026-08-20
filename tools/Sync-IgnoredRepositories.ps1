[CmdletBinding()]
param()

<#
Module: Sync-IgnoredRepositories.ps1
Purpose: Synchronizes root .vscode/settings.json git.ignoredRepositories with current workspace non-git directories.
Path: tools/Sync-IgnoredRepositories.ps1
Authors: Rolf, Workspace_AI Engine
Version: 1.0.0
Date: 2026-08-20
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..\modules\WorkspaceCM.psm1'
Import-Module (Resolve-Path $modulePath) -Force

Sync-IgnoredRepositories
