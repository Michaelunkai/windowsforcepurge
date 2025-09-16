# Enhanced Multi-Command After Reboot Script - PowerShell 5 Compatible
# Run as Administrator
# Usage: ./script.ps1 'command1; command2; command3'

param(
    [string]$Command = "",
    [switch]$SkipReboot,
    [switch]$Debug
)

# Global variables
$ScriptVersion = "3.0-MULTI-COMMAND"
$ScriptDir = "C:\Windows\Temp"
$ScriptPath = Join-Path $ScriptDir "AutoMultiCommand.ps1"
$CommandPath = Join-Path $ScriptDir "MultiCommand.txt"
$FlagPath = Join-Path $ScriptDir "MultiCommand.flag"
$TaskName = "AutoMultiCommandTask"
$LogPath = Join-Path $ScriptDir "AutoMultiCommand.log"

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
        Write-ColorOutput "  - Get-Process notepad | Stop-Process; Start-Process notepad" "Gray"
        Write-ColorOutput "  - Write-Host 'Starting...'; Start-Sleep 2; Write-Host 'Done!'" "Gray"
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

        Write-Log "=== EXECUTING YOUR CUSTOM COMMANDS (ONE TIME ONLY) ===" "Cyan"

        # Set execution policy temporarily
        try {
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            Write-Log "Execution policy set to Bypass for this process" "Green"
        }
        catch {
            Write-Log "Warning: Could not set execution policy: $($_.Exception.Message)" "Yellow"
        }

        # Parse commands (split by semicolon)
        $Commands = $CustomCommand -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        
        Write-Log "Found $($Commands.Count) commands to execute sequentially" "Cyan"
        Write-Log "=== COMMAND EXECUTION STARTING ===" "Green"

        # Execute each command sequentially
        for ($i = 0; $i -lt $Commands.Count; $i++) {
            $CurrentCommand = $Commands[$i]
            $CommandNumber = $i + 1
            
            Write-Log "" "White"
            Write-Log "*** EXECUTING COMMAND $CommandNumber OF $($Commands.Count) ***" "Cyan"
            Write-Log "Command: $CurrentCommand" "White"
            Write-Log "---" "Gray"

            try {
                # Execute command with comprehensive error handling
                $CommandResult = Invoke-Expression $CurrentCommand 2>&1

                if ($CommandResult) {
                    $ResultString = $CommandResult | Out-String
                    Write-Log "Output: $ResultString" "White"
                } else {
                    Write-Log "Command completed successfully with no output" "Green"
                }

                Write-Log "*** COMMAND $CommandNumber COMPLETED SUCCESSFULLY ***" "Green"
                
                # Small delay between commands for visibility
                if ($i -lt ($Commands.Count - 1)) {
                    Write-Log "Waiting 2 seconds before next command..." "Yellow"
                    Start-Sleep -Seconds 2
                }
            }
            catch {
                Write-Log "ERROR executing command $CommandNumber`: $($_.Exception.Message)" "Red"

                # Try alternative execution method
                Write-Log "Attempting alternative execution method for command $CommandNumber..." "Yellow"
                try {
                    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
                    $ProcessInfo.FileName = "powershell.exe"
                    $ProcessInfo.Arguments = "-ExecutionPolicy Bypass -Command `"$CurrentCommand`""
                    $ProcessInfo.UseShellExecute = $false
                    $ProcessInfo.RedirectStandardOutput = $true
                    $ProcessInfo.RedirectStandardError = $true
                    $ProcessInfo.CreateNoWindow = $false

                    $Process = New-Object System.Diagnostics.Process
                    $Process.StartInfo = $ProcessInfo
                    $Process.Start() | Out-Null
                    $Process.WaitForExit()

                    $Output = $Process.StandardOutput.ReadToEnd()
                    $Errors = $Process.StandardError.ReadToEnd()

                    if ($Output) { Write-Log "Alternative method output: $Output" "White" }
                    if ($Errors) { Write-Log "Alternative method errors: $Errors" "Yellow" }

                    Write-Log "Alternative execution method completed for command $CommandNumber" "Green"
                }
                catch {
                    Write-Log "Alternative execution method failed for command $CommandNumber`: $($_.Exception.Message)" "Red"
                }
                
                # Small delay before next command even if this one failed
                if ($i -lt ($Commands.Count - 1)) {
                    Write-Log "Waiting 2 seconds before next command..." "Yellow"
                    Start-Sleep -Seconds 2
                }
            }
        }

        Write-Log "" "White"
        Write-Log "=== ALL COMMANDS EXECUTION COMPLETED ===" "Green"
        Write-Log "Total commands executed: $($Commands.Count)" "Cyan"
        Write-Log "" "White"
        Write-Log "*** MULTI-COMMAND EXECUTION FINISHED ***" "Magenta"
        Write-Log "This window will remain open for 30 seconds for you to review the output..." "Yellow"
        
        # Keep window open for review
        for ($countdown = 30; $countdown -gt 0; $countdown--) {
            Write-Host "`rWindow will close in $countdown seconds... (Press any key to close immediately)" -NoNewline -ForegroundColor Yellow
            
            if ($Host.UI.RawUI.KeyAvailable) {
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                break
            }
            
            Start-Sleep -Seconds 1
        }
        
        Write-Log "" "White"
        Write-Log "Closing window and cleaning up..." "Yellow"

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

        # Delete the scheduled task immediately
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

        # Delete the scheduled task (multiple methods)
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

        # Also try PowerShell method
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
    # Set console title and make window more visible
    $Host.UI.RawUI.WindowTitle = "★ Multi-Command Executor - ONE TIME ONLY ★"
    
    # Create a test file to prove we ran
    "SCRIPT STARTED: $(Get-Date)" | Out-File -FilePath "C:\Windows\Temp\MultiCommand_PROOF.txt" -Force
    
    # Make sure console is visible and properly sized
    try {
        $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(140, 50)
        $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(140, 35)
        
        # Try to bring window to front
        Add-Type -TypeDefinition @"
            using System;
            using System.Runtime.InteropServices;
            public class Win32 {
                [DllImport("user32.dll")]
                public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                [DllImport("kernel32.dll")]
                public static extern IntPtr GetConsoleWindow();
            }
"@
        $consolePtr = [Win32]::GetConsoleWindow()
        [Win32]::ShowWindow($consolePtr, 3) # SW_MAXIMIZE
    } catch {
        # Ignore sizing/positioning errors
    }

    Write-Log "=== AutoMultiCommand Script Started - ONE-TIME EXECUTION ONLY ===" "Cyan"
    Write-Log "Current user: $env:USERNAME" "White"
    Write-Log "Computer: $env:COMPUTERNAME" "White"
    Write-Log "Date/Time: $(Get-Date)" "White"
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" "White"

    # Create visual proof file that script started
    "MULTI-COMMAND SCRIPT STARTED SUCCESSFULLY: $(Get-Date)" | Out-File -FilePath "C:\Windows\Temp\MultiCommand_STARTED.txt" -Force

    Write-Log "Waiting 20 seconds after login for system stabilization..." "Yellow"
    Write-Log "*** YOU SHOULD SEE THIS WINDOW - COMMANDS WILL RUN SOON! ***" "Green"
    for ($i = 20; $i -gt 0; $i--) {
        Write-Host "`r*** SYSTEM STABILIZATION: $i seconds remaining - WINDOW IS WORKING! ***" -NoNewline -ForegroundColor Green
        Start-Sleep -Seconds 1
    }
    Write-Log "" "White"
    Write-Log "System stabilization complete - proceeding with command execution" "Green"

    # Execute the custom commands (ONE TIME ONLY)
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
    Write-ColorOutput "=== CREATING SCHEDULED TASK ===" "Yellow"

    $CurrentUser = $env:USERNAME
    $CurrentDomain = $env:USERDOMAIN
    $ComputerName = $env:COMPUTERNAME

    # Try different user format approaches
    $UserFormats = @(
        "$ComputerName\$CurrentUser",  # COMPUTERNAME\username
        ".\$CurrentUser",              # .\username (local user)
        "$CurrentUser",                # just username
        "$CurrentDomain\$CurrentUser"  # DOMAIN\username
    )

    Write-DebugLog "Task name: $TaskName"
    Write-DebugLog "Current user: $CurrentUser"
    Write-DebugLog "Current domain: $CurrentDomain"
    Write-DebugLog "Computer name: $ComputerName"
    Write-DebugLog "Script path: $ScriptPath"

    # Method 1: Create a test task first to verify the system works
    Write-ColorOutput "Testing basic task creation capability..." "Yellow"
    
    $TestTaskName = "MultiCommandTest"
    $TestCommand = "cmd.exe /c echo TASK_TEST_SUCCESS > C:\Windows\Temp\task_test.txt"
    
    try {
        # Clean up any existing test task
        & schtasks.exe /delete /tn $TestTaskName /f 2>&1 | Out-Null
        
        # Create simple test task
        $TestResult = & schtasks.exe /create /tn $TestTaskName /tr $TestCommand /sc ONLOGON /rl HIGHEST /f 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Basic task creation works - proceeding with main task" "Green"
            # Clean up test task
            & schtasks.exe /delete /tn $TestTaskName /f 2>&1 | Out-Null
        } else {
            Write-ColorOutput "Basic task creation failed: $TestResult" "Red"
        }
    } catch {
        Write-ColorOutput "Test task creation error: $($_.Exception.Message)" "Red"
    }

    # Method 1: Simple schtasks command with VISIBLE window and explicit path
    Write-ColorOutput "Trying simple schtasks method..." "Yellow"

    foreach ($UserFormat in $UserFormats) {
        try {
            Write-DebugLog "Trying user format: $UserFormat"

            # FIXED: Use cmd.exe to launch PowerShell to ensure visibility
            $TaskCommand = "cmd.exe /c start `"Multi-Command Window`" /max powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -Command `"& '$ScriptPath'`""

            $Result = & schtasks.exe /create /tn $TaskName /tr $TaskCommand /sc ONLOGON /ru $UserFormat /rl HIGHEST /f 2>&1
            $ExitCode = $LASTEXITCODE

            if ($ExitCode -eq 0) {
                Write-ColorOutput "Simple schtasks method successful with user format: $UserFormat" "Green"
                return $true
            } else {
                Write-DebugLog "Failed with user format $UserFormat. Result: $Result"
            }
        }
        catch {
            Write-DebugLog "Exception with user format $UserFormat`: $($_.Exception.Message)"
        }
    }

    # Method 1B: Try without cmd.exe wrapper
    Write-ColorOutput "Trying direct PowerShell method..." "Yellow"

    foreach ($UserFormat in $UserFormats) {
        try {
            Write-DebugLog "Trying direct PowerShell with user format: $UserFormat"

            # FIXED: Explicitly make window visible and maximize
            $TaskCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -Command `"& '$ScriptPath'`""

            $Result = & schtasks.exe /create /tn $TaskName /tr $TaskCommand /sc ONLOGON /ru $UserFormat /rl HIGHEST /f 2>&1
            $ExitCode = $LASTEXITCODE

            if ($ExitCode -eq 0) {
                Write-ColorOutput "Direct PowerShell method successful with user format: $UserFormat" "Green"
                return $true
            } else {
                Write-DebugLog "Failed with user format $UserFormat. Result: $Result"
            }
        }
        catch {
            Write-DebugLog "Exception with user format $UserFormat`: $($_.Exception.Message)"
        }
    }

    Write-ColorOutput "Simple schtasks method failed with all user formats" "Red"

    # Method 2: XML-based task creation with VISIBLE window
    Write-ColorOutput "Trying XML method..." "Yellow"

    foreach ($UserFormat in $UserFormats) {
        try {
            Write-DebugLog "Trying XML with user format: $UserFormat"

            $TaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Auto Multi-Command - One-time execution after reboot</Description>
    <Author>$UserFormat</Author>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$UserFormat</UserId>
      <Delay>PT10S</Delay>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$UserFormat</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT30M</ExecutionTimeLimit>
    <Priority>6</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -WindowStyle Normal -Command "& '$ScriptPath'"</Arguments>
      <WorkingDirectory>C:\Windows\Temp</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@

            $XmlPath = Join-Path $ScriptDir "task.xml"
            $TaskXml | Out-File -FilePath $XmlPath -Encoding Unicode -Force

            $Result = & schtasks.exe /create /tn $TaskName /xml $XmlPath /f 2>&1
            $ExitCode = $LASTEXITCODE

            # Clean up XML file
            Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue

            if ($ExitCode -eq 0) {
                Write-ColorOutput "XML method successful with user format: $UserFormat" "Green"
                return $true
            } else {
                Write-DebugLog "XML failed with user format $UserFormat. Result: $Result"
            }
        }
        catch {
            Write-DebugLog "XML exception with user format $UserFormat`: $($_.Exception.Message)"
        }
    }

    Write-ColorOutput "XML method failed with all user formats" "Red"

    # Method 3: PowerShell cmdlets with VISIBLE window
    Write-ColorOutput "Trying PowerShell cmdlets method..." "Yellow"

    try {
        # Check if ScheduledTasks module is available
        $Module = Get-Module -Name ScheduledTasks -ListAvailable -ErrorAction SilentlyContinue
        if (-not $Module) {
            Write-DebugLog "ScheduledTasks module not available"
        } else {
            Import-Module ScheduledTasks -Force -ErrorAction SilentlyContinue

            foreach ($UserFormat in $UserFormats) {
                try {
                    Write-DebugLog "Trying PowerShell cmdlets with user format: $UserFormat"

                    # FIXED: Explicitly make window visible
                    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Normal -Command `"& '$ScriptPath'`"" -WorkingDirectory "C:\Windows\Temp"
                    $Trigger = New-ScheduledTaskTrigger -AtLogOn -User $UserFormat
                    $Principal = New-ScheduledTaskPrincipal -UserId $UserFormat -RunLevel Highest -LogonType Interactive
                    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

                    $null = Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force

                    Write-ColorOutput "PowerShell cmdlets method successful with user format: $UserFormat" "Green"
                    return $true
                }
                catch {
                    Write-DebugLog "PowerShell cmdlets failed with user format $UserFormat`: $($_.Exception.Message)"
                }
            }
        }
    }
    catch {
        Write-ColorOutput "PowerShell cmdlets failed: $($_.Exception.Message)" "Red"
        Write-DebugLog "PowerShell cmdlets error details: $($_.Exception | Out-String)"
    }

    Write-ColorOutput "PowerShell cmdlets method failed with all user formats" "Red"

    # Method 4: Fallback with current user context (no domain)
    Write-ColorOutput "Trying fallback method with current user..." "Yellow"

    try {
        # FIXED: Explicitly make window visible
        $TaskCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -Command `"& '$ScriptPath'`""

        # Try without specifying user (uses current user context)
        $Result = & schtasks.exe /create /tn $TaskName /tr $TaskCommand /sc ONLOGON /rl HIGHEST /f 2>&1
        $ExitCode = $LASTEXITCODE

        if ($ExitCode -eq 0) {
            Write-ColorOutput "Fallback method successful!" "Green"
            return $true
        } else {
            Write-DebugLog "Fallback method failed: $Result"
        }
    }
    catch {
        Write-DebugLog "Fallback method exception: $($_.Exception.Message)"
    }

    Write-ColorOutput "ALL TASK CREATION METHODS FAILED!" "Red"
    return $false
}

