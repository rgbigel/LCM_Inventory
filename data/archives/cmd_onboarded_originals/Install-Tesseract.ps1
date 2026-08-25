# =================================================================================================
#  Module:      Install-Tesseract.ps1
#  Path:        D:\Onedrive\cmd
#  Author:      Rolf Bercht
#  Version:     1.0.0
# =================================================================================================

$ToolsRoot = "D:\Tools"
$TessDir   = "$ToolsRoot\Tesseract"
$ZipFile   = "$ToolsRoot\tesseract.zip"

# Official portable build (stable, no installer)
$TessURL = "https://digi.bib.uni-mannheim.de/tesseract/tesseract-ocr-w64-5.3.0-portable.zip"

Write-Host "Downloading Tesseract portable ZIP..."
Invoke-WebRequest -Uri $TessURL -OutFile $ZipFile -Headers @{ "User-Agent" = "Mozilla/5.0" }

Write-Host "Extracting..."
Expand-Archive -Path $ZipFile -DestinationPath $TessDir -Force

Remove-Item $ZipFile

# Add to SYSTEM PATH
$sysPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$sysPath += ";$TessDir"
[Environment]::SetEnvironmentVariable("Path", $sysPath, "Machine")

Write-Host "Tesseract installed to $TessDir" -ForegroundColor Green
