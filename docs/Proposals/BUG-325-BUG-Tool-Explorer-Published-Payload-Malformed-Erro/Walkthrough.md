# Walkthrough: BUG-325

## Changes Made
1. Corrected script tag attribute order in `modules/LcmToolCatalog.psm1`.
2. Hardened `src/do/daemon.go` display data extractor to support both attribute permutations.
3. Compiled `do.exe` and deployed to `DoT/do.exe`.
4. Re-rendered `data/artifacts/SHOW_TOOLS.html`.
5. Restarted elevated daemon task `LCM_DesktopDaemon_rgbig`.

## Verification Results
- `GET /displays/data/tools`: Returned 317 tools.
- `GET /displays/status/tools`: `state: Current`.
- Pester suite: 17 passed, 0 failed.
