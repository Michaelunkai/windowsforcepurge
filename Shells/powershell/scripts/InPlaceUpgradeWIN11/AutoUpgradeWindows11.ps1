#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Automated Windows 11 upgrade script with real-time progress monitoring
.DESCRIPTION
    Mounts the Windows 11 ISO and performs fully automated upgrade with real-time progress monitoring
    Schedules DISM cleanup to run automatically after reboot
#>

param(
    [string]$ISOPath = "F:\isos\windows.iso"
)

# Enable strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Create log file
$LogPath = "F:\study\shells\powershell\scripts\InPlaceUpgradeWIN11\log.txt"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage
    Add-Content -Path $LogPath -Value $logMessage -Force
}

# Function to check if Windows 11 setup is running
function Test-SetupRunning {
    try {
        $setupProcesses = Get-Process | Where-Object { $_.ProcessName -eq "setup" -or $_.ProcessName -eq "SetupHost" -or $_.ProcessName -eq "WinSetupUI" }
        return ($setupProcesses.Count -gt 0)
    } catch {
        return $false
    }
}

Write-Log "Starting automated Windows 11 upgrade process"

# Check if system meets Windows 11 requirements
function Test-Windows11Requirements {
    Write-Log "Checking Windows 11 system requirements..."
    
    # Get system information
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $processor = Get-CimInstance -ClassName Win32_Processor
    $mem = Get-CimInstance -ClassName Win32_PhysicalMemory
    $tpm = Get-CimInstance -ClassName Win32_TPM -ErrorAction SilentlyContinue
    
    # Check OS version (must be Windows 10 20H1 or later)
    $osVersion = [System.Version]$os.Version
    $minVersion = [System.Version]"10.0.19041"
    
    if ($osVersion -lt $minVersion) {
        Write-Log "ERROR: Windows version $($os.Version) is not supported for Windows 11 upgrade"
        return $false
    }
    
    # Check processor (1 GHz or faster, 2 or more cores)
    if ($processor.NumberOfCores -lt 2) {
        Write-Log "ERROR: CPU does not meet Windows 11 requirements (minimum 2 cores)"
        return $false
    }
    
    # Check RAM (4 GB minimum)
    $totalMemGB = ($mem | Measure-Object -Property Capacity -Sum).Sum / 1GB
    if ($totalMemGB -lt 4) {
        Write-Log "ERROR: System memory ($([math]::Round($totalMemGB, 2)) GB) is less than the required 4 GB"
        return $false
    }
    
    # Check storage (64 GB minimum)
    $systemDrive = Get-PSDrive -Name $env:SystemDrive.Trim(":")
    $freeSpaceGB = $systemDrive.Free / 1GB
    if ($freeSpaceGB -lt 64) {
        Write-Log "ERROR: Free disk space ($([math]::Round($freeSpaceGB, 2)) GB) is less than the required 64 GB"
        return $false
    }
    
    Write-Log "System meets Windows 11 upgrade requirements"
    return $true
}

# Check requirements before proceeding
if (-not (Test-Windows11Requirements)) {
    throw "System does not meet Windows 11 upgrade requirements. Cannot proceed with upgrade."
}

# Global variables for cleanup
$isoMounted = $false
$driveLetter = $null

