<#
.SYNOPSIS
  Launches the Antigravity authenticated local remote bridge daemon with mobile QR pairing.
.DESCRIPTION
  Module: Start-RemoteBridge
  Purpose: Self-contained HTTP bridge server providing an authenticated mobile web interface
           and REST API endpoint over LAN / WireGuard VPN. Serves a responsive mobile terminal
           and generates an ASCII QR code for 1-click mobile phone pairing.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), RULE-PS-010 (CLI Help), and RULE-PS-011 (Interactive Desktop Dispatch).
  Path: tools/Start-RemoteBridge.ps1
  Authors: Rolf, LCM Workspace Automation
  Version: 10.0.0
  Date: 2026-10-13
.PARAMETER BindIp
  IP address interface to bind the remote bridge daemon on (Defaults to detected LAN IP e.g. 192.168.10.2).
.PARAMETER StartPort
  Starting port candidate for port availability scan (Default: 8080).
.PARAMETER MaxPortScan
  Maximum consecutive ports to scan for availability (Default: 50).
.PARAMETER NoConfirm
  Accepts suggested candidate port automatically without interactive prompt.
.PARAMETER LogFile
  Custom log file destination. Defaults to tools/logs/Start-RemoteBridge-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Start-RemoteBridge.ps1 -h
.EXAMPLE
  pwsh tools/Start-RemoteBridge.ps1
.EXAMPLE
  pwsh tools/Start-RemoteBridge.ps1 -NoConfirm
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$BindIp = "",

  [Parameter(Mandatory = $false)]
  [ValidateRange(1024, 65535)]
  [int]$StartPort = 8080,

  [Parameter(Mandatory = $false)]
  [ValidateRange(1, 1000)]
  [int]$MaxPortScan = 50,

  [switch]$NoConfirm,

  [string]$LogFile = "",

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptVersion = "10.0.0"
$scriptName = "Start-RemoteBridge"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " ANTIGRAVITY LOCAL REMOTE BRIDGE LAUNCHER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Launches Antigravity Remote Control with cryptographic token auth,"
  Write-Host "  auto-detected LAN IP, interactive confirmation, and mobile QR pairing."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Start-RemoteBridge.ps1 [-BindIp <IP>] [-StartPort <Port>] [-MaxPortScan <Count>] [-NoConfirm] [-LogFile <Path>] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -BindIp <str>      : Listening interface IP (Defaults to detected LAN IP e.g. 192.168.10.2)."
  Write-Host "  -StartPort <int>   : Base port for collision scan (Default: 8080)."
  Write-Host "  -MaxPortScan <int> : Scan depth for open ports (Default: 50)."
  Write-Host "  -NoConfirm         : Automatically accept candidate port without interactive prompt."
  Write-Host "  -LogFile <str>     : Custom log file destination."
  Write-Host "  -h, -Help, -?      : Displays this parameter reference."
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Start-RemoteBridge.ps1"
  Write-Host "  pwsh tools/Start-RemoteBridge.ps1 -NoConfirm"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Initialize Logging Context per RULE-PS-009
# ------------------------------------------------------------------------------
$workspaceRoot = 'D:\Git_Repositories'
$lcdRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$toolsDir = Join-Path $lcdRoot 'tools'
$logDir = Join-Path $lcdRoot 'data\logs\lcm'
if (-not (Test-Path -Path $logDir)) {
  New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $LogFile = Join-Path $logDir "$($scriptName)-$($timestampStr).log"
}
$script:ActiveLogFile = $LogFile

function Write-ToolLog {
  param(
    [AllowEmptyString()]
    [string]$Message = "",
    [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "ACTION", "SUMMARY")]
    [string]$Level = "INFO",
    [switch]$ConsoleOnly,
    [switch]$LogOnly
  )

  $timeHeader = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  $formattedLog = "[$timeHeader] [$Level] $Message"

  if (-not $ConsoleOnly -and -not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
    try {
      $formattedLog | Out-File -FilePath $script:ActiveLogFile -Append -Encoding UTF8
    } catch {}
  }

  if (-not $LogOnly) {
    switch ($Level) {
      "WARN"    { Write-Warning $Message }
      "ERROR"   { Write-Error $Message }
      "DEBUG"   { Write-Host "  [DEBUG] $Message" -ForegroundColor DarkGray }
      "ACTION"  { Write-Host "  -> $Message" -ForegroundColor Green }
      "SUMMARY" { Write-Host $Message -ForegroundColor Cyan }
      default   { Write-Host $Message }
    }
  }
}

