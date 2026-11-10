# =====================================================================
# InboxWatcher.psm1 - LCM Inbox Two-Phase Acknowledgement Engine
# =====================================================================
# Module: InboxWatcher
# Purpose: Implements two-phase acknowledgement protocol (CRP-263) for LCM inbox:
#          Phase 1 immediate receipt ACK upon discovery/acceptance;
#          Phase 2 terminal outcome ACK (success with proposal ID or failure with error reason).
# Path: LCM_Inventory/modules/InboxWatcher.psm1
# Authors: Rolf, LCM_AI Engine
# Version: 10.2.0
# Date: 2026-11-10
# =====================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-InboxItemCorrelationId {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.IO.FileInfo]$File,

    [Parameter(Mandatory = $false)]
    [hashtable]$ParsedData = $null
  )

  # Check if parsed data provides explicit correlation identity
  if ($null -ne $ParsedData -and $ParsedData.ContainsKey('CorrelationId') -and -not [string]::IsNullOrWhiteSpace([string]$ParsedData['CorrelationId'])) {
    return [string]$ParsedData['CorrelationId']
  }

  # Deterministic fallback based on file content sha256 and name
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  $bytes = [System.IO.File]::ReadAllBytes($File.FullName)
  $hashBytes = $sha256.ComputeHash($bytes)
  $hashStr = [System.BitConverter]::ToString($hashBytes).Replace('-', '').Substring(0, 16)
  return "INBOX-$($File.BaseName)-$hashStr"
}

function Save-InboxAcknowledgement {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$CorrelationId,

    [Parameter(Mandatory = $true)]
    [ValidateSet(1, 2)]
    [int]$Phase,

    [Parameter(Mandatory = $true)]
    [ValidateSet('RECEIVED', 'SUCCESS', 'FAILURE')]
    [string]$Status,

    [Parameter(Mandatory = $true)]
    [string]$SourceFile,

    [Parameter(Mandatory = $false)]
    [int]$ProposalId = 0,

    [Parameter(Mandatory = $false)]
    [string]$Error = '',

    [Parameter(Mandatory = $false)]
    [string]$Details = '',

    [Parameter(Mandatory = $false)]
    [string]$InboxPath = 'D:\GDrive\LCM\INBOX',

    [Parameter(Mandatory = $false)]
    [string]$AckLedgerPath = 'D:\Git_Repositories\LCM_Inventory\data\inbox\acks'
  )

  $ackRecord = [ordered]@{
    correlation_id = $CorrelationId
    phase          = $Phase
    status         = $Status
    timestamp      = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    source_file    = $SourceFile
    proposal_id    = if ($ProposalId -gt 0) { $ProposalId } else { $null }
    error          = if (-not [string]::IsNullOrWhiteSpace($Error)) { $Error } else { $null }
    details        = if (-not [string]::IsNullOrWhiteSpace($Details)) { $Details } else { $null }
  }

  $json = $ackRecord | ConvertTo-Json -Depth 4

  # Target 1: Sender-facing return channel (GDrive inbox/acks)
  if (-not [string]::IsNullOrWhiteSpace($InboxPath)) {
    $senderAckDir = Join-Path $InboxPath 'acks'
    if (-not (Test-Path -LiteralPath $senderAckDir)) {
      New-Item -ItemType Directory -Path $senderAckDir -Force | Out-Null
    }
    $senderAckFile = Join-Path $senderAckDir "$CorrelationId.json"
    [System.IO.File]::WriteAllText($senderAckFile, $json, [System.Text.UTF8Encoding]::new($false))
  }

  # Target 2: Governed CM ledger in LCM_Inventory (data/inbox/acks)
  if (-not [string]::IsNullOrWhiteSpace($AckLedgerPath)) {
    if (-not (Test-Path -LiteralPath $AckLedgerPath)) {
      New-Item -ItemType Directory -Path $AckLedgerPath -Force | Out-Null
    }
    $ledgerAckFile = Join-Path $AckLedgerPath "$CorrelationId.json"
    [System.IO.File]::WriteAllText($ledgerAckFile, $json, [System.Text.UTF8Encoding]::new($false))
  }

  return $ackRecord
}

