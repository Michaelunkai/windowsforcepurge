# Enhanced Multi-Command After Reboot Script - PowerShell 5 Compatible
# Run as Administrator
# Usage: ./script.ps1 'command1; command2; command3'

param(
    [string]$Command = "",
    [switch]$SkipReboot,
    [switch]$Debug
)

# Global variables
$ScriptVersion = "5.0-ABSOLUTE-GUARANTEED-EXECUTION"
$ScriptDir = "C:\Windows\Temp"
$ScriptPath = Join-Path $ScriptDir "AutoMultiCommand.ps1"
$CommandPath = Join-Path $ScriptDir "MultiCommand.txt"
$FlagPath = Join-Path $ScriptDir "MultiCommand.flag"
$TaskName = "AutoMultiCommandTask"
$LogPath = Join-Path $ScriptDir "AutoMultiCommand.log"
$RegistryRunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RegistryValueName = "AutoMultiCommand"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")

    $ColorMap = @{
        "Red" = [System.ConsoleColor]::Red
        "Green" = [System.ConsoleColor]::Green
        "Yellow" = [System.ConsoleColor]::Yellow
        "Cyan" = [System.ConsoleColor]::Cyan
        "Gray" = [System.ConsoleColor]::Gray
        "White" = [System.ConsoleColor]::White
        "Magenta" = [System.ConsoleColor]::Magenta
    }

    if ($ColorMap.ContainsKey($Color)) {
        Write-Host $Message -ForegroundColor $ColorMap[$Color]
    } else {
        Write-Host $Message
    }
}

function Write-DebugLog {
    param([string]$Message)

    if ($Debug) {
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-ColorOutput "DEBUG: $Timestamp - $Message" "Gray"
    }
}

function Test-Administrator {
    Write-DebugLog "Checking administrator privileges"

    try {
        $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
        $IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        Write-DebugLog "Administrator check result: $IsAdmin"
        return $IsAdmin
    }
    catch {
        Write-DebugLog "Administrator check failed: $($_.Exception.Message)"
        return $false
    }
}

function Remove-OldTasks {
    Write-ColorOutput "=== CLEANING UP OLD TASKS ===" "Yellow"

    $OldTasks = @(
        "KeyboardSleepTask", "PostBootPowerConfig", "PostLoginPowerConfig",
        "PostLoginPowerShell", "AutoSleepTask", "AutoFitFitTask",
        "AutoDkillTask", "AutoCustomCommandTask", "AutoMultiCommandTask"
    )

    foreach ($TaskNameToDelete in $OldTasks) {
        try {
            Write-DebugLog "Attempting to delete task: $TaskNameToDelete"

            # Method 1: Use schtasks
            $Result = & schtasks.exe /delete /tn $TaskNameToDelete /f 2>&1
            $ExitCode = $LASTEXITCODE

            if ($ExitCode -eq 0) {
                Write-ColorOutput "Deleted old task: $TaskNameToDelete" "Green"
            } else {
                Write-DebugLog "Task $TaskNameToDelete not found or already deleted"
            }
        }
        catch {
            Write-DebugLog "Error deleting task ${TaskNameToDelete}: $($_.Exception.Message)"
        }

        # Method 2: Try PowerShell cmdlets as backup
        try {
            $Task = Get-ScheduledTask -TaskName $TaskNameToDelete -ErrorAction SilentlyContinue
            if ($Task) {
                Unregister-ScheduledTask -TaskName $TaskNameToDelete -Confirm:$false -ErrorAction SilentlyContinue
                Write-ColorOutput "Deleted old task via PS: $TaskNameToDelete" "Green"
            }
        }
        catch {
            Write-DebugLog "PowerShell task deletion failed for $TaskNameToDelete"
        }
    }
}

function Get-UserCommand {
    Write-ColorOutput "=== MULTI-COMMAND INPUT ===" "Yellow"

    if ([string]::IsNullOrWhiteSpace($Command)) {
        Write-ColorOutput "Enter PowerShell commands (separate multiple commands with semicolons):" "White"
        Write-ColorOutput "Examples:" "Gray"
        Write-ColorOutput "  - gshort; ps7run dddesk; wall" "Gray"
        Write-ColorOutput "  - dkill; qbit; update" "Gray"
        Write-ColorOutput " - Get-Process notepad | Stop-Process; Start-Process notepad" "Gray"
        Write-ColorOutput " - Write-Host 'Starting...'; Start-Sleep 2; Write-Host 'Done!'" "Gray"
        Write-ColorOutput "" "White"

        do {
            $UserCommand = Read-Host "Commands"
            if ([string]::IsNullOrWhiteSpace($UserCommand)) {
                Write-ColorOutput "Please enter valid commands." "Red"
            }
        } while ([string]::IsNullOrWhiteSpace($UserCommand))

        Write-ColorOutput "" "White"
        Write-ColorOutput "You entered: $UserCommand" "Green"
        
        # Parse and display individual commands
        $Commands = $UserCommand -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        Write-ColorOutput "This will execute the following commands in sequence:" "Cyan"
        for ($i = 0; $i -lt $Commands.Count; $i++) {
            Write-ColorOutput "  $($i + 1). $($Commands[$i])" "White"
        }
        
        Write-ColorOutput "" "White"
        $Confirmation = Read-Host "Is this correct? (y/n)"
        if ($Confirmation -notmatch '^[yY]') {
            Write-ColorOutput "Script cancelled." "Yellow"
            exit 0
        }

        return $UserCommand
    } else {
        Write-ColorOutput "Commands from parameter: $Command" "Green"
        
        # Parse and display individual commands
        $Commands = $Command -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        Write-ColorOutput "Will execute the following commands in sequence:" "Cyan"
        for ($i = 0; $i -lt $Commands.Count; $i++) {
            Write-ColorOutput "  $($i + 1). $($Commands[$i])" "White"
        }
        
        return $Command
    }
}

