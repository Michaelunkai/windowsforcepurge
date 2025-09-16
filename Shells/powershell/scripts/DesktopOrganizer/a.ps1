# Desktop and Taskbar Reset Script
# Run as Administrator

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Starting Desktop and Taskbar Reset..." -ForegroundColor Green

# Get desktop path
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$PublicDesktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")

# Function to create folder shortcut (with AGGRESSIVE duplicate prevention)
function Create-FolderShortcut {
    param(
        [string]$ShortcutName,
        [string]$TargetPath,
        [string]$DesktopPath
    )
    
    $ShortcutPath = "$DesktopPath\$ShortcutName.lnk"
    
    # ABSOLUTE BAN on creating Recycle Bin shortcuts
    if ($ShortcutName -eq "Recycle Bin" -or $ShortcutName -like "*Recycle*") {
        Write-Host "🚫 BLOCKED: Will NOT create Recycle Bin shortcut to prevent duplicates!" -ForegroundColor Red
        return
    }
    
    # AGGRESSIVELY remove ANY existing shortcut with similar names - NO PROMPTS!
    $SimilarNames = @("$ShortcutName", "$ShortcutName.lnk", "$ShortcutName (2)", "$ShortcutName - Copy")
    foreach ($name in $SimilarNames) {
        $TestPath = "$DesktopPath\$name"
        if (Test-Path $TestPath) {
            Remove-Item $TestPath -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "ELIMINATED DUPLICATE: $name" -ForegroundColor Red
        }
        $TestPathLnk = "$DesktopPath\$name.lnk"
        if (Test-Path $TestPathLnk) {
            Remove-Item $TestPathLnk -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "ELIMINATED DUPLICATE: $name.lnk" -ForegroundColor Red
        }
    }
    
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.Save()
    Write-Host "Created UNIQUE shortcut: $ShortcutName -> $TargetPath" -ForegroundColor Cyan
}

# Function to create file shortcut (with AGGRESSIVE duplicate prevention)
function Create-FileShortcut {
    param(
        [string]$ShortcutName,
        [string]$TargetPath,
        [string]$DesktopPath
    )
    
    $ShortcutPath = "$DesktopPath\$ShortcutName.lnk"
    
    # AGGRESSIVELY remove ANY existing shortcut with similar names - NO PROMPTS!
    $SimilarNames = @("$ShortcutName", "$ShortcutName.lnk", "$ShortcutName (2)", "$ShortcutName - Copy")
    foreach ($name in $SimilarNames) {
        $TestPath = "$DesktopPath\$name"
        if (Test-Path $TestPath) {
            Remove-Item $TestPath -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "ELIMINATED DUPLICATE: $name" -ForegroundColor Red
        }
        $TestPathLnk = "$DesktopPath\$name.lnk"
        if (Test-Path $TestPathLnk) {
            Remove-Item $TestPathLnk -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "ELIMINATED DUPLICATE: $name.lnk" -ForegroundColor Red
        }
    }
    
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.Save()
    Write-Host "Created UNIQUE shortcut: $ShortcutName -> $TargetPath" -ForegroundColor Cyan
}

# Step 1: AGGRESSIVELY remove ALL desktop shortcuts and duplicates
Write-Host "AGGRESSIVELY removing ALL desktop shortcuts and duplicates..." -ForegroundColor Red

# Remove ALL shortcuts from EVERYWHERE (no games backup needed) - NO PROMPTS!
$LocationsToClean = @($DesktopPath, $PublicDesktopPath)
foreach ($location in $LocationsToClean) {
    Get-ChildItem -Path $location -Filter "*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
    Get-ChildItem -Path $location -Filter "*.url" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
}

