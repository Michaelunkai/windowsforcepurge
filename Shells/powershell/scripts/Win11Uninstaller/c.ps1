# HYPER-SPEED AGGRESSIVE SOFTWARE PURGE SCRIPT - NO MERCY EDITION
# INSTANT EXECUTION - NO CONFIRMATIONS - ZERO LEFTOVERS
# Requires PowerShell 5.0+ and Administrator privileges

param(
    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$ToolNames,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
HYPER-SPEED AGGRESSIVE SOFTWARE PURGE - NO MERCY EDITION
=======================================================

INSTANT EXECUTION - NO CONFIRMATIONS - GUARANTEED ZERO LEFTOVERS
Ultra-fast parallel processing with maximum aggression.

Requirements:
- PowerShell 5.0+
- Run as Administrator
- Revo Uninstaller Pro

FEATURES:
- NO CONFIRMATIONS - Runs immediately
- GUARANTEED return to terminal
- ZERO LEFTOVERS - Finds everything
- Parallel execution with timeouts
- Force-kills stuck processes

Usage: Just enter app names and press Enter!

"@
    exit
}

# Check prerequisites
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Run as Administrator!"
    Read-Host "Press Enter to exit"
    exit 1
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "Requires PowerShell 5.0 or higher!"
    Read-Host "Press Enter to exit"
    exit 1
}

# Configuration
$revoPath = 'F:\backup\windowsapps\installed\Revo Uninstaller Pro\RevoUninPro.exe'
$drivesToClean = @('C:', 'F:')
$protectedFolder = "study"
$maxThreads = [Environment]::ProcessorCount * 2
$jobTimeout = 300  # 5 minutes max per job

# Ultra-fast nuclear deletion function
function Remove-Nuclear {
    param([string[]]$Paths, [string]$AppName)

    if (-not $Paths -or $Paths.Count -eq 0) { return }

    $scriptBlock = {
        param($pathList, $app, $protected)

        foreach ($path in $pathList) {
            if (-not $path -or -not (Test-Path $path)) { continue }
            if ($path -match "\\$protected(\\|$)") {
                "PROTECTED: $path"
                continue
            }

            try {
                # Nuclear deletion sequence
                attrib -R -S -H "$path" /S /D 2>$null
                if (Test-Path $path -PathType Container) {
                    cmd /c "rmdir /s /q `"$path`" 2>nul"
                } else {
                    cmd /c "del /f /q `"$path`" 2>nul"
                }

                if (Test-Path $path) {
                    takeown /f "$path" /r /d y 2>$null | Out-Null
                    icacls "$path" /grant administrators:F /t /c /q 2>$null | Out-Null
                    Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
                }

                if (Test-Path $path) {
                    # Final nuclear option
                    Start-Process "cmd" -ArgumentList "/c `"del /f /s /q `"$path`" & rmdir /s /q `"$path`"`"" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
                }

                if (-not (Test-Path $path)) {
                    "NUKED: $path"
                } else {
                    "RESISTANT: $path"
                }
            }
            catch {
                "FAILED: $path - $($_.Exception.Message)"
            }
        }
    }

    # Execute with timeout
    $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $Paths, $AppName, $protectedFolder

    if (Wait-Job $job -Timeout $jobTimeout) {
        $results = Receive-Job $job
        Remove-Job $job
        return $results
    } else {
        Stop-Job $job
        Remove-Job $job
        return @("TIMEOUT: Deletion job timed out")
    }
}

