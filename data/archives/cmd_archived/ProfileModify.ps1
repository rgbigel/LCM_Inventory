[CmdletBinding()]
param(
    [Alias('p', 'e')]
    [string]$EditMode = 'Parameters',

    [Alias('v', 'c')]
    [string]$ProfValue = 'Yellow',

    [Alias('h')]
    [switch]$HelpMode,

    [Alias('l')]
    [switch]$ListMode,

    [Alias('a')]
    [switch]$ListAllMode,

    [Alias('t')]
    [switch]$TraceMode,

    [Alias('f')]
    [switch]$Force
)

Set-StrictMode -Version Latest

# ============================================
# ProfileModify 1.0 - PSReadLine Profile Setting Tool
# ============================================
# Purpose:
#   Applies and persists PSReadLine settings using generic profile values.
#
# Parameters:
#   -p / -EditMode    : Setting target name (default: Parameters)
#                      Legacy alias: -e
#   -v / -ProfValue   : Value to apply for selected setting (default: Yellow)
#                      Alias -c kept for backward compatibility.
#   -h / -HelpMode    : Show allowed values for selected edit mode and exit
#   -l / -ListMode    : Show current PSReadLine option state and exit
#                      Includes a ParameterName/ParameterValue overview table.
#   -a / -ListAllMode : Show profile target paths and exit
#                       With -l -a together: show all profile setting matches
#   -t / -TraceMode   : Optional trace output
#   -f / -Force       : Required to apply high-impact settings
#
# Behavior:
#   1) Loads PSReadLine and resolves the selected edit mode.
#   2) Applies the setting immediately in the current session.
#   3) Persists the setting to current-user profile files.
#
# Examples:
#   .\ProfileModify.ps1
#   .\ProfileModify.ps1 -p Parameters -v Green
#   .\ProfileModify.ps1 -p EditMode -v Windows
#   .\ProfileModify.ps1 -h -p EditMode
#   .\ProfileModify.ps1 -l
#   .\ProfileModify.ps1 -a
#   .\ProfileModify.ps1 -l -a
#   .\ProfileModify.ps1 -p EditMode -v Vi -f
#   .\ProfileModify.ps1 -t

$tokenModeSpec = @{
    Parameters = @{ ColorsKey = 'Parameter'; TokenKind = 'Parameter' }
}

$safeSettingList = @(
    'Parameters',
    'BellStyle',
    'DingTone',
    'DingDuration',
    'HistoryNoDuplicates',
    'HistorySearchCaseSensitive',
    'MaximumHistoryCount',
    'MaximumKillRingCount',
    'ShowToolTips',
    'WordDelimiters'
)

$highImpactSettingList = @(
    'AddToHistoryHandler',
    'CommandValidationHandler',
    'EditMode',
    'HistorySavePath',
    'PromptText',
    'PredictionSource',
    'ViModeIndicator'
)

function Write-TraceMessage {
    param([string]$Message)

    if ($TraceMode) {
        Write-Host ('[TRACE] {0}' -f $Message)
    }
}

function Ensure-PsReadLineLoaded {
    Write-TraceMessage -Message 'Loading PSReadLine module...'
    Import-Module PSReadLine -Force -ErrorAction Stop

    $module = Get-Module PSReadLine
    if ($null -eq $module) {
        throw 'PSReadLine could not be loaded.'
    }

    Write-TraceMessage -Message ('PSReadLine loaded: {0} {1}' -f $module.Name, $module.Version)
}

