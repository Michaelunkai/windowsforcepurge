# Bulletproof Free Command - Fixed All Syntax Errors
# Usage: free 'command1; command2; function_name'
# Runs commands in FOREGROUND after next login - ONE TIME ONLY

param(
    [string]$Command = "",
    [switch]$SkipReboot,
    [switch]$Debug
)

# Configuration
$ScriptVersion = "3.0-FIXED"
$WorkDir = "C:\Windows\Temp\FreeCmd"
$ScriptPath = "$WorkDir\FreeExecutor.ps1"
$CommandFile = "$WorkDir\command.txt" 
$StatusFile = "$WorkDir\status.json"
$TaskName = "FreeCommandExecutor"
$LogFile = "$WorkDir\execution.log"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    
    # Console output with color
    $colorMap = @{
        "Red" = [ConsoleColor]::Red
        "Green" = [ConsoleColor]::Green  
        "Yellow" = [ConsoleColor]::Yellow
        "Cyan" = [ConsoleColor]::Cyan
        "Gray" = [ConsoleColor]::Gray
        "White" = [ConsoleColor]::White
    }
    
    if ($colorMap[$Color]) {
        Write-Host $logEntry -ForegroundColor $colorMap[$Color]
    } else {
        Write-Host $logEntry
    }
    
    # File logging
    try {
        $logEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
    } catch {
        # Silent fail for logging
    }
    
    if ($Debug) {
        Write-Host "DEBUG: $Message" -ForegroundColor Gray
    }
}

