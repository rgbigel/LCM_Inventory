<#
Module: LcmDaemon/Classes/DaemonDto.ps1
Purpose: Strongly-typed data transfer objects (DTOs) for LCM Desktop Daemon REST Bridge.
Path: LCM_Inventory/modules/LcmDaemon/Classes/DaemonDto.ps1
Authors: Rolf, LCM_AI Engine
Version: 10.0.1
Date: 2026-11-08 15:17:24
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

class DaemonOpenRequest {
  [string]$Url = ""
  [string]$FilePath = ""
  [string]$Args = ""
  [bool]$Foreground = $true
  [string]$Title = ""

  static [DaemonOpenRequest] FromJson([psobject]$json) {
    $dto = [DaemonOpenRequest]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['url'] -and $json.url) { $dto.Url = [string]$json.url }
    if ($json.PSObject.Properties['filePath'] -and $json.filePath) { $dto.FilePath = [string]$json.filePath }
    if ($json.PSObject.Properties['args'] -and $json.args) { $dto.Args = [string]$json.args }
    if ($json.PSObject.Properties['foreground']) { $dto.Foreground = [bool]$json.foreground }
    if ($json.PSObject.Properties['title'] -and $json.title) { $dto.Title = [string]$json.title }
    return $dto
  }
}

class DaemonExecuteRequest {
  [string]$Command = ""
  [bool]$Elevated = $false
  [bool]$NoExit = $true
  [string]$WindowStyle = ""
  [bool]$Sync = $false
  [int]$TimeoutMs = 0

  static [DaemonExecuteRequest] FromJson([psobject]$json) {
    $dto = [DaemonExecuteRequest]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['command'] -and $json.command) { $dto.Command = [string]$json.command }
    if ($json.PSObject.Properties['elevated']) { $dto.Elevated = [bool]$json.elevated }
    if ($json.PSObject.Properties['noExit']) {
      $val = $json.noExit
      $dto.NoExit = ($val -eq $true -or $val -eq 'true' -or $val -eq 1)
    }
    if ($json.PSObject.Properties['windowStyle'] -and $json.windowStyle) { $dto.WindowStyle = [string]$json.windowStyle }
    if ($json.PSObject.Properties['sync']) {
      $val = $json.sync
      $dto.Sync = ($val -eq $true -or $val -eq 'true' -or $val -eq 1)
    }
    if ($json.PSObject.Properties['timeoutMs'] -and $json.timeoutMs) {
      $dto.TimeoutMs = [int]$json.timeoutMs
    }
    return $dto
  }
}

class DaemonHelpRequest {
  [string]$FilePath = ""
  [string]$RelativePath = ""

  static [DaemonHelpRequest] FromJson([psobject]$json) {
    $dto = [DaemonHelpRequest]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['filePath'] -and $json.filePath) { $dto.FilePath = [string]$json.filePath }
    if ($json.PSObject.Properties['relativePath'] -and $json.relativePath) { $dto.RelativePath = [string]$json.relativePath }
    return $dto
  }
}

class DaemonEditRequest {
  [string]$FilePath = ""
  [int]$Line = 1
  [string]$Editor = ""
  [string]$Content = ""

  static [DaemonEditRequest] FromJson([psobject]$json) {
    $dto = [DaemonEditRequest]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['filePath'] -and $json.filePath) { $dto.FilePath = [string]$json.filePath }
    elseif ($json.PSObject.Properties['path'] -and $json.path) { $dto.FilePath = [string]$json.path }
    if ($json.PSObject.Properties['line'] -and $json.line) { $dto.Line = [int]$json.line }
    if ($json.PSObject.Properties['editor'] -and $json.editor) { $dto.Editor = [string]$json.editor }
    if ($json.PSObject.Properties['content'] -and $json.content) { $dto.Content = [string]$json.content }
    return $dto
  }
}

class DaemonCleanupQueryRequest {
  [string]$ToolName = ""
  [string]$ShortName = ""

  static [DaemonCleanupQueryRequest] FromJson([psobject]$json) {
    $dto = [DaemonCleanupQueryRequest]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['toolName'] -and $json.toolName) { $dto.ToolName = [string]$json.toolName }
    if ($json.PSObject.Properties['shortName'] -and $json.shortName) { $dto.ShortName = [string]$json.shortName }
    return $dto
  }
}

