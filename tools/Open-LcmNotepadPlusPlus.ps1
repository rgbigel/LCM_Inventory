<#
.SYNOPSIS
    Opens one or more files in Notepad++ and brings Notepad++ to the foreground.
.DESCRIPTION
    Module: tools/Open-LcmNotepadPlusPlus.ps1
    Purpose: Editor launcher for the Control Hub ("Show CRP", "Edit in Notepad++") and tools: relative paths resolve
             against the workspace root; files open as tabs; the registered AHK atom activate-window brings the window
             to the front, because a program started by the background DO daemon may not take the foreground.
    Path: LCM_Inventory/tools/Open-LcmNotepadPlusPlus.ps1
    Authors: Rolf, Claude
    Version: 10.7.5
    Date: 2026-11-18
    Implementation Choices (CRP-354): direct Notepad++ start, no VS Code route; missing files are skipped and named;
    activation failure is a warning, not an error (the files are open).
.PARAMETER Path
    One or more file paths (absolute, or relative to the workspace root). Remaining arguments are paths.
.PARAMETER DryRun
    Resolves the paths and returns the plan without starting anything.
.NOTES
    Caveats: Notepad++ is expected at C:\Program Files\Notepad++\notepad++.exe (else on PATH). Run non-elevated
    (through the DO); the activation atom refuses a caller whose elevation differs from the atom (CRP-343 border rule).
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path,

    [switch]$DryRun,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help -or $null -eq $Path -or @($Path).Count -eq 0) {
    Write-Host '=========================================================================='
    Write-Host ' OPEN IN NOTEPAD++ (Open-LcmNotepadPlusPlus)'
    Write-Host '=========================================================================='
    Write-Host 'USAGE:'
    Write-Host '  pwsh LCM_Inventory/tools/Open-LcmNotepadPlusPlus.ps1 <path> [<path> ...] [-DryRun] [-h]'
    Write-Host 'PARAMETERS:'
    Write-Host '  <path>    : File(s), absolute or relative to the workspace root; opened as tabs'
    Write-Host '  -DryRun   : Resolve the paths only; start nothing'
    Write-Host '  -Help     : Displays this help screen'
    Write-Host '=========================================================================='
    return
}

$workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$resolved = [System.Collections.Generic.List[string]]::new()
$missing = [System.Collections.Generic.List[string]]::new()
foreach ($item in $Path) {
    $candidate = $item.Trim('"', "'").Replace('/', '\')
    if (-not [System.IO.Path]::IsPathRooted($candidate)) { $candidate = Join-Path $workspaceRoot $candidate }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $resolved.Add((Resolve-Path -LiteralPath $candidate).Path) } else { $missing.Add($item) }
}

$editor = 'C:\Program Files\Notepad++\notepad++.exe'
if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) {
    $onPath = Get-Command 'notepad++.exe' -ErrorAction SilentlyContinue
    $editor = if ($null -ne $onPath) { $onPath.Source } else { $null }
}

$plan = [pscustomobject]@{ Editor = $editor; Files = @($resolved); Missing = @($missing) }
if ($DryRun) { return $plan }
if ($null -eq $editor) { throw 'Notepad++ was not found (C:\Program Files\Notepad++\notepad++.exe or PATH).' }
foreach ($m in $missing) { Write-Warning "File not found, skipped: $m" }
if ($resolved.Count -eq 0) { throw "None of the files exists: $($Path -join ', ')" }

$arguments = @($resolved | ForEach-Object { '"{0}"' -f $_ })
$null = Start-Process -FilePath $editor -ArgumentList $arguments -PassThru
Write-Host "[ACTION] Notepad++: $($resolved.Count) file(s) opened."

Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmAhkAtoms.psm1') -Force
try {
    $leaf = Split-Path $resolved[$resolved.Count - 1] -Leaf
    $activation = Invoke-LcmAhkAtom -Intent 'activate-window' -ArgumentList @('notepad++.exe', $leaf, '10') -TimeoutSeconds 20
    if ($activation.Succeeded) { Write-Host "[INFO] Activation: $($activation.Output)" }
    else { Write-Warning "Notepad++ is open but not in the foreground (atom exit $($activation.ExitCode)): $($activation.Output)" }
} catch {
    Write-Warning "Notepad++ is open but could not be brought to the foreground: $($_.Exception.Message)"
}
