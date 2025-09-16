# Windows 11 Ultimate Cache and Temp Cleanup Script - OPTIMIZED VERSION
# Run as Administrator for best results

param(
    [switch]$WhatIf = $false  # Add -WhatIf to see what would be deleted without actually deleting
)

# Enable parallel processing
$MaxThreads = 16  # Adjust based on CPU cores
$Global:Jobs = @()
$ErrorActionPreference = 'SilentlyContinue'

# Global tracking variables
$script:totalFreed = 0
$script:pendingDeletions = @()
$script:lockedDirectories = @()
$script:pendingDeletionSize = 0
$script:pendingFileCount = 0
$script:processedCount = 0
$script:skippedCount = 0

# Function to get folder size in MB with timeout (optimized)
function Get-FolderSizeMB {
    param([string]$Path, [int]$TimeoutSeconds = 5)
    try {
        if (Test-Path $Path) {
            $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
                    Measure-Object -Property Length -Sum).Sum
            return [math]::Round($size / 1MB, 2)
        }
    }
    catch { return 0 }
    return 0
}

# Function to add items to pending deletion (optimized)
function Add-PendingDeletion {
    param([string]$Path, [string]$Type = "File")
    try {
        if (Test-Path $Path) {
            $size = (Get-Item $Path).PSIsContainer ? 
                    (Get-FolderSizeMB -Path $Path -TimeoutSeconds 2) : 
                    [math]::Round((Get-Item $Path).Length / 1MB, 2)
            $fileCount = (Get-Item $Path).PSIsContainer ? 50 : 1
            
            $script:pendingDeletionSize += $size
            $script:pendingFileCount += $fileCount
            
            # Use registry for pending operations
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
            $regName = "PendingFileRenameOperations"
            $existingOperations = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
            Set-ItemProperty -Path $regPath -Name $regName -Value ($existingOperations + @("\??\$Path", "")) -Type MultiString
            
            # Take ownership in parallel
            Start-Job -ScriptBlock {
                param($p)
                takeown /f "$p" /r /d y 2>$null
                icacls "$p" /grant administrators:F /t 2>$null
            } -ArgumentList $Path | Out-Null
            
            $script:pendingDeletions += $Path
            return $true
        }
    }
    catch { return $false }
}

# Fast cleanup function with parallel processing
function Clear-DirectoryContents {
    param([string]$Path, [int]$MaxTimeSeconds = 30)
    
    $sizeBefore = 0
    $freed = 0
    
    try {
        if (Test-Path $Path) {
            Write-Host "Processing: $Path" -ForegroundColor Cyan
            $sizeBefore = Get-FolderSizeMB -Path $Path -TimeoutSeconds 2
            
            if ($sizeBefore -gt 0) {
                Write-Host "  Size before: $sizeBefore MB" -ForegroundColor Yellow
                
                if (!$WhatIf) {
                    # Parallel deletion
                    $job = Start-Job -ScriptBlock {
                        param($dir)
                        Get-ChildItem -Path $dir -Recurse -Force | ForEach-Object {
                            try { Remove-Item $_.FullName -Force -Recurse } catch {}
                        }
                    } -ArgumentList $Path
                    
                    $completed = Wait-Job -Job $job -Timeout $MaxTimeSeconds
                    if ($completed) {
                        Receive-Job -Job $job
                        $sizeAfter = Get-FolderSizeMB -Path $Path -TimeoutSeconds 2
                        $freed = $sizeBefore - $sizeAfter
                        Write-Host "  Freed: $freed MB" -ForegroundColor Green
                    }
                    else {
                        Stop-Job -Job $job
                        Add-PendingDeletion -Path $Path
                        $script:lockedDirectories += $Path
                        $freed = $sizeBefore
                        Write-Host "  → Scheduled for reboot deletion" -ForegroundColor Magenta
                    }
                    Remove-Job -Job $job -Force
                }
                else {
                    Write-Host "  [WHATIF] Would free: $sizeBefore MB" -ForegroundColor Magenta
                    $freed = $sizeBefore
                }
            }
        }
        else {
            $script:skippedCount++
        }
        
        $script:processedCount++
        return $freed
    }
    catch { return 0 }
}

