# === Watch-GameSetup-and-AHK.ps1 ===
$watchDir = "F:\Downloads"
$gamesDir = "F:\games"
$ahkPath = "F:\study\shells\powershell\scripts\AutoSetupFitGgames\b.ahk"
$ahkScriptName = "b.ahk"
$launchedSetups = @{}

function Ensure-AHK-Running {
    $isRunning = Get-Process | Where-Object { $_.ProcessName -like "*AutoHotkey*" -and $_.MainWindowTitle -eq $ahkScriptName } -ErrorAction SilentlyContinue
    if (-not $isRunning) {
        Start-Process -FilePath $ahkPath -WindowStyle Hidden
        Write-Host "[AHK] a.ahk started"
    } else {
        Write-Host "[AHK] a.ahk is already running"
    }
}

# Ensure AHK is running first before starting the watcher
Write-Host "[Startup] Ensuring AHK script is running before starting watcher..."
Ensure-AHK-Running

Write-Host "[Watcher] Scanning $watchDir for setup.exe every 30 seconds..."
Write-Host "[Watcher] Launched setups will be tracked to prevent re-runs"

while ($true) {
    Ensure-AHK-Running

    # Find all setup.exe files in Downloads directory
    $allSetupFiles = Get-ChildItem -Path $watchDir -Filter "setup.exe" -Recurse -File -ErrorAction SilentlyContinue
    
    Write-Host "[Watcher] Found $($allSetupFiles.Count) setup.exe file(s) in total"
    
    # Filter out already launched ones
    $newSetupFiles = $allSetupFiles | Where-Object { -not $launchedSetups.ContainsKey($_.FullName) }
    
    if ($newSetupFiles.Count -gt 0) {
        Write-Host "[Watcher] Found $($newSetupFiles.Count) new setup.exe file(s) not yet launched"
        
        # Get the most recent one
        $setupFile = $newSetupFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        Write-Host "[Watcher] Attempting to launch: $($setupFile.FullName)"
        
        # Check if file is ready (not being written to)
        try {
            $stream = $setupFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            $stream.Close()
            
            # File is ready, launch it
            Write-Host "[Watcher] Launching $($setupFile.FullName)..."
            Start-Process -FilePath $setupFile.FullName
            $launchedSetups[$setupFile.FullName] = $true
            Write-Host "[Watcher] Successfully launched and marked as completed"
            
        } catch {
            Write-Host "[Watcher] $($setupFile.Name) is still in use or locked. Will try again in 30 seconds..."
        }
    } else {
        Write-Host "[Watcher] No new setup.exe files found"
    }
    
    # Show currently tracked launched setups
    if ($launchedSetups.Count -gt 0) {
        Write-Host "[Watcher] Currently tracking $($launchedSetups.Count) launched setup(s)"
    }
    
    Start-Sleep -Seconds 200
}