function Get-ProfileTargets {
    return @(
        $PROFILE.CurrentUserAllHosts,
        $PROFILE.CurrentUserCurrentHost
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
}

function Get-ColorApiMode {
    $setPsReadLineOption = Get-Command Set-PSReadLineOption -ErrorAction Stop

    if ($setPsReadLineOption.Parameters.ContainsKey('Colors')) {
        return 'Colors'
    }

    if ($setPsReadLineOption.Parameters.ContainsKey('TokenKind') -and $setPsReadLineOption.Parameters.ContainsKey('TokenForegroundColor')) {
        return 'LegacyToken'
    }

    throw 'This PSReadLine version does not expose a supported color API.'
}

function Get-EditSpec {
    $setPsReadLineOption = Get-Command Set-PSReadLineOption -ErrorAction Stop

    if ($tokenModeSpec.ContainsKey($EditMode)) {
        $spec = $tokenModeSpec[$EditMode]
        return [pscustomobject]@{
            Kind = 'TokenColor'
            Name = $EditMode
            ColorsKey = $spec.ColorsKey
            TokenKind = $spec.TokenKind
            ValueType = [System.ConsoleColor]
        }
    }

    if (-not $setPsReadLineOption.Parameters.ContainsKey($EditMode)) {
        $available = ($setPsReadLineOption.Parameters.Keys | Sort-Object) -join ', '
        throw ('Unsupported edit mode "{0}". Available Set-PSReadLineOption parameters: {1}' -f $EditMode, $available)
    }

    $parameterMeta = $setPsReadLineOption.Parameters[$EditMode]
    return [pscustomobject]@{
        Kind = 'Option'
        Name = $EditMode
        ParameterMeta = $parameterMeta
        ValueType = $parameterMeta.ParameterType
    }
}

function Convert-ProfValue {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$EditSpec,

        [Parameter(Mandatory = $true)]
        [string]$InputValue
    )

    if ($EditSpec.Kind -eq 'TokenColor') {
        try {
            return ([System.Enum]::Parse([System.ConsoleColor], $InputValue, $true)).ToString()
        }
        catch {
            $allowed = [System.Enum]::GetNames([System.ConsoleColor]) -join ', '
            throw ('Invalid ProfValue "{0}" for edit mode "{1}". Allowed values: {2}' -f $InputValue, $EditSpec.Name, $allowed)
        }
    }

    $targetType = $EditSpec.ValueType

    if ($targetType -eq [System.Management.Automation.SwitchParameter]) {
        if ($InputValue -match '^(1|true|yes|on)$') { return $true }
        if ($InputValue -match '^(0|false|no|off)$') { return $false }
        throw ('Invalid ProfValue "{0}" for switch setting "{1}". Use true/false.' -f $InputValue, $EditSpec.Name)
    }

    if ($targetType -eq [bool]) {
        if ($InputValue -match '^(1|true|yes|on)$') { return $true }
        if ($InputValue -match '^(0|false|no|off)$') { return $false }
        throw ('Invalid ProfValue "{0}" for boolean setting "{1}". Use true/false.' -f $InputValue, $EditSpec.Name)
    }

    if ($targetType -eq [int]) {
        try {
            return [int]$InputValue
        }
        catch {
            throw ('Invalid ProfValue "{0}" for integer setting "{1}".' -f $InputValue, $EditSpec.Name)
        }
    }

    if ($targetType.IsEnum) {
        try {
            return ([System.Enum]::Parse($targetType, $InputValue, $true)).ToString()
        }
        catch {
            $allowed = [System.Enum]::GetNames($targetType) -join ', '
            throw ('Invalid ProfValue "{0}" for setting "{1}". Allowed values: {2}' -f $InputValue, $EditSpec.Name, $allowed)
        }
    }

    return $InputValue
}

function Format-ValueLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    if ($Value -is [bool]) {
        if ($Value) { return '$true' }
        return '$false'
    }

    if ($Value -is [int]) {
        return [string]$Value
    }

    $asString = [string]$Value
    $escaped = $asString.Replace("'", "''")
    return "'$escaped'"
}

