; ==============================================================================
; Select-BeyondCompareTab.ahk - Beyond Compare Tab Atom (CRP-345, for CRP-346)
; Module: tools/automation/Select-BeyondCompareTab.ahk
; Purpose: Lists the tabs of one Beyond Compare window, activates the tab whose
;          title starts with a given prefix, or activates it and runs a Full Refresh (Ctrl+F5).
; Path: LCM_Inventory/tools/automation/Select-BeyondCompareTab.ahk
; Authors: Rolf, Claude
; Version: 10.7.5
; Date: 2026-11-18
; Usage: AutoHotkey64.exe Select-BeyondCompareTab.ahk <hwnd> <list|activate|refresh> [titlePrefix]
;        Run only through Invoke-LcmAhkAtom (registered intent, non-elevated).
; Method (probe 2026-11-18): BC exposes no tab names to UI Automation/MSAA, but the
;        window title always names the active tab and Ctrl+Tab cycles the tabs; each
;        tab owns one view control (TDirCompareView, THomeView, ...), so the tab count
;        is the number of such controls. "list" cycles once through all tabs and ends
;        on the starting tab. The window is activated, because keys go to the
;        foreground window.
; Output: one line per item on stdout (or the file named by LCM_AHK_OUT):
;        TAB: <n>: <title>   STATUS: SUCCESS|NOT_FOUND|NO_WINDOW|BAD_ARGS
; Exit codes: 0 success, 2 bad arguments or no window, 3 tab not found, 4 window not activated.
; ==============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Off

outPath := EnvGet("LCM_AHK_OUT")
Out(msg) {
  global outPath
  FileAppend(msg "`n", (outPath != "") ? outPath : "*", "UTF-8")
}

if (A_Args.Length < 2 || !IsInteger(A_Args[1]) || !(A_Args[2] ~= "^(list|activate|refresh)$")) {
  Out("STATUS: BAD_ARGS (expected <hwnd> <list|activate|refresh> [titlePrefix])")
  ExitApp(2)
}
target := "ahk_id " Integer(A_Args[1])
mode := A_Args[2]
prefix := (A_Args.Length >= 3) ? A_Args[3] : ""
if (mode != "list" && prefix = "") {
  Out("STATUS: BAD_ARGS (titlePrefix required for " mode ")")
  ExitApp(2)
}
if (!WinExist(target) || WinGetProcessName(target) != "BCompare.exe") {
  Out("STATUS: NO_WINDOW")
  ExitApp(2)
}

; One view control per tab; tree and list helper views are not tabs.
tabCount := 0
for ctl in WinGetControls(target) {
  cls := RegExReplace(ctl, "\d+$")
  if (cls ~= "^T(?!Ui)\w+View$" && cls != "TDirTreeView")
    tabCount += 1
}
if (tabCount < 1)
  tabCount := 1

; Windows may refuse a foreground change (foreground lock); retry, restore a minimized window first.
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
Sleep(300)

NextTab() {
  global target
  Send("^{Tab}")
  Sleep(400)
  return WinGetTitle(target)
}

title := WinGetTitle(target)
if (mode = "list") {
  Loop tabCount {
    Out("TAB: " A_Index ": " title)
    title := NextTab()
  }
  Out("STATUS: SUCCESS")
  ExitApp(0)
}

found := (SubStr(title, 1, StrLen(prefix)) = prefix)
Loop tabCount - 1 {
  if found
    break
  title := NextTab()
  found := (SubStr(title, 1, StrLen(prefix)) = prefix)
}
if !found {
  ; after tabCount - 1 steps one more step returns to the starting tab
  if (tabCount > 1)
    NextTab()
  Out("STATUS: NOT_FOUND (" prefix ")")
  ExitApp(3)
}
Out("TAB: active: " title)
if (mode = "refresh") {
  Send("^{F5}")
  Out("REFRESH: Full Refresh (Ctrl+F5) sent")
}
Out("STATUS: SUCCESS")
ExitApp(0)
