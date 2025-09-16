# === Watch-GameSetup-and-AHK-Enhanced.ps1 ===
$watchDir = "F:\Downloads"
$gamesDir = "F:\games"
$ahkPath = "F:\study\shells\powershell\scripts\AutoSetupFitGgames\b.ahk"
$ahkScriptName = "b.ahk"
$launchedSetups = @{}
$maxConcurrentSetups = 3

function Ensure-Single-AHK-Running {
    # Find all AutoHotkey processes running our specific script
    $ahkProcesses = Get-Process | Where-Object { 
        $_.ProcessName -like "*AutoHotkey*" -and 
        $_.CommandLine -like "*$ahkPath*" 
    } -ErrorAction SilentlyContinue
    
    # Alternative method if CommandLine is not available
    if (-not $ahkProcesses) {
        $ahkProcesses = Get-WmiObject Win32_Process | Where-Object { 
            $_.Name -like "*AutoHotkey*" -and 
            $_.CommandLine -like "*$ahkPath*" 
        } -ErrorAction SilentlyContinue
    }
    
    if ($ahkProcesses.Count -gt 1) {
        Write-Host "[AHK] Multiple AutoHotkey instances detected. Terminating extras..."
        $ahkProcesses | Select-Object -Skip 1 | ForEach-Object { 
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Host "[AHK] Terminated extra process ID: $($_.ProcessId)"
        }
    }
    
    if ($ahkProcesses.Count -eq 0) {
        Write-Host "[AHK] No AutoHotkey instance running. Starting $ahkScriptName..."
        Start-Process -FilePath $ahkPath -WindowStyle Hidden
        Start-Sleep -Seconds 2  # Give it time to start
        Write-Host "[AHK] $ahkScriptName started"
    } else {
        Write-Host "[AHK] Single AutoHotkey instance confirmed running"
    }
}

function Get-Running-Setup-Count {
    # Count currently running setup.exe processes
    $runningSetups = Get-Process | Where-Object { $_.ProcessName -eq "setup" } -ErrorAction SilentlyContinue
    return $runningSetups.Count
}

function Remove-Completed-Setups {
    # Clean up tracking for setups that are no longer running
    $completedSetups = @()
    foreach ($setupPath in $launchedSetups.Keys) {
        $setupName = [System.IO.Path]::GetFileNameWithoutExtension($setupPath)
        $isStillRunning = Get-Process | Where-Object { 
            $_.ProcessName -eq "setup" -and 
            $_.MainModule.FileName -eq $setupPath 
        } -ErrorAction SilentlyContinue
        
        if (-not $isStillRunning) {
            $completedSetups += $setupPath
        }
    }
    
    # Remove completed setups from tracking
    foreach ($completed in $completedSetups) {
        $launchedSetups.Remove($completed)
        Write-Host "[Cleanup] Removed completed setup from tracking: $([System.IO.Path]::GetFileName($completed))"
    }
}

function Launch-Setup-If-Possible {
    param($setupFile)
    
    $currentRunning = Get-Running-Setup-Count
    
    if ($currentRunning -ge $maxConcurrentSetups) {
        Write-Host "[Limit] Cannot launch setup - already running $currentRunning/$maxConcurrentSetups setups"
        return $false
    }
    
    # Check if file is ready (not being written to)
    try {
        $stream = $setupFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
        $stream.Close()
        
        # File is ready, launch it
        Write-Host "[Launch] Starting $($setupFile.Name) (will be $($currentRunning + 1)/$maxConcurrentSetups)"
        Start-Process -FilePath $setupFile.FullName
        $launchedSetups[$setupFile.FullName] = Get-Date
        Write-Host "[Launch] Successfully launched and added to tracking"
        return $true
        
    } catch {
        Write-Host "[Launch] $($setupFile.Name) is still being written or locked. Will try again later..."
        return $false
    }
}

# === MAIN EXECUTION ===

Write-Host "================================================================"
Write-Host "Enhanced Game Setup Watcher v2.0"
Write-Host "================================================================"
Write-Host "[Config] Watch Directory: $watchDir"
Write-Host "[Config] Games Directory: $gamesDir"
Write-Host "[Config] AHK Script: $ahkPath"
Write-Host "[Config] Max Concurrent Setups: $maxConcurrentSetups"
Write-Host "================================================================"

# Ensure AHK is running first before starting the watcher
Write-Host "[Startup] Ensuring single AHK script instance is running..."
Ensure-Single-AHK-Running

Write-Host "[Watcher] Starting monitoring for setup.exe files..."
Write-Host "[Watcher] Scan interval: 60 seconds"
Write-Host "================================================================"

$scanCount = 0

while ($true) {
    $scanCount++
    Write-Host "`n[Scan #$scanCount] $(Get-Date -Format 'HH:mm:ss') - Checking system status..."
    
    # Ensure only one AHK instance is running
    Ensure-Single-AHK-Running
    
    # Clean up completed setups from tracking
    Remove-Completed-Setups
    
    # Get current system status
    $currentRunning = Get-Running-Setup-Count
    Write-Host "[Status] Currently running setups: $currentRunning/$maxConcurrentSetups"
    Write-Host "[Status] Tracked launched setups: $($launchedSetups.Count)"
    
    # Only look for new setups if we have capacity
    if ($currentRunning -lt $maxConcurrentSetups) {
        # Find all setup.exe files in Downloads directory
        $allSetupFiles = Get-ChildItem -Path $watchDir -Filter "setup.exe" -Recurse -File -ErrorAction SilentlyContinue
        Write-Host "[Scan] Found $($allSetupFiles.Count) setup.exe file(s) total"
        
        # Filter out already launched ones
        $newSetupFiles = $allSetupFiles | Where-Object { -not $launchedSetups.ContainsKey($_.FullName) }
        
        if ($newSetupFiles.Count -gt 0) {
            Write-Host "[Scan] Found $($newSetupFiles.Count) new setup.exe file(s) not yet launched"
            
            # Sort by most recent and try to launch one
            $setupFile = $newSetupFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            Write-Host "[Scan] Attempting to launch most recent: $($setupFile.Name)"
            
            $launched = Launch-Setup-If-Possible -setupFile $setupFile
            if ($launched) {
                Write-Host "[Success] Setup launched successfully"
            }
        } else {
            Write-Host "[Scan] No new setup.exe files found"
        }
    } else {
        Write-Host "[Limit] Skipping scan - maximum concurrent setups already running"
    }
    
    # Show current tracking status
    if ($launchedSetups.Count -gt 0) {
        Write-Host "[Tracking] Currently monitoring $($launchedSetups.Count) launched setup(s):"
        foreach ($setup in $launchedSetups.Keys) {
            $launchTime = $launchedSetups[$setup]
            $fileName = [System.IO.Path]::GetFileName($setup)
            Write-Host "  - $fileName (launched: $($launchTime.ToString('HH:mm:ss')))"
        }
    }
    
    Write-Host "[Wait] Next scan in 60 seconds..."
    Start-Sleep -Seconds 60
}