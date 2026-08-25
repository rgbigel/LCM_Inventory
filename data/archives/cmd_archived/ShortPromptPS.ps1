# File: ShortPromptPS.ps1
function prompt {
    $leaf = Split-Path -Leaf (Get-Location)
    return "$leaf$ "
}
