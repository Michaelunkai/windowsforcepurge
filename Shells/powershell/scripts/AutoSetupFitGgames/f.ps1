# === Watch-GameSetup-and-AHK-Enhanced-PersistentTracking.ps1 ===
$watchDir = "F:\Downloads"
$gamesDir = "F:\games"
$ahkPath = "F:\study\shells\powershell\scripts\AutoSetupFitGgames\b.ahk"
$ahkScriptName = "b.ahk"
$maxConcurrentSetups = 3

# Persistent tracking file to ensure no setup runs twice EVER
$trackingFile = "F:\study\shells\powershell\scripts\AutoSetupFitGgames\completed_installations.json"
$currentSessionSetups = @{}  # Track current session only
$completedInstallations = @{}  # Persistent tracking across all sessions

function Initialize-Persistent-Tracking {
    Write-Host "[Tracking] Initializing persistent installation tracking system..."
    
    # Create tracking directory if it doesn't exist
    $trackingDir = Split-Path $trackingFile -Parent
    if (-not (Test-Path $trackingDir)) {
        New-Item -ItemType Directory -Path $trackingDir -Force | Out-Null
        Write-Host "[Tracking] Created tracking directory: $trackingDir"
    }
    
    # Load existing completed installations
    if (Test-Path $trackingFile) {
        try {
            $jsonContent = Get-Content $trackingFile -Raw -ErrorAction Stop
            $loadedData = $jsonContent | ConvertFrom-Json -ErrorAction Stop
            
            # Convert PSCustomObject properties to hashtable
            $script:completedInstallations = @{}
            $loadedData.PSObject.Properties | ForEach-Object {
                $script:completedInstallations[$_.Name] = $_.Value
            }
            
            Write-Host "[Tracking] Loaded $($completedInstallations.Count) previously completed installations"
            
            # Display some examples of tracked installations
            if ($completedInstallations.Count -gt 0) {
                Write-Host "[Tracking] Examples of completed installations:"
                $completedInstallations.Keys | Select-Object -First 5 | ForEach-Object {
                    $fileName = [System.IO.Path]::GetFileName($_)
                    $completedTime = $completedInstallations[$_]
                    Write-Host "  - $fileName (completed: $completedTime)"
                }
                if ($completedInstallations.Count -gt 5) {
                    Write-Host "  - ... and $($completedInstallations.Count - 5) more"
                }
            }
        }
        catch {
            Write-Host "[Warning] Could not load tracking file. Starting fresh. Error: $($_.Exception.Message)"
            $script:completedInstallations = @{}
        }
    } else {
        Write-Host "[Tracking] No existing tracking file found. Starting fresh tracking system."
        $script:completedInstallations = @{}
    }
}

function Save-Persistent-Tracking {
    try {
        $script:completedInstallations | ConvertTo-Json -Depth 10 | Set-Content $trackingFile -Encoding UTF8
        Write-Host "[Tracking] Successfully saved tracking data ($($completedInstallations.Count) entries)"
    }
    catch {
        Write-Host "[Error] Failed to save tracking data: $($_.Exception.Message)"
    }
}

function Add-Completed-Installation {
    param($setupPath)
    
    $normalizedPath = [System.IO.Path]::GetFullPath($setupPath).ToLower()
    $completionTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Add to persistent tracking
    $script:completedInstallations[$normalizedPath] = $completionTime
    
    # Save immediately to prevent data loss
    Save-Persistent-Tracking
    
    $fileName = [System.IO.Path]::GetFileName($setupPath)
    Write-Host "[Tracking] ✓ Permanently marked as completed: $fileName"
}

function Is-Installation-Completed {
    param($setupPath)
    
    $normalizedPath = [System.IO.Path]::GetFullPath($setupPath).ToLower()
    return $script:completedInstallations.ContainsKey($normalizedPath)
}

function Get-Installation-Fingerprint {
    param($setupFile)
    
    try {
        # Create a unique fingerprint based on file path, size, and last write time
        $path = $setupFile.FullName.ToLower()
        $size = $setupFile.Length
        $lastWrite = $setupFile.LastWriteTime.ToString("yyyy-MM-dd-HH-mm-ss")
        
        return "$path|$size|$lastWrite"
    }
    catch {
        # Fallback to just the path if file properties can't be read
        return $setupFile.FullName.ToLower()
    }
}

function Is-Installation-Completed-By-Fingerprint {
    param($setupFile)
    
    $fingerprint = Get-Installation-Fingerprint -setupFile $setupFile
    return $script:completedInstallations.ContainsKey($fingerprint)
}

function Add-Completed-Installation-By-Fingerprint {
    param($setupFile)
    
    $fingerprint = Get-Installation-Fingerprint -setupFile $setupFile
    $completionTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Add to persistent tracking
    $script:completedInstallations[$fingerprint] = $completionTime
    
    # Save immediately
    Save-Persistent-Tracking
    
    Write-Host "[Tracking] ✓ Permanently marked as completed: $($setupFile.Name) [Fingerprint: $($fingerprint.Substring(0, 50))...]"
}