function Test-AdminRights {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Initialize-Environment {
    Write-Log "Initializing environment..." "Yellow"
    
    try {
        # Create work directory
        if (-not (Test-Path $WorkDir)) {
            New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
            Write-Log "Created work directory: $WorkDir" "Green"
        }
        
        # Test write permissions
        $testFile = "$WorkDir\test.tmp"
        "test" | Out-File -FilePath $testFile -Force
        Remove-Item $testFile -Force
        
        Write-Log "Environment initialized successfully" "Green"
        return $true
    } catch {
        Write-Log "Failed to initialize environment: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Get-CommandInput {
    Write-Log "Getting command input..." "Yellow"
    
    if ([string]::IsNullOrWhiteSpace($Command)) {
        Write-Log "Enter the command(s) to run after reboot:" "White"
        Write-Log "Examples:" "Gray"
        Write-Log "  Single: notepad" "Gray"
        Write-Log "  Multiple: dkill; ss; notepad" "Gray"
        Write-Log "  Functions: myfunction; Get-Process" "Gray"
        Write-Log "" "White"
        
        do {
            $userInput = Read-Host "Command(s)"
            if ([string]::IsNullOrWhiteSpace($userInput)) {
                Write-Log "Please enter a valid command." "Red"
            }
        } while ([string]::IsNullOrWhiteSpace($userInput))
        
        Write-Log "" "White"
        Write-Log "You entered: $userInput" "Green"
        $confirm = Read-Host "Execute this after reboot? (y/n)"
        
        if ($confirm -notmatch '^[yY]') {
            Write-Log "Operation cancelled." "Yellow"
            exit 0
        }
        
        return $userInput
    } else {
        Write-Log "Command from parameter: $Command" "Green"
        return $Command
    }
}

function Save-CommandData {
    param([string]$CommandText)
    
    Write-Log "Saving command data..." "Yellow"
    
    try {
        # Save command text
        $CommandText | Out-File -FilePath $CommandFile -Encoding UTF8 -Force
        
        # Create status tracking
        $status = @{
            Command = $CommandText
            Created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            CreatedBy = $env:USERNAME
            Computer = $env:COMPUTERNAME
            Executed = $false
            OneTimeOnly = $true
            Version = $ScriptVersion
            UniqueId = [System.Guid]::NewGuid().ToString()
        }
        
        $status | ConvertTo-Json | Out-File -FilePath $StatusFile -Encoding UTF8 -Force
        
        Write-Log "Command data saved successfully" "Green"
        Write-Log "IMPORTANT: Command will execute ONLY ONCE after next reboot!" "Yellow"
        return $true
    } catch {
        Write-Log "Failed to save command data: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Create-ExecutorScript {
    Write-Log "Creating executor script..." "Yellow"
    
    # Create the executor script content with proper escaping
    $executorContent = @'
# Free Command Executor - ONE TIME EXECUTION ONLY
# This script runs in FOREGROUND after login

param()

$WorkDir = "C:\Windows\Temp\FreeCmd"
$CommandFile = "$WorkDir\command.txt"
$StatusFile = "$WorkDir\status.json" 
$LogFile = "$WorkDir\execution.log"
$TaskName = "FreeCommandExecutor"
$LockFile = "$WorkDir\execution.lock"

function Write-ExecLog {
    param([string]$Message, [string]$Color = "White")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    
    # Always show in console (FOREGROUND execution)
    switch ($Color) {
        "Red" { Write-Host $logEntry -ForegroundColor Red }
        "Green" { Write-Host $logEntry -ForegroundColor Green }
        "Yellow" { Write-Host $logEntry -ForegroundColor Yellow }
        "Cyan" { Write-Host $logEntry -ForegroundColor Cyan }
        default { Write-Host $logEntry }
    }
    
    # Log to file
    try {
        $logEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
    } catch {
        # Continue even if logging fails
    }
}

function Test-ShouldExecute {
    Write-ExecLog "=== CHECKING EXECUTION STATUS ===" "Yellow"
    
    # Check lock file
    if (Test-Path $LockFile) {
        Write-ExecLog "BLOCKED: Lock file exists - already running or executed" "Red"
        return $false
    }
    
    # Check status file
    if (-not (Test-Path $StatusFile)) {
        Write-ExecLog "BLOCKED: Status file missing - already executed or cleaned up" "Red"
        return $false
    }
    
    try {
        $status = Get-Content $StatusFile -Raw | ConvertFrom-Json
        
        if ($status.Executed -eq $true) {
            Write-ExecLog "BLOCKED: Already executed (marked in status)" "Red"
            return $false
        }
        
        if ($status.OneTimeOnly -ne $true) {
            Write-ExecLog "BLOCKED: Not marked for one-time execution" "Red"
            return $false
        }
        
        Write-ExecLog "APPROVED: Ready for ONE-TIME execution" "Green"
        Write-ExecLog "Command: $($status.Command)" "Cyan"
        Write-ExecLog "Created by: $($status.CreatedBy) on $($status.Created)" "Gray"
        
        return $true
        
    } catch {
        Write-ExecLog "BLOCKED: Cannot read status file: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Set-ExecutionLock {
    try {
        $lockData = @{
            StartTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            ProcessId = $PID
            Purpose = "Prevent concurrent execution"
        }
        $lockData | ConvertTo-Json | Out-File -FilePath $LockFile -Encoding UTF8 -Force
        Write-ExecLog "Execution lock created" "Green"
    } catch {
        Write-ExecLog "Warning: Could not create lock: $($_.Exception.Message)" "Yellow"
    }
}

function Mark-AsExecuted {
    try {
        if (Test-Path $StatusFile) {
            $status = Get-Content $StatusFile -Raw | ConvertFrom-Json
            $status.Executed = $true
            $status.ExecutedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $status.ExecutedBy = $env:USERNAME
            $status | ConvertTo-Json | Out-File -FilePath $StatusFile -Encoding UTF8 -Force
            Write-ExecLog "Marked as executed - will NEVER run again" "Yellow"
        }
    } catch {
        Write-ExecLog "Warning: Could not update status: $($_.Exception.Message)" "Yellow"
    }
}

function Invoke-UserCommand {
    Write-ExecLog "=== STARTING COMMAND EXECUTION ===" "Cyan"
    
    # Final execution check
    if (-not (Test-ShouldExecute)) {
        Write-ExecLog "=== EXECUTION CANCELLED ===" "Red"
        Start-Cleanup
        return
    }
    
    # Set lock and mark as executed IMMEDIATELY
    Set-ExecutionLock
    Mark-AsExecuted
    
    try {
        # Read command
        if (-not (Test-Path $CommandFile)) {
            Write-ExecLog "ERROR: Command file not found" "Red"
            Start-Cleanup
            return
        }
        
        $commandText = Get-Content $CommandFile -Raw -Encoding UTF8
        $commandText = $commandText.Trim()
        
        if ([string]::IsNullOrWhiteSpace($commandText)) {
            Write-ExecLog "ERROR: Command is empty" "Red"
            Start-Cleanup
            return
        }
        
        Write-ExecLog "=== EXECUTING COMMANDS ===" "Green"
        Write-ExecLog "Command(s): $commandText" "White"
        
        # Set execution policy for this session
        try {
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            Write-ExecLog "Execution policy set to Bypass" "Green"
        } catch {
            Write-ExecLog "Warning: Could not set execution policy: $($_.Exception.Message)" "Yellow"
        }
        
        # Execute the command(s) - supports multiple commands with semicolon
        # This handles: single commands, multiple commands, functions, etc.
        Write-ExecLog "*** EXECUTING YOUR COMMANDS ***" "Cyan"
        
        try {
            # Use Invoke-Expression to handle complex command strings with semicolons
            $result = Invoke-Expression $commandText 2>&1
            
            if ($result) {
                $resultString = $result | Out-String
                Write-ExecLog "Command output:" "Green"
                Write-Host $resultString
                Write-ExecLog "Output logged to file" "Gray"
            } else {
                Write-ExecLog "Commands executed successfully (no output)" "Green"
            }
            
            Write-ExecLog "*** COMMAND EXECUTION COMPLETED SUCCESSFULLY ***" "Green"
            
        } catch {
            Write-ExecLog "ERROR during execution: $($_.Exception.Message)" "Red"
            
            # Try alternative execution for complex commands
            Write-ExecLog "Trying alternative execution method..." "Yellow"
            try {
                # Split by semicolon and execute each command separately
                $commands = $commandText -split ';'
                foreach ($cmd in $commands) {
                    $cmd = $cmd.Trim()
                    if (-not [string]::IsNullOrWhiteSpace($cmd)) {
                        Write-ExecLog "Executing: $cmd" "Cyan"
                        $cmdResult = Invoke-Expression $cmd 2>&1
                        if ($cmdResult) {
                            Write-Host ($cmdResult | Out-String)
                        }
                    }
                }
                Write-ExecLog "Alternative execution completed" "Green"
            } catch {
                Write-ExecLog "Alternative execution failed: $($_.Exception.Message)" "Red"
            }
        }
        
        Write-ExecLog "=== EXECUTION PHASE COMPLETED ===" "Yellow"
        
    } catch {
        Write-ExecLog "CRITICAL ERROR: $($_.Exception.Message)" "Red"
    } finally {
        # Always cleanup
        Write-ExecLog "Starting cleanup..." "Yellow"
        Start-Cleanup
    }
}

function Start-Cleanup {
    Write-ExecLog "=== CLEANUP - REMOVING ALL TRACES ===" "Yellow"
    
    try {
        # Remove lock file
        if (Test-Path $LockFile) {
            Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
            Write-ExecLog "Removed lock file" "Green"
        }
        
        # Delete scheduled task - multiple methods for reliability
        try {
            & schtasks.exe /delete /tn $TaskName /f 2>&1 | Out-Null
            Write-ExecLog "Deleted scheduled task (schtasks)" "Green"
        } catch {}
        
        try {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-ExecLog "Deleted scheduled task (PowerShell)" "Green"
        } catch {}
        
        # Create cleanup script with proper path escaping
        $cleanupScriptContent = @"
Start-Sleep -Seconds 5
try {
    Remove-Item 'C:\Windows\Temp\FreeCmd\*' -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item 'C:\Windows\Temp\FreeCmd' -Force -ErrorAction SilentlyContinue
    Remove-Item 'C:\Windows\Temp\FreeCmd_Cleanup.ps1' -Force -ErrorAction SilentlyContinue
} catch {}
"@
        
        $cleanupScriptPath = "C:\Windows\Temp\FreeCmd_Cleanup.ps1"
        $cleanupScriptContent | Out-File -FilePath $cleanupScriptPath -Encoding UTF8 -Force
        
        $argumentList = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$cleanupScriptPath`""
        Start-Process powershell.exe -ArgumentList $argumentList -WindowStyle Hidden
        
        Write-ExecLog "Scheduled complete cleanup" "Green"
        Write-ExecLog "=== CLEANUP COMPLETED - WILL NEVER RUN AGAIN ===" "Yellow"
        
        # Give user time to see the results
        Write-ExecLog "" "White"
        Write-ExecLog "Command execution completed. Window will close in 10 seconds..." "Cyan"
        Write-ExecLog "Press any key to close immediately." "Gray"
        
        # Wait with timeout
        $timeout = 10
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        
        while ($timer.Elapsed.TotalSeconds -lt $timeout) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                break
            }
            Start-Sleep -Milliseconds 100
        }
        
    } catch {
        Write-ExecLog "Cleanup error: $($_.Exception.Message)" "Red"
    }
}

# ===== MAIN EXECUTION =====
try {
    Write-ExecLog "=== FREE COMMAND EXECUTOR STARTED ===" "Cyan"
    $userInfo = "$env:USERNAME on $env:COMPUTERNAME"
    Write-ExecLog "User: $userInfo" "Gray"
    Write-ExecLog "Time: $(Get-Date)" "Gray"
    Write-ExecLog "Process ID: $PID" "Gray"
    
    # Wait for system stabilization
    Write-ExecLog "Waiting 10 seconds for system stabilization..." "Yellow"
    Start-Sleep -Seconds 10
    
    # Execute the user command
    Invoke-UserCommand
    
    Write-ExecLog "=== EXECUTOR COMPLETED ===" "Green"
    
} catch {
    Write-ExecLog "CRITICAL ERROR: $($_.Exception.Message)" "Red"
    try {
        Start-Cleanup
    } catch {
        Write-ExecLog "Emergency cleanup failed: $($_.Exception.Message)" "Red"
    }
}
'@

    try {
        $executorContent | Out-File -FilePath $ScriptPath -Encoding UTF8 -Force
        Write-Log "Executor script created: $ScriptPath" "Green"
        
        if (Test-Path $ScriptPath) {
            return $true
        } else {
            throw "Script file not created"
        }
    } catch {
        Write-Log "Failed to create executor script: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Remove-OldTasks {
    Write-Log "Cleaning up old tasks..." "Yellow"
    
    $oldTasks = @(
        "FreeCommandExecutor", "AutoCustomCommandTask", "KeyboardSleepTask", 
        "PostBootPowerConfig", "PostLoginPowerConfig", "AutoSleepTask"
    )
    
    foreach ($task in $oldTasks) {
        try {
            & schtasks.exe /delete /tn $task /f 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Removed old task: $task" "Green"
            }
        } catch {}
        
        try {
            Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
        } catch {}
    }
}

function Create-ScheduledTask {
    Write-Log "Creating scheduled task for one-time execution..." "Yellow"
    
    $currentUser = $env:USERNAME
    $currentDomain = $env:USERDOMAIN  
    $computerName = $env:COMPUTERNAME
    
    # User format options for different environments
    $userFormats = @(
        "$computerName\$currentUser",
        ".\$currentUser", 
        "$currentUser",
        "$currentDomain\$currentUser"
    )
    
    # FOREGROUND execution command - visible PowerShell window
    $taskCommand = "powershell.exe -ExecutionPolicy Bypass -NoProfile -File `"$ScriptPath`""
    
    Write-Log "Task command: $taskCommand" "Gray"
    
    # Method 1: Simple schtasks (most reliable)
    foreach ($userFormat in $userFormats) {
        try {
            Write-Log "Trying user format: $userFormat" "Gray"
            
            $result = & schtasks.exe /create /tn $TaskName /tr $taskCommand /sc ONLOGON /ru $userFormat /rl HIGHEST /f 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Task created successfully with user: $userFormat" "Green"
                return $true
            }
        } catch {
            Write-Log "Failed with user format $userFormat" "Gray"
        }
    }
    
    # Method 2: XML-based task creation
    Write-Log "Trying XML method..." "Yellow"
    
    foreach ($userFormat in $userFormats) {
        try {
            $taskXmlContent = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Free Command Executor - One-time execution</Description>
    <Author>$userFormat</Author>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$userFormat</UserId>
      <Delay>PT5S</Delay>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$userFormat</UserId>
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
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>6</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -NoProfile -File "$ScriptPath"</Arguments>
      <WorkingDirectory>$WorkDir</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@
            
            $xmlPath = "$WorkDir\task.xml"
            $taskXmlContent | Out-File -FilePath $xmlPath -Encoding Unicode -Force
            
            $result = & schtasks.exe /create /tn $TaskName /xml $xmlPath /f 2>&1
            Remove-Item $xmlPath -Force -ErrorAction SilentlyContinue
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "XML method successful with user: $userFormat" "Green"
                return $true
            }
        } catch {
            Write-Log "XML method failed with user: $userFormat" "Gray"
        }
    }
    
    # Method 3: PowerShell cmdlets
    Write-Log "Trying PowerShell cmdlets..." "Yellow"
    
    try {
        if (Get-Module -Name ScheduledTasks -ListAvailable) {
            Import-Module ScheduledTasks -Force
            
            foreach ($userFormat in $userFormats) {
                try {
                    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$ScriptPath`"" -WorkingDirectory $WorkDir
                    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userFormat  
                    $principal = New-ScheduledTaskPrincipal -UserId $userFormat -RunLevel Highest -LogonType Interactive
                    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
                    
                    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
                    
                    Write-Log "PowerShell cmdlets successful with user: $userFormat" "Green"
                    return $true
                } catch {
                    Write-Log "PowerShell cmdlets failed with user: $userFormat" "Gray"
                }
            }
        }
    } catch {
        Write-Log "PowerShell cmdlets not available or failed" "Gray"
    }
    
    Write-Log "ALL TASK CREATION METHODS FAILED!" "Red"
    return $false
}

function Test-TaskExists {
    Write-Log "Verifying task creation..." "Yellow"
    
    try {
        # Method 1: schtasks query
        $result = & schtasks.exe /query /tn $TaskName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Task verified via schtasks: $TaskName" "Green"
            return $true
        }
        
        # Method 2: PowerShell
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($task) {
            Write-Log "Task verified via PowerShell: $TaskName" "Green"
            return $true
        }
        
        Write-Log "Task verification failed" "Red"
        return $false
        
    } catch {
        Write-Log "Task verification error: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Show-FinalSummary {
    param([string]$CommandText, [bool]$TaskCreated)
    
    Write-Log "" "White"
    Write-Log "=== SETUP SUMMARY ===" "Cyan"
    Write-Log "Command(s): $CommandText" "White"
    Write-Log "Execution: ONE TIME ONLY after next login" "Yellow"
    Write-Log "Display: FOREGROUND (visible PowerShell window)" "Yellow"
    Write-Log "Multiple commands: Supported (semicolon separated)" "Yellow"
    Write-Log "Functions: Supported" "Yellow"
    Write-Log "" "White"
    
    if ($TaskCreated) {
        Write-Log "✓ Task created successfully" "Green"
        Write-Log "✓ Executor script ready" "Green"
        Write-Log "✓ Command data saved" "Green"
        Write-Log "✓ One-time execution configured" "Green"
        Write-Log "" "White"
        
        if (-not $SkipReboot) {
            Write-Log "Ready to reboot! Your command(s) will run ONCE after login." "Cyan"
            Write-Log "IMPORTANT: Commands run in FOREGROUND - you'll see the window!" "Yellow"
            Write-Log "" "White"
            Write-Log "Rebooting in 10 seconds... Press Ctrl+C to cancel" "Red"
            
            for ($i = 10; $i -ge 1; $i--) {
                Write-Host "$i..." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
            
            Write-Log "REBOOTING NOW!" "Red"
            Restart-Computer -Force
        } else {
            Write-Log "Setup complete! Reboot when ready." "Green"
            Write-Log "Command will execute ONCE after next login." "Yellow"
        }
    } else {
        Write-Log "✗ Task creation failed" "Red"
        Write-Log "Manual execution option:" "Yellow"
        Write-Log "  powershell -ExecutionPolicy Bypass -File `"$ScriptPath`"" "Gray"
        Write-Log "" "White"
        Write-Log "The manual execution will also be ONE-TIME only!" "Yellow"
    }
}

# ===== MAIN SCRIPT EXECUTION =====

Write-Log "=== FREE COMMAND SETUP - FIXED VERSION ===" "Cyan"
Write-Log "Version: $ScriptVersion" "Gray"
Write-Log "PowerShell: $($PSVersionTable.PSVersion)" "Gray"
Write-Log "User: $env:USERNAME" "Gray"
Write-Log "Computer: $env:COMPUTERNAME" "Gray"

# Check admin rights
if (-not (Test-AdminRights)) {
    Write-Log "ADMINISTRATOR PRIVILEGES REQUIRED!" "Red"
    Write-Log "Please run PowerShell as Administrator and try again." "Yellow"
    Write-Log "Right-click PowerShell → 'Run as Administrator'" "Gray"
    exit 1
}

Write-Log "Administrator privileges confirmed" "Green"

# Initialize environment
if (-not (Initialize-Environment)) {
    Write-Log "Environment initialization failed. Exiting." "Red"
    exit 1
}

# Clean up old tasks
Remove-OldTasks

# Get command input
$userCommand = Get-CommandInput

# Save command data
if (-not (Save-CommandData -CommandText $userCommand)) {
    Write-Log "Failed to save command data. Exiting." "Red"
    exit 1
}

# Create executor script
if (-not (Create-ExecutorScript)) {
    Write-Log "Failed to create executor script. Exiting." "Red"
    exit 1
}

# Create scheduled task
$taskCreated = Create-ScheduledTask

# Verify task creation
if ($taskCreated) {
    $taskCreated = Test-TaskExists
}

# Show final summary and optionally reboot
Show-FinalSummary -CommandText $userCommand -TaskCreated $taskCreated

Write-Log "Script execution completed." "Green"