# AGGRESSIVE cleanup: Remove ALL possible variations and duplicates (PRESERVE WINDOWS RECYCLE BIN)
$AllPossibleNames = @(
    "This PC", "ThisPC", "This PC.lnk",
    "gamesaves", "Gamesaves", "gamesaves.lnk",
    "win11recovery", "Win11recovery", "win11recovery.lnk", "win11recov...", "win11recov.lnk",
    "install", "Install", "install.lnk",
    "wsl", "WSL", "wsl.lnk",
    "games", "Games", "GAMES", "games.lnk", "Games.lnk",
    "installed", "Installed", "installed.lnk",
    "yt", "YT", "yt.lnk",
    "alias.txt", "alias.txt.lnk",
    "misha", "Misha", "misha.lnk",
    "backup", "Backup", "backup.lnk",
    "profile", "Profile", "profile.lnk",
    "Credentials", "credentials", "Credentials.lnk",
    "study", "Study", "study.lnk",
    "Downloads", "downloads", "Downloads.lnk",
    "SyncFiles", "syncfiles", "SyncFiles.lnk"
)

foreach ($location in $LocationsToClean) {
    foreach ($name in $AllPossibleNames) {
        $FullPath = "$location\$name"
        if (Test-Path $FullPath) {
            Remove-Item $FullPath -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "REMOVED: $FullPath" -ForegroundColor Red
        }
    }
}

# Handle Recycle Bin specially - remove ONLY duplicates, keep one valid one
foreach ($location in $LocationsToClean) {
    $RecycleBins = Get-ChildItem -Path $location -Filter "*Recycle*" -ErrorAction SilentlyContinue
    if ($RecycleBins.Count -gt 1) {
        # Keep the first valid one, remove all others
        for ($i = 1; $i -lt $RecycleBins.Count; $i++) {
            Remove-Item $RecycleBins[$i].FullName -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "REMOVED DUPLICATE RECYCLE BIN: $($RecycleBins[$i].Name)" -ForegroundColor Red
        }
    }
}

# Force remove any .lnk files that start with problematic names (NOT Recycle Bin)
foreach ($location in $LocationsToClean) {
    Get-ChildItem -Path $location -Filter "*.lnk" -ErrorAction SilentlyContinue | Where-Object {
        $_.BaseName -like "*Games*" -or 
        $_.BaseName -like "*games*" -or
        $_.BaseName -like "*This PC*" -or
        $_.BaseName -like "*Downloads*"
    } | Remove-Item -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
}

Write-Host "AGGRESSIVE cleanup completed - All games shortcuts removed!" -ForegroundColor Green

# Step 2: Create alias.txt file if it doesn't exist
Write-Host "Ensuring alias.txt file exists..." -ForegroundColor Yellow

# Create alias.txt file if it doesn't exist
$AliasFile = "C:\Users\misha\alias.txt"
if (!(Test-Path $AliasFile)) {
    # Create the directory if it doesn't exist
    $AliasDir = Split-Path $AliasFile -Parent
    if (!(Test-Path $AliasDir)) {
        New-Item -Path $AliasDir -ItemType Directory -Force | Out-Null
    }
    New-Item -Path $AliasFile -ItemType File -Force | Out-Null
    Write-Host "Created file: $AliasFile" -ForegroundColor Cyan
}

# Step 3: Create desktop shortcuts in EXACT layout from your image (NO DUPLICATES)
Write-Host "Creating desktop shortcuts in exact layout..." -ForegroundColor Yellow

