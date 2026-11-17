<#
.SYNOPSIS
  Shared client atoms for PowerShell tools that call the DO daemon directly (CRP-343).
.DESCRIPTION
  Module: modules/LcmDoClient.psm1
  Purpose: Sends the per-boot daemon key (X-LCM-Key, %LOCALAPPDATA%\LCM\do.key) with direct
           /execute calls, after verifying that the listener on 127.0.0.1:<port> is the
           LCM_Inventory\DoT\do.exe daemon (port-squatting guard).
  Path: LCM_Inventory/modules/LcmDoClient.psm1
  Authors: Rolf, Claude
  Version: 10.7.4
  Date: 2026-11-17
  Rule: RULE-ELEV-006, RULE-PS-025 (CRP-343 D2)
  Implementation Choices (CRP-343): the key is never logged or returned to callers; a listener
           that is not the expected do.exe gets no key (the request is still sent, unauthenticated,
           so the daemon decides: never elevated).
.NOTES
  Caveats: the key file is readable by every process of the operator account (by design).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not ('LcmDoClientNative' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class LcmDoClientNative
{
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool QueryFullProcessImageName(IntPtr process, uint flags, StringBuilder name, ref uint size);
    [DllImport("kernel32.dll")]
    private static extern bool CloseHandle(IntPtr handle);
    public static string ImagePath(uint pid)
    {
        IntPtr h = OpenProcess(0x1000, false, pid);
        if (h == IntPtr.Zero) { return null; }
        try
        {
            var sb = new StringBuilder(1024);
            uint n = 1024;
            return QueryFullProcessImageName(h, 0, sb, ref n) ? sb.ToString() : null;
        }
        finally { CloseHandle(h); }
    }
}
'@
}

function Get-LcmDaemonPort {
  [CmdletBinding()]
  param()
  if ($env:LCM_DAEMON_PORT -match '^\d+$') { return [int]$env:LCM_DAEMON_PORT }
  9876
}

function Test-LcmDaemonListener {
  [CmdletBinding()]
  param([int]$Port = (Get-LcmDaemonPort))
  $expected = Join-Path (Split-Path $PSScriptRoot -Parent) 'DoT\do.exe'
  try {
    $conn = @(Get-NetTCPConnection -LocalAddress '127.0.0.1', '0.0.0.0' -LocalPort $Port -State Listen -ErrorAction Stop)[0]
    # Get-Process / CIM cannot read the image of the elevated daemon from a non-elevated shell;
    # QueryFullProcessImageName with PROCESS_QUERY_LIMITED_INFORMATION can (same as do.exe serverid.go).
    $path = [LcmDoClientNative]::ImagePath([uint32]$conn.OwningProcess)
  } catch {
    return $false
  }
  if ([string]::IsNullOrWhiteSpace($path)) { return $false }
  return ([System.IO.Path]::GetFullPath($path) -ieq [System.IO.Path]::GetFullPath($expected))
}

function Get-LcmDaemonHeaders {
  [CmdletBinding()]
  param([int]$Port = (Get-LcmDaemonPort))
  $headers = @{}
  $keyFile = Join-Path $env:LOCALAPPDATA 'LCM\do.key'
  if ((Test-Path -LiteralPath $keyFile -PathType Leaf) -and (Test-LcmDaemonListener -Port $Port)) {
    $headers['X-LCM-Key'] = ([System.IO.File]::ReadAllText($keyFile)).Trim()
  }
  $headers
}

function Invoke-LcmDaemonCommand {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Command,
    [switch]$Sync,
    [switch]$Elevated,
    [int]$TimeoutSeconds = 60
  )
  $port = Get-LcmDaemonPort
  $body = @{
    command   = $Command
    elevated  = [bool]$Elevated
    sync      = [bool]$Sync
    timeoutMs = $TimeoutSeconds * 1000
  } | ConvertTo-Json
  $params = @{
    Uri         = 'http://127.0.0.1:{0}/execute' -f $port
    Method      = 'Post'
    Body        = $body
    ContentType = 'application/json'
    Headers     = (Get-LcmDaemonHeaders -Port $port)
    TimeoutSec  = $TimeoutSeconds + 10
    ErrorAction = 'Stop'
  }
  Invoke-RestMethod @params
}

Export-ModuleMember -Function Get-LcmDaemonPort, Test-LcmDaemonListener, Get-LcmDaemonHeaders, Invoke-LcmDaemonCommand
