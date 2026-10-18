Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-GoodNightSaveAllReceiptPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot
  )

  Join-Path $WorkspaceRoot 'LCM_Inventory\data\session_state\goodnight-saveall-receipt.json'
}

function New-GoodNightSaveAllReceipt {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$ReceiptPath,

    [Parameter(Mandatory = $true)]
    [datetime]$ContextSnapshotSavedAt,

    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot,

    [Parameter(Mandatory = $true)]
    [string]$ConfirmedBy,

    [Parameter(Mandatory = $true)]
    [string]$SessionIdentity
  )

  $receiptDirectory = Split-Path -Path $ReceiptPath -Parent
  New-Item -ItemType Directory -Path $receiptDirectory -Force | Out-Null
  $receipt = [ordered]@{
    schema_version            = 1
    completion_state          = 'save_all_confirmed'
    completed_at              = (Get-Date).ToString('o')
    workspace_root            = $WorkspaceRoot
    confirmed_by              = $ConfirmedBy
    session_identity          = $SessionIdentity
    context_snapshot_saved_at = $ContextSnapshotSavedAt.ToString('o')
  }
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($ReceiptPath, ($receipt | ConvertTo-Json -Depth 3), $utf8)
  return [pscustomobject]$receipt
}

function Get-GoodNightSaveAllReceiptState {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$ReceiptPath,

    [Parameter(Mandatory = $true)]
    [datetime]$ContextSnapshotSavedAt,

    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot
  )

  if (-not (Test-Path -LiteralPath $ReceiptPath -PathType Leaf)) {
    return [pscustomobject]@{ State = 'missing'; Message = "No GoodNIGHT Save All receipt exists at $ReceiptPath."; Receipt = $null }
  }

  try {
    $receipt = Get-Content -LiteralPath $ReceiptPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
  } catch {
    return [pscustomobject]@{ State = 'malformed'; Message = "GoodNIGHT Save All receipt is not valid JSON: $ReceiptPath."; Receipt = $null }
  }

  $required = @('schema_version', 'completion_state', 'completed_at', 'workspace_root', 'confirmed_by', 'session_identity', 'context_snapshot_saved_at')
  $missing = @($required | Where-Object {
      -not $receipt.PSObject.Properties[$_] -or [string]::IsNullOrWhiteSpace([string]$receipt.$_)
    })
  if ($missing.Count -gt 0 -or $receipt.schema_version -ne 1 -or $receipt.completion_state -ne 'save_all_confirmed') {
    return [pscustomobject]@{ State = 'incomplete'; Message = "GoodNIGHT Save All receipt is incomplete or unsupported: $ReceiptPath."; Receipt = $receipt }
  }

  if (-not [string]::Equals([string]$receipt.workspace_root, $WorkspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    return [pscustomobject]@{ State = 'mismatched'; Message = "GoodNIGHT Save All receipt belongs to a different workspace: $ReceiptPath."; Receipt = $receipt }
  }

  try {
    $completedAt = [datetimeoffset]::Parse([string]$receipt.completed_at)
    $receiptSnapshot = [datetimeoffset]::Parse([string]$receipt.context_snapshot_saved_at)
  } catch {
    return [pscustomobject]@{ State = 'malformed'; Message = "GoodNIGHT Save All receipt contains invalid timestamps: $ReceiptPath."; Receipt = $receipt }
  }

  if ($receiptSnapshot.LocalDateTime -lt $ContextSnapshotSavedAt -or $completedAt.LocalDateTime -lt $ContextSnapshotSavedAt) {
    return [pscustomobject]@{ State = 'stale'; Message = "GoodNIGHT Save All receipt predates the current session snapshot: $ReceiptPath."; Receipt = $receipt }
  }

  return [pscustomobject]@{ State = 'valid'; Message = "GoodNIGHT Save All receipt is valid: $ReceiptPath."; Receipt = $receipt }
}

Export-ModuleMember -Function Get-GoodNightSaveAllReceiptPath, New-GoodNightSaveAllReceipt, Get-GoodNightSaveAllReceiptState
