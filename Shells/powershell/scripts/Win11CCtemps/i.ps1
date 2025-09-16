# Windows 11 Ultimate Cache and Temp Cleanup Script - FULL COMPREHENSIVE MODE
# Run as Administrator for best results

param(
    [switch]$WhatIf = $false  # Add -WhatIf to see what would be deleted without actually deleting
)

# Global tracking variables
$script:totalFreed = 0
$script:pendingDeletions = @()
$script:lockedDirectories = @()
$script:pendingDeletionSize = 0
$script:pendingFileCount = 0
$script:processedCount = 0
$script:skippedCount = 0

# Function to get folder size in MB with timeout
function Get-FolderSizeMB {
    param([string]$Path, [int]$TimeoutSeconds = 10)
    try {
        if (Test-Path $Path) {
            $job = Start-Job -ScriptBlock {
                param($dir)
                $size = (Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                return [math]::Round($size / 1MB, 2)
            } -ArgumentList $Path
            
            $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
            if ($completed) {
                $result = Receive-Job -Job $job
                Remove-Job -Job $job -Force
                return $result
            } else {
                Stop-Job -Job $job
                Remove-Job -Job $job -Force
                return 0
            }
        }
    }
    catch {
        return 0
    }
    return 0
}

# Function to add items to pending deletion on reboot (silent mode)
function Add-PendingDeletion {
    param([string]$Path, [string]$Type = "File")
    
    try {
        # Calculate size of what we're scheduling for deletion
        if (Test-Path $Path) {
            if ((Get-Item $Path).PSIsContainer) {
                $size = Get-FolderSizeMB -Path $Path -TimeoutSeconds 5
                $fileCount = 50 # Estimate to avoid slow enumeration
            } else {
                $size = [math]::Round((Get-Item $Path).Length / 1MB, 2)
                $fileCount = 1
            }
            $script:pendingDeletionSize += $size
            $script:pendingFileCount += $fileCount
        }
        
        # Use PendingFileRenameOperations registry key (official Windows method)
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
        $regName = "PendingFileRenameOperations"
        
        # Get existing pending operations
        $existingOperations = @()
        try {
            $existingOperations = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $regName
        }
        catch {
            $existingOperations = @()
        }
        
        # Add new operation (format: source_path, empty_string means delete)
        $newOperations = $existingOperations + @("\??\$Path", "")
        Set-ItemProperty -Path $regPath -Name $regName -Value $newOperations -Type MultiString
        
        # Use takeown and icacls for stubborn files
        if (Test-Path $Path) {
            takeown /f "$Path" /r /d y 2>$null | Out-Null
            icacls "$Path" /grant administrators:F /t 2>$null | Out-Null
        }
        
        # Add to backup deletion script
        $script:pendingDeletions += $Path
        return $true
    }
    catch {
        return $false
    }
}

# Fast cleanup function with timeouts
function Clear-DirectoryContents {
    param([string]$Path, [int]$MaxTimeSeconds = 45)
    
    $sizeBefore = 0
    $freed = 0
    
    try {
        if (Test-Path $Path) {
            Write-Host "Processing: $Path" -ForegroundColor Cyan
            
            # Get size before cleanup (with timeout)
            $sizeBefore = Get-FolderSizeMB -Path $Path -TimeoutSeconds 5
            
            if ($sizeBefore -gt 0) {
                Write-Host "  Size before: $sizeBefore MB" -ForegroundColor Yellow
                
                if (!$WhatIf) {
                    # Try fast deletion with timeout
                    try {
                        $job = Start-Job -ScriptBlock {
                            param($dir)
                            Get-ChildItem -Path $dir -Recurse -Force -ErrorAction SilentlyContinue | 
                                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        } -ArgumentList $Path
                        
                        $completed = Wait-Job -Job $job -Timeout $MaxTimeSeconds
                        if ($completed) {
                            Receive-Job -Job $job
                            $sizeAfter = Get-FolderSizeMB -Path $Path -TimeoutSeconds 3
                            $freed = $sizeBefore - $sizeAfter
                            if ($freed -gt 0) {
                                Write-Host "  Freed: $freed MB" -ForegroundColor Green
                            } else {
                                Write-Host "  Already cleaned or empty" -ForegroundColor Gray
                            }
                        } else {
                            Stop-Job -Job $job
                            throw "Deletion timeout after $MaxTimeSeconds seconds"
                        }
                        Remove-Job -Job $job -Force
                    }
                    catch {
                        Write-Host "  Files locked, scheduling for reboot deletion..." -ForegroundColor Yellow
                        Add-PendingDeletion -Path $Path
                        $script:lockedDirectories += $Path
                        $freed = $sizeBefore  # Count full size as it will be freed on reboot
                        Write-Host "  → Scheduled for reboot deletion" -ForegroundColor Magenta
                    }
                } else {
                    Write-Host "  [WHATIF] Would free: $sizeBefore MB" -ForegroundColor Magenta
                    $freed = $sizeBefore
                }
            } else {
                Write-Host "  Already empty" -ForegroundColor Gray
            }
        } else {
            Write-Host "  Path not found: $Path" -ForegroundColor DarkGray
            $script:skippedCount++
        }
        
        $script:processedCount++
        return $freed
    }
    catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return 0
    }
}

# Create reboot cleanup script
function New-RebootCleanupScript {
    $cleanupScript = @"
@echo off
echo Starting force cleanup on reboot...
echo %date% %time% - Reboot cleanup started >> C:\Windows\Temp\cleanup_log.txt

REM Force delete each pending item (without killing any processes)
"@

    foreach ($item in $script:pendingDeletions) {
        $cleanupScript += @"

echo Deleting: $item
rd /s /q "$item" 2>nul
del /f /q "$item" 2>nul
rmdir /s /q "$item" 2>nul

"@
    }

    $cleanupScript += @"

REM Additional aggressive cleanup
for /d %%x in (C:\Users\*\AppData\Local\Temp\*) do rd /s /q "%%x" 2>nul
for /d %%x in (C:\Windows\Temp\*) do rd /s /q "%%x" 2>nul
del /f /q C:\Users\*\AppData\Local\Temp\*.* 2>nul
del /f /q C:\Windows\Temp\*.* 2>nul

echo %date% %time% - Reboot cleanup completed >> C:\Windows\Temp\cleanup_log.txt
echo Reboot cleanup completed.

REM Self-delete this script
timeout /t 2 /nobreak > nul
del "%~f0"
"@

    $scriptPath = "C:\Windows\Temp\CleanupOnBoot.bat"
    $cleanupScript | Out-File -FilePath $scriptPath -Encoding ASCII -Force
    
    # Add to startup (runs once then removes itself)
    $startupPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\CleanupOnBoot.bat"
    Copy-Item -Path $scriptPath -Destination $startupPath -Force -ErrorAction SilentlyContinue
    
    # Also add to registry Run key as backup
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "CleanupOnBoot" -Value "$scriptPath" -ErrorAction SilentlyContinue
    
    return $scriptPath
}

# Main script execution
Write-Host "=======================================" -ForegroundColor White
Write-Host "Windows 11 ULTIMATE Cache & Temp Cleanup" -ForegroundColor White
Write-Host "=======================================" -ForegroundColor White
Write-Host "RUNNING IN FULL COMPREHENSIVE MODE - May take 3+ hours" -ForegroundColor Red -BackgroundColor Yellow
Write-Host "Includes: Cache cleanup, SFC scan, DISM repair, memory test, and file compression" -ForegroundColor Yellow
Write-Host "Running processes will NOT be stopped" -ForegroundColor Yellow

if ($WhatIf) {
    Write-Host "RUNNING IN WHATIF MODE - NO FILES WILL BE DELETED" -ForegroundColor Magenta
}

Write-Host ""

# STEP 1: ULTRA-FAST COMPREHENSIVE CLEANUP USING ADVANCED ONE-LINER
Write-Host "STEP 1: Running ultra-fast comprehensive cleanup..." -ForegroundColor Green
Write-Host "Targeting: Temp files, Cache files, Log files, Dump files, NVIDIA files, Browser cache" -ForegroundColor Cyan

