# Windows 11 Cache and Temp Cleanup Script
# Run as Administrator for best results

param(
    [switch]$WhatIf = $false  # Add -WhatIf to see what would be deleted without actually deleting
)

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

# Function to safely clean directory contents
function Clear-DirectoryContents {
    param(
        [string]$Path,
        [string]$Description = ""
    )
    
    $sizeBefore = 0
    $sizeAfter = 0
    
    try {
        if (Test-Path $Path) {
            Write-Host "Processing: $Path" -ForegroundColor Cyan
            
            # Get size before cleanup
            $sizeBefore = Get-FolderSizeMB -Path $Path
            
            if ($sizeBefore -gt 0) {
                Write-Host "  Size before: $sizeBefore MB" -ForegroundColor Yellow
                
                if (!$WhatIf) {
                    # Delete all contents but keep the directory
                    Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    
                    # Get size after cleanup
                    $sizeAfter = Get-FolderSizeMB -Path $Path
                    $freed = $sizeBefore - $sizeAfter
                    
                    if ($freed -gt 0) {
                        Write-Host "  Freed: $freed MB" -ForegroundColor Green
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
        return 0
    }
}

# Initialize counters
$totalFreed = 0
$processedCount = 0
$skippedCount = 0

Write-Host "=======================================" -ForegroundColor White
Write-Host "Windows 11 Cache and Temp Cleanup Tool" -ForegroundColor White
Write-Host "=======================================" -ForegroundColor White

if ($WhatIf) {
    Write-Host "RUNNING IN WHATIF MODE - NO FILES WILL BE DELETED" -ForegroundColor Magenta
    Write-Host ""
}

# Define all directories to clean (extracted from your data)
$directoriesToClean = @(
    # Cache directories
    "C:\Windows\System32\winevt\Logs",
    "C:\Users\micha\AppData\Local\Packages\MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy\LocalState\EBWebView\Default\Cache",
    "C:\Users\micha\AppData\Local\Docker\log",
    "C:\Users\micha\AppData\Roaming\Todoist\Cache",
    "C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\Cortana.UI\cache",
    "C:\Windows\WinSxS\amd64_userexperience-desktop_31bf3856ad364e35_10.0.26100.4768_none_c7fcad031a649b96\CBS\Cortana.UI\cache",
    "C:\Windows\WinSxS\amd64_userexperience-desktop_31bf3856ad364e35_10.0.26100.1591_none_c815e77f1a5104dd\CBS\Cortana.UI\cache",
    "C:\Windows\WinSxS\amd64_userexperience-lkg_31bf3856ad364e35_10.0.26100.1742_none_3c72368675eae921\LKG.Search\Cortana.UI\cache",
    "C:\Users\micha\AppData\Local\CD Projekt Red\Cyberpunk 2077\cache",
    "C:\Users\micha\AppData\Local\Packages\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\LocalState\EBWebView\Default\Cache",
    "C:\Windows\Logs",
    "C:\Users\micha\AppData\Local\NVIDIA Corporation\NVIDIA App\CefCache\Default\Cache",
    "C:\Users\micha\AppData\Local\Packages\B9ECED6F.ASUSPCAssistant_qmba6cd70vzyy\LocalState\EBWebView\Default\Cache",
    "C:\Users\micha\AppData\Roaming\Wise Utilities\EBWebView\Default\Cache",
    "C:\Users\micha\AppData\Roaming\Cursor\Cache",
    "C:\Windows\SoftwareDistribution\DataStore\Logs",
    "C:\ProgramData\ASUS\ASUS System Control Interface\log",
    "C:\Users\micha\AppData\Local\NVIDIA Corporation\NVIDIA Overlay\CefCache\Default\Cache",
    "C:\Users\micha\AppData\Local\Microsoft\Power Automate Desktop\Cache",
    "C:\ProgramData\NVIDIA Corporation\NVIDIA App\Installer\Logs",
    "C:\ProgramData\Microsoft\EdgeUpdate\Log",
    "C:\Windows\WinSxS\amd64_userexperience-desktop_31bf3856ad364e35_10.0.26100.1591_none_c815e77f1a5104dd\r\CBS\Cortana.UI\cache",
    "C:\ProgramData\NVIDIA Corporation\NVIDIA App\Logs",
    "C:\Users\micha\AppData\Roaming\Docker Desktop\Cache",
    "C:\Users\micha\AppData\Local\Microsoft\Windows\Caches",
    "C:\Users\micha\AppData\Roaming\Cursor\logs",
    "C:\Windows\System32\spp\store\2.0\cache",
    "C:\Users\micha\AppData\Local\Google\Chrome\User Data\Default\Shared Dictionary\cache",
    "C:\Windows\System32\config\systemprofile\AppData\Local\Microsoft\Windows\Caches",
    "C:\ProgramData\Microsoft\Windows Security Health\Logs",
    "C:\Users\micha\AppData\Local\AMD\RadeonSoftware\cache",
    "C:\ProgramData\Microsoft\Windows\LfSvc\Cache",
    "C:\ProgramData\USOShared\Logs",
    "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Logs",
    "C:\Users\micha\AppData\Local\Packages\B9ECED6F.ASUSPCAssistant_qmba6cd70vzyy\LocalState\log",
    "C:\Users\micha\AppData\Roaming\GlarySoft\Glary Utilities\Log",
    "C:\Windows\WinSxS\amd64_userexperience-desktop_31bf3856ad364e35_10.0.26100.4768_none_c7fcad031a649b96\r\CBS\Cortana.UI\cache",
    "C:\Users\micha\AppData\Local\Microsoft\TokenBroker\Cache",
    "C:\Users\micha\AppData\Local\Packages\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\AC\TokenBroker\Cache",
    
    # Temp directories
    "C:\Users\micha\AppData\Local\Temp",
    "C:\Windows\Temp",
    "C:\Windows\WinSxS\Temp",
    "C:\ProgramData\Microsoft\Windows\Containers\Layers\51d19691-4f83-4cad-9042-a9972a72b773\Files\Windows\WinSxS\Temp",
    
    # Additional cache and temp locations
    "C:\Users\micha\AppData\Local\Microsoft\Windows\INetCache",
    "C:\Users\micha\AppData\Local\Microsoft\Windows\WebCache",
    "C:\Users\micha\AppData\Local\CrashDumps",
    "C:\Windows\Prefetch",
    "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
    "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
    "C:\ProgramData\Microsoft\Windows\WER\Temp",
    
    # Thumbnail cache
    "C:\Users\micha\AppData\Local\Microsoft\Windows\Explorer",
    
    # Recent files
    "C:\Users\micha\AppData\Roaming\Microsoft\Windows\Recent"
)

# Add current user paths (replace 'micha' with current user)
$currentUser = $env:USERNAME
$userSpecificPaths = @()

foreach ($path in $directoriesToClean) {
    if ($path -like "*\Users\micha\*") {
        $userSpecificPaths += $path -replace "\\Users\\micha\\", "\Users\$currentUser\"
    }
}

# Combine original and user-specific paths
$allPaths = $directoriesToClean + $userSpecificPaths | Sort-Object | Get-Unique

Write-Host "Starting cleanup of $($allPaths.Count) directories..." -ForegroundColor Green
Write-Host ""

# Process each directory
foreach ($directory in $allPaths) {
    $freed = Clear-DirectoryContents -Path $directory
    $totalFreed += $freed
    $processedCount++
    
    if ($freed -eq 0 -and !(Test-Path $directory)) {
        $skippedCount++
    }
    
    Start-Sleep -Milliseconds 100  # Small delay to prevent overwhelming the system
}

# Run Windows built-in cleanup
Write-Host ""
Write-Host "Running additional Windows cleanup tools..." -ForegroundColor Green

if (!$WhatIf) {
    try {
        # Clean Windows Update cache
        Write-Host "Cleaning Windows Update cache..." -ForegroundColor Cyan
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        $wuCacheSize = Get-FolderSizeMB -Path "C:\Windows\SoftwareDistribution\Download"
        if ($wuCacheSize -gt 0) {
            Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
            $totalFreed += $wuCacheSize
            Write-Host "  Freed: $wuCacheSize MB from Windows Update cache" -ForegroundColor Green
        }
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        
        # Run Disk Cleanup for system files
        Write-Host "Running system disk cleanup..." -ForegroundColor Cyan
        $beforeCleanup = (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        $afterCleanup = (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
        $systemCleanupFreed = [math]::Round(($afterCleanup - $beforeCleanup) / 1MB, 2)
        if ($systemCleanupFreed -gt 0) {
            $totalFreed += $systemCleanupFreed
            Write-Host "  System cleanup freed: $systemCleanupFreed MB" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  Some system cleanup operations failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Final summary
Write-Host ""
Write-Host "=======================================" -ForegroundColor White
Write-Host "CLEANUP SUMMARY" -ForegroundColor White
Write-Host "=======================================" -ForegroundColor White
Write-Host "Directories processed: $processedCount" -ForegroundColor Cyan
Write-Host "Directories skipped (not found): $skippedCount" -ForegroundColor Yellow
Write-Host ""
Write-Host "TOTAL SPACE FREED: $totalFreed MB" -ForegroundColor Green -BackgroundColor Black
Write-Host "TOTAL SPACE FREED: $([math]::Round($totalFreed / 1024, 2)) GB" -ForegroundColor Green -BackgroundColor Black
Write-Host ""

if ($WhatIf) {
    Write-Host "This was a simulation. Run without -WhatIf to actually clean the files." -ForegroundColor Magenta
} else {
    Write-Host "Cleanup completed successfully!" -ForegroundColor Green
    Write-Host "It's recommended to restart your computer to ensure all changes take effect." -ForegroundColor Yellow
}

# Optional: Empty Recycle Bin
$emptyRecycleBin = Read-Host "Would you like to empty the Recycle Bin as well? (y/n)"
if ($emptyRecycleBin -eq 'y' -or $emptyRecycleBin -eq 'Y') {
    if (!$WhatIf) {
        try {
            $recycleBinSize = (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'").Size - (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            Write-Host "Recycle Bin emptied." -ForegroundColor Green
        }
        catch {
            Write-Host "Could not empty Recycle Bin: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[WHATIF] Would empty Recycle Bin" -ForegroundColor Magenta
    }
}
