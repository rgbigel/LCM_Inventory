<#
.SYNOPSIS
  Line-ending atoms: classify text files and convert lone LF to CRLF at byte level.
.DESCRIPTION
  Module: LcmLineEndingAtoms
  Purpose: Reusable, idempotent atoms that enforce the LCM line-ending invariant (newline-crlf, operator
  decision Option A, CRP-332) without re-encoding: only bytes 0x0A not preceded by 0x0D are expanded.
  Path: LCM_Inventory/modules/LcmLineEndingAtoms.psm1
  Authors: Rolf, Claude (Anthropic)
  Version: 10.6.4
  Date: 2026-11-15

  Implementation Choices (CRP-332):
  - Byte-level conversion keeps BOM, encoding and every other byte unchanged (learned advice: a UTF-8
    round-trip corrupted a script once).
  - Extension allow-list instead of content sniffing; files with a NUL byte or a UTF-16/32 BOM are skipped.
  - *.sh (LF by design) and *.go (gofmt rewrites to LF) are excluded; see CRP-332 Walkthrough.
  - A CRLF correction is not a review-relevant change (operator 2026-11-15).
.NOTES
  Caveats: Writes in place via a temp file and atomic replace; a file locked by another process is reported,
  not retried indefinitely. No elevation required.
#>

Set-StrictMode -Version Latest

$script:CrlfExtensions = @(
  '.ps1', '.psm1', '.psd1', '.ps1xml', '.cmd', '.bat', '.json', '.md', '.py', '.html', '.htm', '.css', '.js',
  '.txt', '.yaml', '.yml', '.xml', '.sql', '.csv', '.ini', '.cfg', '.toml', '.svg', '.gitattributes', '.gitignore',
  '.editorconfig', '.mmd', '.xaml', '.ahk', '.vbs', '.reg'
)
$script:ExcludedDirectoryNames = @('.git', 'node_modules', '.venv', 'venv', '__pycache__', 'bin', 'obj')

function Get-LcmCrlfExtensions {
  <#
  .SYNOPSIS
    Returns the extensions that the LCM line-ending invariant converts to CRLF.
  #>
  [CmdletBinding()]
  param()
  return @($script:CrlfExtensions)
}

function Test-LcmCrlfCandidatePath {
  <#
  .SYNOPSIS
    True when the path has a CRLF-governed extension and lies outside excluded directories.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)
  $name = [IO.Path]::GetFileName($Path)
  $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
  if ([string]::IsNullOrEmpty($extension) -and $name.StartsWith('.')) { $extension = $name.ToLowerInvariant() }
  if ($script:CrlfExtensions -notcontains $extension) { return $false }
  $segments = @($Path -split '[\\/]')
  foreach ($segment in $segments) {
    if ($script:ExcludedDirectoryNames -contains $segment) { return $false }
  }
  return $true
}

function Get-LcmLineEndingStats {
  <#
  .SYNOPSIS
    Counts CRLF and lone LF line breaks in a byte array and reports whether it looks binary or UTF-16/32.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes)
  $crlf = 0
  $loneLf = 0
  $binary = $false
  $wide = $false
  if ($Bytes.Length -ge 2 -and (($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) -or ($Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF))) { $wide = $true }
  for ($i = 0; $i -lt $Bytes.Length; $i++) {
    $b = $Bytes[$i]
    if (0 -eq $b) { $binary = $true; break }
    if (0x0A -eq $b) {
      if ($i -gt 0 -and 0x0D -eq $Bytes[$i - 1]) { $crlf++ } else { $loneLf++ }
    }
  }
  return [pscustomobject]@{ Crlf = $crlf; LoneLf = $loneLf; Binary = $binary; Wide = $wide }
}

