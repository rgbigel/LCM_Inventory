# Test_SaveClipboard.ps1
# Automated test suite for SaveClipboard.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ScriptPath = "D:\OneDrive\cmd\SaveClipboard.ps1"
$TestDir    = "C:\Temp"

$Global:TestResults = @()
$Global:Coverage = [ordered]@{
    FolderOnly      = $false
    FileOnly        = $false
    BothParams      = $false
    TextMode        = $false
    ImageMode       = $false
    ClipboardName   = $false
    HeaderName      = $false
    Dotfile         = $false
    MissingExt      = $false
    JsonExt         = $false
    RegExt          = $false
    Collision       = $false
}

function Add-Result {
    param($Name, $Expected, $Actual, $Pass)
    $Global:TestResults += [ordered]@{
        Test     = $Name
        Expected = $Expected
        Actual   = $Actual
        Result   = $(if ($Pass) { "PASS" } else { "FAIL" })
    }
}

function New-TestScriptCopy {
    param([string]$HeaderFilename)

    $TestScript = "D:\OneDrive\cmd\SaveClipboard_TEST.ps1"
    $content = Get-Content $ScriptPath

    $content = $content -replace '^(#\s*File:).+$', "`$1 $HeaderFilename"
    Set-Content -Path $TestScript -Value $content -Encoding UTF8

    return $TestScript
}

function New-CollisionFiles {
    param(
        [string]$BaseName,
        [string]$Ext,
        [int]$Count
    )

    for ($i = 0; $i -lt $Count; $i++) {
        $suffix = if ($i -eq 0) { "" } else { "_{0:000}" -f ($i - 1) }
        $name = "$BaseName$suffix$Ext"
        $path = Join-Path $TestDir $name
        Set-Content -Path $path -Value "collision test" -Encoding UTF8
    }
}

function Invoke-TestCase {
    param(
        [string]$Name,
        [string]$Folder,
        [string]$File,
        [string]$Type,
        [string]$Value,
        [string]$Expected,
        [string]$Coverage,
        [string]$HeaderOverride,
        [string]$CollisionBase,
        [string]$CollisionExt,
        [int]$CollisionCount
    )

    Write-Host "=== Running test: $Name ==="

    if ($Coverage) { $Global:Coverage[$Coverage] = $true }

    if ($Type -eq "text") {
        Set-Clipboard -Value $Value
        $Global:Coverage["TextMode"] = $true
    }
    elseif ($Type -eq "image") {
        $bmp = New-Object System.Drawing.Bitmap 50,50
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::Red)
        [Windows.Forms.Clipboard]::SetImage($bmp)
        $Global:Coverage["ImageMode"] = $true
    }

    if ($Folder -and -not $File) { $Global:Coverage["FolderOnly"] = $true }
    if ($File -and -not $Folder) { $Global:Coverage["FileOnly"] = $true }
    if ($File -and $Folder)      { $Global:Coverage["BothParams"] = $true }

    $EffectiveScript = $ScriptPath
    if ($HeaderOverride) {
        $EffectiveScript = New-TestScriptCopy -HeaderFilename $HeaderOverride
        $Global:Coverage["HeaderName"] = $true
    }

    if ($CollisionBase) {
        New-CollisionFiles -BaseName $CollisionBase -Ext $CollisionExt -Count $CollisionCount
        $Global:Coverage["Collision"] = $true
    }

    # Normalize nulls to empty strings
    if ($null -eq $Folder) { $Folder = "" }
    if ($null -eq $File)   { $File   = "" }

    # Named-parameter invocation to avoid ambiguity
    pwsh -NoLogo -NoProfile -File $EffectiveScript -FolderPath "$Folder" -FilePath "$File" -d

    $ExpectedPath = Join-Path $TestDir $Expected

    if (Test-Path $ExpectedPath) {
        Add-Result -Name $Name -Expected $Expected -Actual $Expected -Pass $true
    }
    else {
        $actual = Get-ChildItem -Path $TestDir | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Add-Result -Name $Name -Expected $Expected -Actual $actual.Name -Pass $false
    }
}

