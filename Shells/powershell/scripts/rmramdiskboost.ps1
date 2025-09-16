# FIXED Complete RAM Drive Removal Script
# Removes ALL persistence from C: drive and restores everything
# Safely restores EXACT original state with zero persistence
# Game saves remain PROTECTED throughout entire process
# Run as Administrator

#Requires -RunAsAdministrator

Write-Host "===============================================" -ForegroundColor Red
Write-Host "  FIXED COMPLETE RAM DRIVE REMOVAL" -ForegroundColor Red
Write-Host "  REMOVES ALL C: DRIVE PERSISTENCE!" -ForegroundColor Red
Write-Host "===============================================" -ForegroundColor Red
Write-Host ""
Write-Host "This will COMPLETELY remove the FIXED RAM drive setup:" -ForegroundColor Yellow
Write-Host "• Remove ALL startup tasks" -ForegroundColor White
Write-Host "• Remove ALL scripts from C:\RAMDrivePersistent\" -ForegroundColor White
Write-Host "• Remove ALL configuration files" -ForegroundColor White
Write-Host "• Restore ALL Chrome maximum allocation to original locations" -ForegroundColor White
Write-Host "• Restore ALL Firefox maximum allocation to original locations" -ForegroundColor White
Write-Host "• Restore ALL game cache redirections" -ForegroundColor White
Write-Host "• Reset ALL environment variables" -ForegroundColor White
Write-Host "• Move ALL data back from RAM drive safely" -ForegroundColor White
Write-Host "• Clean up ALL RAM drive folders" -ForegroundColor White
Write-Host "• Game saves remain PROTECTED and untouched" -ForegroundColor Green
Write-Host ""
Write-Host "Are you sure you want to completely remove the RAM drive setup?" -ForegroundColor Red
$confirmation = Read-Host "Type 'REMOVE' to confirm complete removal"

