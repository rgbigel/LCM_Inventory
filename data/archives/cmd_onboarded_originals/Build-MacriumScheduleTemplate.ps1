param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ZipFile,

    [Parameter(Mandatory = $false)]
    [Alias("n")]
    [string]$TemplateName = "Generated Template",

    [Parameter(Mandatory = $false)]
    [switch]$t,

    [Parameter(Mandatory = $false)]
    [switch]$h
)

<#
Module: Build-MacriumScheduleTemplate.ps1
Purpose: Extract Macrium schedule parameters from a Schedules.zip file and build a unified Schedule-Template.xml
Path: D:\OneDrive\cmd\Build-MacriumScheduleTemplate.ps1
Authors: Rolf + Copilot
Version: 1.4
Changelog:
- Added positional ZipFile parameter
- Added -n alias for TemplateName
- Added -t trace/debug mode
- Added -h help
- Added final user feedback output
#>

if ($h) {
    Write-Host "Build-MacriumScheduleTemplate.ps1"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  Build-MacriumScheduleTemplate.ps1 <ZipFile> [-n <name>] [-t] [-h]"
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  Build-MacriumScheduleTemplate.ps1 D:\Reflect\Schedules.zip -n ""D5P0 Monthly"" -t"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  ZipFile        Path to Schedules.zip (positional)"
    Write-Host "  -n             Template name (alias for -TemplateName)"
    Write-Host "  -t             Trace/debug mode"
    Write-Host "  -h             Show this help"
    exit 0
}

if (-not (Test-Path -LiteralPath $ZipFile)) {
    Write-Host "ERROR: ZIP file not found."
    exit 1
}

$OutDir  = "C:\Temp"
$OutFile = Join-Path $OutDir "Schedule-Template.xml"
$LogFile = Join-Path $OutDir "Schedule-Template.log"

if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

"Macrium Schedule Template Generation Log" | Out-File -FilePath $LogFile -Encoding ASCII
"Template Name: $TemplateName" | Out-File -FilePath $LogFile -Append -Encoding ASCII
"ZIP File: $ZipFile" | Out-File -FilePath $LogFile -Append -Encoding ASCII
"Trace Mode: $t" | Out-File -FilePath $LogFile -Append -Encoding ASCII
"----------------------------------------" | Out-File -FilePath $LogFile -Append -Encoding ASCII

if ($t) {
    Write-Host "[TRACE] TemplateName: $TemplateName"
    Write-Host "[TRACE] ZIP: $ZipFile"
}
$TempRoot  = $env:TEMP
$GuidValue = [guid]::NewGuid().ToString()
$Temp      = Join-Path $TempRoot ("MacriumSched_" + $GuidValue)

New-Item -ItemType Directory -Path $Temp | Out-Null
if ($t) { Write-Host "[TRACE] Temp folder: $Temp" }

try {
    Expand-Archive -Path $ZipFile -DestinationPath $Temp -Force
}
catch {
    $Err = $_.Exception.Message
    "ERROR: Failed to extract ZIP." | Out-File -FilePath $LogFile -Append -Encoding ASCII
    $Err | Out-File -FilePath $LogFile -Append -Encoding ASCII
    if ($t) { Write-Host "[TRACE] Extract failed: $Err" }
    exit 1
}

$schFiles = Get-ChildItem -LiteralPath $Temp -Filter "*.sch" -ErrorAction SilentlyContinue

if ($schFiles.Count -eq 0) {
    "ERROR: No .sch files found." | Out-File -FilePath $LogFile -Append -Encoding ASCII
    if ($t) { Write-Host "[TRACE] No .sch files found." }
    exit 1
}

"Found .sch files:" | Out-File -FilePath $LogFile -Append -Encoding ASCII
foreach ($f in $schFiles) {
    $f.FullName | Out-File -FilePath $LogFile -Append -Encoding ASCII
    if ($t) { Write-Host "[TRACE] .sch: $($f.FullName)" }
}

function Get-NodeValue {
    param([xml]$XmlObject, [string]$NodeName)
    $Value = $XmlObject.Task.$NodeName
    if ($Value -eq $null) { return "" }
    return ($Value | Out-String).Trim()
}

function Parse-Trigger {
    param([string]$TriggerString)

    $Result = @{
        Time = ""
        Week = ""
        Day = ""
        StartDate = ""
    }

    if ($TriggerString -match "At\s+(\d{2}:\d{2})") {
        $Result.Time = $matches[1]
    }

    if ($TriggerString -match "the\s+(\w+)\s+(\w{2})") {
        $Result.Week = $matches[1]
        $Result.Day  = $matches[2]
    }

    if ($TriggerString -match "starting\s+(\d{8})") {
        $Raw   = $matches[1]
        $Year  = $Raw.Substring(0,4)
        $Month = $Raw.Substring(4,2)
        $Day   = $Raw.Substring(6,2)
        $Result.StartDate = $Year + "-" + $Month + "-" + $Day
    }

    return $Result
}

