# ===== POWERSHELL-SCRIPT.ps1 =====
# THIS IS THE POWERSHELL SCRIPT - SAVE AS .ps1 FILE
# DO NOT SAVE AS .ahk - THIS IS PURE POWERSHELL CODE

$watchDir = "F:\Downloads"
$gamesDir = "F:\games"
$ahkPath = "F:\study\shells\powershell\scripts\AutoSetupFitGgames\a.ahk"
$ahkScriptName = "a.ahk"
$launchedSetups = @{}
$launchedSetupsHash = @{}
$maxConcurrentSetups = 1
$currentRunningSetup = $null

function Get-File-Hash {
    param($filePath)
    try {
        $hash = Get-FileHash -Path $filePath -Algorithm MD5 -ErrorAction SilentlyContinue
        return $hash.Hash
    } catch {
        return $null
    }
}

function Is-Setup-Already-Launched {
    param($setupFile)
    
    if ($launchedSetups.ContainsKey($setupFile.FullName)) {
        return $true
    }
    
    $fileHash = Get-File-Hash -filePath $setupFile.FullName
    if ($fileHash -and $launchedSetupsHash.ContainsKey($fileHash)) {
        return $true
    }
    
    $sizeNameKey = "$($setupFile.Length)_$($setupFile.Name)"
    if ($launchedSetups.Values | Where-Object { $_.SizeNameKey -eq $sizeNameKey }) {
        return $true
    }
    
    return $false
}

function Add-Setup-To-Tracking {
    param($setupFile)
    
    $fileHash = Get-File-Hash -filePath $setupFile.FullName
    $sizeNameKey = "$($setupFile.Length)_$($setupFile.Name)"
    
    $trackingInfo = @{
        FullPath = $setupFile.FullName
        LaunchTime = Get-Date
        FileHash = $fileHash
        SizeNameKey = $sizeNameKey
        FileName = $setupFile.Name
    }
    
    $launchedSetups[$setupFile.FullName] = $trackingInfo
    if ($fileHash) {
        $launchedSetupsHash[$fileHash] = $trackingInfo
    }
    
    Write-Host "[Track] Added to permanent tracking: $($setupFile.Name)" -ForegroundColor Green
}

