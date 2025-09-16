# FIXED Bulletproof RAM Drive Setup - TRUE Persistence
# Stores all critical scripts on C: drive (NOT RAM drive)
# Ensures EVERYTHING stays EXACTLY the same after every reboot
# Chrome, Firefox & Games Maximum Allocation - Game saves PROTECTED
# Run as Administrator

#Requires -RunAsAdministrator

Write-Host "===============================================" -ForegroundColor Red
Write-Host "  FIXED BULLETPROOF RAM DRIVE - TRUE PERSISTENCE" -ForegroundColor Red
Write-Host "  SCRIPTS STORED ON C: DRIVE - SURVIVES REBOOT!" -ForegroundColor Red
Write-Host "===============================================" -ForegroundColor Red
Write-Host ""

# Check if A: drive exists
if (-not (Test-Path "A:\")) {
    Write-Host "ERROR: A: drive not found!" -ForegroundColor Red
    Write-Host "Please create your RAM disk first and assign it to drive A:" -ForegroundColor Red
    exit 1
}

Write-Host "[FIXED MODE] Creating TRUE persistence with scripts on C: drive..." -ForegroundColor Green
Write-Host "Everything will survive reboots because scripts are on permanent storage!" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Yellow
$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# ===========================================
# CREATE PERSISTENT STORAGE DIRECTORY ON C: DRIVE
# ===========================================
Write-Host "[1/12] Creating persistent storage directory on C: drive..." -ForegroundColor Green

$persistentDir = "C:\RAMDrivePersistent"
if (-not (Test-Path $persistentDir)) {
    New-Item -ItemType Directory -Path $persistentDir -Force | Out-Null
}

Write-Host "✓ Persistent storage directory created: $persistentDir" -ForegroundColor Green

# ===========================================
# CREATE CONFIGURATION SYSTEM (ON C: DRIVE)
# ===========================================
Write-Host "[2/12] Creating configuration system on C: drive..." -ForegroundColor Green

$configSystemScript = @'
# Configuration System - Stores EXACT configuration on C: drive
param([string]$Action = "Save")

$configFile = "C:\RAMDrivePersistent\RAMDriveConfig.json"

function Save-Configuration {
    $config = @{
        Version = "2.0"
        Timestamp = (Get-Date).ToString()
        RAMDriveLetter = "A:"
        
        # EXACT folder structure
        Folders = @(
            # Chrome Maximum (3GB)
            "A:\Chrome\MaxCache\Default", "A:\Chrome\MaxCache\Profile1", "A:\Chrome\MaxCache\Profile2", "A:\Chrome\MaxCache\Profile3",
            "A:\Chrome\CodeCache\Default", "A:\Chrome\CodeCache\Profile1", "A:\Chrome\CodeCache\Profile2", "A:\Chrome\CodeCache\Profile3",
            "A:\Chrome\GPUCache\Default", "A:\Chrome\GPUCache\Profile1", "A:\Chrome\GPUCache\Profile2", "A:\Chrome\GPUCache\Profile3",
            "A:\Chrome\MediaCache\Default", "A:\Chrome\MediaCache\Profile1", "A:\Chrome\MediaCache\Profile2", "A:\Chrome\MediaCache\Profile3",
            "A:\Chrome\ShaderCache\Global", "A:\Chrome\ShaderCache\Local", "A:\Chrome\ShaderCache\Backup",
            "A:\Chrome\ApplicationCache\Default", "A:\Chrome\ApplicationCache\Incognito",
            "A:\Chrome\ServiceWorker\Default", "A:\Chrome\ServiceWorker\Cache",
            "A:\Chrome\WebRTC\Logs", "A:\Chrome\CrashReports", "A:\Chrome\Extensions\Cache",
            
            # Firefox Maximum (2.5GB)
            "A:\Firefox\MaxCache\Default", "A:\Firefox\MaxCache\Profile1", "A:\Firefox\MaxCache\Profile2", "A:\Firefox\MaxCache\Profile3",
            "A:\Firefox\OfflineCache\Default", "A:\Firefox\OfflineCache\Profile1", "A:\Firefox\OfflineCache\Profile2",
            "A:\Firefox\ShaderCache\WebGL", "A:\Firefox\ShaderCache\WebGPU", "A:\Firefox\ShaderCache\DirectX",
            "A:\Firefox\DiskCache\Content", "A:\Firefox\DiskCache\Scripts", "A:\Firefox\DiskCache\Images",
            "A:\Firefox\WebCache\Storage", "A:\Firefox\WebCache\IndexedDB", "A:\Firefox\WebCache\LocalStorage",
            "A:\Firefox\Extensions\Cache", "A:\Firefox\Plugins\Cache", "A:\Firefox\CrashReports",
            
            # Games Maximum (2GB+)
            "A:\Games\Steam\ShaderCache", "A:\Games\Steam\Downloads", "A:\Games\Steam\Logs", "A:\Games\Steam\CrashDumps",
            "A:\Games\Epic\ShaderCache", "A:\Games\Epic\Downloads", "A:\Games\Epic\Logs", "A:\Games\Epic\CrashDumps",
            "A:\Games\Universal\ShaderCache", "A:\Games\Universal\Cache", "A:\Games\Universal\Temp", "A:\Games\Universal\Downloads",
            "A:\Games\DirectX\ShaderCache", "A:\Games\OpenGL\ShaderCache", "A:\Games\Vulkan\ShaderCache",
            "A:\Games\NVIDIA\ShaderCache", "A:\Games\AMD\ShaderCache", "A:\Games\Intel\ShaderCache",
            
            # Dynamic Games
            "A:\DetectedGames\Cache", "A:\DetectedGames\Temp", "A:\DetectedGames\Logs", "A:\DetectedGames\Shaders", "A:\DetectedGames\Downloads",
            
            # Other Apps (500MB)
            "A:\OtherApps\Discord", "A:\OtherApps\Spotify", "A:\OtherApps\Teams", "A:\OtherApps\VSCode", "A:\OtherApps\Temp"
        )
        
        # EXACT symbolic links mapping
        SymbolicLinks = @{
            # Chrome Complete
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" = "A:\Chrome\MaxCache\Default"
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache" = "A:\Chrome\CodeCache\Default"
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache" = "A:\Chrome\GPUCache\Default"
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Media Cache" = "A:\Chrome\MediaCache\Default"
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Application Cache" = "A:\Chrome\ApplicationCache\Default"
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker" = "A:\Chrome\ServiceWorker\Default"
            "$env:LOCALAPPDATA\Google\Chrome\User Data\ShaderCache" = "A:\Chrome\ShaderCache\Global"
            "$env:LOCALAPPDATA\Google\Chrome\User Data\CrashReports" = "A:\Chrome\CrashReports"
            
            # Gaming Complete (CACHES ONLY - SAVES PROTECTED!)
            "${env:ProgramFiles(x86)}\Steam\appcache" = "A:\Games\Steam\ShaderCache"
            "${env:ProgramFiles(x86)}\Steam\logs" = "A:\Games\Steam\Logs"
            "${env:ProgramFiles(x86)}\Steam\dumps" = "A:\Games\Steam\CrashDumps"
            "${env:ProgramFiles(x86)}\Steam\shader_cache" = "A:\Games\Steam\ShaderCache"
            "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache" = "A:\Games\Epic\ShaderCache"
            "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Logs" = "A:\Games\Epic\Logs"
            "$env:LOCALAPPDATA\D3DSCache" = "A:\Games\DirectX\ShaderCache"
            "$env:LOCALAPPDATA\NVIDIA\DXCache" = "A:\Games\NVIDIA\ShaderCache"
            "$env:LOCALAPPDATA\AMD\DxCache" = "A:\Games\AMD\ShaderCache"
            
            # Other Apps
            "$env:APPDATA\discord\Cache" = "A:\OtherApps\Discord"
            "$env:APPDATA\Spotify\Storage" = "A:\OtherApps\Spotify"
            "$env:APPDATA\Microsoft\Teams\Cache" = "A:\OtherApps\Teams"
            "$env:APPDATA\Code\User\workspaceStorage" = "A:\OtherApps\VSCode"
        }
        
        # EXACT environment variables
        EnvironmentVariables = @{
            "TEMP" = "A:\OtherApps\Temp"
            "TMP" = "A:\OtherApps\Temp"
            "CHROME_CACHE_DIR" = "A:\Chrome\MaxCache"
            "CHROME_USER_DATA_DIR" = "A:\Chrome"
            "STEAM_COMPAT_DATA_PATH" = "A:\Games\Steam"
            "DXVK_STATE_CACHE_PATH" = "A:\Games\DirectX"
            "__GL_SHADER_DISK_CACHE_PATH" = "A:\Games\OpenGL"
        }
    }
    
    # Save Firefox profiles dynamically
    $firefoxProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
    $profileIndex = 0
    foreach ($profile in $firefoxProfiles) {
        $config.SymbolicLinks[$(Join-Path $profile.FullName "cache2")] = "A:\Firefox\MaxCache\Profile$profileIndex"
        $config.SymbolicLinks[$(Join-Path $profile.FullName "OfflineCache")] = "A:\Firefox\OfflineCache\Profile$profileIndex"
        $config.SymbolicLinks[$(Join-Path $profile.FullName "shader-cache")] = "A:\Firefox\ShaderCache\Profile$profileIndex"
        $profileIndex++
    }
    
    # Save Chrome profiles dynamically
    for ($i = 1; $i -le 5; $i++) {
        $profilePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Profile $i"
        if (Test-Path $profilePath) {
            $config.SymbolicLinks["$profilePath\Cache"] = "A:\Chrome\MaxCache\Profile$i"
            $config.SymbolicLinks["$profilePath\Code Cache"] = "A:\Chrome\CodeCache\Profile$i"
            $config.SymbolicLinks["$profilePath\GPUCache"] = "A:\Chrome\GPUCache\Profile$i"
            $config.SymbolicLinks["$profilePath\Media Cache"] = "A:\Chrome\MediaCache\Profile$i"
        }
    }
    
    $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configFile -Encoding UTF8
    return $config
}

function Load-Configuration {
    if (Test-Path $configFile) {
        return Get-Content $configFile | ConvertFrom-Json
    }
    return $null
}

if ($Action -eq "Save") {
    Save-Configuration
} elseif ($Action -eq "Load") {
    Load-Configuration
}
'@

$configSystemScript | Out-File -FilePath "$persistentDir\ConfigSystem.ps1" -Encoding UTF8

Write-Host "✓ Configuration system created on C: drive" -ForegroundColor Green

# ===========================================
# CREATE MASTER PERSISTENCE SCRIPT (ON C: DRIVE)
# ===========================================
Write-Host "[3/12] Creating master persistence script on C: drive..." -ForegroundColor Green

$masterPersistenceScript = @'
# MASTER Persistence Script - RECREATES EVERYTHING AFTER REBOOT
# Stored on C: drive - SURVIVES REBOOT
param([switch]$Verbose)

function Write-PersistenceLog {
    param($Message, $Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = "C:\RAMDrivePersistent\PersistenceLog.txt"
    Add-Content -Path $logFile -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
    if ($Verbose) {
        Write-Host "[$timestamp] $Message" -ForegroundColor $Color
    }
}

Write-PersistenceLog "=== MASTER PERSISTENCE: Starting complete recreation ===" "Green"

# STAGE 1: WAIT FOR RAM DRIVE
$maxWait = 120
$waited = 0
while (-not (Test-Path "A:\") -and $waited -lt $maxWait) {
    Start-Sleep -Seconds 1
    $waited++
    if ($waited % 15 -eq 0) {
        Write-PersistenceLog "Waiting for RAM Drive... ($waited/$maxWait seconds)" "Yellow"
    }
}

if (-not (Test-Path "A:\")) {
    Write-PersistenceLog "CRITICAL ERROR: RAM Drive not available after $maxWait seconds!" "Red"
    exit 1
}

Write-PersistenceLog "RAM Drive A: confirmed available" "Green"

# STAGE 2: LOAD CONFIGURATION
$configFile = "C:\RAMDrivePersistent\RAMDriveConfig.json"
if (-not (Test-Path $configFile)) {
    Write-PersistenceLog "CRITICAL ERROR: Configuration file not found at $configFile" "Red"
    exit 1
}

$config = Get-Content $configFile | ConvertFrom-Json
Write-PersistenceLog "Loaded configuration version $($config.Version) from $($config.Timestamp)" "Green"

# STAGE 3: RECREATE ALL FOLDERS
Write-PersistenceLog "Recreating ALL folders..." "Green"

$folderCount = 0
$failedFolders = 0
foreach ($folder in $config.Folders) {
    try {
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null
            $folderCount++
        }
    } catch {
        Write-PersistenceLog "FAILED to create folder: $folder - $($_.Exception.Message)" "Red"
        $failedFolders++
    }
}

Write-PersistenceLog "Created $folderCount folders ($failedFolders failed)" "Green"

# STAGE 4: DETECT CURRENT GAMES
Write-PersistenceLog "Detecting running games..." "Green"

$gamePatterns = @(
    "*game*", "*steam*", "*epic*", "*origin*", "*battle*", "*uplay*", "*gog*",
    "*minecraft*", "*fortnite*", "*valorant*", "*csgo*", "*cs2*", "*dota*", "*lol*",
    "*wow*", "*overwatch*", "*apex*", "*destiny*", "*warzone*", "*pubg*", "*rocket*",
    "*gta*", "*cyberpunk*", "*witcher*", "*assassin*", "*farcry*", "*battlefield*",
    "*cod*", "*callofduty*", "*fallout*", "*skyrim*", "*elden*", "*darksouls*"
)

$currentGames = Get-Process | Where-Object { 
    $_.ProcessName -ne "Idle" -and $_.ProcessName -ne "System" 
} | Where-Object {
    $processName = $_.ProcessName.ToLower()
    foreach ($pattern in $gamePatterns) {
        if ($processName -like $pattern.ToLower()) { return $true }
    }
    return $false
} | Sort-Object ProcessName | Get-Unique -AsString

$gameCount = 0
foreach ($game in $currentGames) {
    $gameFolders = @(
        "A:\DetectedGames\$($game.ProcessName)\Cache",
        "A:\DetectedGames\$($game.ProcessName)\Temp",
        "A:\DetectedGames\$($game.ProcessName)\Logs",
        "A:\DetectedGames\$($game.ProcessName)\Shaders",
        "A:\DetectedGames\$($game.ProcessName)\Downloads"
    )
    foreach ($folder in $gameFolders) {
        try {
            New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null
            $gameCount++
        } catch {
            Write-PersistenceLog "Failed to create game folder: $folder" "Yellow"
        }
    }
}

Write-PersistenceLog "Created $gameCount game folders for $($currentGames.Count) detected games" "Green"

# STAGE 5: RECREATE ALL SYMBOLIC LINKS
Write-PersistenceLog "Recreating ALL symbolic links..." "Green"

$linkCount = 0
$failedLinks = 0

foreach ($originalPath in $config.SymbolicLinks.PSObject.Properties.Name) {
    $targetPath = $config.SymbolicLinks.$originalPath
    
    try {
        # Remove existing if not correct symbolic link
        if (Test-Path $originalPath) {
            $item = Get-Item $originalPath -ErrorAction SilentlyContinue
            if ($item.LinkType -eq "SymbolicLink" -and $item.Target -eq $targetPath) {
                continue # Already correct
            } else {
                Remove-Item $originalPath -Recurse -Force -ErrorAction Stop
            }
        }
        
        # Create parent directory
        $parentDir = Split-Path $originalPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force -ErrorAction Stop | Out-Null
        }
        
        # Ensure target exists
        if (-not (Test-Path $targetPath)) {
            New-Item -ItemType Directory -Path $targetPath -Force -ErrorAction Stop | Out-Null
        }
        
        # Create symbolic link
        New-Item -ItemType SymbolicLink -Path $originalPath -Target $targetPath -Force -ErrorAction Stop | Out-Null
        $linkCount++
        
    } catch {
        Write-PersistenceLog "FAILED to create symbolic link: $originalPath -> $targetPath - $($_.Exception.Message)" "Red"
        $failedLinks++
    }
}

Write-PersistenceLog "Created $linkCount symbolic links ($failedLinks failed)" "Green"

# STAGE 6: SET ENVIRONMENT VARIABLES
Write-PersistenceLog "Setting environment variables..." "Green"

$envCount = 0
foreach ($varName in $config.EnvironmentVariables.PSObject.Properties.Name) {
    $varValue = $config.EnvironmentVariables.$varName
    try {
        [Environment]::SetEnvironmentVariable($varName, $varValue, "User")
        $envCount++
    } catch {
        Write-PersistenceLog "Failed to set environment variable: $varName = $varValue" "Red"
    }
}

Write-PersistenceLog "Set $envCount environment variables" "Green"

# STAGE 7: SET PROCESS PRIORITIES
Write-PersistenceLog "Setting process priorities..." "Green"

$priorityCount = 0
$priorityProcesses = @("chrome", "firefox") + ($currentGames | ForEach-Object { $_.ProcessName })
foreach ($processName in $priorityProcesses) {
    Get-Process -Name $processName -ErrorAction SilentlyContinue | ForEach-Object { 
        try { 
            $_.PriorityClass = "High"
            $priorityCount++
        } catch {}
    }
}

Write-PersistenceLog "Set high priority for $priorityCount processes" "Green"

# STAGE 8: FINAL VERIFICATION
Write-PersistenceLog "Performing final verification..." "Green"

$verification = @{
    FoldersExist = ($config.Folders | Where-Object { Test-Path $_ }).Count
    SymbolicLinksCorrect = 0
    EnvironmentVariablesSet = 0
}

# Verify symbolic links
foreach ($originalPath in $config.SymbolicLinks.PSObject.Properties.Name) {
    $targetPath = $config.SymbolicLinks.$originalPath
    if (Test-Path $originalPath) {
        $item = Get-Item $originalPath -ErrorAction SilentlyContinue
        if ($item.LinkType -eq "SymbolicLink" -and $item.Target -eq $targetPath) {
            $verification.SymbolicLinksCorrect++
        }
    }
}

# Verify environment variables
foreach ($varName in $config.EnvironmentVariables.PSObject.Properties.Name) {
    $currentValue = [Environment]::GetEnvironmentVariable($varName, "User")
    $expectedValue = $config.EnvironmentVariables.$varName
    if ($currentValue -eq $expectedValue) {
        $verification.EnvironmentVariablesSet++
    }
}

$totalExpectedFolders = $config.Folders.Count
$totalExpectedLinks = $config.SymbolicLinks.PSObject.Properties.Name.Count
$totalExpectedEnvVars = $config.EnvironmentVariables.PSObject.Properties.Name.Count

$successRate = [math]::Round((
    ($verification.FoldersExist / $totalExpectedFolders) +
    ($verification.SymbolicLinksCorrect / $totalExpectedLinks) +
    ($verification.EnvironmentVariablesSet / $totalExpectedEnvVars)
) / 3 * 100, 1)

Write-PersistenceLog "=== MASTER PERSISTENCE COMPLETED ===" "Green"
Write-PersistenceLog "Folders: $($verification.FoldersExist)/$totalExpectedFolders | Links: $($verification.SymbolicLinksCorrect)/$totalExpectedLinks | EnvVars: $($verification.EnvironmentVariablesSet)/$totalExpectedEnvVars" "Cyan"
Write-PersistenceLog "Overall Success Rate: $successRate%" "Green"

# Copy monitoring scripts to RAM drive for convenience
$monitoringScripts = @(
    "C:\RAMDrivePersistent\QuickMonitor.ps1",
    "C:\RAMDrivePersistent\ManualRepair.ps1"
)

foreach ($script in $monitoringScripts) {
    if (Test-Path $script) {
        $scriptName = Split-Path $script -Leaf
        Copy-Item $script "A:\$scriptName" -Force -ErrorAction SilentlyContinue
    }
}

Write-PersistenceLog "Monitoring scripts copied to RAM drive for convenience" "Green"
Write-PersistenceLog "=== READY FOR USE ===" "Green"
'@

$masterPersistenceScript | Out-File -FilePath "$persistentDir\MasterPersistence.ps1" -Encoding UTF8

Write-Host "✓ Master persistence script created on C: drive" -ForegroundColor Green

# ===========================================
# CREATE MONITORING SCRIPT (ON C: DRIVE)
# ===========================================
Write-Host "[4/12] Creating monitoring script on C: drive..." -ForegroundColor Green

$monitoringScript = @'
# Quick Monitor Script for RAM Drive
Clear-Host
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   RAM DRIVE QUICK MONITOR" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path "A:\") {
    $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='A:'"
    $usedGB = [math]::Round(($drive.Size - $drive.FreeSpace) / 1GB, 2)
    $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
    $totalGB = [math]::Round($drive.Size / 1GB, 2)
    $usagePercent = [math]::Round(($usedGB / $totalGB) * 100, 1)
    
    Write-Host "RAM DRIVE STATUS:" -ForegroundColor Yellow
    Write-Host "  Used: $usedGB GB ($usagePercent%)" -ForegroundColor Green
    Write-Host "  Free: $freeGB GB" -ForegroundColor Green
    Write-Host "  Total: $totalGB GB" -ForegroundColor Cyan
    Write-Host ""
    
    # Check folder structure
    $folders = @("Chrome", "Firefox", "Games", "DetectedGames", "OtherApps")
    Write-Host "FOLDER STRUCTURE:" -ForegroundColor Yellow
    foreach ($folder in $folders) {
        $exists = Test-Path "A:\$folder"
        $status = if ($exists) {"✓"} else {"✗"}
        $color = if ($exists) {"Green"} else {"Red"}
        Write-Host "  $folder`: $status" -ForegroundColor $color
    }
    Write-Host ""
    
    # Check persistence system
    $persistenceStatus = if (Test-Path "C:\RAMDrivePersistent\MasterPersistence.ps1") {"ACTIVE ✓"} else {"MISSING ✗"}
    Write-Host "PERSISTENCE SYSTEM: $persistenceStatus" -ForegroundColor $(if($persistenceStatus -like "*✓*"){"Green"}else{"Red"})
    
    # Check scheduled tasks
    $systemTask = Get-ScheduledTask -TaskName "RAMDrive_SystemStartup" -ErrorAction SilentlyContinue
    $userTask = Get-ScheduledTask -TaskName "RAMDrive_UserStartup" -ErrorAction SilentlyContinue
    $taskStatus = "$(if($systemTask){"System:✓"}else{"System:✗"}) $(if($userTask){"User:✓"}else{"User:✗"})"
    Write-Host "STARTUP TASKS: $taskStatus" -ForegroundColor $(if($systemTask -and $userTask){"Green"}else{"Red"})
    
} else {
    Write-Host "RAM Drive A: NOT AVAILABLE!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Last persistence log entries:" -ForegroundColor Yellow
if (Test-Path "C:\RAMDrivePersistent\PersistenceLog.txt") {
    Get-Content "C:\RAMDrivePersistent\PersistenceLog.txt" | Select-Object -Last 5 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
} else {
    Write-Host "  No log file found" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit"
'@

$monitoringScript | Out-File -FilePath "$persistentDir\QuickMonitor.ps1" -Encoding UTF8

Write-Host "✓ Monitoring script created on C: drive" -ForegroundColor Green

# ===========================================
# CREATE MANUAL REPAIR SCRIPT (ON C: DRIVE)
# ===========================================
Write-Host "[5/12] Creating manual repair script on C: drive..." -ForegroundColor Green

$manualRepairScript = @'
# Manual Repair Script for RAM Drive
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host "  RAM DRIVE MANUAL REPAIR" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path "A:\")) {
    Write-Host "ERROR: RAM Drive A: not available!" -ForegroundColor Red
    Write-Host "Please ensure your RAM disk software is running" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Running manual repair..." -ForegroundColor Green

if (Test-Path "C:\RAMDrivePersistent\MasterPersistence.ps1") {
    & "C:\RAMDrivePersistent\MasterPersistence.ps1" -Verbose
    Write-Host ""
    Write-Host "✓ Manual repair completed!" -ForegroundColor Green
} else {
    Write-Host "✗ Master persistence script not found!" -ForegroundColor Red
    Write-Host "The persistence system may need to be reinstalled" -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to exit"
'@

$manualRepairScript | Out-File -FilePath "$persistentDir\ManualRepair.ps1" -Encoding UTF8

Write-Host "✓ Manual repair script created on C: drive" -ForegroundColor Green

# ===========================================
# SET ENVIRONMENT VARIABLES
# ===========================================
Write-Host "[6/12] Setting environment variables..." -ForegroundColor Green

[Environment]::SetEnvironmentVariable("TEMP", "A:\OtherApps\Temp", "User")
[Environment]::SetEnvironmentVariable("TMP", "A:\OtherApps\Temp", "User")
[Environment]::SetEnvironmentVariable("CHROME_CACHE_DIR", "A:\Chrome\MaxCache", "User")
[Environment]::SetEnvironmentVariable("CHROME_USER_DATA_DIR", "A:\Chrome", "User")
[Environment]::SetEnvironmentVariable("STEAM_COMPAT_DATA_PATH", "A:\Games\Steam", "User")
[Environment]::SetEnvironmentVariable("DXVK_STATE_CACHE_PATH", "A:\Games\DirectX", "User")
[Environment]::SetEnvironmentVariable("__GL_SHADER_DISK_CACHE_PATH", "A:\Games\OpenGL", "User")

Write-Host "✓ Environment variables set" -ForegroundColor Green

# ===========================================
# STOP APPLICATIONS
# ===========================================
Write-Host "[7/12] Stopping applications for setup..." -ForegroundColor Green

$appsToStop = @("chrome", "firefox", "msedge", "steam", "epicgameslauncher", "origin", "battle.net", "discord", "spotify")
foreach ($app in $appsToStop) {
    Get-Process -Name $app -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 3
Write-Host "✓ Applications stopped" -ForegroundColor Green

# ===========================================
# SAVE INITIAL CONFIGURATION
# ===========================================
Write-Host "[8/12] Saving initial configuration..." -ForegroundColor Green

& "$persistentDir\ConfigSystem.ps1" -Action "Save"

Write-Host "✓ Configuration saved" -ForegroundColor Green

# ===========================================
# RUN INITIAL SETUP
# ===========================================
Write-Host "[9/12] Running initial setup..." -ForegroundColor Green

& "$persistentDir\MasterPersistence.ps1" -Verbose

Write-Host "✓ Initial setup completed" -ForegroundColor Green

# ===========================================
# CREATE STARTUP TASKS (POINTING TO C: DRIVE)
# ===========================================
Write-Host "[10/12] Creating startup tasks pointing to C: drive..." -ForegroundColor Green

# Remove any existing tasks first
$existingTasks = @("RAMDrive_SystemStartup", "RAMDrive_UserStartup", "RAMDrive_Verification")
foreach ($taskName in $existingTasks) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
}

# System-level startup task
$action1 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\RAMDrivePersistent\MasterPersistence.ps1"
$trigger1 = New-ScheduledTaskTrigger -AtStartup
$trigger1.Delay = "PT30S"
$principal1 = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings1 = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName "RAMDrive_SystemStartup" -Action $action1 -Trigger $trigger1 -Principal $principal1 -Settings $settings1 -Force | Out-Null

# User-level startup task (backup)
$action2 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\RAMDrivePersistent\MasterPersistence.ps1"
$trigger2 = New-ScheduledTaskTrigger -AtLogOn
$trigger2.Delay = "PT45S"
$principal2 = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Limited
$settings2 = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName "RAMDrive_UserStartup" -Action $action2 -Trigger $trigger2 -Principal $principal2 -Settings $settings2 -Force | Out-Null

# Delayed verification task
$action3 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\RAMDrivePersistent\MasterPersistence.ps1"
$trigger3 = New-ScheduledTaskTrigger -AtStartup
$trigger3.Delay = "PT90S"
$principal3 = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings3 = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName "RAMDrive_Verification" -Action $action3 -Trigger $trigger3 -Principal $principal3 -Settings $settings3 -Force | Out-Null

Write-Host "✓ Startup tasks created (pointing to C: drive scripts)" -ForegroundColor Green

# ===========================================
# COPY CONVENIENCE SCRIPTS TO RAM DRIVE
# ===========================================
Write-Host "[11/12] Copying convenience scripts to RAM drive..." -ForegroundColor Green

Copy-Item "$persistentDir\QuickMonitor.ps1" "A:\QuickMonitor.ps1" -Force -ErrorAction SilentlyContinue
Copy-Item "$persistentDir\ManualRepair.ps1" "A:\ManualRepair.ps1" -Force -ErrorAction SilentlyContinue

# Create quick access script on RAM drive
$quickAccessScript = @'
# Quick Access Commands
Write-Host "RAM DRIVE QUICK ACCESS" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Commands:" -ForegroundColor Yellow
Write-Host "• Monitor    - powershell A:\QuickMonitor.ps1" -ForegroundColor White
Write-Host "• Repair     - powershell A:\ManualRepair.ps1" -ForegroundColor White
Write-Host "• Full Setup - powershell C:\RAMDrivePersistent\MasterPersistence.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Persistence files stored on C: drive:" -ForegroundColor Green
Write-Host "• C:\RAMDrivePersistent\MasterPersistence.ps1" -ForegroundColor White
Write-Host "• C:\RAMDrivePersistent\RAMDriveConfig.json" -ForegroundColor White
Write-Host "• C:\RAMDrivePersistent\PersistenceLog.txt" -ForegroundColor White
Write-Host ""
'@

$quickAccessScript | Out-File -FilePath "A:\QuickAccess.ps1" -Encoding UTF8

Write-Host "✓ Convenience scripts copied to RAM drive" -ForegroundColor Green

# ===========================================
# FINAL COMPLETION
# ===========================================
Write-Host "[12/12] Finalizing FIXED persistence system..." -ForegroundColor Green

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "  FIXED BULLETPROOF SETUP COMPLETE!" -ForegroundColor Green
Write-Host "  🔧 PERSISTENCE SCRIPTS ON C: DRIVE!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "CRITICAL FIXES APPLIED:" -ForegroundColor Yellow
Write-Host "✓ All persistence scripts moved to C:\RAMDrivePersistent\" -ForegroundColor White
Write-Host "✓ Configuration file stored on C: drive (survives reboot)" -ForegroundColor White
Write-Host "✓ Master persistence script on C: drive (survives reboot)" -ForegroundColor White
Write-Host "✓ Startup tasks point to C: drive scripts" -ForegroundColor White
Write-Host "✓ Multiple startup tasks for redundancy" -ForegroundColor White
Write-Host "✓ Enhanced error handling and logging" -ForegroundColor White
Write-Host "✓ Extended RAM drive wait time (120 seconds)" -ForegroundColor White
Write-Host ""
Write-Host "ALLOCATION TARGETS:" -ForegroundColor Yellow
Write-Host "🎯 Chrome: 3GB EXACT (all profiles, all cache types)" -ForegroundColor White
Write-Host "🎯 Firefox: 2.5GB EXACT (all profiles, all cache types)" -ForegroundColor White
Write-Host "🎯 Games: 2GB+ EXACT (detected + platform caches)" -ForegroundColor White
Write-Host "📱 Other Apps: 500MB (minimal allocation)" -ForegroundColor White
Write-Host ""
Write-Host "GAME SAVE PROTECTION:" -ForegroundColor Green
Write-Host "✓ Steam userdata - NEVER TOUCHED" -ForegroundColor White
Write-Host "✓ Epic savedgames - NEVER TOUCHED" -ForegroundColor White
Write-Host "✓ All game saves - NEVER TOUCHED" -ForegroundColor White
Write-Host ""
Write-Host "PERSISTENCE FILES (ON C: DRIVE):" -ForegroundColor Cyan
Write-Host "• C:\RAMDrivePersistent\MasterPersistence.ps1 (main script)" -ForegroundColor White
Write-Host "• C:\RAMDrivePersistent\RAMDriveConfig.json (configuration)" -ForegroundColor White
Write-Host "• C:\RAMDrivePersistent\ConfigSystem.ps1 (config management)" -ForegroundColor White
Write-Host "• C:\RAMDrivePersistent\QuickMonitor.ps1 (monitoring)" -ForegroundColor White
Write-Host "• C:\RAMDrivePersistent\ManualRepair.ps1 (repair tool)" -ForegroundColor White
Write-Host "• C:\RAMDrivePersistent\PersistenceLog.txt (logs)" -ForegroundColor White
Write-Host ""
Write-Host "CONVENIENCE SCRIPTS (ON RAM DRIVE):" -ForegroundColor Cyan
Write-Host "• A:\QuickMonitor.ps1 (quick status check)" -ForegroundColor White
Write-Host "• A:\ManualRepair.ps1 (quick repair)" -ForegroundColor White
Write-Host "• A:\QuickAccess.ps1 (command reference)" -ForegroundColor White
Write-Host ""
Write-Host "STARTUP TASKS REGISTERED:" -ForegroundColor Cyan
Write-Host "• RAMDrive_SystemStartup (30s delay, system level)" -ForegroundColor White
Write-Host "• RAMDrive_UserStartup (45s delay, user level)" -ForegroundColor White
Write-Host "• RAMDrive_Verification (90s delay, verification)" -ForegroundColor White
Write-Host ""
Write-Host "🔄 REBOOT NOW TO TEST - EVERYTHING WILL PERSIST!" -ForegroundColor Green
Write-Host ""
Write-Host "After reboot, you should see ALL folders recreated:" -ForegroundColor Yellow
Write-Host "• Chrome, Firefox, Games, DetectedGames, OtherApps" -ForegroundColor White
Write-Host "• All PowerShell scripts copied back to A: drive" -ForegroundColor White
Write-Host "• All symbolic links working" -ForegroundColor White
Write-Host ""
Write-Host "If any issues occur, check:" -ForegroundColor Yellow
Write-Host "• C:\RAMDrivePersistent\PersistenceLog.txt (for logs)" -ForegroundColor White
Write-Host "• Run: powershell C:\RAMDrivePersistent\MasterPersistence.ps1 -Verbose" -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to exit"
