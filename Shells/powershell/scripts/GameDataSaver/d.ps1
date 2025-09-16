# Enhanced Game Save Backup/Restore Script with Comprehensive Search
# History file to remember previous games
$historyFile = "$env:USERPROFILE\.gamesave_history.json"

# Function to load history
function Get-GameHistory {
    if (Test-Path $historyFile) {
        try {
            $content = Get-Content $historyFile -Raw | ConvertFrom-Json
            return $content
        } catch {
            return @{ backups = @(); restores = @() }
        }
    } else {
        return @{ backups = @(); restores = @() }
    }
}

# Function to save history
function Save-GameHistory {
    param($history)
    $history | ConvertTo-Json -Depth 3 | Set-Content $historyFile
}

# Function to add game to history (always keep exactly 10 items)
function Add-ToHistory {
    param($gameName, $action)
    $history = Get-GameHistory
    
    if ($action -eq 'backup') {
        $history.backups = @($gameName) + ($history.backups | Where-Object { $_ -ne $gameName })
        $history.backups = $history.backups[0..([Math]::Min($history.backups.Count - 1, 9))]
    } else {
        $history.restores = @($gameName) + ($history.restores | Where-Object { $_ -ne $gameName })
        $history.restores = $history.restores[0..([Math]::Min($history.restores.Count - 1, 9))]
    }
    
    Save-GameHistory $history
}

# Function to display suggestions
function Show-Suggestions {
    param($action)
    $history = Get-GameHistory
    
    $suggestions = if ($action -eq 'backup') { $history.backups } else { $history.restores }
    
    if ($suggestions -and $suggestions.Count -gt 0) {
        Write-Host "`nRecent ${action}s:" -ForegroundColor Cyan
        for ($i = 0; $i -lt [Math]::Min($suggestions.Count, 5); $i++) {
            Write-Host "  $($i + 1). $($suggestions[$i])" -ForegroundColor Yellow
        }
        Write-Host ""
    }
}

