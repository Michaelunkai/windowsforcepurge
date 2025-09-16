; ===== AUTOHOTKEY-SCRIPT.ahk =====
; THIS IS THE AUTOHOTKEY SCRIPT - SAVE AS .ahk FILE
; DO NOT SAVE AS .ps1 - THIS IS PURE AUTOHOTKEY CODE

#NoEnv
#SingleInstance Force
#Persistent
SendMode Input
SetWorkingDir %A_ScriptDir%
CoordMode, Mouse, Screen

; 5X FASTER SETTINGS
SetBatchLines, -1
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetControlDelay, -1
SetWinDelay, -1
SetDefaultMouseSpeed, 0

; Variables
RAMDialogHandled := {}
CheckInterval := 50

; Start monitoring
SetTimer, MonitorSetups, %CheckInterval%

; Show startup message
TrayTip, AutoHotkey Started, Ultra Fast Setup Automation Active, 3, 1
return

MonitorSetups:
    WinGet, windows, List
    
    Loop, %windows%
    {
        WinID := windows%A_Index%
        WinGetTitle, WinTitle, ahk_id %WinID%
        WinGetClass, WinClass, ahk_id %WinID%
        
        ; Check if it's a setup window
        if (InStr(WinTitle, "Setup") or InStr(WinTitle, "Install") or InStr(WinTitle, "Wizard") or WinClass = "#32770")
        {
            WinActivate, ahk_id %WinID%
            WinWaitActive, ahk_id %WinID%, , 1
            
            ; Handle RAM dialog FIRST
            HandleRAMLimitationDialog(WinID, WinTitle)
            
            ; Handle other setup steps
            HandleSetupWindow(WinID, WinTitle)
        }
    }
return

HandleRAMLimitationDialog(WinID, WinTitle)
{
    if (RAMDialogHandled[WinID])
        return
        
    WinActivate, ahk_id %WinID%
    
    ; Look for RAM limitation text
    WinGetText, WindowText, ahk_id %WinID%
    
    if (InStr(WindowText, "limit RAM") or InStr(WindowText, "2 gigabyte") or InStr(WindowText, "2GB") or InStr(WindowText, "memory limit"))
    {
        HandleRAMDialog(WinID, WinTitle)
        RAMDialogHandled[WinID] := true
        TrayTip, RAM Dialog, RAM limitation dialog handled, 2, 1
    }
}

HandleRAMDialog(WinID, WinTitle)
{
    WinActivate, ahk_id %WinID%
    
    ; Strategy 1: Find RAM checkbox by text
    Loop, 10 
    {
        ControlGetText, ButtonText, Button%A_Index%, ahk_id %WinID%
        if (InStr(ButtonText, "2") and InStr(ButtonText, "GB"))
        {
            Control, Check, , Button%A_Index%, ahk_id %WinID%
            Sleep, 10
            break
        }
    }
    
    ; Strategy 2: Click common checkbox positions
    Click, 150, 200
    Sleep, 6
    Click, 120, 250
    Sleep, 6
    Click, 180, 180
    Sleep, 6
    
    ; Strategy 3: Keyboard navigation
    Send, {Tab}{Tab}{Space}
    Sleep, 10
    Send, {Tab}{Space}
    Sleep, 10
    
    ; Click Next buttons
    ClickNextButtons(WinID)
}

HandleSetupWindow(WinID, WinTitle)
{
    WinActivate, ahk_id %WinID%
    
    WinGetText, WindowText, ahk_id %WinID%
    
    ; Handle different dialog types
    if (InStr(WindowText, "license") or InStr(WindowText, "agreement"))
    {
        CheckLicenseAndNext(WinID)
    }
    else if (InStr(WindowText, "welcome"))
    {
        ClickNextButtons(WinID)
    }
    else if (InStr(WindowText, "directory") or InStr(WindowText, "folder"))
    {
        ClickNextButtons(WinID)
    }
    else if (InStr(WindowText, "component"))
    {
        ClickNextButtons(WinID)
    }
    else if (InStr(WindowText, "ready") or InStr(WindowText, "install"))
    {
        ClickInstall(WinID)
    }
    else if (InStr(WindowText, "finish") or InStr(WindowText, "complete"))
    {
        ClickFinish(WinID)
    }
    else
    {
        ; Default action - try to click Next
        ClickNextButtons(WinID)
    }
}

CheckLicenseAndNext(WinID)
{
    ; Check license checkbox
    Loop, 5
    {
        ControlClick, Button%A_Index%, ahk_id %WinID%, , LEFT, 1, 0, 0
        Sleep, 6
    }
    ClickNextButtons(WinID)
}

ClickInstall(WinID) 
{
    ; Click Install buttons
    ControlClick, Install, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 6
    ControlClick, &Install, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 6
    ControlClick, Start, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 6
    ControlClick, Begin, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 6
}

ClickFinish(WinID)
{
    ; Click Finish buttons
    ControlClick, Finish, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 6
    ControlClick, &Finish, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 6
    ControlClick, Complete, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 6
    ControlClick, Close, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 6
}

ClickNextButtons(WinID)
{
    ; Method 1: Control click by text - 5X FASTER
    ControlClick, &Next, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 4
    ControlClick, Next, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 4
    ControlClick, Next >, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 4
    ControlClick, Continue, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 4
    ControlClick, &Continue, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 4
    ControlClick, OK, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 4
    ControlClick, &OK, ahk_id %WinID%, , LEFT, 1, 0, 0
    Sleep, 4
    
    ; Method 2: Try button controls
    Loop, 10
    {
        ControlGetText, ButtonText, Button%A_Index%, ahk_id %WinID%
        if (InStr(ButtonText, "Next") or InStr(ButtonText, "Continue") or InStr(ButtonText, "OK"))
        {
            ControlClick, Button%A_Index%, ahk_id %WinID%, , LEFT, 1, 0, 0
            Sleep, 6
            break
        }
    }
    
    ; Method 3: Keyboard shortcuts - 5X FASTER
    Send, {Enter}
    Sleep, 6
    Send, {Alt down}n{Alt up}
    Sleep, 6
}

; HOTKEYS
F1::
    ; Emergency close all setups
    WinGet, windows, List
    Loop, %windows%
    {
        WinID := windows%A_Index%
        WinGetTitle, WinTitle, ahk_id %WinID%
        if (InStr(WinTitle, "Setup") or InStr(WinTitle, "Install"))
        {
            WinClose, ahk_id %WinID%
        }
    }
    TrayTip, Emergency, All setup windows closed, 2, 2
return

F2::
    ; Pause/Resume
    SetTimer, MonitorSetups, Toggle
    TrayTip, Toggle, Automation toggled, 2, 1
return

F3::
    ; Force RAM dialog on current window
    WinGet, CurrentWindow, ID, A
    WinGetTitle, CurrentTitle, A
    HandleRAMLimitationDialog(CurrentWindow, CurrentTitle)
    TrayTip, Force RAM, Forced RAM dialog handling, 2, 1
return

F4::ExitApp