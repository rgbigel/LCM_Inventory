# CRP-258 Walkthrough

Planned operator commands:

```powershell
Show-GoodMorningContext.ps1
Show-GoodMorningContext.ps1 -Both
Show-GoodMorningContext.ps1 -Learned
Show-GoodMorningContext.ps1 -Operator
```

The default and `-Both` open both durable context files. `-Learned` opens
`LEARNED_ADVICE.md`; `-Operator` opens `ACTIVE_CONTEXT.md` at its operator-remarks section.