function Get-InboxAcknowledgement {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$CorrelationId,

    [Parameter(Mandatory = $false)]
    [string]$InboxPath = 'D:\GDrive\LCM\INBOX',

    [Parameter(Mandatory = $false)]
    [string]$AckLedgerPath = 'D:\Git_Repositories\LCM_Inventory\data\inbox\acks'
  )

  $candidates = @()
  if (-not [string]::IsNullOrWhiteSpace($AckLedgerPath)) {
    $candidates += Join-Path $AckLedgerPath "$CorrelationId.json"
  }
  if (-not [string]::IsNullOrWhiteSpace($InboxPath)) {
    $candidates += Join-Path (Join-Path $InboxPath 'acks') "$CorrelationId.json"
    $candidates += Join-Path (Join-Path $InboxPath 'ack') "$CorrelationId.json"
  }

  foreach ($file in $candidates) {
    if (Test-Path -LiteralPath $file) {
      $raw = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
      return ($raw | ConvertFrom-Json)
    }
  }

  return $null
}

function Test-InboxItemProcessed {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$CorrelationId,

    [Parameter(Mandatory = $false)]
    [string]$InboxPath = 'D:\GDrive\LCM\INBOX',

    [Parameter(Mandatory = $false)]
    [string]$AckLedgerPath = 'D:\Git_Repositories\LCM_Inventory\data\inbox\acks'
  )

  $ack = Get-InboxAcknowledgement -CorrelationId $CorrelationId -InboxPath $InboxPath -AckLedgerPath $AckLedgerPath
  if ($null -ne $ack -and $ack.phase -eq 2) {
    return $true
  }
  return $false
}

function ConvertFrom-InboxItemContent {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][System.IO.FileInfo]$File)

  $rawContent = [System.IO.File]::ReadAllText($File.FullName, [System.Text.Encoding]::UTF8)
  $itemData = @{
    FileName        = $File.Name
    RawContent      = $rawContent
    Type            = 'TASK'
    Classification  = 'TASK'
    Title           = $File.BaseName
    Timestamp       = $File.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    TimestampValid  = $false
    OriginRepo      = 'Gemini / GDrive Inbox'
    Criticality     = 'MEDIUM'
    Details         = ''
    CorrelationId   = ''
  }

  if ($File.Extension -eq '.json') {
    try {
      $json = $rawContent | ConvertFrom-Json
      if ($json.type) { $itemData.Type = $json.type }
      if ($json.classification) { $itemData.Classification = $json.classification }
      else { $itemData.Classification = $itemData.Type }
      if ($json.title) { $itemData.Title = $json.title }
      if ($json.timestamp) {
        $itemData.Timestamp = $json.timestamp
        $itemData.TimestampValid = $true
      }
      if ($json.correlation_id) { $itemData.CorrelationId = $json.correlation_id }
      if ($json.target_repo) { $itemData.OriginRepo = "Gemini / $($json.target_repo)" }
      if ($json.criticality) { $itemData.Criticality = $json.criticality }
      if ($json.details) { $itemData.Details = $json.details }
      elseif ($json.summary) { $itemData.Details = $json.summary }
      return $itemData
    } catch {
      # Fallback to regex text parsing on json parse error
    }
  }

  # Parse Markdown / Text metadata headers
  $lines = @($rawContent -split "\r?\n")
  foreach ($line in $lines) {
    if ($line -match '^(?:#\s*)?\[?(?:TYPE:\s*)?(BUG|TASK|PROPOSAL|FEATURE|NOTE|AUDIT)\]?:?\s*(.+)$') {
      $itemData.Type = $matches[1].ToUpperInvariant()
      $itemData.Classification = $itemData.Type
      $itemData.Title = $matches[2].Trim().TrimStart(':').Trim()
    }
    if ($line -match '(?i)\*\*(?:Classification)\*\*:\s*(.+)$') {
      $itemData.Classification = $matches[1].Trim().ToUpperInvariant()
    }
    if ($line -match '(?i)\*\*(?:Timestamp|Date)\*\*:\s*([0-9T:_\-+ ]+)') {
      $itemData.Timestamp = $matches[1].Trim()
      $itemData.TimestampValid = $true
    }
    if ($line -match '(?i)\*\*(?:Correlation-?ID|ID)\*\*:\s*(.+)$') {
      $itemData.CorrelationId = $matches[1].Trim()
    }
    if ($line -match '(?i)\*\*(?:Target Repository|Target Repo|Repo)\*\*:\s*(.+)$') {
      $itemData.OriginRepo = "Gemini / $($matches[1].Trim())"
    }
    if ($line -match '(?i)\*\*(?:Criticality|Severity|Priority)\*\*:\s*(.+)$') {
      $itemData.Criticality = $matches[1].Trim().ToUpperInvariant()
    }
  }

  if ([string]::IsNullOrWhiteSpace($itemData.Title) -or $itemData.Title -eq $File.BaseName) {
    $firstHeader = @($lines | Where-Object { $_ -match '^#+\s+(.+)$' } | Select-Object -First 1)
    if ($firstHeader.Count -gt 0) {
      $itemData.Title = ($firstHeader[0] -replace '^#+\s+', '').Trim()
    }
  }

  $itemData.Details = $rawContent
  return $itemData
}

