$root = "D:\OneDrive"

# Ordner- und Dateinamen, die OneDrive ignorieren soll
$patterns = @(
    ".git",
    "-Help",
    "reports",
    "Tests",
    ".editorconfig",
    ".gitattributes",
    ".gitignore"
)

Write-Host "Scanning $root for folders/files to mark as system..."

Get-ChildItem -Path $root -Recurse -Force |
    Where-Object {
        $patterns -contains $_.Name
    } |
    ForEach-Object {
        Write-Host "Marking $($_.FullName) as system (OneDrive will ignore it)"
        attrib +s "$($_.FullName)"
    }

Write-Host "Done. These items will be invisible to OneDrive after reinstall."
