[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$GitHubOwner,

    [string]$TargetRoot = "D:\OneDrive\Git_Repositories",
    [string]$CmdRoot = "D:\OneDrive\cmd",

    [switch]$UpdateExisting,

    # Optional: also run BackgroundModifier setup/verify after clone/update.
    [switch]$RunBackgroundModifierHousekeeping,

    [string]$BackgroundCmdRoot = "D:\OneDrive\cmd",
    [string]$BackgroundRuntimeRoot = "C:\BootOpsHub"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$logDir = Join-Path $CmdRoot "logs"
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logPath = Join-Path $logDir ("Git_Restore_HubToLocal_All_{0}.log" -f $timestamp)

$counts = [ordered]@{
    S_Total = 0
    E_Total = 0

    S_Cloned = 0
    E_Clone = 0

    S_Updated = 0
    E_Update = 0

    S_Housekeeping = 0
    E_Housekeeping = 0

    S_Skipped = 0
    E_Config = 0
}

function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )

    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level.ToUpperInvariant(), $Message
    Add-Content -LiteralPath $logPath -Value $line
    Write-Host $line
}

function Add-Success {
    param([string]$Key)
    $script:counts[$Key] = [int]$script:counts[$Key] + 1
    $script:counts["S_Total"] = [int]$script:counts["S_Total"] + 1
}

function Add-ErrorCount {
    param([string]$Key)
    $script:counts[$Key] = [int]$script:counts[$Key] + 1
    $script:counts["E_Total"] = [int]$script:counts["E_Total"] + 1
}

function Invoke-Git {
    param(
        [string]$WorkingDir,
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $cmdText = "git {0}" -f ($Arguments -join " ")
    if ([string]::IsNullOrWhiteSpace($WorkingDir)) {
        Write-Log "INFO" ("Run: {0}" -f $cmdText)
        $output = & git @Arguments 2>&1
    }
    else {
        Write-Log "INFO" ('Run: git -C "{0}" {1}' -f $WorkingDir, ($Arguments -join " "))
        $output = & git -C $WorkingDir @Arguments 2>&1
    }

    $exitCode = $LASTEXITCODE
    if ($output) {
        foreach ($line in $output) {
            Write-Log "TRACE" ([string]$line)
        }
    }

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        $detail = ""
        if ($output) {
            $detail = (($output | ForEach-Object { [string]$_ }) -join " | ")
        }
        throw "Git command failed (exit $exitCode): $cmdText :: $detail"
    }

    return $output
}

function Test-IsGitRepo {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $null = & git -C $Path rev-parse --is-inside-work-tree 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Run-BackgroundModifierHousekeeping {
    param(
        [string]$RepoPath,
        [string]$CmdRootPath,
        [string]$RuntimeRootPath
    )

    $setupPath = Join-Path $RepoPath "Install\Setup.ps1"
    $verifyPath = Join-Path $RepoPath "Install\Verifyer.ps1"

    if (-not (Test-Path -LiteralPath $setupPath)) {
        throw "BackgroundModifier setup script not found: $setupPath"
    }
    if (-not (Test-Path -LiteralPath $verifyPath)) {
        throw "BackgroundModifier verifier script not found: $verifyPath"
    }

    if ($PSCmdlet.ShouldProcess($setupPath, "Run Setup.ps1 with CmdRoot/RuntimeRoot")) {
        Write-Log "INFO" "Running BackgroundModifier setup housekeeping"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $setupPath -CmdRoot $CmdRootPath -RuntimeRoot $RuntimeRootPath
        if ($LASTEXITCODE -ne 0) {
            throw "BackgroundModifier setup returned exit code $LASTEXITCODE"
        }
    }

    if ($PSCmdlet.ShouldProcess($verifyPath, "Run Verifyer.ps1 with CmdRoot/RuntimeRoot")) {
        Write-Log "INFO" "Running BackgroundModifier verify housekeeping"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $verifyPath -CmdRoot $CmdRootPath -RuntimeRoot $RuntimeRootPath
        if ($LASTEXITCODE -ne 0) {
            throw "BackgroundModifier verifier returned exit code $LASTEXITCODE"
        }
    }
}

# Known repositories from prior workspace inventory.
$repoList = @(
    [pscustomobject]@{ Name = "BackgroundModifier"; Slug = "BackgroundModifier-Windows-11" },
    [pscustomobject]@{ Name = "BootEntryManager"; Slug = "BootEntryManager" },
    [pscustomobject]@{ Name = "NextBootTray"; Slug = "NextBootTray" },
    [pscustomobject]@{ Name = "OutlookVBAConversion"; Slug = "OutlookVBAConversion" },
    [pscustomobject]@{ Name = "ReEnableRadeonRx580"; Slug = "ReEnableRadeonRx580" },
    [pscustomobject]@{ Name = "VolumeInventory"; Slug = "VolumeInventory" }
)

Write-Log "INFO" "=== Git restore start ==="
Write-Log "INFO" ("TargetRoot: {0}" -f $TargetRoot)
Write-Log "INFO" ("GitHubOwner: {0}" -f $GitHubOwner)
Write-Log "INFO" ("UpdateExisting: {0}" -f [bool]$UpdateExisting)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Add-ErrorCount -Key "E_Config"
    Write-Log "ERROR" "git.exe not found in PATH."
    Write-Log "ERROR" "Aborting."
    exit 1
}

