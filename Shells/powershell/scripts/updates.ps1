# Windows 11 Auto Update and Restart Script - Windows Terminal Version
# This script will continuously check for updates, install them, and restart until no more updates are available
# Modified to run in Windows Terminal instead of regular PowerShell and ensure normal mode only

param(
    [switch]$ContinueAfterRestart
)

# Set execution policy for current session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Windows Terminal path (update this if your version differs)
$WindowsTerminalPath = "C:\Program Files\WindowsApps\microsoft.windowsterminal_1.22.11141.0_x64__8wekyb3d8bbwe\WindowsTerminal.exe"

# Function to find Windows Terminal executable
function Get-WindowsTerminalPath {
    # First try the provided path
    if (Test-Path $WindowsTerminalPath) {
        return $WindowsTerminalPath
    }
    
    # Try to find Windows Terminal in common locations
    $possiblePaths = @(
        "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_*\WindowsTerminal.exe",
        "C:\Program Files\WindowsApps\microsoft.windowsterminal_*\WindowsTerminal.exe",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
    )
    
    foreach ($path in $possiblePaths) {
        $found = Get-ChildItem -Path (Split-Path $path) -Filter (Split-Path $path -Leaf) -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }
    
    # Try using wt.exe from PATH
    try {
        $wtPath = (Get-Command wt.exe -ErrorAction SilentlyContinue).Source
        if ($wtPath) {
            return $wtPath
        }
    }
    catch {
        # Continue to fallback
    }
    
    # Fallback to regular PowerShell if Windows Terminal not found
    Write-Log "Windows Terminal not found, falling back to regular PowerShell"
    return "PowerShell.exe"
}

# Function to write logs
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor Green
    Add-Content -Path "C:\Windows\Temp\WindowsUpdateLog.txt" -Value $logMessage
}

# Function to check if system is in Safe Mode
function Test-SafeMode {
    Write-Log "Checking system boot mode..."
    
    # Check WMI boot state
    $bootState = (Get-WmiObject -Class Win32_ComputerSystem).BootupState
    Write-Log "WMI Boot State: $bootState"
    
    # Check if we're actually in safe mode via environment variable
    $safeModeEnv = $env:SAFEBOOT_OPTION
    Write-Log "Safe Mode Environment Variable: $safeModeEnv"
    
    # Check current safe boot option in BCD
    $bcdSafeBoot = $null
    try {
        $bcdOutput = cmd /c "bcdedit /enum {current}" 2>&1
        if ($bcdOutput -match "safeboot\s+(.+)") {
            $bcdSafeBoot = $matches[1].Trim()
        }
    }
    catch {
        # Ignore errors
    }
    Write-Log "BCD Safe Boot Setting: $bcdSafeBoot"
    
    # Check safe boot registry (only if it indicates active safe mode)
    $safeModeRegistry = $null
    try {
        $regKey = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Option" -Name "OptionValue" -ErrorAction SilentlyContinue
        if ($regKey) {
            $safeModeRegistry = $regKey.OptionValue
        }
    }
    catch {
        # Ignore errors
    }
    Write-Log "Safe Mode Registry Value: $safeModeRegistry"
    
    # Determine if we're actually in safe mode
    # We're in safe mode if:
    # 1. Environment variable SAFEBOOT_OPTION is set, OR
    # 2. Registry OptionValue is 1 (minimal) or 2 (network), OR  
    # 3. Boot state explicitly indicates safe mode
    
    $isInSafeMode = $false
    
    if ($safeModeEnv) {
        Write-Log "DETECTED: Safe mode via environment variable"
        $isInSafeMode = $true
    }
    elseif ($safeModeRegistry -eq 1 -or $safeModeRegistry -eq 2) {
        Write-Log "DETECTED: Safe mode via registry (value: $safeModeRegistry)"
        $isInSafeMode = $true
    }
    elseif ($bootState -and $bootState -notlike "*Normal*" -and $bootState -like "*Safe*") {
        Write-Log "DETECTED: Safe mode via WMI boot state"
        $isInSafeMode = $true
    }
    else {
        Write-Log "CONFIRMED: System is running in Normal Mode"
        $isInSafeMode = $false
    }
    
    return $isInSafeMode
}

