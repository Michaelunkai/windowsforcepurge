#Persistent
SetTitleMatchMode, 2
CoordMode, Mouse, Screen
targetDrive := "F:\Games"

; Auto-install folder handler
Loop {
    WinWaitActive, Setup
    Sleep, 500

    ; Extract game name from title
    WinGetTitle, fullTitle, A
    RegExMatch(fullTitle, "Setup\s*-\s*(.*)", m)
    gameName := Trim(m1)
    gameName := RegExReplace(gameName, "[\s<>:""/|?*]", "")
    if (gameName = "")
        gameName := "UnknownGame_" . A_Now
    fullPath := targetDrive . "\" . gameName

    ; Click Browse and set path
    ControlClick, Button2, Setup
    Sleep, 600
    Send, ^a
    Sleep, 150
    Send, %fullPath%
    Sleep, 400
    Send, {Enter}
    Sleep, 700

    ; Click Next
    ControlClick, Button1, Setup
    Sleep, 1000

    ; Wait for component selection screen and uncheck all boxes
    WinWaitActive, Setup
    Sleep, 500

    ; Check if we're at the component selection screen
    ControlGetText, buttonText, Button1, Setup
    if (buttonText = "Install" or buttonText = "&Install") {
        ; We're at the component selection screen, uncheck all boxes
        UncheckAllComponents()
        Sleep, 500

        ; Now click Install to continue
        ControlClick, Button1, Setup
        break
    }
}

; Function to uncheck all component checkboxes
UncheckAllComponents() {
    ; Get all controls in the window
    WinGet, controlList, ControlList, Setup

    ; Loop through all controls looking for checkboxes
    Loop, Parse, controlList, n
    {
        currentControl := A_LoopField

        ; Check if it's a checkbox control (Button class with BS_CHECKBOX style)
        ControlGet, controlStyle, Style,, %currentControl%, Setup

        ; Check if it's checked (state = 1 means checked)
        ControlGet, checkState, Checked,, %currentControl%, Setup

        ; If it's a checkbox and it's checked, uncheck it
        if (checkState = 1) {
            ControlClick, %currentControl%, Setup
            Sleep, 100
        }
    }

    ; Alternative method using specific control names if the above doesn't work
    ; Try common checkbox control names
    checkboxControls := ["Button2", "Button3", "Button4", "Button5", "Button6", "Button7", "Button8", "Button9", "Button10"]

    for index, controlName in checkboxControls {
        ControlGet, exists, Visible,, %controlName%, Setup
        if (exists) {
            ControlGet, checkState, Checked,, %controlName%, Setup
            if (checkState = 1) {
                ControlClick, %controlName%, Setup
                Sleep, 100
            }
        }
    }

    ; Final method using coordinates if control names don't work
    ; Based on typical checkbox positions in installer dialogs
    checkboxX := 104
    checkboxYPositions := [334, 364, 394, 424, 454]

    Loop % checkboxYPositions.MaxIndex() {
        yPos := checkboxYPositions[A_Index]
        ; Click to uncheck if it appears to be checked
        Click, %checkboxX%, %yPos%
        Sleep, 100
    }
}

; --- Timers ---
SetTimer, BlockExitConfirmation, 200
SetTimer, AutoCloseVerifier, 300
SetTimer, CancelDirectX, 300
SetTimer, CloseVCpp, 300
return

; --- Block "Exit Setup?" popup ---
BlockExitConfirmation:
WinGetTitle, exitTitle, A
if (exitTitle ~= "Exit Setup") {
    ControlClick, Button2, %exitTitle%  ; "No"
    Sleep, 300
}
return

; --- Close "Finished" file checkers ---
AutoCloseVerifier:
WinGetTitle, finishTitle, A
if (finishTitle ~= "Finished" and WinExist("A")) {
    WinClose, A
    Sleep, 300
}
return

; --- Cancel DirectX setup ---
CancelDirectX:
WinGetTitle, dxTitle, A
if (dxTitle ~= "DirectX" and dxTitle ~= "Installing Microsoft") {
    ControlClick, Button3, %dxTitle%  ; "Cancel"
    Sleep, 300
}
return

; --- Close Microsoft Visual C++ Redistributable windows ---
CloseVCpp:
WinGetTitle, cppTitle, A
if (cppTitle ~= "Microsoft Visual C\+\+" or cppTitle ~= "Redistributable") {
    ControlClick, Button2, %cppTitle%  ; "Close"
    Sleep, 300
}
return