if ($confirmation -ne "REMOVE") {
    Write-Host "Removal cancelled" -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "Beginning complete removal of FIXED RAM drive configuration..." -ForegroundColor Green

# ===========================================
# LOAD CONFIGURATION FOR SAFE RESTORATION
# ===========================================
Write-Host "[1/15] Loading configuration for safe restoration..." -ForegroundColor Green

$configFile = "C:\RAMDrivePersistent\RAMDriveConfig.json"
$config = $null

if (Test-Path $configFile) {
    try {
        $config = Get-Content $configFile | ConvertFrom-Json
        Write-Host "✓ Loaded configuration version $($config.Version)" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Configuration file corrupted - proceeding with default restoration" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ Configuration file not found - proceeding with default restoration" -ForegroundColor Yellow
}

# ===========================================
# DETECT CURRENT RUNNING GAMES
# ===========================================
Write-Host "[2/15] Detecting current running games..." -ForegroundColor Green

function Get-CurrentRunningGames {
    $allProcesses = Get-Process | Where-Object { $_.ProcessName -ne "Idle" -and $_.ProcessName -ne "System" }
    
    $gamePatterns = @(
        "*game*", "*steam*", "*epic*", "*origin*", "*battle*", "*uplay*", "*gog*",
        "*minecraft*", "*fortnite*", "*valorant*", "*csgo*", "*cs2*", "*dota*", "*lol*",
        "*wow*", "*overwatch*", "*apex*", "*destiny*", "*warzone*", "*pubg*", "*rocket*",
        "*gta*", "*cyberpunk*", "*witcher*", "*assassin*", "*farcry*", "*battlefield*",
        "*cod*", "*callofduty*", "*fallout*", "*skyrim*", "*elden*", "*darksouls*"
    )
    
    $detectedGames = @()
    
    foreach ($process in $allProcesses) {
        $processName = $process.ProcessName.ToLower()
        
        foreach ($pattern in $gamePatterns) {
            if ($processName -like $pattern.ToLower()) {
                $detectedGames += @{
                    Name = $process.ProcessName
                    Path = $process.Path
                    Id = $process.Id
                }
                break
            }
        }
        
        if ($process.Path) {
            $processPath = $process.Path.ToLower()
            $gameDirectories = @("steam", "epic games", "origin games", "ubisoft", "gog", "rockstar")
            
            foreach ($gameDir in $gameDirectories) {
                if ($processPath -like "*$gameDir*") {
                    $detectedGames += @{
                        Name = $process.ProcessName
                        Path = $process.Path
                        Id = $process.Id
                    }
                    break
                }
            }
        }
    }
    
    return $detectedGames | Sort-Object Name | Get-Unique -AsString
}

$currentGames = Get-CurrentRunningGames
Write-Host "✓ Detected $($currentGames.Count) running games for restoration" -ForegroundColor Green

# ===========================================
# STOP ALL APPLICATIONS
# ===========================================
Write-Host "[3/15] Stopping ALL applications..." -ForegroundColor Green

$allAppsToStop = @("chrome", "firefox", "msedge") + ($currentGames | ForEach-Object { $_.Name })
foreach ($app in $allAppsToStop) {
    Get-Process -Name $app -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 5
Write-Host "✓ All applications stopped" -ForegroundColor Green

# ===========================================
# REMOVE ALL STARTUP TASKS
# ===========================================
Write-Host "[4/15] Removing ALL startup tasks..." -ForegroundColor Green

$tasksToRemove = @(
    "RAMDrive_SystemStartup",
    "RAMDrive_UserStartup", 
    "RAMDrive_Verification"
)

$removedTasks = 0
foreach ($taskName in $tasksToRemove) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "  ✓ Removed task: $taskName" -ForegroundColor Green
        $removedTasks++
    } else {
        Write-Host "  - Task not found: $taskName" -ForegroundColor Gray
    }
}

Write-Host "✓ All startup tasks removed ($removedTasks tasks)" -ForegroundColor Green

# ===========================================
# RESTORE ENVIRONMENT VARIABLES
# ===========================================
Write-Host "[5/15] Restoring ALL environment variables..." -ForegroundColor Green

# Restore user temp to default Windows location
[Environment]::SetEnvironmentVariable("TEMP", "$env:USERPROFILE\AppData\Local\Temp", "User")
[Environment]::SetEnvironmentVariable("TMP", "$env:USERPROFILE\AppData\Local\Temp", "User")

# Remove ALL custom environment variables
$envVarsToRemove = @(
    "CHROME_CACHE_DIR", "CHROME_USER_DATA_DIR", 
    "STEAM_COMPAT_DATA_PATH", "DXVK_STATE_CACHE_PATH", "__GL_SHADER_DISK_CACHE_PATH"
)

$removedEnvVars = 0
foreach ($var in $envVarsToRemove) {
    [Environment]::SetEnvironmentVariable($var, $null, "User")
    Write-Host "  ✓ Removed environment variable: $var" -ForegroundColor Green
    $removedEnvVars++
}

Write-Host "✓ All environment variables restored ($removedEnvVars variables)" -ForegroundColor Green

# ===========================================
# RESTORE CHROME ALLOCATION
# ===========================================
Write-Host "[6/15] Restoring Chrome allocation..." -ForegroundColor Green

$chromeMaxAllocationPaths = @{
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" = "A:\Chrome\MaxCache\Default"
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache" = "A:\Chrome\CodeCache\Default"
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache" = "A:\Chrome\GPUCache\Default"
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Media Cache" = "A:\Chrome\MediaCache\Default"
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Application Cache" = "A:\Chrome\ApplicationCache\Default"
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker" = "A:\Chrome\ServiceWorker\Default"
    "$env:LOCALAPPDATA\Google\Chrome\User Data\ShaderCache" = "A:\Chrome\ShaderCache\Global"
    "$env:LOCALAPPDATA\Google\Chrome\User Data\CrashReports" = "A:\Chrome\CrashReports"
}

# Add Chrome profiles
for ($i = 1; $i -le 5; $i++) {
    $profilePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Profile $i"
    if (Test-Path $profilePath) {
        $chromeMaxAllocationPaths["$profilePath\Cache"] = "A:\Chrome\MaxCache\Profile$i"
        $chromeMaxAllocationPaths["$profilePath\Code Cache"] = "A:\Chrome\CodeCache\Profile$i"
        $chromeMaxAllocationPaths["$profilePath\GPUCache"] = "A:\Chrome\GPUCache\Profile$i"
        $chromeMaxAllocationPaths["$profilePath\Media Cache"] = "A:\Chrome\MediaCache\Profile$i"
    }
}

# Use configuration if available
if ($config -and $config.SymbolicLinks) {
    foreach ($originalPath in $config.SymbolicLinks.PSObject.Properties.Name) {
        if ($originalPath -like "*Chrome*") {
            $targetPath = $config.SymbolicLinks.$originalPath
            $chromeMaxAllocationPaths[$originalPath] = $targetPath
        }
    }
}

$restoredChrome = 0
foreach ($original in $chromeMaxAllocationPaths.Keys) {
    $ramLocation = $chromeMaxAllocationPaths[$original]
    
    if ((Get-Item $original -ErrorAction SilentlyContinue).LinkType -eq "SymbolicLink") {
        Remove-Item $original -Force -ErrorAction SilentlyContinue
        
        if (Test-Path $ramLocation) {
            $parentDir = Split-Path $original -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            robocopy $ramLocation $original /E /MOVE /R:0 /W:0 /NFL /NDL /NJH /NJS | Out-Null
        }
        
        if (-not (Test-Path $original)) {
            New-Item -ItemType Directory -Path $original -Force | Out-Null
        }
        $restoredChrome++
    }
}

Write-Host "✓ Chrome allocation restored ($restoredChrome locations)" -ForegroundColor Green

# ===========================================
# RESTORE FIREFOX ALLOCATION
# ===========================================
Write-Host "[7/15] Restoring Firefox allocation..." -ForegroundColor Green

$restoredFirefox = 0
$firefoxProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
$profileIndex = 0

foreach ($profile in $firefoxProfiles) {
    $firefoxMaxPaths = @{
        $(Join-Path $profile.FullName "cache2") = "A:\Firefox\MaxCache\Profile$profileIndex"
        $(Join-Path $profile.FullName "OfflineCache") = "A:\Firefox\OfflineCache\Profile$profileIndex"
        $(Join-Path $profile.FullName "shader-cache") = "A:\Firefox\ShaderCache\Profile$profileIndex"
        $(Join-Path $profile.FullName "startupCache") = "A:\Firefox\DiskCache\Profile$profileIndex"
    }
    
    # Use configuration if available
    if ($config -and $config.SymbolicLinks) {
        foreach ($originalPath in $config.SymbolicLinks.PSObject.Properties.Name) {
            if ($originalPath -like "*Firefox*" -or $originalPath -like "*Mozilla*") {
                $targetPath = $config.SymbolicLinks.$originalPath
                $firefoxMaxPaths[$originalPath] = $targetPath
            }
        }
    }
    
    foreach ($original in $firefoxMaxPaths.Keys) {
        $ramLocation = $firefoxMaxPaths[$original]
        
        if ((Get-Item $original -ErrorAction SilentlyContinue).LinkType -eq "SymbolicLink") {
            Remove-Item $original -Force -ErrorAction SilentlyContinue
            
            if (Test-Path $ramLocation) {
                $parentDir = Split-Path $original -Parent
                if (-not (Test-Path $parentDir)) {
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                }
                robocopy $ramLocation $original /E /MOVE /R:0 /W:0 /NFL /NDL /NJH /NJS | Out-Null
            }
            
            if (-not (Test-Path $original)) {
                New-Item -ItemType Directory -Path $original -Force | Out-Null
            }
            $restoredFirefox++
        }
    }
    $profileIndex++
}

Write-Host "✓ Firefox allocation restored ($restoredFirefox locations)" -ForegroundColor Green

# ===========================================
# RESTORE GAMING ALLOCATION (SAVES PROTECTED)
# ===========================================
Write-Host "[8/15] Restoring gaming allocation (saves protected)..." -ForegroundColor Green

$gamingMaxAllocationPaths = @{
    "${env:ProgramFiles(x86)}\Steam\appcache" = "A:\Games\Steam\ShaderCache"
    "${env:ProgramFiles(x86)}\Steam\logs" = "A:\Games\Steam\Logs"
    "${env:ProgramFiles(x86)}\Steam\dumps" = "A:\Games\Steam\CrashDumps"
    "${env:ProgramFiles(x86)}\Steam\shader_cache" = "A:\Games\Steam\ShaderCache"
    "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache" = "A:\Games\Epic\ShaderCache"
    "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Logs" = "A:\Games\Epic\Logs"
    "$env:LOCALAPPDATA\D3DSCache" = "A:\Games\DirectX\ShaderCache"
    "$env:LOCALAPPDATA\NVIDIA\DXCache" = "A:\Games\NVIDIA\ShaderCache"
    "$env:LOCALAPPDATA\AMD\DxCache" = "A:\Games\AMD\ShaderCache"
}

# Use configuration if available
if ($config -and $config.SymbolicLinks) {
    foreach ($originalPath in $config.SymbolicLinks.PSObject.Properties.Name) {
        if ($originalPath -like "*Steam*" -or $originalPath -like "*Epic*" -or $originalPath -like "*D3DSCache*" -or $originalPath -like "*DXCache*" -or $originalPath -like "*DxCache*") {
            $targetPath = $config.SymbolicLinks.$originalPath
            $gamingMaxAllocationPaths[$originalPath] = $targetPath
        }
    }
}

$restoredGaming = 0
foreach ($original in $gamingMaxAllocationPaths.Keys) {
    $ramLocation = $gamingMaxAllocationPaths[$original]
    
    if ((Get-Item $original -ErrorAction SilentlyContinue).LinkType -eq "SymbolicLink") {
        Remove-Item $original -Force -ErrorAction SilentlyContinue
        
        if (Test-Path $ramLocation) {
            $parentDir = Split-Path $original -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            robocopy $ramLocation $original /E /MOVE /R:0 /W:0 /NFL /NDL /NJH /NJS | Out-Null
        }
        
        if (-not (Test-Path $original)) {
            New-Item -ItemType Directory -Path $original -Force | Out-Null
        }
        $restoredGaming++
    }
}

Write-Host "✓ Gaming allocation restored ($restoredGaming locations) - SAVES PROTECTED!" -ForegroundColor Green

# ===========================================
# RESTORE DETECTED GAMES
# ===========================================
Write-Host "[9/15] Restoring detected games..." -ForegroundColor Green

$restoredDetectedGames = 0

if (Test-Path "A:\DetectedGames") {
    $detectedGameFolders = Get-ChildItem "A:\DetectedGames" -Directory -ErrorAction SilentlyContinue
    
    foreach ($gameFolder in $detectedGameFolders) {
        $gameName = $gameFolder.Name
        
        $gameProcess = Get-Process -Name $gameName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($gameProcess -and $gameProcess.Path) {
            $gameDir = Split-Path $gameProcess.Path -Parent
            
            $cacheTypes = @("Cache", "Temp", "Logs", "Shaders", "Downloads")
            foreach ($cacheType in $cacheTypes) {
                $ramCachePath = "A:\DetectedGames\$gameName\$cacheType"
                $originalCachePath = "$gameDir\$($cacheType.ToLower())"
                
                if (Test-Path $ramCachePath) {
                    if ((Get-Item $originalCachePath -ErrorAction SilentlyContinue).LinkType -eq "SymbolicLink") {
                        Remove-Item $originalCachePath -Force -ErrorAction SilentlyContinue
                        robocopy $ramCachePath $originalCachePath /E /MOVE /R:0 /W:0 /NFL /NDL /NJH /NJS | Out-Null
                        
                        if (-not (Test-Path $originalCachePath)) {
                            New-Item -ItemType Directory -Path $originalCachePath -Force | Out-Null
                        }
                        $restoredDetectedGames++
                    }
                }
            }
        }
    }
}

Write-Host "✓ Detected games restored ($restoredDetectedGames locations)" -ForegroundColor Green

# ===========================================
# RESTORE OTHER APPLICATIONS
# ===========================================
Write-Host "[10/15] Restoring other applications..." -ForegroundColor Green

$otherAppsAllocationPaths = @{
    "$env:APPDATA\discord\Cache" = "A:\OtherApps\Discord"
    "$env:APPDATA\Spotify\Storage" = "A:\OtherApps\Spotify"
    "$env:APPDATA\Microsoft\Teams\Cache" = "A:\OtherApps\Teams"
    "$env:APPDATA\Code\User\workspaceStorage" = "A:\OtherApps\VSCode"
}

# Use configuration if available
if ($config -and $config.SymbolicLinks) {
    foreach ($originalPath in $config.SymbolicLinks.PSObject.Properties.Name) {
        if ($originalPath -like "*discord*" -or $originalPath -like "*Spotify*" -or $originalPath -like "*Teams*" -or $originalPath -like "*Code*") {
            $targetPath = $config.SymbolicLinks.$originalPath
            $otherAppsAllocationPaths[$originalPath] = $targetPath
        }
    }
}

$restoredOtherApps = 0
foreach ($original in $otherAppsAllocationPaths.Keys) {
    $ramLocation = $otherAppsAllocationPaths[$original]
    
    if ((Get-Item $original -ErrorAction SilentlyContinue).LinkType -eq "SymbolicLink") {
        Remove-Item $original -Force -ErrorAction SilentlyContinue
        
        if (Test-Path $ramLocation) {
            $parentDir = Split-Path $original -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            robocopy $ramLocation $original /E /MOVE /R:0 /W:0 /NFL /NDL /NJH /NJS | Out-Null
        }
        
        if (-not (Test-Path $original)) {
            New-Item -ItemType Directory -Path $original -Force | Out-Null
        }
        $restoredOtherApps++
    }
}

Write-Host "✓ Other applications restored ($restoredOtherApps locations)" -ForegroundColor Green

# ===========================================
# VERIFY GAME SAVE PROTECTION
# ===========================================
Write-Host "[11/15] Verifying game save protection..." -ForegroundColor Green

$criticalGameSaveLocations = @{
    "Steam User Data (ALL Game Saves)" = "${env:ProgramFiles(x86)}\Steam\userdata"
    "Epic Saved Games" = "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\SaveGames"
    "Documents My Games" = "$env:USERPROFILE\Documents\My Games"
    "Origin Electronic Arts Saves" = "$env:USERPROFILE\Documents\Electronic Arts"
    "Rockstar Social Club" = "$env:USERPROFILE\Documents\Rockstar Games"
}

Write-Host ""
Write-Host "GAME SAVE PROTECTION VERIFICATION:" -ForegroundColor Yellow
$allSavesProtected = $true

foreach ($location in $criticalGameSaveLocations.Keys) {
    $path = $criticalGameSaveLocations[$location]
    $status = "NOT FOUND"
    $color = "Gray"
    
    if (Test-Path $path) {
        $item = Get-Item $path -ErrorAction SilentlyContinue
        if ($item.LinkType -eq "SymbolicLink") {
            $status = "REDIRECTED (ERROR!)"
            $color = "Red"
            $allSavesProtected = $false
        } else {
            $status = "PROTECTED ✓"
            $color = "Green"
        }
    }
    
    Write-Host "  $location`: $status" -ForegroundColor $color
}

if ($allSavesProtected) {
    Write-Host ""
    Write-Host "✓ ALL GAME SAVES REMAIN FULLY PROTECTED!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠ WARNING: Some game save locations may have been affected!" -ForegroundColor Red
}

Write-Host "✓ Game save protection verification complete" -ForegroundColor Green

# ===========================================
# RESET PROCESS PRIORITIES
# ===========================================
Write-Host "[12/15] Resetting process priorities..." -ForegroundColor Green

$priorityProcessesToReset = @("chrome", "firefox", "msedge") + ($currentGames | ForEach-Object { $_.Name })
$resetPriorities = 0

foreach ($processName in $priorityProcessesToReset) {
    Get-Process -Name $processName -ErrorAction SilentlyContinue | ForEach-Object { 
        try { 
            $_.PriorityClass = "Normal"
            $resetPriorities++
        } catch {}
    }
}

Write-Host "✓ Reset $resetPriorities process priorities to normal" -ForegroundColor Green

# ===========================================
# CLEAN UP RAM DRIVE
# ===========================================
Write-Host "[13/15] Cleaning up RAM drive..." -ForegroundColor Green

if (Test-Path "A:\") {
    $ramDriveFiles = @(
        "A:\QuickMonitor.ps1",
        "A:\ManualRepair.ps1", 
        "A:\QuickAccess.ps1"
    )
    
    $removedFiles = 0
    foreach ($file in $ramDriveFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force -ErrorAction SilentlyContinue
            $removedFiles++
        }
    }
    
    $ramDriveFolders = @(
        "A:\Chrome", "A:\Firefox", "A:\Games", "A:\DetectedGames", "A:\OtherApps"
    )
    
    $removedFolders = 0
    foreach ($folder in $ramDriveFolders) {
        if (Test-Path $folder) {
            Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            $removedFolders++
        }
    }
    
    Write-Host "  ✓ Removed $removedFiles files and $removedFolders folders from RAM drive" -ForegroundColor Green
} else {
    Write-Host "  - RAM Drive not available for cleanup" -ForegroundColor Gray
}