function Test-TaskCreation {
    Write-ColorOutput "=== VERIFYING TASK CREATION ===" "Yellow"

    try {
        # Method 1: schtasks query
        $QueryResult = & schtasks.exe /query /tn $TaskName 2>&1
        $QueryExitCode = $LASTEXITCODE

        if ($QueryExitCode -eq 0) {
            Write-ColorOutput "TASK VERIFIED: $TaskName exists and is ready!" "Green"
            Write-DebugLog "Task query successful"
            return $true
        }

        # Method 2: PowerShell Get-ScheduledTask
        try {
            $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($Task) {
                Write-ColorOutput "TASK VERIFIED via PowerShell: $TaskName exists!" "Green"
                Write-DebugLog "Task found via Get-ScheduledTask"
                return $true
            }
        }
        catch {
            Write-DebugLog "Get-ScheduledTask failed: $($_.Exception.Message)"
        }

        Write-ColorOutput "TASK VERIFICATION FAILED" "Red"
        return $false

    }
    catch {
        Write-ColorOutput "Task verification error: $($_.Exception.Message)" "Red"
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
        Write-ColorOutput "=== READY FOR REBOOT ===" "Cyan"

        if ($TaskCreated) {
            Write-ColorOutput "After reboot the system will:" "White"
            Write-ColorOutput "  • Wait 15 seconds after login for system stabilization" "White"
            Write-ColorOutput "  • Open a VISIBLE PowerShell window" "Green"
            Write-ColorOutput "  • Execute your commands SEQUENTIALLY: $CustomCommand" "White"
            Write-ColorOutput "  • *** COMMANDS WILL RUN ONLY ONCE *** (never again after that)" "Yellow"
            Write-ColorOutput "  • Show execution progress and results in the window" "Green"
            Write-ColorOutput "  • Keep window open for 30 seconds for review" "Green"
            Write-ColorOutput "  • Task will DELETE ITSELF after execution" "White"
            Write-ColorOutput "  • All script files will be PERMANENTLY REMOVED" "White"
            Write-ColorOutput "  • Log file will be created at: $LogPath" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "CRITICAL: This is a ONE-TIME execution. After commands run once," "Red"
            Write-ColorOutput "they will NEVER run again, even on future reboots!" "Red"
            Write-ColorOutput "" "White"
            Write-ColorOutput "Rebooting in 10 seconds..." "Red"
            Write-ColorOutput "Press Ctrl+C to cancel..." "Yellow"

            for ($i = 10; $i -ge 1; $i--) {
                Write-ColorOutput "$i..." "Red"
                Start-Sleep -Seconds 1
            }

            Write-ColorOutput "REBOOTING NOW!" "Red"
            Restart-Computer -Force
        } else {
            Write-ColorOutput "TASK CREATION FAILED - Cannot proceed with reboot!" "Red"
            Write-ColorOutput "Please check the manual alternatives below." "Yellow"
        }
    } else {
        Write-ColorOutput "" "White"
        Write-ColorOutput "=== SETUP COMPLETE ===" "Green"
        Write-ColorOutput "Script path: $ScriptPath" "Gray"
        Write-ColorOutput "Command file: $CommandPath" "Gray"
        Write-ColorOutput "Flag file: $FlagPath" "Gray"
        Write-ColorOutput "Task name: $TaskName" "Gray"
        Write-ColorOutput "Custom commands: $CustomCommand" "Gray"
        Write-ColorOutput "Log file: $LogPath" "Gray"
        Write-ColorOutput "" "White"

        if ($TaskCreated) {
            Write-ColorOutput "*** ONE-TIME MULTI-COMMAND SETUP COMPLETE ***" "Yellow"
            Write-ColorOutput "Commands will run SEQUENTIALLY in a VISIBLE window ONLY ONCE after next login!" "Yellow"
            Write-ColorOutput "After execution, ALL files will be deleted automatically!" "Yellow"
            Write-ColorOutput "Task created successfully and ready for ONE-TIME execution." "Green"
        } else {
            Write-ColorOutput "TASK CREATION FAILED!" "Red"
            Write-ColorOutput "You can run the script manually: $ScriptPath" "Yellow"
        }
    }

    if (-not $TaskCreated) {
        Write-ColorOutput "" "White"
        Write-ColorOutput "=== MANUAL ALTERNATIVES ===" "Cyan"
        Write-ColorOutput "1. Test the script manually RIGHT NOW:" "Yellow"
        Write-ColorOutput "   powershell -ExecutionPolicy Bypass -WindowStyle Normal -Command `"& '$ScriptPath'`"" "Green"
        Write-ColorOutput "" "White"
        Write-ColorOutput "2. If manual test works, create task manually:" "Yellow"
        Write-ColorOutput "   schtasks /create /tn $TaskName /tr `"cmd /c start `"MultiCmd`" /max powershell -ExecutionPolicy Bypass -WindowStyle Normal -Command `"& '$ScriptPath'`"`" /sc ONLOGON /rl HIGHEST" "Green"
        Write-ColorOutput "" "White"
        Write-ColorOutput "3. Alternative: Use Task Scheduler GUI" "Yellow"
        Write-ColorOutput "4. Check Windows Event Log for task creation errors" "Yellow"
        Write-ColorOutput "" "White"
        Write-ColorOutput "NOTE: Manual execution will also be ONE-TIME only!" "Red"
        Write-ColorOutput "" "White"
        Write-ColorOutput "VERIFICATION FILES (check if these exist after reboot):" "Cyan"
        Write-ColorOutput "- C:\Windows\Temp\MultiCommand_PROOF.txt" "Gray"
        Write-ColorOutput "- C:\Windows\Temp\MultiCommand_STARTED.txt" "Gray"
        Write-ColorOutput "- $LogPath" "Gray"
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