if (-not (Test-Path -LiteralPath $TargetRoot)) {
    if ($PSCmdlet.ShouldProcess($TargetRoot, "Create target root")) {
        New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null
        Write-Log "INFO" ("Created target root: {0}" -f $TargetRoot)
    }
}

foreach ($repo in $repoList) {
    $localPath = Join-Path $TargetRoot $repo.Name
    $repoUrl = "https://github.com/{0}/{1}.git" -f $GitHubOwner, $repo.Slug
    $operation = "none"

    Write-Log "INFO" ("--- Repository: {0} ---" -f $repo.Name)
    Write-Log "INFO" ("Remote: {0}" -f $repoUrl)

    try {
        $gitDir = Join-Path $localPath ".git"
        $isGitRepo = Test-IsGitRepo -Path $localPath

        if ($isGitRepo -or (Test-Path -LiteralPath $gitDir)) {
            if ($UpdateExisting) {
                if ($PSCmdlet.ShouldProcess($localPath, "Fetch updates")) {
                    $operation = "update"
                    Invoke-Git -WorkingDir $localPath -Arguments @("fetch", "--all", "--prune") | Out-Null
                    Add-Success -Key "S_Updated"
                    Write-Log "OK" "Updated existing repository (fetch --all --prune)."
                }
            }
            else {
                Add-Success -Key "S_Skipped"
                Write-Log "WARN" "Repository already exists. Skipped (use -UpdateExisting to fetch)."
            }
        }
        elseif (Test-Path -LiteralPath $localPath) {
            Add-ErrorCount -Key "E_Config"
            Write-Log "ERROR" "Target folder exists but is not a git repo (.git missing). Skipping."
            continue
        }
        else {
            if ($PSCmdlet.ShouldProcess($repoUrl, ("Clone to {0}" -f $localPath))) {
                $operation = "clone"
                Invoke-Git -WorkingDir $null -Arguments @("clone", $repoUrl, $localPath) | Out-Null
                Add-Success -Key "S_Cloned"
                Write-Log "OK" "Cloned successfully."
            }
        }

        if (Test-IsGitRepo -Path $localPath) {
            try {
                $origin = (Invoke-Git -WorkingDir $localPath -Arguments @("remote", "get-url", "origin") -AllowFailure).Trim()
                $branch = (Invoke-Git -WorkingDir $localPath -Arguments @("rev-parse", "--abbrev-ref", "HEAD") -AllowFailure).Trim()
                $commit = (Invoke-Git -WorkingDir $localPath -Arguments @("rev-parse", "--short", "HEAD") -AllowFailure).Trim()

                Write-Log "INFO" ("Housekeeping: origin={0} | branch={1} | commit={2}" -f $origin, $branch, $commit)
                Add-Success -Key "S_Housekeeping"
            }
            catch {
                Add-ErrorCount -Key "E_Housekeeping"
                Write-Log "ERROR" ("Housekeeping failed: {0}" -f $_.Exception.Message)
            }
        }
    }
    catch {
        if ($operation -eq "update") {
            Add-ErrorCount -Key "E_Update"
        }
        elseif ($operation -eq "clone") {
            Add-ErrorCount -Key "E_Clone"
        }
        else {
            Add-ErrorCount -Key "E_Config"
        }
        Write-Log "ERROR" ("Repository failed: {0}" -f $_.Exception.Message)
    }
}

if ($RunBackgroundModifierHousekeeping) {
    $bmPath = Join-Path $TargetRoot "BackgroundModifier"
    if (Test-Path -LiteralPath (Join-Path $bmPath ".git")) {
        try {
            Run-BackgroundModifierHousekeeping -RepoPath $bmPath -CmdRootPath $BackgroundCmdRoot -RuntimeRootPath $BackgroundRuntimeRoot
            Add-Success -Key "S_Housekeeping"
            Write-Log "OK" "BackgroundModifier setup/verify housekeeping completed."
        }
        catch {
            Add-ErrorCount -Key "E_Housekeeping"
            Write-Log "ERROR" ("BackgroundModifier housekeeping failed: {0}" -f $_.Exception.Message)
        }
    }
    else {
        Add-ErrorCount -Key "E_Housekeeping"
        Write-Log "ERROR" "BackgroundModifier repository not available for housekeeping."
    }
}

Write-Log "INFO" "=== Summary ==="
foreach ($key in $counts.Keys) {
    Write-Log "INFO" ("{0}: {1}" -f $key, $counts[$key])
}
Write-Log "INFO" ("Log file: {0}" -f $logPath)

if ([int]$counts.E_Total -gt 0) {
    exit 1
}

exit 0
