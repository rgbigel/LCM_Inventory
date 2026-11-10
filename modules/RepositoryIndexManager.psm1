<#
.SYNOPSIS
    Discovers workspace repositories and applies an optional user metadata overlay.
.DESCRIPTION
    Module: RepositoryIndexManager.psm1
    Purpose: Produces read-only repository facts for direct workspace children and overlays
             user-maintained metadata without modifying discovered repositories.
    Path: modules/RepositoryIndexManager.psm1
    Authors: Rolf, GitHub Copilot
    Version: 10.2.0
    Date: 2026-10-13
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepositoryMetadataOverlay {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$MetadataPath
  )

  if (-not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
    return @{}
  }

  $metadata = Get-Content -LiteralPath $MetadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $entries = if ($null -ne $metadata.PSObject.Properties['repositories']) { @($metadata.repositories) } else { @($metadata) }
  $overlay = @{}
  foreach ($entry in $entries) {
    if ($null -ne $entry -and $null -ne $entry.PSObject.Properties['name'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.name)) {
      $overlay[[string]$entry.name] = $entry
    }
  }

  return $overlay
}

function Get-RepositoryIndex {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot,

    [Parameter(Mandatory = $false)]
    [string]$MetadataPath = (Join-Path $WorkspaceRoot 'LCM_Inventory\data\repository-metadata.json')
  )

  if (-not (Test-Path -LiteralPath $WorkspaceRoot -PathType Container)) {
    throw "Workspace root not found: $WorkspaceRoot"
  }

  $overlay = Get-RepositoryMetadataOverlay -MetadataPath $MetadataPath
  $candidates = @()
  if (Test-Path -LiteralPath (Join-Path $WorkspaceRoot '.git')) {
    $candidates += Get-Item -LiteralPath $WorkspaceRoot
  }
  $candidates += @(Get-ChildItem -LiteralPath $WorkspaceRoot -Directory -Force | Where-Object {
      $candidate = $_
      Test-Path -LiteralPath (Join-Path $candidate.FullName '.git')
    })

  foreach ($candidate in @($candidates | Sort-Object -Property FullName -Unique)) {
    $repositoryName = $candidate.Name
    $repositoryPath = $candidate.FullName
    $branch = $null
    $headCommit = $null
    $isDirty = $null
    try {
      $branch = @(git -C $repositoryPath branch --show-current 2>$null)[0]
      $headCommit = @(git -C $repositoryPath rev-parse --short HEAD 2>$null)[0]
      $isDirty = @((git -C $repositoryPath status --porcelain 2>$null)).Count -gt 0
    }
    catch {
      $branch = $null
      $headCommit = $null
      $isDirty = $null
    }

    $metadata = if ($overlay.ContainsKey($repositoryName)) { $overlay[$repositoryName] } else { $null }
    [pscustomobject]@{
      Name = $repositoryName
      Path = $repositoryPath
      Branch = $branch
      HeadCommit = $headCommit
      IsDirty = $isDirty
      Metadata = $metadata
    }
  }
}

function Format-RepositoryIndex {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object[]]$Repository
  )

  $Repository | Select-Object Name, Branch, HeadCommit, IsDirty, Path
}

Export-ModuleMember -Function Get-RepositoryIndex, Format-RepositoryIndex
