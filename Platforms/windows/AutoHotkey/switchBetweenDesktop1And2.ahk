#SingleInstance Force

; Track current desktop state
currentDesktop := 1  ; Start assuming we're on desktop 1

; Desktop switcher: Shift + S toggles between Desktop 1 and Desktop 2
+s:: ; Shift + S
{
    global currentDesktop
    
    if (currentDesktop = 1) {
        ; Go from Desktop 1 to Desktop 2
        Send "^#{Right}"  ; Ctrl + Win + Right Arrow
        currentDesktop := 2
    } else {
        ; Go from Desktop 2 to Desktop 1  
        Send "^#{Left}"   ; Ctrl + Win + Left Arrow
        currentDesktop := 1
    }
}
