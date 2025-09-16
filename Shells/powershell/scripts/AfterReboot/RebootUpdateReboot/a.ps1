# Bulletproof Script - PowerShell 5 Compatible (IMMEDIATE VISIBLE UPDATE2 + REBOOT LOOP - CRITICAL FIXES)
# Run as Administrator

param(
    [switch]$SkipReboot
)

Write-Host "=== BULLETPROOF SCRIPT - PS5 COMPATIBLE (IMMEDIATE VISIBLE UPDATE2 + REBOOT LOOP - CRITICAL FIXES) ===" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-NOT $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# --- Configuration ---
$TaskName = "AutoRunUpdate2LoopTask"
$MainScriptFileName = "RunUpdate2Loop.ps1"
$ScriptDir = "C:\Windows\Temp"
$MainScriptPath = Join-Path $ScriptDir $MainScriptFileName
$LogPath = Join-Path $ScriptDir "RunUpdate2Loop.log"
$RebootCountFile = Join-Path $ScriptDir "reboot_count.txt"
$MaxReboots = 2 # Set how many times you want it to run 'update2' and reboot. Set to a reasonable number!
# ---------------------

# STEP 1: Clean up all old broken tasks and files
Write-Host ""
Write-Host "=== CLEANING UP OLD TASKS AND FILES ===" -ForegroundColor Yellow
$oldTasks = @("KeyboardSleepTask", "PostBootPowerConfig", "PostLoginPowerConfig", "PostLoginPowerShell", "AutoSleepTask", "AutoFitFitTask", "AutoDkillTask", "AutoUpdate2Task", "AutoUpdate2ImmediateTask", $TaskName)
foreach ($taskNameItem in $oldTasks) {
    try {
        $null = schtasks /delete /tn $taskNameItem /f 2>$null
        Write-Host "Deleted old task: $taskNameItem" -ForegroundColor Green
    } catch {
        Write-Host "Task $taskNameItem didn't exist" -ForegroundColor Gray
    }
}
# Clean up old script files and log files from previous runs (be careful with wildcards, ensure it doesn't delete important files)
Remove-Item (Join-Path $ScriptDir "Auto*.ps1") -ErrorAction SilentlyContinue
Remove-Item (Join-Path $ScriptDir "Auto*.log") -ErrorAction SilentlyContinue
Remove-Item (Join-Path $ScriptDir "RunUpdate2Loop.ps1") -ErrorAction SilentlyContinue
Remove-Item (Join-Path $ScriptDir "RunUpdate2Loop.log") -ErrorAction SilentlyContinue
Remove-Item (Join-Path $ScriptDir "*.txt") -ErrorAction SilentlyContinue # For reboot_count.txt
Remove-Item (Join-Path $ScriptDir "*.xml") -ErrorAction SilentlyContinue # For temporary task XML
Remove-Item (Join-Path $ScriptDir "Delete*.ps1") -ErrorAction SilentlyContinue


# STEP 2: Create the main looping script
Write-Host ""
Write-Host "=== CREATING MAIN LOOPING SCRIPT ($MainScriptPath) ===" -ForegroundColor Yellow

# Ensure directory exists
if (-not (Test-Path $ScriptDir)) {
    $null = New-Item -ItemType Directory -Path $ScriptDir -Force
}

# Define the core script content using a SINGLE-QUOTED here-string (@'...')
# This treats everything inside as literal text. Variables from the outer script
# must be injected using a .Replace() method after this string is defined.
$coreScriptContentTemplate = @'
# Core Reboot Loop Script
param()

$logPath = "$LogPathPlaceHolder$" # Path to the log file
$rebootCountFile = "$RebootCountFilePlaceHolder$" # Path to the reboot counter file
$maxReboots = $MaxRebootsPlaceHolder$ # Maximum number of reboots before cleanup
$taskName = "$TaskNamePlaceHolder$" # Name of the scheduled task to delete during cleanup
$mainScriptPath = "$MainScriptPathPlaceHolder$" # Path to this script for self-deletion

function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logPath -Append -Force
}

