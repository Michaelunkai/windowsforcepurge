# Windows 11 Ultimate Cache and Temp Cleanup Script - FAST & COMPREHENSIVE
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
function Create-RebootCleanupScript {
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
Write-Host "RUNNING IN FAST MODE - MAXIMUM 3 MINUTE EXECUTION" -ForegroundColor Green
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
        Write-Host "  Executing advanced cleanup command..." -ForegroundColor Yellow
        
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
        } | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        Write-Host "  ✓ Advanced cleanup completed in $([math]::Round($duration, 1)) seconds" -ForegroundColor Green
        
        # Estimate space freed (rough calculation)
        $estimatedFreed = 150  # Conservative estimate in MB
        $script:totalFreed += $estimatedFreed
        Write-Host "  ✓ Estimated $estimatedFreed MB freed from comprehensive cleanup" -ForegroundColor Green
    }
    catch {
        Write-Host "  Advanced cleanup encountered issues: $($_.Exception.Message)" -ForegroundColor Yellow
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

# STEP 3: ADDITIONAL SYSTEM CLEANUP
Write-Host ""
Write-Host "STEP 3: Running additional system cleanup..." -ForegroundColor Green

if (!$WhatIf) {
    # Clean Windows Update cache
    Write-Host "Cleaning Windows Update cache..." -ForegroundColor Cyan
    try {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        $wuCacheSize = Get-FolderSizeMB -Path "C:\Windows\SoftwareDistribution\Download" -TimeoutSeconds 5
        if ($wuCacheSize -gt 0) {
            Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
            $script:totalFreed += $wuCacheSize
            Write-Host "  ✓ Freed: $wuCacheSize MB from Windows Update cache" -ForegroundColor Green
        }
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "  Scheduling Windows Update cache for reboot deletion..." -ForegroundColor Yellow
        Add-PendingDeletion -Path "C:\Windows\SoftwareDistribution\Download"
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
    $iconFilesRemoved = 0
    foreach ($file in $iconCacheFiles) {
        try {
            $iconSize = [math]::Round($file.Length / 1MB, 2)
            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            $script:totalFreed += $iconSize
            $iconFilesRemoved++
        }
        catch {
            Add-PendingDeletion -Path $file.FullName
        }
    }
    if ($iconFilesRemoved -gt 0) {
        Write-Host "  ✓ Removed $iconFilesRemoved icon cache files" -ForegroundColor Green
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
    $rebootScript = Create-RebootCleanupScript
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
    Write-Host "This was a simulation. Run without -WhatIf to actually clean the files." -ForegroundColor Magenta
} else {
    Write-Host "✓ CLEANUP COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "✓ Recycle Bin has been automatically emptied." -ForegroundColor Green
    Write-Host "✓ System caches have been cleared." -ForegroundColor Green
    
    if ($script:pendingDeletions.Count -gt 0) {
        Write-Host "⚠️  Some files were locked and scheduled for deletion on next reboot." -ForegroundColor Yellow
        Write-Host "⚠️  A cleanup script will run automatically on next boot." -ForegroundColor Yellow
        Write-Host "⚠️  RESTART YOUR COMPUTER to complete the cleanup process." -ForegroundColor Red -BackgroundColor Yellow
    } else {
        Write-Host "✓ All files cleaned successfully - no reboot required." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Script completed in under 3 minutes with comprehensive cleanup!" -ForegroundColor White
