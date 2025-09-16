; === a.ahk - ULTRA FAST Game Setup Automation (5X FASTER) ===
; AUTOHOTKEY SCRIPT - Handles RAM limitation dialog and all setup steps
; ALL DELAYS REDUCED BY 5X: 50ms→10ms, 30ms→6ms, 20ms→4ms
; MONITORING SPEED: 100ms→50ms for instant response

#NoEnv
#SingleInstance Force
#Persistent
SendMode Input
SetWorkingDir %A_ScriptDir%
CoordMode, Mouse, Screen

; === 5X FASTER SETTINGS ===
SetBatchLines, -1                ; Run at maximum speed
SetKeyDelay, -1, -1             ; FASTEST possible keystrokes  
SetMouseDelay, -1               ; FASTEST possible mouse actions
SetControlDelay, -1             ; FASTEST possible control commands
SetWinDelay, -1                 ; FASTEST possible window commands
SetDefaultMouseSpeed, 0         ; Instant mouse movement

; Global variables
RAMDialogHandled := {}          ; Track which windows we've handled RAM dialog for
SetupWindows := {}              ; Track all setup windows
CheckInterval := 50             ; Check every 50ms for MAXIMUM responsiveness (5X faster)

; Start monitoring immediately
SetTimer, MonitorSetups, %CheckInterval%

; Show startup message
OutputDebug, [AHK] Ultra Fast Setup Automation Started - 5X Speed Mode
return

MonitorSetups:
    ; Get all setup windows
    WinGet, windows, List
    
    Loop, %windows%
    {
        WinID := windows%A_Index%
        WinGetTitle, WinTitle, ahk_id %WinID%
        WinGetClass, WinClass, ahk_id %WinID%
        
        ; Check if it's a setup/installer window
        if (InStr(WinTitle, "Setup") or InStr(WinTitle, "Install") or InStr(WinTitle, "Wizard") or WinClass = "#32770")
        {
            ; Make sure window is active and visible
            WinActivate, ahk_id %WinID%
            WinWaitActive, ahk_id %WinID%, , 1
            
            ; Handle RAM limitation dialog FIRST (highest priority)
            HandleRAMLimitationDialog(WinID, WinTitle)
            
            ; Then handle other setup steps
            HandleSetupWindow(WinID, WinTitle)
        }
    }
return

HandleRAMLimitationDialog(WinID, WinTitle)
{
    ; Skip if we've already handled RAM dialog for this window
    if (RAMDialogHandled[WinID])
        return
        
    WinActivate, ahk_id %WinID%
    
    ; Look for RAM limitation dialog text patterns
    RAMTexts := ["limit RAM", "RAM to 2", "2 gigabytes", "memory limit", "2GB", "2048", "limit memory"]
    
    Loop, 7  ; Loop through RAMTexts array
    {
        SearchText := RAMTexts[A_Index]
        ControlGet, DialogText, List, , Edit1, ahk_id %WinID%
        WinGetText, WindowText, ahk_id %WinID%
        
        if (InStr(WindowText, SearchText) or InStr(DialogText, SearchText))
        {
            ; Found RAM limitation dialog - handle it immediately
            HandleRAMDialog(WinID, WinTitle)
            RAMDialogHandled[WinID] := true
            OutputDebug, [RAM] Dialog detected and handled for: %WinTitle%
            return
        }
    }
}

