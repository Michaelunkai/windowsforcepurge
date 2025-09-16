# Bulletproof QbitSetset Script - ONE TIME EXECUTION ONLY
# Run as Administrator

param(
    [switch]$SkipReboot
)

Write-Host "=== ONE-TIME QBIT SETSET SCRIPT ===" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-NOT $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# STEP 1: Clean up all old tasks
Write-Host ""
Write-Host "=== CLEANING UP OLD TASKS ===" -ForegroundColor Yellow
$oldTasks = @("KeyboardSleepTask", "PostBootPowerConfig", "PostLoginPowerConfig", "PostLoginPowerShell", "AutoSleepTask", "AutoFitFitTask", "AutoDkillTask", "AutoQbitSetsetTask")
foreach ($taskName in $oldTasks) {
    try {
        $null = schtasks /delete /tn $taskName /f 2>$null
        Write-Host "Deleted old task: $taskName" -ForegroundColor Green
    } catch {
        Write-Host "Task $taskName didn't exist" -ForegroundColor Gray
    }
}

# STEP 2: Create the simple one-time script
Write-Host ""
Write-Host "=== CREATING ONE-TIME SCRIPT ===" -ForegroundColor Yellow

$scriptDir = "C:\Windows\Temp"
$scriptPath = Join-Path $scriptDir "AutoQbitSetset.ps1"

# Ensure directory exists
if (-not (Test-Path $scriptDir)) {
    $null = New-Item -ItemType Directory -Path $scriptDir -Force
}

# Create the SIMPLE one-time script that KILLS ITSELF FIRST
$qbitSetsetScript = @'
# KILL THE TASK FIRST BEFORE ANYTHING
$logPath = "C:\Windows\Temp\AutoQbitSetset.log"

function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logPath -Append -Force
}

Write-Log "=== SCRIPT STARTED ==="

# DELETE THE TASK IMMEDIATELY TO PREVENT FUTURE RUNS
Write-Log "=== KILLING TASK FIRST ==="
try {
    cmd /c "schtasks /delete /tn AutoQbitSetsetTask /f" 2>&1
    Write-Log "schtasks delete executed"
} catch {}

try {
    Unregister-ScheduledTask -TaskName "AutoQbitSetsetTask" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "PowerShell unregister executed"
} catch {}

Write-Log "Task deletion completed - should not run again"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

Write-Log "Executing: qbit; setset"
try {
    Invoke-Expression "qbit; setset" 2>&1 | ForEach-Object { Write-Log "Output: $_" }
    Write-Log "Command executed successfully"
} catch {
    Write-Log "Error: $($_.Exception.Message)"
}

Write-Log "=== SCRIPT COMPLETE ==="

# Delete this script file
Start-Sleep -Seconds 2
try {
    Remove-Item "C:\Windows\Temp\AutoQbitSetset.ps1" -Force -ErrorAction SilentlyContinue
    Write-Log "Script file deleted"
} catch {
    Write-Log "Could not delete script file"
}
'@

# Write the script to file
try {
    $qbitSetsetScript | Out-File -FilePath $scriptPath -Encoding ASCII -Force
    Write-Host "Script created: $scriptPath" -ForegroundColor Green
} catch {
    Write-Host "FAILED to create script: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# STEP 3: Create the scheduled task
Write-Host ""
Write-Host "=== CREATING SCHEDULED TASK ===" -ForegroundColor Yellow

$taskName = "AutoQbitSetsetTask"
$userName = $env:USERNAME
$taskCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

Write-Host "Creating task: $taskName" -ForegroundColor Gray

$taskCreated = $false

# Try schtasks command
try {
    $result = schtasks /create /tn $taskName /tr $taskCommand /sc ONLOGON /ru $userName /rl HIGHEST /f 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Task created successfully!" -ForegroundColor Green
        $taskCreated = $true
    } else {
        Write-Host "schtasks failed: $result" -ForegroundColor Red
    }
} catch {
    Write-Host "schtasks exception: $($_.Exception.Message)" -ForegroundColor Red
}

# Try PowerShell cmdlets if schtasks failed
if (-not $taskCreated) {
    try {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userName
        $principal = New-ScheduledTaskPrincipal -UserId $userName -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        $null = Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
        Write-Host "PowerShell method succeeded!" -ForegroundColor Green
        $taskCreated = $true
    } catch {
        Write-Host "PowerShell method failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# STEP 4: Verify task creation
if ($taskCreated) {
    try {
        $verification = schtasks /query /tn $taskName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "TASK VERIFIED AND READY" -ForegroundColor Green
        } else {
            Write-Host "Task verification failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "Verification error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "TASK CREATION FAILED!" -ForegroundColor Red
    exit 1
}

# STEP 5: Reboot
if (-not $SkipReboot) {
    Write-Host ""
    Write-Host "=== READY FOR REBOOT ===" -ForegroundColor Cyan
    Write-Host "WHAT WILL HAPPEN:" -ForegroundColor Yellow
    Write-Host "1. After reboot: KILL TASK IMMEDIATELY" -ForegroundColor Green
    Write-Host "2. Wait 10 seconds" -ForegroundColor White
    Write-Host "3. Run 'qbit; setset' ONE TIME" -ForegroundColor White  
    Write-Host "4. Task will be GONE FOREVER" -ForegroundColor Green
    Write-Host "5. Future reboots: NOTHING HAPPENS" -ForegroundColor White
    Write-Host ""
    Write-Host "=== EMERGENCY STOP COMMAND ===" -ForegroundColor Red
    Write-Host "If it keeps running after reboot, run this as Admin:" -ForegroundColor Yellow
    Write-Host 'schtasks /delete /tn AutoQbitSetsetTask /f; Unregister-ScheduledTask -TaskName "AutoQbitSetsetTask" -Confirm:$false -ErrorAction SilentlyContinue; Remove-Item "C:\Windows\Temp\AutoQbitSetset.ps1" -Force -ErrorAction SilentlyContinue' -ForegroundColor White
    Write-Host ""
    Write-Host "Rebooting in 5 seconds..." -ForegroundColor Red
    
    for ($i = 5; $i -ge 1; $i--) {
        Write-Host "$i..." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
    
    Write-Host "REBOOTING NOW!" -ForegroundColor Red
    Restart-Computer -Force
} else {
    Write-Host ""
    Write-Host "=== SETUP COMPLETE ===" -ForegroundColor Green
    Write-Host "Task will run ONCE on next login and DELETE ITSELF" -ForegroundColor Yellow
    Write-Host "Log: C:\Windows\Temp\AutoQbitSetset.log" -ForegroundColor Gray
    Write-Host ""
    Write-Host "=== EMERGENCY STOP COMMAND ===" -ForegroundColor Red
    Write-Host "If task keeps running, execute this as Admin:" -ForegroundColor Yellow
    Write-Host 'schtasks /delete /tn AutoQbitSetsetTask /f; Unregister-ScheduledTask -TaskName "AutoQbitSetsetTask" -Confirm:$false -ErrorAction SilentlyContinue; Remove-Item "C:\Windows\Temp\AutoQbitSetset.ps1" -Force -ErrorAction SilentlyContinue' -ForegroundColor White
}