function Invoke-TwoPhaseInboxIntake {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$InboxPath,

    [Parameter(Mandatory = $true)]
    [string]$ArchivePath,

    [Parameter(Mandatory = $false)]
    [string]$AckPath = '',

    [Parameter(Mandatory = $false)]
    [string]$AckLedgerPath = 'D:\Git_Repositories\LCM_Inventory\data\inbox\acks',

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceRoot = 'D:\Git_Repositories',

    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [scriptblock]$LogCallback = $null
  )

  if ([string]::IsNullOrWhiteSpace($AckPath)) {
    $AckPath = Join-Path $InboxPath 'acks'
  }

  # Ensure directories
  foreach ($dir in @($InboxPath, $ArchivePath, $AckPath, $AckLedgerPath)) {
    if (-not (Test-Path -LiteralPath $dir)) {
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
  }

  $pendingFiles = @(Get-ChildItem -Path $InboxPath -File | Where-Object {
    $ext = $_.Extension
    $dirName = $_.DirectoryName
    ($ext -in @('.md', '.txt', '.json')) -and
    ($dirName -ne $ArchivePath) -and
    ($dirName -ne $AckPath)
  })

  if ($pendingFiles.Count -eq 0) {
    return @()
  }

  # Import ProposalManager if not already loaded
  if (-not (Get-Command 'New-WorkspaceProposal' -ErrorAction SilentlyContinue)) {
    $pmPath = Join-Path $WorkspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1'
    if (Test-Path -LiteralPath $pmPath) {
      Import-Module -Name $pmPath -Force
    }
  }

  $results = @()

  foreach ($file in $pendingFiles) {
    $parsed = ConvertFrom-InboxItemContent -File $file
    $correlationId = Get-InboxItemCorrelationId -File $file -ParsedData $parsed

    # Check Idempotency: If already terminal acknowledged, avoid duplicating
    $alreadyDone = Test-InboxItemProcessed -CorrelationId $correlationId -InboxPath $InboxPath -AckLedgerPath $AckLedgerPath
    if ($alreadyDone) {
      if ($null -ne $LogCallback) {
        & $LogCallback "Item '$($file.Name)' (ID: $correlationId) was already processed. Archiving without re-intake." 'WARN'
      }
      # Safely archive duplicate file
      $stampPrefix = (Get-Date).ToString("yyyyMMdd_HHmmss")
      $archivedPath = Join-Path $ArchivePath "$($stampPrefix)_$($file.Name)"
      Move-Item -LiteralPath $file.FullName -Destination $archivedPath -Force
      continue
    }

    # =========================================================================
    # PHASE 1: IMMEDIATE RECEIPT ACKNOWLEDGEMENT
    # Persisted before any irreversible processing, classification, or proposal creation
    # =========================================================================
    if (-not $DryRun) {
      Save-InboxAcknowledgement -CorrelationId $correlationId `
                                -Phase 1 `
                                -Status 'RECEIVED' `
                                -SourceFile $file.Name `
                                -InboxPath $InboxPath `
                                -AckLedgerPath $AckLedgerPath | Out-Null
    }

    if ($null -ne $LogCallback) {
      & $LogCallback "[PHASE 1 ACK] Accepted inbox item: $($file.Name) (CorrelationId: $correlationId)" 'ACTION'
    }

    if ($DryRun) {
      $results += [PSCustomObject]@{
        CorrelationId = $correlationId
        File          = $file.Name
        Phase         = 1
        Status        = 'RECEIVED (DRY-RUN)'
        ProposalId    = $null
        Error         = $null
      }
      continue
    }

    # =========================================================================
    # CLASSIFICATION & PROCESSING
    # =========================================================================
    try {
      # CRP-263 requirement: AUDIT classification cannot be ingested as proposal
      if ($parsed.Classification -eq 'AUDIT') {
        $errorReason = "Unsupported classification 'AUDIT'. Proposal intake is not permitted for audit reports."
        Save-InboxAcknowledgement -CorrelationId $correlationId `
                                  -Phase 2 `
                                  -Status 'FAILURE' `
                                  -SourceFile $file.Name `
                                  -Error $errorReason `
                                  -InboxPath $InboxPath `
                                  -AckLedgerPath $AckLedgerPath | Out-Null

        if ($null -ne $LogCallback) {
          & $LogCallback "[PHASE 2 ACK] Terminal failure for $($file.Name): $errorReason" 'ERROR'
        }

        # Archive rejected file
        $stampPrefix = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $archivedPath = Join-Path $ArchivePath "rejected_$($stampPrefix)_$($file.Name)"
        Move-Item -LiteralPath $file.FullName -Destination $archivedPath -Force

        $results += [PSCustomObject]@{
          CorrelationId = $correlationId
          File          = $file.Name
          Phase         = 2
          Status        = 'FAILURE'
          ProposalId    = $null
          Error         = $errorReason
        }
        continue
      }

      # Valid proposal intake
      $proposalTitle = "[$($parsed.Type)] $($parsed.Title)"
      $proposalDetails = "Source: Gemini Inbox ($($file.Name)) | Correlation: $correlationId | Time: $($parsed.Timestamp) | Criticality: $($parsed.Criticality)`n`n$($parsed.Details)"

      $prop = New-WorkspaceProposal -Title $proposalTitle -OriginRepo $parsed.OriginRepo -Details $proposalDetails -Author 'Gemini Cloud'

      # Persist complete plan payload
      $fullPlanPath = Join-Path $WorkspaceRoot $prop.plan_path
      $planDir = Split-Path $fullPlanPath -Parent
      if (-not (Test-Path -LiteralPath $planDir)) {
        New-Item -ItemType Directory -Force -Path $planDir | Out-Null
      }

      $planHeader = @(
        "# LCM Proposal #$($prop.id): $($prop.title)",
        "",
        "- **CR ID**: $($prop.cr_id)",
        "- **Correlation ID**: $correlationId",
        "- **Origin**: $($prop.origin_repo)",
        "- **Intake Timestamp**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))",
        "- **Gemini Source Timestamp**: $($parsed.Timestamp)",
        "- **Criticality**: $($parsed.Criticality)",
        "- **Status**: $($prop.state) (Awaiting operator review: ProposalAction do $($prop.id))",
        "",
        "---",
        "",
        "## Gemini Intake Payload",
        "",
        $parsed.RawContent
      ) -join "`n"

      [System.IO.File]::WriteAllText($fullPlanPath, $planHeader, [System.Text.UTF8Encoding]::new($false))

      # Archive original item
      $stampPrefix = (Get-Date).ToString("yyyyMMdd_HHmmss")
      $archivedName = "$($stampPrefix)_$($file.Name)"
      $archivedPath = Join-Path $ArchivePath $archivedName
      Move-Item -LiteralPath $file.FullName -Destination $archivedPath -Force

      # =========================================================================
      # PHASE 2: TERMINAL SUCCESS ACKNOWLEDGEMENT
      # =========================================================================
      Save-InboxAcknowledgement -CorrelationId $correlationId `
                                -Phase 2 `
                                -Status 'SUCCESS' `
                                -SourceFile $file.Name `
                                -ProposalId [int]$prop.id `
                                -InboxPath $InboxPath `
                                -AckLedgerPath $AckLedgerPath | Out-Null

      if ($null -ne $LogCallback) {
        & $LogCallback "[PHASE 2 ACK] Terminal success for $($file.Name) -> Proposal #$($prop.id)" 'ACTION'
      }

      $results += [PSCustomObject]@{
        CorrelationId = $correlationId
        File          = $file.Name
        Phase         = 2
        Status        = 'SUCCESS'
        ProposalId    = [int]$prop.id
        Error         = $null
      }
    } catch {
      $failureMsg = $_.Exception.Message

      # =========================================================================
      # PHASE 2: TERMINAL FAILURE ACKNOWLEDGEMENT
      # =========================================================================
      Save-InboxAcknowledgement -CorrelationId $correlationId `
                                -Phase 2 `
                                -Status 'FAILURE' `
                                -SourceFile $file.Name `
                                -Error $failureMsg `
                                -InboxPath $InboxPath `
                                -AckLedgerPath $AckLedgerPath | Out-Null

      if ($null -ne $LogCallback) {
        & $LogCallback "[PHASE 2 ACK] Terminal failure for $($file.Name): $failureMsg" 'ERROR'
      }

      $results += [PSCustomObject]@{
        CorrelationId = $correlationId
        File          = $file.Name
        Phase         = 2
        Status        = 'FAILURE'
        ProposalId    = $null
        Error         = $failureMsg
      }
    }
  }

  return $results
}

Export-ModuleMember -Function Get-InboxItemCorrelationId,
                              Save-InboxAcknowledgement,
                              Get-InboxAcknowledgement,
                              Test-InboxItemProcessed,
                              ConvertFrom-InboxItemContent,
                              Invoke-TwoPhaseInboxIntake