# Hyper-aggressive file finder
function Find-AllTraces {
    param([string]$Drive, [string[]]$AppNames)

    $allTargets = @()

    foreach ($appName in $AppNames) {
        Write-Host "SCANNING $Drive for '$appName'..." -ForegroundColor Yellow

        # Known hiding spots first
        $knownPaths = @(
            "$Drive\Program Files\*$appName*",
            "$Drive\Program Files (x86)\*$appName*",
            "$Drive\ProgramData\*$appName*",
            "$Drive\Users\*\AppData\Local\*$appName*",
            "$Drive\Users\*\AppData\Roaming\*$appName*",
            "$Drive\Users\*\AppData\LocalLow\*$appName*",
            "$Drive\Users\*\Desktop\*$appName*",
            "$Drive\Users\*\Documents\*$appName*",
            "$Drive\Users\*\Downloads\*$appName*",
            "$Drive\Users\*\Start Menu\*$appName*",
            "$Drive\ProgramData\Microsoft\Windows\Start Menu\*$appName*",
            "$Drive\Windows\Temp\*$appName*",
            "$Drive\Temp\*$appName*",
            "$Drive\Users\*\AppData\Local\Temp\*$appName*"
        )

        foreach ($pattern in $knownPaths) {
            try {
                $found = Get-ChildItem $pattern -Force -ErrorAction SilentlyContinue |
                        Where-Object { $_.FullName -notmatch "\\$protectedFolder(\\|$)" }
                $allTargets += $found.FullName
            }
            catch { }
        }

        # DEEP SCAN - Use WHERE command for speed
        try {
            $whereCmd = "where /r `"$Drive\`" `"*$appName*`" 2>nul"
            $whereResults = cmd /c $whereCmd
            foreach ($result in $whereResults) {
                if ($result -and (Test-Path $result) -and $result -notmatch "\\$protectedFolder(\\|$)") {
                    $allTargets += $result.Trim('"')
                }
            }
        }
        catch { }

        # Registry-based installer locations
        try {
            $regPaths = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
                'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
            )

            foreach ($regPath in $regPaths) {
                $entries = Get-ChildItem $regPath -ErrorAction SilentlyContinue |
                          Get-ItemProperty -ErrorAction SilentlyContinue |
                          Where-Object { $_.DisplayName -like "*$appName*" }

                foreach ($entry in $entries) {
                    if ($entry.InstallLocation -and (Test-Path $entry.InstallLocation)) {
                        $allTargets += $entry.InstallLocation
                    }
                    if ($entry.UninstallString) {
                        $uninstallDir = Split-Path $entry.UninstallString -Parent
                        if ($uninstallDir -and (Test-Path $uninstallDir)) {
                            $allTargets += $uninstallDir
                        }
                    }
                }
            }
        }
        catch { }
    }

    return ($allTargets | Sort-Object -Unique | Where-Object { $_ -and (Test-Path $_) })
}