Write-ToolLog -Message "==========================================================================" -Level INFO
Write-ToolLog -Message " ANTIGRAVITY LOCAL REMOTE BRIDGE LAUNCHER (v$($scriptVersion))" -Level INFO
Write-ToolLog -Message " Log File : $($LogFile)" -Level INFO
Write-ToolLog -Message " Date     : $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) | Host: $($env:COMPUTERNAME)" -Level INFO
Write-ToolLog -Message "==========================================================================" -Level INFO

# Auto-detect Primary LAN IP if not explicitly provided
if ([string]::IsNullOrWhiteSpace($BindIp)) {
  $detected = @(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.IPAddress -notlike "127.*" -and 
    $_.IPAddress -notlike "169.254.*" -and 
    $_.InterfaceAlias -notlike "*vEthernet*" -and
    $_.InterfaceAlias -notlike "*Virtual*"
  } | Select-Object -ExpandProperty IPAddress)

  if ($detected.Count -gt 0) {
    $BindIp = $detected[0]
    Write-ToolLog -Message "Auto-detected Primary LAN IPv4: $BindIp" -Level INFO
  } else {
    $BindIp = "192.168.10.2"
    Write-ToolLog -Message "Fallback default IPv4: $BindIp" -Level WARN
  }
}

function Test-PortAvailability {
  param([int]$TestPort)
  $occupied = @(Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue)
  return ($occupied.Count -eq 0)
}

function Find-NextAvailablePort {
  param(
    [int]$InitialPort,
    [int]$ScanLimit
  )
  for ($offset = 0; $offset -lt $ScanLimit; $offset++) {
    $candidate = $InitialPort + $offset
    if (Test-PortAvailability -TestPort $candidate) {
      return $candidate
    }
  }
  return 0
}

# ------------------------------------------------------------------------------
# 2. Resolve Candidate Port & Collision Detection
# ------------------------------------------------------------------------------
$suggestedPort = Find-NextAvailablePort -InitialPort $StartPort -ScanLimit $MaxPortScan

if ($suggestedPort -eq 0) {
  $errMsg = "No free TCP ports found in range $StartPort to $($StartPort + $MaxPortScan - 1)."
  Write-ToolLog -Message $errMsg -Level ERROR
  throw $errMsg
}

# ------------------------------------------------------------------------------
# 3. Port Selection & Confirmation
# ------------------------------------------------------------------------------
$selectedPort = $suggestedPort
$confirmed = $false

if ($NoConfirm) {
  Write-ToolLog -Message "Non-interactive mode: Auto-selected available port $selectedPort." -Level ACTION
  $confirmed = $true
} else {
  Write-Host ""
  Write-Host "Candidate Port Selected: $($selectedPort)" -ForegroundColor Cyan
  $promptMessage = "Accept port $($selectedPort)? [Y]es / [N]ew port / [C]ancel: "
  $userChoice = (Read-Host -Prompt $promptMessage).Trim().ToUpperInvariant()

  if ($userChoice -eq "Y" -or $userChoice -eq "") {
    if (Test-PortAvailability -TestPort $selectedPort) {
      $confirmed = $true
    } else {
      Write-ToolLog -Message "Port $selectedPort is currently occupied. Please choose another port." -Level WARN
      $selectedPort = Find-NextAvailablePort -InitialPort ($selectedPort + 1) -ScanLimit $MaxPortScan
    }
  } elseif ($userChoice -eq "N") {
    $customInput = Read-Host -Prompt "Enter desired port number (1024-65535)"
    $parsedPort = 0
    if ([int]::TryParse($customInput, [ref]$parsedPort) -and $parsedPort -ge 1024 -and $parsedPort -le 65535) {
      if (Test-PortAvailability -TestPort $parsedPort) {
        $selectedPort = $parsedPort
        $confirmed = $true
      } else {
        Write-ToolLog -Message "Port $parsedPort is already in use by another process." -Level WARN
      }
    }
  } elseif ($userChoice -eq "C") {
    Write-ToolLog -Message "Operation cancelled by user." -Level WARN
    return
  }
}

