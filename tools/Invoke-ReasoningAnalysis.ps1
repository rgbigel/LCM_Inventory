<#
.SYNOPSIS
    Generates an evidence-based execution trace from a conversation transcript.
.DESCRIPTION
    Module: Invoke-ReasoningAnalysis
    Purpose: Selects transcript events by quoted message text or legacy offset and writes a
             bounded, evidence-only Markdown report. During interactive chat use, the active
             IDE host automatically provides its current session transcript; -TranscriptPath
             is retained as an offline fallback for explicit exported files.
    Path: LCM_Inventory/tools/Invoke-ReasoningAnalysis.ps1
    Authors: Rolf, LCM_AI Engine, Copilot, Antigravity
    Version: 10.0.0
    Date: 2026-10-13
.PARAMETER TranscriptPath
    Optional offline fallback: path to an exported JSON or JSONL transcript file. During normal
    chat use, the active IDE host supplies its session transcript automatically.
.PARAMETER From
    Case-insensitive quoted text that identifies the start event. Matching multiple events
    stops with an explicit ambiguity error; use -ListMatches to inspect candidates.
.PARAMETER Until
    Optional case-insensitive quoted text that identifies the inclusive final event.
.PARAMETER ListMatches
    Lists matching event metadata and does not generate a report.
.PARAMETER Offset
    Legacy user-message offset. Zero is the newest user message in the supplied transcript.
.EXAMPLE
    ar -TranscriptPath .\conversation.jsonl -From 'good morning routine'
.EXAMPLE
    ar -TranscriptPath .\conversation.json -From 'good morning routine' -Until 'found problems'
.EXAMPLE
    ar -TranscriptPath .\conversation.jsonl -Find 'GoodMorning' -ListMatches
#>

[CmdletBinding(DefaultParameterSetName = 'Quote')]
param(
    [string]$TranscriptPath,

    [Parameter(ParameterSetName = 'Quote')]
    [Alias('Find')]
    [string]$From,

    [Parameter(ParameterSetName = 'Quote')]
    [string]$Until,

    [Parameter(ParameterSetName = 'Quote')]
    [switch]$ListMatches,

    [Parameter(ParameterSetName = 'Offset')]
    [int]$Offset,

    [ValidateRange(0, 50)]
    [int]$Context = 0,

    [ValidateSet('All', 'Messages', 'ToolCalls', 'Errors')]
    [string[]]$Include = @('All'),

    [string]$OutputPath,

    [switch]$View,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-ReasoningText {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ''
    }
    if ($Value -is [string]) {
        return $Value
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        return (@($Value | ForEach-Object { ConvertTo-ReasoningText -Value $_ }) -join [Environment]::NewLine)
    }
    return ($Value | ConvertTo-Json -Depth 20 -Compress)
}

function Get-ReasoningProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    foreach ($name in $Names) {
        $property = $InputObject.PSObject.Properties[$name]
        if ($null -ne $property -and $null -ne $property.Value) {
            return $property.Value
        }
    }
    return $null
}

function ConvertTo-ReasoningEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    $textValue = Get-ReasoningProperty -InputObject $InputObject -Names @(
        'content', 'text', 'message', 'user_message', 'assistant_response', 'body', 'summary'
    )
    $typeValue = Get-ReasoningProperty -InputObject $InputObject -Names @('type', 'event_type', 'kind')
    $roleValue = Get-ReasoningProperty -InputObject $InputObject -Names @('role', 'speaker', 'author', 'source')
    $toolValue = Get-ReasoningProperty -InputObject $InputObject -Names @('tool_name', 'tool', 'name')
    $timeValue = Get-ReasoningProperty -InputObject $InputObject -Names @(
        'timestamp', 'created_at', 'time', 'datetime', 'occurred_at'
    )
    $idValue = Get-ReasoningProperty -InputObject $InputObject -Names @('id', 'event_id', 'uuid', 'step_index')

    $eventType = ConvertTo-ReasoningText -Value $typeValue
    $role = ConvertTo-ReasoningText -Value $roleValue
    $tool = ConvertTo-ReasoningText -Value $toolValue

    $toolCallsProp = Get-ReasoningProperty -InputObject $InputObject -Names @('tool_calls', 'tools')
    if ([string]::IsNullOrWhiteSpace($tool) -and $null -ne $toolCallsProp) {
        $extractedNames = @()
        foreach ($call in @($toolCallsProp)) {
            if ($call -is [System.Collections.IDictionary] -or $call.PSObject) {
                $cName = Get-ReasoningProperty -InputObject $call -Names @('name', 'tool', 'tool_name', 'toolAction')
                if (-not [string]::IsNullOrWhiteSpace((ConvertTo-ReasoningText -Value $cName))) {
                    $extractedNames += ConvertTo-ReasoningText -Value $cName
                }
            }
        }
        if ($extractedNames.Count -gt 0) {
            $tool = $extractedNames -join ', '
        }
    }

    $rawText = ConvertTo-ReasoningText -Value $textValue
    if ([string]::IsNullOrWhiteSpace($rawText) -and $null -ne $toolCallsProp) {
        $rawText = ConvertTo-ReasoningText -Value $toolCallsProp
    }

    $category = if ($eventType -match 'error|fail' -or $role -match 'error|fail') {
        'Error'
    } elseif (-not [string]::IsNullOrWhiteSpace($tool) -or $eventType -match 'tool|PLANNER_RESPONSE') {
        'ToolCall'
    } else {
        'Message'
    }

    [pscustomobject]@{
        Index = $Index
        EventId = if ([string]::IsNullOrWhiteSpace((ConvertTo-ReasoningText -Value $idValue))) { "event-$Index" } else { ConvertTo-ReasoningText -Value $idValue }
        Timestamp = ConvertTo-ReasoningText -Value $timeValue
        Role = $role
        Category = $category
        Tool = $tool
        Text = $rawText
        Raw = $InputObject
    }
}