# Comprehensive game save folder search function
function Find-GameSaveFolder {
    param($gameName)
    
    Write-Host "Searching for '$gameName' save files..." -ForegroundColor Cyan
    
    # Define all possible base locations where games store saves
    $baseLocations = @(
        $env:APPDATA,                          # Roaming
        $env:LOCALAPPDATA,                     # Local
        "$env:APPDATA\..\LocalLow",            # LocalLow
        "$env:USERPROFILE\Documents",          # Documents
        "$env:USERPROFILE\Saved Games",        # Saved Games
        "$env:USERPROFILE\Documents\My Games", # My Games  
        "$env:PROGRAMDATA",                    # ProgramData
        "$env:USERPROFILE\AppData"             # AppData root
    )
    
    $foundPaths = @()
    
    # Search method 1: Direct folder name matches
    Write-Host "Phase 1: Searching for exact folder matches..." -ForegroundColor Gray
    foreach ($baseLocation in $baseLocations) {
        if (Test-Path $baseLocation) {
            # Direct match in base location
            $directPath = Join-Path $baseLocation $gameName
            if (Test-Path $directPath) {
                $foundPaths += [PSCustomObject]@{
                    Path = $directPath
                    Score = 5
                    Type = "Direct match"
                }
                Write-Host "  Found: $directPath" -ForegroundColor Green
            }
            
            # Search in publisher subfolders (one level deep)
            try {
                Get-ChildItem $baseLocation -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                    $publisherFolder = $_.FullName
                    $gameInPublisher = Join-Path $publisherFolder $gameName
                    if (Test-Path $gameInPublisher) {
                        $foundPaths += [PSCustomObject]@{
                            Path = $gameInPublisher
                            Score = 4
                            Type = "In publisher folder"
                        }
                        Write-Host "  Found: $gameInPublisher" -ForegroundColor Green
                    }
                }
            } catch { }
        }
    }
    
    # Search method 2: Case-insensitive and partial matches
    if ($foundPaths.Count -eq 0) {
        Write-Host "Phase 2: Searching for case-insensitive matches..." -ForegroundColor Gray
        foreach ($baseLocation in $baseLocations) {
            if (Test-Path $baseLocation) {
                try {
                    # Search direct folders
                    Get-ChildItem $baseLocation -Directory -ErrorAction SilentlyContinue | Where-Object { 
                        $_.Name -like "*$gameName*" -or $_.Name -match [regex]::Escape($gameName) 
                    } | ForEach-Object {
                        $foundPaths += [PSCustomObject]@{
                            Path = $_.FullName
                            Score = 3
                            Type = "Partial match"
                        }
                        Write-Host "  Found: $($_.FullName)" -ForegroundColor Yellow
                    }
                    
                    # Search in publisher subfolders
                    Get-ChildItem $baseLocation -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                        $publisherPath = $_.FullName
                        try {
                            Get-ChildItem $publisherPath -Directory -ErrorAction SilentlyContinue | Where-Object { 
                                $_.Name -like "*$gameName*" -or $_.Name -match [regex]::Escape($gameName) 
                            } | ForEach-Object {
                                $foundPaths += [PSCustomObject]@{
                                    Path = $_.FullName
                                    Score = 2
                                    Type = "Partial match in publisher folder"
                                }
                                Write-Host "  Found: $($_.FullName)" -ForegroundColor Yellow
                            }
                        } catch { }
                    }
                } catch { }
            }
        }
    }
    
    # Search method 3: Manual browse option
    if ($foundPaths.Count -eq 0) {
        Write-Host "`nNo automatic matches found for '$gameName'" -ForegroundColor Red
        Write-Host "Would you like to browse manually? (y/n)" -ForegroundColor Yellow
        $browse = Read-Host
        
        if ($browse -eq 'y' -or $browse -eq 'Y') {
            Write-Host "`nCommon game save locations to check manually:" -ForegroundColor Cyan
            $baseLocations | ForEach-Object { 
                if (Test-Path $_) {
                    Write-Host "  $_" -ForegroundColor Gray
                }
            }
            Write-Host "`nPlease enter the full path to your game's save folder:" -ForegroundColor Yellow
            $manualPath = Read-Host
            
            if ([string]::IsNullOrWhiteSpace($manualPath)) {
                return $null
            }
            
            if (Test-Path $manualPath) {
                return $manualPath
            } else {
                Write-Host "Path not found: $manualPath" -ForegroundColor Red
                return $null
            }
        } else {
            return $null
        }
    }
    
    if ($foundPaths.Count -eq 0) {
        return $null
    }
    
    # Simple duplicate removal by path string
    $uniquePaths = @{}
    foreach ($pathObj in $foundPaths) {
        $key = $pathObj.Path.ToLower().TrimEnd('\')
        if (-not $uniquePaths.ContainsKey($key) -or $uniquePaths[$key].Score -lt $pathObj.Score) {
            $uniquePaths[$key] = $pathObj
        }
    }
    
    # Convert back to array and sort by score
    $finalPaths = $uniquePaths.Values | Sort-Object Score -Descending
    
    if ($finalPaths.Count -eq 1) {
        $selectedPath = $finalPaths[0]
        Write-Host "✅ Auto-selected: $($selectedPath.Path)" -ForegroundColor Green
        Write-Host "   Type: $($selectedPath.Type)" -ForegroundColor Gray
        return $selectedPath.Path
    } else {
        # Multiple unique paths - auto-select the highest scoring one
        $bestPath = $finalPaths[0]
        Write-Host "✅ Auto-selected (highest score): $($bestPath.Path)" -ForegroundColor Green
        Write-Host "   Reason: Score $($bestPath.Score) - $($bestPath.Type)" -ForegroundColor Gray
        return $bestPath.Path
    }
    
    return $null
}

# Clear screen for better presentation
Clear-Host
Write-Host "=== Enhanced Game Save Backup/Restore Tool ===" -ForegroundColor Magenta
Write-Host ""

# Ask for action first to determine which suggestions to show
do {
    $action = Read-Host "Type 'b' for backup or 'r' for restore"
    $actionLower = $action.ToLower()
} while ($actionLower -ne 'b' -and $actionLower -ne 'r' -and $actionLower -ne 'backup' -and $actionLower -ne 'restore')

# Normalize action
$normalizedAction = switch ($actionLower) {
    'b' { 'backup' }
    'r' { 'restore' }
    default { $actionLower }
}

# Show suggestions based on action
Show-Suggestions $normalizedAction

# Prompt for game name with suggestions
$game = Read-Host "Enter the name of the game (case-sensitive folder name)"

# Check if user entered a number to select from suggestions
$history = Get-GameHistory
$suggestions = if ($normalizedAction -eq 'backup') { $history.backups } else { $history.restores }

