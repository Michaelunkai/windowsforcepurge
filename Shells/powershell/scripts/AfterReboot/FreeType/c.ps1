# Bulletproof Custom Command Script - PowerShell 5 Compatible - FIXED VERSION
# Run as Administrator
# Usage: ./script.ps1 'your command here'

param(
    [string]$Command = "",
    [switch]$SkipReboot,
    [switch]$Debug
)

# Global variables
$ScriptVersion = "2.0-FIXED"
$ScriptDir = "C:\Windows\Temp"
$ScriptPath = Join-Path $ScriptDir "AutoCustomCommand.ps1"
$CommandPath = Join-Path $ScriptDir "CustomCommand.txt"
$FlagPath = Join-Path $ScriptDir "CustomCommand.flag"
$TaskName = "AutoCustomCommandTask"
$LogPath = Join-Path $ScriptDir "AutoCustomCommand.log"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    
    $ColorMap = @{
        "Red" = [System.ConsoleColor]::Red
        "Green" = [System.ConsoleColor]::Green
        "Yellow" = [System.ConsoleColor]::Yellow
        "Cyan" = [System.ConsoleColor]::Cyan
        "Gray" = [System.ConsoleColor]::Gray
        "White" = [System.ConsoleColor]::White
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
        "AutoDkillTask", "AutoCustomCommandTask"
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
    Write-ColorOutput "=== COMMAND INPUT ===" "Yellow"
    
    if ([string]::IsNullOrWhiteSpace($Command)) {
        Write-ColorOutput "Enter the PowerShell command you want to run after reboot:" "White"
        Write-ColorOutput "Examples:" "Gray"
        Write-ColorOutput "  - dkill" "Gray"
        Write-ColorOutput "  - qbit; update" "Gray"
        Write-ColorOutput "  - Get-Process | Where-Object {`$_.Name -eq 'notepad'} | Stop-Process" "Gray"
        Write-ColorOutput "  - Start-Process notepad" "Gray"
        Write-ColorOutput "  - Write-Host 'Hello World!'" "Gray"
        Write-ColorOutput "" "White"

        do {
            $UserCommand = Read-Host "Command"
            if ([string]::IsNullOrWhiteSpace($UserCommand)) {
                Write-ColorOutput "Please enter a valid command." "Red"
            }
        } while ([string]::IsNullOrWhiteSpace($UserCommand))

        Write-ColorOutput "" "White"
        Write-ColorOutput "You entered: $UserCommand" "Green"
        $Confirmation = Read-Host "Is this correct? (y/n)"
        if ($Confirmation -notmatch '^[yY]') {
            Write-ColorOutput "Script cancelled." "Yellow"
            exit 0
        }
        
        return $UserCommand
    } else {
        Write-ColorOutput "Command from parameter: $Command" "Green"
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
    
    Write-ColorOutput "=== CREATING CUSTOM COMMAND SCRIPT ===" "Yellow"
    
    try {
        # Save the custom command
        $CustomCommand | Out-File -FilePath $CommandPath -Encoding UTF8 -Force
        Write-ColorOutput "Custom command saved to: $CommandPath" "Green"
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
        }
        
        $FlagContent | ConvertTo-Json | Out-File -FilePath $FlagPath -Encoding UTF8 -Force
        Write-ColorOutput "Execution flag created: $FlagPath" "Green"
        Write-ColorOutput "IMPORTANT: Command will execute ONLY ONCE after next reboot!" "Yellow"
        
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
# Auto Custom Command Script - PowerShell 5 Compatible - ONE-TIME EXECUTION ONLY
param()

$LogPath = "C:\Windows\Temp\AutoCustomCommand.log" 
$CommandPath = "C:\Windows\Temp\CustomCommand.txt"
$FlagPath = "C:\Windows\Temp\CustomCommand.flag"
$TaskName = "AutoCustomCommandTask"
$LockFile = "C:\Windows\Temp\CustomCommand.lock"

function Write-Log {
    param([string]$Message)
    
    try {
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "$Timestamp - $Message"
        $LogEntry | Out-File -FilePath $LogPath -Append -Force -Encoding UTF8
        
        # Also write to console for immediate feedback
        Write-Host $LogEntry
    }
    catch {
        # Silently fail if logging doesn't work
        Write-Host $Message
    }
}

function Test-AlreadyExecuted {
    Write-Log "=== CHECKING ONE-TIME EXECUTION STATUS ==="
    
    # Check 1: Lock file (prevents concurrent execution)
    if (Test-Path $LockFile) {
        Write-Log "EXECUTION BLOCKED: Lock file exists - script may already be running"
        return $true
    }
    
    # Check 2: Flag file existence and content
    if (-not (Test-Path $FlagPath)) {
        Write-Log "EXECUTION BLOCKED: Flag file missing - command already executed or cleaned up"
        return $true
    }
    
    try {
        $FlagContent = Get-Content $FlagPath -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Check 3: Already executed flag
        if ($FlagContent.Executed -eq $true) {
            Write-Log "EXECUTION BLOCKED: Command already executed (flag marked as executed)"
            return $true
        }
        
        # Check 4: One-time only flag
        if ($FlagContent.OneTimeOnly -ne $true) {
            Write-Log "EXECUTION BLOCKED: Not marked as one-time execution"
            return $true
        }
        
        Write-Log "EXECUTION APPROVED: All checks passed - ready to execute ONE TIME"
        Write-Log "Command to execute: $($FlagContent.Command)"
        Write-Log "Created by: $($FlagContent.CreatedBy)"
        Write-Log "Created on: $($FlagContent.Timestamp)"
        
        return $false
        
    }
    catch {
        Write-Log "EXECUTION BLOCKED: Could not read or parse flag file: $($_.Exception.Message)"
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
        Write-Log "Lock file created to prevent re-execution"
    }
    catch {
        Write-Log "Warning: Could not create lock file: $($_.Exception.Message)"
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
            Write-Log "FLAG UPDATED: Marked as executed - will NEVER run again"
        }
    }
    catch {
        Write-Log "Warning: Could not update execution flag: $($_.Exception.Message)"
    }
}

function Invoke-CustomCommand {
    Write-Log "=== STARTING ONE-TIME COMMAND EXECUTION ==="

    # CRITICAL: Check if we should execute (one-time only)
    if (Test-AlreadyExecuted) {
        Write-Log "=== EXECUTION CANCELLED - ALREADY RAN OR BLOCKED ==="
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
            Write-Log "Custom command loaded: $CustomCommand"
        } else {
            Write-Log "ERROR: Custom command file not found at $CommandPath"
            Start-ImmediateCleanup
            return
        }

        if ([string]::IsNullOrWhiteSpace($CustomCommand)) {
            Write-Log "ERROR: Custom command is empty"
            Start-ImmediateCleanup
            return
        }

        # CRITICAL: Mark as executed IMMEDIATELY to prevent any re-execution
        Write-Log "=== MARKING AS EXECUTED TO PREVENT RE-EXECUTION ==="
        Mark-AsExecuted

        Write-Log "=== EXECUTING YOUR CUSTOM COMMAND (ONE TIME ONLY) ==="

        # Set execution policy temporarily
        try {
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            Write-Log "Execution policy set to Bypass for this process"
        }
        catch {
            Write-Log "Warning: Could not set execution policy: $($_.Exception.Message)"
        }

        # Execute custom command with comprehensive error handling
        try {
            Write-Log "*** EXECUTING: $CustomCommand ***"
            $CommandResult = Invoke-Expression $CustomCommand 2>&1
            
            if ($CommandResult) {
                $ResultString = $CommandResult | Out-String
                Write-Log "Command output: $ResultString"
            } else {
                Write-Log "Command executed successfully with no output"
            }
            
            Write-Log "*** CUSTOM COMMAND COMPLETED SUCCESSFULLY ***"
        }
        catch {
            Write-Log "ERROR executing command: $($_.Exception.Message)"
            
            # Try alternative execution method
            Write-Log "Attempting alternative execution method..."
            try {
                $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
                $ProcessInfo.FileName = "powershell.exe"
                $ProcessInfo.Arguments = "-ExecutionPolicy Bypass -Command `"$CustomCommand`""
                $ProcessInfo.UseShellExecute = $false
                $ProcessInfo.RedirectStandardOutput = $true
                $ProcessInfo.RedirectStandardError = $true
                $ProcessInfo.CreateNoWindow = $true
                
                $Process = New-Object System.Diagnostics.Process
                $Process.StartInfo = $ProcessInfo
                $Process.Start() | Out-Null
                $Process.WaitForExit()
                
                $Output = $Process.StandardOutput.ReadToEnd()
                $Errors = $Process.StandardError.ReadToEnd()
                
                if ($Output) { Write-Log "Alternative method output: $Output" }
                if ($Errors) { Write-Log "Alternative method errors: $Errors" }
                
                Write-Log "Alternative execution method completed"
            }
            catch {
                Write-Log "Alternative execution method failed: $($_.Exception.Message)"
            }
        }

        Write-Log "=== COMMAND EXECUTION PHASE COMPLETED ==="

    }
    catch {
        Write-Log "CRITICAL ERROR in command execution: $($_.Exception.Message)"
    }
    finally {
        # Always clean up, regardless of success or failure
        Write-Log "=== STARTING CLEANUP TO PREVENT FUTURE EXECUTION ==="
        Start-ThoroughCleanup
    }
}

function Start-ImmediateCleanup {
    Write-Log "=== IMMEDIATE CLEANUP - REMOVING ALL TRACES ==="
    
    try {
        # Remove lock file
        if (Test-Path $LockFile) {
            Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
            Write-Log "Removed lock file"
        }
        
        # Delete the scheduled task immediately
        try {
            $DeleteResult = & schtasks.exe /delete /tn $TaskName /f 2>&1
            Write-Log "Task deletion result: $DeleteResult"
        }
        catch {
            Write-Log "Task deletion error: $($_.Exception.Message)"
        }
        
        # Also try PowerShell method
        try {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "PowerShell task deletion attempted"
        }
        catch {
            Write-Log "PowerShell task deletion error: $($_.Exception.Message)"
        }
        
        Write-Log "Immediate cleanup completed"
        
    }
    catch {
        Write-Log "Immediate cleanup error: $($_.Exception.Message)"
    }
}

function Start-ThoroughCleanup {
    Write-Log "=== THOROUGH CLEANUP - ENSURING NO FUTURE EXECUTION ==="

    # Wait a moment for any processes to finish
    Start-Sleep -Seconds 2

    try {
        # Remove lock file
        if (Test-Path $LockFile) {
            Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
            Write-Log "Removed lock file"
        }

        # Delete the scheduled task (multiple methods)
        try {
            $DeleteResult = & schtasks.exe /delete /tn $TaskName /f 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Successfully deleted scheduled task: $TaskName"
            } else {
                Write-Log "Task may already be deleted: $DeleteResult"
            }
        }
        catch {
            Write-Log "schtasks deletion: $($_.Exception.Message)"
        }
        
        # Also try PowerShell method
        try {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "PowerShell task deletion completed"
        }
        catch {
            Write-Log "PowerShell task deletion: $($_.Exception.Message)"
        }

        # Delete all related files
        $FilesToDelete = @($CommandPath, $FlagPath)
        foreach ($FileToDelete in $FilesToDelete) {
            if (Test-Path $FileToDelete) {
                Remove-Item $FileToDelete -Force -ErrorAction SilentlyContinue
                Write-Log "Deleted file: $FileToDelete"
            }
        }

        # Schedule self-deletion of the script
        $SelfDeleteScript = @"
# Self-deletion script - removes all traces
Start-Sleep -Seconds 3
try {
    Remove-Item 'C:\Windows\Temp\AutoCustomCommand.ps1' -Force -ErrorAction SilentlyContinue
    Remove-Item 'C:\Windows\Temp\SelfDelete.ps1' -Force -ErrorAction SilentlyContinue
    Remove-Item 'C:\Windows\Temp\CustomCommand.*' -Force -ErrorAction SilentlyContinue
} catch {}
"@

        $SelfDeletePath = "C:\Windows\Temp\SelfDelete.ps1"
        $SelfDeleteScript | Out-File -FilePath $SelfDeletePath -Encoding UTF8 -Force
        
        Start-Process -FilePath "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$SelfDeletePath`"" -WindowStyle Hidden -ErrorAction SilentlyContinue
        
        Write-Log "Scheduled complete self-deletion - all traces will be removed"
        Write-Log "=== CLEANUP COMPLETED - WILL NEVER RUN AGAIN ==="

    }
    catch {
        Write-Log "Cleanup error: $($_.Exception.Message)"
    }
}

# ========================================
# MAIN EXECUTION - ONE TIME ONLY
# ========================================

try {
    Write-Log "=== AutoCustomCommand Script Started - ONE-TIME EXECUTION ONLY ==="
    Write-Log "Current user: $env:USERNAME"
    Write-Log "Computer: $env:COMPUTERNAME"
    Write-Log "Date/Time: $(Get-Date)"

    Write-Log "Waiting 15 seconds after login for system stabilization..."
    Start-Sleep -Seconds 15
    Write-Log "System stabilization complete - proceeding with command execution"

    # Execute the custom command (ONE TIME ONLY)
    Invoke-CustomCommand

    Write-Log "=== SCRIPT EXECUTION COMPLETED - WILL NEVER RUN AGAIN ==="

}
catch {
    Write-Log "CRITICAL ERROR in main script: $($_.Exception.Message)"
    
    # Emergency cleanup
    try {
        Write-Log "Attempting emergency cleanup..."
        Start-ThoroughCleanup
    }
    catch {
        Write-Log "Emergency cleanup failed: $($_.Exception.Message)"
    }
}
'@

    try {
        $ExecutionScript | Out-File -FilePath $ScriptPath -Encoding UTF8 -Force
        Write-ColorOutput "Execution script created successfully at: $ScriptPath" "Green"
        
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
    
    # Method 1: Simple schtasks command (try first as it's most reliable)
    Write-ColorOutput "Trying simple schtasks method..." "Yellow"
    
    foreach ($UserFormat in $UserFormats) {
        try {
            Write-DebugLog "Trying user format: $UserFormat"
            
            $TaskCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File `"$ScriptPath`""
            
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
    
    Write-ColorOutput "Simple schtasks method failed with all user formats" "Red"
    
    # Method 2: XML-based task creation
    Write-ColorOutput "Trying XML method..." "Yellow"
    
    foreach ($UserFormat in $UserFormats) {
        try {
            Write-DebugLog "Trying XML with user format: $UserFormat"
            
            $TaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Auto Custom Command - One-time execution after reboot</Description>
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
      <Arguments>-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "$ScriptPath"</Arguments>
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
    
    # Method 3: PowerShell cmdlets
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
                    
                    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File `"$ScriptPath`"" -WorkingDirectory "C:\Windows\Temp"
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
        $TaskCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File `"$ScriptPath`""
        
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
            Write-ColorOutput "  • Execute your custom command: $CustomCommand" "White"
            Write-ColorOutput "  • *** COMMAND WILL RUN ONLY ONCE *** (never again after that)" "Yellow"
            Write-ColorOutput "  • Task will DELETE ITSELF immediately after execution" "White"
            Write-ColorOutput "  • All script files will be PERMANENTLY REMOVED" "White" 
            Write-ColorOutput "  • Log file will be created at: $LogPath" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "CRITICAL: This is a ONE-TIME execution. After it runs once," "Red"  
            Write-ColorOutput "it will NEVER run again, even on future reboots!" "Red"
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
        Write-ColorOutput "Custom command: $CustomCommand" "Gray"
        Write-ColorOutput "Log file: $LogPath" "Gray"
        Write-ColorOutput "" "White"
        
        if ($TaskCreated) {
            Write-ColorOutput "*** ONE-TIME EXECUTION SETUP COMPLETE ***" "Yellow"
            Write-ColorOutput "Command will run ONLY ONCE after next login!" "Yellow"
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
        Write-ColorOutput "1. Run script manually: powershell -ExecutionPolicy Bypass -File `"$ScriptPath`"" "Yellow"
        Write-ColorOutput "2. Create task manually in Task Scheduler GUI" "Yellow"
        Write-ColorOutput "3. Check Windows Event Log for task creation errors" "Yellow"
        Write-ColorOutput "" "White"
        Write-ColorOutput "NOTE: Manual execution will also be ONE-TIME only!" "Red"
    }
}

# MAIN EXECUTION
Write-ColorOutput "=== BULLETPROOF CUSTOM COMMAND SCRIPT - FIXED VERSION ===" "Cyan"
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

# Get custom command
$CustomCommand = Get-UserCommand

# Save command and create flag
if (-not (Save-CommandAndFlag -CustomCommand $CustomCommand)) {
    Write-ColorOutput "Failed to save command and flag. Exiting." "Red"
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
