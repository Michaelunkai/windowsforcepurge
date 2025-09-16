; ───────────── CONFIG ──────────────────────────────────────────────────────────
#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir "F:\backup\windowsapps\installed\PSTools"
psSuspend := A_WorkingDir "\pssuspend64.exe"          ; full path to PsSuspend64

; ───────────── GLOBAL STATE ────────────────────────────────────────────────────
global suspended := Map()                             ; tracks suspended EXEs
global skipMap  := Map(                               ; NEVER suspend these
    "MultiSuspend.exe", 1,
    "MultiSuspend.ahk", 1,
    "a.exe", 1,
    "a.ahk", 1
)

; ───────────── HELPERS ─────────────────────────────────────────────────────────
GetActiveProcess() {
    try {
        pid := WinGetPID("A")
        return ProcessGetName(pid)                    ; e.g. "notepad.exe"
    } catch {
        return ""
    }
}

SuspendProcess(proc) {
    global psSuspend
    RunWait(psSuspend ' "' proc '"', , "Hide")
}

ResumeProcess(proc) {
    global psSuspend
    RunWait(psSuspend ' -r "' proc '"', , "Hide")
}

; ───────────── HOTKEYS ─────────────────────────────────────────────────────────
F1:: {                                             ; Ctrl + Z → suspend
    global skipMap, suspended
    proc := GetActiveProcess()
    if (proc = "" || skipMap.Has(proc))
        return

    if suspended.Has(proc) {
        TrayTip "Already Suspended", "<" proc "> is already suspended!", 0x1
        return
    }
    SuspendProcess(proc)
    suspended[proc] := true
    TrayTip "Suspended", "<" proc "> suspended!", 0x1
}

F2:: {                                             ; Ctrl + R → resume focused
    global suspended
    proc := GetActiveProcess()
    if !suspended.Has(proc) {
        TrayTip "Not Suspended", "<" proc "> isn't suspended.", 0x1
        return
    }
    ResumeProcess(proc)
    suspended.Delete(proc)
    TrayTip "Resumed", "<" proc "> resumed!", 0x1
}

F3:: {                                             ; Ctrl + D → resume **all**
    global suspended
    for proc in suspended {
        ResumeProcess(proc)
        TrayTip "Resumed", "<" proc "> resumed!", 0x1
        Sleep 250                                   ; brief delay between tips
    }
    suspended := Map()                              ; clear tracking map
}