function Ensure-Single-AHK-Running {
    $ahkProcesses = Get-Process | Where-Object { $_.ProcessName -like "*AutoHotkey*" } -ErrorAction SilentlyContinue
    
    if ($ahkProcesses.Count -gt 1) {
        Write-Host "[AHK] Multiple instances detected. Terminating extras..." -ForegroundColor Yellow
        $ahkProcesses | Select-Object -Skip 1 | ForEach-Object { 
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
    
    if ($ahkProcesses.Count -eq 0) {
        Write-Host "[AHK] Starting AutoHotkey script..." -ForegroundColor Cyan
        try {
            Start-Process -FilePath $ahkPath -WindowStyle Hidden
            Start-Sleep -Milliseconds 100
            Write-Host "[AHK] AutoHotkey started successfully" -ForegroundColor Green
        } catch {
            Write-Host "[AHK] ERROR: Could not start AutoHotkey script: $_" -ForegroundColor Red
            Write-Host "[AHK] Make sure AUTOHOTKEY-SCRIPT.ahk exists and AutoHotkey is installed!" -ForegroundColor Red
        }
    } else {
        Write-Host "[AHK] AutoHotkey running" -ForegroundColor Green
    }
}

function Get-Running-Setup-Count {
    $runningSetups = Get-Process | Where-Object { $_.ProcessName -eq "setup" } -ErrorAction SilentlyContinue
    return $runningSetups.Count
}

function Monitor-Setup-Completion {
    if ($global:currentRunningSetup) {
        $stillRunning = Get-Process | Where-Object { 
            $_.ProcessName -eq "setup" -and 
            $_.Id -eq $global:currentRunningSetup.ProcessId 
        } -ErrorAction SilentlyContinue
        
        if (-not $stillRunning) {
            Write-Host "[Complete] ✓ Setup FINISHED: $($global:currentRunningSetup.Name)" -ForegroundColor Green
            Write-Host "[Complete] → IMMEDIATELY launching next setup..." -ForegroundColor Yellow
            $global:currentRunningSetup = $null
            return $true
        }
    }
    return $false
}

function Launch-Setup-If-Possible {
    param($setupFile)
    
    if (Is-Setup-Already-Launched -setupFile $setupFile) {
        Write-Host "[Skip] ALREADY LAUNCHED: $($setupFile.Name)" -ForegroundColor Red
        return $false
    }
    
    $currentRunning = Get-Running-Setup-Count
    
    if ($currentRunning -ge $maxConcurrentSetups) {
        Write-Host "[Busy] Setup already running" -ForegroundColor Yellow
        return $false
    }
    
    try {
        $stream = $setupFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
        $stream.Close()
        
        Write-Host "[Launch] ⚡ LAUNCHING: $($setupFile.Name)" -ForegroundColor Cyan
        $process = Start-Process -FilePath $setupFile.FullName -PassThru
        
        $global:currentRunningSetup = @{
            ProcessId = $process.Id
            Name = $setupFile.Name
            StartTime = Get-Date
        }
        
        Add-Setup-To-Tracking -setupFile $setupFile
        
        Write-Host "[Track] Now monitoring process ID: $($process.Id)" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "[Wait] File locked: $($setupFile.Name)" -ForegroundColor Yellow
        return $false
    }
}

# === MAIN EXECUTION ===

Clear-Host
Write-Host "================================================================" -ForegroundColor White
Write-Host "SINGLE SETUP WATCHER - INSTANT NEXT LAUNCH" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor White
Write-Host "[IMPORTANT] Make sure AUTOHOTKEY-SCRIPT.ahk is in the same folder!" -ForegroundColor Red
Write-Host "[Config] Watch: $watchDir" -ForegroundColor Cyan
Write-Host "[Config] Single setup mode - 1 second scanning" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor White

Write-Host "`n[Startup] Starting AutoHotkey script..." -ForegroundColor Yellow
Ensure-Single-AHK-Running

$scanCount = 0
$fastScanInterval = 1

while ($true) {
    $scanCount++
    Write-Host "`n[#$scanCount] $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor White
    
    if ($scanCount % 5 -eq 0) {
        Ensure-Single-AHK-Running
    }
    
    $setupJustCompleted = Monitor-Setup-Completion
    $currentRunning = Get-Running-Setup-Count
    Write-Host "[Status] RUNNING: $currentRunning/1 | Tracked: $($launchedSetups.Count)" -ForegroundColor Cyan
    
    if ($global:currentRunningSetup) {
        $runtime = (Get-Date) - $global:currentRunningSetup.StartTime
        Write-Host "[Current] $($global:currentRunningSetup.Name) - $($runtime.ToString('mm\:ss'))" -ForegroundColor Green
    }
    
    if ($currentRunning -eq 0 -or $setupJustCompleted) {
        if ($setupJustCompleted) {
            Write-Host "[Immediate] Setup completed - launching next!" -ForegroundColor Yellow
        }
        
        $allSetupFiles = Get-ChildItem -Path $watchDir -Filter "setup.exe" -Recurse -File -ErrorAction SilentlyContinue
        
        if ($allSetupFiles.Count -gt 0) {
            Write-Host "[Scan] Found $($allSetupFiles.Count) setup.exe files" -ForegroundColor Cyan
            
            $newSetupFiles = $allSetupFiles | Where-Object { -not (Is-Setup-Already-Launched -setupFile $_) }
            
            if ($newSetupFiles.Count -gt 0) {
                Write-Host "[Available] $($newSetupFiles.Count) NEW setups ready" -ForegroundColor Green
                
                $setupFile = $newSetupFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                Write-Host "[Next] ⚡ IMMEDIATE LAUNCH: $($setupFile.Name)" -ForegroundColor Magenta
                
                $launched = Launch-Setup-If-Possible -setupFile $setupFile
                if ($launched) {
                    Write-Host "[Success] ✓ LAUNCHED - AutoHotkey handling at 5X speed!" -ForegroundColor Green
                } else {
                    Write-Host "[Failed] ✗ Could not launch" -ForegroundColor Red
                }
            } else {
                Write-Host "[Status] All setups already launched" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[Scan] No setup.exe files found" -ForegroundColor Gray
        }
    } else {
        Write-Host "[Busy] Setup running - monitoring..." -ForegroundColor Yellow
    }
    
    if ($launchedSetups.Count -gt 0) {
        Write-Host "[Tracking] $($launchedSetups.Count) setups will NEVER be relaunched" -ForegroundColor Magenta
        $launchedSetups.Values | Select-Object -Last 2 | ForEach-Object { 
            Write-Host "  ✓ $($_.FileName) @ $($_.LaunchTime.ToString('HH:mm:ss'))" -ForegroundColor Gray
        }
    }
    
    Start-Sleep -Seconds $fastScanInterval
}
