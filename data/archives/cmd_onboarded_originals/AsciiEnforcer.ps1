<# 
Module: AsciiEnforcer.ps1
Purpose: Enforce strict ASCII-only content in repository files and repair mojibake arrow sequences.
Path: D:\Onedrive\cmd\AsciiEnforcer.ps1
Authors: Rolf
Version: 1.4.0
Changelog:
  1.4.0 - Removed all '+' concatenation; replaced with -f formatting to avoid parser errors.
  1.3.0 - Mojibake detection via byte sequences (no Unicode literals in script).
  1.2.0 - Switched mojibake replacements to .Replace().
  1.1.0 - Added mojibake arrow mapping.
  1.0.0 - Initial release.
#>

$root = "D:\Git_Repositories"

# Mojibake byte patterns → ASCII replacements
$patterns = @{
  ([System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA0,0xE2,0x80,0x99))) = '->'
  ([System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA0,0xEF,0xBF,0xBD))) = '<-'
  ([System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA0,0xE2,0x80,0x98))) = '^'
  ([System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA0,0xE2,0x80,0x9C))) = 'v'
}

# Counters
$cntTotal = 0
$cntAscii = 0
$cntNonAscii = 0
$cntSanitized = 0

# Logs
$logAscii = @()
$logNonAscii = @()
$logSanitized = @()

Get-ChildItem -Path $root -Recurse -File -Include *.md,*.ps1,*.psm1 |
  ForEach-Object {

    $cntTotal++
    $file = $_.FullName

    $bytes = [System.IO.File]::ReadAllBytes($file)
    $hasNonAscii = $bytes | Where-Object { $_ -gt 0x7F }

    if (-not $hasNonAscii) {
      $cntAscii++
      $logAscii += ('ASCII OK: {0}' -f $file)
      return
    }

    $cntNonAscii++
    $logNonAscii += ('Non-ASCII detected: {0}' -f $file)

    $text = [System.Text.Encoding]::UTF8.GetString($bytes)

    foreach ($key in $patterns.Keys) {
      $text = $text.Replace($key, $patterns[$key])
    }

    $ascii = ''
    foreach ($char in $text.ToCharArray()) {
      if ([int][char]$char -le 0x7F) {
        $ascii += $char
      }
      else {
        $ascii += '-'
      }
    }

    [System.IO.File]::WriteAllText(
      $file,
      $ascii,
      (New-Object System.Text.UTF8Encoding($false))
    )

    $cntSanitized++
    $logSanitized += ('Sanitized: {0}' -f $file)
  }

Write-Host ''
Write-Host '===== ASCII ENFORCER SUMMARY ====='
Write-Host ('Total files scanned: {0}' -f $cntTotal)
Write-Host ('ASCII OK:            {0}' -f $cntAscii)
Write-Host ('Non-ASCII found:     {0}' -f $cntNonAscii)
Write-Host ('Sanitized:           {0}' -f $cntSanitized)
Write-Host '=================================='
Write-Host ''

Write-Host '===== ASCII FILES ====='
$logAscii | ForEach-Object { Write-Host $_ }
Write-Host ''

Write-Host '===== NON-ASCII FILES ====='
$logNonAscii | ForEach-Object { Write-Host $_ }
Write-Host ''

Write-Host '===== SANITIZED FILES ====='
$logSanitized | ForEach-Object { Write-Host $_ }
Write-Host ''