function Show-HelpMode {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$EditSpec
    )

    Write-Host 'ProfileModify help mode'
    Write-Host ('EditMode (-p): {0}' -f $EditMode)
    Write-Host ('Default ProfValue (-v): {0}' -f $ProfValue)

    if ($safeSettingList -contains $EditMode) {
        Write-Host 'Impact: Low-risk (safe list)'
    }
    elseif ($highImpactSettingList -contains $EditMode) {
        Write-Host 'Impact: High-impact (requires -f when applying)'
    }
    else {
        Write-Host 'Impact: Unknown (treated as high-impact unless forced)'
    }

    if ($EditMode -eq 'PromptText') {
        Write-Host 'Special handling: you will be asked whether to change the PromptText setting or edit the prompt function.'
    }

    if ($EditSpec.Kind -eq 'TokenColor') {
        $allowed = [System.Enum]::GetNames([System.ConsoleColor])
        Write-Host ('Allowed values for -v when -p {0}:' -f $EditMode)
        Write-Host ($allowed -join ', ')
    }
    else {
        $paramMeta = $EditSpec.ParameterMeta
        $valueType = $EditSpec.ValueType

        Write-Host ('Target parameter type: {0}' -f $valueType.FullName)

        $validateSetAttr = $paramMeta.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | Select-Object -First 1
        if ($validateSetAttr) {
            Write-Host 'Allowed values:'
            Write-Host ($validateSetAttr.ValidValues -join ', ')
        }
        elseif ($valueType.IsEnum) {
            Write-Host 'Allowed values:'
            Write-Host (([System.Enum]::GetNames($valueType)) -join ', ')
        }
        elseif ($valueType -eq [bool] -or $valueType -eq [System.Management.Automation.SwitchParameter]) {
            Write-Host 'Allowed values:'
            Write-Host 'true, false'
        }
        else {
            Write-Host 'Allowed values:'
            Write-Host 'Any value accepted by Set-PSReadLineOption for this parameter.'
        }
    }

    Write-Host 'Examples:'
    Write-Host '.\ProfileModify.ps1 -h'
    Write-Host '.\ProfileModify.ps1 -h -p EditMode'
    Write-Host '.\ProfileModify.ps1 -p Parameters -v Green'
    Write-Host '.\ProfileModify.ps1 -p EditMode -v Windows'
}

function Get-SettingImpact {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingName
    )

    if ($safeSettingList -contains $SettingName) {
        return 'Safe'
    }

    if ($highImpactSettingList -contains $SettingName) {
        return 'HighImpact'
    }

    return 'Unknown'
}

function Assert-ApplyAllowed {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$EditSpec
    )

    $impact = Get-SettingImpact -SettingName $EditSpec.Name
    if ($impact -eq 'Safe') {
        Write-TraceMessage -Message ('Setting "{0}" is in safe list.' -f $EditSpec.Name)
        return
    }

    if (-not $Force) {
        if ($impact -eq 'HighImpact') {
            throw ('Setting "{0}" is high-impact. Re-run with -f to apply and persist this change.' -f $EditSpec.Name)
        }

        throw ('Setting "{0}" is not in the safe list. Re-run with -f to apply and persist this change.' -f $EditSpec.Name)
    }

    Write-Warning ('Applying {0} setting "{1}" because -f was provided.' -f $impact.ToLower(), $EditSpec.Name)
}

function Show-ProfileTargetsOnly {
    $profileTargets = Get-ProfileTargets

    if (@($profileTargets).Count -eq 0) {
        Write-Host 'No profile targets are available in this host context.'
        return
    }

    Write-Host 'Profile targets:'
    foreach ($profilePath in $profileTargets) {
        Write-Host ('Path: {0}' -f $profilePath)
        Write-Host ('Exists: {0}' -f (Test-Path -LiteralPath $profilePath))
        Write-Host '---'
    }
}

function Get-PromptTextWorkflowChoice {
    Write-Host ('Which change to <{0}> do you want?' -f $EditMode)
    Write-Host ' A - Change the PromptText setting'
    Write-Host ' B - Edit the prompt function'

    $choice = (Read-Host 'Select A or B').Trim().ToUpperInvariant()
    switch ($choice) {
        'A' { return 'PromptTextSetting' }
        'B' { return 'PromptFunction' }
        default { throw 'Invalid choice. Use A or B.' }
    }
}

function Build-PromptFunctionDefinition {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PromptPrefix
    )

    $escapedPrefix = $PromptPrefix.Replace("'", "''")

    return @"