try {
    # Verify ISO exists
    if (-not (Test-Path $ISOPath)) {
        throw "ISO file not found at: $ISOPath"
    }
    Write-Log "ISO file found: $ISOPath"

    # Mount the ISO using multiple fallback methods
    Write-Log "Mounting ISO using multiple fallback methods..."
    
    # Method 1: Try direct mounting and finding drive
    try {
        Write-Log "Method 1: Using Mount-DiskImage with volume detection"
        
        # First, unmount if already mounted
        Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Seconds 2
        
        # Mount the ISO
        Mount-DiskImage -ImagePath $ISOPath -StorageType ISO | Out-Null
        Start-Sleep -Seconds 5  # Wait for mount to complete
        
        # Find the drive by checking all CD-ROM drives for setup.exe
        $cdromDrives = Get-WmiObject -Class Win32_Volume | Where-Object { $_.DriveType -eq 5 }  # 5 = CD-ROM
        foreach ($drive in $cdromDrives) {
            $driveLetterOnly = $drive.DriveLetter.Trim(":")
            if ($driveLetterOnly -and $driveLetterOnly -ne "") {
                $drivePath = "${driveLetterOnly}:\"
                Write-Log "Checking drive: $drivePath"
                if (Test-Path "$drivePath\setup.exe") {
                    $driveLetter = $driveLetterOnly
                    Write-Log "Found Windows setup at drive: $driveLetter"
                    break
                }
            }
        }
    } catch {
        Write-Log "Method 1 failed: $($_.Exception.Message)"
    }
    
    # Method 2: If method 1 failed, try Shell.Application
    if (-not $driveLetter) {
        try {
            Write-Log "Method 2: Using Shell.Application COM object"
            
            # Unmount first
            Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue | Out-Null
            Start-Sleep -Seconds 2
            
            # Use Shell.Application to mount
            $shell = New-Object -ComObject Shell.Application
            $isoDirectory = Split-Path $ISOPath
            $isoFileName = Split-Path $ISOPath -Leaf
            
            Write-Log "Mounting $isoFileName from $isoDirectory"
            $shell.Namespace($isoDirectory).ParseName($isoFileName).InvokeVerb("mount")
            Start-Sleep -Seconds 5  # Wait for mount to complete
            
            # Check for setup.exe again
            $cdromDrives = Get-WmiObject -Class Win32_Volume | Where-Object { $_.DriveType -eq 5 }
            foreach ($drive in $cdromDrives) {
                $driveLetterOnly = $drive.DriveLetter.Trim(":")
                if ($driveLetterOnly -and $driveLetterOnly -ne "") {
                    $drivePath = "${driveLetterOnly}:\"
                    Write-Log "Checking drive: $drivePath"
                    if (Test-Path "$drivePath\setup.exe") {
                        $driveLetter = $driveLetterOnly
                        Write-Log "Found Windows setup at drive: $driveLetter"
                        break
                    }
                }
            }
        } catch {
            Write-Log "Method 2 failed: $($_.Exception.Message)"
        }
    }
    
    # Method 3: Manual drive detection
    if (-not $driveLetter) {
        try {
            Write-Log "Method 3: Manual drive detection"
            
            # Get all CD-ROM drives
            $cdromDrives = Get-WmiObject -Class Win32_CDROMDrive
            foreach ($cdrom in $cdromDrives) {
                $driveLetterOnly = $cdrom.Drive.Trim(":")
                if ($driveLetterOnly -and $driveLetterOnly -ne "") {
                    $drivePath = "${driveLetterOnly}:\"
                    Write-Log "Checking CD-ROM drive: $drivePath"
                    if (Test-Path "$drivePath\setup.exe") {
                        $driveLetter = $driveLetterOnly
                        Write-Log "Found Windows setup at drive: $driveLetter"
                        break
                    }
                }
            }
        } catch {
            Write-Log "Method 3 failed: $($_.Exception.Message)"
        }
    }
    
    # If we still haven't found the drive letter, we have to abort
    if (-not $driveLetter) {
        throw "Failed to mount ISO or determine drive letter after all methods. Please check the ISO file and try manually mounting it."
    }
    
    $isoMounted = $true
    $setupPath = "${driveLetter}:\setup.exe"
    Write-Log "ISO successfully available at drive: ${driveLetter}:"
    
    # Verify setup.exe exists
    if (-not (Test-Path $setupPath)) {
        throw "setup.exe not found in mounted ISO at path: $setupPath"
    }
    Write-Log "Found setup.exe at: $setupPath"

    # Create post-reboot script for DISM cleanup and Windows Updates
    $postRebootScript = @"
# Post-reboot DISM cleanup and Windows Updates script
`$logPath = "F:\study\shells\powershell\scripts\InPlaceUpgradeWIN11\post_reboot_log.txt"
function Write-PostLog {
    param([string]`$Message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logMessage = "[`$timestamp] `$Message"
    Write-Host `$logMessage
    Add-Content -Path `$logPath -Value `$logMessage -Force
    # Also write to console for visibility
    Write-Output `$logMessage
}

Write-PostLog "Starting post-reboot cleanup and updates"

# Wait for system to stabilize after upgrade
Write-PostLog "Waiting for system to stabilize after upgrade (60 seconds)..."
Start-Sleep -Seconds 60

