SetWorkingDir A_ScriptDir
CoordMode "Mouse", "Window"
SendMode "Input"
SetTitleMatchMode 2
SetControlDelay -1
SetWinDelay 0
SetKeyDelay -1, -1
SetMouseDelay -1
; SetBatchLines is deprecated in v2

; === MAIN START ===
WinActivate "Administrator: Windows PowerShell ahk_class CASCADIA_HOSTING_WINDOW_CLASS"
Sleep 100 ; small delay to ensure window focus

; Fast clicks (minimized wait)
Click 1530, 384, 0
Click 1524, 387, 0
Click 1523, 387, 0
Click 1523, 388, 0
Click 1523, 390, 0
Click 1523, 391, 0
Click 1523, 392, 0
Click 1523, 392, "Down"
Click 1523, 393, 0
Click 1523, 393, "Up"

; Send combined commands quickly
SendInput ". `$profile{Enter}"
Sleep 100
SendInput "profile{Enter}"