function Get-ReasoningTranscriptEvents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Transcript is empty: $Path"
    }

    $items = @()
    if ([System.IO.Path]::GetExtension($Path) -ieq '.jsonl') {
        $lineNumber = 0
        foreach ($line in @($raw -split "`r?`n")) {
            $lineNumber++
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            try {
                $items += $line | ConvertFrom-Json -ErrorAction Stop
            } catch {
                throw "Transcript JSONL line $lineNumber cannot be parsed: $($_.Exception.Message)"
            }
        }
    } else {
        try {
            $document = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Transcript JSON cannot be parsed: $($_.Exception.Message)"
        }
        if ($document -is [System.Collections.IEnumerable] -and -not ($document -is [string])) {
            $items = @($document)
        } else {
            $collection = Get-ReasoningProperty -InputObject $document -Names @('events', 'messages', 'turns', 'records')
            if ($null -eq $collection) {
                throw 'Transcript JSON must be an event array or contain events, messages, turns, or records.'
            }
            $items = @($collection)
        }
    }

    if ($items.Count -eq 0) {
        throw "Transcript contains no events: $Path"
    }
    return @($items | ForEach-Object -Begin { $index = 0 } -Process {
        $index++
        ConvertTo-ReasoningEvent -InputObject $_ -Index $index
    })
}

function Get-ReasoningMatches {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Events,

        [Parameter(Mandatory = $true)]
        [string]$Phrase
    )

    return @($Events | Where-Object { $_.Text.IndexOf($Phrase, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 })
}

function Resolve-ReasoningMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Events,

        [Parameter(Mandatory = $true)]
        [string]$Phrase,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $matches = @(Get-ReasoningMatches -Events $Events -Phrase $Phrase)
    if ($matches.Count -eq 0) {
        throw "No transcript event matches $Label text: $Phrase"
    }
    if ($matches.Count -gt 1) {
        $candidates = $matches | ForEach-Object { "[$($_.Index)] $($_.Timestamp) $($_.Role): $($_.Text.Substring(0, [Math]::Min(120, $_.Text.Length)))" }
        throw "Ambiguous $Label text '$Phrase' matched $($matches.Count) events. Use -ListMatches to inspect candidates.`n$($candidates -join [Environment]::NewLine)"
    }
    return $matches[0]
}

function ConvertTo-MarkdownCell {
    [CmdletBinding()]
    param([AllowNull()][string]$Value)

    return (($Value -replace '\|', '\|' -replace "`r?`n", '<br>') -replace '`', '\`')
}

if ($Help) {
    @'
Invoke-ReasoningAnalysis.ps1 -TranscriptPath <path> [-From <quoted text> [-Until <quoted text>]]
                                [-ListMatches] [-Context <count>] [-Include <All|Messages|ToolCalls|Errors>]
Invoke-ReasoningAnalysis.ps1 -TranscriptPath <path> -Offset <legacy user-message offset>

The active IDE host automatically obtains and normalizes its current session transcript when
invoking 'ar -From "<quoted chat input>"'. -TranscriptPath is retained as an offline fallback
when analyzing an explicit exported JSON or JSONL file. Use -From (or -Find) with quoted prompt text
as the primary selection mechanism. Use -ListMatches before selecting duplicate text.
'@ | Write-Host
    return
}

if ([string]::IsNullOrWhiteSpace($TranscriptPath)) {
    throw 'TranscriptPath is required for offline invocation. In normal chat use, enter ''ar -From "<quoted chat input>"'' in the active IDE host, which automatically exports and normalizes its current session transcript.'
}
if (-not (Test-Path -LiteralPath $TranscriptPath -PathType Leaf)) {
    throw "TranscriptPath does not exist or is not a file: $TranscriptPath"
}

$events = @(Get-ReasoningTranscriptEvents -Path $TranscriptPath)
if ($ListMatches) {
    if ([string]::IsNullOrWhiteSpace($From)) {
        throw '-ListMatches requires -From or -Find text.'
    }
    $matches = @(Get-ReasoningMatches -Events $events -Phrase $From)
    if ($matches.Count -eq 0) {
        throw "No transcript event matches text: $From"
    }
    $matches | Select-Object Index, EventId, Timestamp, Role, Category, Tool, @{ Name = 'Preview'; Expression = { $_.Text.Substring(0, [Math]::Min(160, $_.Text.Length)) } } | Format-Table -AutoSize
    return
}