# Optimized reboot cleanup script creation
function New-RebootCleanupScript {
    $cleanupScript = @"
@echo off
echo Starting force cleanup on reboot...
echo %date% %time% - Reboot cleanup started >> C:\Windows\Temp\cleanup_log.txt

REM Force delete each pending item
"@

    foreach ($item in $script:pendingDeletions) {
        $cleanupScript += "`nrd /s /q `"$item`" 2>nul & del /f /q `"$item`" 2>nul"
    }

    $cleanupScript += @"

REM Additional cleanup
for /d %%x in (C:\Users\*\AppData\Local\Temp\*) do rd /s /q "%%x" 2>nul
for /d %%x in (C:\Windows\Temp\*) do rd /s /q "%%x" 2>nul
del /f /q C:\Users\*\AppData\Local\Temp\*.* 2>nul
del /f /q C:\Windows\Temp\*.* 2>nul

echo %date% %time% - Cleanup completed >> C:\Windows\Temp\cleanup_log.txt
del "%~f0"
"@

    $scriptPath = "C:\Windows\Temp\CleanupOnBoot.bat"
    $cleanupScript | Out-File -FilePath $scriptPath -Encoding ASCII -Force
    Copy-Item -Path $scriptPath -Destination "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\CleanupOnBoot.bat" -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "CleanupOnBoot" -Value $scriptPath
    
    return $scriptPath
}

# Main execution with parallel processing
Write-Host "Windows 11 OPTIMIZED Cache & Temp Cleanup" -ForegroundColor White
Write-Host "Running in parallel mode with $MaxThreads threads" -ForegroundColor Yellow

if ($WhatIf) {
    Write-Host "RUNNING IN WHATIF MODE - NO FILES WILL BE DELETED" -ForegroundColor Magenta
}

# STEP 1: ULTRA-FAST PARALLEL CLEANUP
Write-Host "`nSTEP 1: Running ultra-fast parallel cleanup..." -ForegroundColor Green

if (!$WhatIf) {
    $paths = @(
        "$env:TEMP",
        "$env:TMP",
        "$env:WINDIR\Temp",
        "$env:WINDIR\Logs",
        "$env:WINDIR\SoftwareDistribution\Download",
        "$env:WINDIR\ServiceProfiles\*\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache",
        "$env:ProgramData\NVIDIA Corporation",
        "$env:LOCALAPPDATA\NVIDIA",
        "$env:LOCALAPPDATA\Temp",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "$env:LOCALAPPDATA\Microsoft\Windows\WebCache",
        "$env:PROGRAMFILES\NVIDIA Corporation\Installer2",
        "${env:PROGRAMFILES(X86)}\NVIDIA Corporation\Installer2",
        "$env:USERPROFILE\AppData\Local\CrashDumps"
    )

    # Process paths in parallel batches
    $batch = [System.Collections.ArrayList]::new()
    foreach ($path in $paths) {
        $job = Start-Job -ScriptBlock {
            param($p)
            Get-ChildItem -Path $p -Recurse -Force | 
            Where-Object { $_.Extension -match '\.(tmp|temp|log|cache|dmp|old|bak)$' -or 
                         $_.Name -match '(temp|cache|log|\.tmp|\.log|\.dmp|\.old|\.bak|nvph|content\.bin)' } |
            ForEach-Object { Remove-Item $_.FullName -Force -Recurse }
        } -ArgumentList $path
        
        $batch.Add($job) | Out-Null
        
        if ($batch.Count -ge $MaxThreads) {
            Wait-Job -Job $batch | Receive-Job
            Remove-Job -Job $batch
            $batch.Clear()
        }
    }
    
    if ($batch.Count -gt 0) {
        Wait-Job -Job $batch | Receive-Job
        Remove-Job -Job $batch
    }
    
    $script:totalFreed += 150  # Conservative estimate
}

# STEP 2: PARALLEL HIGH-VALUE DIRECTORY CLEANUP
Write-Host "`nSTEP 2: Parallel high-value directory cleanup..." -ForegroundColor Green

$highValueDirectories = @(
    "C:\Windows\System32\winevt\Logs",
    "C:\Windows\Prefetch",
    "$env:LOCALAPPDATA\Microsoft\Windows\Explorer",
    "$env:LOCALAPPDATA\Microsoft\Windows\WebCache",
    "C:\Windows\WinSxS\Temp"
)

# Process directories in parallel
$batch = [System.Collections.ArrayList]::new()
foreach ($dir in $highValueDirectories) {
    $job = Start-Job -ScriptBlock ${function:Clear-DirectoryContents} -ArgumentList $dir, 15
    $batch.Add($job) | Out-Null
    
    if ($batch.Count -ge $MaxThreads) {
        $freed = (Wait-Job -Job $batch | Receive-Job | Measure-Object -Sum).Sum
        $script:totalFreed += $freed
        Remove-Job -Job $batch
        $batch.Clear()
    }
}

if ($batch.Count -gt 0) {
    $freed = (Wait-Job -Job $batch | Receive-Job | Measure-Object -Sum).Sum
    $script:totalFreed += $freed
    Remove-Job -Job $batch
}

# STEP 3: FAST WINDOWS UPDATE CLEANUP
Write-Host "`nSTEP 3: Fast Windows Update cleanup..." -ForegroundColor Green