function prompt {
    `$cwd = (Get-Location).Path
    if (`$cwd.Length -gt 40) {
        `$cwd = '...' + `$cwd.Substring(`$cwd.Length - 40)
    }

    '$escapedPrefix' + ' ' + `$cwd + '> '
}
"@
}

function Set-PromptFunctionInProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfilePath,

        [Parameter(Mandatory = $true)]
        [string]$PromptPrefix
    )

    $definition = Build-PromptFunctionDefinition -PromptPrefix $PromptPrefix
    $block = @"
# BEGIN ProfileModify Prompt
$definition
# END ProfileModify Prompt
"@

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        Write-TraceMessage -Message ('Creating profile file: {0}' -f $ProfilePath)
        New-Item -Path $ProfilePath -ItemType File -Force | Out-Null
    }

    $content = Get-Content -LiteralPath $ProfilePath -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) {
        Set-Content -LiteralPath $ProfilePath -Value $block
        Write-Host ('Updated profile: {0}' -f $ProfilePath)
        return
    }

    $pattern = '(?ms)# BEGIN ProfileModify Prompt.*?# END ProfileModify Prompt\s*'
    if ($content -match $pattern) {
        $updated = [regex]::Replace($content, $pattern, ($block + [Environment]::NewLine))
        Set-Content -LiteralPath $ProfilePath -Value $updated
        Write-Host ('Updated profile: {0}' -f $ProfilePath)
        return
    }

    $trimmed = $content.TrimEnd()
    $separator = [Environment]::NewLine
    $updated = $trimmed + $separator + $separator + $block + $separator
    Set-Content -LiteralPath $ProfilePath -Value $updated
    Write-Host ('Updated profile: {0}' -f $ProfilePath)
}

function Show-ParameterOverview {
    param(
        [Parameter(Mandatory = $true)]
        [object]$OptionObject
    )

    $rows = foreach ($prop in ($OptionObject.PSObject.Properties | Sort-Object Name)) {
        $valueText = if ($null -eq $prop.Value) {
            '<null>'
        }
        elseif ($prop.Name -eq 'Colors' -and $prop.Value -is [System.Collections.IDictionary]) {
            ($prop.Value.GetEnumerator() | Sort-Object Key | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value }) -join '; '
        }
        elseif ($prop.Value -is [System.Array]) {
            ($prop.Value | ForEach-Object { [string]$_ }) -join ', '
        }
        else {
            [string]$prop.Value
        }

        [pscustomobject]@{
            ParameterName = $prop.Name
            ParameterValue = $valueText
        }
    }

    Write-Host 'ParameterName / ParameterValue overview:'
    $rows | Format-Table -AutoSize
}

function Show-ListEffective {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$EditSpec,

        [Parameter(Mandatory = $true)]
        [string]$ResolvedProfValue
    )

    Import-Module PSReadLine -Force -ErrorAction Stop
    $opt = Get-PSReadLineOption

    if ($null -eq $opt) {
        Write-Host 'PSReadLine option object is null (module/host issue).'
        return
    }

    if ($EditSpec.Kind -eq 'TokenColor') {
        $hasColorsProperty = ($opt.PSObject.Properties.Name -contains 'Colors')
        if ($hasColorsProperty -and $null -eq $opt.Colors) {
            Write-Host ('Colors table is null. Initializing {0} color now...' -f $EditSpec.ColorsKey)

            $setPsReadLineOption = Get-Command Set-PSReadLineOption -ErrorAction Stop
            if ($setPsReadLineOption.Parameters.ContainsKey('Colors')) {
                Set-PSReadLineOption -Colors @{ $EditSpec.ColorsKey = $ResolvedProfValue }
            }
            elseif ($setPsReadLineOption.Parameters.ContainsKey('TokenKind') -and $setPsReadLineOption.Parameters.ContainsKey('TokenForegroundColor')) {
                Set-PSReadLineOption -TokenKind $EditSpec.TokenKind -TokenForegroundColor $ResolvedProfValue
            }

            $opt = Get-PSReadLineOption
            $hasColorsProperty = ($opt.PSObject.Properties.Name -contains 'Colors')
        }

        Show-ParameterOverview -OptionObject $opt

        $opt | Format-List *
        if ($hasColorsProperty) {
            $opt.Colors
        }

        return
    }

    Show-ParameterOverview -OptionObject $opt

    $opt | Format-List *
}

