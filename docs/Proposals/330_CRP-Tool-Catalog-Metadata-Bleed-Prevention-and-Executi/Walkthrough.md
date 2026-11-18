# Walkthrough: CRP-330

## Overview
This walkthrough demonstrates the prevention of metadata bleeding across tools with identical filenames in different domains, specifically correcting `Set-MachineWideExecutionPolicy.ps1`.

## Key Inspection Points
1. **Catalog Entry Check**:
   Before:
   ```json
   {
     "Name": "Set-MachineWideExecutionPolicy.ps1",
     "ShortName": "SystemConfigurationSetMachineWideExecutionPolicy",
     "RelativePath": "LCM_Inventory\\tools\\Set-MachineWideExecutionPolicy.ps1"
   }
   ```
   After:
   ```json
   {
     "Name": "Set-MachineWideExecutionPolicy.ps1",
     "ShortName": "SetMachineWideExecutionPolicy",
     "RelativePath": "LCM_Inventory\\tools\\Set-MachineWideExecutionPolicy.ps1"
   }
   ```
2. **Duplicate Filename Audit**:
   Ensure `asus-debloater.ps1`, `GoAdm.ps1`, `Test-PowerShellHklmState.ps1`, and `Set-MachineWideExecutionPolicy.ps1` each reflect their proper individual group/domain identities.
