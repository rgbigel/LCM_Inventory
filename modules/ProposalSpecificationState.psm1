<#
Module: ProposalSpecificationState
Purpose: Prepare specification-header mirrors for persisted lifecycle changes.
Path: modules/ProposalSpecificationState.psm1
Authors: Rolf, Copilot
Version: 10.2.2
Date: 2026-11-14
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
    $repo = if ($proposal.PSObject.Properties['origin_repo'] -and $proposal.origin_repo -and ($proposal.origin_repo -notlike 'LCM_*')) { [string]$proposal.origin_repo } else { 'LCM_Inventory' }
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
    if (-not [IO.File]::Exists($path)) {
      if (-not [IO.Directory]::Exists($bundle)) {
        [IO.Directory]::CreateDirectory($bundle) | Out-Null
      }
      $bytes = [byte[]]@()
      $originalText = ''
      $text = ''
    } else {
      $bytes = [IO.File]::ReadAllBytes($path)
      $originalText = [Text.Encoding]::UTF8.GetString($bytes)
      $text = $originalText
    }
    $header = [regex]::Match($text, '(?ms)^```yaml\r?\n(?<metadata>.*?)^```\s*\r?$')
    $values = [ordered]@{
      Status = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($state.Replace('_', ' '))
      'Plan-State' = $state
      'Progress-State' = $progress[$state]
    }

    if (-not $header.Success) {
      # Silently construct and insert missing YAML metadata block per operator directive
      $crpTag = if ($proposal.PSObject.Properties['crp_id'] -and $proposal.crp_id) { $proposal.crp_id } elseif ($proposal.PSObject.Properties['cr_id'] -and $proposal.cr_id) { $proposal.cr_id } else { "CRP-$($proposal.id)" }
      $title = if ($proposal.PSObject.Properties['title'] -and $proposal.title) { $proposal.title } else { "Proposal #$($proposal.id)" }
      $authorVal = if ($proposal.PSObject.Properties['author'] -and $proposal.author) { $proposal.author } else { $env:USERNAME }
      $dateVal = if ($proposal.PSObject.Properties['timestamp'] -and $proposal.timestamp) { $proposal.timestamp } else { (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }
      $prioVal = if ($proposal.PSObject.Properties['priority'] -and $proposal.priority) { $proposal.priority } else { 5 }
      $appIdVal = if ($proposal.PSObject.Properties['app_id'] -and $proposal.app_id) { $proposal.app_id } else { 'None' }
      $versionVal = if ($proposal.PSObject.Properties['lcm_version'] -and $proposal.lcm_version) { $proposal.lcm_version } else { '10.2.5' }

      $yamlTemplate = @'
```yaml
CRP-ID: {0}
Title: {1}
Scope: {2}
Baseline-Version: {3}
Author: {4}
Date: {5}
Status: {6}
Plan-State: {7}
Progress-State: {8}
Priority: {9}
App-ID: {10}
```
'@
      $yamlFence = $yamlTemplate -f $crpTag, $title, $repo, $versionVal, $authorVal, $dateVal, $values['Status'], $values['Plan-State'], $values['Progress-State'], $prioVal, $appIdVal

      if ($text -match '(?ms)^(?<h1line>#[^\r\n]*\r?\n+)') {
        $insertPos = $Matches[0].Length
        $text = $text.Substring(0, $insertPos) + "`r`n" + $yamlFence + "`r`n`r`n" + $text.Substring($insertPos)
      } else {
        $text = $yamlFence + "`r`n`r`n" + $text
      }
      $header = [regex]::Match($text, '(?ms)^```yaml\r?\n(?<metadata>.*?)^```\s*\r?$')
      if (-not $header.Success) {
        throw "Specification metadata fence missing: $path. Automatic insertion failed; operator intervention required."
      }
    }

    $metadata = $header.Groups['metadata'].Value
    foreach ($key in $values.Keys) {
      $pattern = '(?m)^' + [regex]::Escape($key) + ':[^\r\n]*'
      $matchedKeys = [regex]::Matches($metadata, $pattern)
      if ($matchedKeys.Count -eq 0) {
        $metadata = $metadata.TrimEnd("`r", "`n") + "`r`n$key`: $($values[$key])`r`n"
      } elseif ($matchedKeys.Count -eq 1) {
        $metadata = [regex]::Replace($metadata, $pattern, ($key + ': ' + $values[$key]))
      } else {
        throw "Ambiguous metadata: expected one '$key' field in $path, but found $($matchedKeys.Count). Operator intervention required."
      }
    }
    $group = $header.Groups['metadata']
    $updated = $text.Substring(0, $group.Index) + $metadata + $text.Substring($group.Index + $group.Length)
    if ($updated -ne $originalText) {
      [pscustomobject]@{ Path=$path; Original=$bytes; Content=$updated }
    }
  }
}

Export-ModuleMember -Function Get-LcmSpecificationStateEdits
