# BUG-264: Prohibition of POSIX Backslash Escaping in PowerShell and AST Gate Enforcement

## Metadata
* **Bug-ID**: BUG-264
* **Scope**: LCM Governance & PowerShell Standards (`LCM_AI`)
* **Version**: 10.2.0
* **Affected-Repos**: `LCM_AI`, `LCM_Inventory`
* **Severity**: High
* **Status**: In-Progress
* **Root-Cause**: Absence of an explicit rule prohibiting POSIX/Bash-style backslash (`\`) escaping in PowerShell commands and scripts, leading models to substitute `\` for forbidden backticks, resulting in command resolution and parser failures.

---

## 1. Problem Description
PowerShell strictly treats backslash (`\`) as a literal character, primarily as a directory path separator or within regular expression patterns. PowerShell's language escape character is the backtick (`` ` ``).
Because `PowerShellRules.md` prohibits backticks via `no-backticks: forbidden`, AI agents trained on POSIX environments often instinctively attempt to escape variable identifiers (`\$var`), quotes (`\"`), or control characters using backslashes in double-quoted strings or inline `-Command` blocks.
In PowerShell script blocks, expressions like `{ \$_.status }` cause PowerShell to treat `\.status` as a command invocation, resulting in:
```text
\.status: The term '\.status' is not recognized as a name of a cmdlet, function, script file, or executable program.
```

Furthermore, the Antigravity transcript extractor (`Export-AntigravityExtractor.py`) contained a defective guard clause (`text.startswith("")`) that inadvertently filtered out all user messages from Antigravity session SQLite databases.

---

## 2. Requirements & Remediations
1. **Rule Codification (`PowerShellRules.md`)**:
   - Add invariant `no-posix-backslash-escapes: forbidden`.
   - Explicitly document that backslash `\` is never an escape character in PowerShell; developers and models must use single quotes (`'...'`), format strings, or concatenation.
2. **Policy Standard (`PowerShellStandardsPolicy.md`)**:
   - Codify `RULE-PS-022: Prohibition of POSIX/Bash Backslash Escaping in PowerShell`.
   - Define canonical formatting requirements and linter detection patterns for `\$` and escaped quote syntax in PowerShell code.
3. **Governance Cross-Reference Synchronization**:
   - Update `LCM_AI/docs/LCM-Rules-Cross-Reference.md` and `AGENTS.md` to index `RULE-PS-001` - `022`.
4. **Antigravity Extractor Remediation**:
   - Correct line 37 in `D:\OneDrive\cmd\Export-AntigravityExtractor.py` to prevent filtering user prompts.
5. **Rules Mirroring**:
   - Execute `Update-Gemini.ps1` to update plain-text exports and Gemini mirrors per `RULE-LCM-013`.
