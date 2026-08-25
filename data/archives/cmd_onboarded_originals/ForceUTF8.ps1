<#
Module: ForceUTF8.ps1
Purpose: Unified encoding + character sanitizer for .md and .ps* files
Authors: Rolf
Version: 4.0.2
Path: D:\Git_Repositories\ForceUTF8.ps1
Changelog:
  - Corrected Replace() overloads to string/string everywhere
  - Added mojibake non-breaking hyphen (â€‘) fix
  - Fixed Unicode arrow replacement using literal characters
  - Changed sanitizer to drop disallowed chars only at beginning of text
  - Kept ASCII + Umlaut enforcement for .ps1/.psm1
  - Kept Unicode arrows/dashes/ellipsis for .md
#>

$root = 'D:\Git_Repositories'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$excludeDirs = @(
  'DiskAssignmentStatus_S1'
)

function IsAllowedChar($ch) {
  $code = [int][char]$ch
  if ($code -le 0x7F) { return $true }
  switch ($code) {
    0x00E4 { return $true } # ä
    0x00F6 { return $true } # ö
    0x00FC { return $true } # ü
    0x00C4 { return $true } # Ä
    0x00D6 { return $true } # Ö
    0x00DC { return $true } # Ü
    0x00DF { return $true } # ß
  }
  return $false
}

# Mojibake sequences (UTF-8 mis-decoded)
$mjRight = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA0,0xE2,0x80,0x99))
$mjLeft  = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA0,0xEF,0xBF,0xBD))
$mjUp    = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA0,0xE2,0x80,0x98))
$mjDown  = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA0,0xE2,0x80,0x9C))
$mjEm    = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0x94))
$mjEn    = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0x93))
$mjEll   = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA6))

$mjBullet1 = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA2))
$mjBullet2 = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA3))
$mjQuoteL  = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0x9C))
$mjQuoteR  = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0x9D))
$mjApos    = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0x99))
$mjDag     = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA0))
$mjDDag    = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0xA1))
$mjNbHyphen = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3,0xA2,0xE2,0x80,0x91)) # â€‘

Get-ChildItem -Path $root -Recurse -File -Include *.md,*.ps1,*.psm1 |
  ForEach-Object {

    $file = $_.FullName
    $ext  = $_.Extension.ToLower()

    $skip = $false
    foreach ($ex in $excludeDirs) {
      if ($file -like ('*' + $ex + '*')) { $skip = $true; break }
    }
    if ($skip) { return }

    $bytes = [System.IO.File]::ReadAllBytes($file)
    $text  = [System.Text.Encoding]::UTF8.GetString($bytes)

    if ($ext -eq '.md') {

      # Mojibake arrows → real Unicode arrows
      $text = $text.Replace($mjRight, [string][char]0x2192)
      $text = $text.Replace($mjLeft,  [string][char]0x2190)
      $text = $text.Replace($mjUp,    [string][char]0x2191)
      $text = $text.Replace($mjDown,  [string][char]0x2193)

      # Mojibake dashes and ellipsis → real Unicode
      $text = $text.Replace($mjEm,  [string][char]0x2014)
      $text = $text.Replace($mjEn,  [string][char]0x2013)
      $text = $text.Replace($mjEll, [string][char]0x2026)

      # Mojibake bullets → real bullets
      $text = $text.Replace($mjBullet1, [string][char]0x2022)
      $text = $text.Replace($mjBullet2, [string][char]0x2022)

      # Mojibake quotes → real Unicode quotes
      $text = $text.Replace($mjQuoteL, [string][char]0x201C)
      $text = $text.Replace($mjQuoteR, [string][char]0x201D)
      $text = $text.Replace($mjApos,   [string][char]0x2019)

      # Mojibake daggers → real Unicode daggers
      $text = $text.Replace($mjDag,  [string][char]0x2020)
      $text = $text.Replace($mjDDag, [string][char]0x2021)

      # Mojibake non-breaking hyphen → ASCII '-'
      $text = $text.Replace($mjNbHyphen, '-')

      # Remove zero-width spaces
      $text = $text.Replace([string][char]0x200B, '')

      # Normalize minus-like Unicode to ASCII '-'
      $text = $text.Replace([string][char]0x2010, '-')
      $text = $text.Replace([string][char]0x2011, '-')
      $text = $text.Replace([string][char]0x2012, '-')
      $text = $text.Replace([string][char]0x2212, '-')

      [System.IO.File]::WriteAllText($file, $text, $utf8NoBom)
      return
    }

    # .ps1 / .psm1: strict ASCII + Umlaute

    # Unicode arrows → ASCII arrows (literal chars)
    $text = $text.Replace('→', '->')
    $text = $text.Replace('←', '<-')
    $text = $text.Replace('↑', '^')
    $text = $text.Replace('↓', 'v')

    # Mojibake arrows → ASCII arrows
    $text = $text.Replace($mjRight, '->')
    $text = $text.Replace($mjLeft,  '<-')
    $text = $text.Replace($mjUp,    '^')
    $text = $text.Replace($mjDown,  'v')

    # Mojibake dashes and ellipsis → ASCII
    $text = $text.Replace($mjEm,  '--')
    $text = $text.Replace($mjEn,  '-')
    $text = $text.Replace($mjEll, '...')

    # Unicode dashes and minus → ASCII
    $text = $text.Replace([string][char]0x2014, '--')
    $text = $text.Replace([string][char]0x2013, '-')
    $text = $text.Replace([string][char]0x2012, '-')
    $text = $text.Replace([string][char]0x2010, '-')
    $text = $text.Replace([string][char]0x2011, '-')
    $text = $text.Replace([string][char]0x2212, '-')

    # Mojibake bullets → ASCII
    $text = $text.Replace($mjBullet1, '*')
    $text = $text.Replace($mjBullet2, '*')

    # Mojibake quotes → ASCII
    $text = $text.Replace($mjQuoteL, '"')
    $text = $text.Replace($mjQuoteR, '"')
    $text = $text.Replace($mjApos,   "'")

    # Mojibake daggers → ASCII
    $text = $text.Replace($mjDag,  '+')
    $text = $text.Replace($mjDDag, '++')

    # Mojibake non-breaking hyphen → ASCII '-'
    $text = $text.Replace($mjNbHyphen, '-')

    # Remove zero-width spaces
    $text = $text.Replace([string][char]0x200B, '')

    # Final ASCII + Umlaute enforcement
    $ascii = ''
    $seenAllowed = $false

    foreach ($ch in $text.ToCharArray()) {

      if (-not $seenAllowed) {
        if (IsAllowedChar $ch) {
          $ascii += $ch
          $seenAllowed = $true
        }
        else {
          # drop BOM / ZWSP / mojibake garbage at beginning
        }
      }
      else {
        if (IsAllowedChar $ch) {
          $ascii += $ch
        }
        else {
          $ascii += '-'
        }
      }
    }

    # Normalize indentation to 2 spaces
    $ascii = $ascii -replace "`t", '  '
    $ascii = $ascii -replace '^ {4}', '  '

    [System.IO.File]::WriteAllText($file, $ascii, $utf8NoBom)
  }