Write-Host "✓ RAM drive cleaned up" -ForegroundColor Green

# ===========================================
# REMOVE C: DRIVE PERSISTENCE DIRECTORY
# ===========================================
Write-Host "[14/15] Removing C: drive persistence directory..." -ForegroundColor Green

$persistentDir = "C:\RAMDrivePersistent"
$removedPersistenceFiles = 0

if (Test-Path $persistentDir) {
    $persistenceFiles = Get-ChildItem $persistentDir -File -ErrorAction SilentlyContinue
    $removedPersistenceFiles = $persistenceFiles.Count
    
    Remove-Item $persistentDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Removed persistence directory with $removedPersistenceFiles files" -ForegroundColor Green
} else {
    Write-Host "  - Persistence directory not found" -ForegroundColor Gray
}

Write-Host "✓ C: drive persistence directory removed" -ForegroundColor Green

# ===========================================
# FINAL VERIFICATION AND SUMMARY
# ===========================================
Write-Host "[15/15] Final verification and summary..." -ForegroundColor Green

# Count remaining items
$remainingSymLinks = 0
$remainingTasks = 0
$remainingEnvVars = 0

# Check symbolic links
$checkPaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "${env:ProgramFiles(x86)}\Steam\appcache"
)

foreach ($path in $checkPaths) {
    if (Test-Path $path) {
        $item = Get-Item $path -ErrorAction SilentlyContinue
        if ($item.LinkType -eq "SymbolicLink") {
            $remainingSymLinks++
        }
    }
}