function Get-ProfileSettingMatches {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$EditSpec
    )

    $profileLoadOrder = Get-ProfileTargets

    $results = @()
    foreach ($profilePath in $profileLoadOrder) {
        if (-not (Test-Path -LiteralPath $profilePath)) {
            continue
        }

        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $profilePath) {
            $lineNumber++

            if ($line -notmatch 'Set-PSReadLineOption') {
                continue
            }

            $isMatch = $false
            if ($EditSpec.Kind -eq 'TokenColor') {
                $colorsKey = [regex]::Escape($EditSpec.ColorsKey)
                $tokenKind = [regex]::Escape($EditSpec.TokenKind)
                $isMatch = ($line -match "${colorsKey}" -or $line -match "TokenKind\s+${tokenKind}")
            }
            else {
                $paramName = [regex]::Escape($EditSpec.Name)
                $isMatch = ($line -match "-${paramName}(\s|$)")
            }

            if ($isMatch) {
                $results += [pscustomobject]@{
                    ProfilePath = $profilePath
                    LineNumber = $lineNumber
                    Line = $line.Trim()
                    LoadOrder = [array]::IndexOf($profileLoadOrder, $profilePath)
                }
            }
        }
    }

    return $results
}

function Show-ListAll {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$EditSpec
    )

    $profileMatches = Get-ProfileSettingMatches -EditSpec $EditSpec | Sort-Object LoadOrder, LineNumber

    if (@($profileMatches).Count -eq 0) {
        Write-Host ('No profile setting match found for edit mode "{0}" in current-user profile files.' -f $EditMode)
        return
    }

    Write-Host 'All profile setting matches:'
    foreach ($entry in $profileMatches) {
        Write-Host ('Path: {0}' -f $entry.ProfilePath)
        Write-Host ('Line: {0}' -f $entry.LineNumber)
        Write-Host ('Text: {0}' -f $entry.Line)
        Write-Host '---'
    }
}

function Set-SessionSetting {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$EditSpec,

        [Parameter(Mandatory = $true)]
        [object]$ResolvedProfValue,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Colors', 'LegacyToken')]
        [string]$ColorApiMode
    )

    if ($EditSpec.Kind -eq 'TokenColor') {
        Write-TraceMessage -Message ('Applying session setting: {0}={1} via {2}' -f $EditSpec.ColorsKey, $ResolvedProfValue, $ColorApiMode)

        if ($ColorApiMode -eq 'Colors') {
            Set-PSReadLineOption -Colors @{ $EditSpec.ColorsKey = $ResolvedProfValue }
        }
        else {
            Set-PSReadLineOption -TokenKind $EditSpec.TokenKind -TokenForegroundColor $ResolvedProfValue
        }

        return
    }

    Write-TraceMessage -Message ('Applying session setting: {0}={1}' -f $EditSpec.Name, $ResolvedProfValue)
    $splat = @{ }
    $splat[$EditSpec.Name] = $ResolvedProfValue
    Set-PSReadLineOption @splat
}

function Build-ProfileLine {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$EditSpec,

        [Parameter(Mandatory = $true)]
        [object]$ResolvedProfValue
    )

    if ($EditSpec.Kind -eq 'TokenColor') {
        $valueLiteral = Format-ValueLiteral -Value $ResolvedProfValue
        return "if ((Get-Command Set-PSReadLineOption).Parameters.ContainsKey('Colors')) { Set-PSReadLineOption -Colors @{ $($EditSpec.ColorsKey) = $valueLiteral } } else { Set-PSReadLineOption -TokenKind $($EditSpec.TokenKind) -TokenForegroundColor $valueLiteral }"
    }

    $valueLiteral = Format-ValueLiteral -Value $ResolvedProfValue
    return "Set-PSReadLineOption -$($EditSpec.Name) $valueLiteral"
}

