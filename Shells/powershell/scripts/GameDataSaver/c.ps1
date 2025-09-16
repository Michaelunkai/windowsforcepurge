# Enhanced Game Save Backup/Restore Script with Memory and Suggestions
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

# Clear screen for better presentation
Clear-Host
Write-Host "=== Game Save Backup/Restore Tool ===" -ForegroundColor Magenta
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

# Expanded search paths to handle publisher subfolders
$locations = @(
    "$env:APPDATA\$game",
    "$env:LOCALAPPDATA\$game",
    "$env:APPDATA\..\LocalLow\$game",
    "$env:USERPROFILE\Documents\$game",
    "$env:USERPROFILE\Saved Games\$game",
    "$env:APPDATA\*\$game",
    "$env:LOCALAPPDATA\*\$game",
    "$env:APPDATA\..\LocalLow\*\$game",
    "$env:USERPROFILE\Documents\*\$game",
    "$env:USERPROFILE\Saved Games\*\$game"
)

Write-Host "Searching for save files..." -ForegroundColor Cyan

# Try to find the correct game save path with improved logic
$savePath = $null
$foundPaths = @()

# First pass: collect all potential matches
foreach ($pattern in $locations) {
    Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_ -ne $null -and $_.Name -ieq $game) {
            $foundPaths += $_.FullName
        }
    }
}

if ($foundPaths.Count -eq 0) {
    # No matches found
    $savePath = $null
} elseif ($foundPaths.Count -eq 1) {
    # Only one match, use it
    $savePath = $foundPaths[0]
} else {
    # Multiple matches found - prioritize the one that looks most like actual save data
    Write-Host "Multiple potential save locations found:" -ForegroundColor Yellow
    
    $bestMatch = $null
    $bestScore = -1
    
    for ($i = 0; $i -lt $foundPaths.Count; $i++) {
        $path = $foundPaths[$i]
        $score = 0
        
        # Check for common save file indicators
        $items = Get-ChildItem $path -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            if ($item.Name -match "save|slot|profile|user|data|config") { $score += 3 }
            if ($item.Extension -match "\.(sav|dat|json|xml|bin|save)$") { $score += 2 }
            if ($item.Name -match "Unity") { $score += 1 }
        }
        
        Write-Host "  $($i + 1). $path (Score: $score)" -ForegroundColor Gray
        
        if ($score -gt $bestScore) {
            $bestScore = $score
            $bestMatch = $path
        }
    }
    
    if ($bestMatch) {
        $savePath = $bestMatch
        Write-Host "Auto-selected best match: $savePath" -ForegroundColor Green
    } else {
        # Let user choose manually
        Write-Host "Could not determine best save location automatically." -ForegroundColor Yellow
        $choice = Read-Host "Enter the number of the correct save location (1-$($foundPaths.Count))"
        
        if ($choice -match '^\d+$' -and [int]$choice -le $foundPaths.Count -and [int]$choice -gt 0) {
            $savePath = $foundPaths[[int]$choice - 1]
        } else {
            Write-Host "Invalid selection" -ForegroundColor Red
            pause
            exit 1
        }
    }
}

if ($savePath) {
    Write-Host "Using save folder: $savePath" -ForegroundColor Green
}

if (-not $savePath) {
    Write-Host "Could not find save folder for '$game'" -ForegroundColor Red
    Write-Host "Common locations searched:" -ForegroundColor Yellow
    $locations | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
    pause
    exit 1
}

# Set base backup location
$backupBase = "F:\backup\gamesaves\$game"

# Perform selected action
switch ($normalizedAction) {
    'backup' {
        Write-Host "Creating backup..." -ForegroundColor Cyan
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $dest = Join-Path $backupBase $timestamp
        
        try {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            Copy-Item $savePath -Destination $dest -Recurse -Force
            
            # Add to history
            Add-ToHistory $game 'backup'
            
            Write-Host "Backup completed to $dest" -ForegroundColor Green
            Write-Host "Size: $([math]::Round((Get-ChildItem $dest -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 2)) MB" -ForegroundColor Gray
        } catch {
            Write-Host "Backup failed: $_" -ForegroundColor Red
        }
    }
    'restore' {
        if (-not (Test-Path $backupBase)) {
            Write-Host "No backups found for '$game'" -ForegroundColor Red
            pause
            exit 1
        }
        
        # Show available backups
        $backups = Get-ChildItem $backupBase | Sort-Object LastWriteTime -Descending
        if (-not $backups) {
            Write-Host "No backups available to restore" -ForegroundColor Red
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
            Write-Host "Invalid selection" -ForegroundColor Red
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
            
            # Find the game folder inside the backup (e.g., NineSols folder inside the timestamp folder)
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
            
            Write-Host "Perfect restore completed!" -ForegroundColor Green
            Write-Host "Restored contents from: $backupGameFolder" -ForegroundColor Gray
            Write-Host "Restored contents to: $savePath" -ForegroundColor Gray
        } catch {
            Write-Host "Restore failed: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")