class DaemonCleanupRequest {
  [string]$ToolName = ""
  [string]$ShortName = ""
  [bool]$PurgeLogs = $false
  [bool]$PurgeArchive = $false

  static [DaemonCleanupRequest] FromJson([psobject]$json) {
    $dto = [DaemonCleanupRequest]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['toolName'] -and $json.toolName) { $dto.ToolName = [string]$json.toolName }
    if ($json.PSObject.Properties['shortName'] -and $json.shortName) { $dto.ShortName = [string]$json.shortName }
    if ($json.PSObject.Properties['purgeLogs']) { $dto.PurgeLogs = [bool]$json.purgeLogs }
    if ($json.PSObject.Properties['purgeArchive']) { $dto.PurgeArchive = [bool]$json.purgeArchive }
    return $dto
  }
}

class DaemonRenameRequest {
  [string]$OldName = ""
  [string]$NewName = ""
  [string]$OldShortName = ""
  [string]$NewShortName = ""
  [string]$RelativePath = ""
  [string[]]$Aliases = @()

  static [DaemonRenameRequest] FromJson([psobject]$json) {
    $dto = [DaemonRenameRequest]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['oldName'] -and $json.oldName) { $dto.OldName = [string]$json.oldName }
    if ($json.PSObject.Properties['newName'] -and $json.newName) { $dto.NewName = [string]$json.newName }
    if ($json.PSObject.Properties['oldShortName'] -and $json.oldShortName) { $dto.OldShortName = [string]$json.oldShortName }
    if ($json.PSObject.Properties['newShortName'] -and $json.newShortName) { $dto.NewShortName = [string]$json.newShortName }
    if ($json.PSObject.Properties['relativePath'] -and $json.relativePath) { $dto.RelativePath = [string]$json.relativePath }
    if ($json.PSObject.Properties['aliases'] -and $null -ne $json.aliases) {
      $dto.Aliases = @($json.aliases | ForEach-Object { [string]$_ })
    }
    return $dto
  }
}

class DaemonArchiveRequest {
  [string]$ToolName = ""
  [string]$RelativePath = ""

  static [DaemonArchiveRequest] FromJson([psobject]$json) {
    $dto = [DaemonArchiveRequest]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['toolName'] -and $json.toolName) { $dto.ToolName = [string]$json.toolName }
    if ($json.PSObject.Properties['relativePath'] -and $json.relativePath) { $dto.RelativePath = [string]$json.relativePath }
    return $dto
  }
}

class DaemonSyncRequest {
  [bool]$DefeatSwitch = $true
  [psobject]$Overrides = $null

  static [DaemonSyncRequest] FromJson([psobject]$json) {
    $dto = [DaemonSyncRequest]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['defeatSwitch']) { $dto.DefeatSwitch = [bool]$json.defeatSwitch }
    if ($json.PSObject.Properties['overrides']) { $dto.Overrides = $json.overrides }
    return $dto
  }
}

class DaemonIncidentReportRequest {
  [string]$Source = ""
  [string]$Status = ""
  [string]$MasterLog = ""
  [psobject]$Warnings = $null
  [psobject]$Errors = $null

  static [DaemonIncidentReportRequest] FromJson([psobject]$json) {
    $dto = [DaemonIncidentReportRequest]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['source']) { $dto.Source = [string]$json.source }
    if ($json.PSObject.Properties['status']) { $dto.Status = [string]$json.status }
    if ($json.PSObject.Properties['masterLog']) { $dto.MasterLog = [string]$json.masterLog }
    if ($json.PSObject.Properties['warnings']) { $dto.Warnings = $json.warnings }
    if ($json.PSObject.Properties['errors']) { $dto.Errors = $json.errors }
    return $dto
  }
}

class DaemonPrintRequest {
  [string]$DocumentTitle = ""
  [string]$Subsystem = ""
  [string]$ViewMode = ""
  [string]$Action = "preview"
  [psobject]$Prefs = $null