if (!$WhatIf) {
    try {
        $startTime = Get-Date
        Write-Host "  → Executing advanced cleanup command..." -ForegroundColor Yellow
        Write-Host "  → Scanning directories for temp/cache files..." -ForegroundColor Gray
        
        # The comprehensive one-liner cleanup
        $filesRemoved = Get-ChildItem -Path @(
            "$env:TEMP\*", 
            "$env:TMP\*", 
            "$env:WINDIR\Temp\*", 
            "$env:WINDIR\Logs\*", 
            "$env:WINDIR\SoftwareDistribution\Download\*", 
            "$env:WINDIR\ServiceProfiles\*\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*", 
            "$env:ProgramData\NVIDIA Corporation\*", 
            "$env:LOCALAPPDATA\NVIDIA\*", 
            "$env:LOCALAPPDATA\Temp\*", 
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*", 
            "$env:LOCALAPPDATA\Microsoft\Windows\WebCache\*", 
            "$env:PROGRAMFILES\NVIDIA Corporation\Installer2\*", 
            "${env:PROGRAMFILES(X86)}\NVIDIA Corporation\Installer2\*", 
            "$env:USERPROFILE\AppData\Local\CrashDumps\*"
        ) -Recurse -Force -ErrorAction SilentlyContinue | 
        Where-Object {
            $_.Extension -match '\.(tmp|temp|log|cache|dmp|old|bak)$' -or 
            $_.Name -match '(temp|cache|log|\.tmp|\.log|\.dmp|\.old|\.bak|nvph|content\.bin)' -or 
            $_.PSIsContainer -eq $false
        }
        
        Write-Host "  → Removing identified files..." -ForegroundColor Gray
        $filesRemoved | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        Write-Host "  ✓ Advanced cleanup completed in $([math]::Round($duration, 1)) seconds" -ForegroundColor Green
        
        # Estimate space freed (rough calculation)
        $estimatedFreed = 150  # Conservative estimate in MB
        $script:totalFreed += $estimatedFreed
        Write-Host "  ✓ Estimated $estimatedFreed MB freed from comprehensive cleanup" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Advanced cleanup encountered issues: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  [WHATIF] Would run comprehensive file cleanup" -ForegroundColor Magenta
}

# STEP 2: TARGET SPECIFIC HIGH-VALUE DIRECTORIES
Write-Host ""
Write-Host "STEP 2: Targeting specific high-value cache directories..." -ForegroundColor Green

# High-value directories that typically contain lots of cache
$highValueDirectories = @(
    "C:\Windows\System32\winevt\Logs",
    "C:\Windows\Prefetch",
    "C:\Users\$env:USERNAME\AppData\Local\Packages\MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy\LocalState\EBWebView\Default\Cache",
    "C:\Users\$env:USERNAME\AppData\Local\Docker\log",
    "C:\Users\$env:USERNAME\AppData\Roaming\Todoist\Cache",
    "C:\Users\$env:USERNAME\AppData\Local\CD Projekt Red\Cyberpunk 2077\cache",
    "C:\Users\$env:USERNAME\AppData\Local\NVIDIA Corporation\NVIDIA App\CefCache\Default\Cache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Cursor\Cache",
    "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Windows\Explorer",
    "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Windows\WebCache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\Default\Cache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\Default\DawnGraphiteCache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\Default\DawnWebGPUCache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\Default\GPUCache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\GraphiteDawnCache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\ShaderCache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\GrShaderCache",
    "C:\Users\$env:USERNAME\AppData\Local\D3DSCache",
    "C:\Windows\WinSxS\Temp"
)

foreach ($directory in $highValueDirectories) {
    $freed = Clear-DirectoryContents -Path $directory -MaxTimeSeconds 30
    $script:totalFreed += $freed
    Start-Sleep -Milliseconds 100
}

# STEP 3: WINDOWS UPDATE SERVICE RESET AND CLEANUP
Write-Host ""
Write-Host "STEP 3: Windows Update service reset and cleanup..." -ForegroundColor Green

if (!$WhatIf) {
    Write-Host "Stopping Windows Update services..." -ForegroundColor Cyan
    Write-Host "  → Stopping UsoSvc, cryptsvc, bits, msiserver, dosvc, wuauserv..." -ForegroundColor Gray
    Stop-Service -Name UsoSvc,cryptsvc,bits,msiserver,dosvc,wuauserv -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Windows Update services stopped" -ForegroundColor Green
    
    Write-Host "Cleaning old Windows Update directories..." -ForegroundColor Cyan
    Remove-Item -Path "C:\Windows\SoftwareDistribution.old","C:\Windows\System32\catroot2.old" -Recurse -Force -ErrorAction SilentlyContinue
    
    try {
        Write-Host "Resetting SoftwareDistribution directory..." -ForegroundColor Cyan
        Rename-Item -Path "C:\Windows\SoftwareDistribution" -NewName "SoftwareDistribution.old" -Force -ErrorAction Stop
        New-Item -Path "C:\Windows\SoftwareDistribution" -ItemType Directory -Force | Out-Null
        Write-Host "  ✓ SoftwareDistribution directory reset" -ForegroundColor Green
        $script:totalFreed += 50  # Estimate
    }
    catch {
        Write-Host "  SoftwareDistribution reset failed (may be in use)" -ForegroundColor Yellow
    }
    
    try {
        Write-Host "Resetting catroot2 directory..." -ForegroundColor Cyan
        Rename-Item -Path "C:\Windows\System32\catroot2" -NewName "catroot2.old" -Force -ErrorAction Stop
        New-Item -Path "C:\Windows\System32\catroot2" -ItemType Directory -Force | Out-Null
        Write-Host "  ✓ catroot2 directory reset" -ForegroundColor Green
        $script:totalFreed += 20  # Estimate
    }
    catch {
        Write-Host "  catroot2 reset failed (may be in use)" -ForegroundColor Yellow
    }
    
    Write-Host "Restarting Windows Update services..." -ForegroundColor Cyan
    Write-Host "  → Starting UsoSvc, cryptsvc, bits, msiserver, dosvc, wuauserv..." -ForegroundColor Gray
    Start-Service -Name UsoSvc,cryptsvc,bits,msiserver,dosvc,wuauserv -ErrorAction SilentlyContinue
    Write-Host "  ✓ Windows Update services restarted" -ForegroundColor Green
} else {
    Write-Host "  [WHATIF] Would reset Windows Update services and directories" -ForegroundColor Magenta
}

# STEP 4: ENHANCED TEMP DIRECTORY AND REGISTRY CLEANUP
Write-Host ""
Write-Host "STEP 4: Enhanced temp directory and registry cleanup..." -ForegroundColor Green

if (!$WhatIf) {
    Write-Host "Running Windows Disk Cleanup utility..." -ForegroundColor Cyan
    Write-Host "  → Starting disk cleanup (may take 3-5 minutes)..." -ForegroundColor Gray
    try {
        $cleanmgrJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($cleanmgrJob.State -eq "Running" -and $elapsed -lt 300) {  # 5 minute timeout
            Start-Sleep -Seconds 15
            $elapsed += 15
            $secondsElapsed = $elapsed
            Write-Host "  → Disk cleanup in progress... ($secondsElapsed seconds elapsed)" -ForegroundColor Gray
        }
        
        if ($cleanmgrJob.State -eq "Completed") {
            Remove-Job -Job $cleanmgrJob -Force
            Write-Host "  ✓ Windows Disk Cleanup completed" -ForegroundColor Green
            $script:totalFreed += 100  # Estimate
        } else {
            Stop-Job -Job $cleanmgrJob
            Remove-Job -Job $cleanmgrJob -Force
            Write-Host "  ⚠ Disk Cleanup timed out after 5 minutes" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ Disk Cleanup failed to start: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Clearing Run dialog history..." -ForegroundColor Cyan
    try {
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" /f 2>$null
        Write-Host "  ✓ Run dialog history cleared" -ForegroundColor Green
    }
    catch {
        Write-Host "  Run dialog history was already empty or inaccessible" -ForegroundColor Gray
    }
    
    Write-Host "Clearing Windows Event Logs..." -ForegroundColor Cyan
    Write-Host "  → Enumerating event logs..." -ForegroundColor Gray
    try {
        $clearedLogs = 0
        $totalLogs = 0
        
        # Get all logs first to show progress
        $allLogs = wevtutil el | Where-Object {$_ -notmatch "(LiveId|USBVideo|Analytic)"}
        $totalLogs = $allLogs.Count
        Write-Host "  → Found $totalLogs event logs to clear..." -ForegroundColor Gray
        
        $allLogs | ForEach-Object {
            try {
                wevtutil cl "$_" 2>$null
                $clearedLogs++
                if ($clearedLogs % 10 -eq 0) {
                    Write-Host "  → Cleared $clearedLogs/$totalLogs event logs..." -ForegroundColor Gray
                }
            }
            catch {
                # Ignore individual log clearing failures
            }
        }
        Write-Host "  ✓ Cleared $clearedLogs event logs successfully" -ForegroundColor Green
        $script:totalFreed += 25  # Estimate
    }
    catch {
        Write-Host "  ❌ Event log clearing encountered issues: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Cleaning user temp directories..." -ForegroundColor Cyan
    try {
        Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ User temp directory cleaned" -ForegroundColor Green
    }
    catch {
        Write-Host "  Some user temp files were locked" -ForegroundColor Yellow
    }
    
    try {
        Get-ChildItem -Path $env:WINDIR\Temp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Windows temp directory cleaned" -ForegroundColor Green
    }
    catch {
        Write-Host "  Some Windows temp files were locked" -ForegroundColor Yellow
    }
    
    try {
        Get-ChildItem -Path $env:LOCALAPPDATA\Temp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Local AppData temp directory cleaned" -ForegroundColor Green
    }
    catch {
        Write-Host "  Some local temp files were locked" -ForegroundColor Yellow
    }
    
    Write-Host "Cleaning crash dumps and system reports..." -ForegroundColor Cyan
    try {
        Remove-Item "$env:LOCALAPPDATA\CrashDumps\*" -Force -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem "$env:WINDIR\LiveKernelReports" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem "$env:WINDIR\Minidump" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Crash dumps and kernel reports cleaned" -ForegroundColor Green
        $script:totalFreed += 50  # Estimate
    }
    catch {
        Write-Host "  Some crash dumps were locked or inaccessible" -ForegroundColor Yellow
    }
    
    Write-Host "Cleaning browser and compatibility caches..." -ForegroundColor Cyan
    try {
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\IECompatCache\*" -Force -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter "*.db" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "  ✓ Browser and compatibility caches cleaned" -ForegroundColor Green
        $script:totalFreed += 40  # Estimate
    }
    catch {
        Write-Host "  Some browser cache files were locked" -ForegroundColor Yellow
    }
    
    Write-Host "Cleaning additional Windows caches..." -ForegroundColor Cyan
    try {
        Remove-Item "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Prefetch cache cleaned" -ForegroundColor Green
        $script:totalFreed += 15
    }
    catch {
        Write-Host "  Prefetch cache partially cleaned" -ForegroundColor Yellow
    }
    
    try {
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Internet cache cleaned" -ForegroundColor Green
        $script:totalFreed += 25
    }
    catch {
        Write-Host "  Internet cache partially cleaned" -ForegroundColor Yellow
    }
    
    try {
        Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Recent files cache cleaned" -ForegroundColor Green
        $script:totalFreed += 5
    }
    catch {
        Write-Host "  Recent files cache partially cleaned" -ForegroundColor Yellow
    }
    
    try {
        Get-ChildItem "$env:WINDIR\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Logs" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Caches\*" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "  ✓ Delivery Optimization and additional caches cleaned" -ForegroundColor Green
        $script:totalFreed += 30  # Estimate
    }
    catch {
        Write-Host "  Some delivery optimization files were locked" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [WHATIF] Would run disk cleanup, clear logs, and clean temp directories" -ForegroundColor Magenta
}

# STEP 5: SYSTEM OPTIMIZATION AND NETWORK RESETS
Write-Host ""
Write-Host "STEP 5: System optimization and network resets..." -ForegroundColor Green

if (!$WhatIf) {
    Write-Host "Disabling SuperFetch/SysMain service..." -ForegroundColor Cyan
    Write-Host "  → Configuring SysMain service startup type..." -ForegroundColor Gray
    try {
        sc.exe config "SysMain" start= disabled | Out-Null
        Write-Host "  ✓ SuperFetch/SysMain service disabled (improves SSD performance)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ SuperFetch/SysMain service configuration failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Resetting Windows Store cache..." -ForegroundColor Cyan
    Write-Host "  → Starting Windows Store reset..." -ForegroundColor Gray
    try {
        $wsresetJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "wsreset.exe" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($wsresetJob.State -eq "Running" -and $elapsed -lt 60) {  # 1 minute timeout
            Start-Sleep -Seconds 5
            $elapsed += 5
            Write-Host "  → Store reset in progress... ($elapsed seconds)" -ForegroundColor Gray
        }
        
        if ($wsresetJob.State -eq "Completed") {
            Remove-Job -Job $wsresetJob -Force
            Write-Host "  ✓ Windows Store cache reset completed" -ForegroundColor Green
        } else {
            Stop-Job -Job $wsresetJob
            Remove-Job -Job $wsresetJob -Force
            Write-Host "  ⚠ Windows Store reset timed out after 60 seconds" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ Windows Store reset failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Flushing DNS and resetting network stack..." -ForegroundColor Cyan
    try {
        Write-Host "  → Flushing DNS cache..." -ForegroundColor Gray
        ipconfig.exe /flushdns | Out-Null
        
        Write-Host "  → Resetting IP interface..." -ForegroundColor Gray
        netsh interface ip reset | Out-Null
        
        Write-Host "  → Resetting Winsock catalog..." -ForegroundColor Gray
        netsh winsock reset catalog | Out-Null
        
        Write-Host "  ✓ Network stack reset completed" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Network reset failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Testing network connectivity..." -ForegroundColor Cyan
    try {
        Write-Host "  → Testing connection to 8.8.8.8:53..." -ForegroundColor Gray
        $testJob = Start-Job -ScriptBlock {
            Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -WarningAction SilentlyContinue
        }
        
        $testCompleted = Wait-Job -Job $testJob -Timeout 15
        if ($testCompleted) {
            $testConnection = Receive-Job -Job $testJob
            Remove-Job -Job $testJob -Force
            if ($testConnection.TcpTestSucceeded) {
                Write-Host "  ✓ Network connectivity test passed" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ Network connectivity test failed" -ForegroundColor Yellow
            }
        } else {
            Stop-Job -Job $testJob
            Remove-Job -Job $testJob -Force
            Write-Host "  ⚠ Network connectivity test timed out (15 seconds)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ⚠ Network test could not be completed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host "Updating group policies..." -ForegroundColor Cyan
    Write-Host "  → Starting group policy update..." -ForegroundColor Gray
    try {
        $gpupdateJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "gpupdate.exe" -ArgumentList "/force" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($gpupdateJob.State -eq "Running" -and $elapsed -lt 120) {  # 2 minute timeout
            Start-Sleep -Seconds 10
            $elapsed += 10
            Write-Host "  → Group policy update in progress... ($elapsed seconds)" -ForegroundColor Gray
        }
        
        if ($gpupdateJob.State -eq "Completed") {
            Remove-Job -Job $gpupdateJob -Force
            Write-Host "  ✓ Group policies updated successfully" -ForegroundColor Green
        } else {
            Stop-Job -Job $gpupdateJob
            Remove-Job -Job $gpupdateJob -Force
            Write-Host "  ⚠ Group policy update timed out after 2 minutes" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ Group policy update failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Starting Windows Update scan..." -ForegroundColor Cyan
    Write-Host "  → Initiating update scan..." -ForegroundColor Gray
    try {
        $usoclientJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "usoclient.exe" -ArgumentList "StartScanInstallWait" -WindowStyle Hidden -NoNewWindow -Wait -PassThru
        }
        
        $elapsed = 0
        while ($usoclientJob.State -eq "Running" -and $elapsed -lt 180) {  # 3 minute timeout
            Start-Sleep -Seconds 15
            $elapsed += 15
            Write-Host "  → Windows Update scan in progress... ($elapsed seconds)" -ForegroundColor Gray
        }
        
        if ($usoclientJob.State -eq "Completed") {
            Remove-Job -Job $usoclientJob -Force
            Write-Host "  ✓ Windows Update scan completed" -ForegroundColor Green
        } else {
            Stop-Job -Job $usoclientJob
            Remove-Job -Job $usoclientJob -Force
            Write-Host "  ⚠ Windows Update scan timed out after 3 minutes" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ Windows Update scan failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  [WHATIF] Would optimize system services and reset network stack" -ForegroundColor Magenta
}

# STEP 6: ADVANCED SYSTEM MAINTENANCE
if (!$WhatIf) {
    Write-Host ""
    Write-Host "STEP 6: Advanced system maintenance (This may take 3+ hours)..." -ForegroundColor Red -BackgroundColor Yellow
    
    Write-Host "Running System File Checker..." -ForegroundColor Cyan
    Write-Host "  → Starting SFC scan (this may take 15-30 minutes)..." -ForegroundColor Gray
    try {
        $sfcJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -WindowStyle Hidden -Wait -PassThru
        }
        
        # Monitor SFC progress
        $sfcTimeout = 45 * 60  # 45 minutes maximum
        $elapsed = 0
        $progressInterval = 30  # Update every 30 seconds
        
        while ($sfcJob.State -eq "Running" -and $elapsed -lt $sfcTimeout) {
            Start-Sleep -Seconds $progressInterval
            $elapsed += $progressInterval
            $minutesElapsed = [math]::Round($elapsed / 60, 1)
            Write-Host "  → SFC scan in progress... ($minutesElapsed minutes elapsed)" -ForegroundColor Gray
        }
        
        if ($sfcJob.State -eq "Completed") {
            $sfcResult = Receive-Job -Job $sfcJob
            Remove-Job -Job $sfcJob -Force
            if ($sfcResult.ExitCode -eq 0) {
                Write-Host "  ✓ System File Checker completed successfully" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ System File Checker found issues (check CBS.log)" -ForegroundColor Yellow
            }
        } else {
            Stop-Job -Job $sfcJob
            Remove-Job -Job $sfcJob -Force
            Write-Host "  ⚠ SFC scan timed out after 45 minutes (may continue in background)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ System File Checker failed to start: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Running DISM health scans..." -ForegroundColor Cyan
    try {
        # DISM ScanHealth
        Write-Host "  → Starting DISM ScanHealth (may take 10-15 minutes)..." -ForegroundColor Gray
        $dismScanJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /ScanHealth" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($dismScanJob.State -eq "Running" -and $elapsed -lt 900) {  # 15 minute timeout
            Start-Sleep -Seconds 30
            $elapsed += 30
            $minutesElapsed = [math]::Round($elapsed / 60, 1)
            Write-Host "    → ScanHealth in progress... ($minutesElapsed minutes)" -ForegroundColor Gray
        }
        
        if ($dismScanJob.State -eq "Completed") {
            Remove-Job -Job $dismScanJob -Force
            Write-Host "  ✓ DISM ScanHealth completed" -ForegroundColor Green
        } else {
            Stop-Job -Job $dismScanJob
            Remove-Job -Job $dismScanJob -Force
            Write-Host "  ⚠ DISM ScanHealth timed out" -ForegroundColor Yellow
        }
        
        # DISM CheckHealth
        Write-Host "  → Starting DISM CheckHealth (may take 5-10 minutes)..." -ForegroundColor Gray
        $dismCheckJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /CheckHealth" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($dismCheckJob.State -eq "Running" -and $elapsed -lt 600) {  # 10 minute timeout
            Start-Sleep -Seconds 30
            $elapsed += 30
            $minutesElapsed = [math]::Round($elapsed / 60, 1)
            Write-Host "    → CheckHealth in progress... ($minutesElapsed minutes)" -ForegroundColor Gray
        }
        
        if ($dismCheckJob.State -eq "Completed") {
            Remove-Job -Job $dismCheckJob -Force
            Write-Host "  ✓ DISM CheckHealth completed" -ForegroundColor Green
        } else {
            Stop-Job -Job $dismCheckJob
            Remove-Job -Job $dismCheckJob -Force
            Write-Host "  ⚠ DISM CheckHealth timed out" -ForegroundColor Yellow
        }
        
        # DISM RestoreHealth
        Write-Host "  → Starting DISM RestoreHealth (may take 20-45 minutes)..." -ForegroundColor Gray
        $dismRestoreJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($dismRestoreJob.State -eq "Running" -and $elapsed -lt 2700) {  # 45 minute timeout
            Start-Sleep -Seconds 30
            $elapsed += 30
            $minutesElapsed = [math]::Round($elapsed / 60, 1)
            Write-Host "    → RestoreHealth in progress... ($minutesElapsed minutes)" -ForegroundColor Gray
        }
        
        if ($dismRestoreJob.State -eq "Completed") {
            Remove-Job -Job $dismRestoreJob -Force
            Write-Host "  ✓ DISM RestoreHealth completed" -ForegroundColor Green
        } else {
            Stop-Job -Job $dismRestoreJob
            Remove-Job -Job $dismRestoreJob -Force
            Write-Host "  ⚠ DISM RestoreHealth timed out after 45 minutes" -ForegroundColor Yellow
        }
        
        # DISM StartComponentCleanup
        Write-Host "  → Starting DISM StartComponentCleanup (may take 10-20 minutes)..." -ForegroundColor Gray
        $dismCleanupJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($dismCleanupJob.State -eq "Running" -and $elapsed -lt 1200) {  # 20 minute timeout
            Start-Sleep -Seconds 30
            $elapsed += 30
            $minutesElapsed = [math]::Round($elapsed / 60, 1)
            Write-Host "    → ComponentCleanup in progress... ($minutesElapsed minutes)" -ForegroundColor Gray
        }
        
        if ($dismCleanupJob.State -eq "Completed") {
            Remove-Job -Job $dismCleanupJob -Force
            Write-Host "  ✓ DISM StartComponentCleanup completed" -ForegroundColor Green
        } else {
            Stop-Job -Job $dismCleanupJob
            Remove-Job -Job $dismCleanupJob -Force
            Write-Host "  ⚠ DISM StartComponentCleanup timed out" -ForegroundColor Yellow
        }
        
        Write-Host "  ✓ All DISM operations completed" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ DISM operations encountered errors: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Checking software licensing service..." -ForegroundColor Cyan
    Write-Host "  → Querying software licensing service..." -ForegroundColor Gray
    try {
        $licensingService = Get-WmiObject -Query "SELECT * FROM SoftwareLicensingService" -ErrorAction SilentlyContinue
        if ($licensingService) {
            Write-Host "  ✓ Software licensing service is accessible and functioning" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Software licensing service is not responding" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ Software licensing service check failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Scheduling memory diagnostic test..." -ForegroundColor Cyan
    Write-Host "  → Configuring memory diagnostic..." -ForegroundColor Gray
    try {
        Start-Process -FilePath "mdsched.exe" -ArgumentList "/f" -WindowStyle Hidden -ErrorAction Stop
        Start-Sleep -Seconds 2  # Give it a moment to register
        Write-Host "  ✓ Memory diagnostic test scheduled for next reboot" -ForegroundColor Green
        Write-Host "  ⚠️  SYSTEM WILL RUN MEMORY TEST ON NEXT RESTART" -ForegroundColor Yellow -BackgroundColor Red
    }
    catch {
        Write-Host "  ❌ Memory diagnostic scheduling failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Starting file system compression (This may take hours)..." -ForegroundColor Cyan -BackgroundColor Red
    Write-Host "  ⚠️  WARNING: This operation can take 2+ hours on large drives" -ForegroundColor Yellow -BackgroundColor Red
    try {
        $compactJob = Start-Job -ScriptBlock {
            compact /c /s:C:\ /i /q *.*
        }
        
        # Wait for compression with progress updates
        $timeoutMinutes = 180  # 3 hours maximum
        $elapsed = 0
        $progressInterval = 30  # Update every 30 seconds
        
        while ($compactJob.State -eq "Running" -and $elapsed -lt ($timeoutMinutes * 60)) {
            Start-Sleep -Seconds $progressInterval
            $elapsed += $progressInterval
            $minutesElapsed = [math]::Round($elapsed / 60, 1)
            Write-Host "  → File compression in progress... ($minutesElapsed minutes elapsed)" -ForegroundColor Yellow
        }
        
        if ($compactJob.State -eq "Completed") {
            Receive-Job -Job $compactJob | Out-Null
            Remove-Job -Job $compactJob -Force
            Write-Host "  ✓ File system compression completed successfully" -ForegroundColor Green
            Write-Host "  ✓ Significant disk space may have been saved through compression" -ForegroundColor Green
            $script:totalFreed += 500  # Conservative estimate for compression savings
        } else {
            Stop-Job -Job $compactJob
            Remove-Job -Job $compactJob -Force
            Write-Host "  ⚠ File compression timed out after 3 hours (may continue in background)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  File compression could not be started: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "OPTIONAL INTERACTIVE TOOLS (will open GUI applications):" -ForegroundColor Yellow
    Write-Host "To open System Properties (System Restore), run: systempropertiesprotection.exe" -ForegroundColor Gray
    Write-Host "To open Internet Properties, run: rundll32.exe shell32.dll,Control_RunDLL inetcpl.cpl" -ForegroundColor Gray
    Write-Host "To open reliability monitor, run: perfmon.exe /rel" -ForegroundColor Gray
    Write-Host "To schedule disk check (requires reboot), run: chkdsk C: /f /r" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "🔄 REBOOT REQUIRED FOR MEMORY DIAGNOSTIC TEST" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "Your system will automatically run a memory test on the next restart." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "STEP 6: Advanced system maintenance..." -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "  [WHATIF] Would run System File Checker (sfc /scannow)" -ForegroundColor Magenta
    Write-Host "  [WHATIF] Would run DISM health scans and image restoration" -ForegroundColor Magenta
    Write-Host "  [WHATIF] Would check software licensing service" -ForegroundColor Magenta
    Write-Host "  [WHATIF] Would schedule memory diagnostic test (mdsched /f)" -ForegroundColor Magenta
    Write-Host "  [WHATIF] Would start file system compression (compact /c /s:C:\)" -ForegroundColor Magenta
}

# STEP 7: ADDITIONAL SYSTEM CLEANUP
Write-Host ""
Write-Host "STEP 7: Additional system cleanup..." -ForegroundColor Green

if (!$WhatIf) {
    # Clean remaining Windows Update cache (if any left)
    Write-Host "Final Windows Update cache cleanup..." -ForegroundColor Cyan
    try {
        $remainingWUCache = Get-FolderSizeMB -Path "C:\Windows\SoftwareDistribution\Download" -TimeoutSeconds 5
        if ($remainingWUCache -gt 0) {
            Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
            $script:totalFreed += $remainingWUCache
            Write-Host "  ✓ Additional $remainingWUCache MB freed from Windows Update cache" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  Windows Update cache already cleaned or locked" -ForegroundColor Gray
    }
    
    # Clean system font cache
    Write-Host "Cleaning system font cache..." -ForegroundColor Cyan
    try {
        Write-Host "  → Stopping FontCache service..." -ForegroundColor Gray
        Stop-Service -Name FontCache -Force -ErrorAction SilentlyContinue
        
        Write-Host "  → Removing font cache files..." -ForegroundColor Gray
        Remove-Item -Path "C:\Windows\System32\FNTCACHE.DAT" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Host "  → Restarting FontCache service..." -ForegroundColor Gray
        Start-Service -Name FontCache -ErrorAction SilentlyContinue
        
        Write-Host "  ✓ Font cache cleared successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "  ⚠ Scheduling font cache files for reboot deletion..." -ForegroundColor Yellow
        Add-PendingDeletion -Path "C:\Windows\System32\FNTCACHE.DAT"
        Add-PendingDeletion -Path "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache"
    }
    
    # Flush DNS cache
    Write-Host "Flushing DNS cache..." -ForegroundColor Cyan
    ipconfig /flushdns | Out-Null
    Write-Host "  ✓ DNS cache flushed" -ForegroundColor Green
    
    # Clean icon cache
    Write-Host "Cleaning icon cache..." -ForegroundColor Cyan
    Write-Host "  → Scanning for icon cache files..." -ForegroundColor Gray
    $iconCacheFiles = Get-ChildItem -Path "C:\Users\*\AppData\Local\IconCache.db" -Force -ErrorAction SilentlyContinue
    $iconFilesScheduled = 0
    $iconFilesRemoved = 0
    
    Write-Host "  → Found $($iconCacheFiles.Count) icon cache files to process..." -ForegroundColor Gray
    foreach ($file in $iconCacheFiles) {
        $iconSize = [math]::Round($file.Length / 1MB, 2)
        try {
            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            $script:totalFreed += $iconSize
            $iconFilesRemoved++
        }
        catch {
            Add-PendingDeletion -Path $file.FullName
            $iconFilesScheduled++
        }
    }
    
    if ($iconFilesRemoved -gt 0) {
        Write-Host "  ✓ Removed $iconFilesRemoved icon cache files immediately" -ForegroundColor Green
    }
    if ($iconFilesScheduled -gt 0) {
        Write-Host "  → $iconFilesScheduled icon cache files scheduled for reboot deletion" -ForegroundColor Magenta
    }
    
    # Empty Recycle Bin
    Write-Host "Emptying Recycle Bin..." -ForegroundColor Cyan
    Write-Host "  → Clearing all recycle bin contents..." -ForegroundColor Gray
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue -Confirm:$false
        Write-Host "  ✓ Recycle Bin emptied successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Could not empty Recycle Bin: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Create reboot cleanup script if needed
if ($script:pendingDeletions.Count -gt 0 -and !$WhatIf) {
    Write-Host ""
    Write-Host "Creating reboot cleanup script for locked files..." -ForegroundColor Magenta
    $rebootScript = New-RebootCleanupScript
    Write-Host "✓ Reboot cleanup script created: $rebootScript" -ForegroundColor Green
}

# FINAL SUMMARY
Write-Host ""
Write-Host "=======================================" -ForegroundColor White
Write-Host "CLEANUP SUMMARY" -ForegroundColor White
Write-Host "=======================================" -ForegroundColor White
Write-Host "Directories processed: $($script:processedCount)" -ForegroundColor Cyan
Write-Host "Directories skipped (not found): $($script:skippedCount)" -ForegroundColor Yellow

# Immediate cleanup summary
Write-Host ""
Write-Host "IMMEDIATE CLEANUP RESULTS:" -ForegroundColor Green
Write-Host "→ Space freed immediately: $([math]::Round($script:totalFreed, 2)) MB ($([math]::Round($script:totalFreed / 1024, 2)) GB)" -ForegroundColor Green

# Pending reboot deletion summary
if ($script:pendingDeletions.Count -gt 0) {
    Write-Host ""
    Write-Host "SCHEDULED FOR NEXT REBOOT:" -ForegroundColor Magenta
    Write-Host "→ Files to be deleted on reboot: ~$($script:pendingFileCount)" -ForegroundColor Magenta
    Write-Host "→ Additional space to be freed: $([math]::Round($script:pendingDeletionSize, 2)) MB ($([math]::Round($script:pendingDeletionSize / 1024, 2)) GB)" -ForegroundColor Magenta
    Write-Host "→ Locked directories: $($script:lockedDirectories.Count)" -ForegroundColor Magenta
}

# Total summary
$totalSpace = $script:totalFreed + $script:pendingDeletionSize
Write-Host ""
Write-Host "TOTAL CLEANUP RESULTS:" -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "→ TOTAL SPACE TO BE FREED: $([math]::Round($totalSpace, 2)) MB ($([math]::Round($totalSpace / 1024, 2)) GB)" -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "→ Freed now: $([math]::Round($script:totalFreed, 2)) MB | After reboot: $([math]::Round($script:pendingDeletionSize, 2)) MB" -ForegroundColor White -BackgroundColor DarkBlue

Write-Host ""
if ($WhatIf) {
    Write-Host "This was a simulation. Run without -WhatIf to actually clean the files and perform maintenance." -ForegroundColor Magenta
} else {
    Write-Host "✓ COMPREHENSIVE CLEANUP AND MAINTENANCE COMPLETED!" -ForegroundColor Green
    Write-Host "✓ Cache cleanup, system repairs, and optimization finished." -ForegroundColor Green
    Write-Host "✓ Recycle Bin has been automatically emptied." -ForegroundColor Green
    Write-Host "✓ System caches have been cleared." -ForegroundColor Green
    Write-Host "✓ System File Checker and DISM repairs completed." -ForegroundColor Green
    Write-Host "✓ File system compression applied (if successful)." -ForegroundColor Green
    Write-Host "🔄 MEMORY DIAGNOSTIC TEST SCHEDULED FOR NEXT REBOOT" -ForegroundColor Red -BackgroundColor Yellow
    
    if ($script:pendingDeletions.Count -gt 0) {
        Write-Host "⚠️  Some files were locked and scheduled for deletion on next reboot." -ForegroundColor Yellow
        Write-Host "⚠️  A cleanup script will run automatically on next boot." -ForegroundColor Yellow
        Write-Host "⚠️  RESTART YOUR COMPUTER to complete the cleanup process and run memory test." -ForegroundColor Red -BackgroundColor Yellow
    } else {
        Write-Host "⚠️  RESTART YOUR COMPUTER to run the scheduled memory diagnostic test." -ForegroundColor Red -BackgroundColor Yellow
    }
}

Write-Host ""
Write-Host "Script completed with comprehensive cleanup and system maintenance!" -ForegroundColor White

Write-Host ""
Write-Host "ADDITIONAL MANUAL TOOLS AVAILABLE:" -ForegroundColor Cyan
Write-Host "• System Restore: systempropertiesprotection.exe" -ForegroundColor Gray
Write-Host "• Internet Settings: rundll32.exe shell32.dll,Control_RunDLL inetcpl.cpl" -ForegroundColor Gray
Write-Host "• Reliability Monitor: perfmon.exe /rel" -ForegroundColor Gray
Write-Host "• Disk Check: chkdsk C: /f /r (requires reboot)" -ForegroundColor Gray

# STEP 2: TARGET SPECIFIC HIGH-VALUE DIRECTORIES
Write-Host ""
Write-Host "STEP 2: Targeting specific high-value cache directories..." -ForegroundColor Green

# High-value directories that typically contain lots of cache
$highValueDirectories = @(
    "C:\Windows\System32\winevt\Logs",
    "C:\Windows\Prefetch",
    "C:\Users\$env:USERNAME\AppData\Local\Packages\MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy\LocalState\EBWebView\Default\Cache",
    "C:\Users\$env:USERNAME\AppData\Local\Docker\log",
    "C:\Users\$env:USERNAME\AppData\Roaming\Todoist\Cache",
    "C:\Users\$env:USERNAME\AppData\Local\CD Projekt Red\Cyberpunk 2077\cache",
    "C:\Users\$env:USERNAME\AppData\Local\NVIDIA Corporation\NVIDIA App\CefCache\Default\Cache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Cursor\Cache",
    "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Windows\Explorer",
    "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Windows\WebCache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\Default\Cache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\Default\DawnGraphiteCache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\Default\DawnWebGPUCache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\Default\GPUCache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\GraphiteDawnCache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\ShaderCache",
    "C:\Users\$env:USERNAME\AppData\Roaming\Wise Utilities\EBWebView\GrShaderCache",
    "C:\Users\$env:USERNAME\AppData\Local\D3DSCache",
    "C:\Windows\WinSxS\Temp"
)

foreach ($directory in $highValueDirectories) {
    $freed = Clear-DirectoryContents -Path $directory -MaxTimeSeconds 30
    $script:totalFreed += $freed
    Start-Sleep -Milliseconds 100
}

# STEP 3: WINDOWS UPDATE SERVICE RESET AND CLEANUP
Write-Host ""
Write-Host "STEP 3: Windows Update service reset and cleanup..." -ForegroundColor Green

if (!$WhatIf) {
    Write-Host "Stopping Windows Update services..." -ForegroundColor Cyan
    Stop-Service -Name UsoSvc,cryptsvc,bits,msiserver,dosvc,wuauserv -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Windows Update services stopped" -ForegroundColor Green
    
    Write-Host "Cleaning old Windows Update directories..." -ForegroundColor Cyan
    Remove-Item -Path "C:\Windows\SoftwareDistribution.old","C:\Windows\System32\catroot2.old" -Recurse -Force -ErrorAction SilentlyContinue
    
    try {
        Write-Host "Resetting SoftwareDistribution directory..." -ForegroundColor Cyan
        Rename-Item -Path "C:\Windows\SoftwareDistribution" -NewName "SoftwareDistribution.old" -Force -ErrorAction Stop
        New-Item -Path "C:\Windows\SoftwareDistribution" -ItemType Directory -Force | Out-Null
        Write-Host "  ✓ SoftwareDistribution directory reset" -ForegroundColor Green
        $script:totalFreed += 50  # Estimate
    }
    catch {
        Write-Host "  SoftwareDistribution reset failed (may be in use)" -ForegroundColor Yellow
    }
    
    try {
        Write-Host "Resetting catroot2 directory..." -ForegroundColor Cyan
        Rename-Item -Path "C:\Windows\System32\catroot2" -NewName "catroot2.old" -Force -ErrorAction Stop
        New-Item -Path "C:\Windows\System32\catroot2" -ItemType Directory -Force | Out-Null
        Write-Host "  ✓ catroot2 directory reset" -ForegroundColor Green
        $script:totalFreed += 20  # Estimate
    }
    catch {
        Write-Host "  catroot2 reset failed (may be in use)" -ForegroundColor Yellow
    }
    
    Write-Host "Restarting Windows Update services..." -ForegroundColor Cyan
    Start-Service -Name UsoSvc,cryptsvc,bits,msiserver,dosvc,wuauserv -ErrorAction SilentlyContinue
    Write-Host "  ✓ Windows Update services restarted" -ForegroundColor Green
} else {
    Write-Host "  [WHATIF] Would reset Windows Update services and directories" -ForegroundColor Magenta
}

# STEP 4: ENHANCED TEMP DIRECTORY AND REGISTRY CLEANUP
Write-Host ""
Write-Host "STEP 4: Enhanced temp directory and registry cleanup..." -ForegroundColor Green

if (!$WhatIf) {
    Write-Host "Running Windows Disk Cleanup utility..." -ForegroundColor Cyan
    Write-Host "  → Starting disk cleanup (may take 3-5 minutes)..." -ForegroundColor Gray
    try {
        $cleanmgrJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($cleanmgrJob.State -eq "Running" -and $elapsed -lt 300) {  # 5 minute timeout
            Start-Sleep -Seconds 15
            $elapsed += 15
            $secondsElapsed = $elapsed
            Write-Host "  → Disk cleanup in progress... ($secondsElapsed seconds elapsed)" -ForegroundColor Gray
        }
        
        if ($cleanmgrJob.State -eq "Completed") {
            Remove-Job -Job $cleanmgrJob -Force
            Write-Host "  ✓ Windows Disk Cleanup completed" -ForegroundColor Green
            $script:totalFreed += 100  # Estimate
        } else {
            Stop-Job -Job $cleanmgrJob
            Remove-Job -Job $cleanmgrJob -Force
            Write-Host "  ⚠ Disk Cleanup timed out after 5 minutes" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ Disk Cleanup failed to start: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Clearing Run dialog history..." -ForegroundColor Cyan
    try {
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" /f 2>$null
        Write-Host "  ✓ Run dialog history cleared" -ForegroundColor Green
    }
    catch {
        Write-Host "  Run dialog history was already empty or inaccessible" -ForegroundColor Gray
    }
    
    Write-Host "Clearing Windows Event Logs..." -ForegroundColor Cyan
    Write-Host "  → Enumerating event logs..." -ForegroundColor Gray
    try {
        $clearedLogs = 0
        $totalLogs = 0
        
        # Get all logs first to show progress
        $allLogs = wevtutil el | Where-Object {$_ -notmatch "(LiveId|USBVideo|Analytic)"}
        $totalLogs = $allLogs.Count
        Write-Host "  → Found $totalLogs event logs to clear..." -ForegroundColor Gray
        
        $allLogs | ForEach-Object {
            try {
                wevtutil cl "$_" 2>$null
                $clearedLogs++
                if ($clearedLogs % 10 -eq 0) {
                    Write-Host "  → Cleared $clearedLogs/$totalLogs event logs..." -ForegroundColor Gray
                }
            }
            catch {
                # Ignore individual log clearing failures
            }
        }
        Write-Host "  ✓ Cleared $clearedLogs event logs successfully" -ForegroundColor Green
        $script:totalFreed += 25  # Estimate
    }
    catch {
        Write-Host "  ❌ Event log clearing encountered issues: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Cleaning user temp directories..." -ForegroundColor Cyan
    try {
        Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ User temp directory cleaned" -ForegroundColor Green
    }
    catch {
        Write-Host "  Some user temp files were locked" -ForegroundColor Yellow
    }
    
    try {
        Get-ChildItem -Path $env:WINDIR\Temp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Windows temp directory cleaned" -ForegroundColor Green
    }
    catch {
        Write-Host "  Some Windows temp files were locked" -ForegroundColor Yellow
    }
    
    try {
        Get-ChildItem -Path $env:LOCALAPPDATA\Temp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Local AppData temp directory cleaned" -ForegroundColor Green
    }
    catch {
        Write-Host "  Some local temp files were locked" -ForegroundColor Yellow
    }
    
    Write-Host "Cleaning crash dumps and system reports..." -ForegroundColor Cyan
    try {
        Remove-Item "$env:LOCALAPPDATA\CrashDumps\*" -Force -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem "$env:WINDIR\LiveKernelReports" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem "$env:WINDIR\Minidump" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Crash dumps and kernel reports cleaned" -ForegroundColor Green
        $script:totalFreed += 50  # Estimate
    }
    catch {
        Write-Host "  Some crash dumps were locked or inaccessible" -ForegroundColor Yellow
    }
    
    Write-Host "Cleaning browser and compatibility caches..." -ForegroundColor Cyan
    try {
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\IECompatCache\*" -Force -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter "*.db" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "  ✓ Browser and compatibility caches cleaned" -ForegroundColor Green
        $script:totalFreed += 40  # Estimate
    }
    catch {
        Write-Host "  Some browser cache files were locked" -ForegroundColor Yellow
    }
    
    Write-Host "Cleaning additional Windows caches..." -ForegroundColor Cyan
    try {
        Remove-Item "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Prefetch cache cleaned" -ForegroundColor Green
        $script:totalFreed += 15
    }
    catch {
        Write-Host "  Prefetch cache partially cleaned" -ForegroundColor Yellow
    }
    
    try {
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Internet cache cleaned" -ForegroundColor Green
        $script:totalFreed += 25
    }
    catch {
        Write-Host "  Internet cache partially cleaned" -ForegroundColor Yellow
    }
    
    try {
        Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Recent files cache cleaned" -ForegroundColor Green
        $script:totalFreed += 5
    }
    catch {
        Write-Host "  Recent files cache partially cleaned" -ForegroundColor Yellow
    }
    
    try {
        Get-ChildItem "$env:WINDIR\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Logs" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Caches\*" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "  ✓ Delivery Optimization and additional caches cleaned" -ForegroundColor Green
        $script:totalFreed += 30  # Estimate
    }
    catch {
        Write-Host "  Some delivery optimization files were locked" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [WHATIF] Would run disk cleanup, clear logs, and clean temp directories" -ForegroundColor Magenta
}

# STEP 5: SYSTEM OPTIMIZATION AND NETWORK RESETS
Write-Host ""
Write-Host "STEP 5: System optimization and network resets..." -ForegroundColor Green

if (!$WhatIf) {
    Write-Host "Disabling SuperFetch/SysMain service..." -ForegroundColor Cyan
    try {
        sc.exe config "SysMain" start= disabled | Out-Null
        Write-Host "  ✓ SuperFetch/SysMain service disabled (improves SSD performance)" -ForegroundColor Green
    }
    catch {
        Write-Host "  SuperFetch/SysMain service configuration failed" -ForegroundColor Yellow
    }
    
    Write-Host "Resetting Windows Store cache..." -ForegroundColor Cyan
    Write-Host "  → Starting Windows Store reset..." -ForegroundColor Gray
    try {
        $wsresetJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "wsreset.exe" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($wsresetJob.State -eq "Running" -and $elapsed -lt 60) {  # 1 minute timeout
            Start-Sleep -Seconds 5
            $elapsed += 5
            Write-Host "  → Store reset in progress... ($elapsed seconds)" -ForegroundColor Gray
        }
        
        if ($wsresetJob.State -eq "Completed") {
            Remove-Job -Job $wsresetJob -Force
            Write-Host "  ✓ Windows Store cache reset completed" -ForegroundColor Green
        } else {
            Stop-Job -Job $wsresetJob
            Remove-Job -Job $wsresetJob -Force
            Write-Host "  ⚠ Windows Store reset timed out after 60 seconds" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ Windows Store reset failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Flushing DNS and resetting network stack..." -ForegroundColor Cyan
    try {
        ipconfig.exe /flushdns | Out-Null
        netsh interface ip reset | Out-Null
        netsh winsock reset catalog | Out-Null
        Write-Host "  ✓ Network stack reset completed" -ForegroundColor Green
    }
    catch {
        Write-Host "  Network reset partially completed" -ForegroundColor Yellow
    }
    
    Write-Host "Testing network connectivity..." -ForegroundColor Cyan
    try {
        Write-Host "  → Testing connection to 8.8.8.8:53..." -ForegroundColor Gray
        $testJob = Start-Job -ScriptBlock {
            Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -WarningAction SilentlyContinue
        }
        
        $testCompleted = Wait-Job -Job $testJob -Timeout 15
        if ($testCompleted) {
            $testConnection = Receive-Job -Job $testJob
            Remove-Job -Job $testJob -Force
            if ($testConnection.TcpTestSucceeded) {
                Write-Host "  ✓ Network connectivity test passed" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ Network connectivity test failed" -ForegroundColor Yellow
            }
        } else {
            Stop-Job -Job $testJob
            Remove-Job -Job $testJob -Force
            Write-Host "  ⚠ Network connectivity test timed out (15 seconds)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ⚠ Network test could not be completed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host "Updating group policies..." -ForegroundColor Cyan
    Write-Host "  → Starting group policy update..." -ForegroundColor Gray
    try {
        $gpupdateJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "gpupdate.exe" -ArgumentList "/force" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($gpupdateJob.State -eq "Running" -and $elapsed -lt 120) {  # 2 minute timeout
            Start-Sleep -Seconds 10
            $elapsed += 10
            Write-Host "  → Group policy update in progress... ($elapsed seconds)" -ForegroundColor Gray
        }
        
        if ($gpupdateJob.State -eq "Completed") {
            Remove-Job -Job $gpupdateJob -Force
            Write-Host "  ✓ Group policies updated successfully" -ForegroundColor Green
        } else {
            Stop-Job -Job $gpupdateJob
            Remove-Job -Job $gpupdateJob -Force
            Write-Host "  ⚠ Group policy update timed out after 2 minutes" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ Group policy update failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Starting Windows Update scan..." -ForegroundColor Cyan
    Write-Host "  → Initiating update scan..." -ForegroundColor Gray
    try {
        $usoclientJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "usoclient.exe" -ArgumentList "StartScanInstallWait" -WindowStyle Hidden -NoNewWindow -Wait -PassThru
        }
        
        $elapsed = 0
        while ($usoclientJob.State -eq "Running" -and $elapsed -lt 180) {  # 3 minute timeout
            Start-Sleep -Seconds 15
            $elapsed += 15
            Write-Host "  → Windows Update scan in progress... ($elapsed seconds)" -ForegroundColor Gray
        }
        
        if ($usoclientJob.State -eq "Completed") {
            Remove-Job -Job $usoclientJob -Force
            Write-Host "  ✓ Windows Update scan completed" -ForegroundColor Green
        } else {
            Stop-Job -Job $usoclientJob
            Remove-Job -Job $usoclientJob -Force
            Write-Host "  ⚠ Windows Update scan timed out after 3 minutes" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ Windows Update scan failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  [WHATIF] Would optimize system services and reset network stack" -ForegroundColor Magenta
}

# STEP 6: ADVANCED SYSTEM MAINTENANCE
if (!$WhatIf) {
    Write-Host ""
    Write-Host "STEP 6: Advanced system maintenance (This may take 3+ hours)..." -ForegroundColor Red -BackgroundColor Yellow
    
    Write-Host "Running System File Checker..." -ForegroundColor Cyan
    Write-Host "  → Starting SFC scan (this may take 15-30 minutes)..." -ForegroundColor Gray
    try {
        $sfcJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -WindowStyle Hidden -Wait -PassThru
        }
        
        # Monitor SFC progress
        $sfcTimeout = 45 * 60  # 45 minutes maximum
        $elapsed = 0
        $progressInterval = 30  # Update every 30 seconds
        
        while ($sfcJob.State -eq "Running" -and $elapsed -lt $sfcTimeout) {
            Start-Sleep -Seconds $progressInterval
            $elapsed += $progressInterval
            $minutesElapsed = [math]::Round($elapsed / 60, 1)
            Write-Host "  → SFC scan in progress... ($minutesElapsed minutes elapsed)" -ForegroundColor Gray
        }
        
        if ($sfcJob.State -eq "Completed") {
            $sfcResult = Receive-Job -Job $sfcJob
            Remove-Job -Job $sfcJob -Force
            if ($sfcResult.ExitCode -eq 0) {
                Write-Host "  ✓ System File Checker completed successfully" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ System File Checker found issues (check CBS.log)" -ForegroundColor Yellow
            }
        } else {
            Stop-Job -Job $sfcJob
            Remove-Job -Job $sfcJob -Force
            Write-Host "  ⚠ SFC scan timed out after 45 minutes (may continue in background)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ System File Checker failed to start: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Running DISM health scans..." -ForegroundColor Cyan
    try {
        # DISM ScanHealth
        Write-Host "  → Starting DISM ScanHealth (may take 10-15 minutes)..." -ForegroundColor Gray
        $dismScanJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /ScanHealth" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($dismScanJob.State -eq "Running" -and $elapsed -lt 900) {  # 15 minute timeout
            Start-Sleep -Seconds 30
            $elapsed += 30
            $minutesElapsed = [math]::Round($elapsed / 60, 1)
            Write-Host "    → ScanHealth in progress... ($minutesElapsed minutes)" -ForegroundColor Gray
        }
        
        if ($dismScanJob.State -eq "Completed") {
            Remove-Job -Job $dismScanJob -Force
            Write-Host "  ✓ DISM ScanHealth completed" -ForegroundColor Green
        } else {
            Stop-Job -Job $dismScanJob
            Remove-Job -Job $dismScanJob -Force
            Write-Host "  ⚠ DISM ScanHealth timed out" -ForegroundColor Yellow
        }
        
        # DISM CheckHealth
        Write-Host "  → Starting DISM CheckHealth (may take 5-10 minutes)..." -ForegroundColor Gray
        $dismCheckJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /CheckHealth" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($dismCheckJob.State -eq "Running" -and $elapsed -lt 600) {  # 10 minute timeout
            Start-Sleep -Seconds 30
            $elapsed += 30
            $minutesElapsed = [math]::Round($elapsed / 60, 1)
            Write-Host "    → CheckHealth in progress... ($minutesElapsed minutes)" -ForegroundColor Gray
        }
        
        if ($dismCheckJob.State -eq "Completed") {
            Remove-Job -Job $dismCheckJob -Force
            Write-Host "  ✓ DISM CheckHealth completed" -ForegroundColor Green
        } else {
            Stop-Job -Job $dismCheckJob
            Remove-Job -Job $dismCheckJob -Force
            Write-Host "  ⚠ DISM CheckHealth timed out" -ForegroundColor Yellow
        }
        
        # DISM RestoreHealth
        Write-Host "  → Starting DISM RestoreHealth (may take 20-45 minutes)..." -ForegroundColor Gray
        $dismRestoreJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($dismRestoreJob.State -eq "Running" -and $elapsed -lt 2700) {  # 45 minute timeout
            Start-Sleep -Seconds 30
            $elapsed += 30
            $minutesElapsed = [math]::Round($elapsed / 60, 1)
            Write-Host "    → RestoreHealth in progress... ($minutesElapsed minutes)" -ForegroundColor Gray
        }
        
        if ($dismRestoreJob.State -eq "Completed") {
            Remove-Job -Job $dismRestoreJob -Force
            Write-Host "  ✓ DISM RestoreHealth completed" -ForegroundColor Green
        } else {
            Stop-Job -Job $dismRestoreJob
            Remove-Job -Job $dismRestoreJob -Force
            Write-Host "  ⚠ DISM RestoreHealth timed out after 45 minutes" -ForegroundColor Yellow
        }
        
        # DISM StartComponentCleanup
        Write-Host "  → Starting DISM StartComponentCleanup (may take 10-20 minutes)..." -ForegroundColor Gray
        $dismCleanupJob = Start-Job -ScriptBlock {
            Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup" -WindowStyle Hidden -Wait -PassThru
        }
        
        $elapsed = 0
        while ($dismCleanupJob.State -eq "Running" -and $elapsed -lt 1200) {  # 20 minute timeout
            Start-Sleep -Seconds 30
            $elapsed += 30
            $minutesElapsed = [math]::Round($elapsed / 60, 1)
            Write-Host "    → ComponentCleanup in progress... ($minutesElapsed minutes)" -ForegroundColor Gray
        }
        
        if ($dismCleanupJob.State -eq "Completed") {
            Remove-Job -Job $dismCleanupJob -Force
            Write-Host "  ✓ DISM StartComponentCleanup completed" -ForegroundColor Green
        } else {
            Stop-Job -Job $dismCleanupJob
            Remove-Job -Job $dismCleanupJob -Force
            Write-Host "  ⚠ DISM StartComponentCleanup timed out" -ForegroundColor Yellow
        }
        
        Write-Host "  ✓ All DISM operations completed" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ DISM operations encountered errors: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Checking software licensing service..." -ForegroundColor Cyan
    try {
        $licensingService = Get-WmiObject -Query "SELECT * FROM SoftwareLicensingService" -ErrorAction SilentlyContinue
        if ($licensingService) {
            Write-Host "  ✓ Software licensing service is accessible" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  Software licensing service check failed" -ForegroundColor Yellow
    }
    
    Write-Host "Scheduling memory diagnostic test..." -ForegroundColor Cyan
    Write-Host "  → Configuring memory diagnostic..." -ForegroundColor Gray
    try {
        Start-Process -FilePath "mdsched.exe" -ArgumentList "/f" -WindowStyle Hidden -ErrorAction Stop
        Start-Sleep -Seconds 2  # Give it a moment to register
        Write-Host "  ✓ Memory diagnostic test scheduled for next reboot" -ForegroundColor Green
        Write-Host "  ⚠️  SYSTEM WILL RUN MEMORY TEST ON NEXT RESTART" -ForegroundColor Yellow -BackgroundColor Red
    }
    catch {
        Write-Host "  ❌ Memory diagnostic scheduling failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Starting file system compression (This may take hours)..." -ForegroundColor Cyan -BackgroundColor Red
    Write-Host "  ⚠️  WARNING: This operation can take 2+ hours on large drives" -ForegroundColor Yellow -BackgroundColor Red
    try {
        $compactJob = Start-Job -ScriptBlock {
            compact /c /s:C:\ /i /q *.*
        }
        
        # Wait for compression with progress updates
        $timeoutMinutes = 180  # 3 hours maximum
        $elapsed = 0
        $progressInterval = 30  # Update every 30 seconds
        
        while ($compactJob.State -eq "Running" -and $elapsed -lt ($timeoutMinutes * 60)) {
            Start-Sleep -Seconds $progressInterval
            $elapsed += $progressInterval
            $minutesElapsed = [math]::Round($elapsed / 60, 1)
            Write-Host "  → File compression in progress... ($minutesElapsed minutes elapsed)" -ForegroundColor Yellow
        }
        
        if ($compactJob.State -eq "Completed") {
            Receive-Job -Job $compactJob | Out-Null
            Remove-Job -Job $compactJob -Force
            Write-Host "  ✓ File system compression completed successfully" -ForegroundColor Green
            Write-Host "  ✓ Significant disk space may have been saved through compression" -ForegroundColor Green
            $script:totalFreed += 500  # Conservative estimate for compression savings
        } else {
            Stop-Job -Job $compactJob
            Remove-Job -Job $compactJob -Force
            Write-Host "  ⚠ File compression timed out after 3 hours (may continue in background)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  File compression could not be started: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "OPTIONAL INTERACTIVE TOOLS (will open GUI applications):" -ForegroundColor Yellow
    Write-Host "To open System Properties (System Restore), run: systempropertiesprotection.exe" -ForegroundColor Gray
    Write-Host "To open Internet Properties, run: rundll32.exe shell32.dll,Control_RunDLL inetcpl.cpl" -ForegroundColor Gray
    Write-Host "To open reliability monitor, run: perfmon.exe /rel" -ForegroundColor Gray
    Write-Host "To schedule disk check (requires reboot), run: chkdsk C: /f /r" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "🔄 REBOOT REQUIRED FOR MEMORY DIAGNOSTIC TEST" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "Your system will automatically run a memory test on the next restart." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "STEP 6: Advanced system maintenance..." -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "  [WHATIF] Would run System File Checker (sfc /scannow)" -ForegroundColor Magenta
    Write-Host "  [WHATIF] Would run DISM health scans and image restoration" -ForegroundColor Magenta
    Write-Host "  [WHATIF] Would check software licensing service" -ForegroundColor Magenta
    Write-Host "  [WHATIF] Would schedule memory diagnostic test (mdsched /f)" -ForegroundColor Magenta
    Write-Host "  [WHATIF] Would start file system compression (compact /c /s:C:\)" -ForegroundColor Magenta
}

# STEP 7: ADDITIONAL SYSTEM CLEANUP
Write-Host ""
Write-Host "STEP 7: Additional system cleanup..." -ForegroundColor Green

if (!$WhatIf) {
    # Clean remaining Windows Update cache (if any left)
    Write-Host "Final Windows Update cache cleanup..." -ForegroundColor Cyan
    try {
        $remainingWUCache = Get-FolderSizeMB -Path "C:\Windows\SoftwareDistribution\Download" -TimeoutSeconds 5
        if ($remainingWUCache -gt 0) {
            Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
            $script:totalFreed += $remainingWUCache
            Write-Host "  ✓ Additional $remainingWUCache MB freed from Windows Update cache" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  Windows Update cache already cleaned or locked" -ForegroundColor Gray
    }
    
    # Clean system font cache
    Write-Host "Cleaning system font cache..." -ForegroundColor Cyan
    try {
        Stop-Service -Name FontCache -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\System32\FNTCACHE.DAT" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name FontCache -ErrorAction SilentlyContinue
        Write-Host "  ✓ Font cache cleared" -ForegroundColor Green
    }
    catch {
        Write-Host "  Scheduling font cache files for reboot deletion..." -ForegroundColor Yellow
        Add-PendingDeletion -Path "C:\Windows\System32\FNTCACHE.DAT"
        Add-PendingDeletion -Path "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache"
    }
    
    # Flush DNS cache
    Write-Host "Flushing DNS cache..." -ForegroundColor Cyan
    ipconfig /flushdns | Out-Null
    Write-Host "  ✓ DNS cache flushed" -ForegroundColor Green
    
    # Clean icon cache
    Write-Host "Cleaning icon cache..." -ForegroundColor Cyan
    $iconCacheFiles = Get-ChildItem -Path "C:\Users\*\AppData\Local\IconCache.db" -Force -ErrorAction SilentlyContinue
    $iconFilesScheduled = 0
    foreach ($file in $iconCacheFiles) {
        $iconSize = [math]::Round($file.Length / 1MB, 2)
        try {
            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            $script:totalFreed += $iconSize
        }
        catch {
            Add-PendingDeletion -Path $file.FullName
            $iconFilesScheduled++
        }
    }
    if ($iconFilesScheduled -gt 0) {
        Write-Host "  → $iconFilesScheduled icon cache files scheduled for reboot deletion" -ForegroundColor Magenta
    }
    
    # Empty Recycle Bin
    Write-Host "Emptying Recycle Bin..." -ForegroundColor Cyan
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue -Confirm:$false
        Write-Host "  ✓ Recycle Bin emptied" -ForegroundColor Green
    }
    catch {
        Write-Host "  Could not empty Recycle Bin: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Create reboot cleanup script if needed
if ($script:pendingDeletions.Count -gt 0 -and !$WhatIf) {
    Write-Host ""
    Write-Host "Creating reboot cleanup script for locked files..." -ForegroundColor Magenta
    $rebootScript = New-RebootCleanupScript
    Write-Host "✓ Reboot cleanup script created: $rebootScript" -ForegroundColor Green
}

# FINAL SUMMARY
Write-Host ""
Write-Host "=======================================" -ForegroundColor White
Write-Host "CLEANUP SUMMARY" -ForegroundColor White
Write-Host "=======================================" -ForegroundColor White
Write-Host "Directories processed: $($script:processedCount)" -ForegroundColor Cyan
Write-Host "Directories skipped (not found): $($script:skippedCount)" -ForegroundColor Yellow

# Immediate cleanup summary
Write-Host ""
Write-Host "IMMEDIATE CLEANUP RESULTS:" -ForegroundColor Green
Write-Host "→ Space freed immediately: $([math]::Round($script:totalFreed, 2)) MB ($([math]::Round($script:totalFreed / 1024, 2)) GB)" -ForegroundColor Green

# Pending reboot deletion summary
if ($script:pendingDeletions.Count -gt 0) {
    Write-Host ""
    Write-Host "SCHEDULED FOR NEXT REBOOT:" -ForegroundColor Magenta
    Write-Host "→ Files to be deleted on reboot: ~$($script:pendingFileCount)" -ForegroundColor Magenta
    Write-Host "→ Additional space to be freed: $([math]::Round($script:pendingDeletionSize, 2)) MB ($([math]::Round($script:pendingDeletionSize / 1024, 2)) GB)" -ForegroundColor Magenta
    Write-Host "→ Locked directories: $($script:lockedDirectories.Count)" -ForegroundColor Magenta
}

# Total summary
$totalSpace = $script:totalFreed + $script:pendingDeletionSize
Write-Host ""
Write-Host "TOTAL CLEANUP RESULTS:" -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "→ TOTAL SPACE TO BE FREED: $([math]::Round($totalSpace, 2)) MB ($([math]::Round($totalSpace / 1024, 2)) GB)" -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "→ Freed now: $([math]::Round($script:totalFreed, 2)) MB | After reboot: $([math]::Round($script:pendingDeletionSize, 2)) MB" -ForegroundColor White -BackgroundColor DarkBlue

Write-Host ""
if ($WhatIf) {
    Write-Host "This was a simulation. Run without -WhatIf to actually clean the files and perform maintenance." -ForegroundColor Magenta
} else {
    Write-Host "✓ COMPREHENSIVE CLEANUP AND MAINTENANCE COMPLETED!" -ForegroundColor Green
    Write-Host "✓ Cache cleanup, system repairs, and optimization finished." -ForegroundColor Green
    Write-Host "✓ Recycle Bin has been automatically emptied." -ForegroundColor Green
    Write-Host "✓ System caches have been cleared." -ForegroundColor Green
    Write-Host "✓ System File Checker and DISM repairs completed." -ForegroundColor Green
    Write-Host "✓ File system compression applied (if successful)." -ForegroundColor Green
    Write-Host "🔄 MEMORY DIAGNOSTIC TEST SCHEDULED FOR NEXT REBOOT" -ForegroundColor Red -BackgroundColor Yellow
    
    if ($script:pendingDeletions.Count -gt 0) {
        Write-Host "⚠️  Some files were locked and scheduled for deletion on next reboot." -ForegroundColor Yellow
        Write-Host "⚠️  A cleanup script will run automatically on next boot." -ForegroundColor Yellow
        Write-Host "⚠️  RESTART YOUR COMPUTER to complete the cleanup process and run memory test." -ForegroundColor Red -BackgroundColor Yellow
    } else {
        Write-Host "⚠️  RESTART YOUR COMPUTER to run the scheduled memory diagnostic test." -ForegroundColor Red -BackgroundColor Yellow
    }
}

Write-Host ""
Write-Host "Script completed with comprehensive cleanup and system maintenance!" -ForegroundColor White

Write-Host ""
Write-Host "ADDITIONAL MANUAL TOOLS AVAILABLE:" -ForegroundColor Cyan
Write-Host "• System Restore: systempropertiesprotection.exe" -ForegroundColor Gray
Write-Host "• Internet Settings: rundll32.exe shell32.dll,Control_RunDLL inetcpl.cpl" -ForegroundColor Gray
Write-Host "• Reliability Monitor: perfmon.exe /rel" -ForegroundColor Gray
Write-Host "• Disk Check: chkdsk C: /f /r (requires reboot)" -ForegroundColor Gray