<#
Module: FixLocalizedNames.ps1
Purpose: Disable localized folder names and remove desktop.ini overlays
Authors: Rolf
Version: 1.0.0
#>

# Registry: force real folder names
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'UseLocalizedFolderNames' -Type DWord -Value 0

# Stop Explorer
Stop-Process -Name explorer -Force

# Remove desktop.ini overlays
$paths = @(
  'C:\Program Files',
  'C:\Program Files (x86)',
  'C:\Users',
  'C:\Users\Public',
  'C:\Users\Default',
  'C:\ProgramData'
)

foreach ($p in $paths) {

  $ini = Join-Path $p 'desktop.ini'

  if (Test-Path $ini) {

    $content = Get-Content $ini -Encoding UTF8

    $fixed = @()

    foreach ($line in $content) {

      if ($line -like 'LocalizedResourceName*') {
        continue
      }

      if ($line -like 'IconResource*') {
        continue
      }

      $fixed += $line
    }

    Set-Content -Path $ini -Value $fixed -Encoding UTF8
  }
}

# Restart Explorer
Start-Process explorer.exe
