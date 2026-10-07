# LCM_AI Quality Gates

This folder contains reusable checks for LCM_AI readiness and stabilization.

Operators should run the single public readiness command from the repository root:

```powershell
.\tools/Test-WorkspaceReadiness.ps1
```

The module is imported by native governance scripts. Do not run individual quality-gate functions as the normal verification workflow unless the readiness command reports a focused failure.

Real-repository dry-run preparation is intentionally guarded:

- selecting a candidate repository does not enable writes;
- dry-run mode remains read-only;
- `_AC` and backup base paths remain off-limits;
- `Invoke-RealRepoDryRun.ps1` reports blocked state until a candidate and dry-run mode are explicitly configured.

The inspectable dry-run case documentation is maintained in [docs/real-repo-dry-run.md](docs/real-repo-dry-run.md).