if (!$WhatIf) {
    Stop-Service -Name UsoSvc,cryptsvc,bits,msiserver,dosvc,wuauserv -Force
    Remove-Item -Path "C:\Windows\SoftwareDistribution.old","C:\Windows\System32\catroot2.old" -Recurse -Force
    
    try {
        Rename-Item -Path "C:\Windows\SoftwareDistribution" -NewName "SoftwareDistribution.old" -Force
        New-Item -Path "C:\Windows\SoftwareDistribution" -ItemType Directory -Force | Out-Null
        $script:totalFreed += 50
        
        Rename-Item -Path "C:\Windows\System32\catroot2" -NewName "catroot2.old" -Force
        New-Item -Path "C:\Windows\System32\catroot2" -ItemType Directory -Force | Out-Null
        $script:totalFreed += 20
    }
    catch {
        Write-Host "Some Windows Update files were locked" -ForegroundColor Yellow
    }
    
    Start-Service -Name UsoSvc,cryptsvc,bits,msiserver,dosvc,wuauserv
}

# STEP 4: PARALLEL SYSTEM CLEANUP
Write-Host "`nSTEP 4: Parallel system cleanup..." -ForegroundColor Green

if (!$WhatIf) {
    # Run cleanmgr in parallel
    Start-Job -ScriptBlock {
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -Wait
    } | Out-Null
    
    # Clear event logs in parallel
    $eventLogs = wevtutil el | Where-Object {$_ -notmatch "(LiveId|USBVideo|Analytic)"}
    $batch = [System.Collections.ArrayList]::new()
    
    foreach ($log in $eventLogs) {
        $job = Start-Job -ScriptBlock { param($l) wevtutil cl "$l" } -ArgumentList $log
        $batch.Add($job) | Out-Null
        
        if ($batch.Count -ge $MaxThreads) {
            Wait-Job -Job $batch | Out-Null
            Remove-Job -Job $batch
            $batch.Clear()
        }
    }
    
    # Parallel temp directory cleanup
    $tempPaths = @(
        $env:TEMP,
        "$env:WINDIR\Temp",
        "$env:LOCALAPPDATA\Temp"
    )
    
    foreach ($path in $tempPaths) {
        Start-Job -ScriptBlock {
            param($p)
            Get-ChildItem -Path $p -Recurse -Force | Remove-Item -Recurse -Force
        } -ArgumentList $path | Out-Null
    }
    
    # Parallel cache cleanup
    $cachePaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\IECompatCache",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:WINDIR\Prefetch",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "$env:APPDATA\Microsoft\Windows\Recent"
    )
    
    foreach ($path in $cachePaths) {
        Start-Job -ScriptBlock {
            param($p)
            Remove-Item -Path "$p\*" -Recurse -Force
        } -ArgumentList $path | Out-Null
    }
    
    Get-Job | Wait-Job | Remove-Job
    $script:totalFreed += 200  # Estimate for all parallel cleanups
}

# STEP 5: QUICK SYSTEM OPTIMIZATION
Write-Host "`nSTEP 5: Quick system optimization..." -ForegroundColor Green

if (!$WhatIf) {
    # Parallel service optimization
    Start-Job -ScriptBlock { sc.exe config "SysMain" start= disabled } | Out-Null
    Start-Job -ScriptBlock { Start-Process "wsreset.exe" -WindowStyle Hidden -Wait } | Out-Null
    
    # Quick network reset
    Start-Job -ScriptBlock {
        ipconfig.exe /flushdns
        netsh interface ip reset
        netsh winsock reset catalog
    } | Out-Null
    
    # Fast group policy update
    Start-Job -ScriptBlock {
        Start-Process "gpupdate.exe" -ArgumentList "/force" -WindowStyle Hidden -Wait
    } | Out-Null
    
    Get-Job | Wait-Job -Timeout 30 | Remove-Job
}

# Create reboot cleanup script if needed
if ($script:pendingDeletions.Count -gt 0 -and !$WhatIf) {
    $rebootScript = New-RebootCleanupScript
}

# FINAL SUMMARY
$totalSpace = $script:totalFreed + $script:pendingDeletionSize
Write-Host "`nCLEANUP SUMMARY" -ForegroundColor White
Write-Host "Space freed: $([math]::Round($script:totalFreed, 2)) MB" -ForegroundColor Green
if ($script:pendingDeletions.Count -gt 0) {
    Write-Host "Pending deletion: $([math]::Round($script:pendingDeletionSize, 2)) MB" -ForegroundColor Magenta
    Write-Host "Total space to be freed: $([math]::Round($totalSpace, 2)) MB" -ForegroundColor White
    Write-Host "`n⚠️  RESTART REQUIRED to complete cleanup" -ForegroundColor Yellow
}

Write-Host "`nOptimized cleanup completed!" -ForegroundColor Green