try {
    Write-Log "Script started. Current PID: $PID"

    # Read reboot count
    $currentReboots = 0
    if (Test-Path $rebootCountFile) {
        try {
            $currentReboots = [int](Get-Content $rebootCountFile)
            Write-Log "Current reboot count: $currentReboots"
        } catch {
            Write-Log "Error reading reboot count file: $($_.Exception.Message). Resetting to 0."
            $currentReboots = 0
        }
    } else {
        Write-Log "Reboot count file not found. Starting from 0."
    }

    if ($currentReboots -lt $maxReboots) {
        Write-Log "Executing 'update2' command..."
        Write-Host "Running 'update2' command..." -ForegroundColor Yellow
        
        try {
            # Execute 'update2' and capture output for logging while still displaying
            Invoke-Expression "update2" | Out-String | ForEach-Object { 
                Write-Host $_ # Display to console
                Write-Log "update2 output: $_" # Log to file
            }
            Write-Log "'update2' command finished successfully."
            Write-Host "'update2' command finished." -ForegroundColor Green
        } catch {
            Write-Log "Error executing 'update2': $($_.Exception.Message)"
            Write-Host "Error running 'update2': $($_.Exception.Message)" -ForegroundColor Red
        }

        # Increment and save reboot count
        $currentReboots++
        Write-Log "Incremented reboot count to: $currentReboots"
        "$currentReboots" | Out-File -FilePath $rebootCountFile -Force

        Write-Host ""
        Write-Host "Command 'update2' executed. Rebooting system in 5 seconds (Reboot $currentReboots of $maxReboots)..." -ForegroundColor Cyan
        Write-Log "Initiating reboot (Reboot $currentReboots of $maxReboots)."
        Start-Sleep -Seconds 5
        Restart-Computer -Force # -Wait might prevent cleanup if it reboots too fast, so removed for loop.

    } else {
        Write-Log "Max reboots ($maxReboots) reached. Starting final cleanup."
        Write-Host "Max reboots ($maxReboots) reached. Performing final cleanup..." -ForegroundColor Cyan

        # Cleanup scheduled task
        try {
            Write-Log "Deleting scheduled task '$taskName'..."
            schtasks /delete /tn "$taskName" /f 2>$null
            Write-Log "Scheduled task '$taskName' deleted."
        } catch {
            Write-Log "Failed to delete scheduled task '$taskName': $($_.Exception.Message)"
        }

        # Create self-deletion script
        Write-Log "Creating self-deletion script..."
        $deleteSelfScript = @"
Start-Sleep -Seconds 5
Remove-Item '$mainScriptPath' -Force -ErrorAction SilentlyContinue
Remove-Item '$rebootCountFile' -Force -ErrorAction SilentlyContinue
Remove-Item '$logPath' -Force -ErrorAction SilentlyContinue
Remove-Item 'C:\Windows\Temp\Delete$taskName.ps1' -Force -ErrorAction SilentlyContinue
"@
        $deleteSelfScriptPath = "C:\Windows\Temp\Delete$taskName.ps1" # Unique name based on task
        $deleteSelfScript | Out-File -FilePath $deleteSelfScriptPath -Encoding ASCII -Force
        
        Write-Log "Launching self-deletion script: $deleteSelfScriptPath"
        Start-Process -FilePath "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File $deleteSelfScriptPath" -WindowStyle Hidden
        Write-Log "Self-deletion script launched. Exiting."
        
        Write-Host "Cleanup process initiated. The window will close shortly." -ForegroundColor Yellow
        Start-Sleep -Seconds 10 # Give enough time for the self-deletion script to start
    }

} catch {
    Write-Log "Fatal error in main script: $($_.Exception.Message)"
    Write-Host "A fatal error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Start-Sleep -Seconds 30 # Keep window open to show error
}
'@

# Now, inject the actual values into the template
$coreScriptContent = $coreScriptContentTemplate.Replace('$LogPathPlaceHolder$', $LogPath)
$coreScriptContent = $coreScriptContent.Replace('$RebootCountFilePlaceHolder$', $RebootCountFile)
$coreScriptContent = $coreScriptContent.Replace('$MaxRebootsPlaceHolder$', $MaxReboots)
$coreScriptContent = $coreScriptContent.Replace('$TaskNamePlaceHolder$', $TaskName)
$coreScriptContent = $coreScriptContent.Replace('$MainScriptPathPlaceHolder$', $MainScriptPath)