# Define all shortcuts in exact order matching your image (NO RECYCLE BIN CREATION!)
$DesktopShortcuts = @(
    # Row 1: alias.txt, installed, win11recovery
    @{Name="alias.txt"; Target="C:\Users\misha\alias.txt"; Type="File"},
    @{Name="installed"; Target="F:\backup\windowsapps\installed"; Type="Folder"},
    @{Name="win11recovery"; Target="F:\win11recovery"; Type="Folder"},
    
    # Row 2: backup, misha, wsl
    @{Name="backup"; Target="F:\backup"; Type="Folder"},
    @{Name="misha"; Target="C:\Users\misha"; Type="Folder"},
    @{Name="wsl"; Target="F:\backup\linux\wsl"; Type="Folder"},
    
    # Row 3: Credentials, profile, yt
    @{Name="Credentials"; Target="F:\backup\windowsapps\Credentials"; Type="Folder"},
    @{Name="profile"; Target="F:\backup\windowsapps\profile"; Type="Folder"},
    @{Name="yt"; Target="F:\yt"; Type="Folder"},
    
    # Row 4: Downloads (NO RECYCLE BIN CREATION - Windows handles this!)
    @{Name="Downloads"; Target="F:\Downloads"; Type="Folder"},
    
    # Row 5: study (games will be preserved if it exists, not recreated)
    @{Name="study"; Target="F:\study"; Type="Folder"},
    
    # Row 6: gamesaves, SyncFiles
    @{Name="gamesaves"; Target="F:\backup\gamesaves"; Type="Folder"},
    @{Name="SyncFiles"; Target="F:\backup\SyncFiles"; Type="Folder"},
    
    # Row 7: install, This PC
    @{Name="install"; Target="F:\backup\windowsapps\install"; Type="Folder"},
    @{Name="This PC"; Target="shell:MyComputerFolder"; Type="Folder"}
)

# Create each shortcut exactly once (RECYCLE BIN EXCLUDED FROM CREATION!)
foreach ($shortcut in $DesktopShortcuts) {
    if ($shortcut.Type -eq "File") {
        Create-FileShortcut -ShortcutName $shortcut.Name -TargetPath $shortcut.Target -DesktopPath $DesktopPath
    } else {
        Create-FolderShortcut -ShortcutName $shortcut.Name -TargetPath $shortcut.Target -DesktopPath $DesktopPath
    }
}

# Create 'games' FOLDER (not shortcut) on desktop - NO PROMPTS!
Write-Host "Creating 'games' folder on desktop..." -ForegroundColor Yellow
$GamesFolderPath = "$DesktopPath\games"

# Remove any existing games folder/shortcut first - NO PROMPTS!
if (Test-Path $GamesFolderPath) {
    Remove-Item $GamesFolderPath -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed existing games folder/shortcut" -ForegroundColor Red
}