function Start-SaveClipboardTests {

    if (-not (Test-Path $TestDir)) {
        New-Item -ItemType Directory -Path $TestDir | Out-Null
    }

    $Matrix = @(
        @{ Name="FolderOnly_Text"; Folder=$TestDir; File=""; Type="text"; Value="example.txt"; Expected="example.txt"; Coverage="ClipboardName" }
        @{ Name="FolderOnly_Image"; Folder=$TestDir; File=""; Type="image"; Value=""; Expected="ClipboardOutput.png"; Coverage="ImageMode" }

        @{ Name="FileOnly_Text"; Folder=""; File="$TestDir\test.txt"; Type="text"; Value="hello.txt"; Expected="hello.txt"; Coverage="ClipboardName" }
        @{ Name="FileOnly_Image"; Folder=""; File="$TestDir\test.png"; Type="image"; Value=""; Expected="test.png"; Coverage="ImageMode" }

        @{ Name="Both_Text"; Folder=$TestDir; File="$TestDir\file.ini"; Type="text"; Value="config.ini"; Expected="config.ini"; Coverage="ClipboardName" }
        @{ Name="Both_Image"; Folder=$TestDir; File="$TestDir\image.jpg"; Type="image"; Value=""; Expected="image.jpg"; Coverage="ImageMode" }

        @{ Name="MissingExt_Text"; Folder=$TestDir; File=""; Type="text"; Value="NoExt"; Expected="NoExt.txt"; Coverage="MissingExt" }
        @{ Name="Dotfile_Text"; Folder=$TestDir; File=""; Type="text"; Value=".abc"; Expected=".abc"; Coverage="Dotfile" }
        @{ Name="Json_Text"; Folder=$TestDir; File=""; Type="text"; Value="settings.json"; Expected="settings.json"; Coverage="JsonExt" }
        @{ Name="Reg_Text"; Folder=$TestDir; File=""; Type="text"; Value="registry.reg"; Expected="registry.reg"; Coverage="RegExt" }

        @{ Name="Header_FileLine_Text"; Folder=$TestDir; File=""; Type="text"; Value="NoFilename"; Expected="HeaderName.txt"; Coverage="HeaderName"; HeaderOverride="HeaderName.txt" }
        @{ Name="Header_FileLine_Image"; Folder=$TestDir; File=""; Type="image"; Value=""; Expected="HeaderImage.png"; Coverage="HeaderName"; HeaderOverride="HeaderImage.png" }

        @{ Name="Collision_Text"; Folder=$TestDir; File=""; Type="text"; Value="SaveClipboard.txt"; Expected="SaveClipboard_000.txt"; Coverage="Collision"; CollisionBase="SaveClipboard"; CollisionExt=".txt"; CollisionCount=1 }
        @{ Name="Collision_Text_Multi"; Folder=$TestDir; File=""; Type="text"; Value="SaveClipboard.txt"; Expected="SaveClipboard_002.txt"; Coverage="Collision"; CollisionBase="SaveClipboard"; CollisionExt=".txt"; CollisionCount=3 }
    )

    foreach ($case in $Matrix) {
        Invoke-TestCase @case
    }

    Write-Host ""
    Write-Host "=== TEST REPORT ==="
    foreach ($r in $Global:TestResults) {
        Write-Host ("{0,-25} {1,-25} {2,-25} {3}" -f $r.Test, $r.Expected, $r.Actual, $r.Result)
    }

    Write-Host ""
    Write-Host "=== COVERAGE ==="
    foreach ($k in $Global:Coverage.Keys) {
        Write-Host ("{0,-15} : {1}" -f $k, $Global:Coverage[$k])
    }

    Write-Host ""
    Write-Host "=== SUMMARY ==="
    $pass = ($Global:TestResults | Where-Object { $_.Result -eq "PASS" }).Count
    $fail = ($Global:TestResults | Where-Object { $_.Result -eq "FAIL" }).Count
    Write-Host "Passed: $pass"
    Write-Host "Failed: $fail"
}

Start-SaveClipboardTests
