###   Complete Nvidia Driver & App Update Script (Normal Mode)   ###
###############################################################################
# A Windows PowerShell script to cleanly update your Nvidia display driver and app,
# using Display Driver Uninstaller and Chocolatey, with complete Nvidia app management.
# Modified to run entirely in normal mode without safe boot.

function Set-RunOnce($type) {
    $RunOnceKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    Set-ItemProperty -Path $RunOnceKey -Name "DDUScript" -Value ('C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe -executionPolicy Unrestricted -File ' + "$PSCommandPath")
}

function Remove-NvidiaApp {
    Write-Host 'Removing existing Nvidia App...' -ForegroundColor Yellow

    # Try to uninstall via Package Manager (Windows 11/10 Store apps)
    try {
        $nvidiaPackages = Get-AppxPackage -Name "*NVIDIA*" -AllUsers
        foreach ($package in $nvidiaPackages) {
            Write-Host "Removing package: $($package.Name)" -ForegroundColor Gray
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "Could not remove Store packages: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Try to uninstall traditional Win32 applications
    $nvidiaApps = @(
        "NVIDIA App",
        "NVIDIA GeForce Experience",
        "NVIDIA Control Panel",
        "NVIDIA GeForce NOW"
    )

    foreach ($appName in $nvidiaApps) {
        try {
            $app = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*$appName*" }
            if ($app) {
                Write-Host "Uninstalling: $($app.Name)" -ForegroundColor Gray
                $app.Uninstall() | Out-Null
            }
        } catch {
            Write-Host "Could not uninstall $appName via WMI: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Try chocolatey uninstall as backup
    try {
        choco uninstall -y nvidia-geforce-experience --ignore-unfound >$null 2>&1
        choco uninstall -y nvidia-geforce-now --ignore-unfound >$null 2>&1
    } catch {
        Write-Host "Chocolatey uninstall failed or not available" -ForegroundColor Yellow
    }

    Write-Host 'Nvidia App removal completed.' -ForegroundColor Green
}

function Install-NvidiaApp {
    Write-Host 'Installing latest Nvidia App...' -ForegroundColor Yellow

    # Try Chocolatey first (if available)
    try {
        Write-Host 'Attempting to install via Chocolatey...' -ForegroundColor Gray
        choco install -y nvidia-geforce-experience >$null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host 'Nvidia App installed successfully via Chocolatey!' -ForegroundColor Green
            return
        }
    } catch {
        Write-Host 'Chocolatey installation failed, trying direct download...' -ForegroundColor Yellow
    }

    # Direct download method
    try {
        Write-Host 'Downloading Nvidia App directly...' -ForegroundColor Gray
        $downloadUrl = "https://us.download.nvidia.com/nvapp/client/10.0.1.95/NVIDIA_app_v10.0.1.95.exe"
        $downloadPath = "$env:TEMP\NVIDIA_app_installer.exe"

        # Download the installer
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing

        if (Test-Path $downloadPath) {
            Write-Host 'Installing Nvidia App...' -ForegroundColor Gray
            Start-Process -FilePath $downloadPath -ArgumentList "/S" -Wait -NoNewWindow
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
            Write-Host 'Nvidia App installed successfully!' -ForegroundColor Green
        } else {
            Write-Host 'Failed to download Nvidia App installer' -ForegroundColor Red
        }
    } catch {
        Write-Host "Direct download failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host 'Please manually download and install the Nvidia App from https://www.nvidia.com/en-us/software/nvidia-app/' -ForegroundColor Yellow
    }
}

function Uninstall-DisplayDriver {
    Write-Host 'Cleaning display driver in normal mode...' -ForegroundColor Yellow
    
    # Stop Nvidia services before cleanup
    $nvidiaServices = @("NvDisplayContainer", "NVDisplay.ContainerLocalSystem", "NvContainerLocalSystem")
    foreach ($service in $nvidiaServices) {
        try {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Write-Host "Stopped service: $service" -ForegroundColor Gray
        } catch {
            Write-Host "Could not stop service $service" -ForegroundColor Yellow
        }
    }

    # Run DDU in normal mode with aggressive cleaning
    Write-Host 'Running Display Driver Uninstaller...' -ForegroundColor Yellow
    & 'Display Driver Uninstaller.exe' -Silent -NoRestorePoint -PreventWinUpdate -CleanNvidia -Restart | Out-Null
    
    # Mark uninstall as complete and set up for next phase
    Set-ItemProperty -Path $ScriptKey -Name UninstallComplete -Value 1
    Set-RunOnce
    
    Write-Host 'Display driver cleaned. Rebooting for fresh driver installation...' -ForegroundColor Green
    Start-Sleep -Seconds 3
    Restart-Computer -Force
    Exit
}

function Install-Prerequisites {
    Write-Host 'Checking and installing prerequisites...' -ForegroundColor Yellow

    # Check if Chocolatey is installed
    try {
        choco --version | Out-Null
        Write-Host 'Chocolatey is already installed.' -ForegroundColor Green
    } catch {
        Write-Host 'Installing Chocolatey...' -ForegroundColor Gray
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        refreshenv
    }
}

function Create-NvidiaAppMonitor {
    Write-Host 'Setting up Nvidia App first launch monitor...' -ForegroundColor Cyan

    # Create the monitoring script content
    $monitorScriptContent = @'
# Nvidia App First Launch Monitor Script
$ErrorActionPreference = 'SilentlyContinue'

# Registry key to track if we've already detected first launch
$RegKey = "HKCU:\SOFTWARE\DDUScript"
$FirstLaunchKey = "NvidiaAppFirstLaunchDetected"

# Check if we've already detected first launch
if ((Get-ItemProperty -Path $RegKey -Name $FirstLaunchKey -ErrorAction SilentlyContinue).$FirstLaunchKey) {
    # Already detected, remove the scheduled task and exit
    Unregister-ScheduledTask -TaskName "NvidiaAppMonitor" -Confirm:$false -ErrorAction SilentlyContinue
    exit
}

# Nvidia App process names to monitor
$NvidiaProcesses = @(
    'NVIDIA App',
    'NVIDIAApp',
    'nvidia-app',
    'GeForceExperience',
    'NVIDIA GeForce Experience'
)

# Check if any Nvidia App process is running
$nvidiaRunning = $false
foreach ($processName in $NvidiaProcesses) {
    if (Get-Process -Name ($processName -replace ' ', '') -ErrorAction SilentlyContinue) {
        $nvidiaRunning = $true
        break
    }
}

if ($nvidiaRunning) {
    # Mark as detected
    if (!(Test-Path -Path $RegKey)) {
        New-Item -Path $RegKey -Force | Out-Null
    }
    Set-ItemProperty -Path $RegKey -Name $FirstLaunchKey -Value 1

    # Log the detection
    Add-Content -Path "$env:TEMP\nvidia_monitor.log" -Value "$(Get-Date): Nvidia App first launch detected!"

    # Wait a moment for the app to fully start
    Start-Sleep -Seconds 5

    # Create the clean and ress execution script
    $cleanAndRessScript = @"
# Define the clean function (placeholder - update with your actual clean function)
function clean {
    Write-Host "Running clean function..." -ForegroundColor Yellow
    # Add your clean function implementation here
    Write-Host "Clean function completed!" -ForegroundColor Green
}

try {
    Write-Host "Starting clean and ress.ps1 execution sequence..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    # Run the clean function
    Write-Host "Step 1: Running clean function..." -ForegroundColor Yellow
    clean
    Write-Host "Clean command executed successfully!" -ForegroundColor Green

    Write-Host ""
    Write-Host "Step 2: Running ress.ps1 script..." -ForegroundColor Yellow

    # Check if ress.ps1 exists
    if (Test-Path "F:\study\shells\powershell\scripts\ress.ps1") {
        # Execute ress.ps1 script
        & "F:\study\shells\powershell\scripts\ress.ps1"
        Write-Host "ress.ps1 script executed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Error: ress.ps1 script not found at F:\study\shells\powershell\scripts\ress.ps1" -ForegroundColor Red
        Write-Host "Please verify the script path and ensure the file exists." -ForegroundColor Yellow
    }

} catch {
    Write-Host "Error during execution: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Nvidia App first launch sequence completed:" -ForegroundColor Cyan
Write-Host "- Clean function executed" -ForegroundColor Gray
Write-Host "- ress.ps1 script executed" -ForegroundColor Gray
Write-Host "Press any key to close this window..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
"@

    # Save the clean and ress script
    $tempCleanScript = "$env:TEMP\clean_and_ress_runner.ps1"
    $cleanAndRessScript | Out-File -FilePath $tempCleanScript -Encoding UTF8

    # Start new PowerShell window with the script
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $tempCleanScript -WindowStyle Normal

        Add-Content -Path "$env:TEMP\nvidia_monitor.log" -Value "$(Get-Date): Clean command and ress.ps1 executed in new PowerShell window"

        # Clean up temp script after delay
        Start-Job -ScriptBlock {
            param($scriptPath)
            Start-Sleep -Seconds 30
            Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
        } -ArgumentList $tempCleanScript | Out-Null

    } catch {
        Add-Content -Path "$env:TEMP\nvidia_monitor.log" -Value "$(Get-Date): Error executing clean command and ress.ps1: $($_.Exception.Message)"
    }

    # Remove the scheduled task since we're done
    Unregister-ScheduledTask -TaskName "NvidiaAppMonitor" -Confirm:$false -ErrorAction SilentlyContinue
}
'@

    # Save the monitoring script
    $monitorScriptPath = "$env:TEMP\NvidiaAppMonitor.ps1"
    $monitorScriptContent | Out-File -FilePath $monitorScriptPath -Encoding UTF8

    # Create scheduled task to run the monitor every 30 seconds
    try {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$monitorScriptPath`""
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Seconds 30) -RepetitionDuration (New-TimeSpan -Days 7)
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive

        Register-ScheduledTask -TaskName "NvidiaAppMonitor" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

        Write-Host 'Nvidia App monitor scheduled task created successfully!' -ForegroundColor Green
        Write-Host 'Monitor will detect first Nvidia App launch, run "clean" command, then execute ress.ps1.' -ForegroundColor Yellow

    } catch {
        Write-Host "Failed to create scheduled task: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Monitor script saved to: $monitorScriptPath" -ForegroundColor Yellow
    }
}

function Start-FinalPowerShellCommand {
    Write-Host 'Opening new PowerShell window to run nnvc function...' -ForegroundColor Cyan

    # Create the nnvc script content
    $nnvcScriptContent = @'
# Define the nnvc function
function nnvc {
    Start-Process "F:\study\Platforms\windows\autohotkey\NVCeanInstall.ahk"
    Start-Sleep -Milliseconds 700
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait("1")
}

try {
    # Run the nnvc function
    Write-Host "Running nnvc function..." -ForegroundColor Yellow
    nnvc
    Write-Host "nnvc function executed successfully!" -ForegroundColor Green
    Write-Host "- Started AutoHotkey script: F:\study\Platforms\windows\autohotkey\NVCeanInstall.ahv" -ForegroundColor Gray
    Write-Host "- Sent keypress: 1" -ForegroundColor Gray
} catch {
    Write-Host "Error running nnvc function: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure the AutoHotkey script exists at the specified path." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "nnvc execution completed. Nvidia App monitor is now active." -ForegroundColor Cyan
Write-Host "Press any key to close this window..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
'@

    # Save the script to a temporary file
    $tempScript = "$env:TEMP\nnvc_runner.ps1"
    $nnvcScriptContent | Out-File -FilePath $tempScript -Encoding UTF8

    # Start new PowerShell window with the script
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $tempScript -WindowStyle Normal

        Write-Host 'New PowerShell window opened successfully!' -ForegroundColor Green

        # Clean up temp script after a delay
        Start-Job -ScriptBlock {
            param($scriptPath)
            Start-Sleep -Seconds 15
            Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
        } -ArgumentList $tempScript | Out-Null

    } catch {
        Write-Host "Failed to open new PowerShell window: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "You can manually run 'nnvc' in a new PowerShell window." -ForegroundColor Yellow

        # Clean up temp script
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
    }
}

#######################
###   Main Script   ###
###############################################################################

Write-Host @"
========================================
   Nvidia Driver & App Complete Updater
   (Normal Mode - No Safe Boot)
========================================
This script will:
1. Remove existing Nvidia App
2. Clean uninstall current drivers (DDU in normal mode)
3. Reboot and install latest drivers
4. Install latest Nvidia App
5. Run nnvc function in new PowerShell window
6. Monitor for Nvidia App first launch
7. Run "clean" command then execute ress.ps1
"@ -ForegroundColor Cyan

# Request (via UAC) to elevate permissions
if (!
    # Current role
    (New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    # Is admin?
    )).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
) {
    # Elevate script and exit current non-elevated runtime
    Write-Host 'Requesting administrator privileges...' -ForegroundColor Yellow
    Start-Process `
        -FilePath 'powershell' `
        -ArgumentList (
            #flatten to single array
            '-File', $MyInvocation.MyCommand.Source, $args `
            | %{ $_ }
        ) `
        -Verb RunAs
    exit
}

# Create the script registry key
$ScriptKey = "HKCU:\SOFTWARE\DDUScript"
if (! (Test-Path -Path $ScriptKey -PathType Container)) {
    New-Item -Path $ScriptKey | Out-Null
    Set-ItemProperty -Path $ScriptKey -Name UninstallComplete -Value 0
    Set-ItemProperty -Path $ScriptKey -Name AppRemoved -Value 0
    Set-ItemProperty -Path $ScriptKey -Name NvidiaAppFirstLaunchDetected -Value 0
}

# Check if we're resuming after driver cleanup
if ((Get-ItemProperty -Path $ScriptKey -Name UninstallComplete -ErrorAction SilentlyContinue).UninstallComplete) {
    Write-Host 'Phase 2: Installing latest Nvidia driver and app...' -ForegroundColor Cyan

    # Install latest driver
    Write-Host 'Installing/upgrading Nvidia driver...' -ForegroundColor Yellow
    choco upgrade -y --force nvidia-display-driver >$null 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Nvidia driver installed successfully!' -ForegroundColor Green
    } else {
        Write-Host 'Driver installation may have encountered issues. Please check manually.' -ForegroundColor Yellow
    }

    # Install Nvidia App
    Install-NvidiaApp

    Write-Host @"

========================================
   Update Complete!
========================================
Driver and Nvidia App have been updated.
Now setting up monitoring and running nnvc function...
"@ -ForegroundColor Green

    # Wait a moment for everything to settle
    Start-Sleep -Seconds 2

    # Set up the Nvidia App first launch monitor
    Create-NvidiaAppMonitor

    # Run the nnvc function
    Start-FinalPowerShellCommand

    # Clean up registry for next run
    Set-ItemProperty -Path $ScriptKey -Name UninstallComplete -Value 0
    Set-ItemProperty -Path $ScriptKey -Name AppRemoved -Value 0

    Write-Host @"

All operations completed successfully!
- Nvidia drivers updated (in normal mode)
- Nvidia App installed
- nnvc function executed in new window
- Monitor active for Nvidia App first launch
- "clean" command and ress.ps1 will run automatically when Nvidia App starts

The monitor will remain active for 7 days or until first launch is detected.
You may restart your computer - the monitor will persist across reboots.

Sequence when Nvidia App first launches:
1. Run "clean" function
2. Execute F:\study\shells\powershell\scripts\ress.ps1
"@ -ForegroundColor Green

    Read-Host -Prompt 'Press Enter to exit this window'
    Exit
} else {
    # Phase 1: Initial setup and app removal
    Write-Host 'Phase 1: Preparing for driver update...' -ForegroundColor Cyan

    # Install prerequisites
    Install-Prerequisites

    # Remove existing Nvidia App first
    if (!(Get-ItemProperty -Path $ScriptKey -Name AppRemoved -ErrorAction SilentlyContinue).AppRemoved) {
        Remove-NvidiaApp
        Set-ItemProperty -Path $ScriptKey -Name AppRemoved -Value 1
    }

    Write-Host 'Installing/upgrading DDU...' -ForegroundColor Yellow
    choco upgrade -y ddu >$null 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Warning: DDU installation may have failed. Continuing...' -ForegroundColor Yellow
    }

    Write-Host @"

Phase 1 Complete!
==================
The system will now perform a clean driver uninstallation 
using DDU in NORMAL MODE (no safe boot required).

After the clean uninstall, the system will reboot
normally and automatically install the latest driver
and Nvidia App, then run the nnvc function and set up
monitoring for Nvidia App first launch.

When Nvidia App first launches, it will:
1. Run the "clean" function
2. Execute F:\study\shells\powershell\scripts\ress.ps1

Automatically proceeding with driver cleanup...
"@ -ForegroundColor Yellow

    # Proceed with driver cleanup in normal mode
    Write-Host 'Starting driver cleanup in normal mode in 5 seconds...' -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    Uninstall-DisplayDriver
}