if ($game -match '^\d+$' -and $suggestions -and [int]$game -le $suggestions.Count -and [int]$game -gt 0) {
    $game = $suggestions[[int]$game - 1]
    Write-Host "Selected: $game" -ForegroundColor Green
}

# Use comprehensive search function
$savePath = Find-GameSaveFolder $game

if (-not $savePath) {
    Write-Host "Could not find or select save folder for '$game'" -ForegroundColor Red
    pause
    exit 1
}

# Set base backup location
$backupBase = "F:\backup\gamesaves\$game"

# Perform selected action
switch ($normalizedAction) {
    'backup' {
        Write-Host "`nCreating backup..." -ForegroundColor Cyan
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $dest = Join-Path $backupBase $timestamp
        
        try {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            Copy-Item $savePath -Destination $dest -Recurse -Force
            
            # Add to history
            Add-ToHistory $game 'backup'
            
            Write-Host "✅ Backup completed to $dest" -ForegroundColor Green
            Write-Host "Size: $([math]::Round((Get-ChildItem $dest -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 2)) MB" -ForegroundColor Gray
        } catch {
            Write-Host "❌ Backup failed: $_" -ForegroundColor Red
        }
    }
    'restore' {
        if (-not (Test-Path $backupBase)) {
            Write-Host "❌ No backups found for '$game'" -ForegroundColor Red
            pause
            exit 1
        }
        
        # Show available backups
        $backups = Get-ChildItem $backupBase | Sort-Object LastWriteTime -Descending
        if (-not $backups) {
            Write-Host "❌ No backups available to restore" -ForegroundColor Red
            pause
            exit 1
        }
        
        Write-Host "`nAvailable backups:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $backups.Count; $i++) {
            $backup = $backups[$i]
            $size = [math]::Round((Get-ChildItem $backup.FullName -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
            Write-Host "  $($i + 1). $($backup.Name) (${size} MB) - $($backup.LastWriteTime)" -ForegroundColor Yellow
        }
        
        $selection = Read-Host "`nSelect backup number (or press Enter for latest)"
        
        if ([string]::IsNullOrWhiteSpace($selection)) {
            $selectedBackup = $backups[0]
        } elseif ($selection -match '^\d+$' -and [int]$selection -le $backups.Count -and [int]$selection -gt 0) {
            $selectedBackup = $backups[[int]$selection - 1]
        } else {
            Write-Host "❌ Invalid selection" -ForegroundColor Red
            pause
            exit 1
        }
        
        Write-Host "Restoring from: $($selectedBackup.Name)" -ForegroundColor Cyan
        
        try {
            # Create backup of current saves before restore
            $preRestoreBackup = Join-Path $backupBase "pre-restore_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
            New-Item -ItemType Directory -Path $preRestoreBackup -Force | Out-Null
            Copy-Item $savePath -Destination $preRestoreBackup -Recurse -Force
            Write-Host "Current saves backed up to: $preRestoreBackup" -ForegroundColor Gray
            
            # Perform restore - delete all contents INSIDE the game save folder
            Write-Host "Deleting all contents inside: $savePath" -ForegroundColor Yellow
            Remove-Item "$savePath\*" -Recurse -Force -ErrorAction SilentlyContinue
            
            # Find the game folder inside the backup (e.g., game folder inside the timestamp folder)
            $backupGameFolder = Join-Path $selectedBackup.FullName $game
            if (-not (Test-Path $backupGameFolder)) {
                Write-Host "ERROR: Could not find game folder '$game' inside backup!" -ForegroundColor Red
                Write-Host "Backup contents:" -ForegroundColor Yellow
                Get-ChildItem $selectedBackup.FullName | ForEach-Object { Write-Host "  $($_.Name)" }
                throw "Backup structure mismatch"
            }
            
            Write-Host "Copying from: $backupGameFolder\*" -ForegroundColor Cyan
            Write-Host "Copying to: $savePath" -ForegroundColor Cyan
            Copy-Item "$backupGameFolder\*" -Destination $savePath -Recurse -Force
            
            # Add to history
            Add-ToHistory $game 'restore'
            
            Write-Host "✅ Perfect restore completed!" -ForegroundColor Green
            Write-Host "Restored contents from: $backupGameFolder" -ForegroundColor Gray
            Write-Host "Restored contents to: $savePath" -ForegroundColor Gray
        } catch {
            Write-Host "❌ Restore failed: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")