$Template = New-Object System.Xml.XmlDocument
$Root     = $Template.CreateElement("ScheduleTemplate")
$Template.AppendChild($Root) | Out-Null

$NameNode = $Template.CreateElement("Name")
$NameNode.InnerText = $TemplateName
$Root.AppendChild($NameNode) | Out-Null

$DescNode = $Template.CreateElement("Description")
$DescNode.InnerText = "Generated from Schedules.zip"
$Root.AppendChild($DescNode) | Out-Null

$SchedulesNode = $Template.CreateElement("Schedules")
$Root.AppendChild($SchedulesNode) | Out-Null
foreach ($File in $schFiles) {

    $Content = Get-Content -LiteralPath $File.FullName -ErrorAction SilentlyContinue
    if ($Content -eq $null) { 
        if ($t) { Write-Host "[TRACE] Empty file: $($File.FullName)" }
        continue 
    }

    try { 
        $Xml = [xml]$Content 
    }
    catch { 
        if ($t) { Write-Host "[TRACE] Invalid XML: $($File.FullName)" }
        continue 
    }

    $Params  = Get-NodeValue -XmlObject $Xml -NodeName "Parameters"
    $Trigger = Get-NodeValue -XmlObject $Xml -NodeName "TriggerString"

    if ($Params -eq "") { 
        if ($t) { Write-Host "[TRACE] No <Parameters> in: $($File.FullName)" }
        continue 
    }

    $Type = "Unknown"
    if ($Params -match "-full") { $Type = "Full" }
    if ($Params -match "-diff") { $Type = "Differential" }
    if ($Params -match "-inc")  { $Type = "Incremental" }

    $Freq = "Unknown"
    if ($Params -match "-freq\s+(\w+)") { $Freq = $matches[1] }

    $Parsed = Parse-Trigger -TriggerString $Trigger

    "Schedule detected:" | Out-File -FilePath $LogFile -Append -Encoding ASCII
    "Type: $Type" | Out-File -FilePath $LogFile -Append -Encoding ASCII
    "Frequency: $Freq" | Out-File -FilePath $LogFile -Append -Encoding ASCII
    "Trigger: $Trigger" | Out-File -FilePath $LogFile -Append -Encoding ASCII
    "Time: $($Parsed.Time)" | Out-File -FilePath $LogFile -Append -Encoding ASCII
    "Week: $($Parsed.Week)" | Out-File -FilePath $LogFile -Append -Encoding ASCII
    "Day: $($Parsed.Day)" | Out-File -FilePath $LogFile -Append -Encoding ASCII
    "StartDate: $($Parsed.StartDate)" | Out-File -FilePath $LogFile -Append -Encoding ASCII
    "----------------------------------------" | Out-File -FilePath $LogFile -Append -Encoding ASCII

    if ($t) {
        Write-Host "[TRACE] Schedule:"
        Write-Host "        Type      : $Type"
        Write-Host "        Frequency : $Freq"
        Write-Host "        Trigger   : $Trigger"
        Write-Host "        Time      : $($Parsed.Time)"
        Write-Host "        Week      : $($Parsed.Week)"
        Write-Host "        Day       : $($Parsed.Day)"
        Write-Host "        StartDate : $($Parsed.StartDate)"
    }

    $Sched = $Template.CreateElement("Schedule")

    $NodeType = $Template.CreateElement("Type")
    $NodeType.InnerText = $Type
    $Sched.AppendChild($NodeType) | Out-Null

    $NodeFreq = $Template.CreateElement("Frequency")
    $NodeFreq.InnerText = $Freq
    $Sched.AppendChild($NodeFreq) | Out-Null

    $NodeWeek = $Template.CreateElement("Week")
    $NodeWeek.InnerText = $Parsed.Week
    $Sched.AppendChild($NodeWeek) | Out-Null

    $NodeDay = $Template.CreateElement("Day")
    $NodeDay.InnerText = $Parsed.Day
    $Sched.AppendChild($NodeDay) | Out-Null

    $NodeTime = $Template.CreateElement("Time")
    $NodeTime.InnerText = $Parsed.Time
    $Sched.AppendChild($NodeTime) | Out-Null

    $NodeStart = $Template.CreateElement("StartDate")
    $NodeStart.InnerText = $Parsed.StartDate
    $Sched.AppendChild($NodeStart) | Out-Null

    $SchedulesNode.AppendChild($Sched) | Out-Null
}

try {
    $Template.Save($OutFile)
}
catch {
    $Err = $_.Exception.Message
    "ERROR: Failed to write output XML." | Out-File -FilePath $LogFile -Append -Encoding ASCII
    $Err | Out-File -FilePath $LogFile -Append -Encoding ASCII
    if ($t) { Write-Host "[TRACE] Save failed: $Err" }
    exit 1
}

"SUCCESS: Template written to $OutFile" | Out-File -FilePath $LogFile -Append -Encoding ASCII

Write-Host "Template name used : $TemplateName"
Write-Host "Output XML written : $OutFile"
Write-Host "Log file written   : $LogFile"

if ($t) { Write-Host "[TRACE] Completed successfully." }
