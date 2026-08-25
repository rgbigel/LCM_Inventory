
Option Explicit

Dim objShell, regPath, regValue, statusText, objWMIService, colServices, svcState

' Create Shell object
Set objShell = CreateObject("WScript.Shell")

' Registry path for startup type
regPath = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WSearch\Start"

' Read the registry value
On Error Resume Next
regValue = objShell.RegRead(regPath)
If Err.Number <> 0 Then
    Echo "Error reading registry: " & Err.Description
    WScript.Quit
End If
On Error GoTo 0

' Map numeric values to descriptive text
Select Case regValue
    Case 0
        statusText = "Boot"
    Case 1
        statusText = "System"
    Case 2
        statusText = "Automatic"
    Case 3
        statusText = "Manual"
    Case 4
        statusText = "Disabled"
    Case Else
        statusText = "Unknown(" & regValue & ")"
End Select

' Check if the service is running
svcState = "Unknown"
Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
Set colServices = objWMIService.ExecQuery("Select * from Win32_Service Where Name='WSearch'")

Dim svc
For Each svc In colServices
    If svc.State = "Running" Then
        svcState = "Running"
    Else
        svcState = svc.State ' Could be Stopped, Paused, etc.
    End If
Next

' Output combined info for BGInfo
Echo statusText & " / " & svcState