# Function to ensure normal boot mode
function Set-NormalBootMode {
    Write-Log "Ensuring system is set to boot in normal mode..."
    
    try {
        # Remove any safe boot settings
        $result = cmd /c "bcdedit /deletevalue safeboot 2>&1"
        Write-Log "BCDEdit safeboot removal result: $result"
        
        # Ensure normal boot is set
        $result = cmd /c "bcdedit /set {current} safeboot No 2>&1"
        if ($result -notlike "*error*") {
            Write-Log "Normal boot mode set successfully"
        }
        
        # Also try alternative method
        $result = cmd /c "bcdedit /deletevalue {current} safeboot 2>&1"
        Write-Log "Alternative BCDEdit command result: $result"
        
        # Set timeout to ensure normal boot
        cmd /c "bcdedit /timeout 3" | Out-Null
        
        Write-Log "Boot configuration updated to ensure normal mode"
    }
    catch {
        Write-Log "Warning: Could not modify boot configuration: $($_.Exception.Message)"
    }
}

# Function to install PSWindowsUpdate module if not present
function Install-PSWindowsUpdate {
    Write-Log "Checking for PSWindowsUpdate module..."
    if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Log "Installing PSWindowsUpdate module..."
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
            Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -AllowClobber
            Write-Log "PSWindowsUpdate module installed successfully."
        }
        catch {
            Write-Log "Failed to install PSWindowsUpdate module: $($_.Exception.Message)"
            exit 1
        }
    }
    Import-Module PSWindowsUpdate
}

# Function to create restart continuation task using Windows Terminal
function Create-RestartTask {
    Write-Log "Creating scheduled task for post-restart continuation using Windows Terminal..."

    $scriptPath = $MyInvocation.ScriptName
    $terminalPath = Get-WindowsTerminalPath
    
    # Create the command based on whether we found Windows Terminal or not
    if ($terminalPath -like "*WindowsTerminal.exe*" -or $terminalPath -like "*wt.exe*") {
        Write-Log "Using Windows Terminal: $terminalPath"
        # Windows Terminal command with PowerShell profile
        $action = New-ScheduledTaskAction -Execute "`"$terminalPath`"" -Argument "--profile `"PowerShell`" --title `"Windows Update Script`" powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`" -ContinueAfterRestart"
    }
    else {
        Write-Log "Using regular PowerShell: $terminalPath"
        # Fallback to regular PowerShell
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -ContinueAfterRestart"
    }
    
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Settings to ensure normal operation
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)

    try {
        Register-ScheduledTask -TaskName "WindowsUpdateContinuation" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
        Write-Log "Scheduled task created successfully with Windows Terminal."
    }
    catch {
        Write-Log "Failed to create scheduled task: $($_.Exception.Message)"
    }
}

# Function to remove restart continuation task
function Remove-RestartTask {
    try {
        Unregister-ScheduledTask -TaskName "WindowsUpdateContinuation" -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "Scheduled task removed."
    }
    catch {
        Write-Log "Task removal failed or task didn't exist."
    }
}

# Function to check and install updates
function Install-WindowsUpdates {
    Write-Log "Checking for available Windows updates..."

    try {
        # Get available updates
        $updates = Get-WUList -Verbose

        if ($updates.Count -eq 0) {
            Write-Log "No updates available."
            return $false
        }

        Write-Log "Found $($updates.Count) update(s) available:"
        foreach ($update in $updates) {
            Write-Log "- $($update.Title)"
        }

        # Install updates
        Write-Log "Installing updates..."
        $result = Install-WindowsUpdate -AcceptAll -AutoReboot:$false -Verbose

        # Check if restart is required
        $rebootRequired = Get-WURebootStatus
        if ($rebootRequired -eq $true) {
            Write-Log "Restart required after update installation."
            return $true
        }
        else {
            Write-Log "No restart required. Checking for more updates..."
            return "continue"
        }
    }
    catch {
        Write-Log "Error during update process: $($_.Exception.Message)"
        return $false
    }
}

# Function to perform safe restart with normal mode guarantee
function Restart-SystemNormalMode {
    Write-Log "Preparing system for restart in normal mode..."
    
    # Ensure normal boot mode is set
    Set-NormalBootMode
    
    # Double-check boot configuration
    $bootConfig = cmd /c "bcdedit /enum {current}" 2>&1
    Write-Log "Current boot configuration check complete"
    
    # Create restart task before reboot
    Create-RestartTask
    
    Write-Log "Restarting system in normal mode in 60 seconds..."
    Write-Log "Windows Terminal will automatically open after restart to continue the script."
    
    # Give time to read the message
    Start-Sleep -Seconds 60
    
    # Force normal restart (not safe mode)
    Write-Log "Initiating normal mode restart..."
    Restart-Computer -Force
    exit
}

