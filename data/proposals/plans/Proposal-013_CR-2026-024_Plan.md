# Implementation Plan - Proposal #13 (CR-2026-024)
## Modular Tool Selection & Conditional Deployment Engine
- Extend PreInstallCheck.ps1 with modular component selection (Everything, AI, BC5, Database, Daemon, Web UX).
- Tailor lcm_config.json in Setup deployer.
- Adapt Test-InstalledEnvironment.ps1 to verify active components and skip omitted ones.