# Write the script to file
try {
    $coreScriptContent | Out-File -FilePath $MainScriptPath -Encoding ASCII -Force
    Write-Host "Main looping script created successfully at: $MainScriptPath" -ForegroundColor Green

    if (Test-Path $MainScriptPath) {
        $fileSize = (Get-Item $MainScriptPath).Length
        Write-Host "File size: $fileSize bytes" -ForegroundColor Gray
    } else {
        throw "Script file was not created"
    }

} catch {
    Write-Host "FAILED to create main script file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# STEP 3: Create the scheduled task
Write-Host ""
Write-Host "=== CREATING SCHEDULED TASK ($TaskName) ===" -ForegroundColor Yellow

$userName = $env:USERNAME
# Ensure correct quoting for the path in arguments
$taskCommandArguments = "-ExecutionPolicy Bypass -WindowStyle Normal -File `"$MainScriptPath`""
$taskCommand = "powershell.exe"

Write-Host "Task name: $TaskName" -ForegroundColor Gray
Write-Host "User: $userName" -ForegroundColor Gray
Write-Host "Command: $taskCommand" -ForegroundColor Gray
Write-Host "Arguments: $taskCommandArguments" -ForegroundColor Gray

$taskCreated = $false

# Method 1: Try schtasks command
Write-Host "Trying schtasks method..." -ForegroundColor Yellow
try {
    # /it for interactive, /ru to run as user
    $result = schtasks /create /tn $TaskName /tr "$taskCommand $taskCommandArguments" /sc ONLOGON /ru $userName /rl HIGHEST /f /it 2>&1

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
        $action = New-ScheduledTaskAction -Execute $taskCommand -Argument $taskCommandArguments
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userName
        $principal = New-ScheduledTaskPrincipal -UserId $userName -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances Parallel # Ensure it can run if a previous instance is stuck

        $null = Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force

        Write-Host "PowerShell cmdlets method successful!" -ForegroundColor Green
        $taskCreated = $true

    } catch {
        Write-Host "PowerShell cmdlets failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Method 3: XML method if both failed (ensuring interactive)
if (-not $taskCreated) {
    Write-Host "Trying manual XML method..." -ForegroundColor Yellow
    try {
        # Using a literal string for XML to avoid PowerShell interpretation of '<' and '>'
        # Note the careful use of double quotes and escaping for $MainScriptPath inside the XML argument
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
    <MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy>
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
      <Arguments>-ExecutionPolicy Bypass -WindowStyle Normal -File &quot;$MainScriptPath&quot;</Arguments>
    </Exec>
  </Actions>
</Task>
"@

        $xmlPath = Join-Path $ScriptDir "temp_task.xml"
        $taskXML | Out-File -FilePath $xmlPath -Encoding Unicode -Force

        $result = schtasks /create /tn $TaskName /xml $xmlPath /f 2>&1

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
        $verification = schtasks /query /tn $TaskName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "TASK VERIFIED: $TaskName exists and is ready!" -ForegroundColor Green
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
    Write-Host "You can try creating the task manually in Task Scheduler GUI with the following settings:" -ForegroundColor Yellow
    Write-Host "  - Action: Start a program" -ForegroundColor Yellow
    Write-Host "  - Program/script: powershell.exe" -ForegroundColor Yellow
    Write-Host "  - Add arguments: -ExecutionPolicy Bypass -WindowStyle Normal -File `"$MainScriptPath`"" -ForegroundColor Yellow
    Write-Host "  - Trigger: At log on, for specific user ($userName)" -ForegroundColor Yellow
    Write-Host "  - General tab: Run only when user is logged on, Run with highest privileges" -ForegroundColor Yellow
}

# STEP 5: Clean up system for reboot
Write-Host ""
Write-Host "=== PREPARING FOR INITIAL REBOOT ===" -ForegroundColor Yellow

# Close common applications to ensure a smooth reboot
$processesToClose = @("chrome", "firefox", "msedge", "teams", "outlook", "excel", "word", "powerpoint")
foreach ($processName in $processesToClose) {
    $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($processes) {
        Write-Host "Closing process: $processName" -ForegroundColor Gray
        $processes | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

# Restart explorer.exe to resolve potential issues, if any (optional, can sometimes cause temporary visual glitches)
$explorerProcesses = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
if ($explorerProcesses) {
    Write-Host "Restarting explorer.exe..." -ForegroundColor Gray
    $explorerProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
}


# STEP 6: Reboot or show summary
if (-not $SkipReboot) {
    Write-Host ""
    Write-Host "=== READY FOR INITIAL REBOOT ===" -ForegroundColor Cyan
    Write-Host "After reboot and login, the system will:" -ForegroundColor White
    Write-Host "  • Immediately launch a visible PowerShell window." -ForegroundColor White
    Write-Host "  • Run the 'update2' command exactly as specified." -ForegroundColor White
    Write-Host "  • After 'update2' finishes, it will reboot again." -ForegroundColor White
    Write-Host "  • This cycle will repeat $($MaxReboots) time(s)." -ForegroundColor White
    Write-Host "  • A log file will be created at: $LogPath" -ForegroundColor White
    Write-Host "  • After the final run, the script and task will self-delete." -ForegroundColor White
    Write-Host ""
    Write-Host "Rebooting in 10 seconds..." -ForegroundColor Red
    Write-Host "Press Ctrl+C to cancel..." -ForegroundColor Yellow

    # Initialize reboot counter to 0 before the first reboot
    "0" | Out-File -FilePath $RebootCountFile -Force -ErrorAction SilentlyContinue
    Write-Host "Reboot counter initialized to 0." -ForegroundColor Gray

    for ($i = 10; $i -ge 1; $i--) {
        Write-Host "$i..." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }

    Write-Host "REBOOTING NOW!" -ForegroundColor Red
    Restart-Computer -Force

} else {
    Write-Host ""
    Write-Host "=== SETUP COMPLETE (NO REBOOT INITIATED) ===" -ForegroundColor Green
    Write-Host "Main script path: $MainScriptPath" -ForegroundColor Gray
    Write-Host "Task name: $TaskName" -ForegroundColor Gray
    Write-Host "Log file: $LogPath" -ForegroundColor Gray
    Write-Host "Reboot count file: $RebootCountFile" -ForegroundColor Gray
    Write-Host "Max Reboots: $MaxReboots" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To test manually, open PowerShell as Administrator and run: `"$MainScriptPath`"" -ForegroundColor Yellow
    Write-Host "To reset the loop for manual testing: Remove-Item '$RebootCountFile' -ErrorAction SilentlyContinue" -ForegroundColor Yellow
}