HandleRAMDialog(WinID, WinTitle)
{
    WinActivate, ahk_id %WinID%
    
    ; Multiple strategies to find and check the RAM limitation checkbox
    
    ; Strategy 1: Look for checkbox controls
    Loop, 10 
    {
        ControlGetText, ButtonText, Button%A_Index%, ahk_id %WinID%
        if (InStr(ButtonText, "2") and (InStr(ButtonText, "GB") or InStr(ButtonText, "gigabyte")))
        {
            ; Found the RAM checkbox - check it immediately
            Control, Check, , Button%A_Index%, ahk_id %WinID%
            Sleep, 10  ; 5X faster (was 50ms)
            OutputDebug, [RAM] Checkbox found and checked: Button%A_Index%
            break
        }
    }
    
    ; Strategy 2: Click at common checkbox positions for RAM dialogs
    CheckboxPositions := "150,200|120,250|180,180|200,220"
    StringSplit, PosArray, CheckboxPositions, |
    Loop, %PosArray0%
    {
        StringSplit, Coords, PosArray%A_Index%, `,
        Click, %Coords1%, %Coords2%
        Sleep, 6  ; 5X faster (was 30ms)
    }
    
    ; Strategy 3: Use keyboard to check checkbox
    Send, {Tab}{Tab}{Space}
    Sleep, 10  ; 5X faster (was 50ms)
    Send, {Tab}{Space}
    Sleep, 10  ; 5X faster (was 50ms)
    
    ; Now click Next/OK/Continue buttons immediately
    ClickNextButtons(WinID)
    
    ; Log the action
    OutputDebug, [RAM] Handled RAM limitation dialog for: %WinTitle%
}

HandleSetupWindow(WinID, WinTitle)
{
    WinActivate, ahk_id %WinID%
    
    ; Ultra-fast setup automation
    
    ; 1. Handle common dialogs instantly
    HandleCommonDialogs(WinID, WinTitle)
    
    ; 2. Auto-click Next/Continue/Install buttons
    ClickNextButtons(WinID)
    
    ; 3. Handle license agreements
    HandleLicenseAgreement(WinID)
    
    ; 4. Handle installation path
    HandleInstallPath(WinID)
    
    ; 5. Handle component selection  
    HandleComponentSelection(WinID)
    
    ; 6. Handle final installation
    HandleFinalInstall(WinID)
}

HandleCommonDialogs(WinID, WinTitle)
{
    WinGetText, WindowText, ahk_id %WinID%
    
    ; Handle various common dialogs instantly
    if (InStr(WindowText, "license") or InStr(WindowText, "agreement") or InStr(WindowText, "terms"))
    {
        CheckLicenseAndNext(WinID)
    }
    else if (InStr(WindowText, "welcome"))
    {
        ClickNext(WinID)
    }
    else if (InStr(WindowText, "directory") or InStr(WindowText, "folder"))
    {
        ClickNext(WinID)
    }
    else if (InStr(WindowText, "components"))
    {
        ClickNext(WinID)
    }
    else if (InStr(WindowText, "ready") or InStr(WindowText, "install now"))
    {
        ClickInstall(WinID)
    }
    else if (InStr(WindowText, "finish") or InStr(WindowText, "complete"))
    {
        ClickFinish(WinID)
    }
}

CheckLicenseAndNext(WinID)
{
    ; Check license agreement checkbox and click next
    Loop, 5
    {
        ControlClick, Button%A_Index%, ahk_id %WinID%, , LEFT, 1, 0, 0
        Sleep, 6  ; 5X faster (was 30ms)
    }
    ClickNextButtons(WinID)
}

ClickNext(WinID)
{
    ClickNextButtons(WinID)
}

ClickInstall(WinID) 
{
    ; Click Install/Start buttons
    InstallButtons := "&Install|Install|&Start|Start|Begin"
    StringSplit, ButtonArray, InstallButtons, |
    Loop, %ButtonArray0%
    {
        ControlClick, %ButtonArray%A_Index%%, ahk_id %WinID%, , LEFT, 1, 0, 0
        Sleep, 6  ; 5X faster (was 30ms)
    }
}

ClickFinish(WinID)
{
    ; Click Finish/Complete buttons  
    FinishButtons := "&Finish|Finish|&Complete|Complete|&Close|Close"
    StringSplit, ButtonArray, FinishButtons, |
    Loop, %ButtonArray0%
    {
        ControlClick, %ButtonArray%A_Index%%, ahk_id %WinID%, , LEFT, 1, 0, 0
        Sleep, 6  ; 5X faster (was 30ms)
    }
}

ClickNextButtons(WinID)
{
    ; Try multiple methods to click Next/Continue/OK buttons at 5X speed
    
    ; Method 1: Control click by text
    NextButtons := "&Next|Next >|Next|&Continue|Continue|&OK|OK|Proceed"
    StringSplit, ButtonArray, NextButtons, |
    Loop, %ButtonArray0%
    {
        ButtonText := ButtonArray%A_Index%
        ControlClick, %ButtonText%, ahk_id %WinID%, , LEFT, 1, 0, 0
        Sleep, 4  ; 5X faster (was 20ms)
    }
    
    ; Method 2: Click by button control
    Loop, 10
    {
        ControlGetText, ButtonText, Button%A_Index%, ahk_id %WinID%
        if (InStr(ButtonText, "Next") or InStr(ButtonText, "Continue") or InStr(ButtonText, "OK"))
        {
            ControlClick, Button%A_Index%, ahk_id %WinID%, , LEFT, 1, 0, 0
            Sleep, 6  ; 5X faster (was 30ms)
            break
        }
    }
    
    ; Method 3: Keyboard shortcuts
    Send, {Enter}
    Sleep, 6  ; 5X faster (was 30ms)
    Send, {Alt down}n{Alt up}
    Sleep, 6  ; 5X faster (was 30ms)
}

HandleLicenseAgreement(WinID)
{
    ; Look for and accept license agreements
    WinGetText, WindowText, ahk_id %WinID%
    
    if (InStr(WindowText, "license") or InStr(WindowText, "agreement"))
    {
        ; Try to find and check acceptance checkbox
        Loop, 8
        {
            ControlGetText, ButtonText, Button%A_Index%, ahk_id %WinID%
            if (InStr(ButtonText, "accept") or InStr(ButtonText, "agree"))
            {
                Control, Check, , Button%A_Index%, ahk_id %WinID%
                Sleep, 6  ; 5X faster (was 30ms)
                break
            }
        }
        ClickNextButtons(WinID)
    }
}

HandleInstallPath(WinID)
{
    ; Handle installation directory - just use default and continue
    WinGetText, WindowText, ahk_id %WinID%
    
    if (InStr(WindowText, "directory") or InStr(WindowText, "folder") or InStr(WindowText, "path"))
    {
        ; Accept default path and continue
        ClickNextButtons(WinID)
    }
}

HandleComponentSelection(WinID)
{
    ; Handle component/feature selection - select all and continue
    WinGetText, WindowText, ahk_id %WinID%
    
    if (InStr(WindowText, "component") or InStr(WindowText, "feature") or InStr(WindowText, "custom"))
    {
        ; Select all components (default usually) and continue
        ClickNextButtons(WinID)
    }
}

HandleFinalInstall(WinID)
{
    ; Handle final installation step
    WinGetText, WindowText, ahk_id %WinID%
    
    if (InStr(WindowText, "ready") or InStr(WindowText, "install now") or InStr(WindowText, "begin"))
    {
        ClickInstall(WinID)
    }
    
    if (InStr(WindowText, "complete") or InStr(WindowText, "finish") or InStr(WindowText, "done"))
    {
        ClickFinish(WinID)
    }
}

; === HOTKEYS FOR MANUAL CONTROL ===
F1::
    ; Emergency: Close all setup windows
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
    OutputDebug, [Manual] Emergency close all setups activated
return

F2::
    ; Pause/Resume automation
    SetTimer, MonitorSetups, Toggle
    OutputDebug, [Manual] Automation toggled
return

F3::
    ; Force handle RAM dialog on current window
    WinGet, CurrentWindow, ID, A
    WinGetTitle, CurrentTitle, A
    HandleRAMLimitationDialog(CurrentWindow, CurrentTitle)
    OutputDebug, [Manual] Force RAM dialog handling on current window
return

; Exit hotkey
F4::ExitApp