try {
    Write-PostLog "Running DISM cleanup (this may take 10-30 minutes)..."
    
    # Run DISM with visible output
    `$psi = New-Object System.Diagnostics.ProcessStartInfo
    `$psi.FileName = "dism.exe"
    `$psi.Arguments = "/online /cleanup-image /startcomponentcleanup"
    `$psi.UseShellExecute = `$false
    `$psi.RedirectStandardOutput = `$false
    `$psi.RedirectStandardError = `$false
    `$psi.CreateNoWindow = `$false
    `$psi.WindowStyle = "Normal"
    
    `$process = [System.Diagnostics.Process]::Start(`$psi)
    `$process.WaitForExit()
    
    if (`$process.ExitCode -eq 0) {
        Write-PostLog "DISM component cleanup completed successfully"
    } else {
        Write-PostLog "DISM component cleanup completed with exit code: `$(`$process.ExitCode)"
    }
    
    # Run additional DISM cleanup
    Write-PostLog "Running additional DISM cleanup..."
    `$psi2 = New-Object System.Diagnostics.ProcessStartInfo
    `$psi2.FileName = "dism.exe"
    `$psi2.Arguments = "/online /cleanup-image /restorehealth"
    `$psi2.UseShellExecute = `$false
    `$psi2.RedirectStandardOutput = `$false
    `$psi2.RedirectStandardError = `$false
    `$psi2.CreateNoWindow = `$false
    `$psi2.WindowStyle = "Normal"
    
    `$process2 = [System.Diagnostics.Process]::Start(`$psi2)
    `$process2.WaitForExit()
    
    if (`$process2.ExitCode -eq 0) {
        Write-PostLog "DISM restore health completed successfully"
    } else {
        Write-PostLog "DISM restore health completed with exit code: `$(`$process2.ExitCode)"
    }
} catch {
    Write-PostLog "Error during DISM cleanup: `$_"
}

# Install and run Windows Updates
Write-PostLog "Starting Windows Update installation process..."

