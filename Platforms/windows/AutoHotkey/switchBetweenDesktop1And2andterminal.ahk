#SingleInstance Force
SendMode("Input")
SetWorkingDir(A_ScriptDir)

; Track current desktop state
currentDesktop := 1  ; Start assuming we're on desktop 1

; Desktop switcher: Shift + S toggles between Desktop 1 and Desktop 2
+s:: ; Shift + S
{
    global currentDesktop
    if (currentDesktop = 1) {
        ; Go from Desktop 1 to Desktop 2
        Send("^#{Right}")  ; Ctrl + Win + Right Arrow
        currentDesktop := 2
    } else {
        ; Go from Desktop 2 to Desktop 1
        Send("^#{Left}")   ; Ctrl + Win + Left Arrow
        currentDesktop := 1
    }
}

; Open terminal above all other apps: Space + T
Space & t::
{
    ; Try to open Windows Terminal first, fallback to PowerShell, then CMD
    try {
        Run("wt.exe")
        Sleep(500)  ; Wait for window to appear
        if WinWait("ahk_exe WindowsTerminal.exe", , 2) {
            WinActivate("ahk_exe WindowsTerminal.exe")
            WinSetAlwaysOnTop(true, "ahk_exe WindowsTerminal.exe")
        }
    } catch {
        try {
            Run("powershell.exe")
            Sleep(500)
            if WinWait("ahk_exe powershell.exe", , 2) {
                WinActivate("ahk_exe powershell.exe")
                WinSetAlwaysOnTop(true, "ahk_exe powershell.exe")
            }
        } catch {
            Run("cmd.exe")
            Sleep(500)
            if WinWait("ahk_exe cmd.exe", , 2) {
                WinActivate("ahk_exe cmd.exe")
                WinSetAlwaysOnTop(true, "ahk_exe cmd.exe")
            }
        }
    }
}

; Exit current terminal: Space + R
Space & r::
{
    ; Get the active window
    activeTitle := WinGetTitle("A")
    activeProcess := WinGetProcessName("A")
    
    ; Check if current window is a terminal application
    if (activeProcess = "WindowsTerminal.exe" 
        || activeProcess = "powershell.exe" 
        || activeProcess = "cmd.exe"
        || activeProcess = "pwsh.exe"
        || InStr(activeTitle, "Command Prompt")
        || InStr(activeTitle, "PowerShell")
        || InStr(activeTitle, "Windows Terminal")) {
        
        ; Remove always on top before closing
        WinSetAlwaysOnTop(false, "A")
        
        ; Close the terminal
        WinClose("A")
    } else {
        ; If not a terminal, show a brief tooltip
        ToolTip("Not a terminal window")
        SetTimer(RemoveToolTip, -1000)
    }
}

; Helper function to remove tooltip
RemoveToolTip() {
    ToolTip()
}

; Prevent Space key from being sent when used with modifiers
Space::
{
    if (A_PriorHotkey = "Space & t" && A_TimeSinceThisHotkey < 200)
        return
    if (A_PriorHotkey = "Space & r" && A_TimeSinceThisHotkey < 200)
        return
    Send("{Space}")
}
