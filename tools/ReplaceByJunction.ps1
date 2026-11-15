<#
.SYNOPSIS
  Replaces a folder with an NTFS directory junction pointing to a chosen target folder.
.DESCRIPTION
  Converts or retargets a source directory into an NTFS junction.
  The supplied target path is exact by default. The script never automatically
  appends the source directory name unless -InFolder IsChild is explicitly used.

  1. For a normal source directory, the script compares it with an existing target:
  - identical contents allow the source to be deleted before creating the junction;
  - differing contents cause the source to be moved to a timestamped backup first.
  
  2. A missing target directory is created and populated from the source before the junction is created. 
  
  3. A missing source can be created directly as a junction when its target already exists. 
  
  Files are refused, and target layouts that would expose a
  duplicate source-name child through the junction are rejected without changes.

.PARAMETER SourcePath
  Directory to replace with a junction. This is the junction path after completion.
  If omitted, the script prompts for it.

.PARAMETER TargetPath
  Exact directory that the source junction will point to. If omitted, the script
  prompts for a path or opens an Explorer folder picker.

.PARAMETER InFolder
  Optional target-resolution mode:
    Direct  - Treat TargetPath as the exact target. This is the default and normal case.
    IsChild - Treat TargetPath as a parent and append the source directory name, but
              only when TargetPath does not already end in that name.

.PARAMETER Help
  Shows detailed script help.

.EXAMPLE
  .\ReplaceByJunction.ps1 K:\Git_Repositories\.agents K:\Git_Repositories\LCM_AI\.agents

  Normal case. The second path is the exact target. If both directories contain the
  same files, the source is removed and replaced with a junction. If they differ,
  the source is first moved to a timestamped .bak directory.

.EXAMPLE
  .\ReplaceByJunction.ps1 K:\Git_Repositories\.agents K:\Git_Repositories\LCM_AI -InFolder IsChild

  Explicit parent-folder mode. Resolves the target to
  K:\Git_Repositories\LCM_AI\.agents.

.EXAMPLE
  .\ReplaceByJunction.ps1 K:\Git_Repositories\.agents K:\Git_Repositories\LCM_AI\.agents -WhatIf

  Displays the planned action without changing directories or junctions.

.EXAMPLE
  .\ReplaceByJunction.ps1 K:\Git_Repositories\.agents K:\Git_Repositories\LCM_AI\.agents

  When the source path does not exist but the exact target already exists, prompts
  to create the missing source path as a junction to that target.

.NOTES
  Use -InFolder IsChild only when supplying a parent directory. In normal use,
  provide the full target path and omit -InFolder. Existing duplicate directories
  or junctions are never deleted as cleanup by this script.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Position = 0, Mandatory = $false, HelpMessage = 'Path to the folder to be replaced by a junction.')]
  [Alias('Source', 'Src', 'Path')]
  [string]$SourcePath = '',

  [Parameter(Position = 1, Mandatory = $false, HelpMessage = 'Target folder the junction will point to (skips GUI selector).')]
  [Alias('Target', 'Dest', 'To')]
  [string]$TargetPath = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Optional compatibility mode. "IsChild" appends the source folder name only when the supplied target path has a different name. "Direct" is the default exact-target behavior.')]
  [ValidateSet('IsChild', 'Direct', IgnoreCase = $true)]
  [string]$InFolder = '',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Get-Help -Name $PSCommandPath -Detailed
    return
}

$scriptDir = [System.IO.Path]::GetDirectoryName($PSCommandPath)
$ManifestPath = [System.IO.Path]::Combine($scriptDir, 'ReplaceByJunction_History.json')

function Test-IsStopToken {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    $clean = $Value.Trim().Trim('"', "'")
    if ($clean -match '^(nil|stop|exit|quit|q|cancel)$') { return $true }
    $leaf = [System.IO.Path]::GetFileName($clean)
    if ($leaf -match '^(nil|stop)$') { return $true }
    return $false
}

