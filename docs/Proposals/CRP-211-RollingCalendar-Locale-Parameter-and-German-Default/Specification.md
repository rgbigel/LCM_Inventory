# CRP-211: RollingCalendar Locale Parameter and German Default

```yaml
CRP-ID: CRP-211
Priority: 3
Scope: RollingCalendar Locale/Culture Internationalization & German Default
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Affected-Repos:
  - RollingCalendar
  - LCM_Inventory
```

## Objective

Enhance `Invoke-RollingCalendar.ps1` in repository `RollingCalendar` with configurable locale and culture formatting support.
By default, calendar presentations and date calculations shall use the **German (`de-DE`)** locale standard (e.g., date formats `dd.MM.yyyy`, German day/month names, and `lang="de"` in HTML).
The tool shall provide an explicit parameter (`-Culture` / `-Locale`) enabling operators to dynamically specify alternative cultures (such as `en-US`, `fr-FR`, or `en-GB`).

---

## Current State vs. Proposed Architecture

### Current Behavior (`v1.1.0`)
1. **Hardcoded US English Date Formatting**:
   - The period string in the HTML header is hardcoded to US format:
     `$periodStr = '{0:MM/dd/yyyy} - {1:MM/dd/yyyy}' -f $startMonday, ($startMonday.AddDays($totalDays - 1))`
   - Scheduled task logging formats dates with `$candidate.ToString('MM/dd/yyyy HH:mm')`.
2. **Hardcoded English Weekday Column Headers**:
   - HTML grid headers are hardcoded as static English tags:
     ```html
     <div class="weekday-header">Mon</div>
     <div class="weekday-header">Tue</div>
     <div class="weekday-header">Wed</div>
     <div class="weekday-header">Thu</div>
     <div class="weekday-header">Fri</div>
     <div class="weekday-header">Sat</div>
     <div class="weekday-header">Sun</div>
     ```
3. **Hardcoded Invariant Month Names**:
   - First-of-month and first-cell labels use `$cellDate.ToString('MMM')` under the ambient process culture without explicit culture binding.
4. **Hardcoded HTML Language**:
   - Document root is hardcoded to `<html lang="en">`.

### Proposed Architecture (`v1.2.0`)
1. **New Parameter: `-Culture` (Alias: `-Locale`)**:
   - Added to `param()` in `Invoke-RollingCalendar.ps1`:
     ```powershell
     [Parameter()]
     [Alias('Locale')]
     [string]$Culture = 'de-DE'
     ```
   - Validated against `[System.Globalization.CultureInfo]::GetCultureInfo($Culture)` with graceful error reporting if an invalid culture string is supplied.
2. **German Default (`de-DE`) Standards**:
   - **Period Header**: Formatted according to the selected culture's short date pattern (for `de-DE`: `dd.MM.yyyy`, e.g., `05.10.2026 - 01.11.2026`).
   - **Weekday Column Headers**: Resolved dynamically from the culture's `DateTimeFormat.AbbreviatedDayNames`:
     - Starting from Monday (`DayOfWeek.Monday` through `DayOfWeek.Sunday`).
     - For `de-DE`: `Mo`, `Di`, `Mi`, `Do`, `Fr`, `Sa`, `So`.
     - For `en-US`: `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun`.
   - **Month Abbreviations**: Extracted using `$cellDate.ToString('MMM', $cultureObj)` (e.g., `1. Okt`, `1. Nov` in German).
   - **HTML Document Language**: Dynamically populated: `<html lang="$($cultureObj.TwoLetterISOLanguageName)">` (`de` for `de-DE`).
3. **Display Standards Compliance**:
   - Conforms to `DisplayStandardsPolicy.md` v9.2.0 (`RULE-DSP-007` Headless Print-to-PDF, `RULE-DSP-016` Dynamic Tool Versioning).
   - Tool version displayed in generated HTML footer or title reflects the dynamic `$scriptVersion`.

---

## User Acceptance Requirements

1. **REQ-RC-001: Default German Locale**:
   Running `Invoke-RollingCalendar.ps1` with default parameters MUST produce calendar output using `de-DE` locale conventions (period format `dd.MM.yyyy`, German weekday headers `Mo`..`So`, and `lang="de"`).
2. **REQ-RC-002: Dynamic Culture Parameter**:
   Specifying `-Culture <culture-name>` (or `-Locale <culture-name>`) MUST switch all date formatting, weekday abbreviations, month labels, and HTML language tags to the requested culture.
3. **REQ-RC-003: Backward Compatibility**:
   Existing parameters (`-Time`, `-Frequency`, `-OutputDir`, `-NoShow`, `-SendToPrinter`, `-ResetUrl`) MUST continue to function identically.
4. **REQ-RC-004: Test Suite Validation**:
   Unit and integration tests in `RollingCalendar/tests/` MUST verify both default `de-DE` output and parameterized `en-US` / custom culture output.
