<#
Module: LcmDaemon/Classes/DaemonActionController.ps1
Purpose: Object-Oriented controller routing and executing daemon REST operations.
Path: LCM_Inventory/modules/LcmDaemon/Classes/DaemonActionController.ps1
Authors: Rolf, LCM_AI Engine
Version: 10.2.2
Date: 2026-11-09 19:05:00
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

class DaemonActionController {
  [DaemonEnvironment]$Env
  [System.Diagnostics.Process]$ActiveProcess = $null

  DaemonActionController([DaemonEnvironment]$env) {
    $this.Env = $env
  }

  [hashtable] AbortExecution() {
    $proc = $this.ActiveProcess
    if ($proc -and -not $proc.HasExited) {
      $this.Env.Log("Aborting active execution process PID $($proc.Id)...", 'WARN')
      try {
        $proc.Kill($true)
        $this.ActiveProcess = $null
        return @{ status = "ABORTED"; pid = $proc.Id; success = $true }
      } catch {
        $this.Env.Log("Error aborting process: $($_.Exception.Message)", 'WARN')
        return @{ status = "ERROR"; error = $_.Exception.Message; success = $false }
      }
    }
    return @{ status = "IDLE"; message = "No active execution process to abort."; success = $true }
  }

  [hashtable] GetStatus() {
    $uptimeSec = [int](([System.DateTime]::Now - $this.Env.StartTime).TotalSeconds)
    $process = [System.Diagnostics.Process]::GetCurrentProcess()
    return @{
      status       = "ONLINE"
      version      = $this.Env.Version
      port         = $this.Env.Port
      pid          = $this.Env.Pid
      sessionId    = $this.Env.SessionId
      user         = $this.Env.User
      uptimeSec    = $uptimeSec
      workingSetMB = [math]::Round($process.WorkingSet64 / 1MB, 2)
      logFile      = $this.Env.LogFile
    }
  }

  [hashtable] OpenTarget([DaemonOpenRequest]$req) {
    $target = if ($req.Url) { $req.Url } else { $req.FilePath }
    if ([string]::IsNullOrWhiteSpace($target)) {
      throw [System.ArgumentException]::new("Missing 'url' or 'filePath' in request payload.")
    }

    $this.Env.Log("Opening target: $target (Args: $($req.Args), Foreground: $($req.Foreground))", 'ACTION')
    $cleanPath = $target
    if ($cleanPath -notmatch '[#?]' -and $cleanPath -like 'file:///*') {
      $cleanPath = $cleanPath.Substring(8).Replace('/', '\')
    } elseif ($cleanPath -notmatch '[#?]' -and $cleanPath -like 'file://*') {
      $cleanPath = $cleanPath.Substring(7).Replace('/', '\')
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $cleanPath
    if (-not [string]::IsNullOrWhiteSpace($req.Args)) {
      $psi.Arguments = $req.Args
    }
    $psi.UseShellExecute = $true
    $proc = [System.Diagnostics.Process]::Start($psi)

    if ($req.Foreground) {
      Start-Sleep -Milliseconds 400
      $wsh = New-Object -ComObject WScript.Shell
      if ($req.Title) {
        $null = $wsh.AppActivate($req.Title)
        if ($cleanPath -like "*notepad*") {
          $null = $wsh.AppActivate("Notepad")
        }
      } else {
        $isBrowserTarget = ($cleanPath -like "*.html" -or $cleanPath -like "*.htm" -or $target -like "http*")
        if ($isBrowserTarget) {
          $null = $wsh.AppActivate("LCM Tool Explorer")
          $null = $wsh.AppActivate("SHOW_TOOLS")
        } elseif ($cleanPath -like "*notepad*") {
          $null = $wsh.AppActivate("Notepad")
        } elseif ($proc) {
          try {
            $null = $proc.WaitForInputIdle(500)
            if ($proc.MainWindowTitle) {
              $null = $wsh.AppActivate($proc.MainWindowTitle)
            } elseif ($proc.ProcessName) {
              $null = $wsh.AppActivate($proc.ProcessName)
            }
          } catch {}
        }
      }
    }
    return @{ status = "OPENED"; target = $target; args = $req.Args }
  }

  [void] UpdateScriptDescription([PSCustomObject]$tool, [string]$newDesc) {
    if ($tool.RelativePath -like "*.ps1" -or $tool.RelativePath -like "*.psm1") {
      $scriptPath = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, $tool.RelativePath)
      if (Test-Path $scriptPath) {
        $content = Get-Content -LiteralPath $scriptPath -Raw
        $pattern = '(?ms)(<#.*?\.DESCRIPTION\s*\r?\n)(.*?)(?=\r?\n\s*\.|\r?\n\s*#>)'
        if ($content -match $pattern) {
          $newContent = [regex]::Replace($content, $pattern, "`${1}  $newDesc")
          Set-Content -LiteralPath $scriptPath -Value $newContent -Encoding UTF8
          $this.Env.Log("Updated script header description for $($tool.Name)", 'ACTION')
        }
      }
    }
  }

  [hashtable] ForegroundWindow([string]$title) {
    return $this.ForegroundWindow($title, $true)
  }

  [hashtable] ForegroundWindow([string]$title, [bool]$refresh) {
    if ([string]::IsNullOrWhiteSpace($title)) {
      throw [System.ArgumentException]::new("Missing 'title' in request payload.")
    }
    $this.Env.Log("Activating window: $title (refresh: $refresh)", 'ACTION')
    $wsh = New-Object -ComObject WScript.Shell
    $activated = $false
    try {
      $proc = Get-Process | Where-Object { $_.MainWindowTitle -like "*$title*" } | Select-Object -First 1
      if ($proc) {
        $activated = $wsh.AppActivate($proc.Id)
      }
    } catch {}

    if (-not $activated) {
      try {
        $activated = $wsh.AppActivate($title)
      } catch {}
    }

    if ($activated -and $refresh) {
      Start-Sleep -Milliseconds 120
      $wsh.SendKeys("^{F5}")
    }
    return @{ status = "ACTIVATED"; title = $title; success = [bool]$activated; refreshed = [bool]($activated -and $refresh) }
  }

  [hashtable] ExecuteCommand([DaemonExecuteRequest]$req) {
    if ([string]::IsNullOrWhiteSpace($req.Command)) {
      throw [System.ArgumentException]::new("Missing 'command' in request payload.")
    }
    $cmd = $req.Command.Trim()
    $wsRoot = $this.Env.WorkspaceRoot

    # Defense-in-depth: If command is actually an HTML file or URL, route to OpenTarget
    $cleanCmd = $cmd.Trim(' &"')
    if ($cleanCmd -match '(?i)\.html?(?:[#?].*)?$' -or $cleanCmd -match '^https?://' -or $cleanCmd -match '^file:') {
      $openReq = [DaemonOpenRequest]::new()
      $openReq.Url = if ($cleanCmd -match '^https?://' -or $cleanCmd -match '^file:') { $cleanCmd } else { [System.Uri]::new($cleanCmd).AbsoluteUri }
      $openReq.Foreground = $true
      $openReq.Title = "LCM Mission Control"
      return $this.OpenTarget($openReq)
    }

    # If the command references relative paths or pwsh wrapper, resolve with workspace root and convert to direct invocation
    if ($cmd -match '(?i)^pwsh(?:\.exe)?\s+(?:.*?\s+)?-File\s+"?([^"\s]+)"?(.*)$') {
      $scriptPath = $Matches[1]
      $extraArgs = $Matches[2]
      if (-not [System.IO.Path]::IsPathRooted($scriptPath)) {
        $scriptPath = [System.IO.Path]::Combine($wsRoot, $scriptPath)
      }
      $cmdToRun = "& `"$scriptPath`"$extraArgs"
    } else {
      if ($cmd.StartsWith('"') -and -not $cmd.StartsWith('&')) {
        $cmdToRun = "& $cmd"
      } elseif ($cmd -match '^(?:[A-Za-z]:\\[^"''\s]+\s+[^"''\s]+|\S+\s+\S+)' -and $cmd -notmatch '^&') {
        if ($cmd -match '(?i)^([A-Za-z]:\\[^"]*?\.exe)(?:\s+(.*))?$') {
          $exePath = $Matches[1]
          $remArgs = if ($Matches.Count -gt 2) { $Matches[2] } else { "" }
          $cmdToRun = "& `"$exePath`" $remArgs"
        } else {
          $cmdToRun = $cmd
        }
      } else {
        $cmdToRun = $cmd
      }
    }

    # Synchronous Execution with universal stdout/stderr capture (CRP-309 Clause 2)
    if ($req.Sync) {
      if ($cmdToRun -notmatch '(?i)(?:^|;|\s)exit(?:\s*;\s*|\s*$)') {
        $cmdToRun = "$cmdToRun; exit `$LASTEXITCODE"
      }
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      $this.Env.Log("Executing synchronous command: $cmdToRun in $wsRoot (Elevated: $($req.Elevated))", 'ACTION')
      $encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmdToRun))
      $pinfo = [System.Diagnostics.ProcessStartInfo]::new()
      $pinfo.FileName = "pwsh.exe"
      $pinfo.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encodedCmd"
      $pinfo.WorkingDirectory = $wsRoot
      $pinfo.RedirectStandardOutput = $true
      $pinfo.RedirectStandardError = $true
      $pinfo.UseShellExecute = $false
      $pinfo.CreateNoWindow = $true
      $pinfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
      $pinfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