if ($PSCmdlet.ParameterSetName -eq 'Offset') {
    $userMessages = @($events | Where-Object { $_.Role -match '^user$|human|operator' })
    if ($userMessages.Count -eq 0) {
        throw 'Legacy -Offset selection requires transcript events with role user, human, or operator.'
    }
    $offsetIndex = [Math]::Abs($Offset)
    if ($offsetIndex -ge $userMessages.Count) {
        throw "Legacy offset $Offset is outside the $($userMessages.Count) available user messages."
    }
    $startEvent = @($userMessages | Sort-Object Index -Descending)[$offsetIndex]
} elseif ([string]::IsNullOrWhiteSpace($From)) {
    throw 'Specify -From (or -Find) quoted text. Legacy -Offset remains available only when explicitly requested.'
} else {
    $startEvent = Resolve-ReasoningMatch -Events $events -Phrase $From -Label 'start'
}

$endEvent = if ([string]::IsNullOrWhiteSpace($Until)) {
    $arInvocation = @($events | Where-Object {
        $_.Index -gt $startEvent.Index -and
        $_.Role -match '^(?i)user$' -and
        $_.Text.Trim() -match '^(?i)(?:@?ar|AnalyzeReasoning)(?:\s|$)'
    } | Select-Object -Last 1)
    if ($arInvocation.Count -gt 0) {
        $priorEvents = @($events | Where-Object { $_.Index -lt $arInvocation[0].Index })
        if ($priorEvents.Count -eq 0) {
            throw 'The AR invocation is the first selected event; provide -Until or a later -From boundary.'
        }
        $priorEvents[-1]
    } else {
        $events[-1]
    }
} else {
    Resolve-ReasoningMatch -Events $events -Phrase $Until -Label 'end'
}
if ($endEvent.Index -lt $startEvent.Index) {
    throw "The end event precedes the selected start event."
}

$startIndex = [Math]::Max(1, $startEvent.Index - $Context)
$endIndex = [Math]::Min($events.Count, $endEvent.Index + $Context)
$selectedEvents = @($events | Where-Object { $_.Index -ge $startIndex -and $_.Index -le $endIndex })
if ($Include -notcontains 'All') {
    $selectedEvents = @($selectedEvents | Where-Object { $Include -contains $_.Category -or ($_.Category -eq 'Message' -and $Include -contains 'Messages') -or ($_.Category -eq 'ToolCall' -and $Include -contains 'ToolCalls') -or ($_.Category -eq 'Error' -and $Include -contains 'Errors') })
}

$workspaceRoot = 'D:\Git_Repositories'
$logsDir = Join-Path $workspaceRoot 'LCM_Inventory\data\logs'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $OutputPath = Join-Path $logsDir "Reasoning-Analysis_$timestamp.md"
}
$outputDirectory = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$rows = @($selectedEvents | ForEach-Object {
    "| $($_.Index) | $(ConvertTo-MarkdownCell $_.EventId) | $(ConvertTo-MarkdownCell $_.Timestamp) | $(ConvertTo-MarkdownCell $_.Role) | $($_.Category) | $(ConvertTo-MarkdownCell $_.Tool) | $(ConvertTo-MarkdownCell $_.Text) |"
})
$reportContent = @"
# Evidence-Based Execution Trace

* **Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
* **Transcript:** $(ConvertTo-MarkdownCell ([System.IO.Path]::GetFullPath($TranscriptPath)))
* **Selection start:** event $($startEvent.Index) / $(ConvertTo-MarkdownCell $startEvent.EventId)
* **Selection end:** event $($endEvent.Index) / $(ConvertTo-MarkdownCell $endEvent.EventId)
* **Selected events:** $($selectedEvents.Count)

## Selection Evidence

| Field | Value |
|---|---|
| Start event | $($startEvent.Index) - $(ConvertTo-MarkdownCell $startEvent.Text) |
| End event | $($endEvent.Index) - $(ConvertTo-MarkdownCell $endEvent.Text) |
| Selection method | $(if ($PSCmdlet.ParameterSetName -eq 'Offset') { "Legacy offset $Offset" } else { "Quoted text: $(ConvertTo-MarkdownCell $From)" }) |

## Observed Events

| # | Event ID | Timestamp | Role | Category | Tool | Evidence |
|---|---|---|---|---|---|---|
$($rows -join [Environment]::NewLine)

## Scope Note

This report lists only source events selected from the supplied transcript. It makes no
independent assertions about AST health, rule compliance, daemon state, repository state, or
intent. Any conclusion must cite an event above.
"@

[System.IO.File]::WriteAllText($OutputPath, $reportContent, [System.Text.UTF8Encoding]::new($false))
Write-Host "Evidence-based reasoning report generated: $OutputPath"
if ($View) {
    Start-Process -FilePath $OutputPath
}
