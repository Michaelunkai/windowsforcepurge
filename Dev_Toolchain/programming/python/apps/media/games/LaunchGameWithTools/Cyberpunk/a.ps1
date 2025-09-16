# Launch Gaming Applications with Virtual Desktop via Windows API
# Works on Windows 10 and 11 without requiring VirtualDesktop module

param(
    [string]$OpenSpeedy = "F:\backup\windowsapps\installed\openspeedy\OpenSpeedy.exe",
    [string]$CyberpunkGame = "C:\Users\micha\Desktop\games\Cyberpunk2077.lnk", 
    [string]$WeMod = "C:\Users\micha\AppData\Local\WeMod\app-11.0.2\WeMod.exe"
)

try {
    # Add Windows API types for virtual desktop management
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class VirtualDesktopAPI
{
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll", SetLastError = true)]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, uint dwExtraInfo);
    
    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();
    
    public const int SW_MINIMIZE = 6;
    public const byte VK_LWIN = 0x5B;
    public const byte VK_TAB = 0x09;
    public const byte VK_D = 0x44;
    public const uint KEYEVENTF_KEYUP = 0x02;
}
"@

    Write-Host "Creating new virtual desktop using keyboard shortcut..."
    
    # Use Win+Ctrl+D to create new virtual desktop (built-in Windows shortcut)
    [VirtualDesktopAPI]::keybd_event([VirtualDesktopAPI]::VK_LWIN, 0, 0, 0) # Win key down
    [VirtualDesktopAPI]::keybd_event(0x11, 0, 0, 0) # Ctrl key down  
    [VirtualDesktopAPI]::keybd_event([VirtualDesktopAPI]::VK_D, 0, 0, 0) # D key down
    [VirtualDesktopAPI]::keybd_event([VirtualDesktopAPI]::VK_D, 0, [VirtualDesktopAPI]::KEYEVENTF_KEYUP, 0) # D key up
    [VirtualDesktopAPI]::keybd_event(0x11, 0, [VirtualDesktopAPI]::KEYEVENTF_KEYUP, 0) # Ctrl key up
    [VirtualDesktopAPI]::keybd_event([VirtualDesktopAPI]::VK_LWIN, 0, [VirtualDesktopAPI]::KEYEVENTF_KEYUP, 0) # Win key up
    
    Start-Sleep -Seconds 3
    
    Write-Host "Launching gaming applications on new desktop..."
    
    # Launch OpenSpeedy first
    Write-Host "Starting: $OpenSpeedy"
    Start-Process $OpenSpeedy
    Start-Sleep -Seconds 5
    
    # Send Win+D to show desktop
    Write-Host "Sending Win+D to show desktop..."
    [VirtualDesktopAPI]::keybd_event([VirtualDesktopAPI]::VK_LWIN, 0, 0, 0) # Win key down
    [VirtualDesktopAPI]::keybd_event([VirtualDesktopAPI]::VK_D, 0, 0, 0) # D key down  
    [VirtualDesktopAPI]::keybd_event([VirtualDesktopAPI]::VK_D, 0, [VirtualDesktopAPI]::KEYEVENTF_KEYUP, 0) # D key up
    [VirtualDesktopAPI]::keybd_event([VirtualDesktopAPI]::VK_LWIN, 0, [VirtualDesktopAPI]::KEYEVENTF_KEYUP, 0) # Win key up
    Start-Sleep -Seconds 1
    
    # Launch Cyberpunk game
    Write-Host "Starting: $CyberpunkGame"
    Start-Process $CyberpunkGame
    Start-Sleep -Seconds 10
    
    # Launch WeMod
    Write-Host "Starting: $WeMod"
    Start-Process $WeMod
    Start-Sleep -Seconds 2
    
    Write-Host "All gaming applications launched successfully on new virtual desktop!"
    Write-Host "Sequence: New Desktop -> OpenSpeedy -> Win+D -> Cyberpunk 2077 -> WeMod"
    Write-Host "Use Win+Ctrl+Left/Right arrows to switch between virtual desktops"
    
} catch {
    Write-Error "Error occurred: $($_.Exception.Message)"
    Write-Host "Try running PowerShell as Administrator for better compatibility"
    exit 1
}