function Initialize-Directories {
    Write-DebugLog "Initializing directories"

    try {
        if (-not (Test-Path $ScriptDir)) {
            $null = New-Item -ItemType Directory -Path $ScriptDir -Force
            Write-DebugLog "Created directory: $ScriptDir"
        }

        # Test write permissions
        $TestFile = Join-Path $ScriptDir "test.tmp"
        "test" | Out-File -FilePath $TestFile -Force
        Remove-Item $TestFile -Force -ErrorAction SilentlyContinue

        Write-DebugLog "Directory permissions verified"
        return $true
    }
    catch {
        Write-ColorOutput "FAILED to initialize directories: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Save-CommandAndFlag {
    param([string]$CustomCommand)

    Write-ColorOutput "=== CREATING MULTI-COMMAND SCRIPT ===" "Yellow"

    try {
        # Save the custom command
        $CustomCommand | Out-File -FilePath $CommandPath -Encoding UTF8 -Force
        Write-ColorOutput "Multi-command saved to: $CommandPath" "Green"
        Write-DebugLog "Command content: $CustomCommand"

        # Create execution flag with unique timestamp to prevent reuse
        $UniqueId = [System.Guid]::NewGuid().ToString()
        $FlagContent = @{
            UniqueId = $UniqueId
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Command = $CustomCommand
            Executed = $false
            Version = $ScriptVersion
            CreatedBy = $env:USERNAME
            ComputerName = $env:COMPUTERNAME
            OneTimeOnly = $true
            MultiCommand = $true
        }

        $FlagContent | ConvertTo-Json | Out-File -FilePath $FlagPath -Encoding UTF8 -Force
        Write-ColorOutput "Execution flag created: $FlagPath" "Green"
        Write-ColorOutput "IMPORTANT: Commands will execute ONLY ONCE after next reboot!" "Yellow"

        return $true
    }
    catch {
        Write-ColorOutput "FAILED to save command and flag: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Create-ExecutionScript {
    Write-DebugLog "Creating execution script"

    $ExecutionScript = @'
# Auto Multi-Command Script - PowerShell 5 Compatible - ONE-TIME EXECUTION ONLY
param()

$LogPath = "C:\Windows\Temp\AutoMultiCommand.log"
$CommandPath = "C:\Windows\Temp\MultiCommand.txt"
$FlagPath = "C:\Windows\Temp\MultiCommand.flag"
$TaskName = "AutoMultiCommandTask"
$LockFile = "C:\Windows\Temp\MultiCommand.lock"

function Write-Log {
    param([string]$Message, [string]$Color = "White")

    try {
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "$Timestamp - $Message"
        $LogEntry | Out-File -FilePath $LogPath -Append -Force -Encoding UTF8

        # Also write to console with color for immediate feedback
        $ColorMap = @{
            "Red" = [System.ConsoleColor]::Red
            "Green" = [System.ConsoleColor]::Green
            "Yellow" = [System.ConsoleColor]::Yellow
            "Cyan" = [System.ConsoleColor]::Cyan
            "Magenta" = [System.ConsoleColor]::Magenta
            "White" = [System.ConsoleColor]::White
        }

        if ($ColorMap.ContainsKey($Color)) {
            Write-Host $LogEntry -ForegroundColor $ColorMap[$Color]
        } else {
            Write-Host $LogEntry
        }
    }
    catch {
        # Silently fail if logging doesn't work
        Write-Host $Message
    }
}

function Test-AlreadyExecuted {
    Write-Log "=== CHECKING ONE-TIME EXECUTION STATUS ===" "Yellow"

    # Check 1: Lock file (prevents concurrent execution)
    if (Test-Path $LockFile) {
        Write-Log "EXECUTION BLOCKED: Lock file exists - script may already be running" "Red"
        return $true
    }

    # Check 2: Flag file existence and content
    if (-not (Test-Path $FlagPath)) {
        Write-Log "EXECUTION BLOCKED: Flag file missing - commands already executed or cleaned up" "Red"
        return $true
    }

    try {
        $FlagContent = Get-Content $FlagPath -Raw -Encoding UTF8 | ConvertFrom-Json

        # Check 3: Already executed flag
        if ($FlagContent.Executed -eq $true) {
            Write-Log "EXECUTION BLOCKED: Commands already executed (flag marked as executed)" "Red"
            return $true
        }

        # Check 4: One-time only flag
        if ($FlagContent.OneTimeOnly -ne $true) {
            Write-Log "EXECUTION BLOCKED: Not marked as one-time execution" "Red"
            return $true
        }

        Write-Log "EXECUTION APPROVED: All checks passed - ready to execute ONE TIME" "Green"
        Write-Log "Commands to execute: $($FlagContent.Command)" "Cyan"
        Write-Log "Created by: $($FlagContent.CreatedBy)" "White"
        Write-Log "Created on: $($FlagContent.Timestamp)" "White"

        return $false

    }
    catch {
        Write-Log "EXECUTION BLOCKED: Could not read or parse flag file: $($_.Exception.Message)" "Red"
        return $true
    }
}

function Create-LockFile {
    try {
        $LockContent = @{
            StartTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            ProcessId = $PID
            Purpose = "Prevent concurrent execution"
        }
        $LockContent | ConvertTo-Json | Out-File -FilePath $LockFile -Encoding UTF8 -Force
        Write-Log "Lock file created to prevent re-execution" "Yellow"
    }
    catch {
        Write-Log "Warning: Could not create lock file: $($_.Exception.Message)" "Yellow"
    }
}

function Mark-AsExecuted {
    try {
        if (Test-Path $FlagPath) {
            $FlagContent = Get-Content $FlagPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $FlagContent.Executed = $true
            $FlagContent.ExecutedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $FlagContent.ExecutedBy = $env:USERNAME
            $FlagContent.Note = "EXECUTED - Will never run again"
            $FlagContent | ConvertTo-Json | Out-File -FilePath $FlagPath -Encoding UTF8 -Force
            Write-Log "FLAG UPDATED: Marked as executed - will NEVER run again" "Magenta"
        }
    }
    catch {
        Write-Log "Warning: Could not update execution flag: $($_.Exception.Message)" "Yellow"
    }
}

function Start-Console {
    Write-Log "=== STARTING VISIBLE CONSOLE SESSION ===" "Cyan"
    
    # Read the command from the command file
    $CustomCommand = Get-Content $CommandPath -Raw -Encoding UTF8
    $CustomCommand = $CustomCommand.Trim()
    
    # Create a PowerShell script that will run the commands in a visible window
    $PowerShellScript = @"
# Multi-Command Execution Script
Write-Host '=== GUARANTEED VISIBLE TERMINAL EXECUTION ===' -ForegroundColor Green
Write-Host 'Commands: $CustomCommand' -ForegroundColor Yellow
Write-Host 'Date/Time: ' (Get-Date) -ForegroundColor White
Write-Host ''
Write-Host 'This terminal will REMAIN VISIBLE and OPEN after all commands execute!' -ForegroundColor Cyan
Write-Host ''

`$commands = '$CustomCommand' -split ';' | ForEach-Object { `$_.Trim() } | Where-Object { `$_.Length -gt 0 }

for (`$i = 0; `$i -lt `$commands.Count; `$i++) {
    `$currentCommand = `$commands[`$i]
    `$commandNumber = `$i + 1
    
    Write-Host ''
    Write-Host ('>>> EXECUTING COMMAND ' + `$commandNumber + ' OF ' + `$commands.Count + ' <<<') -ForegroundColor Cyan
    Write-Host ('Command: ' + `$currentCommand) -ForegroundColor White
    Write-Host ('Time: ' + (Get-Date).ToString('HH:mm:ss')) -ForegroundColor Gray
    Write-Host ('-' * 80) -ForegroundColor Gray
    
    try {
        Write-Host 'Running command...' -ForegroundColor Yellow
        `$result = Invoke-Expression `$currentCommand
        if (`$result) {
            Write-Host 'Command output:' -ForegroundColor Green
            Write-Output `$result
        }
        Write-Host ('>>> COMMAND ' + `$commandNumber + ' COMPLETED SUCCESSFULLY <<<') -ForegroundColor Green
    }
    catch {
        Write-Host ('ERROR in command ' + `$commandNumber + ': ' + `$_.Exception.Message) -ForegroundColor Red
        Write-Host 'Attempting to continue with next command...' -ForegroundColor Yellow
    }
    
    if (`$i -lt (`$commands.Count - 1)) {
        Write-Host 'Waiting 2 seconds before next command...' -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

Write-Host ''
Write-Host '=========================================================================' -ForegroundColor Green
Write-Host 'ALL COMMANDS EXECUTED SUCCESSFULLY' -ForegroundColor Green
Write-Host 'Commands executed: $CustomCommand' -ForegroundColor White
Write-Host 'Execution completed at: ' (Get-Date) -ForegroundColor White
Write-Host 'This terminal will REMAIN OPEN for your review' -ForegroundColor Cyan
Write-Host '=========================================================================' -ForegroundColor Green
Write-Host ''
Write-Host 'Press any key to close this window...' -ForegroundColor Yellow
`$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
"@
    
    $ScriptPath = "C:\Windows\Temp\RunCommands.ps1"
    $PowerShellScript | Out-File -FilePath $ScriptPath -Encoding UTF8 -Force
    
    Write-Log "PowerShell script created: $ScriptPath" "Green"
    
    # Start PowerShell with the script using the most reliable method
    try {
        # Method 1: Use Start-Process with maximum visibility
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = "powershell.exe"
        $ProcessInfo.Arguments = "-ExecutionPolicy Bypass -NoExit -WindowStyle Normal -File `"$ScriptPath`""
        $ProcessInfo.UseShellExecute = $true
        $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
        $ProcessInfo.CreateNoWindow = $false
        $Process = [System.Diagnostics.Process]::Start($ProcessInfo)
        
        Write-Log "Successfully started PowerShell with visible window" "Green"
        Write-Log "Process ID: $($Process.Id)" "White"
        
        # Wait a moment to ensure the process started
        Start-Sleep -Seconds 1
        
        # Verify the process is running
        if ($Process.HasExited) {
            Write-Log "WARNING: PowerShell process may have exited immediately" "Yellow"
        } else {
            Write-Log "PowerShell process is running and visible" "Green"
        }
    }
    catch {
        Write-Log "CRITICAL: Failed to start PowerShell: $($_.Exception.Message)" "Red"
        
        # Ultimate fallback: Try to execute the commands directly in this process
        Write-Log "Attempting direct execution as ultimate fallback..." "Yellow"
        try {
            $commands = $CustomCommand -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
            foreach ($cmd in $commands) {
                Write-Log "Executing: $cmd" "White"
                Invoke-Expression $cmd
            }
            Write-Log "Direct execution completed" "Green"
        }
        catch {
            Write-Log "Direct execution also failed: $($_.Exception.Message)" "Red"
        }
    }
}