function Test-DirectoryContentEqual {
    param(
        [Parameter(Mandatory)][string]$ReferencePath,
        [Parameter(Mandatory)][string]$CandidatePath
    )

    $referenceRoot = $ReferencePath.TrimEnd('\')
    $candidateRoot = $CandidatePath.TrimEnd('\')
    $referenceEntries = @(
        Get-ChildItem -LiteralPath $referenceRoot -Force -Recurse | ForEach-Object {
            $relativePath = $_.FullName.Substring($referenceRoot.Length).TrimStart('\')
            if ($_.PSIsContainer) {
                "D|$relativePath"
            }
            else {
                $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                "F|$relativePath|$($_.Length)|$hash"
            }
        } | Sort-Object
    )
    $candidateEntries = @(
        Get-ChildItem -LiteralPath $candidateRoot -Force -Recurse | ForEach-Object {
            $relativePath = $_.FullName.Substring($candidateRoot.Length).TrimStart('\')
            if ($_.PSIsContainer) {
                "D|$relativePath"
            }
            else {
                $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                "F|$relativePath|$($_.Length)|$hash"
            }
        } | Sort-Object
    )

    return (@(Compare-Object -ReferenceObject $referenceEntries -DifferenceObject $candidateEntries -SyncWindow 0).Count -eq 0)
}

function Prompt-UserChoice {
    param(
        [string]$Message,
        [string[]]$ValidYes = @('y', 'yes')
    )
    $promptText = $Message + " (y/N or Enter/'stop' to cancel)"
    $inputVal = Read-Host -Prompt $promptText
    if ([string]::IsNullOrWhiteSpace($inputVal) -or (Test-IsStopToken $inputVal) -or $inputVal.Trim() -match '^(n|no)$') {
        return $false
    }
    $normalized = $inputVal.Trim().ToLowerInvariant()
    return ($normalized -in $ValidYes)
}

function Select-TargetFolderWithDialog {
    param([string]$InitialDirectory = '')

    $pickerBlock = {
        param($initDir)
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
        $dialog.Description = 'Select target folder (or parent folder for the junction target)'
        $dialog.UseDescriptionForTitle = $true
        $dialog.ShowNewFolderButton = $true

        if (-not [string]::IsNullOrWhiteSpace($initDir) -and (Test-Path -LiteralPath $initDir)) {
            $dialog.InitialDirectory = $initDir
        }
        $dialog.SelectedPath = ''

        $topForm = [System.Windows.Forms.Form]::new()
        $topForm.TopMost = $true
        $result = $dialog.ShowDialog($topForm)
        $topForm.Dispose()

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $chosen = $dialog.SelectedPath
            if ([string]::IsNullOrWhiteSpace($chosen)) {
                return $null
            }

            if (-not [string]::IsNullOrWhiteSpace($initDir)) {
                $cleanChosen = $chosen.TrimEnd('\').ToUpperInvariant()
                $cleanInit   = $initDir.TrimEnd('\').ToUpperInvariant()
                if ($cleanChosen -eq $cleanInit) {
                    return '__DEFAULT_SUPPLIED__'
                }
            }

            return $chosen
        }
        return $null
    }

    $rawResult = $null
    if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA) {
        $rawResult = & $pickerBlock $InitialDirectory
    }
    else {
        $resultHolder = [System.Collections.Generic.List[string]]::new()
        [System.Threading.ParameterizedThreadStart]$startDelegate = {
            param($arg)
            $res = & $pickerBlock $arg
            if ($null -ne $res) {
                $resultHolder.Add($res)
            }
        }
        $thread = [System.Threading.Thread]::new($startDelegate)
        $thread.SetApartmentState([System.Threading.ApartmentState]::STA)
        $thread.Start($InitialDirectory)
        $thread.Join()

        if ($resultHolder.Count -gt 0) {
            $rawResult = $resultHolder[0]
        }
    }

    return $rawResult
}

# -------------------------------------------------------------------------
# Step 1: Validate Source Path Input
# -------------------------------------------------------------------------
while ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $inputVal = Read-Host -Prompt "Enter folder path to replace with junction (or press Enter/'stop' to cancel)"
    if (Test-IsStopToken $inputVal) {
        Write-Host "`n[STOP] Operation cancelled: No source path provided.`n" -ForegroundColor Yellow
        return
    }
    $SourcePath = $inputVal.Trim('"', "'").Trim()
}

$SourcePath = [System.IO.Path]::GetFullPath($SourcePath).TrimEnd('\')
$sourceExists = Test-Path -LiteralPath $SourcePath

if ($sourceExists -and (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
    Write-Warning "Source path '$SourcePath' is a FILE. A directory junction cannot replace a file."
    return
}

$srcLeafName      = [System.IO.Path]::GetFileName($SourcePath)
$srcItem          = $null
$sourceIsJunction = $false
$sourceHasContent = $false
if ($sourceExists) {
    $srcItem          = Get-Item -LiteralPath $SourcePath -Force
    $isSrcReparse     = [bool]($srcItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
    $sourceIsJunction = ($isSrcReparse -and $srcItem.LinkType -eq 'Junction')
    $sourceEntries    = [System.IO.Directory]::EnumerateFileSystemEntries($SourcePath)
    $sourceHasContent = [bool]($sourceEntries.GetEnumerator().MoveNext())
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Source Analysis:" -ForegroundColor Cyan
Write-Host "   Path        : $SourcePath" -ForegroundColor Yellow
Write-Host "   Folder Name : $srcLeafName" -ForegroundColor Yellow
Write-Host "   Exists      : $sourceExists" -ForegroundColor Yellow
Write-Host "   Is Junction : $sourceIsJunction" -ForegroundColor Yellow
Write-Host "   Has Content : $sourceHasContent" -ForegroundColor Yellow
Write-Host "==========================================================`n" -ForegroundColor Cyan

# -------------------------------------------------------------------------
# Step 2: Target Selection & Refusal of File Selection
# -------------------------------------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($TargetPath) -and (Test-IsStopToken $TargetPath)) {
    Write-Host "`n[STOP] Target was specified as '$TargetPath'. Operation cancelled.`n" -ForegroundColor Yellow
    return
}

if ([string]::IsNullOrWhiteSpace($TargetPath)) {
    $suggestedInitial = [System.IO.Path]::GetDirectoryName($SourcePath)
    Write-Host "Target Selection:" -ForegroundColor Cyan
    Write-Host "  Press Enter to open Explorer folder picker" -ForegroundColor Yellow
    Write-Host "  Or enter target path directly (or 'nil' / 'stop' to cancel)" -ForegroundColor Yellow
    $promptVal = Read-Host -Prompt "Enter target path or press Enter for Explorer"

    if (Test-IsStopToken $promptVal) {
        Write-Host "`n[STOP] Target selection cancelled by user ('$promptVal').`n" -ForegroundColor Yellow
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($promptVal)) {
        $TargetPath = $promptVal.Trim('"', "'").Trim()
    }
    else {
        Write-Host "Opening Explorer folder selector..." -ForegroundColor Cyan
        $picked = Select-TargetFolderWithDialog -InitialDirectory $suggestedInitial

        if ($picked -eq '__DEFAULT_SUPPLIED__') {
            Write-Host "`n[STOP] The picker dialog automatically supplied its default initial folder ($suggestedInitial)." -ForegroundColor Yellow
            Write-Host "       A specific target folder was not chosen. Operation cancelled.`n" -ForegroundColor Yellow
            return
        }

        if ([string]::IsNullOrWhiteSpace($picked) -or (Test-IsStopToken $picked)) {
            Write-Host "`n[STOP] Target selection cancelled or entered as nil/stop. Operation aborted.`n" -ForegroundColor Yellow
            return
        }

        $TargetPath = $picked
    }
}

$TargetPath = [System.IO.Path]::GetFullPath($TargetPath).TrimEnd('\')

if (Test-Path -LiteralPath $TargetPath -PathType Leaf) {
    Write-Warning "Selected target '$TargetPath' is a FILE! NTFS directory junctions can only target directories. Operation aborted."
    return
}

# -------------------------------------------------------------------------
# Step 3: Target Resolution
# -------------------------------------------------------------------------
$targetLeafName = [System.IO.Path]::GetFileName($TargetPath)

if ($InFolder -eq 'IsChild' -and $targetLeafName.ToUpperInvariant() -ne $srcLeafName.ToUpperInvariant()) {
    $TargetPath = [System.IO.Path]::Combine($TargetPath, $srcLeafName)
    Write-Host "[-InFolder IsChild] Resolved target to child path: $TargetPath`n" -ForegroundColor Cyan
}
elseif ($InFolder -eq 'Direct') {
    Write-Host "[-InFolder Direct] Target path is exact: $TargetPath`n" -ForegroundColor Cyan
}

if (-not (Test-Path -LiteralPath $TargetPath) -and
    ([System.IO.Path]::GetFileName($TargetPath).ToUpperInvariant() -ne $srcLeafName.ToUpperInvariant())) {
    $accepted = Prompt-UserChoice -Message "Target '$TargetPath' does not exist and has a different name than Source '$srcLeafName'. Create this new target name?"
    if (-not $accepted) {
        Write-Host "`n[STOP] Nonexistent renamed target was not confirmed. No files modified.`n" -ForegroundColor Yellow
        return
    }
}

$nestedTargetPath = [System.IO.Path]::Combine($TargetPath, $srcLeafName)
if (Test-Path -LiteralPath $nestedTargetPath -PathType Container) {
    Write-Warning "Target '$TargetPath' already contains '$nestedTargetPath'. Creating a junction at '$SourcePath' would expose it as '$SourcePath\$srcLeafName'. Operation aborted without changes."
    return
}

if ($TargetPath.ToUpperInvariant() -eq $SourcePath.ToUpperInvariant()) {
    Write-Warning "Target cannot be identical to the source path. Operation aborted."
    return
}

# -------------------------------------------------------------------------
# Step 4: Inspect Resolved Target State
# -------------------------------------------------------------------------
$targetExists        = Test-Path -LiteralPath $TargetPath
$targetIsJunction    = $false
$targetHasContent    = $false
$targetCurrentTarget = ''

if ($targetExists) {
    $tgtItem = Get-Item -LiteralPath $TargetPath -Force
    $isTgtReparse = [bool]($tgtItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
    if ($isTgtReparse -and $tgtItem.LinkType -eq 'Junction') {
        $targetIsJunction = $true
        $rawTgt = [string]($tgtItem.Target -join '')
        $targetCurrentTarget = $rawTgt -replace '^\\\?\?\\', '' -replace '^\\\\\?\\', ''
    }
    else {
        $tgtEntries = [System.IO.Directory]::EnumerateFileSystemEntries($TargetPath)
        $targetHasContent = [bool]($tgtEntries.GetEnumerator().MoveNext())
    }
}

Write-Host "Resolved Target Analysis:" -ForegroundColor Cyan
Write-Host "   Target Path : $TargetPath" -ForegroundColor Yellow
Write-Host "   Exists      : $targetExists" -ForegroundColor Yellow
Write-Host "   Is Junction : $targetIsJunction" -ForegroundColor Yellow
if ($targetIsJunction) {
    Write-Host "   Points To   : $targetCurrentTarget" -ForegroundColor Yellow
}
else {
    Write-Host "   Has Content : $targetHasContent" -ForegroundColor Yellow
}
Write-Host ""

# -------------------------------------------------------------------------
# Step 5: Conflict Resolution & Planning
# -------------------------------------------------------------------------
$actionPlan = ''
$backupPath = ''

if (-not $sourceExists) {
    if (-not $targetExists) {
        Write-Warning "Source '$SourcePath' is missing and target '$TargetPath' does not exist. A junction cannot be created."
        return
    }

    Write-Host "[NOTICE] Source does not exist. It will be created as a junction to the existing target." -ForegroundColor Cyan
    $accepted = Prompt-UserChoice -Message "Create missing Source junction to Target?"
    if (-not $accepted) {
        Write-Host "`n[STOP] Operation cancelled by user. No files modified.`n" -ForegroundColor Yellow
        return
    }
    $actionPlan = 'CreateJunction'
}
elseif (-not $sourceIsJunction) {
    Write-Host "[NOTICE] Source is a normal directory, NOT an NTFS junction." -ForegroundColor Yellow

    if (-not $targetExists -or (-not $targetIsJunction -and -not $targetHasContent)) {
        Write-Host "`nTarget does not exist yet as an independent directory." -ForegroundColor Cyan
        Write-Host "Proposed Action: Copy original content from Source to Target, then convert Source into a junction to Target." -ForegroundColor Cyan
        
        $accepted = Prompt-UserChoice -Message "Proceed with copy to target and junction creation?"
        if (-not $accepted) {
            Write-Host "`n[STOP] Operation cancelled by user. No files modified.`n" -ForegroundColor Yellow
            return
        }
        $actionPlan = 'CopyAndJunction'
    }
    else {
        $targetDescription = if ($targetIsJunction) {
            "junction pointing to '$targetCurrentTarget'"
        }
        else {
            'regular directory containing files'
        }
        Write-Host "`nTarget is an existing $targetDescription." -ForegroundColor Yellow

        if (Test-DirectoryContentEqual -ReferencePath $SourcePath -CandidatePath $TargetPath) {
            Write-Host "Source and Target contents are identical. Source can be removed without a backup." -ForegroundColor Green
            $accepted = Prompt-UserChoice -Message "Delete Source and create the junction to Target?"
            if (-not $accepted) {
                Write-Host "`n[STOP] Operation cancelled by user. Source data untouched.`n" -ForegroundColor Yellow
                return
            }
            $actionPlan = 'DeleteAndJunction'
        }
        else {
            Write-Host "Source and Target contents differ. Source will be saved to a timestamped backup folder." -ForegroundColor Yellow
            Write-Host "You are responsible for restoring/merging any needed files from the backup." -ForegroundColor Yellow
            $accepted = Prompt-UserChoice -Message "Backup Source content and link Source to Target?"
            if (-not $accepted) {
                Write-Host "`n[STOP] Operation cancelled by user. Source data untouched.`n" -ForegroundColor Yellow
                return
            }
            $actionPlan = 'BackupAndJunction'
        }
    }
}
else {
    $rawSrcTgt = [string]($srcItem.Target -join '')
    $currentSrcTarget = $rawSrcTgt -replace '^\\\?\?\\', '' -replace '^\\\\\?\\', ''

    $cleanSrcTarget = $currentSrcTarget.TrimEnd('\').ToUpperInvariant()
    $cleanTarget    = $TargetPath.TrimEnd('\').ToUpperInvariant()
    if ($cleanSrcTarget -eq $cleanTarget) {
        Write-Host "[OK] Source is already a junction pointing to '$TargetPath'. Nothing to do.`n" -ForegroundColor Green
        return
    }

    Write-Host "Source is already a junction pointing to: $currentSrcTarget" -ForegroundColor Yellow
    Write-Host "New Target will be                      : $TargetPath" -ForegroundColor Yellow

    $accepted = Prompt-UserChoice -Message "Retarget existing Source junction to new Target?"
    if (-not $accepted) {
        Write-Host "`n[STOP] Operation cancelled by user. Existing junction preserved.`n" -ForegroundColor Yellow
        return
    }
    $actionPlan = 'RetargetJunction'
}

# -------------------------------------------------------------------------
# Step 6: Execution
# -------------------------------------------------------------------------
if (-not $PSCmdlet.ShouldProcess($SourcePath, "Execute action plan: $actionPlan pointing to '$TargetPath'")) {
    Write-Host "`n[WHATIF] Simulation only. No changes applied.`n" -ForegroundColor DarkYellow
    return
}

try {
    switch ($actionPlan) {
        'CreateJunction' {
            Write-Host "Creating junction at missing Source -> Target" -ForegroundColor Cyan
            $null = New-Item -ItemType Junction -Path $SourcePath -Target $TargetPath -Force -ErrorAction Stop
        }

        'CopyAndJunction' {
            Write-Host "1. Creating target directory: $TargetPath" -ForegroundColor Cyan
            if (-not (Test-Path -LiteralPath $TargetPath)) {
                $null = New-Item -ItemType Directory -Path $TargetPath -Force -ErrorAction Stop
            }

            if ($sourceHasContent) {
                Write-Host "2. Copying files from Source to Target..." -ForegroundColor Cyan
                $entries = [System.IO.Directory]::EnumerateFileSystemEntries($SourcePath)
                foreach ($entry in $entries) {
                    Copy-Item -LiteralPath $entry -Destination $TargetPath -Recurse -Force -ErrorAction Stop
                }
            }

            $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
            $tempSource = '{0}.tmp_{1}' -f $SourcePath, $timestamp
            Move-Item -LiteralPath $SourcePath -Destination $tempSource -Force -ErrorAction Stop

            Write-Host "3. Creating junction at Source -> Target" -ForegroundColor Cyan
            $null = New-Item -ItemType Junction -Path $SourcePath -Target $TargetPath -Force -ErrorAction Stop

            $verify = Get-Item -LiteralPath $SourcePath -Force -ErrorAction Stop
            if ($verify.LinkType -eq 'Junction') {
                Remove-Item -LiteralPath $tempSource -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "4. Source successfully converted to junction.`n" -ForegroundColor Green
            }
            else {
                throw "Filesystem verification failed: Source did not become a junction."
            }
        }

        'DeleteAndJunction' {
            Write-Host "Removing identical Source directory: $SourcePath" -ForegroundColor Cyan
            Remove-Item -LiteralPath $SourcePath -Recurse -Force -ErrorAction Stop
            Write-Host "Creating junction at Source -> Target" -ForegroundColor Cyan
            $null = New-Item -ItemType Junction -Path $SourcePath -Target $TargetPath -Force -ErrorAction Stop
        }

        'BackupAndJunction' {
            if ($sourceHasContent) {
                $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
                $backupPath = '{0}.bak_{1}' -f $SourcePath, $timestamp
                Write-Host "Moving Source to backup folder: $backupPath" -ForegroundColor Cyan
                Move-Item -LiteralPath $SourcePath -Destination $backupPath -Force -ErrorAction Stop
            }
            else {
                [System.IO.Directory]::Delete($SourcePath, $false)
            }

            Write-Host "Creating junction at Source -> Target" -ForegroundColor Cyan
            if (-not (Test-Path -LiteralPath $TargetPath)) {
                $null = New-Item -ItemType Directory -Path $TargetPath -Force -ErrorAction Stop
            }
            $null = New-Item -ItemType Junction -Path $SourcePath -Target $TargetPath -Force -ErrorAction Stop
        }

        'RetargetJunction' {
            [System.IO.Directory]::Delete($SourcePath)
            if (-not (Test-Path -LiteralPath $TargetPath)) {
                $null = New-Item -ItemType Directory -Path $TargetPath -Force -ErrorAction Stop
            }
            $null = New-Item -ItemType Junction -Path $SourcePath -Target $TargetPath -Force -ErrorAction Stop
        }
    }

    $finalItem = Get-Item -LiteralPath $SourcePath -Force -ErrorAction Stop
    $finalRaw = [string]($finalItem.Target -join '')
    $finalNorm = $finalRaw -replace '^\\\?\?\\', '' -replace '^\\\\\?\\', ''

    $cleanFinalNorm = $finalNorm.TrimEnd('\').ToUpperInvariant()
    $cleanTarget    = $TargetPath.TrimEnd('\').ToUpperInvariant()

    if ($finalItem.LinkType -eq 'Junction' -and $cleanFinalNorm -eq $cleanTarget) {
        Write-Host "==========================================================" -ForegroundColor Green
        Write-Host " [CONFIRMED SUCCESS] Junction Established" -ForegroundColor Green
        Write-Host "   Junction Path : $SourcePath" -ForegroundColor Green
        Write-Host "   Points To     : $TargetPath" -ForegroundColor Green
        if (-not [string]::IsNullOrWhiteSpace($backupPath)) {
            Write-Host "   Backup Folder : $backupPath" -ForegroundColor Yellow
            Write-Host "   Notice        : Remember to manually inspect/restore any needed files." -ForegroundColor Yellow
        }
        Write-Host "==========================================================`n" -ForegroundColor Green

        $logEntry = [PSCustomObject]@{
            Timestamp     = (Get-Date).ToString('o')
            Action        = $actionPlan
            SourcePath    = $SourcePath
            TargetPath    = $TargetPath
            InFolderMode  = $InFolder
            BackupCreated = $backupPath
            Status        = 'Success'
        }

        $existing = @()
        if (Test-Path -LiteralPath $ManifestPath) {
            try { $existing = @(Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json) } catch {}
        }
        $combined = @($existing) + @($logEntry)
        $combined | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ManifestPath -Encoding ascii
    }
    else {
        throw "Final verification failed: Target does not match expected path."
    }
}
catch {
    $errMsg = $_.Exception.Message
    Write-Host "`n[FAILED] Execution failed: $errMsg" -ForegroundColor Red
    if (-not [string]::IsNullOrWhiteSpace($backupPath) -and (Test-Path -LiteralPath $backupPath) -and -not (Test-Path -LiteralPath $SourcePath)) {
        Write-Host "[ROLLBACK] Restoring original Source folder from backup..." -ForegroundColor Yellow
        Move-Item -LiteralPath $backupPath -Destination $SourcePath -Force -ErrorAction SilentlyContinue
    }
    Write-Host ""
}