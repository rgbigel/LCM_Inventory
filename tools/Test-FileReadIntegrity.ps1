param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath,
    [string]$LogFile = "FileReadIntegrity.log"
)

$ErrorActionPreference = "Stop"

function Test-FileRead {
    param([string]$Path)

    try {
        $stream = [System.IO.File]::Open($Path, 'Open', 'Read', 'Read')
        $buffer = New-Object byte[] 4096
        $null = $stream.Read($buffer, 0, 4096)
        $stream.Seek(-4096, 'End') | Out-Null
        $null = $stream.Read($buffer, 0, 4096)
        $stream.Close()

        "[OK]  $Path" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    }
    catch {
        $msg = $_.Exception.Message
        "[ERR] $Path :: $msg" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    }
}

Get-ChildItem -Path $RootPath -Recurse -File -ErrorAction SilentlyContinue |
    ForEach-Object {
        Test-FileRead -Path $_.FullName
    }