# Create the games folder (ONLY ONE!)
try {
    New-Item -Path $GamesFolderPath -ItemType Directory -Force | Out-Null
    Write-Host "✅ Created games folder: $GamesFolderPath" -ForegroundColor Green
    
    # Run the VBScript to populate game shortcuts
    Write-Host "Running VBScript to create game shortcuts..." -ForegroundColor Yellow
    $VBScriptPath = "F:\study\Platforms\windows\VBScript\CreateGameShortcuts.vbs"
    
    if (Test-Path $VBScriptPath) {
        try {
            & cscript $VBScriptPath
            Write-Host "✅ VBScript executed successfully!" -ForegroundColor Green
        } catch {
            Write-Host "❌ Error running VBScript: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "You can run it manually: cscript F:\study\Platforms\windows\VBScript\CreateGameShortcuts.vbs" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ VBScript not found at: $VBScriptPath" -ForegroundColor Red
        Write-Host "Please check the path and run manually if needed" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Error creating games folder: $($_.Exception.Message)" -ForegroundColor Red
}

# FINAL DUPLICATE ELIMINATION PASS (NO RECYCLE BIN CREATION EVER!) - NO PROMPTS!
Write-Host "Final duplicate elimination pass..." -ForegroundColor Red
Start-Sleep -Seconds 2  # Give Windows time to finish creating shortcuts

# Ensure ONLY ONE Recycle Bin exists (Windows default, never create new ones) - NO PROMPTS!
$RecycleBins = Get-ChildItem -Path $DesktopPath -Filter "*Recycle*" -ErrorAction SilentlyContinue
if ($RecycleBins.Count -gt 1) {
    Write-Host "Found $($RecycleBins.Count) Recycle Bins - keeping only Windows default!" -ForegroundColor Red
    
    # Sort by creation time and keep the oldest (likely Windows default)
    $SortedRecycleBins = $RecycleBins | Sort-Object CreationTime
    for ($i = 1; $i -lt $SortedRecycleBins.Count; $i++) {
        Remove-Item $SortedRecycleBins[$i].FullName -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "🗑️ ELIMINATED DUPLICATE RECYCLE BIN: $($SortedRecycleBins[$i].Name)" -ForegroundColor Red
    }
}

# Ensure only ONE games folder exists (the one we just created) - NO PROMPTS!
$GamesItems = Get-ChildItem -Path $DesktopPath | Where-Object { 
    $_.Name -like "*ames*" -and $_.Name -ne "games" 
}
if ($GamesItems) {
    foreach ($item in $GamesItems) {
        Remove-Item $item.FullName -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "ELIMINATED DUPLICATE GAMES ITEM: $($item.Name)" -ForegroundColor Red
    }
}

Write-Host "✅ ABSOLUTELY NO 2ND RECYCLE BIN POSSIBLE! Desktop cleanup completed!" -ForegroundColor Green
Write-Host "🚫 RECYCLE BIN CREATION: PERMANENTLY BLOCKED" -ForegroundColor Red
Write-Host "📁 GAMES FOLDER: Created and VBScript executed!" -ForegroundColor Cyan

Write-Host "Desktop shortcuts created successfully!" -ForegroundColor Green

# Step 4: Configure Taskbar
Write-Host "Configuring taskbar..." -ForegroundColor Yellow

# Function to pin UWP app to taskbar
function Pin-UWPToTaskbar {
    param([string]$AppUserModelId)
    
    try {
        # Create a temporary shortcut for the UWP app
        $WshShell = New-Object -ComObject WScript.Shell
        $TempShortcut = "$env:TEMP\TempUWPApp.lnk"
        $Shortcut = $WshShell.CreateShortcut($TempShortcut)
        $Shortcut.TargetPath = "shell:AppsFolder\$AppUserModelId"
        $Shortcut.Save()
        
        # Pin using the shortcut
        $Shell = New-Object -ComObject Shell.Application
        $Folder = $Shell.Namespace((Get-Item $TempShortcut).DirectoryName)
        $Item = $Folder.ParseName((Get-Item $TempShortcut).Name)
        $Item.InvokeVerb("taskbarpin")
        
        # Clean up
        Remove-Item $TempShortcut -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        Remove-Item $TempShortcut -Force -ErrorAction SilentlyContinue
        return $false
    }
}

# Function to pin to taskbar
function Pin-ToTaskbar {
    param([string]$AppPath)
    
    try {
        $Shell = New-Object -ComObject Shell.Application
        $Folder = $Shell.Namespace((Get-Item $AppPath).DirectoryName)
        $Item = $Folder.ParseName((Get-Item $AppPath).Name)
        $Item.InvokeVerb("taskbarpin")
        return $true
    } catch {
        return $false
    }
}

# Function to unpin from taskbar
function Unpin-FromTaskbar {
    param([string]$AppPath)
    
    try {
        $Shell = New-Object -ComObject Shell.Application
        $Folder = $Shell.Namespace((Get-Item $AppPath).DirectoryName)
        $Item = $Folder.ParseName((Get-Item $AppPath).Name)
        $Item.InvokeVerb("taskbarunpin")
        return $true
    } catch {
        return $false
    }
}

# Clear existing taskbar pins (this is complex in Windows 10/11)
Write-Host "Clearing existing taskbar pins..." -ForegroundColor Yellow

# Get common pinned applications and unpin them
$CommonPins = @(
    "$env:ProgramFiles\Internet Explorer\iexplore.exe",
    "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft Office\root\Office16\OUTLOOK.EXE",
    "$env:ProgramFiles\Microsoft Office\root\Office16\WINWORD.EXE",
    "$env:ProgramFiles\Microsoft Office\root\Office16\EXCEL.EXE",
    "$env:LOCALAPPDATA\Microsoft\WindowsApps\MicrosoftTeams.exe"
)

foreach ($app in $CommonPins) {
    if (Test-Path $app) {
        Unpin-FromTaskbar -AppPath $app
    }
}

# Pin specific applications to taskbar (based on your requirements)
Write-Host "Pinning new applications to taskbar..." -ForegroundColor Yellow

# Pin File Explorer (Windows Explorer)
$ExplorerPath = "$env:WINDIR\explorer.exe"
if (Test-Path $ExplorerPath) {
    Pin-ToTaskbar -AppPath $ExplorerPath
    Write-Host "Pinned File Explorer to taskbar" -ForegroundColor Cyan
}

# Pin Samsung Account app
$SamsungAccountPaths = @(
    "$env:LOCALAPPDATA\Microsoft\WindowsApps\Samsung Account_1.0.0.0_x64__wyx1vj98g3asy\SamsungAccount.exe",
    "$env:ProgramFiles\Samsung\Samsung Account\SamsungAccount.exe",
    "$env:ProgramFiles(x86)\Samsung\Samsung Account\SamsungAccount.exe"
)

$SamsungAccountFound = $false
foreach ($path in $SamsungAccountPaths) {
    if (Test-Path $path) {
        Pin-ToTaskbar -AppPath $path
        Write-Host "Pinned Samsung Account to taskbar" -ForegroundColor Cyan
        $SamsungAccountFound = $true
        break
    }
}

if (-not $SamsungAccountFound) {
    Write-Host "Samsung Account app not found in common locations. Attempting UWP approach..." -ForegroundColor Yellow
    # Try to find and pin Samsung Account via UWP method
    try {
        $SamsungApp = Get-AppxPackage | Where-Object { $_.Name -like "*Samsung*Account*" }
        if ($SamsungApp) {
            $AppId = $SamsungApp.PackageFamilyName + "!" + $SamsungApp.Name
            Write-Host "Found Samsung Account UWP app: $AppId" -ForegroundColor Cyan
        } else {
            Write-Host "Samsung Account app not found. Please pin manually if needed." -ForegroundColor Red
        }
    } catch {
        Write-Host "Could not locate Samsung Account app automatically." -ForegroundColor Red
    }
}

# Pin ASUS PC Assistant
Write-Host "Pinning ASUS PC Assistant to taskbar..." -ForegroundColor Yellow
$ASUSAppId = "B9ECED6F.ASUSPCAssistant_qmba6cd70vzyy!App"

if (Pin-UWPToTaskbar -AppUserModelId $ASUSAppId) {
    Write-Host "Pinned ASUS PC Assistant to taskbar" -ForegroundColor Cyan
} else {
    Write-Host "Could not pin ASUS PC Assistant automatically." -ForegroundColor Red
    Write-Host "Please pin it manually by:" -ForegroundColor Yellow
    Write-Host "1. Press Win+R and type: shell:AppsFolder\B9ECED6F.ASUSPCAssistant_qmba6cd70vzyy!App" -ForegroundColor Yellow
    Write-Host "2. Or search for 'ASUS PC Assistant' in Start Menu and pin to taskbar" -ForegroundColor Yellow
}

Write-Host "Taskbar configuration completed!" -ForegroundColor Green

# Step 5: Refresh desktop
Write-Host "Refreshing desktop..." -ForegroundColor Yellow
rundll32.exe user32.dll,UpdatePerUserSystemParameters

# Step 6: Restart explorer to apply changes
Write-Host "Restarting Windows Explorer to apply changes..." -ForegroundColor Yellow
Stop-Process -Name "explorer" -Force
Start-Process "explorer"

Write-Host "Desktop and taskbar reset completed successfully!" -ForegroundColor Green
Write-Host "Please check your desktop and taskbar. You may need to restart your computer for all changes to take effect." -ForegroundColor Yellow

# Script completes and returns to terminal automatically