# Walkthrough: BUG-377 - Python Byte-Code Caches Left In Governed Repositories

Module: docs/Proposals/377_BUG-Python-Byte-Code-Caches-Left-In-Governed-Repositor/Walkthrough BUG-377.md  
Purpose: Walkthrough of BUG-377.  
Path: LCM_Inventory/docs/Proposals/377_BUG-Python-Byte-Code-Caches-Left-In-Governed-Repositor/Walkthrough BUG-377.md  
Authors: Rolf, Claude  
Version: 10.8.4  
Status: Verified  
Date: 2026-11-20 16:51:15

---

- `LCM_AI/.claude/settings.json`: both hook commands run `python.exe -I -B` (no byte-code); JSON parse clean.
- `.gitignore` with `__pycache__/` added in LCM_AI, LCM_Shared, LCM_Supervision, LCM_Tools (root and LCM_Inventory had it).
- Check: no untracked `__pycache__` file in any LCM repository.
