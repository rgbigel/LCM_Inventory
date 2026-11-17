<#
.SYNOPSIS
  Pure atoms for reading and writing .agents/ACTIVE_SESSION.md per the RULE-LCM-030 (5) session state schema.
.DESCRIPTION
  Module: modules/LcmSessionStateAtoms.psm1
  Purpose: Section-anchored access to ACTIVE_SESSION.md content. All functions take and return strings or
           objects; none reads or writes a file, so tests never touch the live .agents files (BUG-336 lesson).
  Path: LCM_Inventory/modules/LcmSessionStateAtoms.psm1
  Authors: Rolf, Claude
  Version: 10.7.4
  Date: 2026-11-17
  Rule: RULE-LCM-030 (5), RULE-PS-025
  Implementation Choices (CRP-350):
    - Section 1 fields are replaced only inside section 1 ("## 1. ..." up to the next "## n." heading),
      never by "first match in the file", so host blocks with the same field names stay untouched.
    - Host blocks are parsed from section 2 into a fixed field list; nested "  - " lines belong to the
      preceding field as list items (Attention Items).
    - Host findings: status outside the vocabulary (Active / Closed (<ts>)), Active with a Last Activity
      older than the workspace GoodNight, missing required fields.
.NOTES
  Caveats: the parser expects the "- **Field**: value" layout used by ACTIVE_SESSION.md; other layouts
  return no fields (and are reported as missing fields).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RequiredHostFields = @('Status', 'Last Activity', 'Current Task', 'Next Step', 'Open Operator Decisions', 'Attention Items')

function Get-LcmSessionSection {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
    [Parameter(Mandatory)][int]$Number
  )
  $m = [regex]::Match($Content, ('(?ms)^## {0}\. .*?(?=^## \d+\. |\z)' -f $Number))
  if (-not $m.Success) { return $null }
  [pscustomobject]@{ Start = $m.Index; Length = $m.Length; Text = $m.Value }
}

function ConvertTo-LcmSessionTimestamp {
  [CmdletBinding()]
  param([AllowNull()][AllowEmptyString()][string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
  $m = [regex]::Match($Text, '\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?')
  if (-not $m.Success) { return $null }
  $fmt = if ($m.Groups[1].Success) { 'yyyy-MM-dd HH:mm:ss' } else { 'yyyy-MM-dd HH:mm' }
  [datetime]::ParseExact($m.Value, $fmt, [Globalization.CultureInfo]::InvariantCulture)
}

function Get-LcmSessionWorkspaceField {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
    [Parameter(Mandatory)][string]$Name
  )
  $sec = Get-LcmSessionSection -Content $Content -Number 1
  if ($null -eq $sec) { return $null }
  $m = [regex]::Match($sec.Text, ('(?m)^- \*\*{0}\*\*:[ \t]*(.*?)[ \t]*\r?$' -f [regex]::Escape($Name)))
  if (-not $m.Success) { return $null }
  $m.Groups[1].Value
}

function Set-LcmSessionWorkspaceField {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Value,
    [string]$After = ''
  )
  $sec = Get-LcmSessionSection -Content $Content -Number 1
  if ($null -eq $sec) { throw 'ACTIVE_SESSION.md has no section "## 1."; nothing written.' }
  $nl = if ($Content.Contains("`r`n")) { "`r`n" } else { "`n" }
  $line = '- **{0}**: {1}' -f $Name, $Value
  $text = $sec.Text
  $fieldRx = [regex]::new(('(?m)^- \*\*{0}\*\*:.*?(?=\r?$)' -f [regex]::Escape($Name)))
  if ($fieldRx.IsMatch($text)) {
    $text = $fieldRx.Replace($text, { param($m) $line }, 1)
  } else {
    $anchor = $null
    if (-not [string]::IsNullOrEmpty($After)) {
      $anchor = [regex]::Match($text, ('(?m)^- \*\*{0}\*\*:.*?(?=\r?$)' -f [regex]::Escape($After)))
    }
    if ($null -eq $anchor -or -not $anchor.Success) {
      $anchor = [regex]::Match($text, '(?m)^## 1\. .*?(?=\r?$)')
      $insertAt = $anchor.Index + $anchor.Length
      $text = $text.Insert($insertAt, $nl + $nl + $line)
      $text = $text.Replace($line + $nl + $nl + '- **', $line + $nl + '- **')
    } else {
      $insertAt = $anchor.Index + $anchor.Length
      $text = $text.Insert($insertAt, $nl + $line)
    }
  }
  $Content.Substring(0, $sec.Start) + $text + $Content.Substring($sec.Start + $sec.Length)
}

