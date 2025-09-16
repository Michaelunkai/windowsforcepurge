# Bulletproof FitFit Script - PowerShell 5 Compatible (MODIFIED for dkill)
# Run as Administrator

param(
    [switch]$SkipReboot
)

Write-Host "=== BULLETPROOF FITFIT SCRIPT - PS5 COMPATIBLE (DKILL MOD) ===" -ForegroundColor Cyan
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
$oldTasks = @("KeyboardSleepTask", "PostBootPowerConfig", "PostLoginPowerConfig", "PostLoginPowerShell", "AutoSleepTask", "AutoFitFitTask", "AutoDkillTask")
foreach ($taskName in $oldTasks) {
    try {
        $null = schtasks /delete /tn $taskName /f 2>$null
        Write-Host "Deleted old task: $taskName" -ForegroundColor Green
    } catch {
        Write-Host "Task $taskName didn't exist" -ForegroundColor Gray
    }
}

# STEP 2: Create the dkill script
Write-Host ""
Write-Host "=== CREATING DKILL SCRIPT ===" -ForegroundColor Yellow

$scriptDir = "C:\Windows\Temp"
$scriptPath = Join-Path $scriptDir "AutoDkill.ps1"

# Ensure directory exists
if (-not (Test-Path $scriptDir)) {
    $null = New-Item -ItemType Directory -Path $scriptDir -Force
}

# Create the dkill script content
$dkillScript = @'
# Auto Dkill Script - PowerShell 5 Compatible
param()

$logPath = "C:\Windows\Temp\AutoDkill.log"
function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logPath -Append -Force
}

function Run-Dkill {
    Write-Log "Starting Dkill function..."

    try {
        Write-Log "Executing 'dkill' command in PowerShell..."

        # Execute dkill command
        $dkillResult = Invoke-Expression "dkill" 2>&1

        if ($dkillResult) {
            Write-Log "Dkill output: $dkillResult"
        } else {
            Write-Log "Dkill executed successfully with no output"
        }

        Write-Log "Dkill command completed successfully"

    } catch {
        Write-Log "Error in Dkill function: $($_.Exception.Message)"

        # Fallback - try running dkill via cmd
        Write-Log "Attempting fallback dkill execution via cmd..."
        try {
            $cmdResult = cmd /c "powershell -Command dkill" 2>&1
            Write-Log "Fallback dkill result: $cmdResult"
        } catch {
            Write-Log "Fallback failed: $($_.Exception.Message)"
        }
    }
}

try {
    Write-Log "AutoDkill script started"

    Write-Log "Waiting 10 seconds after login..."
    Start-Sleep -Seconds 10
    Write-Log "10 seconds elapsed, executing Dkill function"

    # Execute the Dkill function
    Run-Dkill

    Write-Log "Dkill function executed successfully"

} catch {
    Write-Log "Error in main script: $($_.Exception.Message)"

    # Fallback dkill execution
    Write-Log "Attempting fallback dkill execution"
    try {
        $fallbackResult = cmd /c "powershell -Command dkill" 2>&1
        Write-Log "Fallback dkill executed: $fallbackResult"
    } catch {
        Write-Log "Fallback failed: $($_.Exception.Message)"
    }
}

# Wait a bit before cleanup
Start-Sleep -Seconds 3
Write-Log "Starting cleanup..."

try {
    # Delete the scheduled task
    cmd /c "schtasks /delete /tn AutoDkillTask /f" 2>$null
    Write-Log "Deleted scheduled task"

    # Create self-deletion script
    $deleteScript = @"
Start-Sleep -Seconds 5
Remove-Item 'C:\Windows\Temp\AutoDkill.ps1' -Force -ErrorAction SilentlyContinue
Remove-Item 'C:\Windows\Temp\DeleteAutoDkill.ps1' -Force -ErrorAction SilentlyContinue
"@

    $deleteScript | Out-File -FilePath "C:\Windows\Temp\DeleteAutoDkill.ps1" -Encoding ASCII -Force
    Start-Process -FilePath "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Temp\DeleteAutoDkill.ps1" -WindowStyle Hidden

    Write-Log "Scheduled self-deletion"

} catch {
    Write-Log "Cleanup error: $($_.Exception.Message)"
}

Write-Log "AutoDkill script completed"
'@

# Write the script to file
try {
    $dkillScript | Out-File -FilePath $scriptPath -Encoding ASCII -Force
    Write-Host "Dkill script created successfully at: $scriptPath" -ForegroundColor Green

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

# STEP 3: Create the scheduled task
Write-Host ""
Write-Host "=== CREATING SCHEDULED TASK ===" -ForegroundColor Yellow

$taskName = "AutoDkillTask"
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
            $taskCreated = true
        } else {
            Write-Host "Manual XML method failed: $result" -ForegroundColor Red
        }

    } catch {
        Write-Host "Manual XML method exception: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# STEP 4: Verify task creation
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

# STEP 5: Clean up system for reboot
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

# STEP 6: Reboot or show summary
if (-not $SkipReboot) {
    Write-Host ""
    Write-Host "=== READY FOR REBOOT ===" -ForegroundColor Cyan
    Write-Host "After reboot the system will:" -ForegroundColor White
    Write-Host "  • Wait 10 seconds after login" -ForegroundColor White
    Write-Host "  • Execute 'dkill' command in PowerShell" -ForegroundColor White
    Write-Host "  • Task will delete itself permanently" -ForegroundColor White
    Write-Host "  • Log file will be created at: C:\Windows\Temp\AutoDkill.log" -ForegroundColor White
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
    Write-Host "Task name: $taskName" -ForegroundColor Gray
    Write-Host "Log file: C:\Windows\Temp\AutoDkill.log" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To test manually run the script file directly" -ForegroundColor Yellow
    Write-Host "To check task status: schtasks /query /tn AutoDkillTask" -ForegroundColor Yellow
}