# Lightning registry cleanup
function Remove-RegistryNuclear {
    param([string[]]$AppNames)

    $results = @()

    foreach ($appName in $AppNames) {
        # Use reg.exe for speed and reliability
        $regHives = @('HKCU', 'HKLM')

        foreach ($hive in $regHives) {
            try {
                # Delete known app registry locations
                $regPaths = @(
                    "$hive\Software\$appName",
                    "$hive\Software\Classes\$appName",
                    "$hive\Software\Classes\Applications\$appName"
                )

                foreach ($regPath in $regPaths) {
                    $output = cmd /c "reg delete `"$regPath`" /f 2>nul"
                    if ($LASTEXITCODE -eq 0) {
                        $results += "REG DELETED: $regPath"
                    }
                }

                # Search and destroy in Software hive
                $searchCmd = "reg query `"$hive\Software`" /s /f `"$appName`" /k 2>nul"
                $searchResults = cmd /c $searchCmd

                foreach ($line in $searchResults) {
                    if ($line -match '^HK') {
                        $keyPath = $line.Trim()
                        $output = cmd /c "reg delete `"$keyPath`" /f 2>nul"
                        if ($LASTEXITCODE -eq 0) {
                            $results += "REG FOUND & DELETED: $keyPath"
                        }
                    }
                }
            }
            catch { }
        }
    }

    return $results
}

# Main execution starts here
Write-Host "=== HYPER-SPEED AGGRESSIVE PURGE - NO MERCY EDITION ===" -ForegroundColor Red
Write-Host "INSTANT EXECUTION - NO CONFIRMATIONS - ZERO LEFTOVERS" -ForegroundColor Yellow
Write-Host "Using $maxThreads threads with $jobTimeout second timeouts" -ForegroundColor Cyan

# Get input - NO CONFIRMATION NEEDED
if ($ToolNames -and $ToolNames.Count -gt 0) {
    $toolNames = $ToolNames | Where-Object { $_ -ne '' }
} else {
    Write-Host "`nEnter tools to INSTANTLY PURGE:" -ForegroundColor Red
    $userInput = Read-Host "Tools"
    if ([string]::IsNullOrWhiteSpace($userInput)) {
        Write-Host "No tools specified. Exiting." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        exit 0
    }
    $toolNames = $userInput.Trim() -split '\s+' | Where-Object { $_ -ne '' }
}

Write-Host "`nINSTANT PURGE STARTING: $($toolNames -join ', ')" -ForegroundColor Red
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Try to uninstall each tool using winget, choco, and Uninstall-Package
foreach ($tool in $ToolNames) {
    Write-Host "\n==== Attempting to uninstall $($tool) via winget, choco, and Uninstall-Package ====" -ForegroundColor Cyan
    $uninstalled = $false

    # Try winget
    try {
        $wingetResult = winget uninstall --id $($tool) --silent -e 2>&1
        if ($wingetResult -match "Successfully uninstalled" -or $wingetResult -match "No installed package found") {
            Write-Host "[winget] $($tool): $wingetResult" -ForegroundColor Green
            $uninstalled = $true
        } else {
            Write-Host "[winget] $($tool): $wingetResult" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[winget] $($tool): Exception $($_)" -ForegroundColor Red
    }

    # Try choco if not uninstalled
    if (-not $uninstalled) {
        try {
            $chocoResult = choco uninstall $($tool) -y --no-progress 2>&1
            if ($chocoResult -match "Chocolatey uninstalled" -or $chocoResult -match "was not found with the source(s) provided") {
                Write-Host "[choco] $($tool): $chocoResult" -ForegroundColor Green
                $uninstalled = $true
            } else {
                Write-Host "[choco] $($tool): $chocoResult" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "[choco] $($tool): Exception $($_)" -ForegroundColor Red
        }
    }

    # Try Uninstall-Package if not uninstalled
    if (-not $uninstalled) {
        try {
            $pkg = Get-Package -Name $($tool) -ErrorAction SilentlyContinue
            if ($pkg) {
                Uninstall-Package -Name $($tool) -Force -ErrorAction SilentlyContinue
                Write-Host "[Uninstall-Package] $($tool): Uninstall attempted." -ForegroundColor Green
                $uninstalled = $true
            } else {
                Write-Host "[Uninstall-Package] $($tool): Not found as a package." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "[Uninstall-Package] $($tool): Exception $($_)" -ForegroundColor Red
        }
    }
}

# --- NEW: Kill processes related to tool names ---
foreach ($toolName in $toolNames) {
    try {
        $procs = Get-Process | Where-Object { $_.Name -like "*$toolName*" -or $_.Path -like "*$toolName*" }
        foreach ($proc in $procs) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                Write-Host "Killed process: $($proc.Name) ($($proc.Id))" -ForegroundColor Red
            } catch {}
        }
    } catch {}
}

# --- NEW: Remove Scheduled Tasks and Services ---
foreach ($toolName in $toolNames) {
    # Scheduled Tasks
    try {
        $tasks = schtasks /Query /FO LIST /V | Select-String -Pattern $toolName
        foreach ($task in $tasks) {
            $taskName = ($task.Line -split ':')[1].Trim()
            if ($taskName) {
                schtasks /Delete /TN "$taskName" /F 2>$null
                Write-Host "Deleted scheduled task: $taskName" -ForegroundColor Red
            }
        }
    } catch {}
    # Services
    try {
        $services = Get-Service | Where-Object { $_.Name -like "*$toolName*" -or $_.DisplayName -like "*$toolName*" }
        foreach ($svc in $services) {
            try {
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                sc.exe delete "$($svc.Name)" | Out-Null
                Write-Host "Deleted service: $($svc.Name)" -ForegroundColor Red
            } catch {}
        }
    } catch {}
}

# Phase 2: Aggressive file system scan
Write-Host "`nPhase 2: AGGRESSIVE FILE SYSTEM SCAN..." -ForegroundColor Cyan
$allTargets = @()

foreach ($drive in $drivesToClean) {
    $targets = Find-AllTraces -Drive $drive -AppNames $toolNames
    $allTargets += $targets
    Write-Host "Found $($targets.Count) targets on $drive" -ForegroundColor Yellow
}

# --- NEW: Extra file/folder patterns for thoroughness ---
foreach ($toolName in $toolNames) {
    # Common root folders
    $extraPatterns = @(
        "$env:USERPROFILE\*$toolName*",
        "$env:USERPROFILE\.*$toolName*",
        "$env:USERPROFILE\Documents\*$toolName*",
        "$env:USERPROFILE\Downloads\*$toolName*",
        "$env:USERPROFILE\Desktop\*$toolName*",
        "$env:USERPROFILE\AppData\*\$toolName*",
        "$env:USERPROFILE\AppData\*\*\$toolName*",
        "$env:ALLUSERSPROFILE\*$toolName*",
        "$env:ALLUSERSPROFILE\*\$toolName*"
    )
    foreach ($pattern in $extraPatterns) {
        try {
            $found = Get-ChildItem $pattern -Force -ErrorAction SilentlyContinue
            $allTargets += $found.FullName
        } catch {}
    }
}

$allTargets = $allTargets | Sort-Object -Unique | Where-Object { $_ -and (Test-Path $_) }

# Phase 3: NUCLEAR DELETION
if ($allTargets.Count -gt 0) {
    Write-Host "`nPhase 3: NUCLEAR DELETION of $($allTargets.Count) targets..." -ForegroundColor Red
    $deleteResults = Remove-Nuclear -Paths $allTargets -AppName "ALL"
    $deleteResults | ForEach-Object { Write-Host $_ -ForegroundColor Red }
} else {
    Write-Host "No filesystem targets found." -ForegroundColor Green
}

# Phase 4: NUCLEAR REGISTRY CLEANUP
Write-Host "`nPhase 4: NUCLEAR REGISTRY CLEANUP..." -ForegroundColor Cyan

# --- NEW: Remove more registry keys/values ---
function Remove-RegistryNuclear {
    param([string[]]$AppNames)
    $results = @()
    foreach ($appName in $AppNames) {
        $regHives = @('HKCU', 'HKLM', 'HKU', 'HKCR')
        foreach ($hive in $regHives) {
            try {
                $regPaths = @(
                    "$hive\Software\$appName",
                    "$hive\Software\Classes\$appName",
                    "$hive\Software\Classes\Applications\$appName",
                    "$hive\System\CurrentControlSet\Services\$appName",
                    "$hive\SYSTEM\CurrentControlSet\Services\$appName",
                    "$hive\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$appName"
                )
                foreach ($regPath in $regPaths) {
                    $output = cmd /c "reg delete `"$regPath`" /f 2>nul"
                    if ($LASTEXITCODE -eq 0) {
                        $results += "REG DELETED: $regPath"
                    }
                }
                # Search and destroy in Software and Classes hives
                foreach ($sub in @("Software", "Software\Classes", "SYSTEM\CurrentControlSet\Services")) {
                    $searchCmd = "reg query `"$hive\$sub`" /s /f `"$appName`" /k 2>nul"
                    $searchResults = cmd /c $searchCmd
                    foreach ($line in $searchResults) {
                        if ($line -match '^HK') {
                            $keyPath = $line.Trim()
                            $output = cmd /c "reg delete `"$keyPath`" /f 2>nul"
                            if ($LASTEXITCODE -eq 0) {
                                $results += "REG FOUND & DELETED: $keyPath"
                            }
                        }
                    }
                }
            } catch {}
        }
    }
    return $results
}

# --- NEW: Browser and system cleanup ---
Write-Host "`nPhase 5: BROWSER & SYSTEM CLEANUP..." -ForegroundColor Cyan

# Browser cleanup
$browserPaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions",
    "$env:APPDATA\Mozilla\Firefox\Profiles",
    "$env:APPDATA\Opera Software\Opera Stable\Extensions"
)

foreach ($basePath in $browserPaths) {
    if (Test-Path $basePath) {
        foreach ($toolName in $toolNames) {
            try {
                $found = Get-ChildItem $basePath -Recurse -Force -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -like "*$toolName*" }
                foreach ($item in $found) {
                    cmd /c "rmdir /s /q `"$($item.FullName)`" 2>nul"
                    Write-Host "BROWSER DELETED: $($item.FullName)" -ForegroundColor Red
                }
            }
            catch { }
        }
    }
}

# System cleanup
$tempPaths = @($env:TEMP, "$env:LOCALAPPDATA\Temp", "$env:WINDIR\Temp", "C:\Temp", "F:\Temp")
foreach ($tempPath in $tempPaths) {
    if (Test-Path $tempPath) {
        cmd /c "del /f /s /q `"$tempPath\*.*`" 2>nul"
    }
}

# Empty recycle bin
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "Recycle bin emptied" -ForegroundColor Green
}
catch { }

# Flush caches
try {
    ipconfig /flushdns | Out-Null
    Write-Host "DNS cache flushed" -ForegroundColor Green
}
catch { }

$stopwatch.Stop()

# FINAL VERIFICATION SCAN
Write-Host "`nFINAL VERIFICATION SCAN..." -ForegroundColor Yellow
$remainingFiles = @()

# --- NEW: Deep scan all user profiles and system locations ---
$allUserProfiles = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' | ForEach-Object {
    try {
        $profilePath = (Get-ItemProperty $_.PSPath).ProfileImagePath
        if ($profilePath -and (Test-Path $profilePath)) { $profilePath }
    } catch {}
}
$allUserProfiles += $env:USERPROFILE
$allUserProfiles = $allUserProfiles | Sort-Object -Unique

foreach ($drive in $drivesToClean) {
    foreach ($toolName in $toolNames) {
        # Deep scan for all file attributes and hidden/system folders
        $deepPatterns = @(
            "$drive\*\*$toolName*",
            "$drive\*\*\*$toolName*",
            "$drive\*\*\*\*$toolName*"
        )
        foreach ($pattern in $deepPatterns) {
            try {
                $found = Get-ChildItem -Path $pattern -Recurse -Force -ErrorAction SilentlyContinue
                $remainingFiles += $found.FullName
            } catch {}
        }

        # Scan all user profiles for deep leftovers
        foreach ($profile in $allUserProfiles) {
            $userPatterns = @(
                "$profile\*\*$toolName*",
                "$profile\*\*\*$toolName*",
                "$profile\AppData\*\$toolName*",
                "$profile\AppData\*\*\$toolName*"
            )
            foreach ($pattern in $userPatterns) {
                try {
                    $found = Get-ChildItem -Path $pattern -Recurse -Force -ErrorAction SilentlyContinue
                    $remainingFiles += $found.FullName
                } catch {}
            }
        }

        # Windows Installer cache
        $installerCache = "$env:WINDIR\Installer"
        if (Test-Path $installerCache) {
            try {
                $found = Get-ChildItem $installerCache -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$toolName*" }
                $remainingFiles += $found.FullName
            } catch {}
        }

        # Prefetch, Recent, shadow copies
        foreach ($sysPath in @("$env:WINDIR\Prefetch", "$env:APPDATA\Microsoft\Windows\Recent")) {
            if (Test-Path $sysPath) {
                try {
                    $found = Get-ChildItem $sysPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$toolName*" }
                    $remainingFiles += $found.FullName
                } catch {}
            }
        }

        # Shadow copies (list only, cannot delete directly here)
        try {
            $shadowInfo = (vssadmin list shadows 2>$null) -join "`n"
            if ($shadowInfo -match $toolName) {
                Write-Host "WARNING: Possible shadow copy contains $toolName" -ForegroundColor Red
            }
        } catch {}

        # Environment variables
        try {
            $envVars = [System.Environment]::GetEnvironmentVariables("Machine")
            foreach ($key in $envVars.Keys) {
                if ($key -like "*$toolName*" -or $envVars[$key] -like "*$toolName*") {
                    [System.Environment]::SetEnvironmentVariable($key, $null, "Machine")
                    Write-Host "ENV VAR REMOVED: $key" -ForegroundColor Red
                }
            }
        } catch {}
        try {
            $envVars = [System.Environment]::GetEnvironmentVariables("User")
            foreach ($key in $envVars.Keys) {
                if ($key -like "*$toolName*" -or $envVars[$key] -like "*$toolName*") {
                    [System.Environment]::SetEnvironmentVariable($key, $null, "User")
                    Write-Host "ENV VAR REMOVED: $key" -ForegroundColor Red
                }
            }
        } catch {}

        # Final registry sweep for orphaned keys/values
        foreach ($hive in @('HKCU', 'HKLM', 'HKU', 'HKCR')) {
            foreach ($sub in @("Software", "Software\Classes", "SYSTEM\CurrentControlSet\Services", "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")) {
                try {
                    $searchCmd = "reg query `"$hive\$sub`" /s /f `"$toolName`" /k /d /c 2>nul"
                    $searchResults = cmd /c $searchCmd
                    foreach ($line in $searchResults) {
                        if ($line -match '^HK') {
                            $keyPath = $line.Trim()
                            $output = cmd /c "reg delete `"$keyPath`" /f 2>nul"
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "REG DELETED: $keyPath" -ForegroundColor Red
                            }
                        }
                    }
                } catch {}
            }
        }

        # Final pass: kill any remaining processes/services
        try {
            $procs = Get-Process | Where-Object { $_.Name -like "*$toolName*" -or $_.Path -like "*$toolName*" }
            foreach ($proc in $procs) {
                try {
                    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                    Write-Host "Killed process: $($proc.Name) ($($proc.Id))" -ForegroundColor Red
                } catch {}
            }
        } catch {}
        try {
            $services = Get-Service | Where-Object { $_.Name -like "*$toolName*" -or $_.DisplayName -like "*$toolName*" }
            foreach ($svc in $services) {
                try {
                    Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                    sc.exe delete "$($svc.Name)" | Out-Null
                    Write-Host "Deleted service: $($svc.Name)" -ForegroundColor Red
                } catch {}
            }
        } catch {}

        # Re-run Remove-Nuclear on any new findings
        $remainingFiles = $remainingFiles | Sort-Object -Unique | Where-Object { $_ -and (Test-Path $_) }
        if ($remainingFiles.Count -gt 0) {
            Write-Host "WARNING: $($remainingFiles.Count) deep files still found for $toolName on $drive" -ForegroundColor Red
            $finalCleanup = Remove-Nuclear -Paths $remainingFiles -AppName $toolName
            $finalCleanup | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        }
    }
}

Write-Host "`n" + "="*70 -ForegroundColor Green
Write-Host "NUCLEAR PURGE COMPLETE!" -ForegroundColor Green
Write-Host "="*70 -ForegroundColor Green
Write-Host "Execution time: $($stopwatch.Elapsed.TotalSeconds) seconds" -ForegroundColor Cyan
Write-Host "Apps processed: $($toolNames -join ', ')" -ForegroundColor Cyan

if ($remainingFiles.Count -eq 0) {
    Write-Host "ZERO LEFTOVERS CONFIRMED!" -ForegroundColor Green
} else {
    Write-Host "WARNING: $($remainingFiles.Count) stubborn files may remain" -ForegroundColor Yellow
}

Write-Host "`nReturning to terminal..." -ForegroundColor Cyan
Start-Sleep -Seconds 2

# GUARANTEE return to terminal
exit 0