function Get-LcmSessionHostBlocks {
  [CmdletBinding()]
  param([Parameter(Mandatory)][AllowEmptyString()][string]$Content)
  $sec = Get-LcmSessionSection -Content $Content -Number 2
  if ($null -eq $sec) { return @() }
  $result = [System.Collections.Generic.List[object]]::new()
  $parts = [regex]::Matches($sec.Text, '(?ms)^### Host:[ \t]*(.+?)[ \t]*\r?$(.*?)(?=^### Host:|\z)')
  foreach ($part in $parts) {
    $fields = [ordered]@{}
    $items = @{}
    $current = $null
    foreach ($raw in ($part.Groups[2].Value -split '\r?\n')) {
      $fm = [regex]::Match($raw, '^- \*\*(.+?)\*\*:[ \t]*(.*?)[ \t]*$')
      if ($fm.Success) {
        $current = $fm.Groups[1].Value
        $fields[$current] = $fm.Groups[2].Value
        $items[$current] = [System.Collections.Generic.List[string]]::new()
        continue
      }
      $im = [regex]::Match($raw, '^\s+- (.*?)\s*$')
      if ($im.Success -and $null -ne $current) { $items[$current].Add($im.Groups[1].Value) }
    }
    $id = $null
    foreach ($k in 'Session ID', 'Conversation ID') { if ($fields.Contains($k)) { $id = $fields[$k]; break } }
    $result.Add([pscustomobject]@{
        Name         = $part.Groups[1].Value
        Id           = $id
        Fields       = $fields
        Items        = $items
        LastActivity = ConvertTo-LcmSessionTimestamp -Text $(if ($fields.Contains('Last Activity')) { $fields['Last Activity'] } else { '' })
      })
  }
  , $result.ToArray()
}

function Get-LcmSessionHostFinding {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object]$HostBlock,
    [AllowNull()][Nullable[datetime]]$GoodNight
  )
  $out = [System.Collections.Generic.List[string]]::new()
  $missing = @($script:RequiredHostFields | Where-Object { -not $HostBlock.Fields.Contains($_) })
  if ($null -eq $HostBlock.Id) { $missing = @('Session ID / Conversation ID') + $missing }
  if ($missing.Count -gt 0) { $out.Add(('missing fields: {0}' -f ($missing -join ', '))) }
  $status = if ($HostBlock.Fields.Contains('Status')) { [string]$HostBlock.Fields['Status'] } else { '' }
  if ($status -notmatch '^(Active|Closed \(\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?\))') {
    $out.Add(('status "{0}" is outside the schema vocabulary (Active / Closed (<ts>))' -f $status))
  }
  if ($status -match '^Active' -and $null -ne $GoodNight -and $null -ne $HostBlock.LastActivity -and $HostBlock.LastActivity -lt $GoodNight) {
    $out.Add(('Active, but Last Activity {0:yyyy-MM-dd HH:mm:ss} is older than the last GoodNight {1:yyyy-MM-dd HH:mm:ss} (stale)' -f $HostBlock.LastActivity, $GoodNight))
  }
  $out.ToArray()
}

Export-ModuleMember -Function Get-LcmSessionSection, ConvertTo-LcmSessionTimestamp, Get-LcmSessionWorkspaceField, Set-LcmSessionWorkspaceField, Get-LcmSessionHostBlocks, Get-LcmSessionHostFinding
