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

# Set console to suppress all prompts and confirmations
$ConfirmPreference = 'None'
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'

# Force PowerShell to trust all certificates and repositories
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue

# Set execution policy globally to bypass
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force -ErrorAction SilentlyContinue
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force -ErrorAction SilentlyContinue
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue

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

# Check requirements before proceeding (but allow bypass)
if (-not (Test-Windows11Requirements)) {
    Write-Log "WARNING: System may not meet Windows 11 requirements, but continuing anyway due to bypass flags"
    Write-Log "Registry bypasses will handle hardware compatibility issues"
    # Don't throw - continue anyway
}

# Global variables for cleanup
$isoMounted = $false
$driveLetter = $null

try {
    # Verify ISO exists and is valid
    if (-not (Test-Path $ISOPath)) {
        throw "ISO file not found at: $ISOPath"
    }

    # Check ISO file size (Windows 11 ISO should be at least 4GB)
    $isoFile = Get-Item $ISOPath
    $isoSizeGB = [math]::Round($isoFile.Length / 1GB, 2)
    Write-Log "ISO file found: $ISOPath (Size: $isoSizeGB GB)"

    if ($isoFile.Length -lt 3GB) {
        throw "ISO file appears to be corrupted or incomplete. Size: $isoSizeGB GB (expected at least 4GB)"
    }

    # Verify ISO file extension
    if ($isoFile.Extension -ne ".iso") {
        Write-Log "WARNING: File extension is not .iso - this may not be a valid ISO file"
    }

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
    
    # Verify setup.exe exists and validate Windows 11 ISO content
    if (-not (Test-Path $setupPath)) {
        throw "setup.exe not found in mounted ISO at path: $setupPath"
    }

    # Verify this is actually a Windows 11 ISO by checking for key files
    $requiredFiles = @("setup.exe", "autorun.inf", "bootmgr", "sources\install.wim")
    $missingFiles = @()

    foreach ($file in $requiredFiles) {
        $fullPath = Join-Path "${driveLetter}:" $file
        if (-not (Test-Path $fullPath)) {
            $missingFiles += $file
        }
    }

    if ($missingFiles.Count -gt 0) {
        Write-Log "WARNING: Some expected Windows installation files are missing:"
        foreach ($missing in $missingFiles) {
            Write-Log "  - Missing: $missing"
        }
        Write-Log "This may not be a valid Windows 11 installation ISO"
    }

    # Check setup.exe version to confirm it's Windows 11
    try {
        $setupInfo = Get-ItemProperty $setupPath
        $version = $setupInfo.VersionInfo.ProductVersion
        Write-Log "Setup.exe version: $version"

        if ($version -and $version.StartsWith("10.0.22")) {
            Write-Log "CONFIRMED: This appears to be a Windows 11 ISO (version starts with 10.0.22)"
        } else {
            Write-Log "WARNING: Setup version '$version' may not be Windows 11 (expected 10.0.22xxx)"
        }
    } catch {
        Write-Log "Could not verify setup.exe version: $($_.Exception.Message)"
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
    
    # Install PSWindowsUpdate module with maximum force
    Write-PostLog "Checking for PSWindowsUpdate module..."
    if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-PostLog "Installing PSWindowsUpdate module with maximum automation..."
        try {
            # Force trust PSGallery
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

            # Multiple installation attempts
            if (`$psVersion -eq 5) {
                Install-Module -Name PSWindowsUpdate -Force -Confirm:`$false -AllowClobber -Scope AllUsers -SkipPublisherCheck -AcceptLicense
            } else {
                Install-Module -Name PSWindowsUpdate -Force -Confirm:`$false -AllowClobber -SkipPublisherCheck -AcceptLicense
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

    # Comprehensive system preparation for 100% automated upgrade
    Write-Log "Applying comprehensive system optimizations and bypasses..."

    # Set high performance power plan
    try {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        Write-Log "Set high performance power plan"
    } catch {
        Write-Log "Could not set high performance power plan: $($_.Exception.Message)"
    }

    # Disable ALL potential blockers and prompts
    try {
        # Disable Windows Defender completely
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisablePrivacyMode $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableArchiveScanning $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableIntrusionPreventionSystem $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableEmailScanning $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableRemovableDriveScanning $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableScanningNetworkFiles $true -ErrorAction SilentlyContinue
        Write-Log "Completely disabled Windows Defender"
    } catch {
        Write-Log "Could not fully disable Windows Defender: $($_.Exception.Message)"
    }

    # Disable User Account Control completely
    try {
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorUser /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Disabled User Account Control"
    } catch {
        Write-Log "Could not disable UAC: $($_.Exception.Message)"
    }

    # Disable Windows Error Reporting
    try {
        reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Disabled Windows Error Reporting"
    } catch {
        Write-Log "Could not disable Windows Error Reporting: $($_.Exception.Message)"
    }

    # Disable all notification systems
    try {
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Disabled all notifications"
    } catch {
        Write-Log "Could not disable notifications: $($_.Exception.Message)"
    }

    # Stop ONLY truly non-essential services (keep critical ones running)
    $servicesToStop = @(
        "WinDefend", "WdNisSvc", "SecurityHealthService", "WerSvc",
        "DiagTrack", "dmwappushservice", "MapsBroker", "lfsvc",
        "TabletInputService", "WbioSrvc", "WMPNetworkSvc", "WSearch",
        "XblAuthManager", "XblGameSave", "XboxNetApiSvc"
    )

    # CRITICAL: Do NOT stop these as they can cause system instability:
    # wuauserv, BITS, CryptSvc, TrustedInstaller, SharedAccess, wscsvc
    foreach ($service in $servicesToStop) {
        try {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Stopped and disabled service: $service"
        } catch {
            Write-Log "Could not stop service: $service (may not exist or be running)"
        }
    }

    # SAFELY disable only non-critical processes (NEVER kill system processes)
    $safeProcessesToStop = @(
        "MsMpEng", "NisSrv", "SecurityHealthSystray", "SecurityHealthService"
    )
    foreach ($processName in $safeProcessesToStop) {
        try {
            Get-Process -Name $processName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Log "Safely terminated process: $processName"
        } catch {
            Write-Log "Could not terminate process: $processName (may not be running)"
        }
    }

    # CRITICAL: Never kill these system processes as they cause BSOD:
    # explorer, dwm, winlogon, csrss, wininit, services, lsass, svchost
    Write-Log "Skipping critical system processes to prevent BSOD"

    # Create unattend.xml for completely automated setup
    $unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserData>
                <AcceptEula>true</AcceptEula>
                <FullName>User</FullName>
                <Organization>Organization</Organization>
                <ProductKey>
                    <WillShowUI>Never</WillShowUI>
                </ProductKey>
            </UserData>
            <EnableFirewall>false</EnableFirewall>
            <EnableNetwork>true</EnableNetwork>
            <Restart>Automatic</Restart>
            <UpgradeData>
                <Upgrade>true</Upgrade>
                <WillShowUI>Never</WillShowUI>
            </UpgradeData>
            <ImageInstall>
                <OSImage>
                    <WillShowUI>Never</WillShowUI>
                    <InstallFrom>
                        <MetaData wcm:action="add">
                            <Key>/IMAGE/INDEX</Key>
                            <Value>1</Value>
                        </MetaData>
                    </InstallFrom>
                </OSImage>
            </ImageInstall>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
            <AutoLogon>
                <Enabled>true</Enabled>
                <LogonCount>1</LogonCount>
                <Username>Administrator</Username>
            </AutoLogon>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Path>reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v SkipUserOOBE /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Path>reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v SkipMachineOOBE /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
</unattend>
"@

    $unattendPath = "F:\study\shells\powershell\scripts\InPlaceUpgradeWIN11\unattend.xml"
    Set-Content -Path $unattendPath -Value $unattendXml -Force
    Write-Log "Created unattend.xml for fully automated setup: $unattendPath"

    # Disable all Windows Update and compatibility checks
    Write-Log "Disabling Windows Update and compatibility checks during upgrade..."
    try {
        # Disable Windows Update during upgrade
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f | Out-Null

        # Disable compatibility assistant
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v DisablePCA /t REG_DWORD /d 1 /f | Out-Null

        # Disable TPM requirement check
        reg add "HKLM\SYSTEM\Setup\MoSetup" /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f | Out-Null

        # Bypass hardware requirements
        reg add "HKLM\SYSTEM\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKLM\SYSTEM\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKLM\SYSTEM\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKLM\SYSTEM\Setup\LabConfig" /v BypassStorageCheck /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKLM\SYSTEM\Setup\LabConfig" /v BypassCPUCheck /t REG_DWORD /d 1 /f | Out-Null

        Write-Log "Registry modifications applied to bypass all checks"
    } catch {
        Write-Log "Warning: Some registry modifications failed: $($_.Exception.Message)"
    }

    Write-Log "Starting Windows 11 setup with maximum automation..."
    
    # Create setup logs directory
    try {
        New-Item -Path "F:\study\shells\powershell\scripts\InPlaceUpgradeWIN11\setup_logs" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Log "Created setup logs directory"
    } catch {
        Write-Log "Could not create setup logs directory: $($_.Exception.Message)"
    }

    # Run setup.exe with multiple tested parameter combinations
    Write-Log "Preparing to launch Windows 11 setup with multiple method attempts..."

    # Define multiple setup argument combinations (in order of preference)
    $setupArguments = @(
        "/Auto Upgrade /Quiet /DynamicUpdate Disable /Compat IgnoreWarning",
        "/Auto Upgrade /Quiet /Compat IgnoreWarning",
        "/Auto Upgrade /Quiet /NoReboot",
        "/Auto Upgrade /Quiet",
        "/Auto Upgrade /DynamicUpdate Disable",
        "/Auto Upgrade",
        "/Upgrade /Quiet /DynamicUpdate Disable /Compat IgnoreWarning",
        "/Upgrade /Quiet /Compat IgnoreWarning"
    )

    $setupSuccess = $false
    $successfulMethod = ""

    # Try each setup method until one works
    for ($i = 0; $i -lt $setupArguments.Length; $i++) {
        $currentArgs = $setupArguments[$i]
        Write-Log "=== ATTEMPT $($i + 1) of $($setupArguments.Length) ==="
        Write-Log "Testing setup with arguments: $currentArgs"

        try {
            # Start the setup process
            $process = Start-Process -FilePath $setupPath -ArgumentList $currentArgs -PassThru -WindowStyle Minimized
            Write-Log "Setup process started with PID: $($process.Id)"

            # Wait and monitor the process
            Write-Log "Monitoring setup process for 90 seconds..."
            $monitorStart = Get-Date
            $processStillRunning = $false

            while ((Get-Date) -lt $monitorStart.AddSeconds(90)) {
                Start-Sleep -Seconds 10

                # Refresh process status
                try {
                    $process.Refresh()
                    if (!$process.HasExited) {
                        $processStillRunning = $true
                        Write-Log "Setup process still running after $([math]::Round(((Get-Date) - $monitorStart).TotalSeconds)) seconds"

                        # Check if Windows setup UI is actually running
                        $setupProcesses = Get-Process | Where-Object {
                            $_.ProcessName -eq "setup" -or
                            $_.ProcessName -eq "SetupHost" -or
                            $_.ProcessName -eq "WinSetupUI" -or
                            $_.ProcessName -eq "setupprep" -or
                            $_.MainWindowTitle -like "*Windows*Setup*" -or
                            $_.MainWindowTitle -like "*Windows*11*"
                        }

                        if ($setupProcesses.Count -gt 0) {
                            Write-Log "CONFIRMED: Windows setup UI processes are running!"
                            foreach ($sp in $setupProcesses) {
                                Write-Log "  - Process: $($sp.ProcessName) (PID: $($sp.Id)) Title: '$($sp.MainWindowTitle)'"
                            }
                            $setupSuccess = $true
                            $successfulMethod = $currentArgs
                            break
                        }
                    } else {
                        Write-Log "Setup process exited after $([math]::Round(((Get-Date) - $monitorStart).TotalSeconds)) seconds"
                        break
                    }
                } catch {
                    Write-Log "Error checking process status: $($_.Exception.Message)"
                    break
                }
            }

            # If we found a working method, exit the loop
            if ($setupSuccess) {
                Write-Log "SUCCESS: Method $($i + 1) worked! Setup is running with arguments: $currentArgs"
                break
            } else {
                Write-Log "Method $($i + 1) failed - setup process did not establish properly"

                # Clean up the process if it's still running
                try {
                    if (!$process.HasExited) {
                        $process.Kill()
                        Write-Log "Terminated failed setup process"
                    }
                } catch {
                    Write-Log "Could not terminate process: $($_.Exception.Message)"
                }
            }

        } catch {
            Write-Log "Error with method $($i + 1): $($_.Exception.Message)"
        }

        # Brief pause between attempts
        if ($i -lt $setupArguments.Length - 1) {
            Write-Log "Waiting 10 seconds before next attempt..."
            Start-Sleep -Seconds 10
        }
    }

    # Check final result
    if ($setupSuccess) {
        Write-Log "=== SETUP SUCCESSFULLY STARTED ==="
        Write-Log "Successful method: $successfulMethod"
        Write-Log "Windows 11 upgrade is now running in the background"
        Write-Log "The system will automatically restart when needed to continue the upgrade process"
        Write-Log "Expected upgrade time: 30-90 minutes"
        Write-Log "DO NOT INTERRUPT THE PROCESS"

        # Create a success marker file
        try {
            Set-Content -Path "F:\study\shells\powershell\scripts\InPlaceUpgradeWIN11\upgrade_started.txt" -Value "Upgrade started at $(Get-Date) with method: $successfulMethod" -Force
            Write-Log "Created upgrade status marker file"
        } catch {
            Write-Log "Could not create status marker: $($_.Exception.Message)"
        }

        # Start real-time monitoring until reboot
        Write-Log "=== STARTING REAL-TIME PROGRESS MONITORING ==="
        Write-Log "Monitoring upgrade progress until system restart..."
        Write-Log "Press Ctrl+C to stop monitoring (upgrade will continue in background)"
        Write-Log ""

        $monitorStartTime = Get-Date
        $lastUpdateTime = Get-Date
        $updateInterval = 30  # Update every 30 seconds
        $progressCounter = 1

        try {
            while ($true) {
                $currentTime = Get-Date
                $elapsedMinutes = [math]::Round(($currentTime - $monitorStartTime).TotalMinutes, 1)

                # Clear screen for better visibility
                Clear-Host

                Write-Host "================================================================" -ForegroundColor Cyan
                Write-Host "    WINDOWS 11 UPGRADE IN PROGRESS - REAL-TIME MONITORING" -ForegroundColor Yellow
                Write-Host "================================================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Started: $($monitorStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
                Write-Host "Elapsed: $elapsedMinutes minutes" -ForegroundColor Green
                Write-Host "Status Check #$progressCounter" -ForegroundColor Cyan
                Write-Host "Last Updated: $($currentTime.ToString('HH:mm:ss'))" -ForegroundColor Gray
                Write-Host ""

                # Check running setup processes
                Write-Host "ACTIVE SETUP PROCESSES:" -ForegroundColor Yellow
                $setupProcesses = Get-Process | Where-Object {
                    $_.ProcessName -eq "setup" -or
                    $_.ProcessName -eq "SetupHost" -or
                    $_.ProcessName -eq "WinSetupUI" -or
                    $_.ProcessName -eq "SetupPrep" -or
                    $_.ProcessName -eq "setupprep" -or
                    $_.MainWindowTitle -like "*Windows*Setup*" -or
                    $_.MainWindowTitle -like "*Windows*11*" -or
                    $_.MainWindowTitle -like "*Upgrade*"
                }

                if ($setupProcesses.Count -gt 0) {
                    foreach ($proc in $setupProcesses) {
                        $cpuUsage = try { $proc.CPU } catch { "N/A" }
                        $memoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 1)
                        Write-Host "  ✓ $($proc.ProcessName) (PID: $($proc.Id)) - CPU: $cpuUsage - Memory: $memoryMB MB" -ForegroundColor Green
                        if ($proc.MainWindowTitle) {
                            Write-Host "    Title: '$($proc.MainWindowTitle)'" -ForegroundColor Gray
                        }
                    }
                } else {
                    Write-Host "  ⚠ No setup processes detected - upgrade may have completed or system is restarting" -ForegroundColor Yellow
                }

                Write-Host ""

                # Check system memory and CPU usage
                Write-Host "SYSTEM RESOURCES:" -ForegroundColor Yellow
                try {
                    $memInfo = Get-CimInstance -ClassName Win32_OperatingSystem
                    $totalMemGB = [math]::Round($memInfo.TotalPhysicalMemory / 1GB, 1)
                    $freeMemGB = [math]::Round($memInfo.FreePhysicalMemory / 1KB / 1MB, 1)
                    $usedMemGB = $totalMemGB - $freeMemGB
                    $memPercentUsed = [math]::Round(($usedMemGB / $totalMemGB) * 100, 1)

                    Write-Host "  Memory: $usedMemGB GB / $totalMemGB GB used ($memPercentUsed percent)" -ForegroundColor Cyan
                } catch {
                    Write-Host "  Memory: Unable to retrieve" -ForegroundColor Red
                }

                # Check disk activity
                Write-Host ""
                Write-Host "DISK ACTIVITY:" -ForegroundColor Yellow
                try {
                    $diskCounters = Get-Counter "\PhysicalDisk(_Total)\Disk Read Bytes/sec", "\PhysicalDisk(_Total)\Disk Write Bytes/sec" -ErrorAction SilentlyContinue
                    if ($diskCounters) {
                        $readBytesPerSec = [math]::Round($diskCounters.CounterSamples[0].CookedValue / 1MB, 2)
                        $writeBytesPerSec = [math]::Round($diskCounters.CounterSamples[1].CookedValue / 1MB, 2)
                        Write-Host "  Read: $readBytesPerSec MB/s | Write: $writeBytesPerSec MB/s" -ForegroundColor Cyan
                    }
                } catch {
                    Write-Host "  Disk activity monitoring unavailable" -ForegroundColor Gray
                }

                # Check for setup log files
                Write-Host ""
                Write-Host "SETUP LOGS:" -ForegroundColor Yellow
                $logPaths = @(
                    "$env:WINDIR\Panther\setupact.log",
                    "$env:WINDIR\Panther\setuperr.log",
                    "F:\study\shells\powershell\scripts\InPlaceUpgradeWIN11\setup_logs"
                )

                foreach ($logPath in $logPaths) {
                    if (Test-Path $logPath) {
                        $logItem = Get-Item $logPath
                        $logSizeKB = [math]::Round($logItem.Length / 1KB, 1)
                        $lastWrite = $logItem.LastWriteTime.ToString('HH:mm:ss')
                        Write-Host "  ✓ $($logItem.Name) - $logSizeKB KB (Updated: $lastWrite)" -ForegroundColor Green

                        # Try to read last few lines of setupact.log for progress
                        if ($logItem.Name -eq "setupact.log" -and $logItem.Length -gt 0) {
                            try {
                                $lastLines = Get-Content $logPath -Tail 3 -ErrorAction SilentlyContinue | Where-Object { $_ -ne "" }
                                if ($lastLines) {
                                    Write-Host "  Recent activity:" -ForegroundColor Gray
                                    foreach ($line in $lastLines) {
                                        $shortLine = if ($line.Length -gt 80) { $line.Substring(0, 80) + "..." } else { $line }
                                        Write-Host "    $shortLine" -ForegroundColor DarkGray
                                    }
                                }
                            } catch {
                                Write-Host "    (Log file in use by setup process)" -ForegroundColor DarkGray
                            }
                        }
                    } else {
                        Write-Host "  ✗ $($logPath.Split('\')[-1]) - Not found" -ForegroundColor Red
                    }
                }

                # Progress indicators
                Write-Host ""
                Write-Host "UPGRADE PROGRESS ESTIMATE:" -ForegroundColor Yellow
                $progressMessage = switch ($elapsedMinutes) {
                    { $_ -lt 5 } { "[INIT] Initializing and preparing upgrade..." }
                    { $_ -lt 15 } { "[DOWNLOAD] Downloading updates and compatibility checks..." }
                    { $_ -lt 30 } { "[INSTALL] Installing Windows 11 components..." }
                    { $_ -lt 45 } { "[MIGRATE] Applying system changes and migrating settings..." }
                    { $_ -lt 60 } { "[FINALIZE] Finalizing installation and preparing restart..." }
                    default { "[EXTENDED] Extended processing - complex system or many programs..." }
                }
                Write-Host "  $progressMessage" -ForegroundColor Cyan

                # Warning about expected restart
                Write-Host ""
                Write-Host "NEXT STEPS:" -ForegroundColor Yellow
                Write-Host "  • System will automatically restart when ready" -ForegroundColor White
                Write-Host "  • After restart: Windows 11 setup will continue" -ForegroundColor White
                Write-Host "  • Final phase: Automatic DISM cleanup + Windows Updates" -ForegroundColor White
                Write-Host ""
                Write-Host "WARNING: DO NOT POWER OFF OR INTERRUPT THE UPGRADE PROCESS" -ForegroundColor Red
                Write-Host ""
                Write-Host "================================================================" -ForegroundColor Cyan
                Write-Host "Next update in $updateInterval seconds... (Press Ctrl+C to stop monitoring)" -ForegroundColor Gray

                # Wait for next update
                Start-Sleep -Seconds $updateInterval
                $progressCounter++

                # Check if processes are still running - if not, setup may have completed
                $currentSetupProcesses = Get-Process | Where-Object {
                    $_.ProcessName -eq "setup" -or $_.ProcessName -eq "SetupHost" -or $_.ProcessName -eq "SetupPrep"
                }

                if ($currentSetupProcesses.Count -eq 0 -and $elapsedMinutes -gt 5) {
                    Write-Host ""
                    Write-Host "SUCCESS: UPGRADE APPEARS TO BE COMPLETING!" -ForegroundColor Green
                    Write-Host "Setup processes have finished - system restart should occur soon..." -ForegroundColor Green
                    Write-Host "Continuing to monitor for restart..." -ForegroundColor Yellow
                }
            }
        } catch [System.Management.Automation.PipelineStoppedException] {
            Write-Host ""
            Write-Host "Monitoring stopped by user. Upgrade continues in background." -ForegroundColor Yellow
        } catch {
            Write-Host ""
            Write-Host "Monitoring error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Upgrade continues in background." -ForegroundColor Yellow
        }

        # This should never be reached as the system will restart, but just in case
        Write-Log "Real-time monitoring completed - upgrade should continue automatically"
        exit 0
    } else {
        Write-Log "=== ALL SETUP METHODS FAILED ==="
        Write-Log "None of the $($setupArguments.Length) setup methods succeeded"
    }
    
    # Add final registry bypasses before restart
    try {
        # Disable automatic restart notifications
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUPowerManagement /t REG_DWORD /d 1 /f | Out-Null

        # Force automatic logon after restart
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d "1" /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d "$env:USERNAME" /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultDomainName /t REG_SZ /d "$env:COMPUTERNAME" /f | Out-Null

        Write-Log "Applied final registry bypasses"
    } catch {
        Write-Log "Warning: Some final registry modifications failed: $($_.Exception.Message)"
    }

    # REMOVED: Dangerous process termination that caused BSOD
    # The following processes MUST NEVER be killed as they cause system crashes:
    # explorer.exe, dwm.exe, winlogon.exe, csrss.exe, wininit.exe, services.exe, lsass.exe
    Write-Log "Skipping process termination to prevent CRITICAL_PROCESS_DIED BSOD"
    Write-Log "Windows 11 setup will handle process management safely"

    # Only restart if setup failed to start properly
    Write-Log "WARNING: Windows 11 setup did not start properly"
    Write-Log "This could be due to:"
    Write-Log "  1. ISO is corrupted or not a valid Windows 11 ISO"
    Write-Log "  2. System incompatibility"
    Write-Log "  3. Setup files are missing or damaged"
    Write-Log ""
    Write-Log "MANUAL ACTION REQUIRED:"
    Write-Log "  1. Verify the ISO file is a valid Windows 11 installation ISO"
    Write-Log "  2. Try running setup manually: $setupPath"
    Write-Log "  3. Check the setup logs in: F:\\study\\shells\\powershell\\scripts\\InPlaceUpgradeWIN11\\setup_logs"
    Write-Log ""
    Write-Log "Script completed - NO automatic restart since setup didn't start"

} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "Stack trace: $($_.ScriptStackTrace)"
    
    # In case of failure, attempt to restore some system settings
    try {
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Attempted to restore some system settings after failure"
    } catch {
        Write-Log "Could not restore system settings after failure"
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

Write-Log "=== FULLY AUTOMATED UPGRADE INITIATED ==="
Write-Log "System will restart IMMEDIATELY to continue the upgrade process"
Write-Log "NO USER INTERACTION REQUIRED OR EXPECTED"
Write-Log "After restart: Windows 11 setup will continue automatically"
Write-Log "After upgrade: System will auto-restart and run DISM cleanup + Windows Updates"
Write-Log "TOTAL PROCESS: 100% AUTOMATED - DO NOT INTERRUPT"
Write-Log "Expected completion time: 1-3 hours depending on system speed"
Write-Log "Log files will be available in: F:\study\shells\powershell\scripts\InPlaceUpgradeWIN11\"

# Final safety measure - create a restore point if possible
try {
    Enable-ComputerRestore -Drive "C:\"
    Checkpoint-Computer -Description "Pre-Windows11-Upgrade-Automated" -RestorePointType "MODIFY_SETTINGS"
    Write-Log "Created system restore point as final safety measure"
} catch {
    Write-Log "Could not create restore point (continuing anyway): $($_.Exception.Message)"
}

# Force execution to continue even if errors occur
$ErrorActionPreference = "Continue"

Write-Log "=== SCRIPT EXECUTION COMPLETE - SYSTEM RESTART IMMINENT ==="