function ConvertTo-LcmCrlfBytes {
  <#
  .SYNOPSIS
    Pure function: returns a copy of the bytes with every lone LF expanded to CRLF; existing CRLF untouched.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes)
  $out = [IO.MemoryStream]::new($Bytes.Length + 64)
  try {
    for ($i = 0; $i -lt $Bytes.Length; $i++) {
      $b = $Bytes[$i]
      if (0x0A -eq $b -and -not ($i -gt 0 -and 0x0D -eq $Bytes[$i - 1])) { $out.WriteByte(0x0D) }
      $out.WriteByte($b)
    }
    return , $out.ToArray()
  } finally {
    $out.Dispose()
  }
}

function Repair-LcmLineEnding {
  <#
  .SYNOPSIS
    Converts one file to CRLF in place (or reports only with -DryRun); returns a result object.
  .OUTPUTS
    [pscustomobject] Path, Status (Converted|WouldConvert|Clean|Skipped|Failed), LoneLf, Reason.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [switch]$DryRun,
    [switch]$IgnoreExtension
  )
  $result = [ordered]@{ Path = $Path; Status = 'Clean'; LoneLf = 0; Reason = '' }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    $result.Status = 'Skipped'; $result.Reason = 'not a file'
    return [pscustomobject]$result
  }
  if (-not $IgnoreExtension -and -not (Test-LcmCrlfCandidatePath -Path $Path)) {
    $result.Status = 'Skipped'; $result.Reason = 'not a CRLF-governed type'
    return [pscustomobject]$result
  }
  try {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $stats = Get-LcmLineEndingStats -Bytes $bytes
    if ($stats.Binary -or $stats.Wide) {
      $result.Status = 'Skipped'; $result.Reason = 'binary or UTF-16/32'
      return [pscustomobject]$result
    }
    $result.LoneLf = $stats.LoneLf
    if (0 -eq $stats.LoneLf) { return [pscustomobject]$result }
    if ($DryRun) {
      $result.Status = 'WouldConvert'
      return [pscustomobject]$result
    }
    $converted = ConvertTo-LcmCrlfBytes -Bytes $bytes
    $temp = $Path + '.crlf.tmp'
    [IO.File]::WriteAllBytes($temp, $converted)
    $attempt = 0
    while ($true) {
      try {
        Move-Item -LiteralPath $temp -Destination $Path -Force
        break
      } catch {
        $attempt++
        if ($attempt -ge 3) { throw }
        Start-Sleep -Milliseconds (200 * $attempt)
      }
    }
    $result.Status = 'Converted'
  } catch {
    $result.Status = 'Failed'
    $result.Reason = $_.Exception.Message
    $leftover = $Path + '.crlf.tmp'
    if (Test-Path -LiteralPath $leftover) { Remove-Item -LiteralPath $leftover -Force -ErrorAction SilentlyContinue }
  }
  return [pscustomobject]$result
}

function Get-LcmCrlfCandidateFiles {
  <#
  .SYNOPSIS
    Enumerates CRLF-governed files below a root without following junctions or symbolic links.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Root,
    [switch]$NoRecurse
  )
  $pending = [Collections.Generic.Stack[string]]::new()
  $pending.Push((Resolve-Path -LiteralPath $Root).Path)
  while ($pending.Count -gt 0) {
    $dir = $pending.Pop()
    foreach ($file in [IO.Directory]::EnumerateFiles($dir)) {
      if (Test-LcmCrlfCandidatePath -Path $file) { $file }
    }
    if ($NoRecurse) { continue }
    foreach ($sub in [IO.Directory]::EnumerateDirectories($dir)) {
      $info = [IO.DirectoryInfo]::new($sub)
      if ($info.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { continue }
      if ($script:ExcludedDirectoryNames -contains $info.Name) { continue }
      $pending.Push($sub)
    }
  }
}

Export-ModuleMember -Function Get-LcmCrlfExtensions, Test-LcmCrlfCandidatePath, Get-LcmLineEndingStats, ConvertTo-LcmCrlfBytes, Repair-LcmLineEnding, Get-LcmCrlfCandidateFiles
