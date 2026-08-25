# Module: Test-SaveClipboard.psm1

$ScriptPath = "D:\OneDrive\cmd\SaveClipboard.ps1"
$TestDir    = "C:\Temp"

function Invoke-TestCase {
    param(
        [string]$Name,
        [string]$FolderArg,
        [string]$FileArg,
        [string]$ClipboardType,
        [string]$ClipboardValue
    )

    Write-Host "=== Running test: $Name ==="

    # --- Set clipboard content ---
    if ($ClipboardType -eq "text") {
        Set-Clipboard -Value $ClipboardValue
    }
    elseif ($ClipboardType -eq "image") {
        $bmp = New-Object System.Drawing.Bitmap 50,50
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::Red)
        [Windows.Forms.Clipboard]::SetImage($bmp)
    }

    # --- Correct invocation: -d AFTER script path ---
    pwsh -NoLogo -NoProfile --% -File "$ScriptPath" "$FolderArg" "$FileArg" -d
}

function Start-SaveClipboardTests {

    if (-not (Test-Path $TestDir)) {
        New-Item -ItemType Directory -Path $TestDir | Out-Null
    }

    $Matrix = @(
        @{ Name="FolderOnly_Text"; Folder=$TestDir; File=""; Type="text"; Value="example.txt" }
        @{ Name="FolderOnly_Image"; Folder=$TestDir; File=""; Type="image"; Value="" }

        @{ Name="FileOnly_Text"; Folder=""; File="$TestDir\test.txt"; Type="text"; Value="hello.txt" }
        @{ Name="FileOnly_Image"; Folder=""; File="$TestDir\test.png"; Type="image"; Value="" }

        @{ Name="Both_Text"; Folder=$TestDir; File="$TestDir\file.ini"; Type="text"; Value="config.ini" }
        @{ Name="Both_Image"; Folder=$TestDir; File="$TestDir\image.jpg"; Type="image"; Value="" }

        @{ Name="MissingExt_Text"; Folder=$TestDir; File=""; Type="text"; Value="NoExt" }
        @{ Name="Dotfile_Text"; Folder=$TestDir; File=""; Type="text"; Value=".abc" }
        @{ Name="Json_Text"; Folder=$TestDir; File=""; Type="text"; Value="settings.json" }
        @{ Name="Reg_Text"; Folder=$TestDir; File=""; Type="text"; Value="registry.reg" }
    )

    foreach ($case in $Matrix) {
        Invoke-TestCase -Name $case.Name -FolderArg $case.Folder -FileArg $case.File -ClipboardType $case.Type -ClipboardValue $case.Value
    }
}

# Auto-run
Start-SaveClipboardTests