# ------------------------------------------------------------------------------
# 4. Generate Cryptographic Session Token & Direct URL
# ------------------------------------------------------------------------------
$randomBytes = [byte[]]::new(32)
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($randomBytes)
$sessionToken = [Convert]::ToBase64String($randomBytes).Replace("+", "-").Replace("/", "_").TrimEnd("=")

$targetUrl = "http://${BindIp}:${selectedPort}/?token=${sessionToken}"

Write-ToolLog -Message "" -Level INFO
Write-ToolLog -Message "==========================================================" -Level INFO
Write-ToolLog -Message " Antigravity Local Remote Control Bridge (v$($scriptVersion))" -Level ACTION
Write-ToolLog -Message "==========================================================" -Level INFO
Write-ToolLog -Message "Binding Host  : $BindIp" -Level INFO
Write-ToolLog -Message "Listening Port: $selectedPort" -Level INFO
Write-ToolLog -Message "Auth Token    : $sessionToken" -Level INFO
Write-ToolLog -Message "Direct URL    : $targetUrl" -Level INFO
Write-ToolLog -Message "----------------------------------------------------------" -Level INFO

# ------------------------------------------------------------------------------
# 5. Render Mobile Pairing QR Code in Terminal
# ------------------------------------------------------------------------------
try {
  $qrAscii = Invoke-RestMethod -Uri "https://qrenco.de/$targetUrl" -Headers @{ "User-Agent" = "curl/10.0.0" } -Method Get -TimeoutSec 5
  Write-Host "`nScan with phone camera (while WireGuard is active):`n" -ForegroundColor Yellow
  Write-Host $qrAscii
} catch {
  Write-ToolLog -Message "Could not render terminal QR code ($($_.Exception.Message)). Connect manually via Direct URL." -Level WARN
}

# ------------------------------------------------------------------------------
# 6. Launch Self-Contained Antigravity Remote Bridge HTTP Server
# ------------------------------------------------------------------------------
Write-ToolLog -Message "`n[ACTION] Launching Antigravity Remote Control Bridge daemon on $targetUrl..." -Level ACTION

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://+:${selectedPort}/")
try {
  $listener.Start()
  Write-ToolLog -Message "HTTP Bridge Listener active on http://${BindIp}:${selectedPort}/ (Press Ctrl+C to terminate)" -Level ACTION
} catch {
  Write-ToolLog -Message "Retrying on localhost prefix: $($_.Exception.Message)" -Level DEBUG
  $listener = [System.Net.HttpListener]::new()
  $listener.Prefixes.Add("http://localhost:${selectedPort}/")
  $listener.Start()
}

$mobileHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Antigravity Remote Bridge</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { background: #0d1117; color: #c9d1d9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 12px; height: 100vh; display: flex; flex-direction: column; }
        header { display: flex; justify-content: space-between; align-items: center; padding-bottom: 8px; border-bottom: 1px solid #30363d; margin-bottom: 8px; }
        h1 { font-size: 15px; color: #58a6ff; font-weight: 700; display: flex; align-items: center; gap: 6px; }
        .status-pill { font-size: 10px; background: rgba(56, 139, 253, 0.2); color: #58a6ff; border: 1px solid rgba(56, 139, 253, 0.4); padding: 2px 6px; border-radius: 10px; font-weight: 600; }
        #terminal { flex: 1; background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 10px; font-family: monospace; font-size: 12px; overflow-y: auto; white-space: pre-wrap; word-break: break-word; color: #7ee787; margin-bottom: 8px; }
        .quick-bar { display: flex; gap: 6px; overflow-x: auto; padding-bottom: 6px; margin-bottom: 6px; }
        .btn-quick { background: #21262d; border: 1px solid #30363d; color: #c9d1d9; font-size: 11px; padding: 6px 10px; border-radius: 6px; white-space: nowrap; cursor: pointer; }
        .input-box { display: flex; gap: 6px; }
        input { flex: 1; background: #161b22; border: 1px solid #30363d; border-radius: 6px; color: #fff; padding: 10px; font-size: 13px; outline: none; }
        input:focus { border-color: #58a6ff; }
        button.btn-send { background: #238636; border: 1px solid rgba(240, 246, 252, 0.1); color: #fff; padding: 10px 16px; border-radius: 6px; font-weight: 700; cursor: pointer; }
    </style>
</head>
<body>
    <header>
        <h1>⚡ Antigravity Remote</h1>
        <span class="status-pill">Connected (WireGuard)</span>
    </header>
    <div id="terminal">========================================================\n Antigravity Mobile Terminal Ready\n Host: D5P0-SSD980-Z\n========================================================\nType a command or click a quick action below.\n</div>
    <div class="quick-bar">
        <button class="btn-quick" onclick="runCmd('showtools -NoBrowser')">🛠️ ShowTools</button>
        <button class="btn-quick" onclick="runCmd('showactions')">📋 ShowActions</button>
        <button class="btn-quick" onclick="runCmd('pwsh -File tools/Export-LCMRules.ps1')">📜 Export Rules</button>
        <button class="btn-quick" onclick="runCmd('pwsh -File tools/Restore-SystemSettings.ps1')">🛡️ Restore Settings</button>
    </div>
    <div class="input-box">
        <input type="text" id="cmdInput" placeholder="Enter command or tool..." onkeydown="if(event.key==='Enter') sendCommand()">
        <button class="btn-send" onclick="sendCommand()">Send</button>
    </div>
    <script>
        const token = new URLSearchParams(window.location.search).get('token') || '';
        function appendTerm(txt) {
            const t = document.getElementById('terminal');
            t.innerText += '\n' + txt;
            t.scrollTop = t.scrollHeight;
        }
        async function runCmd(cmd) {
            document.getElementById('cmdInput').value = cmd;
            sendCommand();
        }
        async function sendCommand() {
            const inp = document.getElementById('cmdInput');
            const cmd = inp.value.trim();
            if (!cmd) return;
            inp.value = '';
            appendTerm('>> ' + cmd);
            try {
                const res = await fetch('/api/exec?token=' + encodeURIComponent(token), {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ command: cmd })
                });
                const data = await res.json();
                appendTerm(data.output || '(No output)');
            } catch(e) {
                appendTerm('Error: ' + e.message);
            }
        }
    </script>
</body>
</html>
"@

while ($listener.IsListening) {
  try {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    $reqToken = $request.QueryString["token"]
    if ($reqToken -ne $sessionToken) {
      $response.StatusCode = 403
      $bytes = [System.Text.Encoding]::UTF8.GetBytes("Forbidden: Invalid authentication token.")
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
      $response.Close()
      continue
    }

    if ($request.HttpMethod -eq "GET" -and ($request.Url.AbsolutePath -eq "/" -or $request.Url.AbsolutePath -eq "")) {
      $response.ContentType = "text/html; charset=utf-8"
      $response.StatusCode = 200
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($mobileHtml)
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
      $response.Close()
    } elseif ($request.HttpMethod -eq "POST" -and $request.Url.AbsolutePath -eq "/api/exec") {
      $reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
      $body = $reader.ReadToEnd() | ConvertFrom-Json
      $cmdToRun = $body.command
      
      $execOutput = ""
      try {
        $execOutput = (pwsh.exe -NoProfile -ExecutionPolicy Bypass -Command $cmdToRun 2>&1 | Out-String)
      } catch {
        $execOutput = $_.Exception.Message
      }

      $jsonResp = @{ output = $execOutput } | ConvertTo-Json
      $response.ContentType = "application/json; charset=utf-8"
      $response.StatusCode = 200
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonResp)
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
      $response.Close()
    } else {
      $response.StatusCode = 404
      $response.Close()
    }
  } catch {
    # Keep listening on error
  }
}