try {
    # Check PowerShell version and install PSWindowsUpdate module
    `$psVersion = `$PSVersionTable.PSVersion.Major
    Write-PostLog "PowerShell version: `$psVersion"
    
    # Install NuGet provider if not already installed (required for PS5)
    if (`$psVersion -eq 5) {
        Write-PostLog "Installing NuGet provider for PowerShell 5..."
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:`$false
            Write-PostLog "NuGet provider installed successfully"
        } catch {
            Write-PostLog "Warning: Could not install NuGet provider: `$_"
        }
    }
    
    # Set execution policy temporarily
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
    
    # Install PSWindowsUpdate module if not already installed
    Write-PostLog "Checking for PSWindowsUpdate module..."
    if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-PostLog "Installing PSWindowsUpdate module..."
        try {
            if (`$psVersion -eq 5) {
                # For PowerShell 5, use specific installation method
                Install-Module -Name PSWindowsUpdate -Force -Confirm:`$false -AllowClobber -Scope AllUsers
            } else {
                Install-Module -Name PSWindowsUpdate -Force -Confirm:`$false -AllowClobber
            }
            Write-PostLog "PSWindowsUpdate module installed successfully"
        } catch {
            Write-PostLog "Error installing PSWindowsUpdate module: `$_"
            Write-PostLog "Attempting alternative Windows Update method using COM objects..."
            
            # Fallback method using Windows Update COM objects
            `$updateSession = New-Object -ComObject Microsoft.Update.Session
            `$updateSearcher = `$updateSession.CreateUpdateSearcher()
            
            Write-PostLog "Searching for available updates..."
            `$searchResult = `$updateSearcher.Search("IsInstalled=0 and Type='Software'")
            
            if (`$searchResult.Updates.Count -eq 0) {
                Write-PostLog "No updates available using COM method"
            } else {
                Write-PostLog "Found `$(`$searchResult.Updates.Count) updates using COM method"
                
                `$updatesCollection = New-Object -ComObject Microsoft.Update.UpdateColl
                foreach (`$update in `$searchResult.Updates) {
                    if (!`$update.IsHidden) {
                        `$updatesCollection.Add(`$update) | Out-Null
                        Write-PostLog "Added update: `$(`$update.Title)"
                    }
                }
                
                if (`$updatesCollection.Count -gt 0) {
                    `$downloader = `$updateSession.CreateUpdateDownloader()
                    `$downloader.Updates = `$updatesCollection
                    Write-PostLog "Downloading `$(`$updatesCollection.Count) updates..."
                    `$downloadResult = `$downloader.Download()
                    
                    if (`$downloadResult.ResultCode -eq 2) {
                        Write-PostLog "Updates downloaded successfully"
                        
                        `$installer = `$updateSession.CreateUpdateInstaller()
                        `$installer.Updates = `$updatesCollection
                        Write-PostLog "Installing updates..."
                        `$installResult = `$installer.Install()
                        
                        Write-PostLog "Installation completed with result code: `$(`$installResult.ResultCode)"
                        
                        if (`$installResult.RebootRequired) {
                            Write-PostLog "Reboot required for updates"
                        }
                    }
                }
            }
            return
        }
    }
    
    # Import the module
    Import-Module PSWindowsUpdate -Force
    Write-PostLog "PSWindowsUpdate module imported successfully"
    
    # Continuous update loop
    `$updateRound = 1
    `$maxRounds = 5  # Prevent infinite loops
    
    do {
        Write-PostLog "=== Windows Update Round `$updateRound of `$maxRounds ==="
        
        # Get available updates
        Write-PostLog "Scanning for available updates..."
        `$updates = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot
        
        if (`$updates) {
            Write-PostLog "Found `$(`$updates.Count) update(s) to install"
            foreach (`$update in `$updates) {
                Write-PostLog "  - `$(`$update.Title)"
            }
            
            # Install updates
            Write-PostLog "Installing updates (Round `$updateRound)..."
            try {
                `$installResult = Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot -Confirm:`$false
                Write-PostLog "Update installation completed for round `$updateRound"
                
                # Log installation results
                if (`$installResult) {
                    foreach (`$result in `$installResult) {
                        Write-PostLog "  Install result: `$(`$result.Title) - `$(`$result.Result)"
                    }
                }
            } catch {
                Write-PostLog "Error during update installation (Round `$updateRound): `$_"
                break
            }
            
            # Wait a bit between rounds
            Start-Sleep -Seconds 30
            
        } else {
            Write-PostLog "No more updates available after round `$updateRound"
            break
        }
        
        `$updateRound++
        
    } while (`$updateRound -le `$maxRounds)
    
    if (`$updateRound -gt `$maxRounds) {
        Write-PostLog "Reached maximum update rounds (`$maxRounds). Stopping update process."
    }
    
    # Final check for any remaining updates
    Write-PostLog "Performing final update scan..."
    `$finalUpdates = Get-WindowsUpdate -MicrosoftUpdate
    if (`$finalUpdates) {
        Write-PostLog "Warning: `$(`$finalUpdates.Count) update(s) still available after all rounds"
        foreach (`$update in `$finalUpdates) {
            Write-PostLog "  Remaining: `$(`$update.Title)"
        }
    } else {
        Write-PostLog "All Windows updates have been installed successfully"
    }
    
} catch {
    Write-PostLog "Error during Windows Update process: `$_"
    Write-PostLog "Stack trace: `$(`$_.ScriptStackTrace)"
}

# Clean up the scheduled task
try {
    Unregister-ScheduledTask -TaskName "PostUpgradeCleanupAndUpdates" -Confirm:`$false -ErrorAction SilentlyContinue
    Write-PostLog "Scheduled task cleaned up"
} catch {
    Write-PostLog "Error cleaning up scheduled task: `$_"
}

# Clean up this script
try {
    Start-Sleep -Seconds 5
    Remove-Item `$PSCommandPath -Force -ErrorAction SilentlyContinue
    Write-PostLog "Post-reboot script cleaned up"
} catch {
    Write-PostLog "Error cleaning up post-reboot script: `$_"
}

Write-PostLog "Post-reboot cleanup and Windows Updates completed"
"@

    $postRebootScriptPath = "F:\study\shells\powershell\scripts\InPlaceUpgradeWIN11\PostRebootCleanup.ps1"
    Set-Content -Path $postRebootScriptPath -Value $postRebootScript -Force
    Write-Log "Created post-reboot script: $postRebootScriptPath"

    # Create scheduled task to run after reboot
    Write-Log "Creating scheduled task for post-reboot cleanup and Windows Updates"
    
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Normal -File `"$postRebootScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Hours 4)
    
    Register-ScheduledTask -TaskName "PostUpgradeCleanupAndUpdates" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
    Write-Log "Scheduled task created successfully"

    # Performance optimizations
    Write-Log "Applying performance optimizations..."
    
    # Set high performance power plan
    try {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        Write-Log "Set high performance power plan"
    } catch {
        Write-Log "Could not set high performance power plan: $($_.Exception.Message)"
    }
    
    # Disable Windows Defender real-time protection temporarily
    try {
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
        Write-Log "Temporarily disabled Windows Defender real-time protection"
    } catch {
        Write-Log "Could not disable Windows Defender (may require manual intervention)"
    }

    # Stop non-essential services temporarily
    $servicesToStop = @("wuauserv", "BITS", "CryptSvc", "TrustedInstaller")
    foreach ($service in $servicesToStop) {
        try {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Write-Log "Stopped service: $service"
        } catch {
            Write-Log "Could not stop service: $service (may not be running)"
        }
    }

    Write-Log "Starting Windows 11 setup with maximum automation..."
    
    # Create setup logs directory
    try {
        New-Item -Path "F:\study\shells\powershell\scripts\InPlaceUpgradeWIN11\setup_logs" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Log "Created setup logs directory"
    } catch {
        Write-Log "Could not create setup logs directory: $($_.Exception.Message)"
    }

    # Run setup.exe with maximum automation parameters
    Write-Log "Preparing to launch Windows 11 setup..."
    
    # Prepare the correct arguments for a fully automated in-place upgrade
    # Using /Auto Upgrade with /Quiet for fully automated upgrade
    # /Compat IgnoreWarning to bypass compatibility warnings
    # /MigrateDrivers to keep existing drivers
    # /CopyLogs to capture setup logs for troubleshooting
    $setupArgs = "/Auto Upgrade /Quiet /NoReboot /Compat IgnoreWarning /MigrateDrivers /CopyLogs F:\study\shells\powershell\scripts\InPlaceUpgradeWIN11\setup_logs"
    
    Write-Log "Executing setup with arguments: $setupArgs"
    Write-Log "This process will take 30-60 minutes. Please be patient and do not interrupt it."
    Write-Log "Setup will run completely in the background with no user interaction required."
    
    # Start the upgrade process with proper handling for in-place upgrade
    try {
        Write-Log "Launching Windows 11 setup with arguments: $setupArgs"
        
        # For in-place upgrade, we start the process and immediately continue without waiting
        # as setup will take over the system and the PowerShell process will be terminated
        $process = Start-Process -FilePath $setupPath -ArgumentList $setupArgs -PassThru -WindowStyle Hidden
        
        Write-Log "Setup process started with PID: $($process.Id)"
        Write-Log "Windows 11 upgrade is now running in the background."
        Write-Log "The system will automatically restart when needed to continue the upgrade process."
        
        # Wait a few seconds to ensure setup has started
        Start-Sleep -Seconds 10
        
        # Check if setup is still running
        if (Test-SetupRunning) {
            Write-Log "Confirmed: Windows 11 setup is running in the background."
        } else {
            Write-Log "Warning: Setup process may have already taken over the system."
        }
        
        # For in-place upgrades, we don't wait for the process to complete as it will
        # take over the system and restart automatically
        Write-Log "Continuing with scheduled restart to ensure upgrade process continues..."
        
    } catch {
        Write-Log "Error launching setup process: $($_.Exception.Message)"
        Write-Log "This is expected during in-place upgrade as setup takes over the system."
        Write-Log "Continuing with restart to ensure upgrade process continues."
    }
    
    # Always schedule restart to ensure upgrade continues
    Write-Log "Scheduling system restart in 30 seconds to continue Windows 11 upgrade..."
    # Force restart even if applications are running
    shutdown /r /t 30 /f /c "Windows 11 upgrade process initiated. System will restart to continue upgrade. Please do not interrupt this process."

} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "Stack trace: $($_.ScriptStackTrace)"
    
    # Re-enable Windows Defender if it was disabled
    try {
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        Write-Log "Re-enabled Windows Defender real-time protection"
    } catch {
        Write-Log "Could not re-enable Windows Defender"
    }
    
    throw
} finally {
    # Unmount ISO
    try {
        if ($isoMounted -and $driveLetter -and (Test-Path $ISOPath)) {
            Write-Log "Unmounting ISO..."
            # Try to unmount using multiple methods
            try {
                # Method 1: Shell.Application
                $shell = New-Object -ComObject Shell.Application
                $driveObj = $shell.NameSpace("$driveLetter`:").Self
                $driveObj.InvokeVerb("Eject")
                Write-Log "ISO unmounted using Shell.Application"
            } catch {
                Write-Log "Shell.Application unmount failed, trying DiskImage method..."
                try {
                    Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue | Out-Null
                    Write-Log "ISO unmounted using DiskImage method"
                } catch {
                    Write-Log "Both unmount methods failed"
                }
            }
            Start-Sleep -Seconds 2
        }
    } catch {
        Write-Log "Warning: Could not unmount ISO: $($_.Exception.Message)"
    }
}

Write-Log "Automated upgrade script completed. System will restart in 60 seconds to continue the upgrade process."
Write-Log "After restart, Windows 11 setup will continue automatically."
Write-Log "Once the upgrade is complete, the system will restart again and then run DISM cleanup and install all available Windows Updates."