      $proc = [System.Diagnostics.Process]::Start($pinfo)
      $this.ActiveProcess = $proc
      $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
      $stderrTask = $proc.StandardError.ReadToEndAsync()

      $timeoutMs = if ($req.TimeoutMs -gt 0) {
        $req.TimeoutMs
      } elseif ($cmdToRun -match '(?i)push|gemini|export|maintenance|macrium|bcr|baseline') {
        300000
      } else {
        60000
      }

      try {
        $hasExited = $proc.WaitForExit($timeoutMs)
        $sw.Stop()
        if ($hasExited) {
          [void][System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask), 5000)
          $exitCode = $proc.ExitCode
          $status = if ($exitCode -eq 0) { "COMPLETED" } else { "ERROR" }

          # Record tool intent execution metrics (CRP-315)
          try {
            $catModule = [System.IO.Path]::Combine($wsRoot, 'LCM_Inventory\modules\LcmToolCatalog.psm1')
            if (Test-Path -LiteralPath $catModule) {
              Import-Module -Name $catModule -Force
              Update-LcmToolIntentCall -CommandOrPath $cmd -DurationMs $sw.ElapsedMilliseconds
            }
          } catch {}

          return @{
            status     = $status
            exitCode   = $exitCode
            stdout     = $stdoutTask.Result
            stderr     = $stderrTask.Result
            durationMs = $sw.ElapsedMilliseconds
            command    = $cmdToRun
            elevated   = [bool]$req.Elevated
          }
        } else {
          $this.Env.Log("Command timed out after ${timeoutMs}ms: $cmdToRun", 'WARN')
          try { $proc.Kill($true) } catch {}
          return @{
            status     = "TIMEOUT"
            exitCode   = -1
            stdout     = if ($stdoutTask.IsCompleted) { $stdoutTask.Result } else { "" }
            stderr     = "Command execution timed out after $([math]::Round($timeoutMs / 1000))s"
            durationMs = $sw.ElapsedMilliseconds
            command    = $cmdToRun
            elevated   = [bool]$req.Elevated
          }
        }
      } finally {
        $this.ActiveProcess = $null
      }
    }

    $this.Env.Log("Dispatching execution: $cmdToRun (Elevated: $($req.Elevated), NoExit: $($req.NoExit), Cwd: $wsRoot)", 'ACTION')
    $noExitFlag = if ($req.NoExit) { "-NoExit " } else { "" }

    if (-not $req.NoExit -and $cmdToRun -notmatch '(?i)(?:^|;|\s)exit(?:\s*;\s*|\s*$)') {
      $cmdToRun = "$cmdToRun; exit"
    }

    $windowStyle = if (-not [string]::IsNullOrWhiteSpace($req.WindowStyle)) {
      $req.WindowStyle
    } elseif ($req.NoExit -or $req.Elevated) {
      "Normal"
    } else {
      "Hidden"
    }

    # Direct execution optimization for Windows GUI executables (e.g. BCompare.exe)
    if (-not $req.Elevated -and -not $req.NoExit -and $cmdToRun -match '^&\s*"([^"]+\.exe)"(?:\s+(.*))?$') {
      $directExe = $Matches[1]
      $directArgs = if ($Matches.Count -gt 2 -and $Matches[2]) { $Matches[2] } else { "" }
      $this.Env.Log("Directly starting GUI process: $directExe $directArgs (WindowStyle: $windowStyle)", 'ACTION')
      if ([string]::IsNullOrWhiteSpace($directArgs)) {
        Start-Process -FilePath $directExe -WorkingDirectory $wsRoot -WindowStyle $windowStyle
      } else {
        Start-Process -FilePath $directExe -ArgumentList $directArgs -WorkingDirectory $wsRoot -WindowStyle $windowStyle
      }
      return @{ status = "DISPATCHED"; command = $cmdToRun; directExe = $directExe; elevated = $false; noExit = $false; windowStyle = $windowStyle }
    }

    if ($req.Elevated) {
      # Prohibition of Opaque UAC Prompts (RULE-ELEV-005): Never use -EncodedCommand with -Verb RunAs.
      # Elevated dispatch requires transparent named script paths so the operator can inspect target and arguments.
      if ($cmdToRun -match '^&\s*"([^"]+\.ps1)"(?:\s+(.*))?$') {
        $elevScript = $Matches[1]
        $elevArgs = if ($Matches.Count -gt 2 -and $Matches[2]) { $Matches[2] } else { "" }
        $argStr = "-NoProfile -ExecutionPolicy Bypass $noExitFlag-File `"$elevScript`" $elevArgs".Trim()
        $this.Env.Log("Dispatching transparent elevated script: $argStr", 'ACTION')
        Start-Process -FilePath "pwsh.exe" -ArgumentList $argStr -WorkingDirectory $wsRoot -Verb RunAs -WindowStyle $windowStyle
      } else {
        $this.Env.Log("Elevated dispatch rejected: command '$cmdToRun' is not a transparent .ps1 invocation (RULE-ELEV-005)", 'WARN')
        return @{
          status   = "DENIED"
          exitCode = 403
          command  = $cmdToRun
          stderr   = "Elevated execution requires a transparent script path (RULE-ELEV-005); opaque encoded commands are prohibited."
          elevated = $true
        }
      }
    } else {
      $encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmdToRun))
      Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass $noExitFlag-EncodedCommand $encodedCmd" -WorkingDirectory $wsRoot -WindowStyle $windowStyle
    }

    # Record tool intent invocation metrics (CRP-315)
    try {
      $catModule = [System.IO.Path]::Combine($wsRoot, 'LCM_Inventory\modules\LcmToolCatalog.psm1')
      if (Test-Path -LiteralPath $catModule) {
        Import-Module -Name $catModule -Force
        Update-LcmToolIntentCall -CommandOrPath $cmd -DurationMs 0.0
      }
    } catch {}

    return @{ status = "DISPATCHED"; command = $cmdToRun; elevated = $req.Elevated; noExit = $req.NoExit; windowStyle = $windowStyle }
  }

  [hashtable] ExecuteActionIntent([DaemonActionIntent]$intent) {
    if ([string]::IsNullOrWhiteSpace($intent.Target)) {
      throw [System.ArgumentException]::new("Missing 'target' in action intent payload.")
    }

    $wsRoot = $this.Env.WorkspaceRoot

    # 1. Authorize against Security Gateway (CRP-309 Clause 10)
    $auth = [LcmSecurityGateway]::Authorize($intent, $wsRoot)
    if (-not $auth.Authorized) {
      [LcmSecurityGateway]::LogAudit($auth, 403, 0, $wsRoot)
      return @{
        status     = "DENIED"
        exitCode   = 403
        stdout     = ""
        stderr     = $auth.Reason
        durationMs = 0
        target     = $intent.Target
        authorized = $false
      }
    }

    # Dedicated atomic registry handler (RULE-ELEV-007)
    $targetName = $intent.Target.Trim()
    if ($targetName -eq 'Set-LcmRegistryValue') {
      $keyPath = if ($intent.Parameters.ContainsKey('KeyPath')) { [string]$intent.Parameters['KeyPath'] } else { '' }
      $name = if ($intent.Parameters.ContainsKey('Name')) { [string]$intent.Parameters['Name'] } else { '' }
      $val = if ($intent.Parameters.ContainsKey('Value')) { [string]$intent.Parameters['Value'] } else { '' }
      $pType = if ($intent.Parameters.ContainsKey('PropertyType') -and $intent.Parameters['PropertyType']) { [string]$intent.Parameters['PropertyType'] } else { 'String' }

      $isLegitimate = $keyPath -match '^(?i)HKLM:\\SOFTWARE\\LCM(?:\\[^\\]+)*$' -or
                      $keyPath -match '^(?i)HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment$'
      if (-not $isLegitimate) {
        $this.Env.Log("Registry write rejected: '$keyPath' is outside legitimate LCM namespaces (RULE-ELEV-007)", 'WARN')
        return @{
          status     = "DENIED"
          exitCode   = 403
          stdout     = ""
          stderr     = "Registry write rejected: '$keyPath' is outside legitimate LCM namespaces (RULE-ELEV-007)."
          durationMs = 0
          target     = $targetName
          authorized = $false
        }
      }

      $daemonElevated = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
      if ($daemonElevated) {
        try {
          if (-not (Test-Path -LiteralPath $keyPath)) { New-Item -Path $keyPath -Force | Out-Null }
          Set-ItemProperty -Path $keyPath -Name $name -Value $val -Type $pType -Force | Out-Null
          $this.Env.Log("Registry updated directly via elevated daemon: $keyPath\$name = '$val'", 'ACTION')
          return @{
            status     = "COMPLETED"
            exitCode   = 0
            stdout     = "Registry updated: $keyPath\$name = '$val'"
            stderr     = ""
            durationMs = 0
            target     = $targetName
            authorized = $true
          }
        } catch {
          $this.Env.Log("Failed direct registry write: $($_.Exception.Message)", 'WARN')
          return @{
            status     = "ERROR"
            exitCode   = 1
            stdout     = ""
            stderr     = $_.Exception.Message
            durationMs = 0
            target     = $targetName
            authorized = $true
          }
        }
      } else {
        $this.Env.Log("Atomic registry write rejected: Port 9876 daemon is running un-elevated (RULE-ELEV-005)", 'WARN')
        return @{
          status     = "ERROR"
          exitCode   = 403
          stdout     = ""
          stderr     = "Atomic registry write requires elevated daemon context. Port 9876 daemon is running un-elevated."
          durationMs = 0
          target     = $targetName
          authorized = $true
        }
      }
    }

    # 2. Resolve target tool from catalog or direct script
    $scriptToRun = ""
    $isElevated = ($auth.Tier -eq 3)
    if ($intent.Options.ContainsKey('elevated') -and $intent.Options['elevated']) {
      $isElevated = $true
    }

    $rawCmdProvided = -not [string]::IsNullOrWhiteSpace($intent.Command)
    $hasExplicitParams = ($null -ne $intent.Parameters -and $intent.Parameters.Count -gt 0)

    # Separate base target name and any trailing arguments embedded in target string
    $baseTarget = $targetName
    $trailingArgs = ""
    if ($targetName -match '^([^\s]+)\s+(.+)$') {
      $baseTarget = $Matches[1].Trim()
      $trailingArgs = $Matches[2].Trim()
    }

    # Check if target matches tool_catalog.json entry
    $catalogPath = [System.IO.Path]::Combine($wsRoot, "LCM_Inventory\config\tool_catalog.json")
    $matchedCatalogTool = $null
    if (Test-Path -LiteralPath $catalogPath) {
      try {
        $rawCat = [System.IO.File]::ReadAllText($catalogPath, [System.Text.Encoding]::UTF8)
        $catalog = $rawCat | ConvertFrom-Json
        $toolsList = if ($catalog -is [System.Collections.IEnumerable] -and $catalog -isnot [PSCustomObject]) { $catalog } elseif ($catalog.PSObject.Properties['tools']) { $catalog.tools } else { @($catalog) }
        $normTarget = $baseTarget -replace '^(?:tools/|tools\\)?', '' -replace '\.ps1$', ''
        $matchedCatalogTool = @($toolsList | Where-Object {
          $_.Name -eq $baseTarget -or
          $_.ShortName -eq $baseTarget -or
          $_.Name -eq "$normTarget.ps1" -or
          $_.ShortName -eq ($normTarget -replace '[^A-Za-z0-9]', '') -or
          ($_.RelativePath -and ($baseTarget -like "*$($_.RelativePath)*" -or $baseTarget -like "*$($_.Name)*"))
        })[0]
        if ($null -ne $matchedCatalogTool -and ($matchedCatalogTool.Admin -or $matchedCatalogTool.Elevated)) {
          $isElevated = $true
        }
      } catch {}
    }

    # If raw command was provided without structured parameters, preserve it
    if ($rawCmdProvided -and -not $hasExplicitParams) {
      $fullCmd = $intent.Command.Trim()
    } else {
      if ($null -ne $matchedCatalogTool) {
        if ($matchedCatalogTool.RelativePath) {
          $absScript = [System.IO.Path]::Combine($wsRoot, $matchedCatalogTool.RelativePath)
          $scriptToRun = "& `"$absScript`""
        } elseif ($matchedCatalogTool.Command) {
          $scriptToRun = $matchedCatalogTool.Command
        }
      }

      if ([string]::IsNullOrWhiteSpace($scriptToRun)) {
        if ($baseTarget.EndsWith('.ps1') -or $baseTarget.EndsWith('.cmd')) {
          $candidate = [System.IO.Path]::Combine($wsRoot, $baseTarget)
          if (Test-Path -LiteralPath $candidate) {
            $scriptToRun = "& `"$candidate`""
          } else {
            $candidateTool = [System.IO.Path]::Combine($wsRoot, "LCM_Inventory\tools", $baseTarget)
            if (Test-Path -LiteralPath $candidateTool) {
              $scriptToRun = "& `"$candidateTool`""
            } else {
              $scriptToRun = $baseTarget
            }
          }
        } else {
          $candidatePs1 = [System.IO.Path]::Combine($wsRoot, "LCM_Inventory\tools", "$baseTarget.ps1")
          if (Test-Path -LiteralPath $candidatePs1) {
            $scriptToRun = "& `"$candidatePs1`""
          } else {
            $candidateCmd = [System.IO.Path]::Combine($wsRoot, "LCM_Inventory\DoT", "$baseTarget.cmd")
            if (Test-Path -LiteralPath $candidateCmd) {
              $scriptToRun = "& `"$candidateCmd`""
            } else {
              $scriptToRun = $baseTarget
            }
          }
        }
      }

      # 3. Assemble parameters from Intent DTO
      $argParts = @()
      if (-not [string]::IsNullOrWhiteSpace($trailingArgs)) {
        $argParts += $trailingArgs
      }
      if ($null -ne $intent.Parameters) {
        foreach ($key in $intent.Parameters.Keys) {
          $val = $intent.Parameters[$key]
          if ($val -is [bool] -or "$val" -eq 'True') {
            if ($val -eq $true -or "$val" -eq 'True') { $argParts += "-$key" }
          } elseif ($null -ne $val -and -not [string]::IsNullOrWhiteSpace("$val")) {
            $argParts += "-$key `"$val`""
          }
        }
      }
      $argsCombined = $argParts -join ' '

      # 4. Construct command string
      $fullCmd = if (-not [string]::IsNullOrWhiteSpace($argsCombined)) {
        "$scriptToRun $argsCombined"
      } else {
        $scriptToRun
      }
    }

    $execReq = [DaemonExecuteRequest]::new()
    $execReq.Command = $fullCmd
    $execReq.Elevated = $isElevated
    $execReq.Sync = if ($intent.Options.ContainsKey('sync')) { [bool]$intent.Options['sync'] } else { $true }
    $execReq.NoExit = if ($intent.Options.ContainsKey('noExit')) { [bool]$intent.Options['noExit'] } else { $false }
    if ($intent.Options.ContainsKey('timeoutMs')) {
      $execReq.TimeoutMs = [int]$intent.Options['timeoutMs']
    }

    # 5. Dispatch command
    $res = $this.ExecuteCommand($execReq)

    # 6. Record Audit Log Receipt
    $exitCode = if ($res.ContainsKey('exitCode')) { [int]$res.exitCode } else { 0 }
    $durMs = if ($res.ContainsKey('durationMs')) { [int]$res.durationMs } else { 0 }
    [LcmSecurityGateway]::LogAudit($auth, $exitCode, $durMs, $wsRoot)

    return $res
  }

  [hashtable] OpenEditor([DaemonEditRequest]$req) {
    if ([string]::IsNullOrWhiteSpace($req.FilePath)) {
      $req.FilePath = "LCM_Inventory/scratch/cm_console_feed.txt"
    }
    $fullPath = if ([System.IO.Path]::IsPathRooted($req.FilePath)) { $req.FilePath } else { [System.IO.Path]::Combine($this.Env.WorkspaceRoot, $req.FilePath) }

    # If inline content is provided, write it to the target file
    if (-not [string]::IsNullOrEmpty($req.Content)) {
      $dir = [System.IO.Path]::GetDirectoryName($fullPath)
      if (-not [string]::IsNullOrEmpty($dir) -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
      }
      Set-Content -LiteralPath $fullPath -Value $req.Content -Encoding UTF8
    }

    if (-not (Test-Path -LiteralPath $fullPath)) {
      throw [System.IO.FileNotFoundException]::new("File not found: $fullPath")
    }

    $editorPref = if ($req.Editor) { $req.Editor.ToLowerInvariant() } else { "" }

    # Notepad++ Candidates
    $nppCandidates = @(
      "D:\Tools\notepad++.exe",
      "C:\Program Files\Notepad++\notepad++.exe",
      "C:\Program Files (x86)\Notepad++\notepad++.exe"
    )
    $nppExe = $null
    foreach ($cand in $nppCandidates) {
      if (Test-Path -LiteralPath $cand) {
        $nppExe = $cand
        break
      }
    }

    # If Notepad is explicitly requested (for material not intended for edits, transient displays, logs)
    if ($editorPref -eq 'notepad' -or $editorPref -eq 'txt' -or $editorPref -eq 'display') {
      $this.Env.Log("Opening in Notepad: $fullPath", 'ACTION')
      Start-Process -FilePath "notepad.exe" -ArgumentList "`"$fullPath`""
      return @{ status = "OPENED"; filePath = $fullPath; editor = "Notepad" }
    }

    # If Notepad++ is explicitly requested (editable source files, scripts)
    if ($editorPref -eq 'notepad++' -or $editorPref -eq 'npp') {
      if ($nppExe) {
        $this.Env.Log("Opening in Notepad++: $fullPath (Line: $($req.Line))", 'ACTION')
        $lineArg = if ($req.Line -gt 0) { "-n$($req.Line) " } else { "" }
        Start-Process -FilePath $nppExe -ArgumentList "$lineArg`"$fullPath`""
        return @{ status = "OPENED"; filePath = $fullPath; editor = "Notepad++" }
      } else {
        $this.Env.Log("Opening in Notepad fallback: $fullPath", 'ACTION')
        Start-Process -FilePath "notepad.exe" -ArgumentList "`"$fullPath`""
        return @{ status = "OPENED"; filePath = $fullPath; editor = "Notepad" }
      }
    }

    # Primary: Context-Aware IDE Selection (Stay inside whichever IDE entered the request)
    $antigravityCmd = @(
      "D:\Tools\Antigravity IDE\bin\antigravity-ide.cmd",
      "D:\Tools\Antigravity IDE\Antigravity IDE.exe"
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    $vscodeCmd = @(
      "D:\Tools\Microsoft VS Code\bin\code.cmd",
      "D:\Tools\Microsoft VS Code\Code.exe",
      (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd"),
      (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\Code.exe"),
      (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd"),
      (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code Insiders\Code - Insiders.exe")
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    $targetIde = $null
    $editorName = "IDE"

    # 1. Explicit caller preference passed in request
    if ($editorPref -match '^(?i)(?:antigravity|agy|anti)') {
      $targetIde = $antigravityCmd
      $editorName = "Antigravity IDE"
    } elseif ($editorPref -match '^(?i)(?:vscode|code)') {
      $targetIde = $vscodeCmd
      $editorName = "VS Code"
    } elseif ($editorPref -and (Test-Path -LiteralPath $editorPref)) {
      $targetIde = $editorPref
      $editorName = [System.IO.Path]::GetFileNameWithoutExtension($editorPref)
    }

    # 2. Dynamic environment detection: stay inside whichever IDE is currently active/running
    if (-not $targetIde) {
      $antigravityRunning = @(Get-Process -Name 'Antigravity IDE' -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 -or $_.MainWindowTitle }).Count -gt 0
      $vscodeRunning = @(Get-Process -Name 'Code' -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 -or $_.MainWindowTitle }).Count -gt 0

      if ($antigravityRunning -and -not $vscodeRunning) {
        $targetIde = $antigravityCmd
        $editorName = "Antigravity IDE"
      } elseif ($vscodeRunning -and -not $antigravityRunning) {
        $targetIde = $vscodeCmd
        $editorName = "VS Code"
      } elseif ($antigravityRunning -and $vscodeRunning) {
        # Both IDEs are running: inspect foreground window process
        $fgProcName = ""
        try {
          $fgType = 'LcmFgDetect' -as [type]
          if (-not $fgType) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LcmFgDetect {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
'@
            $fgType = 'LcmFgDetect' -as [type]
          }
          if ($fgType) {
            $fgHwnd = $fgType.GetMethod('GetForegroundWindow').Invoke($null, $null)
            $params = [object[]]@($fgHwnd, [uint32]0)
            [void]$fgType.GetMethod('GetWindowThreadProcessId').Invoke($null, $params)
            $fgPid = [uint32]$params[1]
            if ($fgPid -gt 0) {
              $fgProc = Get-Process -Id $fgPid -ErrorAction SilentlyContinue
              if ($fgProc) { $fgProcName = $fgProc.ProcessName }
            }
          }
        } catch {}

        if ($fgProcName -like "*Code*") {
          $targetIde = $vscodeCmd
          $editorName = "VS Code"
        } else {
          $targetIde = $antigravityCmd
          $editorName = "Antigravity IDE"
        }
      } else {
        # Neither IDE is currently running: fallback to whichever is installed
        if ($antigravityCmd) {
          $targetIde = $antigravityCmd
          $editorName = "Antigravity IDE"
        } elseif ($vscodeCmd) {
          $targetIde = $vscodeCmd
          $editorName = "VS Code"
        }
      }
    }

    if ($targetIde) {
      $this.Env.Log("Opening in ${editorName}: $fullPath (Line: $($req.Line))", 'ACTION')
      $lineArg = if ($req.Line -gt 0) { "-g `"$fullPath`":$($req.Line)" } else { "-g `"$fullPath`"" }
      if ([System.IO.Path]::GetExtension($targetIde).Equals('.cmd', [System.StringComparison]::OrdinalIgnoreCase)) {
        Start-Process -FilePath $env:ComSpec -ArgumentList "/c `"`"$targetIde`" $lineArg`"" -WindowStyle Hidden
      } else {
        Start-Process -FilePath $targetIde -ArgumentList $lineArg
      }
      return @{ status = "OPENED"; filePath = $fullPath; editor = $editorName }
    }

    if ($nppExe) {
      $this.Env.Log("Opening in Notepad++: $fullPath (Line: $($req.Line))", 'ACTION')
      $lineArg = if ($req.Line -gt 0) { "-n$($req.Line) " } else { "" }
      Start-Process -FilePath $nppExe -ArgumentList "$lineArg`"$fullPath`""
      return @{ status = "OPENED"; filePath = $fullPath; editor = "Notepad++" }
    } else {
      $this.Env.Log("Opening in Notepad: $fullPath", 'ACTION')
      Start-Process -FilePath "notepad.exe" -ArgumentList "`"$fullPath`""
      return @{ status = "OPENED"; filePath = $fullPath; editor = "Notepad" }
    }
  }

  [hashtable] ShowToolHelp([DaemonHelpRequest]$req) {
    $rel = if (-not [string]::IsNullOrWhiteSpace($req.RelativePath)) { $req.RelativePath } else { $req.FilePath }
    if ([string]::IsNullOrWhiteSpace($rel)) {
      throw [System.ArgumentException]::new("Missing 'relativePath' or 'filePath' in request payload.")
    }
    $fullPath = if ([System.IO.Path]::IsPathRooted($rel)) { $rel } else { [System.IO.Path]::Combine($this.Env.WorkspaceRoot, $rel) }
    if (-not (Test-Path -LiteralPath $fullPath)) {
      throw [System.IO.FileNotFoundException]::new("Tool file not found: $fullPath")
    }

    $ext = [System.IO.Path]::GetExtension($fullPath).ToLowerInvariant()
    $toolStem = [System.IO.Path]::GetFileNameWithoutExtension($fullPath)
    $scratchDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "lcm")
    if (-not (Test-Path -LiteralPath $scratchDir)) {
      New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
    }
    $helpOutFile = [System.IO.Path]::Combine($scratchDir, "help_${toolStem}.txt")

    $this.Env.Log("Extracting help for $fullPath -> $helpOutFile", 'ACTION')

    $helpContent = ""
    if ($ext -in @('.ps1', '.psm1')) {
      $helpContent = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$fullPath' -h" 2>&1 | Out-String
    } elseif ($ext -eq '.py') {
      $helpContent = & python "$fullPath" -h 2>&1 | Out-String
    } elseif ($ext -in @('.cmd', '.bat')) {
      $helpContent = & cmd.exe /c "`"$fullPath`" /?" 2>&1 | Out-String
    } else {
      $helpContent = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8
    }

    if ([string]::IsNullOrWhiteSpace($helpContent)) {
      $helpContent = "No CLI help text produced by '$toolStem -h'."
    }

    $header = "========================================================================`r`n" +
              "  LCM TOOL HELP: $toolStem`r`n" +
              "  File: $fullPath`r`n" +
              "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n" +
              "========================================================================`r`n`r`n"
    Set-Content -LiteralPath $helpOutFile -Value ($header + $helpContent) -Encoding UTF8

    Start-Process -FilePath "notepad.exe" -ArgumentList "`"$helpOutFile`""
    return @{ status = "OPENED"; helpFile = $helpOutFile; editor = "notepad.exe" }
  }

  [hashtable] QueryCleanup([DaemonCleanupQueryRequest]$req) {
    $baseStem = if ($req.ToolName) { [System.IO.Path]::GetFileNameWithoutExtension($req.ToolName) } else { $req.ShortName }
    $logDirs = @(
      [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\data\logs\lcm'),
      [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\data\logs\lcm-internal'),
      [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'tools\logs'),
      [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\logs'),
      [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\data\logs')
    )
    $archiveDir = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\data\retired_tools')

    $logFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    foreach ($ld in $logDirs) {
      if (Test-Path -LiteralPath $ld) {
        $matched = @(Get-ChildItem -Path $ld -File -ErrorAction SilentlyContinue | Where-Object {
          $_.Name -like "$baseStem-*" -or ($req.ShortName -and $_.Name -like "$($req.ShortName)-*") -or $_.Name -like "*$baseStem*"
        })
        foreach ($m in $matched) { $logFiles.Add($m) }
      }
    }
    $logMeas = $logFiles | Measure-Object -Property Length -Sum
    $logBytes = if ($logMeas -and $logMeas.PSObject.Properties['Sum'] -and $logMeas.Sum) { $logMeas.Sum } else { 0 }

    $toolArchiveDir = [System.IO.Path]::Combine($archiveDir, $baseStem)
    $archiveFiles = @()
    if (Test-Path $toolArchiveDir) {
      $archiveFiles = @(Get-ChildItem -Path $toolArchiveDir -File -Recurse -ErrorAction SilentlyContinue)
    }
    $archMeas = $archiveFiles | Measure-Object -Property Length -Sum
    $archiveBytes = if ($archMeas -and $archMeas.PSObject.Properties['Sum'] -and $archMeas.Sum) { $archMeas.Sum } else { 0 }

    return @{
      status       = "OK"
      toolName     = $req.ToolName
      shortName    = $req.ShortName
      logCount     = $logFiles.Count
      logBytes     = $logBytes
      archiveCount = $archiveFiles.Count
      archiveBytes = $archiveBytes
    }
  }

  [hashtable] ExecuteCleanup([DaemonCleanupRequest]$req) {
    $baseStem = if ($req.ToolName) { [System.IO.Path]::GetFileNameWithoutExtension($req.ToolName) } else { $req.ShortName }
    $deletedCount = 0
    $freedBytes = 0

    if ($req.PurgeLogs) {
      $logDirs = @(
        [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\data\logs\lcm'),
        [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\data\logs\lcm-internal'),
        [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'tools\logs'),
        [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\logs'),
        [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\data\logs')
      )
      foreach ($ld in $logDirs) {
        if (Test-Path -LiteralPath $ld) {
          $logsToPurge = @(Get-ChildItem -Path $ld -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -like "$baseStem-*" -or ($req.ShortName -and $_.Name -like "$($req.ShortName)-*") -or $_.Name -like "*$baseStem*"
          })
          foreach ($lf in $logsToPurge) {
            $freedBytes += $lf.Length
            Remove-Item -LiteralPath $lf.FullName -Force -ErrorAction SilentlyContinue
            $deletedCount++
          }
        }
      }
    }

    if ($req.PurgeArchive) {
      $toolArchiveDir = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, "LCM_Inventory\data\retired_tools\$baseStem")
      if (Test-Path $toolArchiveDir) {
        $archToPurge = @(Get-ChildItem -Path $toolArchiveDir -File -Recurse -ErrorAction SilentlyContinue)
        foreach ($af in $archToPurge) {
          $freedBytes += $af.Length
          Remove-Item -LiteralPath $af.FullName -Force -ErrorAction SilentlyContinue
          $deletedCount++
        }
      }
    }

    $this.Env.Log("Cleaned up $deletedCount files ($freedBytes bytes) for $baseStem.", 'ACTION')
    return @{
      status       = "CLEANED"
      deletedCount = $deletedCount
      freedBytes   = $freedBytes
    }
  }

  [hashtable] RenameTool([DaemonRenameRequest]$req) {
    if ([string]::IsNullOrWhiteSpace($req.NewName) -or [string]::IsNullOrWhiteSpace($req.NewShortName)) {
      throw [System.ArgumentException]::new("Missing 'newName' or 'newShortName' in request payload.")
    }

    $this.Env.Log("Renaming tool: $($req.OldName) -> $($req.NewName) [ShortName: $($req.OldShortName) -> $($req.NewShortName)]", 'ACTION')

    if ($req.OldName -ne $req.NewName -and -not [string]::IsNullOrWhiteSpace($req.RelativePath)) {
      $sourceFullPath = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, $req.RelativePath)
      if (Test-Path -LiteralPath $sourceFullPath) {
        $sourceDir = [System.IO.Path]::GetDirectoryName($sourceFullPath)
        $newFullPath = [System.IO.Path]::Combine($sourceDir, $req.NewName)
        Rename-Item -LiteralPath $sourceFullPath -NewName $req.NewName -Force
        $this.Env.Log("Renamed physical file: $sourceFullPath -> $newFullPath", 'ACTION')
      }
    }

    # Update ShortName directly in authoritative tool_catalog.json
    $catalogPath = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\config\tool_catalog.json')
    if (Test-Path -LiteralPath $catalogPath) {
      try {
        $cat = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $entry = $cat | Where-Object { $_.Name -eq $req.OldName -or $_.Name -eq $req.NewName }
        if ($entry) {
          $entry.Name = $req.NewName
          $entry.ShortName = $req.NewShortName
          if ($null -ne $req.Aliases) {
            $entry.Aliases = @($req.Aliases)
          }
        }
        $cat | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $catalogPath -Encoding UTF8
        $this.Env.Log("Updated authoritative catalog entry: $($req.NewName) -> $($req.NewShortName)", 'ACTION')
      } catch {}
    }

    # Persist ShortName and Aliases overrides to tool_catalog_overrides.json
    $overridesPath = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\config\tool_catalog_overrides.json')
    try {
      $overrides = if (Test-Path $overridesPath) { Get-Content -LiteralPath $overridesPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [PSCustomObject]@{} }
      $targetKey = if (-not [string]::IsNullOrWhiteSpace($req.RelativePath)) { $req.RelativePath } else { $req.NewName }
      if (-not $overrides.PSObject.Properties[$targetKey]) {
        $overrides | Add-Member -MemberType NoteProperty -Name $targetKey -Value ([PSCustomObject]@{})
      }
      $overrides.$targetKey | Add-Member -MemberType NoteProperty -Name 'ShortName' -Value $req.NewShortName -Force
      if ($null -ne $req.Aliases) {
        $overrides.$targetKey | Add-Member -MemberType NoteProperty -Name 'Aliases' -Value @($req.Aliases) -Force
      }
      $overrides | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $overridesPath -Encoding UTF8
      $this.Env.Log("Persisted ShortName/Aliases override for $targetKey -> $($req.NewShortName)", 'ACTION')
    } catch {}

    $updateScript = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\tools\Update-ToolCatalog.ps1')
    if (Test-Path -LiteralPath $updateScript) {
      & pwsh -File $updateScript -Silent
    }

    # Recompile SHOW_TOOLS.html to reflect changes
    $showToolsScript = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\tools\Show-ToolsExplorer.ps1')
    if (Test-Path -LiteralPath $showToolsScript) {
      & pwsh -File $showToolsScript -NoLaunch
    }

    return @{
      status       = "RENAMED"
      newName      = $req.NewName
      newShortName = $req.NewShortName
      aliases      = $req.Aliases
    }
  }

  [hashtable] ArchiveTool([DaemonArchiveRequest]$req) {
    if ([string]::IsNullOrWhiteSpace($req.ToolName) -or [string]::IsNullOrWhiteSpace($req.RelativePath)) {
      throw [System.ArgumentException]::new("Missing 'toolName' or 'relativePath' in request payload.")
    }

    $sourceFullPath = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, $req.RelativePath)
    if (-not (Test-Path -LiteralPath $sourceFullPath)) {
      throw [System.IO.FileNotFoundException]::new("File not found: $sourceFullPath")
    }

    $baseStem = [System.IO.Path]::GetFileNameWithoutExtension($req.ToolName)
    $toolArchiveDir = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, "LCM_Inventory\data\retired_tools\$baseStem")
    if (-not (Test-Path -LiteralPath $toolArchiveDir)) { New-Item -ItemType Directory -Path $toolArchiveDir -Force | Out-Null }

    $timeTag = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
    $archiveTarget = [System.IO.Path]::Combine($toolArchiveDir, "${timeTag}_$($req.ToolName)")
    Move-Item -LiteralPath $sourceFullPath -Destination $archiveTarget -Force
    $this.Env.Log("Archived tool: $sourceFullPath -> $archiveTarget", 'ACTION')

    $updateScript = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\tools\Update-ToolCatalog.ps1')
    if (Test-Path -LiteralPath $updateScript) {
      & pwsh -File $updateScript -Silent
    }

    return @{
      status        = "ARCHIVED"
      archiveTarget = $archiveTarget
    }
  }

  [hashtable] SyncCatalogState([DaemonSyncRequest]$req, [string]$rawBody) {
    if (-not $req.DefeatSwitch) {
      $this.Env.Log("State sync rejected: Defeat switch is OFF.", 'INFO')
      return @{ status = "IGNORED"; reason = "Defeat switch disabled" }
    }

    $backupDir = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\data\reviews')
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
    $timeTag = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
    $backupFile = [System.IO.Path]::Combine($backupDir, "overrides_sync_$timeTag.json")

    [System.IO.File]::WriteAllText($backupFile, $rawBody, [System.Text.Encoding]::UTF8)
    $this.Env.Log("Saved sync snapshot: $backupFile", 'ACTION')

    # Maintain authoritative catalog directly in LCM_Inventory\config\tool_catalog.json
    $catalogPath = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\config\tool_catalog.json')
    $mergedCount = 0

    if ($null -ne $req.Overrides) {
      try {
        $cat = if (Test-Path $catalogPath) { Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { @() }
        $overrides = $req.Overrides

        # Persist dynamic runtime overrides to LCM_Inventory\config\tool_catalog_overrides.json
        $overridesPath = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\config\tool_catalog_overrides.json')
        $overridesJson = $overrides | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($overridesPath, $overridesJson, [System.Text.Encoding]::UTF8)

        foreach ($prop in $overrides.PSObject.Properties) {
          $toolKey = $prop.Name
          $modifications = $prop.Value

          $match = $cat | Where-Object { 
            ($_.PSObject.Properties['RelativePath'] -and $_.RelativePath -eq $toolKey) -or 
            $_.Name -eq $toolKey 
          }
          if ($match) {
            foreach ($m in @($match)) {
              if ($modifications.PSObject.Properties['ShortName']) { $m.ShortName = [string]$modifications.ShortName }
              if ($modifications.PSObject.Properties['NoExit']) { $m.NoExit = [bool]$modifications.NoExit }
              if ($modifications.PSObject.Properties['Role']) { $m.Role = [string]$modifications.Role }
              if ($modifications.PSObject.Properties['Audience']) { $m.Audience = [string]$modifications.Audience }
              if ($modifications.PSObject.Properties['Category']) { $m.Category = [string]$modifications.Category }
              if ($modifications.PSObject.Properties['Group']) { 
                $m.Group = [string]$modifications.Group 
                $m.Domain = [string]$modifications.Group
              }
              if ($modifications.PSObject.Properties['Domain']) { 
                $m.Domain = [string]$modifications.Domain 
                if (-not $modifications.PSObject.Properties['Group']) { $m.Group = [string]$modifications.Domain }
              }
              if ($modifications.PSObject.Properties['Subsystem']) { 
                $m.Group = [string]$modifications.Subsystem 
                $m.Domain = [string]$modifications.Subsystem
              }
              if ($modifications.PSObject.Properties['Description']) { 
                $m.Description = [string]$modifications.Description 
                $this.UpdateScriptDescription($m, $m.Description)
              }
            }
            $mergedCount++
          }
        }

        if ($mergedCount -gt 0) {
          $cat | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $catalogPath -Encoding UTF8
          $this.Env.Log("Merged $mergedCount overrides into authoritative catalog $catalogPath.", 'ACTION')

          # Regenerate trampolines and markdown docs
          $updateScript = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\tools\Update-ToolCatalog.ps1')
          if (Test-Path -LiteralPath $updateScript) {
            & pwsh -File $updateScript -Silent
          }

          # Recompile SHOW_TOOLS.html with latest catalog baseline
          $explorerScript = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\tools\Show-ToolsExplorer.ps1')
          if (Test-Path -LiteralPath $explorerScript) {
            & pwsh -File $explorerScript -NoLaunch
          }
        }
      } catch {
        $this.Env.Log("Failed to merge catalog: $($_.Exception.Message)", 'WARN')
      }
    }

    return @{
      status      = "SYNCED"
      mergedCount = $mergedCount
      backupFile  = $backupFile
      timestamp   = $timeTag
    }
  }

  [hashtable] ReportIncident([DaemonIncidentReportRequest]$req, [string]$rawBody) {
    $incidentsDir = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\data\incidents')
    if (-not (Test-Path -LiteralPath $incidentsDir)) {
      New-Item -ItemType Directory -Path $incidentsDir -Force | Out-Null
    }
    $timeTag = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $nowIso = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $sourceStem = if ($req.Source) { [System.IO.Path]::GetFileNameWithoutExtension($req.Source) } else { "incident" }
    $incidentFile = [System.IO.Path]::Combine($incidentsDir, "incident_${sourceStem}_$timeTag.json")

    # 1. Write individual event snapshot
    $payload = if (-not [string]::IsNullOrWhiteSpace($rawBody)) {
      $rawBody
    } else {
      $req | ConvertTo-Json -Depth 5
    }
    [System.IO.File]::WriteAllText($incidentFile, $payload, [System.Text.Encoding]::UTF8)

    # 2. Maintain Deduplicated Incident Registry Index
    $registryPath = [System.IO.Path]::Combine($incidentsDir, 'incident_registry.json')
    $registry = @()
    if (Test-Path -LiteralPath $registryPath) {
      try {
        $rawCat = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($rawCat) { $registry = @($rawCat) }
      } catch {}
    }

    # Extract distinct incident signatures
    $sigKey = "$sourceStem"
    if ($req.Errors -and $req.Errors.Count -gt 0) {
      $firstErr = $req.Errors[0]
      $errText = if ($firstErr.PSObject.Properties['Message']) { [string]$firstErr.Message } else { "$firstErr" }
      $sigKey += "::ERR::" + ($errText -replace '\s+', ' ').Substring(0, [Math]::Min(50, $errText.Length))
    } elseif ($req.Warnings -and $req.Warnings.Count -gt 0) {
      $firstWarn = $req.Warnings[0]
      $warnText = if ($firstWarn.PSObject.Properties['Message']) { [string]$firstWarn.Message } else { "$firstWarn" }
      $sigKey += "::WARN::" + ($warnText -replace '\s+', ' ').Substring(0, [Math]::Min(50, $warnText.Length))
    }

    $match = $registry | Where-Object { $_.Signature -eq $sigKey }
    $occurrenceCount = 1
    $currentPriority = "LOW"

    if ($match) {
      $match.OccurrenceCount = [int]$match.OccurrenceCount + 1
      $match.LastSeen = $nowIso
      $occurrenceCount = $match.OccurrenceCount
      if ($occurrenceCount -ge 5) {
        $match.Priority = "HIGH"
      } elseif ($occurrenceCount -ge 2) {
        $match.Priority = "MEDIUM"
      }
      $currentPriority = $match.Priority
      if ($req.MasterLog -and -not ($match.LogFiles -contains $req.MasterLog)) {
        $match.LogFiles += $req.MasterLog
      }
    } else {
      $newEntry = [PSCustomObject]@{
        Signature       = $sigKey
        Source          = $sourceStem
        Status          = $req.Status
        FirstSeen       = $nowIso
        LastSeen        = $nowIso
        OccurrenceCount = 1
        Priority        = "LOW"
        LogFiles        = @($req.MasterLog)
        AssociatedCrp   = ""
      }
      $registry += $newEntry
    }

    # Save registry
    $regJson = $registry | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($registryPath, $regJson, [System.Text.Encoding]::UTF8)

    $this.Env.Log("Recorded incident for $sourceStem (Occurrences: $occurrenceCount, Priority: $currentPriority): $incidentFile", 'ACTION')

    return @{
      status          = "RECORDED"
      incidentFile    = $incidentFile
      timestamp       = $timeTag
      source          = $req.Source
      occurrenceCount = $occurrenceCount
      priority        = $currentPriority
    }
  }

  [void] PerformLogMaintenance([int]$maxDays = 7) {
    if (-not (Test-Path -LiteralPath $this.Env.LogDir)) { return }
    try {
      $cutoff = [System.DateTime]::Now.AddDays(-$maxDays)
      $oldLogs = @(Get-ChildItem -Path $this.Env.LogDir -File -Filter "LcmDesktopDaemon-*.log" | Where-Object { $_.LastWriteTime -lt $cutoff })
      $purged = 0
      foreach ($f in $oldLogs) {
        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
        $purged++
      }
      if ($purged -gt 0) {
        $this.Env.Log("Automated Log Maintenance: Purged $purged daemon logs older than $maxDays days.", 'INFO')
      }
    } catch {
      $this.Env.Log("Log maintenance check failed: $_", 'WARN')
    }
  }

  [hashtable] RecordActionLog([DaemonActionLogRequest]$req, [string]$rawBody) {
    if ($null -eq $req -and -not [string]::IsNullOrWhiteSpace($rawBody)) {
      try {
        $json = $rawBody | ConvertFrom-Json
        $req = [DaemonActionLogRequest]::FromJson($json)
      } catch {}
    }
    if ($null -eq $req) {
      $req = [DaemonActionLogRequest]::new()
    }

    $nowIso = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $nowUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    $timestamp = if (-not [string]::IsNullOrWhiteSpace($req.Timestamp)) { $req.Timestamp } else { $nowIso }
    $utc = if (-not [string]::IsNullOrWhiteSpace($req.Utc)) { $req.Utc } else { $nowUtc }
    $source = if (-not [string]::IsNullOrWhiteSpace($req.Source)) { $req.Source } else { 'Unknown' }
    $subsystem = if (-not [string]::IsNullOrWhiteSpace($req.Subsystem)) { $req.Subsystem } else { '' }
    $actionType = if (-not [string]::IsNullOrWhiteSpace($req.ActionType)) { $req.ActionType } else { 'ACTION' }
    $target = if (-not [string]::IsNullOrWhiteSpace($req.Target)) { $req.Target } else { '-' }
    $status = if (-not [string]::IsNullOrWhiteSpace($req.Status)) { $req.Status } else { 'SUCCESS' }
    $details = if (-not [string]::IsNullOrWhiteSpace($req.Details)) { $req.Details } else { '' }
    $command = if (-not [string]::IsNullOrWhiteSpace($req.Command)) { $req.Command } else { '' }
    $user = if (-not [string]::IsNullOrWhiteSpace($req.User)) { $req.User } else { $this.Env.User }

    $actionRecord = [ordered]@{
      timestamp   = $timestamp
      utc         = $utc
      source      = $source
      subsystem   = $subsystem
      action_type = $actionType
      target      = $target
      status      = $status
      details     = $details
      command     = $command
      user        = $user
    }


    # 1. Append to Central JSONL Ledger: LCM_Inventory/data/logs/lcm/actions.jsonl
    $actionsJsonlDir = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\data\logs\lcm')
    $actionsJsonlPath = [System.IO.Path]::Combine($actionsJsonlDir, 'actions.jsonl')
    if (-not (Test-Path -LiteralPath $actionsJsonlDir)) {
      New-Item -Path $actionsJsonlDir -ItemType Directory -Force | Out-Null
    }
    $jsonLine = ($actionRecord | ConvertTo-Json -Compress) + "`n"
    [System.IO.File]::AppendAllText($actionsJsonlPath, $jsonLine, [System.Text.Encoding]::UTF8)

    # 2. Append to Subsystem Log if Subsystem specified
    if (-not [string]::IsNullOrWhiteSpace($subsystem)) {
      $subsystemLogDir = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, "${subsystem}_Inventory\logs")
      if (Test-Path -LiteralPath $subsystemLogDir) {
        $subsystemLogFile = [System.IO.Path]::Combine($subsystemLogDir, 'actions.log')
        $logLine = "[$timestamp] [$actionType] [$status] Target: $target | Details: $details | Cmd: $command`n"
        [System.IO.File]::AppendAllText($subsystemLogFile, $logLine, [System.Text.Encoding]::UTF8)
      }
    }

    $this.Env.Log("Action Logged: [$actionType] $target ($status) from $source", 'ACTION')

    return @{
      status    = "LOGGED"
      timestamp = $timestamp
      action    = $actionType
      target    = $target
    }
  }

  [hashtable] GetActionLogs([int]$count = 50, [string]$subsystemFilter = "") {
    $actionsJsonlPath = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\data\logs\lcm\actions.jsonl')
    $records = @()
    if (Test-Path -LiteralPath $actionsJsonlPath) {
      $lines = [System.IO.File]::ReadAllLines($actionsJsonlPath, [System.Text.Encoding]::UTF8)

      for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $line = $lines[$i].Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
          $rec = $line | ConvertFrom-Json
          if (-not [string]::IsNullOrWhiteSpace($subsystemFilter)) {
            if ($rec.subsystem -ne $subsystemFilter -and $rec.source -notlike "*$subsystemFilter*") {
              continue
            }
          }
          $records += $rec
          if ($records.Count -ge $count) { break }
        } catch {}
      }
    }
    return @{
      status  = "OK"
      count   = $records.Count
      actions = $records
    }
  }

  [hashtable] HandlePrint([DaemonPrintRequest]$req) {
    $title = if ($req.DocumentTitle) { $req.DocumentTitle } else { "LCM Display Table" }
    $action = if ($req.Action) { $req.Action } else { "preview" }
    $subsystem = if ($req.Subsystem) { $req.Subsystem } else { "LCM" }
    $viewMode = if ($req.ViewMode) { $req.ViewMode } else { "Default" }
    $this.Env.Log("Print/PDF operation: Title='$title', Subsystem='$subsystem', Mode='$viewMode', Action='$action'", 'ACTION')
    return @{
      status    = "OK"
      timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
      action    = $action
      title     = $title
      subsystem = $subsystem
    }
  }

  [hashtable] AddExplorerOption([psobject]$body) {
    if ($null -eq $body -or -not $body.PSObject.Properties['field'] -or -not $body.PSObject.Properties['value']) {
      return @{ status = "ERROR"; error = "Missing field or value" }
    }
    $field = [string]$body.field
    $value = [string]$body.value
    if ([string]::IsNullOrWhiteSpace($value)) {
      return @{ status = "ERROR"; error = "Value cannot be empty" }
    }
    $optionsPath = [System.IO.Path]::Combine($this.Env.WorkspaceRoot, 'LCM_Inventory\config\tool_explorer_options.json')
    $opts = if (Test-Path -LiteralPath $optionsPath) {
      Get-Content -LiteralPath $optionsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } else {
      [PSCustomObject]@{
        Subsystems = @()
        Roles      = @()
        Categories = @()
      }
    }
    $propName = switch ($field) {
      'Subsys'     { 'Subsystems' }
      'Subsystem'  { 'Subsystems' }
      'Subsystems' { 'Subsystems' }
      'Group'      { 'Subsystems' }
      'Role'       { 'Roles' }
      'Roles'      { 'Roles' }
      'Category'   { 'Categories' }
      'Categories' { 'Categories' }
      default      { $field }
    }
    if ($opts.PSObject.Properties[$propName]) {
      $list = [System.Collections.Generic.List[string]]::new(@($opts.$propName))
      if (-not $list.Contains($value)) {
        $list.Add($value)
        $opts.$propName = @($list | Sort-Object)
        $opts | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $optionsPath -Encoding UTF8
        $this.Env.Log("Appended option '$value' to $propName in $optionsPath", 'ACTION')
      }
    }
    return @{ status = "OK"; field = $propName; value = $value }
  }
}


function Send-DaemonJsonResponse {
  param(
    [System.Net.HttpListenerResponse]$Response,
    [object]$Data,
    [int]$StatusCode = 200
  )
  try {
    $jsonStr = $Data | ConvertTo-Json -Compress -Depth 10
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($jsonStr)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = "application/json; charset=utf-8"
    $Response.ContentLength64 = $buffer.Length
    $Response.Headers.Add("Access-Control-Allow-Origin", "*")
    $Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    $Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Access-Control-Allow-Private-Network")
    $Response.Headers.Add("Access-Control-Allow-Private-Network", "true")
    $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $Response.OutputStream.Close()
  } catch {
    try { $Response.Close() } catch {}
  }
}
