# Bulletproof Custom Command Script - PowerShell 5 Compatible
# Run as Administrator

param(
    [switch]$SkipReboot
)

Write-Host "=== CUSTOM COMMAND AFTER REBOOT SCRIPT - PS5 COMPATIBLE ===" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-NOT $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# STEP 1: Clean up all old broken tasks
Write-Host ""
Write-Host "=== CLEANING UP OLD TASKS ===" -ForegroundColor Yellow
$oldTasks = @("KeyboardSleepTask", "PostBootPowerConfig", "PostLoginPowerConfig", "PostLoginPowerShell", "AutoSleepTask", "AutoFitFitTask", "AutoDkillTask", "AutoCustomCommandTask")
foreach ($taskName in $oldTasks) {
    try {
        $null = schtasks /delete /tn $taskName /f 2>$null
        Write-Host "Deleted old task: $taskName" -ForegroundColor Green
    } catch {
        Write-Host "Task $taskName didn't exist" -ForegroundColor Gray
    }
}

# STEP 2: Get custom command from user
Write-Host ""
Write-Host "=== COMMAND INPUT ===" -ForegroundColor Yellow
Write-Host "Enter the PowerShell command you want to run after reboot:" -ForegroundColor White
Write-Host "Examples:" -ForegroundColor Gray
Write-Host "  - dkill" -ForegroundColor Gray
Write-Host "  - Get-Process | Where-Object {`$_.Name -eq 'notepad'} | Stop-Process" -ForegroundColor Gray
Write-Host "  - Start-Process notepad" -ForegroundColor Gray
Write-Host "  - Write-Host 'Hello World!'" -ForegroundColor Gray
Write-Host ""

do {
    $customCommand = Read-Host "Command"
    if ([string]::IsNullOrWhiteSpace($customCommand)) {
        Write-Host "Please enter a valid command." -ForegroundColor Red
    }
} while ([string]::IsNullOrWhiteSpace($customCommand))

Write-Host ""
Write-Host "You entered: $customCommand" -ForegroundColor Green
$confirmation = Read-Host "Is this correct? (y/n)"
if ($confirmation -notmatch '^[yY]') {
    Write-Host "Script cancelled." -ForegroundColor Yellow
    exit 0
}

# STEP 3: Create the custom command script
Write-Host ""
Write-Host "=== CREATING CUSTOM COMMAND SCRIPT ===" -ForegroundColor Yellow

$scriptDir = "C:\Windows\Temp"
$scriptPath = Join-Path $scriptDir "AutoCustomCommand.ps1"
$commandPath = Join-Path $scriptDir "CustomCommand.txt"

# Ensure directory exists
if (-not (Test-Path $scriptDir)) {
    $null = New-Item -ItemType Directory -Path $scriptDir -Force
}

# Save the custom command to a file
try {
    $customCommand | Out-File -FilePath $commandPath -Encoding UTF8 -Force
    Write-Host "Custom command saved to: $commandPath" -ForegroundColor Green
} catch {
    Write-Host "FAILED to save custom command: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create the custom command script content
$customCommandScript = @'
# Auto Custom Command Script - PowerShell 5 Compatible
param()

$logPath = "C:\Windows\Temp\AutoCustomCommand.log"
$commandPath = "C:\Windows\Temp\CustomCommand.txt"

function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logPath -Append -Force
}

