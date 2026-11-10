# Change Request Proposal: CRP-275

```yaml
CRP-ID: CRP-275
Title: Tool Explorer Filter Pattern Matching
Scope: LCM_Inventory
Baseline-Version: 10.2.0
Author: Rolf
Date: 2026-10-14 12:59:25
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Extend Tool Explorer field filters with simple case-insensitive wildcard matching: * matches zero or more characters, ? matches exactly one character, and $ anchors a pattern at the end of a value. Examples: Group:LCM*, Group:*abc, and Group:LCM$.

## 2. Requirements

1. The Tool Explorer global row-search field MUST support simple,
   case-insensitive patterns in field-qualified filters such as `Group:LCM*`.
2. `*` MUST match zero or more characters.
3. `?` MUST match exactly one character.
4. A trailing `$` MUST mean that the preceding pattern matches at the end of
   the field value. It is an end anchor, not a general regular-expression
   feature.
5. `*abc` MUST match a group value containing `abc` at any position.
6. Existing literal searches and `!` negation MUST retain their current
   behavior.
7. Pattern matching MUST apply consistently to supported field-qualified
   filters, including `Group`, `Subsystem`, `Env`, `Role`, `Audience`,
   `Category`, `Name`, and `Description`.
8. The filter grammar MUST remain deliberately limited. Regular-expression
   syntax, character classes, alternation, capture groups, and replacement
   behavior are out of scope.

## 3. Acceptance Examples

| Filter | Required interpretation |
|---|---|
| `Group:LCM*` | Match group/domain values beginning with `LCM`. |
| `Group:*abc` | Match group/domain values containing `abc` at any position. |
| `Group:LCM$` | Match group/domain values ending with `LCM`. |
| `Role:Dev?` | Match role values with `Dev` followed by exactly one character. |
| `!Group:LCM*` | Exclude values matched by the same pattern. |

## 4. Scope

- **In scope:** `matchRowSearch` in `assets/lcm-tool-explorer.js`, its user
  help text, and focused browser-level or JavaScript regression coverage.
- **Out of scope:** full grep, regular expressions, changes to dropdown
  filters, and pattern-based replacement or mass assignment.
