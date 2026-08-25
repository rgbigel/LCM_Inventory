# =================================================================================================
#  Module:      Install-OCRTools.ps1
#  Path:        D:\Onedrive\cmd
#  Author:      Rolf Bercht
#  Version:     1.0.3
#  Changelog:
#      1.003  --------  Fixed GitHub downloads (User-Agent + direct asset URLs)
# =================================================================================================

$ToolsRoot = "D:\Tools"
New-Item -ItemType Directory -Force -Path $ToolsRoot | Out-Null

# -------------------------------------------------------------------------------------------------
# Helper: Safe download with User-Agent
# -------------------------------------------------------------------------------------------------
function Download-File($url, $dest) {
    Invoke-WebRequest `
        -Uri $url `
        -OutFile $dest `
        -Headers @{ "User-Agent" = "Mozilla/5.0" }
}

Write-Host "Installing OCR dependencies into $ToolsRoot ..." -ForegroundColor Cyan

# -------------------------------------------------------------------------------------------------
# 1) Tesseract OCR
# -------------------------------------------------------------------------------------------------

$TessURL = "https://github.com/UB-Mannheim/tesseract/releases/download/v5.3.0.20221214/tesseract-ocr-w64-setup-5.3.0.20221214.exe"
$TessExe = "$ToolsRoot\tesseract-installer.exe"

Write-Host "Downloading Tesseract..."
Download-File $TessURL $TessExe

Start-Process -FilePath $TessExe -ArgumentList "/SILENT", "/DIR=$ToolsRoot\Tesseract" -Wait

# Add to SYSTEM PATH
$sysPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$sysPath += ";$ToolsRoot\Tesseract;$ToolsRoot\Tesseract\tessdata"
[Environment]::SetEnvironmentVariable("Path", $sysPath, "Machine")

Write-Host "Tesseract installed." -ForegroundColor Green


# -------------------------------------------------------------------------------------------------
# 2) Ghostscript
# -------------------------------------------------------------------------------------------------

$GSURL = "https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10071/gs10071w64.exe"
$GSExe = "$ToolsRoot\ghostscript-installer.exe"

Write-Host "Downloading Ghostscript..."
Download-File $GSURL $GSExe

Start-Process -FilePath $GSExe -ArgumentList "/SILENT", "/DIR=$ToolsRoot\Ghostscript" -Wait

# Add to SYSTEM PATH
$sysPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$sysPath += ";$ToolsRoot\Ghostscript\bin"
[Environment]::SetEnvironmentVariable("Path", $sysPath, "Machine")

Write-Host "Ghostscript installed." -ForegroundColor Green


# -------------------------------------------------------------------------------------------------
# 3) OCRmyPDF (pip already available)
# -------------------------------------------------------------------------------------------------

Write-Host "Installing OCRmyPDF via pip..."
pip install ocrmypdf

Write-Host "OCRmyPDF installed." -ForegroundColor Green


# -------------------------------------------------------------------------------------------------
# 4) Verification
# -------------------------------------------------------------------------------------------------

Write-Host "`nVerifying installation..." -ForegroundColor Yellow

Write-Host "Tesseract version:"
tesseract --version

Write-Host "`nGhostscript version:"
gswin64c -v

Write-Host "`nOCRmyPDF version:"
ocrmypdf --version

Write-Host "`nAll components installed successfully." -ForegroundColor Green
