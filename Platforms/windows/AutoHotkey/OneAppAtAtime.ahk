#NoEnv
#SingleInstance Force
SetTitleMatchMode, 2
SetWorkingDir, F:\backup\windowsapps\installed\PSTools
psSuspend := "F:\backup\windowsapps\installed\PSTools\pssuspend64.exe"

GetActiveProcessName() {
    WinGet, pid, PID, A
    Process, Exist, %pid%
    WinGet, exe, ProcessName, ahk_pid %pid%
    return exe
}

global suspended := false
global targetProcess := ""

^s:: ; Ctrl+S to suspend
{
    if !suspended {
        targetProcess := GetActiveProcessName()
        if (targetProcess != "") {
            RunWait, %ComSpec% /c "%psSuspend% %targetProcess%", , Hide
            suspended := true
            TrayTip, Suspended, % "Suspended: " targetProcess, 1
        }
    }
    return
}

^r:: ; Ctrl+R to resume
{
    if suspended && (targetProcess != "") {
        RunWait, %ComSpec% /c "%psSuspend% -r %targetProcess%", , Hide
        TrayTip, Resumed, % "Resumed: " targetProcess, 1
        suspended := false
        targetProcess := ""
    }
    return
}

