# Agent Intermediate Code Failure Patterns & Anti-Pattern Catalog

```yaml
Title: Agent Intermediate Code Failure Patterns & Anti-Pattern Catalog
Module: Agent-Intermediate-Code-Failure-Patterns
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-26
Status: Living Learning Document
Target: All Agent Code Generation & Interactive Execution
```

---

## 1. Executive Summary

During automated agent workflows, code generation, script execution, and ad-hoc orchestration in the LCM workspace, specific intermediate code patterns fail repeatedly. When these failures occur, the agent spends multiple corrective turns diagnosing the syntax or runtime error and refactoring the command.

This catalog documents the **top 7 recurring intermediate failure patterns**, their root cause mechanics, the fragile anti-pattern, and the authoritative **canonical resilient idiom**.

---

## 2. Recurring Failure Pattern Catalog

### Pattern 1: PowerShell Command-String Quoting & Argument Splitting
- **Symptom**: `A positional parameter cannot be found that accepts argument '...'` or unexpected token syntax errors.
- **Root Cause**: Passing `pwsh -NoProfile -Command "..."` with double quotes inside causes PowerShell's command-line parser to unescape outer quotes and split arguments prematurely, especially when backslashes (`\`) or nested strings are present.
- **Fragile Anti-Pattern**:
  ```powershell
  pwsh -NoProfile -Command "Write-Host \"Checking: $dir\file\""
  ```
- **Canonical Resilient Pattern**:
  Always use single-quoted here-strings (`@' ... '@`). Single-quoted here-strings preserve all inner quotes, backslashes, and special characters literally:
  ```powershell
  pwsh -NoProfile -Command @'
    $dir = 'D:\Git_Repositories'
    Write-Host "Checking: $dir\file"
  '@
  ```

---

### Pattern 2: .NET Generic List Constructor Ambiguity in PowerShell
- **Symptom**: `MethodException: Cannot find an overload for "new" and the argument count: "1".`
- **Root Cause**: PowerShell wraps arrays in `object[]`. Calling `[System.Collections.Generic.List[PSCustomObject]]::new($array)` fails because PowerShell cannot bind `object[]` to `IEnumerable<PSCustomObject>` via `::new(arg)`.
- **Fragile Anti-Pattern**:
  ```powershell
  $list = [System.Collections.Generic.List[PSObject]]::new($json.proposals)
  $list.Add($newItem)
  ```
- **Canonical Resilient Pattern**:
  Use native PowerShell array concatenation or explicit object array casting:
  ```powershell
  # Idiom A: Native array concatenation (idiomatic PowerShell)
  $json.proposals = @($json.proposals) + $newItem

  # Idiom B: Explicit object array instantiation
  $list = [System.Collections.Generic.List[object]]::new([object[]]$json.proposals)
  $list.Add($newItem)
  ```

---

### Pattern 3: PowerShell 7 Syntax Invoked in PowerShell 5.1 Hosts
- **Symptom**: `The token '||' is not a valid statement separator in this version.`
- **Root Cause**: Using PowerShell 7 operators (`||`, `&&`, `??`, ternary `? :`) in scripts or tools that may be invoked by Windows PowerShell 5.1 (e.g., legacy batch launchers, background daemons, or standard Windows shortcuts).
- **Fragile Anti-Pattern**:
  ```powershell
  $browser = (Get-Item $regPath).GetValue('') || 'zen.exe'
  $title = $hint ? $hint : 'Default'
  ```
- **Canonical Resilient Pattern**:
  Use explicit, universally compatible `if/else` constructs:
  ```powershell
  $browser = if ($val) { $val } else { 'zen.exe' }
  $title = if ($hint) { $hint } else { 'Default' }
  ```

---

### Pattern 4: `Set-StrictMode -Version Latest` Variable & Property Traps
- **Symptom**: `The variable '$var' cannot be retrieved because it has not been set.` or `The property 'prop' cannot be found on this object.`
- **Root Cause**: Under `Set-StrictMode -Version Latest`, PowerShell forbids evaluating `$null` or unassigned variables, or accessing non-existent properties on a `PSCustomObject`.
- **Fragile Anti-Pattern**:
  ```powershell
  if ($argsToSend) { ... }  # Throws if $argsToSend was never declared!
  if ($obj.nonExistent) { ... } # Throws if property is absent!
  ```
- **Canonical Resilient Pattern**:
  Initialize all variables explicitly before branching, and inspect properties safely:
  ```powershell
  $argsToSend = $null
  if ($null -ne $argsToSend) { ... }

  # Safe property inspection
  if ($obj.PSObject.Properties['nonExistent']) { ... }
  ```

---

### Pattern 5: Windows File Sharing & Concurrency Collisions (`FileShare.None`)
- **Symptom**: `The process cannot access the file '...' because it is being used by another process.`
- **Root Cause**: `Get-Content`, `Set-Content`, and `Get-FileHash` open file handles with exclusive or restrictive sharing. If Google Drive sync, VS Code, or an active process has an open read handle, an `IOException` is thrown.
- **Fragile Anti-Pattern**:
  ```powershell
  $hash = (Get-FileHash -Path $file).Hash
  $content | Set-Content -Path $syncedFile
  ```
- **Canonical Resilient Pattern**:
  Use `[System.IO.FileShare]::ReadWrite` streams for reading, and atomic swap with retry for writing:
  ```powershell
  # Lock-free read:
  $fs = [System.IO.FileStream]::new($file, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
  try {
      $hashBytes = $sha256.ComputeHash($fs)
  } finally {
      $fs.Dispose()
  }

  # Atomic write with exponential backoff retry:
  $tmp = "$dest.tmp"
  for ($i = 1; $i -le 3; $i++) {
      try {
          $content | Set-Content -Path $tmp -Encoding UTF8
          [System.IO.File]::Move($tmp, $dest, $true)
          break
      } catch {
          Start-Sleep -Milliseconds (100 * $i)
      }
  }
  ```

---

### Pattern 6: Directory Junction & Reparse Point Deletion Hazards
- **Symptom**: Deleting an NTFS junction inadvertently purges the target directory's physical contents, or fails with access denied.
- **Root Cause**: In several PowerShell versions, `Remove-Item -Recurse` on a directory reparse point traverses into the target folder instead of merely removing the directory pointer.
- **Fragile Anti-Pattern**:
  ```powershell
  Remove-Item -Path $junctionPath -Recurse -Force
  ```
- **Canonical Resilient Pattern**:
  Test for `ReparsePoint` flag and call `.Delete()` directly on the file system item, or use `cmd /c rmdir`:
  ```powershell
  $item = Get-Item -LiteralPath $path -Force
  if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
      $item.Delete()
  } else {
      Remove-Item -LiteralPath $path -Recurse -Force
  }
  ```

---

### Pattern 7: Bare Inline `(if ...)` Expressions in Command Arguments
- **Symptom**: Parser error: `Unexpected token 'if' in expression or statement.`
- **Root Cause**: PowerShell syntax forbids bare `(if ...)` control statements directly embedded within parameter argument lists.
- **Fragile Anti-Pattern**:
  ```powershell
  My-Function -Param (if ($cond) { "A" } else { "B" })
  ```
- **Canonical Resilient Pattern**:
  Assign the result to an intermediate variable before invoking the cmdlet:
  ```powershell
  $paramVal = if ($cond) { "A" } else { "B" }
  My-Function -Param $paramVal
  ```
