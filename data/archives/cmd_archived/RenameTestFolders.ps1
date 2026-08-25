param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath,
    [switch]$t,
    [switch]$p
)

# Module: RenameTestItems.ps1
# Purpose: Remove test segments, preserve extensions, auto-elevate, ACL fix+restore
# Path: D:\OneDrive\cmd\RenameTestItems.ps1
# Authors: Rolf
# Version: 2.4.1

# --- self-elevate ---
$wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$prp = New-Object System.Security.Principal.WindowsPrincipal($wid)
if (-not $prp.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = @(
        "-File `"$PSCommandPath`"",
        "-RepoPath `"$RepoPath`""
    )
    if ($t) { $args += "-t" }
    $args += "-p"
    Start-Process pwsh -Verb RunAs -ArgumentList ($args -join ' ')
    exit 0
}

# --- counters ---
$SuccessCount = 0
$FailCount    = 0
$SkipCount    = 0

# --- main ---
$items = Get-ChildItem -Path $RepoPath -Recurse -Force

foreach ($item in $items) {

    $name    = $item.Name
    $current = $item.FullName

    $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
    $ext  = [System.IO.Path]::GetExtension($name)

    # remove:
    #   leading  "test." or bare "test" when there is an extension
    #   embedded ".test."
    #   trailing ".test"
    $newBase = $base
    if ($ext -ne '' -and $newBase -eq 'test') {
        $newBase = ''
    }
    $newBase = $newBase -replace '^test\.', ''
    $newBase = $newBase -replace '\.test\.', '.'
    $newBase = $newBase -replace '\.test$', ''

    if ($newBase -eq '' -and $ext -eq '') { $newBase = 'test' }

    $newLeaf = $newBase + $ext

    if ($newLeaf -eq $name) {
        $SkipCount++
        if ($t) { Write-Host "DEBUG: skip: $name" }
        continue
    }

    if ($t) { Write-Host "DEBUG: rename attempt: $name -> $newLeaf" }

    $renamed = $false

    # --- first attempt ---
    try {
        Rename-Item -Path $current -NewName $newLeaf
        $renamed = $true
        if ($t) { Write-Host "SUCCESS(first): $name -> $newLeaf" }
    }
    catch {
        if ($_.Exception.Message -notmatch 'Access') {
            $FailCount++
            if ($t) { Write-Host "FAIL(first): $name -> $newLeaf : $($_.Exception.Message)" }
            continue
        }
        if ($t) { Write-Host "FAIL(first, access denied): $name -> $newLeaf" }
    }

    if ($renamed) {
        $SuccessCount++
        continue
    }

    # --- ACL fix ---
    $aclBackup = $null
    try {
        $aclBackup = Get-Acl $current
        icacls $current /grant "$env:USERNAME":F | Out-Null

        Rename-Item -Path $current -NewName $newLeaf
        $renamed = $true
        if ($t) { Write-Host "SUCCESS(ACL fix): $name -> $newLeaf" }
    }
    catch {
        $FailCount++
        if ($t) { Write-Host "FAIL(ACL fix): $name -> $newLeaf : $($_.Exception.Message)" }
        continue
    }
    finally {
        if ($aclBackup) {
            try {
                $newPath = Join-Path (Split-Path $current -Parent) $newLeaf
                Set-Acl -Path $newPath -AclObject $aclBackup
            } catch {}
        }
    }

    if ($renamed) {
        $SuccessCount++
    }
}

Write-Host ""
Write-Host "SUMMARY (RenameTestItems.ps1 v2.4.1)"
Write-Host "  Success : $SuccessCount"
Write-Host "  Failed  : $FailCount"
Write-Host "  Skipped : $SkipCount"

if ($p) {
    Read-Host "Press ENTER to exit"
}
