# =====================================================================
#  Hard Reset of Local Git Repositories (except DiskAssignmentStatus)
#  Deletes corrupted .git folders and recreates clean repos
#  Working tree files remain untouched
# =====================================================================

$Root     = "D:\Git_Repositories"
$KeepRepo = "DiskAssignmentStatus"

# Count all folders in root (non-recursive)
$TotalFolders = (Get-ChildItem -Path $Root -Directory).Count

# Step 1: Find all .git folders under the root (including hidden)
$GitFolders = Get-ChildItem -Path $Root -Recurse -Force -Directory |
              Where-Object { $_.Name -eq ".git" }

# Step 2: Build list of repos to reset (exclude the one to keep)
$KeepPath      = Join-Path $Root $KeepRepo
$ReposToReset  = foreach ($git in $GitFolders) {
    $RepoPath = Split-Path $git.FullName -Parent
    if ($RepoPath -ne $KeepPath) {
        $RepoPath
    }
}

$ProcessedCount = $ReposToReset.Count

Write-Host "Found $ProcessedCount repos to reset out of $TotalFolders total folders..."

# Step 3: Delete all offending .git folders
foreach ($Repo in $ReposToReset) {
    $GitPath = Join-Path $Repo ".git"
    Write-Host "Deleting: $GitPath"
    Remove-Item -Path $GitPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Step 4: Recreate clean .git folders for each reset repo
foreach ($Repo in $ReposToReset) {
    Write-Host "Reinitializing repo: $Repo"
    git -C $Repo init
}

# Step 5: Return to root
Set-Location $Root

Write-Host "==============================================================="
Write-Host "All repos reset."
Write-Host "Total folders in root: $TotalFolders"
Write-Host "Repos processed:        $ProcessedCount"
Write-Host "Repos kept intact:      $KeepRepo"
Write-Host "==============================================================="

# =====================================================================
#  End of Script
# =====================================================================