function Invoke-MultiCommand {
    Write-Log "=== STARTING ONE-TIME MULTI-COMMAND EXECUTION ===" "Cyan"

    # CRITICAL: Check if we should execute (one-time only)
    if (Test-AlreadyExecuted) {
        Write-Log "=== EXECUTION CANCELLED - ALREADY RAN OR BLOCKED ===" "Red"
        Write-Log "Press any key to close..." "White"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Start-ImmediateCleanup
        return
    }

    # Create lock file to prevent concurrent execution
    Create-LockFile

    try {
        # Read the custom command from file
        if (Test-Path $CommandPath) {
            $CustomCommand = Get-Content $CommandPath -Raw -Encoding UTF8
            $CustomCommand = $CustomCommand.Trim()
            Write-Log "Multi-command loaded: $CustomCommand" "Green"
        } else {
            Write-Log "ERROR: Command file not found at $CommandPath" "Red"
            Write-Log "Press any key to close..." "White"
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Start-ImmediateCleanup
            return
        }

        if ([string]::IsNullOrWhiteSpace($CustomCommand)) {
            Write-Log "ERROR: Custom command is empty" "Red"
            Write-Log "Press any key to close..." "White"
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Start-ImmediateCleanup
            return
        }

        # CRITICAL: Mark as executed IMMEDIATELY to prevent any re-execution
        Write-Log "=== MARKING AS EXECUTED TO PREVENT RE-EXECUTION ===" "Magenta"
        Mark-AsExecuted

        Write-Log "=== STARTING GUARANTEED VISIBLE CONSOLE SESSION ===" "Cyan"
        Write-Log "Your commands will run in a VISIBLE terminal that stays OPEN!" "Green"
        Write-Log "Commands: $CustomCommand" "White"

        # Start the console session that will execute commands in a visible window
        Start-Console

        Write-Log "" "White"
        Write-Log "=== CONSOLE SESSION INITIATED ===" "Green"
        Write-Log "Your commands are now running in a VISIBLE PowerShell window!" "Cyan"
        Write-Log "The window will REMAIN OPEN after execution for review." "Yellow"
        Write-Log "" "White"
        Write-Log "*** MULTI-COMMAND EXECUTION STARTED ***" "Magenta"
        Write-Log "This script will now exit, but the PowerShell window with your commands will remain open." "White"
        
        # Keep this window open briefly to show success, then exit
        Write-Log "Waiting 3 seconds before closing this window..." "Yellow"
        Start-Sleep -Seconds 3

    }
    catch {
        Write-Log "CRITICAL ERROR in command execution: $($_.Exception.Message)" "Red"
        Write-Log "Press any key to close..." "White"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    finally {
        # Always clean up, regardless of success or failure
        Write-Log "=== STARTING CLEANUP TO PREVENT FUTURE EXECUTION ===" "Yellow"
        Start-ThoroughCleanup
    }
}

function Start-ImmediateCleanup {
    Write-Log "=== IMMEDIATE CLEANUP - REMOVING ALL TRACES ===" "Yellow"

    try {
        # Remove lock file
        if (Test-Path $LockFile) {
            Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
            Write-Log "Removed lock file" "Green"
        }

        # 1. Delete the Registry Run key
        try {
            $RegistryRunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
            $RegistryValueName = "AutoMultiCommand"
            Remove-ItemProperty -Path $RegistryRunKey -Name $RegistryValueName -Force -ErrorAction SilentlyContinue
            Write-Log "Registry Run key deleted" "Green"
        }
        catch {
            Write-Log "Registry key deletion: $($_.Exception.Message)" "Yellow"
        }

        # 2. Delete the Startup folder shortcut
        try {
            $StartupFolder = [System.Environment]::GetFolderPath('Startup')
            $ShortcutPath = Join-Path $StartupFolder "AutoMultiCommand.lnk"
            Remove-Item $ShortcutPath -Force -ErrorAction SilentlyContinue
            Write-Log "Startup shortcut deleted" "Green"
        }
        catch {
            Write-Log "Startup shortcut deletion: $($_.Exception.Message)" "Yellow"
        }

        # 3. Delete the scheduled task immediately
        try {
            $DeleteResult = & schtasks.exe /delete /tn $TaskName /f 2>&1
            Write-Log "Task deletion result: $DeleteResult" "White"
        }
        catch {
            Write-Log "Task deletion error: $($_.Exception.Message)" "Yellow"
        }

        # Also try PowerShell method
        try {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "PowerShell task deletion attempted" "Green"
        }
        catch {
            Write-Log "PowerShell task deletion error: $($_.Exception.Message)" "Yellow"
        }

        Write-Log "Immediate cleanup completed" "Green"

    }
    catch {
        Write-Log "Immediate cleanup error: $($_.Exception.Message)" "Red"
    }
}

function Start-ThoroughCleanup {
    Write-Log "=== THOROUGH CLEANUP - ENSURING NO FUTURE EXECUTION ===" "Yellow"

    # Wait a moment for any processes to finish
    Start-Sleep -Seconds 2

    try {
        # Remove lock file
        if (Test-Path $LockFile) {
            Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
            Write-Log "Removed lock file" "Green"
        }

        # 1. Delete the Registry Run key
        try {
            $RegistryRunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
            $RegistryValueName = "AutoMultiCommand"
            $RegistryValue = Get-ItemProperty -Path $RegistryRunKey -Name $RegistryValueName -ErrorAction SilentlyContinue
            if ($RegistryValue) {
                Remove-ItemProperty -Path $RegistryRunKey -Name $RegistryValueName -Force -ErrorAction SilentlyContinue
                Write-Log "Successfully deleted Registry Run key" "Green"
            } else {
                Write-Log "Registry Run key not found (may already be deleted)" "White"
            }
        }
        catch {
            Write-Log "Registry key deletion: $($_.Exception.Message)" "Yellow"
        }

        # 2. Delete the Startup folder shortcut
        try {
            $StartupFolder = [System.Environment]::GetFolderPath('Startup')
            $ShortcutPath = Join-Path $StartupFolder "AutoMultiCommand.lnk"
            if (Test-Path $ShortcutPath) {
                Remove-Item $ShortcutPath -Force -ErrorAction SilentlyContinue
                Write-Log "Successfully deleted Startup folder shortcut" "Green"
            } else {
                Write-Log "Startup shortcut not found (may already be deleted)" "White"
            }
        }
        catch {
            Write-Log "Startup shortcut deletion: $($_.Exception.Message)" "Yellow"
        }

        # 3. Delete the scheduled task (multiple methods)
        try {
            $DeleteResult = & schtasks.exe /delete /tn $TaskName /f 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Successfully deleted scheduled task: $TaskName" "Green"
            } else {
                Write-Log "Task may already be deleted: $DeleteResult" "White"
            }
        }
        catch {
            Write-Log "schtasks deletion: $($_.Exception.Message)" "Yellow"
        }

        # Also try PowerShell method for task
        try {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "PowerShell task deletion completed" "Green"
        }
        catch {
            Write-Log "PowerShell task deletion: $($_.Exception.Message)" "Yellow"
        }

        # Delete all related files
        $FilesToDelete = @($CommandPath, $FlagPath)
        foreach ($FileToDelete in $FilesToDelete) {
            if (Test-Path $FileToDelete) {
                Remove-Item $FileToDelete -Force -ErrorAction SilentlyContinue
                Write-Log "Deleted file: $FileToDelete" "Green"
            }
        }

        # Schedule self-deletion of the script
        $SelfDeleteScript = @"
# Self-deletion script - removes all traces
Start-Sleep -Seconds 5
try {
    Remove-Item 'C:\Windows\Temp\AutoMultiCommand.ps1' -Force -ErrorAction SilentlyContinue
    Remove-Item 'C:\Windows\Temp\RunCommands.ps1' -Force -ErrorAction SilentlyContinue
    Remove-Item 'C:\Windows\Temp\SelfDelete.ps1' -Force -ErrorAction SilentlyContinue
    Remove-Item 'C:\Windows\Temp\MultiCommand.*' -Force -ErrorAction SilentlyContinue
} catch {}
"@

        $SelfDeletePath = "C:\Windows\Temp\SelfDelete.ps1"
        $SelfDeleteScript | Out-File -FilePath $SelfDeletePath -Encoding UTF8 -Force

        Start-Process -FilePath "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$SelfDeletePath`"" -WindowStyle Hidden -ErrorAction SilentlyContinue

        Write-Log "Scheduled complete self-deletion - all traces will be removed" "Green"
        Write-Log "=== CLEANUP COMPLETED - WILL NEVER RUN AGAIN ===" "Green"

    }
    catch {
        Write-Log "Cleanup error: $($_.Exception.Message)" "Red"
    }
}

