# Windows 11 Cache and Temp Cleanup Script - FULLY AUTOMATIC WITH FORCE REBOOT DELETION
# Run as Administrator for best results

param(
    [switch]$WhatIf = $false  # Add -WhatIf to see what would be deleted without actually deleting
)

# Global arrays to track files scheduled for reboot deletion
$script:pendingDeletions = @()
$script:lockedDirectories = @()

# Function to add file/folder to pending deletion on reboot
function Add-PendingDeletion {
    param(
        [string]$Path,
        [string]$Type = "File"
    )
    
    try {
        # Method 1: Use PendingFileRenameOperations registry key (official Windows method)
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
        
        # Update registry
        Set-ItemProperty -Path $regPath -Name $regName -Value $newOperations -Type MultiString
        
        # Method 2: Use takeown and icacls for stubborn files
        if (Test-Path $Path) {
            takeown /f "$Path" /r /d y 2>$null | Out-Null
            icacls "$Path" /grant administrators:F /t 2>$null | Out-Null
        }
        
        # Method 3: Create backup deletion script
        $script:pendingDeletions += $Path
        
        Write-Host "  → Scheduled for deletion on next reboot: $Path" -ForegroundColor Magenta
        return $true
    }
    catch {
        Write-Host "  → Failed to schedule deletion: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to create reboot cleanup script
function Create-RebootCleanupScript {
    $cleanupScript = @"
@echo off
echo Starting force cleanup on reboot...
echo %date% %time% - Reboot cleanup started >> C:\Windows\Temp\cleanup_log.txt

REM Kill only safe application processes that might lock cache files
taskkill /f /im chrome.exe 2>nul
taskkill /f /im msedge.exe 2>nul
taskkill /f /im firefox.exe 2>nul

REM Force delete each pending item
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

# Function to get folder size in MB
function Get-FolderSizeMB {
    param([string]$Path)
    try {
        if (Test-Path $Path) {
            $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            return [math]::Round($size / 1MB, 2)
        }
    }
    catch {
        return 0
    }
    return 0
}

# Enhanced function to safely clean directory contents with force deletion support
function Clear-DirectoryContents {
    param(
        [string]$Path,
        [string]$Description = ""
    )
    
    $sizeBefore = 0
    $sizeAfter = 0
    $deletionSuccess = $false
    
    try {
        if (Test-Path $Path) {
            Write-Host "Processing: $Path" -ForegroundColor Cyan
            
            # Get size before cleanup
            $sizeBefore = Get-FolderSizeMB -Path $Path
            
            if ($sizeBefore -gt 0) {
                Write-Host "  Size before: $sizeBefore MB" -ForegroundColor Yellow
                
                if (!$WhatIf) {
                    # Method 1: Try normal deletion first
                    try {
                        Get-ChildItem -Path $Path -Recurse -Force -ErrorAction Stop | 
                            Remove-Item -Force -Recurse -ErrorAction Stop
                        $deletionSuccess = $true
                    }
                    catch {
                        Write-Host "  Normal deletion failed: $($_.Exception.Message)" -ForegroundColor Yellow
                        
                        # Method 2: Try with takeown and icacls
                        try {
                            takeown /f "$Path" /r /d y 2>$null | Out-Null
                            icacls "$Path" /grant administrators:F /t 2>$null | Out-Null
                            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction Stop | 
                                Remove-Item -Force -Recurse -ErrorAction Stop
                            $deletionSuccess = $true
                        }
                        catch {
                            # Method 3: Schedule for deletion on reboot
                            Write-Host "  Advanced deletion failed, scheduling for reboot deletion..." -ForegroundColor Yellow
                            
                            # Add each file and subdirectory to pending deletion
                            try {
                                Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                                    ForEach-Object { Add-PendingDeletion -Path $_.FullName }
                                Add-PendingDeletion -Path $Path
                                $script:lockedDirectories += $Path
                            }
                            catch {
                                Write-Host "  Failed to schedule for reboot deletion: $($_.Exception.Message)" -ForegroundColor Red
                            }
                        }
                    }
                    
                    # Get size after cleanup attempt
                    $sizeAfter = Get-FolderSizeMB -Path $Path
                    $freed = $sizeBefore - $sizeAfter
                    
                    if ($freed -gt 0) {
                        Write-Host "  Freed: $freed MB" -ForegroundColor Green
                    }
                    
                    if (!$deletionSuccess -and $sizeAfter -gt 0) {
                        Write-Host "  Remaining: $sizeAfter MB (scheduled for reboot deletion)" -ForegroundColor Magenta
                        $freed = $sizeBefore  # Count full size as it will be freed on reboot
                    }
                } else {
                    Write-Host "  [WHATIF] Would free: $sizeBefore MB" -ForegroundColor Magenta
                    $freed = $sizeBefore
                }
                
                return $freed
            } else {
                Write-Host "  Already empty" -ForegroundColor Gray
                return 0
            }
        } else {
            Write-Host "  Path not found: $Path" -ForegroundColor DarkGray
            return 0
        }
    }
    catch {
        Write-Host "  Error processing $Path : $($_.Exception.Message)" -ForegroundColor Red
        # Try to schedule for reboot deletion as last resort
        if (!$WhatIf) {
            Add-PendingDeletion -Path $Path
        }
        return 0
    }
}

# Function to safely stop only application processes that might lock cache files
function Stop-LockingProcesses {
    Write-Host "Stopping application processes that might lock cache files..." -ForegroundColor Cyan
    
    # ONLY target safe application processes - NO SYSTEM PROCESSES!
    $processesToStop = @(
        "chrome", "msedge", "firefox", "opera", "brave",
        "nvcontainer", "nvdisplay", 
        "cursor", "code", "notepad++",
        "discord", "spotify", "steam"
    )
    
    foreach ($process in $processesToStop) {
        try {
            $processes = Get-Process -Name $process -ErrorAction SilentlyContinue
            if ($processes) {
                Write-Host "  Stopping $process..." -ForegroundColor Yellow
                $processes | Stop-Process -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            # Ignore errors - process might not be running
        }
    }
    
    Start-Sleep -Seconds 1
}

# Function to find all user temp directories
function Get-AllUserTempDirectories {
    $tempDirs = @()
    
    # Get all user profiles
    $userProfiles = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.Special -eq $false }
    
    foreach ($profile in $userProfiles) {
        $userPath = $profile.LocalPath
        if (Test-Path $userPath) {
            $username = Split-Path $userPath -Leaf
            
            # Add common temp/cache locations for each user
            $userTempPaths = @(
                "$userPath\AppData\Local\Temp",
                "$userPath\AppData\Local\Microsoft\Windows\INetCache",
                "$userPath\AppData\Local\Microsoft\Windows\WebCache",
                "$userPath\AppData\Local\Microsoft\Windows\Caches",
                "$userPath\AppData\Local\Microsoft\Windows\Explorer",
                "$userPath\AppData\Local\CrashDumps",
                "$userPath\AppData\Roaming\Microsoft\Windows\Recent",
                "$userPath\AppData\Local\Microsoft\Windows\WER",
                "$userPath\AppData\Local\Microsoft\Terminal Server Client\Cache",
                "$userPath\AppData\Local\Microsoft\CLR_v4.0_30319\UsageLogs",
                "$userPath\AppData\Local\Microsoft\CLR_v4.0\UsageLogs",
                "$userPath\AppData\Local\Microsoft\Internet Explorer\Recovery",
                "$userPath\AppData\Local\Microsoft\Windows\Burn",
                "$userPath\AppData\Local\Microsoft\Windows\Temporary Internet Files",
                "$userPath\AppData\Local\AMD\RadeonSoftware\cache",
                "$userPath\AppData\Local\NVIDIA Corporation\NVIDIA App\CefCache",
                "$userPath\AppData\Local\NVIDIA Corporation\NVIDIA Overlay\CefCache",
                "$userPath\AppData\Roaming\Cursor\Cache",
                "$userPath\AppData\Roaming\Cursor\logs",
                "$userPath\AppData\Roaming\Docker Desktop\Cache",
                "$userPath\AppData\Roaming\Todoist\Cache",
                "$userPath\AppData\Roaming\Todoist\logs",
                "$userPath\AppData\Roaming\Wise Utilities\EBWebView\Default\Cache",
                "$userPath\AppData\Local\Google\Chrome\User Data\Default\Cache",
                "$userPath\AppData\Local\Google\Chrome\User Data\Default\Code Cache",
                "$userPath\AppData\Local\Google\Chrome\User Data\Default\GPUCache",
                "$userPath\AppData\Local\Google\Chrome\User Data\Default\Service Worker\CacheStorage",
                "$userPath\AppData\Local\Google\Chrome\User Data\Default\Shared Dictionary\cache",
                "$userPath\AppData\Local\Microsoft\Edge\User Data\Default\Cache",
                "$userPath\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache",
                "$userPath\AppData\Local\Microsoft\Edge\User Data\Default\GPUCache",
                "$userPath\AppData\Local\Mozilla\Firefox\Profiles\*\cache2",
                "$userPath\AppData\Local\Mozilla\Firefox\Profiles\*\startupCache",
                "$userPath\AppData\Local\Opera Software\Opera Stable\Cache",
                "$userPath\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\Cache"
            )
            
            $tempDirs += $userTempPaths
        }
    }
    
    return $tempDirs
}

# Initialize counters
$totalFreed = 0
$processedCount = 0
$skippedCount = 0

Write-Host "=======================================" -ForegroundColor White
Write-Host "Windows 11 FORCE Cache and Temp Cleanup" -ForegroundColor White
Write-Host "=======================================" -ForegroundColor White
Write-Host "RUNNING IN FULLY AUTOMATIC MODE WITH FORCE REBOOT DELETION" -ForegroundColor Green

if ($WhatIf) {
    Write-Host "RUNNING IN WHATIF MODE - NO FILES WILL BE DELETED" -ForegroundColor Magenta
    Write-Host ""
}

# Stop processes that might lock files
if (!$WhatIf) {
    Stop-LockingProcesses
}

# Define core system directories to clean
$systemDirectoriesToClean = @(
    # System Cache and Logs
    "C:\Windows\System32\winevt\Logs",
    "C:\Windows\Logs",
    "C:\Windows\Prefetch",
    "C:\Windows\Temp",
    "C:\Windows\assembly\temp",
    "C:\Windows\assembly\tmp",
    "C:\Windows\assembly\NativeImages_v2.0.50727_32\Temp",
    "C:\Windows\assembly\NativeImages_v2.0.50727_64\Temp",
    "C:\Windows\assembly\NativeImages_v4.0.30319_32\Temp",
    "C:\Windows\assembly\NativeImages_v4.0.30319_64\Temp",
    "C:\Windows\WinSxS\Temp",
    "C:\Windows\System32\DriverStore\Temp",
    "C:\Windows\System32\spp\store\2.0\cache",
    "C:\Windows\System32\config\systemprofile\AppData\Local\Microsoft\Windows\Caches",
    "C:\Windows\ServiceProfiles\LocalService\AppData\Local\Temp",
    "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp",
    "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Logs",
    "C:\Windows\SoftwareDistribution\DataStore\Logs",
    "C:\Windows\SoftwareDistribution\Download\SharedFileCache",
    
    # Cortana Cache
    "C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\Cortana.UI\cache",
    "C:\Windows\WinSxS\amd64_userexperience-desktop_31bf3856ad364e35_10.0.26100.4768_none_c7fcad031a649b96\CBS\Cortana.UI\cache",
    "C:\Windows\WinSxS\amd64_userexperience-desktop_31bf3856ad364e35_10.0.26100.1591_none_c815e77f1a5104dd\CBS\Cortana.UI\cache",
    "C:\Windows\WinSxS\amd64_userexperience-lkg_31bf3856ad364e35_10.0.26100.1742_none_3c72368675eae921\LKG.Search\Cortana.UI\cache",
    "C:\Windows\WinSxS\amd64_userexperience-desktop_31bf3856ad364e35_10.0.26100.1591_none_c815e77f1a5104dd\r\CBS\Cortana.UI\cache",
    "C:\Windows\WinSxS\amd64_userexperience-desktop_31bf3856ad364e35_10.0.26100.4768_none_c7fcad031a649b96\r\CBS\Cortana.UI\cache",
    
    # ProgramData Cache and Logs
    "C:\ProgramData\ASUS\ASUS System Control Interface\log",
    "C:\ProgramData\Microsoft\EdgeUpdate\Log",
    "C:\ProgramData\Microsoft\Windows Security Health\Logs",
    "C:\ProgramData\Microsoft\Windows\LfSvc\Cache",
    "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
    "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
    "C:\ProgramData\Microsoft\Windows\WER\Temp",
    "C:\ProgramData\NVIDIA Corporation\NVIDIA App\Installer\Logs",
    "C:\ProgramData\NVIDIA Corporation\NVIDIA App\Logs",
    "C:\ProgramData\USOShared\Logs",
    "C:\ProgramData\Microsoft\Diagnosis\Temp",
    "C:\ProgramData\Microsoft\Search\Data\Temp",
    "C:\ProgramData\ProcessLasso\temp",
    "C:\ProgramData\Macrium\Reflect\Temp",
    
    # Container Temp Directories
    "C:\ProgramData\Microsoft\Windows\Containers\Layers\*\Files\Windows\Temp",
    "C:\ProgramData\Microsoft\Windows\Containers\Layers\*\Files\Windows\WinSxS\Temp",
    "C:\ProgramData\Microsoft\Windows\Containers\Layers\*\Files\ProgramData\Microsoft\Windows\WER\Temp",
    "C:\ProgramData\Microsoft\Windows\Containers\Layers\*\Files\Users\*\AppData\Local\Temp",
    
    # Additional System Temp
    "C:\KVRT2020_Data\Temp",
    "C:\Program Files\Git\tmp",
    "C:\Program Files (x86)\Microsoft\Temp"
)

# Get all user temp directories dynamically
Write-Host "Scanning for user temp directories..." -ForegroundColor Green
$userTempDirectories = Get-AllUserTempDirectories

# Combine all directories
$allDirectories = $systemDirectoriesToClean + $userTempDirectories | Sort-Object | Get-Unique

Write-Host "Starting cleanup of $($allDirectories.Count) directories..." -ForegroundColor Green
Write-Host ""

# Process each directory
foreach ($directory in $allDirectories) {
    # Handle wildcard paths
    if ($directory -like "*\*\*") {
        $expandedPaths = Get-ChildItem -Path (Split-Path $directory -Parent) -Directory -ErrorAction SilentlyContinue | 
                        ForEach-Object { Join-Path $_.FullName (Split-Path $directory -Leaf) }
        
        foreach ($expandedPath in $expandedPaths) {
            if (Test-Path $expandedPath) {
                $freed = Clear-DirectoryContents -Path $expandedPath
                $totalFreed += $freed
                $processedCount++
            }
        }
    } else {
        $freed = Clear-DirectoryContents -Path $directory
        $totalFreed += $freed
        $processedCount++
        
        if ($freed -eq 0 -and !(Test-Path $directory)) {
            $skippedCount++
        }
    }
    
    Start-Sleep -Milliseconds 50  # Small delay to prevent overwhelming the system
}

# Run Windows built-in cleanup automatically
Write-Host ""
Write-Host "Running additional Windows cleanup tools..." -ForegroundColor Green

if (!$WhatIf) {
    try {
        # Clean Windows Update cache
        Write-Host "Cleaning Windows Update cache..." -ForegroundColor Cyan
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        $wuCacheSize = Get-FolderSizeMB -Path "C:\Windows\SoftwareDistribution\Download"
        if ($wuCacheSize -gt 0) {
            try {
                Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction Stop
                $totalFreed += $wuCacheSize
                Write-Host "  Freed: $wuCacheSize MB from Windows Update cache" -ForegroundColor Green
            }
            catch {
                Add-PendingDeletion -Path "C:\Windows\SoftwareDistribution\Download"
                Write-Host "  Scheduled Windows Update cache for reboot deletion" -ForegroundColor Magenta
            }
        }
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        
        # Clean additional system caches
        Write-Host "Cleaning system font cache..." -ForegroundColor Cyan
        Stop-Service -Name FontCache -Force -ErrorAction SilentlyContinue
        try {
            Remove-Item -Path "C:\Windows\System32\FNTCACHE.DAT" -Force -ErrorAction Stop
            Remove-Item -Path "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache\*" -Recurse -Force -ErrorAction Stop
        }
        catch {
            Add-PendingDeletion -Path "C:\Windows\System32\FNTCACHE.DAT"
            Add-PendingDeletion -Path "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache"
        }
        Start-Service -Name FontCache -ErrorAction SilentlyContinue
        
        # Clean DNS cache
        Write-Host "Flushing DNS cache..." -ForegroundColor Cyan
        ipconfig /flushdns | Out-Null
        
        # Clean icon cache for all users
        Write-Host "Cleaning icon cache..." -ForegroundColor Cyan
        $iconCacheFiles = Get-ChildItem -Path "C:\Users\*\AppData\Local\IconCache.db" -Force -ErrorAction SilentlyContinue
        foreach ($file in $iconCacheFiles) {
            $iconSize = [math]::Round($file.Length / 1MB, 2)
            try {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                $totalFreed += $iconSize
            }
            catch {
                Add-PendingDeletion -Path $file.FullName
            }
        }
        
        # Empty Recycle Bin automatically
        Write-Host "Emptying Recycle Bin..." -ForegroundColor Cyan
        try {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue -Confirm:$false
            Write-Host "  Recycle Bin emptied" -ForegroundColor Green
        }
        catch {
            Write-Host "  Could not empty Recycle Bin: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
    }
    catch {
        Write-Host "  Some system cleanup operations failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Create reboot cleanup script if there are pending deletions
if ($script:pendingDeletions.Count -gt 0 -and !$WhatIf) {
    Write-Host ""
    Write-Host "Creating reboot cleanup script for locked files..." -ForegroundColor Magenta
    $rebootScript = Create-RebootCleanupScript
    Write-Host "Reboot cleanup script created: $rebootScript" -ForegroundColor Green
}

# Final summary
Write-Host ""
Write-Host "=======================================" -ForegroundColor White
Write-Host "CLEANUP SUMMARY" -ForegroundColor White
Write-Host "=======================================" -ForegroundColor White
Write-Host "Directories processed: $processedCount" -ForegroundColor Cyan
Write-Host "Directories skipped (not found): $skippedCount" -ForegroundColor Yellow

if ($script:pendingDeletions.Count -gt 0) {
    Write-Host "Files scheduled for reboot deletion: $($script:pendingDeletions.Count)" -ForegroundColor Magenta
    Write-Host "Locked directories: $($script:lockedDirectories.Count)" -ForegroundColor Magenta
}

Write-Host ""
Write-Host "TOTAL SPACE FREED: $([math]::Round($totalFreed, 2)) MB" -ForegroundColor Green -BackgroundColor Black
Write-Host "TOTAL SPACE FREED: $([math]::Round($totalFreed / 1024, 2)) GB" -ForegroundColor Green -BackgroundColor Black
Write-Host ""

if ($WhatIf) {
    Write-Host "This was a simulation. Run without -WhatIf to actually clean the files." -ForegroundColor Magenta
} else {
    Write-Host "CLEANUP COMPLETED SUCCESSFULLY!" -ForegroundColor Green
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
Write-Host "Script completed in fully automatic mode with force deletion support." -ForegroundColor White

# Display locked files summary
if ($script:pendingDeletions.Count -gt 0 -and !$WhatIf) {
    Write-Host ""
    Write-Host "LOCKED FILES SCHEDULED FOR REBOOT DELETION:" -ForegroundColor Yellow
    $script:lockedDirectories | Sort-Object | Get-Unique | ForEach-Object {
        Write-Host "  → $_" -ForegroundColor Magenta
    }
}
