# CRP-208 Walkthrough

## Intake

The operator requested an early, safe workspace-wide rename of the LCM
repositories and shared module repository.

## Discovery

The migration cohort contains 15 repositories: 13 with `.lcm/config.json`, plus
the central LCM AI and inventory repositories. The root `.agents` junction
currently targets `D:\Git_Repositories\LCM_AI\.agents` and is a required
cutover dependency. The root tool hub is also a cutover dependency:
`D:\Git_Repositories\LCM_Tools` will become `D:\Git_Repositories\LCM_Tools`.

## Gate 1

CRP-208 is active. The migration runner passed its non-mutating preflight and
found two dirty central repositories, so physical cutover awaits explicit
dirty-worktree authorization.