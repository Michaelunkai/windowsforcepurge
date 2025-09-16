# Bulletproof Sleep Script - PowerShell 5 Compatible (FIXED with SS Function)
# Run as Administrator

param(
    [switch]$SkipReboot
)

Write-Host "=== BULLETPROOF SLEEP SCRIPT - PS5 COMPATIBLE ===" -ForegroundColor Cyan
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
$oldTasks = @("KeyboardSleepTask", "PostBootPowerConfig", "PostLoginPowerConfig", "PostLoginPowerShell", "AutoSleepTask")
foreach ($taskName in $oldTasks) {
    try {
        $null = schtasks /delete /tn $taskName /f 2>$null
        Write-Host "Deleted old task: $taskName" -ForegroundColor Green
    } catch {
        Write-Host "Task $taskName didn't exist" -ForegroundColor Gray
    }
}

# STEP 2: Create the sleep script with SS function
Write-Host ""
Write-Host "=== CREATING SLEEP SCRIPT ===" -ForegroundColor Yellow

$scriptDir = "C:\Windows\Temp"
$scriptPath = Join-Path $scriptDir "AutoSleep.ps1"

# Ensure directory exists
if (-not (Test-Path $scriptDir)) {
    $null = New-Item -ItemType Directory -Path $scriptDir -Force
}

# Create the sleep script content with your SS function
$sleepScript = @'
# Auto Sleep Script with SS Function - PowerShell 5 Compatible
param()

$logPath = "C:\Windows\Temp\AutoSleep.log"
function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logPath -Append -Force
}

function ss {
    Write-Log "Starting SS function..."
    
    try {
        # Enable Hibernate (if not already enabled)
        Write-Log "Enabling hibernate..."
        powercfg /hibernate on
        
        # Disable the requirement to enter a password after waking up
        Write-Log "Configuring power settings..."
        powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0
        powercfg /apply
        
        # Set the system to hibernate immediately
        Write-Log "Stopping OneDrive..."
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
        
        # Configure wake-up devices - allow only keyboard
        Write-Log "Configuring wake-up devices..."
        
        # Disable wake-up for all devices first
        try {
            $allDevices = powercfg -devicequery wake_armed
            foreach ($dev in $allDevices) {
                if ($dev -notlike "*Keyboard*") {
                    powercfg -devicedisablewake $dev
                    Write-Log "Disabled wake for device: $dev"
                }
            }
        } catch {
            Write-Log "Error configuring wake devices: $($_.Exception.Message)"
        }
        
        # Enable wake for keyboard devices
        try {
            $devices = Get-WmiObject -Query "SELECT * FROM Win32_PnPEntity WHERE Description LIKE '%Keyboard%'"
            foreach ($device in $devices) {
                powercfg -deviceenablewake $device.Name
                Write-Log "Enabled wake for keyboard: $($device.Name)"
            }
        } catch {
            Write-Log "Error enabling keyboard wake: $($_.Exception.Message)"
        }
        
        # Registry settings
        Write-Log "Setting registry entries..."
        try {
            reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v InactivityTimeoutSecs /t REG_DWORD /d 0 /f
            reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v AllowDomainPINLogon /t REG_DWORD /d 1 /f
        } catch {
            Write-Log "Error setting registry: $($_.Exception.Message)"
        }
        
        Write-Log "SS function configuration complete, preparing to hibernate..."
        
        # Wait a moment for settings to apply
        Start-Sleep -Seconds 2
        
        # Hibernate the system
        Write-Log "Hibernating system now..."
        rundll32.exe powrprof.dll,SetSuspendState Hibernate
        
    } catch {
        Write-Log "Error in SS function: $($_.Exception.Message)"
        
        # Fallback hibernation
        Write-Log "Attempting fallback hibernation..."
        try {
            cmd /c "powercfg /hibernate on"
            cmd /c "rundll32.exe powrprof.dll,SetSuspendState Hibernate"
            Write-Log "Fallback hibernation executed"
        } catch {
            Write-Log "Fallback failed: $($_.Exception.Message)"
        }
    }
}

try {
    Write-Log "AutoSleep script started"

    Write-Log "Waiting 10 seconds after login..."
    Start-Sleep -Seconds 10
    Write-Log "10 seconds elapsed, executing SS function"

    # Execute the SS function
    ss
    
    Write-Log "SS function executed successfully"

} catch {
    Write-Log "Error in main script: $($_.Exception.Message)"
    
    # Fallback hibernation
    Write-Log "Attempting fallback hibernation"
    try {
        cmd /c "powercfg /hibernate on"
        cmd /c "rundll32.exe powrprof.dll,SetSuspendState Hibernate"
        Write-Log "Fallback hibernation executed"
    } catch {
        Write-Log "Fallback failed: $($_.Exception.Message)"
    }
}

# Wait a bit before cleanup
Start-Sleep -Seconds 3
Write-Log "Starting cleanup..."

try {
    # Delete the scheduled task
    cmd /c "schtasks /delete /tn AutoSleepTask /f" 2>$null
    Write-Log "Deleted scheduled task"

    # Create self-deletion script
    $deleteScript = @"
Start-Sleep -Seconds 5
Remove-Item 'C:\Windows\Temp\AutoSleep.ps1' -Force -ErrorAction SilentlyContinue
Remove-Item 'C:\Windows\Temp\DeleteAutoSleep.ps1' -Force -ErrorAction SilentlyContinue
"@

    $deleteScript | Out-File -FilePath "C:\Windows\Temp\DeleteAutoSleep.ps1" -Encoding ASCII -Force
    Start-Process -FilePath "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Temp\DeleteAutoSleep.ps1" -WindowStyle Hidden

    Write-Log "Scheduled self-deletion"

} catch {
    Write-Log "Cleanup error: $($_.Exception.Message)"
}

Write-Log "AutoSleep script completed"
'@

# Write the script to file
try {
    $sleepScript | Out-File -FilePath $scriptPath -Encoding ASCII -Force
    Write-Host "Sleep script created successfully at: $scriptPath" -ForegroundColor Green

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

$taskName = "AutoSleepTask"
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
    Write-Host "  • Execute SS function (configure power settings)" -ForegroundColor White
    Write-Host "  • Stop OneDrive and hibernate system" -ForegroundColor White
    Write-Host "  • Configure keyboard-only wake-up" -ForegroundColor White
    Write-Host "  • Task will delete itself permanently" -ForegroundColor White
    Write-Host "  • Log file will be created at: C:\Windows\Temp\AutoSleep.log" -ForegroundColor White
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
    Write-Host "Log file: C:\Windows\Temp\AutoSleep.log" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To test manually run the script file directly" -ForegroundColor Yellow
    Write-Host "To check task status: schtasks /query /tn AutoSleepTask" -ForegroundColor Yellow
}