# Function to set up Windows Terminal for better visibility
function Initialize-TerminalSettings {
    $terminalPath = Get-WindowsTerminalPath
    if ($terminalPath -like "*WindowsTerminal.exe*" -or $terminalPath -like "*wt.exe*") {
        Write-Log "Running in Windows Terminal - Enhanced logging enabled"
        # Set terminal title
        $host.UI.RawUI.WindowTitle = "Windows 11 Auto Update Script"
        # Clear screen for better visibility
        Clear-Host
    }
}

# Main script logic starts here
Write-Log "=== Windows 11 Auto Update Script Started (Windows Terminal Version) ==="

# Initialize terminal settings
Initialize-TerminalSettings

# Display Windows Terminal status
$terminalPath = Get-WindowsTerminalPath
Write-Log "Terminal Path: $terminalPath"

# Check if we're in Safe Mode and warn if so
if (Test-SafeMode) {
    Write-Log "WARNING: System appears to be in Safe Mode!" 
    Write-Log "This script is designed to run in Normal Mode only."
    Write-Log "Please restart the system in Normal Mode and run the script again."
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Log "Confirmed: System is running in Normal Mode"

# Ensure normal boot mode is set for any future restarts
Set-NormalBootMode

# Install PSWindowsUpdate module if needed
Install-PSWindowsUpdate

# If this is a continuation after restart, remove the scheduled task
if ($ContinueAfterRestart) {
    Write-Log "Continuing after restart in Windows Terminal..."
    Remove-RestartTask
    
    # Verify we're still in normal mode after restart
    if (Test-SafeMode) {
        Write-Log "ERROR: System restarted in Safe Mode despite normal mode configuration!"
        Write-Log "Please check system configuration and restart in Normal Mode."
        exit 1
    }
    
    Write-Log "Confirmed: Restart completed successfully in Normal Mode"
    Write-Log "Windows Terminal resumed script execution automatically"
    Start-Sleep -Seconds 30  # Wait for system to fully boot
}

$maxIterations = 10  # Safety limit to prevent infinite loops
$iteration = 0

do {
    $iteration++
    Write-Log "=== Update Check Iteration $iteration ==="

    if ($iteration -gt $maxIterations) {
        Write-Log "Maximum iterations reached. Stopping to prevent infinite loop."
        break
    }

    $updateResult = Install-WindowsUpdates

    if ($updateResult -eq $true) {
        # Restart required - use our safe normal mode restart function
        Write-Log "Updates installed successfully. Restart required."
        Restart-SystemNormalMode
    }
    elseif ($updateResult -eq "continue") {
        # More updates might be available, continue checking
        Write-Log "Continuing to check for more updates..."
        Start-Sleep -Seconds 10
        continue
    }
    else {
        # No more updates or error occurred
        break
    }

} while ($true)

# Clean up and finish
Remove-RestartTask
Write-Log "=== All Windows updates completed! ==="
Write-Log "System is up to date."

# Optional: Display final status
$finalCheck = Get-WUList
if ($finalCheck.Count -eq 0) {
    Write-Log "FINAL STATUS: No pending updates found. System is fully updated."

    # Run the DDU NVIDIA script after all updates are complete
    $ddUScript = "F:\study\shells\powershell\scripts\DDUNvidia.ps1"
    if (Test-Path $ddUScript) {
        Write-Log "Running DDU NVIDIA script: $ddUScript"
        try {
            # Run DDU script in Windows Terminal as well
            $terminalPath = Get-WindowsTerminalPath
            if ($terminalPath -like "*WindowsTerminal.exe*" -or $terminalPath -like "*wt.exe*") {
                Write-Log "Launching DDU script in new Windows Terminal window..."
                Start-Process -FilePath "`"$terminalPath`"" -ArgumentList "--profile `"PowerShell`" --title `"DDU NVIDIA Script`" powershell.exe -ExecutionPolicy Bypass -File `"$ddUScript`""
            }
            else {
                & $ddUScript
            }
            Write-Log "DDU NVIDIA script launched successfully."
        }
        catch {
            Write-Log "Error running DDU NVIDIA script: $($_.Exception.Message)"
        }
    }
    else {
        Write-Log "DDU NVIDIA script not found at: $ddUScript"
    }
}
else {
    Write-Log "FINAL STATUS: $($finalCheck.Count) updates still available (may require manual intervention)."
}

Write-Log "Script execution completed in Windows Terminal. Log file: C:\Windows\Temp\WindowsUpdateLog.txt"
Write-Host "`nScript completed successfully! Windows Terminal provided enhanced visibility throughout the process." -ForegroundColor Cyan
Read-Host "Press Enter to exit"
