#SingleInstance Force
#NoEnv
SetWorkingDir %A_ScriptDir%
SendMode Input
SetTitleMatchMode, 2

; Path to Macro Creator
MacroCreatorPath := "F:\backup\windowsapps\installed\MacroCreator\MacroCreator.exe"

; Run Macro Creator
Run, %MacroCreatorPath%

; Wait for the application to start
WinWait, Macro Creator ahk_exe MacroCreator.exe,, 10
if ErrorLevel
{
    MsgBox, Failed to open Macro Creator. Please check the path.
    ExitApp
}

; Ensure the window is active
WinActivate, Macro Creator ahk_exe MacroCreator.exe

; Wait briefly for the UI to fully load
Sleep, 1000

; Press the "Macro" menu
Send, !m
Sleep, 500

; Select "Record Macro" option
Send, r
Sleep, 300

; Script is now complete - Macro Creator should be open with the record dialog

ExitApp