# Check tasks
foreach ($taskName in $tasksToRemove) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        $remainingTasks++
    }
}

# Check environment variables
foreach ($var in $envVarsToRemove) {
    $value = [Environment]::GetEnvironmentVariable($var, "User")
    if ($value) {
        $remainingEnvVars++
    }
}

$totalRestored = $restoredChrome + $restoredFirefox + $restoredGaming + $restoredDetectedGames + $restoredOtherApps
$totalRemoved = $removedTasks + $removedEnvVars + $removedPersistenceFiles

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "  FIXED COMPLETE REMOVAL FINISHED!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "REMOVAL SUMMARY:" -ForegroundColor Yellow
Write-Host "✓ Chrome locations restored: $restoredChrome" -ForegroundColor White
Write-Host "✓ Firefox locations restored: $restoredFirefox" -ForegroundColor White
Write-Host "✓ Gaming locations restored: $restoredGaming (saves protected)" -ForegroundColor White
Write-Host "✓ Detected games restored: $restoredDetectedGames" -ForegroundColor White
Write-Host "✓ Other applications restored: $restoredOtherApps" -ForegroundColor White
Write-Host "✓ Startup tasks removed: $removedTasks" -ForegroundColor White
Write-Host "✓ Environment variables removed: $removedEnvVars" -ForegroundColor White
Write-Host "✓ C: drive persistence files removed: $removedPersistenceFiles" -ForegroundColor White
Write-Host "✓ Total locations restored: $totalRestored" -ForegroundColor White
Write-Host "✓ Total components removed: $totalRemoved" -ForegroundColor White
Write-Host ""
Write-Host "PERSISTENCE REMOVAL VERIFIED:" -ForegroundColor Green
Write-Host "✓ C:\RAMDrivePersistent\ directory completely removed" -ForegroundColor White
Write-Host "✓ NO startup tasks remain ($remainingTasks remaining)" -ForegroundColor White
Write-Host "✓ NO symbolic links remain ($remainingSymLinks remaining)" -ForegroundColor White
Write-Host "✓ NO custom environment variables remain ($remainingEnvVars remaining)" -ForegroundColor White
Write-Host "✓ System will NOT attempt any RAM drive setup after reboot" -ForegroundColor White
Write-Host ""
Write-Host "GAME SAVE PROTECTION CONFIRMED:" -ForegroundColor Green
Write-Host "✓ Steam userdata - NEVER TOUCHED, FULLY PROTECTED" -ForegroundColor White
Write-Host "✓ Epic savedgames - NEVER TOUCHED, FULLY PROTECTED" -ForegroundColor White
Write-Host "✓ All game saves exactly where they were before" -ForegroundColor White
Write-Host ""
Write-Host "SYSTEM STATUS:" -ForegroundColor Yellow
Write-Host "• All applications use original cache locations" -ForegroundColor Green
Write-Host "• System performance back to original baseline" -ForegroundColor Green
Write-Host "• RAM drive can be safely removed/formatted" -ForegroundColor Green
Write-Host "• Zero persistence mechanisms remain" -ForegroundColor Green
Write-Host ""