  static [DaemonPrintRequest] FromJson([psobject]$json) {
    $dto = [DaemonPrintRequest]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['documentTitle'] -and $json.documentTitle) { $dto.DocumentTitle = [string]$json.documentTitle }
    if ($json.PSObject.Properties['subsystem'] -and $json.subsystem) { $dto.Subsystem = [string]$json.subsystem }
    if ($json.PSObject.Properties['viewMode'] -and $json.viewMode) { $dto.ViewMode = [string]$json.viewMode }
    if ($json.PSObject.Properties['action'] -and $json.action) { $dto.Action = [string]$json.action }
    if ($json.PSObject.Properties['prefs'] -and $json.prefs) { $dto.Prefs = $json.prefs }
    return $dto
  }
}

class DaemonActionLogRequest {
  [string]$Timestamp = ""
  [string]$Utc = ""
  [string]$Source = ""
  [string]$Subsystem = ""
  [string]$ActionType = ""
  [string]$Target = ""
  [string]$Status = ""
  [string]$Details = ""
  [string]$Command = ""
  [string]$User = ""

  static [DaemonActionLogRequest] FromJson([psobject]$json) {
    $dto = [DaemonActionLogRequest]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['timestamp'] -and $json.timestamp) { $dto.Timestamp = [string]$json.timestamp }
    if ($json.PSObject.Properties['utc'] -and $json.utc) { $dto.Utc = [string]$json.utc }
    if ($json.PSObject.Properties['source'] -and $json.source) { $dto.Source = [string]$json.source }
    if ($json.PSObject.Properties['subsystem'] -and $json.subsystem) { $dto.Subsystem = [string]$json.subsystem }
    if ($json.PSObject.Properties['action_type'] -and $json.action_type) { $dto.ActionType = [string]$json.action_type }
    elseif ($json.PSObject.Properties['action'] -and $json.action) { $dto.ActionType = [string]$json.action }
    if ($json.PSObject.Properties['target'] -and $json.target) { $dto.Target = [string]$json.target }
    if ($json.PSObject.Properties['status'] -and $json.status) { $dto.Status = [string]$json.status }
    if ($json.PSObject.Properties['details'] -and $json.details) { $dto.Details = [string]$json.details }
    if ($json.PSObject.Properties['command'] -and $json.command) { $dto.Command = [string]$json.command }
    if ($json.PSObject.Properties['user'] -and $json.user) { $dto.User = [string]$json.user }
    return $dto
  }
}

class DaemonActionIntent {
  [string]$Action = "DO"
  [string]$Target = ""
  [string]$Caller = "CLI"
  [hashtable]$Context = @{}
  [hashtable]$Parameters = @{}
  [hashtable]$Options = @{}
  [string]$Token = ""

  static [DaemonActionIntent] FromJson([psobject]$json) {
    $dto = [DaemonActionIntent]::new()
    if ($null -eq $json) { return $dto }
    if ($json.PSObject.Properties['action'] -and $json.action) { $dto.Action = [string]$json.action }
    if ($json.PSObject.Properties['target'] -and $json.target) { $dto.Target = [string]$json.target }
    if ($json.PSObject.Properties['caller'] -and $json.caller) { $dto.Caller = [string]$json.caller }
    if ($json.PSObject.Properties['token'] -and $json.token) { $dto.Token = [string]$json.token }
    if ($json.PSObject.Properties['context'] -and $null -ne $json.context) {
      $dto.Context = [hashtable]@{}
      foreach ($prop in $json.context.PSObject.Properties) {
        $dto.Context[$prop.Name] = $prop.Value
      }
    }
    if ($json.PSObject.Properties['parameters'] -and $null -ne $json.parameters) {
      $dto.Parameters = [hashtable]@{}
      foreach ($prop in $json.parameters.PSObject.Properties) {
        $dto.Parameters[$prop.Name] = $prop.Value
      }
    }
    if ($json.PSObject.Properties['options'] -and $null -ne $json.options) {
      $dto.Options = [hashtable]@{}
      foreach ($prop in $json.options.PSObject.Properties) {
        $dto.Options[$prop.Name] = $prop.Value
      }
    }
    return $dto
  }
}
