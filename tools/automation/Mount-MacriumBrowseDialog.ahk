; ==============================================================================
; Mount-MacriumBrowseDialog.ahk - Macrium Reflect Browse Dialog Automation Atom
; Version: 10.0.3 (BUG-313 / AutoHotkey v2)
; Compatibility: This version of the file works in Macrium Reflect v10.0.8989 (Creation timestamp: 2026-11-10 14:22:57)
; ==============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, OutputDebug

A_Args := A_Args
timeoutSeconds := 60
if (A_Args.Length >= 1 && IsNumber(A_Args[1])) {
    timeoutSeconds := Integer(A_Args[1])
}

SetTitleMatchMode(2)
DetectHiddenWindows(false)

startTime := A_TickCount
maxWaitMs := timeoutSeconds * 1000

dialogHwnd := 0

FileAppend("INFO: Awaiting Macrium Browse Image dialog (timeout: " timeoutSeconds "s)...`n", "*")

while ((A_TickCount - startTime) < maxWaitMs) {
    if WinExist("ahk_class #32770", "restricted folders") {
        dialogHwnd := WinExist()
        break
    }
    if WinExist("Browse Backup ahk_class #32770") {
        dialogHwnd := WinExist()
        break
    }
    if WinExist("Macrium Reflect", "restricted folders") {
        dialogHwnd := WinExist()
        break
    }
    Sleep(250)
}

if (!dialogHwnd) {
    FileAppend("STEP_WINDOW_FOUND: FAILED (Dialog did not appear within " timeoutSeconds "s)`n", "*")
    FileAppend("STATUS: FAILED`n", "*")
    ExitApp(1)
}

winTitle := WinGetTitle(dialogHwnd)
FileAppend("STEP_WINDOW_FOUND: SUCCESS (Title: '" winTitle "', HWND: " dialogHwnd ")`n", "*")

WinActivate(dialogHwnd)
Sleep(250)

; 1. Check partition checkbox in SysListView321 (row 1, x=20 y=38)
; This enables Button4 (Restricted), Button5 (Writable), and Button6 (OK)
ControlClick("SysListView321", dialogHwnd, , "Left", 1, "x20 y38")
Sleep(250)
FileAppend("STEP_PARTITION_SELECT: CHECKED (via SysListView321 x20 y38)`n", "*")

; 2. Check "Enable access to restricted folders" (Button4)
try {
    ControlSetChecked(1, "Button4", dialogHwnd)
    FileAppend("STEP_RESTRICTED_FOLDERS: CHECKED (via Button4)`n", "*")
} catch {
    ControlClick("Button4", dialogHwnd)
    FileAppend("STEP_RESTRICTED_FOLDERS: CLICKED (via Button4)`n", "*")
}

; 3. Check "Make writable" (Button5)
try {
    ControlSetChecked(1, "Button5", dialogHwnd)
    FileAppend("STEP_WRITABLE: CHECKED (via Button5)`n", "*")
} catch {
    ControlClick("Button5", dialogHwnd)
    FileAppend("STEP_WRITABLE: CLICKED (via Button5)`n", "*")
}

Sleep(200)

; 4. Click OK Button (Button6)
try {
    ControlFocus("Button6", dialogHwnd)
    Sleep(100)
    ControlClick("Button6", dialogHwnd)
    FileAppend("STEP_OK_CLICK: CLICKED (via Button6)`n", "*")
} catch {
    ControlClick("OK", dialogHwnd)
    FileAppend("STEP_OK_CLICK: CLICKED (via text OK)`n", "*")
}

; Wait and verify dialog closed; if still active, send Enter key
Sleep(500)
if WinExist(dialogHwnd) {
    ControlSend("{Enter}", , dialogHwnd)
    FileAppend("STEP_OK_CLICK: SENT_ENTER`n", "*")
}

Sleep(500)
FileAppend("STATUS: SUCCESS`n", "*")
ExitApp(0)