function Ensure-ProfileContainsLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfilePath,

        [Parameter(Mandatory = $true)]
        [string]$LineToEnsure
    )

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        Write-TraceMessage -Message ('Creating profile file: {0}' -f $ProfilePath)
        New-Item -Path $ProfilePath -ItemType File -Force | Out-Null
    }

    $exists = Select-String -Path $ProfilePath -SimpleMatch -Pattern $LineToEnsure -Quiet
    if (-not $exists) {
        Add-Content -Path $ProfilePath -Value $LineToEnsure
        Write-Host ('Updated profile: {0}' -f $ProfilePath)
    }
    else {
        Write-Host ('Profile already contains setting: {0}' -f $ProfilePath)
    }
}

try {
    Ensure-PsReadLineLoaded
    $editSpec = Get-EditSpec
    $colorApiMode = Get-ColorApiMode

    if ($HelpMode) {
        Write-TraceMessage -Message 'Help mode requested; no changes will be applied.'
        Show-HelpMode -EditSpec $editSpec
        exit 0
    }

    if ($ListAllMode -and $ListMode) {
        Write-TraceMessage -Message 'List-all + list-effective requested; keeping current behavior (all matches).'
        Show-ListAll -EditSpec $editSpec
        exit 0
    }

    if ($ListAllMode) {
        Write-TraceMessage -Message 'List-all mode requested without -l; showing profile targets only.'
        Show-ProfileTargetsOnly
        exit 0
    }

    if ($ListMode) {
        Write-TraceMessage -Message 'List-effective mode requested; no changes will be applied.'

        $listValue = 'Yellow'
        if ($editSpec.Kind -eq 'TokenColor') {
            $listValue = Convert-ProfValue -EditSpec $editSpec -InputValue $ProfValue
        }

        Show-ListEffective -EditSpec $editSpec -ResolvedProfValue $listValue
        exit 0
    }

    Assert-ApplyAllowed -EditSpec $editSpec

    if ($editSpec.Name -eq 'PromptText') {
        $workflowChoice = Get-PromptTextWorkflowChoice
        if ($workflowChoice -eq 'PromptFunction') {
            $script:ResolvedProfValue = Convert-ProfValue -EditSpec $editSpec -InputValue $ProfValue
            Write-TraceMessage -Message ('Resolved ProfValue: {0}' -f $script:ResolvedProfValue)

            $profilePaths = Get-ProfileTargets
            foreach ($profilePath in $profilePaths) {
                Set-PromptFunctionInProfile -ProfilePath $profilePath -PromptPrefix $script:ResolvedProfValue
            }

            $promptDefinition = Build-PromptFunctionDefinition -PromptPrefix $script:ResolvedProfValue
            Set-Item -Path function:prompt -Value ([scriptblock]::Create($promptDefinition))
            Write-Host ('Applied prompt function update using prefix: {0}' -f $script:ResolvedProfValue)
            Write-Host 'Restart terminal(s) to verify startup behavior in new sessions.'
            exit 0
        }

        Write-TraceMessage -Message 'PromptText setting branch selected.'
    }

    $script:ResolvedProfValue = Convert-ProfValue -EditSpec $editSpec -InputValue $ProfValue
    Write-TraceMessage -Message ('Resolved ProfValue: {0}' -f $script:ResolvedProfValue)

    Set-SessionSetting -EditSpec $editSpec -ResolvedProfValue $script:ResolvedProfValue -ColorApiMode $colorApiMode
    $line = Build-ProfileLine -EditSpec $editSpec -ResolvedProfValue $script:ResolvedProfValue

    $profilePaths = Get-ProfileTargets
    foreach ($profilePath in $profilePaths) {
        Ensure-ProfileContainsLine -ProfilePath $profilePath -LineToEnsure $line
    }

    Write-Host ('Applied profile setting: EditMode={0}, ProfValue={1}' -f $EditMode, $script:ResolvedProfValue)
    Write-Host 'Restart terminal(s) to verify startup behavior in new sessions.'
}
catch {
    Write-Error ('ProfileModify failed: {0}' -f $_.Exception.Message)
    exit 1
}