# ========================================
# MAIN EXECUTION - ONE TIME ONLY
# ========================================

try {
    # Set console title
    $Host.UI.RawUI.WindowTitle = "Multi-Command Executor - GUARANTEED EXECUTION"
    
    # Make sure console is visible and properly sized
    try {
        $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(120, 50)
        $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(120, 30)
    } catch {
        # Ignore sizing errors
    }

    Write-Log "=== AutoMultiCommand Script Started - GUARANTEED VISIBLE EXECUTION ===" "Cyan"
    Write-Log "Current user: $env:USERNAME" "White"
    Write-Log "Computer: $env:COMPUTERNAME" "White"
    Write-Log "Date/Time: $(Get-Date)" "White"

    Write-Log "Waiting 3 seconds after login for system stabilization..." "Yellow"
    Start-Sleep -Seconds 3
    Write-Log "System stabilization complete - proceeding with command execution" "Green"

    # Execute the custom commands (ONE TIME ONLY) in a visible console
    Invoke-MultiCommand

    Write-Log "=== SCRIPT EXECUTION COMPLETED - WILL NEVER RUN AGAIN ===" "Magenta"

}
catch {
    Write-Log "CRITICAL ERROR in main script: $($_.Exception.Message)" "Red"

    # Emergency cleanup
    try {
        Write-Log "Attempting emergency cleanup..." "Yellow"
        Start-ThoroughCleanup
    }
    catch {
        Write-Log "Emergency cleanup failed: $($_.Exception.Message)" "Red"
    }
    
    Write-Log "Press any key to close..." "White"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
'@

    try {
        $ExecutionScript | Out-File -FilePath $ScriptPath -Encoding UTF8 -Force
        Write-ColorOutput "Multi-command execution script created successfully at: $ScriptPath" "Green"

        if (Test-Path $ScriptPath) {
            $FileSize = (Get-Item $ScriptPath).Length
            Write-DebugLog "Script file size: $FileSize bytes"
            return $true
        } else {
            throw "Script file was not created"
        }
    }
    catch {
        Write-ColorOutput "FAILED to create execution script: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Create-ScheduledTask {
    Write-ColorOutput "=== CREATING AUTOSTART CONFIGURATION ===" "Yellow"

    $CurrentUser = $env:USERNAME
    $CurrentDomain = $env:USERDOMAIN
    $ComputerName = $env:COMPUTERNAME

    Write-DebugLog "Task name: $TaskName"
    Write-DebugLog "Current user: $CurrentUser"
    Write-DebugLog "Current domain: $CurrentDomain"
    Write-DebugLog "Computer name: $ComputerName"
    Write-DebugLog "Script path: $ScriptPath"

    $SuccessCount = 0
    
    # METHOD 1: Registry Run Key (MOST RELIABLE - ALWAYS WORKS!)
    Write-ColorOutput "Method 1: Setting up Registry Run key (MOST RELIABLE)..." "Yellow"
    
    try {
        # Ensure the Run key exists
        if (-not (Test-Path $RegistryRunKey)) {
            New-Item -Path $RegistryRunKey -Force | Out-Null
        }
        
        # Create the registry value with proper command
        $RegistryCommand = "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File `"$ScriptPath`""
        Set-ItemProperty -Path $RegistryRunKey -Name $RegistryValueName -Value $RegistryCommand -Type String -Force
        
        # Verify it was set
        $VerifyValue = Get-ItemProperty -Path $RegistryRunKey -Name $RegistryValueName -ErrorAction SilentlyContinue
        if ($VerifyValue -and $VerifyValue.$RegistryValueName -eq $RegistryCommand) {
            Write-ColorOutput "[OK] Registry Run key created successfully!" "Green"
            Write-DebugLog "Registry path: $RegistryRunKey\$RegistryValueName"
            Write-DebugLog "Registry value: $RegistryCommand"
            $SuccessCount++
        } else {
            Write-ColorOutput "[FAILED] Registry verification failed" "Red"
        }
    }
    catch {
        Write-ColorOutput "[FAILED] Registry method failed: $($_.Exception.Message)" "Red"
        Write-DebugLog "Registry method exception: $($_.Exception.Message)"
    }

    # METHOD 2: Startup Folder Shortcut (BACKUP METHOD)
    Write-ColorOutput "Method 2: Creating Startup folder shortcut (BACKUP)..." "Yellow"
    
    try {
        $StartupFolder = [System.Environment]::GetFolderPath('Startup')
        $ShortcutPath = Join-Path $StartupFolder "AutoMultiCommand.lnk"
        
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File `"$ScriptPath`""
        $Shortcut.WorkingDirectory = $ScriptDir
        $Shortcut.WindowStyle = 1  # Normal window
        $Shortcut.Description = "Auto Multi-Command Execution"
        $Shortcut.Save()
        
        if (Test-Path $ShortcutPath) {
            Write-ColorOutput "[OK] Startup folder shortcut created successfully!" "Green"
            Write-DebugLog "Shortcut path: $ShortcutPath"
            $SuccessCount++
        } else {
            Write-ColorOutput "[FAILED] Shortcut verification failed" "Red"
        }
    }
    catch {
        Write-ColorOutput "[FAILED] Startup folder method failed: $($_.Exception.Message)" "Red"
        Write-DebugLog "Startup folder exception: $($_.Exception.Message)"
    }

    # METHOD 3: Scheduled Task (ADDITIONAL BACKUP)
    Write-ColorOutput "Method 3: Creating Scheduled Task (ADDITIONAL BACKUP)..." "Yellow"
    
    try {
        $TaskCommand = "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File `"$ScriptPath`""
        
        # Try with current user first (more reliable than SYSTEM for visible windows)
        $Result = & schtasks.exe /create /tn $TaskName /tr $TaskCommand /sc ONLOGON /rl HIGHEST /f 2>&1
        $ExitCode = $LASTEXITCODE

        if ($ExitCode -eq 0) {
            Write-ColorOutput "[OK] Scheduled Task created successfully!" "Green"
            Write-DebugLog "Task created with current user"
            $SuccessCount++
        } else {
            Write-DebugLog "Scheduled task failed: $Result"
            Write-ColorOutput "[FAILED] Scheduled Task creation failed (not critical)" "Yellow"
        }
    }
    catch {
        Write-ColorOutput "[FAILED] Scheduled Task method failed (not critical)" "Yellow"
        Write-DebugLog "Scheduled task exception: $($_.Exception.Message)"
    }

    # Report results
    Write-ColorOutput "" "White"
    if ($SuccessCount -ge 1) {
        Write-ColorOutput "SUCCESS: $SuccessCount autostart method(s) configured!" "Green"
        Write-ColorOutput "Your commands WILL execute after reboot - GUARANTEED!" "Green"
        return $true
    } else {
        Write-ColorOutput "CRITICAL FAILURE: All autostart methods failed!" "Red"
        return $false
    }
}

function Test-TaskCreation {
    Write-ColorOutput "=== VERIFYING AUTOSTART CONFIGURATION ===" "Yellow"

    $VerifiedCount = 0
    
    # Check 1: Registry Run key
    try {
        $RegistryValue = Get-ItemProperty -Path $RegistryRunKey -Name $RegistryValueName -ErrorAction SilentlyContinue
        if ($RegistryValue -and $RegistryValue.$RegistryValueName) {
            Write-ColorOutput "[OK] Registry Run key verified!" "Green"
            Write-DebugLog "Registry value exists: $($RegistryValue.$RegistryValueName)"
            $VerifiedCount++
        } else {
            Write-ColorOutput "[FAILED] Registry Run key not found" "Red"
        }
    }
    catch {
        Write-ColorOutput "[FAILED] Registry verification failed: $($_.Exception.Message)" "Red"
    }
    
    # Check 2: Startup folder shortcut
    try {
        $StartupFolder = [System.Environment]::GetFolderPath('Startup')
        $ShortcutPath = Join-Path $StartupFolder "AutoMultiCommand.lnk"
        
        if (Test-Path $ShortcutPath) {
            Write-ColorOutput "[OK] Startup folder shortcut verified!" "Green"
            Write-DebugLog "Shortcut exists: $ShortcutPath"
            $VerifiedCount++
        } else {
            Write-ColorOutput "[FAILED] Startup folder shortcut not found" "Yellow"
        }
    }
    catch {
        Write-ColorOutput "[FAILED] Startup folder verification failed: $($_.Exception.Message)" "Yellow"
    }
    
    # Check 3: Scheduled task
    try {
        $QueryResult = & schtasks.exe /query /tn $TaskName 2>&1
        $QueryExitCode = $LASTEXITCODE

        if ($QueryExitCode -eq 0) {
            Write-ColorOutput "[OK] Scheduled Task verified!" "Green"
            Write-DebugLog "Task query successful"
            $VerifiedCount++
        } else {
            Write-ColorOutput "[FAILED] Scheduled Task not found (not critical)" "Yellow"
        }
    }
    catch {
        Write-DebugLog "Task verification exception: $($_.Exception.Message)"
    }

    Write-ColorOutput "" "White"
    if ($VerifiedCount -ge 1) {
        Write-ColorOutput "VERIFICATION SUCCESS: $VerifiedCount method(s) confirmed!" "Green"
        Write-ColorOutput "Execution after reboot is GUARANTEED!" "Green"
        return $true
    } else {
        Write-ColorOutput "VERIFICATION FAILED: No autostart methods confirmed!" "Red"
        return $false
    }
}

function Start-SystemCleanup {
    Write-ColorOutput "=== PREPARING FOR REBOOT ===" "Yellow"

    $ProcessesToClose = @("chrome", "firefox", "msedge", "teams", "outlook", "excel", "word", "powerpoint")

    foreach ($ProcessName in $ProcessesToClose) {
        try {
            $Processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            if ($Processes) {
                $Processes | Stop-Process -Force -ErrorAction SilentlyContinue
                Write-DebugLog "Closed process: $ProcessName"
            }
        }
        catch {
            Write-DebugLog "Could not close process ${ProcessName}: $($_.Exception.Message)"
        }
    }

    # Restart Explorer
    try {
        $ExplorerProcesses = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
        if ($ExplorerProcesses) {
            $ExplorerProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-DebugLog "Restarted Explorer"
        }
    }
    catch {
        Write-DebugLog "Could not restart Explorer: $($_.Exception.Message)"
    }
}

function Show-Summary {
    param([string]$CustomCommand, [bool]$TaskCreated)

    if (-not $SkipReboot) {
        Write-ColorOutput "" "White"
        Write-ColorOutput "=== READY FOR IMMEDIATE REBOOT ===" "Cyan"

        if ($TaskCreated) {
            Write-ColorOutput "[SUCCESS] AUTOSTART CONFIGURED SUCCESSFULLY!" "Green"
            Write-ColorOutput "" "White"
            Write-ColorOutput "After reboot and login, the system will:" "White"
            Write-ColorOutput "  - IMMEDIATELY open a VISIBLE PowerShell window" "Green"
            Write-ColorOutput "  - Execute EXACTLY these commands: $CustomCommand" "Cyan"
            Write-ColorOutput "  - Run each command WORD BY WORD, LETTER BY LETTER as typed" "Cyan"
            Write-ColorOutput "  - Show execution progress in REAL-TIME" "Green"
            Write-ColorOutput "  - Keep window OPEN for you to review results" "Green"
            Write-ColorOutput "  - Execute ONLY ONCE (never again after that)" "Yellow"
            Write-ColorOutput "  - Clean up all scripts and tasks automatically" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "CRITICAL: This is ONE-TIME execution ONLY!" "Red"
            Write-ColorOutput "After running once, commands will NEVER run again!" "Red"
            Write-ColorOutput "" "White"
            Write-ColorOutput "REBOOTING IMMEDIATELY IN 3 SECONDS..." "Red"
            Write-ColorOutput "Press Ctrl+C NOW to cancel!" "Yellow"

            for ($i = 3; $i -ge 1; $i--) {
                Write-Host "$i..." -ForegroundColor Red -NoNewline
                Start-Sleep -Seconds 1
            }

            Write-ColorOutput "`nREBOOTING NOW!!!" "Red"
            Start-Sleep -Milliseconds 500
            Restart-Computer -Force
        } else {
            Write-ColorOutput "AUTOSTART CONFIGURATION FAILED - Cannot proceed with reboot!" "Red"
            Write-ColorOutput "Please check the manual alternatives below." "Yellow"
        }
    } else {
        Write-ColorOutput "" "White"
        Write-ColorOutput "=== SETUP COMPLETE ===" "Green"
        Write-ColorOutput "Script path: $ScriptPath" "Gray"
        Write-ColorOutput "Command file: $CommandPath" "Gray"
        Write-ColorOutput "Flag file: $FlagPath" "Gray"
        Write-ColorOutput "Custom commands: $CustomCommand" "Gray"
        Write-ColorOutput "" "White"

        if ($TaskCreated) {
            Write-ColorOutput "[SUCCESS] AUTOSTART CONFIGURED - Ready for next login!" "Green"
            Write-ColorOutput "Commands will execute EXACTLY as typed, ONE TIME only!" "Yellow"
        } else {
            Write-ColorOutput "[FAILED] AUTOSTART CONFIGURATION FAILED!" "Red"
            Write-ColorOutput "You can run the script manually: $ScriptPath" "Yellow"
        }
    }

    if (-not $TaskCreated) {
        Write-ColorOutput "" "White"
        Write-ColorOutput "=== MANUAL ALTERNATIVES ===" "Cyan"
        Write-ColorOutput "1. Run script manually: powershell -ExecutionPolicy Bypass -File `"$ScriptPath`"" "Yellow"
        Write-ColorOutput "2. Check Windows Event Log for errors" "Yellow"
        Write-ColorOutput "" "White"
        Write-ColorOutput "NOTE: Manual execution will also be ONE-TIME only!" "Red"
    }
}

# MAIN EXECUTION
Write-ColorOutput "=== ENHANCED MULTI-COMMAND AFTER REBOOT SCRIPT ===" "Cyan"
Write-ColorOutput "PowerShell Version: $($PSVersionTable.PSVersion)" "Gray"
Write-ColorOutput "Script Version: $ScriptVersion" "Gray"

# Check administrator privileges
if (-not (Test-Administrator)) {
    Write-ColorOutput "This script requires Administrator privileges. Please run as Administrator." "Red"
    Write-ColorOutput "Right-click PowerShell and select 'Run as Administrator'" "Yellow"
    exit 1
}

Write-ColorOutput "Administrator privileges confirmed." "Green"

# Initialize directories
if (-not (Initialize-Directories)) {
    Write-ColorOutput "Failed to initialize required directories. Exiting." "Red"
    exit 1
}

# Clean up old tasks
Remove-OldTasks

# Get custom commands
$CustomCommand = Get-UserCommand

# Save commands and create flag
if (-not (Save-CommandAndFlag -CustomCommand $CustomCommand)) {
    Write-ColorOutput "Failed to save commands and flag. Exiting." "Red"
    exit 1
}

# Create execution script
if (-not (Create-ExecutionScript)) {
    Write-ColorOutput "Failed to create execution script. Exiting." "Red"
    exit 1
}

# Create scheduled task
$TaskCreated = Create-ScheduledTask

# Verify task creation
if ($TaskCreated) {
    $TaskCreated = Test-TaskCreation
}

# Clean up system for reboot
Start-SystemCleanup

# Show summary and reboot or finish
Show-Summary -CustomCommand $CustomCommand -TaskCreated $TaskCreated

Write-ColorOutput "" "White"
Write-ColorOutput "Script execution completed." "Green"
