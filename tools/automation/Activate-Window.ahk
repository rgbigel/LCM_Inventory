; ==============================================================================
; Activate-Window.ahk - Window Activation Atom (CRP-354)
; Module: tools/automation/Activate-Window.ahk
; Purpose: Waits for a window of a given process (optionally with a title substring)
;          and brings it to the foreground; restores a minimized window first.
; Path: LCM_Inventory/tools/automation/Activate-Window.ahk
; Authors: Rolf, Claude
; Version: 10.7.5
; Date: 2026-11-18
; Usage: AutoHotkey64.exe Activate-Window.ahk <processName> [titleSubstring] [waitSeconds]
;        Run only through Invoke-LcmAhkAtom (registered intent, non-elevated).
; Reason: a program started by the background DO daemon may not take the foreground
;         (Windows foreground lock), e.g. Notepad++ receiving files in a running instance.
; Output: one line on stdout (or the file named by LCM_AHK_OUT):
;         STATUS: SUCCESS|NO_WINDOW|NOT_ACTIVATED|BAD_ARGS
; Exit codes: 0 success, 2 bad arguments, 3 no window, 4 window not activated.
; ==============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Off

outPath := EnvGet("LCM_AHK_OUT")
Out(msg) {
  global outPath
  FileAppend(msg "`n", (outPath != "") ? outPath : "*", "UTF-8")
}

if (A_Args.Length < 1 || !(A_Args[1] ~= "i)^[\w.+-]+\.exe$")) {
  Out("STATUS: BAD_ARGS (expected <processName.exe> [titleSubstring] [waitSeconds])")
  ExitApp(2)
}
processName := A_Args[1]
titlePart := (A_Args.Length >= 2) ? A_Args[2] : ""
waitSeconds := (A_Args.Length >= 3 && IsInteger(A_Args[3])) ? Integer(A_Args[3]) : 10
SetTitleMatchMode(2)
target := titlePart " ahk_exe " processName

; The window may still be starting or still loading the file named in its title.
if !WinWait(target, , waitSeconds) {
  if (titlePart = "" || !WinExist("ahk_exe " processName)) {
    Out("STATUS: NO_WINDOW (" processName ")")
    ExitApp(3)
  }
  target := "ahk_exe " processName
}
target := "ahk_id " WinExist(target)

activated := false
Loop 3 {
  if (WinGetMinMax(target) = -1)
    WinRestore(target)
  WinActivate(target)
  if WinWaitActive(target, , 2) {
    activated := true
    break
  }
}
if !activated {
  Out("STATUS: NOT_ACTIVATED (Windows refused the foreground change)")
  ExitApp(4)
}
Out("STATUS: SUCCESS (" WinGetTitle(target) ")")
ExitApp(0)