function Ensure-Single-AHK-Running {
    # Find all AutoHotkey processes running our specific script
    $ahkProcesses = Get-Process | Where-Object {
        $_.ProcessName -like "*AutoHotkey*"
    } -ErrorAction SilentlyContinue

    # Alternative method using WMI for better command line detection
    if ($ahkProcesses) {
        $specificAhkProcesses = Get-WmiObject Win32_Process | Where-Object {
            $_.Name -like "*AutoHotkey*" -and
            $_.CommandLine -like "*$([System.IO.Path]::GetFileName($ahkPath))*"
        } -ErrorAction SilentlyContinue
    }

    if ($specificAhkProcesses -and $specificAhkProcesses.Count -gt 1) {
        Write-Host "[AHK] Multiple AutoHotkey instances detected. Terminating extras..."
        $specificAhkProcesses | Select-Object -Skip 1 | ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Host "[AHK] Terminated extra process ID: $($_.ProcessId)"
        }
    }

    if (-not $specificAhkProcesses -or $specificAhkProcesses.Count -eq 0) {
        if (Test-Path $ahkPath) {
            Write-Host "[AHK] No AutoHotkey instance running. Starting $ahkScriptName..."
            Start-Process -FilePath $ahkPath -WindowStyle Hidden
            Start-Sleep -Seconds 3  # Give it time to start
            Write-Host "[AHK] $ahkScriptName started"
        } else {
            Write-Host "[AHK] Warning: AHK script not found at $ahkPath"
        }
    } else {
        Write-Host "[AHK] Single AutoHotkey instance confirmed running"
    }
}

function Get-Running-Setup-Count {
    # Count currently running setup.exe processes
    $runningSetups = Get-Process | Where-Object { $_.ProcessName -eq "setup" } -ErrorAction SilentlyContinue
    return $runningSetups.Count
}

function Remove-Completed-Session-Setups {
    # Clean up tracking for setups that are no longer running (current session only)
    $completedSetups = @()
    foreach ($setupPath in $currentSessionSetups.Keys) {
        $isStillRunning = Get-Process | Where-Object {
            $_.ProcessName -eq "setup" -and
            $_.MainModule.FileName -eq $setupPath
        } -ErrorAction SilentlyContinue

        if (-not $isStillRunning) {
            $completedSetups += $setupPath
            # Mark as permanently completed
            Add-Completed-Installation -setupPath $setupPath
        }
    }

    # Remove completed setups from current session tracking
    foreach ($completed in $completedSetups) {
        $currentSessionSetups.Remove($completed)
        Write-Host "[Session] Removed completed setup from session tracking: $([System.IO.Path]::GetFileName($completed))"
    }
}

function Is-File-Ready-And-Stable {
    param($file)
    
    try {
        # Check if file exists and is not zero bytes
        if (-not $file.Exists -or $file.Length -eq 0) {
            return $false
        }
        
        # Try to open exclusively to see if it's being written to
        $stream = $file.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
        $stream.Close()
        
        # Additional stability check - compare file size after a short delay
        $initialSize = $file.Length
        Start-Sleep -Milliseconds 500
        $file.Refresh()
        $currentSize = $file.Length
        
        return ($initialSize -eq $currentSize)
        
    } catch {
        return $false
    }
}

function Launch-Setup-If-Possible {
    param($setupFile)

    # CRITICAL: Check if this installation has EVER been completed
    if (Is-Installation-Completed-By-Fingerprint -setupFile $setupFile) {
        Write-Host "[BLOCKED] ❌ Installation already completed previously: $($setupFile.Name)"
        Write-Host "[BLOCKED] This setup will NEVER run again to prevent duplicate installations"
        return $false
    }

    # Check if already launched in current session
    if ($currentSessionSetups.ContainsKey($setupFile.FullName)) {
        Write-Host "[Session] Setup already launched in current session: $($setupFile.Name)"
        return $false
    }

    $currentRunning = Get-Running-Setup-Count

    if ($currentRunning -ge $maxConcurrentSetups) {
        Write-Host "[Limit] Cannot launch setup - already running $currentRunning/$maxConcurrentSetups setups"
        return $false
    }

    # Check if file is ready and stable
    if (-not (Is-File-Ready-And-Stable -file $setupFile)) {
        Write-Host "[Launch] $($setupFile.Name) is still being written or not stable. Will try again later..."
        return $false
    }

    try {
        # File is ready, launch it
        Write-Host "[Launch] 🚀 Starting $($setupFile.Name) (will be $($currentRunning + 1)/$maxConcurrentSetups)"
        Start-Process -FilePath $setupFile.FullName -ErrorAction Stop
        
        # Add to current session tracking
        $currentSessionSetups[$setupFile.FullName] = Get-Date
        
        Write-Host "[Launch] ✓ Successfully launched and added to session tracking"
        Write-Host "[Launch] This installation will be permanently tracked upon completion"
        return $true

    } catch {
        Write-Host "[Launch] ❌ Failed to launch $($setupFile.Name): $($_.Exception.Message)"
        return $false
    }
}