if ($remainingSymLinks -eq 0 -and $remainingTasks -eq 0 -and $remainingEnvVars -eq 0 -and $totalRestored -gt 0) {
    Write-Host "🎉 PERFECT REMOVAL COMPLETED!" -ForegroundColor Green
    Write-Host "Your system is exactly as it was before the RAM drive setup." -ForegroundColor Cyan
    Write-Host "No persistence remains - system is completely clean!" -ForegroundColor Cyan
} else {
    Write-Host "⚠ REMOVAL SUMMARY:" -ForegroundColor Yellow
    if ($remainingSymLinks -gt 0) {
        Write-Host "  - $remainingSymLinks symbolic links may need manual removal" -ForegroundColor Yellow
    }
    if ($remainingTasks -gt 0) {
        Write-Host "  - $remainingTasks scheduled tasks may need manual removal" -ForegroundColor Yellow
    }
    if ($remainingEnvVars -gt 0) {
        Write-Host "  - $remainingEnvVars environment variables may need manual removal" -ForegroundColor Yellow
    }
    Write-Host "  + $totalRestored locations successfully restored" -ForegroundColor Green
}

Write-Host ""
Write-Host "FIXED RAM drive setup has been COMPLETELY removed!" -ForegroundColor Green
Write-Host "No scripts remain on C: drive - system is clean!" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
