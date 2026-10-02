# Implementation Plan: CRP-211

## Phase 1: Parameter & Culture Architecture (RollingCalendar)
1. Add `[string]$Culture = 'de-DE'` parameter with alias `[Alias('Locale')]` to `RollingCalendar/Invoke-RollingCalendar.ps1`.
2. Initialize and validate the `[System.Globalization.CultureInfo]` object at script startup.
3. Update script help documentation (`-h` / `-Help`) to describe the `-Culture` / `-Locale` parameter and German default.

## Phase 2: Dynamic Calendar Localization Rendering
1. Replace hardcoded English weekday `div.weekday-header` elements with dynamic generation iterating Monday through Sunday using `$culture.DateTimeFormat.GetAbbreviatedDayName()`.
2. Update cell month abbreviations to use `$cellDate.ToString('MMM', $culture)`.
3. Format `$periodStr` and scheduled task log timestamps using `$culture.DateTimeFormat.ShortDatePattern` (for `de-DE`: `dd.MM.yyyy`).
4. Inject dynamic `<html lang="$($culture.TwoLetterISOLanguageName)">`.

## Phase 3: Verification & Test Readyness
1. Add Pester tests under `RollingCalendar/tests/` asserting:
   - Default invocation yields `de-DE` day abbreviations (`Mo`, `Di`, ...) and `dd.MM.yyyy` date spans.
   - Parameterized `-Culture en-US` invocation yields `Mon`, `Tue`, ... and `MM/dd/yyyy`.
2. Run test suite to ensure clean pass without dangling browser or PDF viewer windows (`RULE-DSP-008` item 5).
3. Stage changes in Beyond Compare 5 for operator Gate 2 review (`RULE-REV-001`).