function Run-CustomCommand {
    Write-Log "Starting Custom Command function..."

    try {
        # Read the custom command from file
        if (Test-Path $commandPath) {
            $customCommand = Get-Content $commandPath -Raw -Encoding UTF8
            $customCommand = $customCommand.Trim()
            Write-Log "Custom command loaded: $customCommand"
        } else {
            Write-Log "ERROR: Custom command file not found at $commandPath"
            return
        }

        if ([string]::IsNullOrWhiteSpace($customCommand)) {
            Write-Log "ERROR: Custom command is empty"
            return
        }

        Write-Log "Executing custom command in PowerShell..."

        # Execute custom command
        $commandResult = Invoke-Expression $customCommand 2>&1

        if ($commandResult) {
            Write-Log "Command output: $commandResult"
        } else {
            Write-Log "Command executed successfully with no output"
        }

        Write-Log "Custom command completed successfully"

    } catch {
        Write-Log "Error in Custom Command function: $($_.Exception.Message)"

        # Fallback - try running command via cmd
        Write-Log "Attempting fallback command execution via cmd..."
        try {
            $cmdResult = cmd /c "powershell -Command `"$customCommand`"" 2>&1
            Write-Log "Fallback command result: $cmdResult"
        } catch {
            Write-Log "Fallback failed: $($_.Exception.Message)"
        }
    }
}

try {
    Write-Log "AutoCustomCommand script started"

    Write-Log "Waiting 10 seconds after login..."
    Start-Sleep -Seconds 10
    Write-Log "10 seconds elapsed, executing Custom Command function"

    # Execute the Custom Command function
    Run-CustomCommand

    Write-Log "Custom Command function executed successfully"

} catch {
    Write-Log "Error in main script: $($_.Exception.Message)"

    # Fallback command execution
    Write-Log "Attempting fallback command execution"
    try {
        if (Test-Path $commandPath) {
            $fallbackCommand = Get-Content $commandPath -Raw -Encoding UTF8
            $fallbackCommand = $fallbackCommand.Trim()
            $fallbackResult = cmd /c "powershell -Command `"$fallbackCommand`"" 2>&1
            Write-Log "Fallback command executed: $fallbackResult"
        }
    } catch {
        Write-Log "Fallback failed: $($_.Exception.Message)"
    }
}

# Wait a bit before cleanup
Start-Sleep -Seconds 3
Write-Log "Starting cleanup..."

try {
    # Delete the scheduled task
    cmd /c "schtasks /delete /tn AutoCustomCommandTask /f" 2>$null
    Write-Log "Deleted scheduled task"

    # Delete the command file
    Remove-Item $commandPath -Force -ErrorAction SilentlyContinue
    Write-Log "Deleted command file"

    # Create self-deletion script
    $deleteScript = @"
Start-Sleep -Seconds 5
Remove-Item 'C:\Windows\Temp\AutoCustomCommand.ps1' -Force -ErrorAction SilentlyContinue
Remove-Item 'C:\Windows\Temp\DeleteAutoCustomCommand.ps1' -Force -ErrorAction SilentlyContinue
"@

    $deleteScript | Out-File -FilePath "C:\Windows\Temp\DeleteAutoCustomCommand.ps1" -Encoding ASCII -Force
    Start-Process -FilePath "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Temp\DeleteAutoCustomCommand.ps1" -WindowStyle Hidden

    Write-Log "Scheduled self-deletion"

} catch {
    Write-Log "Cleanup error: $($_.Exception.Message)"
}

Write-Log "AutoCustomCommand script completed"
'@

# Write the script to file
try {
    $customCommandScript | Out-File -FilePath $scriptPath -Encoding ASCII -Force
    Write-Host "Custom command script created successfully at: $scriptPath" -ForegroundColor Green

    if (Test-Path $scriptPath) {
        $fileSize = (Get-Item $scriptPath).Length
        Write-Host "File size: $fileSize bytes" -ForegroundColor Gray
    } else {
        throw "Script file was not created"
    }

} catch {
    Write-Host "FAILED to create script file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# STEP 4: Create the scheduled task
Write-Host ""
Write-Host "=== CREATING SCHEDULED TASK ===" -ForegroundColor Yellow

$taskName = "AutoCustomCommandTask"
$userName = $env:USERNAME
$taskCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

Write-Host "Task name: $taskName" -ForegroundColor Gray
Write-Host "User: $userName" -ForegroundColor Gray
Write-Host "Command: $taskCommand" -ForegroundColor Gray

$taskCreated = $false

# Method 1: Try schtasks command
Write-Host "Trying schtasks method..." -ForegroundColor Yellow
try {
    $result = schtasks /create /tn $taskName /tr $taskCommand /sc ONLOGON /ru $userName /rl HIGHEST /f 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "schtasks method successful!" -ForegroundColor Green
        $taskCreated = $true
    } else {
        Write-Host "schtasks failed: $result" -ForegroundColor Red
    }
} catch {
    Write-Host "schtasks exception: $($_.Exception.Message)" -ForegroundColor Red
}