function Show-System-Statistics {
    Write-Host "`n[Statistics] System Overview:"
    Write-Host "  • Total completed installations (all time): $($completedInstallations.Count)"
    Write-Host "  • Current session launches: $($currentSessionSetups.Count)"
    Write-Host "  • Currently running setups: $(Get-Running-Setup-Count)/$maxConcurrentSetups"
    
    # Show tracking file size
    if (Test-Path $trackingFile) {
        $fileSize = (Get-Item $trackingFile).Length
        Write-Host "  • Tracking file size: $fileSize bytes"
    }
}

# === MAIN EXECUTION ===

Write-Host "================================================================"
Write-Host "🎮 Enhanced Game Setup Watcher v3.0 - PERSISTENT TRACKING 🎮"
Write-Host "================================================================"
Write-Host "[Config] Watch Directory: $watchDir"
Write-Host "[Config] Games Directory: $gamesDir"
Write-Host "[Config] AHK Script: $ahkPath"
Write-Host "[Config] Max Concurrent Setups: $maxConcurrentSetups"
Write-Host "[Config] Tracking File: $trackingFile"
Write-Host "================================================================"

# Initialize persistent tracking system
Initialize-Persistent-Tracking

# Ensure AHK is running first before starting the watcher
Write-Host "[Startup] Ensuring single AHK script instance is running..."
Ensure-Single-AHK-Running

Write-Host "[Watcher] Starting monitoring for setup.exe files..."
Write-Host "[Watcher] Scan interval: 60 seconds"
Write-Host "[Important] ⚠️  NO SETUP WILL EVER RUN TWICE - PERMANENT TRACKING ACTIVE ⚠️"
Write-Host "================================================================"

$scanCount = 0

# Show initial statistics
Show-System-Statistics

while ($true) {
    $scanCount++
    Write-Host "`n[Scan #$scanCount] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking system status..."

    # Ensure only one AHK instance is running
    Ensure-Single-AHK-Running

    # Clean up completed setups from session tracking and mark as permanently completed
    Remove-Completed-Session-Setups

    # Get current system status
    $currentRunning = Get-Running-Setup-Count
    Write-Host "[Status] Currently running setups: $currentRunning/$maxConcurrentSetups"
    Write-Host "[Status] Session launches: $($currentSessionSetups.Count) | Total completed: $($completedInstallations.Count)"

    # Only look for new setups if we have capacity
    if ($currentRunning -lt $maxConcurrentSetups) {
        # Find all setup.exe files in Downloads directory
        $allSetupFiles = Get-ChildItem -Path $watchDir -Filter "setup.exe" -Recurse -File -ErrorAction SilentlyContinue
        Write-Host "[Scan] Found $($allSetupFiles.Count) setup.exe file(s) total in watch directory"

        if ($allSetupFiles.Count -gt 0) {
            # Filter out already completed installations (PERMANENT BLOCK)
            $neverCompletedFiles = $allSetupFiles | Where-Object { -not (Is-Installation-Completed-By-Fingerprint -setupFile $_) }
            Write-Host "[Filter] After permanent completion filter: $($neverCompletedFiles.Count) eligible files"
            
            # Filter out current session launches
            $newSetupFiles = $neverCompletedFiles | Where-Object { -not $currentSessionSetups.ContainsKey($_.FullName) }
            Write-Host "[Filter] After session filter: $($newSetupFiles.Count) new files for this session"

            if ($newSetupFiles.Count -gt 0) {
                # Sort by most recent and try to launch one
                $setupFile = $newSetupFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                Write-Host "[Scan] Attempting to launch most recent eligible: $($setupFile.Name)"
                Write-Host "[Scan] File details: Size=$($setupFile.Length) bytes, Modified=$($setupFile.LastWriteTime)"

                $launched = Launch-Setup-If-Possible -setupFile $setupFile
                if ($launched) {
                    Write-Host "[Success] ✅ Setup launched successfully and will be permanently tracked"
                }
            } else {
                Write-Host "[Scan] ℹ️  No new eligible setup.exe files found (all have been processed before)"
            }
        } else {
            Write-Host "[Scan] No setup.exe files found in watch directory"
        }
    } else {
        Write-Host "[Limit] Skipping scan - maximum concurrent setups already running"
    }

    # Show current session tracking status
    if ($currentSessionSetups.Count -gt 0) {
        Write-Host "[Session] Currently monitoring $($currentSessionSetups.Count) active session launch(es):"
        foreach ($setup in $currentSessionSetups.Keys) {
            $launchTime = $currentSessionSetups[$setup]
            $fileName = [System.IO.Path]::GetFileName($setup)
            Write-Host "  🔄 $fileName (launched: $($launchTime.ToString('HH:mm:ss')))"
        }
    }

    # Periodically show statistics
    if ($scanCount % 10 -eq 0) {
        Show-System-Statistics
    }

    Write-Host "[Wait] Next scan in 60 seconds..."
    Start-Sleep -Seconds 60
}
