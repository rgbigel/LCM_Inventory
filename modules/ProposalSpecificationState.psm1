<#
Module: ProposalSpecificationState
Purpose: Prepare specification-header mirrors for persisted lifecycle changes.
Path: modules/ProposalSpecificationState.psm1
Authors: Rolf, Copilot
Version: 10.2.1
Date: 2026-10-21
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LcmSpecificationStateEdits {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object]$Store,
    [Parameter(Mandatory)][string]$StorePath
  )
  $previous = if (Test-Path -LiteralPath $StorePath) {
    [IO.File]::ReadAllText($StorePath) | ConvertFrom-Json -ErrorAction Stop
  } else { $null }
  $workspace = Split-Path (Split-Path (Split-Path (Split-Path $StorePath -Parent) -Parent) -Parent) -Parent
  $progress = @{
    suggested='undecided'; in_progress='in_progress'; verified='verification'
    in_review='verification'; completed='completed'; pushed='pushed'
    held='blocked'; withdrawn='deferred'; rejected='deferred'; superseded='deferred'
  }
  foreach ($proposal in @($Store.proposals)) {
    if (-not $proposal.PSObject.Properties['bundle_dir'] -or -not $proposal.bundle_dir) { continue }
    $old = @(if ($null -ne $previous) { $previous.proposals | Where-Object { $_.id -eq $proposal.id } })
    # New proposal templates already initialize the suggested-state metadata.
    if (-not $old.Count -and $proposal.state -eq 'suggested') { continue }
    if ($old.Count -eq 1 -and $old[0].state -eq $proposal.state) { continue }
    $state = [string]$proposal.state
    if (-not $progress.ContainsKey($state)) { throw "Cannot mirror unsupported proposal state '$state' for #$($proposal.id)." }
    $repo = if ($proposal.PSObject.Properties['origin_repo'] -and $proposal.origin_repo) { [string]$proposal.origin_repo } else { 'LCM_Inventory' }
    if ($repo -in @('.', '..') -or [IO.Path]::GetFileName($repo) -ne $repo) {
      throw "Invalid repository name for proposal #$($proposal.id)."
    }
    $repoRoot = [IO.Path]::GetFullPath((Join-Path $workspace $repo))
    if (-not [IO.Directory]::Exists($repoRoot)) { $repoRoot = Join-Path $workspace 'LCM_Inventory' }
    $bundle = [IO.Path]::GetFullPath((Join-Path $repoRoot $proposal.bundle_dir))
    if (-not $bundle.StartsWith($repoRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
      throw "Proposal #$($proposal.id) bundle escapes its repository."
    }
    $leaf = if ($proposal.PSObject.Properties['docs'] -and $proposal.docs.PSObject.Properties['specification']) { $proposal.docs.specification } else { 'Specification.md' }
    if ([IO.Path]::GetFileName($leaf) -ne $leaf) { throw "Invalid specification filename for proposal #$($proposal.id)." }
    $path = Join-Path $bundle $leaf
    $bytes = [IO.File]::ReadAllBytes($path)
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    $header = [regex]::Match($text, '(?ms)^```yaml\r?\n(?<metadata>.*?)^```\s*\r?$')
    if (-not $header.Success) { throw "Specification metadata fence missing: $path" }
    $metadata = $header.Groups['metadata'].Value
    $values = [ordered]@{
      Status = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($state.Replace('_', ' '))
      'Plan-State' = $state
      'Progress-State' = $progress[$state]
    }
    foreach ($key in $values.Keys) {
      $pattern = '(?m)^' + [regex]::Escape($key) + ':[^\r\n]*'
      if ([regex]::Matches($metadata, $pattern).Count -ne 1) { throw "Expected one '$key' metadata field: $path" }
      $metadata = [regex]::Replace($metadata, $pattern, ($key + ': ' + $values[$key]))
    }
    $group = $header.Groups['metadata']
    $updated = $text.Substring(0, $group.Index) + $metadata + $text.Substring($group.Index + $group.Length)
    if ($updated -ne $text) {
      [pscustomobject]@{ Path=$path; Original=$bytes; Content=$updated }
    }
  }
}

Export-ModuleMember -Function Get-LcmSpecificationStateEdits