# Method 2: Try PowerShell cmdlets if schtasks failed
if (-not $taskCreated) {
    Write-Host "Trying PowerShell cmdlets method..." -ForegroundColor Yellow
    try {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userName
        $principal = New-ScheduledTaskPrincipal -UserId $userName -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        $null = Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force

        Write-Host "PowerShell cmdlets method successful!" -ForegroundColor Green
        $taskCreated = $true

    } catch {
        Write-Host "PowerShell cmdlets failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Method 3: XML method if both failed
if (-not $taskCreated) {
    Write-Host "Trying manual XML method..." -ForegroundColor Yellow
    try {
        $taskXML = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$userName</UserId>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$userName</UserId>
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
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -WindowStyle Hidden -File "$scriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

        $xmlPath = "C:\Windows\Temp\task.xml"
        $taskXML | Out-File -FilePath $xmlPath -Encoding Unicode -Force

        $result = schtasks /create /tn $taskName /xml $xmlPath /f 2>&1

        Remove-Item $xmlPath -Force -ErrorAction SilentlyContinue

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Manual XML method successful!" -ForegroundColor Green
            $taskCreated = $true
        } else {
            Write-Host "Manual XML method failed: $result" -ForegroundColor Red
        }

    } catch {
        Write-Host "Manual XML method exception: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# STEP 5: Verify task creation
Write-Host ""
Write-Host "=== VERIFYING TASK CREATION ===" -ForegroundColor Yellow

if ($taskCreated) {
    try {
        $verification = schtasks /query /tn $taskName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "TASK VERIFIED: $taskName exists and is ready!" -ForegroundColor Green
        } else {
            Write-Host "Task verification failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "Task verification error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "TASK CREATION FAILED - All methods failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "=== MANUAL ALTERNATIVE ===" -ForegroundColor Cyan
    Write-Host "You can run the script manually: $scriptPath" -ForegroundColor Yellow
    Write-Host "Or create the task manually in Task Scheduler GUI" -ForegroundColor Yellow
}

# STEP 6: Clean up system for reboot
Write-Host ""
Write-Host "=== PREPARING FOR REBOOT ===" -ForegroundColor Yellow

$processesToClose = @("chrome", "firefox", "msedge", "teams", "outlook", "excel", "word", "powerpoint")
foreach ($processName in $processesToClose) {
    $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($processes) {
        $processes | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

$explorerProcesses = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
if ($explorerProcesses) {
    $explorerProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
}

# STEP 7: Reboot or show summary
if (-not $SkipReboot) {
    Write-Host ""
    Write-Host "=== READY FOR REBOOT ===" -ForegroundColor Cyan
    Write-Host "After reboot the system will:" -ForegroundColor White
    Write-Host "  • Wait 10 seconds after login" -ForegroundColor White
    Write-Host "  • Execute your custom command: $customCommand" -ForegroundColor White
    Write-Host "  • Task will delete itself permanently" -ForegroundColor White
    Write-Host "  • Log file will be created at: C:\Windows\Temp\AutoCustomCommand.log" -ForegroundColor White
    Write-Host ""
    Write-Host "Rebooting in 5 seconds..." -ForegroundColor Red
    Write-Host "Press Ctrl+C to cancel..." -ForegroundColor Yellow

    for ($i = 5; $i -ge 1; $i--) {
        Write-Host "$i..." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }

    Write-Host "REBOOTING NOW!" -ForegroundColor Red
    Restart-Computer -Force

} else {
    Write-Host ""
    Write-Host "=== SETUP COMPLETE ===" -ForegroundColor Green
    Write-Host "Script path: $scriptPath" -ForegroundColor Gray
    Write-Host "Command file: $commandPath" -ForegroundColor Gray
    Write-Host "Task name: $taskName" -ForegroundColor Gray
    Write-Host "Custom command: $customCommand" -ForegroundColor Gray
    Write-Host "Log file: C:\Windows\Temp\AutoCustomCommand.log" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To test manually run the script file directly" -ForegroundColor Yellow
    Write-Host "To check task status: schtasks /query /tn AutoCustomCommandTask" -ForegroundColor Yellow
}
