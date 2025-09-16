# ASUS Driver Installer Script with Complete Driver Purge
# WARNING: Run as Administrator! This script COMPLETELY REMOVES existing drivers 
# and installs fresh ones from the ASUS folder

# WHAT THIS SCRIPT DOES:
# 1. PURGES all existing AMD, Realtek, MediaTek, ASUS, and related drivers
# 2. Cleans registry entries and driver store
# 3. Removes driver files from system folders  
# 4. Installs fresh drivers from your ASUS folder (100% silently)
# 5. Configures network settings and restarts services

param(
    [Parameter(Mandatory=$false)]
    [switch]$NetworkOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$AllDrivers,
    
    [Parameter(Mandatory=$false)]
    [string]$AsusPath = "F:\backup\windowsapps\install\Asus",
    
    [Parameter(Mandatory=$false)]
    [string]$WiFiName = "Stella_5",
    
    [Parameter(Mandatory=$false)]
    [string]$WiFiPassword = "Stellamylove"
)

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator!"
    exit 1
}

# Function to install network drivers (equivalent to fixnet)
function Install-NetworkDrivers {
    Write-Host "=== Installing Network Drivers ===" -ForegroundColor Green
    
    # Install network drivers using the batch file
    $networkDriverPath = Join-Path $AsusPath "NetworkDriver\Install.bat"
    if (Test-Path $networkDriverPath) {
        Write-Host "Installing network drivers from: $networkDriverPath"
        Start-Process -FilePath $networkDriverPath -Wait -NoNewWindow
    } else {
        Write-Warning "Network driver installer not found at: $networkDriverPath"
    }
    
    # Set location permissions in registry
    Write-Host "Setting location permissions..."
    $locationRegPaths = @(
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location",
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\Microsoft.Windows.ShellExperienceHost_cw5n1h2txyewy",
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\Microsoft.Windows.Cortana_cw5n1h2txyewy",
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged",
        "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
    )
    
    foreach ($regPath in $locationRegPaths) {
        try {
            reg add $regPath /v Value /t REG_SZ /d Allow /f | Out-Null
            Write-Host "✓ Set permission for: $regPath"
        } catch {
            Write-Warning "Failed to set permission for: $regPath"
        }
    }
    
    # Also set using PowerShell method
    try {
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' -Name 'Value' -Value 'Allow' -Force
        Write-Host "✓ Additional location permission set via PowerShell"
    } catch {
        Write-Warning "Failed to set location permission via PowerShell"
    }
    
    # Wait for driver installation to complete
    Write-Host "Waiting 30 seconds for driver installation to complete..."
    Start-Sleep 30
    
    # Configure WiFi profile
    if ($WiFiName -and $WiFiPassword) {
        Configure-WiFi -NetworkName $WiFiName -Password $WiFiPassword
    }
}

# Function to configure WiFi
function Configure-WiFi {
    param(
        [string]$NetworkName,
        [string]$Password
    )
    
    Write-Host "=== Configuring WiFi ===" -ForegroundColor Green
    
    # Delete existing profile
    Write-Host "Removing existing WiFi profile: $NetworkName"
    netsh wlan delete profile name="$NetworkName" 2>$null
    
    # Create WiFi profile XML
    $wifiProfileXml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$NetworkName</name>
    <SSIDConfig>
        <SSID>
            <name>$NetworkName</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$Password</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@
    
    # Save profile to temp file
    $tempProfile = Join-Path $env:temp "$NetworkName.xml"
    $wifiProfileXml | Out-File -FilePath $tempProfile -Encoding UTF8
    
    # Add and connect to WiFi profile
    Write-Host "Adding WiFi profile: $NetworkName"
    netsh wlan add profile filename="$tempProfile"
    
    Write-Host "Connecting to WiFi: $NetworkName"
    netsh wlan connect name="$NetworkName"
    
    # Clean up temp file
    Remove-Item $tempProfile -ErrorAction SilentlyContinue
}

# Function to completely purge existing drivers
function Remove-ExistingDrivers {
    Write-Host "=== PURGING EXISTING DRIVERS ===" -ForegroundColor Red
    Write-Host "This will completely remove existing AMD, ASUS, Realtek, MediaTek, and other drivers..." -ForegroundColor Yellow
    
    # Stop Windows Update service to prevent driver reinstallation
    Write-Host "Stopping Windows Update service..."
    Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
    
    # Remove AMD drivers
    Remove-AMDDrivers
    
    # Remove Audio drivers
    Remove-AudioDrivers
    
    # Remove Network drivers
    Remove-NetworkDrivers
    
    # Remove ASUS software
    Remove-ASUSDrivers
    
    # Remove Bluetooth drivers
    Remove-BluetoothDrivers
    
    # Clean registry entries
    Clean-DriverRegistry
    
    # Remove driver files from system folders
    Clean-DriverFiles
    
    # Clean driver store
    Clean-DriverStore
    
    Write-Host "=== DRIVER PURGE COMPLETE ===" -ForegroundColor Green
}

# Function to remove AMD drivers
function Remove-AMDDrivers {
    Write-Host "--- Removing AMD Drivers ---" -ForegroundColor Yellow
    
    # Uninstall AMD software via Programs and Features
    $amdSoftware = @(
        "*AMD*",
        "*Radeon*",
        "*Catalyst*",
        "*Crimson*",
        "*Adrenalin*",
        "*Ryzen*"
    )
    
    foreach ($pattern in $amdSoftware) {
        $programs = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $pattern }
        foreach ($program in $programs) {
            Write-Host "Uninstalling: $($program.Name)"
            try {
                $program.Uninstall() | Out-Null
            } catch {
                Write-Warning "Failed to uninstall: $($program.Name)"
            }
        }
    }
    
    # Remove AMD devices from Device Manager
    $amdDevices = Get-WmiObject -Class Win32_PnPEntity | Where-Object { 
        $_.Name -like "*AMD*" -or 
        $_.Name -like "*Radeon*" -or 
        $_.HardwareID -like "*AMD*" -or
        $_.HardwareID -like "*ATI*"
    }
    
    foreach ($device in $amdDevices) {
        Write-Host "Removing AMD device: $($device.Name)"
        try {
            $device.Delete()
        } catch {
            # Try using pnputil
            if ($device.HardwareID) {
                foreach ($hwid in $device.HardwareID) {
                    pnputil /delete-driver $hwid /uninstall /force 2>$null
                }
            }
        }
    }
    
    # Remove AMD registry entries
    $amdRegPaths = @(
        "HKLM:\SOFTWARE\AMD",
        "HKLM:\SOFTWARE\ATI Technologies",
        "HKLM:\SOFTWARE\WOW6432Node\AMD",
        "HKLM:\SOFTWARE\WOW6432Node\ATI Technologies"
    )
    
    foreach ($regPath in $amdRegPaths) {
        if (Test-Path $regPath) {
            Write-Host "Removing AMD registry: $regPath"
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Function to remove audio drivers
function Remove-AudioDrivers {
    Write-Host "--- Removing Audio Drivers ---" -ForegroundColor Yellow
    
    # Remove audio software
    $audioSoftware = @(
        "*Realtek*",
        "*Dolby*",
        "*Cirrus*",
        "*SmartAMP*",
        "*Audio*Driver*"
    )
    
    foreach ($pattern in $audioSoftware) {
        $programs = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $pattern }
        foreach ($program in $programs) {
            Write-Host "Uninstalling: $($program.Name)"
            try {
                $program.Uninstall() | Out-Null
            } catch {
                Write-Warning "Failed to uninstall: $($program.Name)"
            }
        }
    }
    
    # Remove audio devices
    $audioDevices = Get-WmiObject -Class Win32_PnPEntity | Where-Object { 
        $_.Name -like "*Realtek*" -or 
        $_.Name -like "*Dolby*" -or
        $_.Name -like "*Cirrus*" -or
        $_.Name -like "*Audio*" -or
        $_.HardwareID -like "*HDAUDIO*"
    }
    
    foreach ($device in $audioDevices) {
        Write-Host "Removing audio device: $($device.Name)"
        try {
            $device.Delete()
        } catch {
            if ($device.HardwareID) {
                foreach ($hwid in $device.HardwareID) {
                    pnputil /delete-driver $hwid /uninstall /force 2>$null
                }
            }
        }
    }
}

# Function to remove network drivers
function Remove-NetworkDrivers {
    Write-Host "--- Removing Network Drivers ---" -ForegroundColor Yellow
    
    # Remove network software
    $networkSoftware = @(
        "*MediaTek*",
        "*WiFi*",
        "*Wireless*",
        "*Network*",
        "*Bluetooth*"
    )
    
    foreach ($pattern in $networkSoftware) {
        $programs = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $pattern }
        foreach ($program in $programs) {
            Write-Host "Uninstalling: $($program.Name)"
            try {
                $program.Uninstall() | Out-Null
            } catch {
                Write-Warning "Failed to uninstall: $($program.Name)"
            }
        }
    }
    
    # Remove network adapters (be careful not to remove essential ones)
    $networkDevices = Get-WmiObject -Class Win32_PnPEntity | Where-Object { 
        ($_.Name -like "*MediaTek*" -or 
         $_.Name -like "*WiFi*" -or 
         $_.Name -like "*Wireless*" -or
         $_.HardwareID -like "*MTK*") -and
        $_.Name -notlike "*Microsoft*" -and
        $_.Name -notlike "*Generic*"
    }
    
    foreach ($device in $networkDevices) {
        Write-Host "Removing network device: $($device.Name)"
        try {
            $device.Delete()
        } catch {
            if ($device.HardwareID) {
                foreach ($hwid in $device.HardwareID) {
                    pnputil /delete-driver $hwid /uninstall /force 2>$null
                }
            }
        }
    }
}

# Function to remove ASUS drivers and software
function Remove-ASUSDrivers {
    Write-Host "--- Removing ASUS Software ---" -ForegroundColor Yellow
    
    $asusSoftware = @(
        "*ASUS*",
        "*ROG*",
        "*TUF*",
        "*Armoury*",
        "*MyASUS*",
        "*System Control Interface*"
    )
    
    foreach ($pattern in $asusSoftware) {
        $programs = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $pattern }
        foreach ($program in $programs) {
            Write-Host "Uninstalling: $($program.Name)"
            try {
                $program.Uninstall() | Out-Null
            } catch {
                Write-Warning "Failed to uninstall: $($program.Name)"
            }
        }
    }
    
    # Remove ASUS devices
    $asusDevices = Get-WmiObject -Class Win32_PnPEntity | Where-Object { 
        $_.Name -like "*ASUS*" -or 
        $_.HardwareID -like "*ASUS*"
    }
    
    foreach ($device in $asusDevices) {
        Write-Host "Removing ASUS device: $($device.Name)"
        try {
            $device.Delete()
        } catch {
            if ($device.HardwareID) {
                foreach ($hwid in $device.HardwareID) {
                    pnputil /delete-driver $hwid /uninstall /force 2>$null
                }
            }
        }
    }
}

# Function to remove Bluetooth drivers
function Remove-BluetoothDrivers {
    Write-Host "--- Removing Bluetooth Drivers ---" -ForegroundColor Yellow
    
    # Remove Bluetooth software
    $bluetoothSoftware = @(
        "*Bluetooth*",
        "*MediaTek*Bluetooth*"
    )
    
    foreach ($pattern in $bluetoothSoftware) {
        $programs = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $pattern }
        foreach ($program in $programs) {
            Write-Host "Uninstalling: $($program.Name)"
            try {
                $program.Uninstall() | Out-Null
            } catch {
                Write-Warning "Failed to uninstall: $($program.Name)"
            }
        }
    }
    
    # Remove Bluetooth devices
    $bluetoothDevices = Get-WmiObject -Class Win32_PnPEntity | Where-Object { 
        $_.Name -like "*Bluetooth*" -and 
        $_.Name -notlike "*Microsoft*" -and
        $_.Name -notlike "*Generic*"
    }
    
    foreach ($device in $bluetoothDevices) {
        Write-Host "Removing Bluetooth device: $($device.Name)"
        try {
            $device.Delete()
        } catch {
            if ($device.HardwareID) {
                foreach ($hwid in $device.HardwareID) {
                    pnputil /delete-driver $hwid /uninstall /force 2>$null
                }
            }
        }
    }
}

# Function to clean driver registry entries
function Clean-DriverRegistry {
    Write-Host "--- Cleaning Driver Registry ---" -ForegroundColor Yellow
    
    $registryPaths = @(
        "HKLM:\SOFTWARE\AMD",
        "HKLM:\SOFTWARE\ATI Technologies",
        "HKLM:\SOFTWARE\Realtek",
        "HKLM:\SOFTWARE\MediaTek",
        "HKLM:\SOFTWARE\ASUS",
        "HKLM:\SOFTWARE\Dolby",
        "HKLM:\SOFTWARE\Cirrus",
        "HKLM:\SOFTWARE\WOW6432Node\AMD",
        "HKLM:\SOFTWARE\WOW6432Node\ATI Technologies",
        "HKLM:\SOFTWARE\WOW6432Node\Realtek",
        "HKLM:\SOFTWARE\WOW6432Node\MediaTek",
        "HKLM:\SOFTWARE\WOW6432Node\ASUS",
        "HKLM:\SOFTWARE\WOW6432Node\Dolby"
    )
    
    foreach ($regPath in $registryPaths) {
        if (Test-Path $regPath) {
            Write-Host "Removing registry: $regPath"
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Clean driver services
    Write-Host "Cleaning driver services..."
    $driverServices = @("amdkmdag", "amdkmdap", "AtihdWT6", "AMD*", "RtkAudio*", "MediaTek*")
    
    foreach ($service in $driverServices) {
        $services = Get-Service -Name $service -ErrorAction SilentlyContinue
        foreach ($svc in $services) {
            try {
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                sc.exe delete $svc.Name 2>$null
                Write-Host "Removed service: $($svc.Name)"
            } catch {
                Write-Warning "Failed to remove service: $($svc.Name)"
            }
        }
    }
}

# Function to clean driver files from system folders
function Clean-DriverFiles {
    Write-Host "--- Cleaning Driver Files ---" -ForegroundColor Yellow
    
    $driverFolders = @(
        "C:\Windows\System32\drivers",
        "C:\Windows\System32\DriverStore\FileRepository",
        "C:\AMD",
        "C:\Program Files\AMD",
        "C:\Program Files (x86)\AMD",
        "C:\Program Files\Realtek",
        "C:\Program Files (x86)\Realtek",
        "C:\Program Files\ASUS",
        "C:\Program Files (x86)\ASUS"
    )
    
    $driverPatterns = @("*amd*", "*ati*", "*realtek*", "*mediatek*", "*asus*", "*dolby*", "*cirrus*")
    
    foreach ($folder in $driverFolders) {
        if (Test-Path $folder) {
            foreach ($pattern in $driverPatterns) {
                $files = Get-ChildItem -Path $folder -Filter $pattern -Recurse -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    try {
                        Write-Host "Removing: $($file.FullName)"
                        Remove-Item -Path $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
                    } catch {
                        # File might be in use, skip
                    }
                }
            }
        }
    }
}

# Function to clean driver store
function Clean-DriverStore {
    Write-Host "--- Cleaning Driver Store ---" -ForegroundColor Yellow
    
    # Get all third-party drivers
    $installedDrivers = pnputil /enum-drivers | Where-Object { $_ -like "*Published Name*" -or $_ -like "*Provider*" }
    
    # Remove AMD, Realtek, MediaTek, ASUS drivers from driver store
    $driverProviders = @("AMD", "ATI", "Realtek", "MediaTek", "ASUS", "Dolby", "Cirrus")
    
    for ($i = 0; $i -lt $installedDrivers.Length; $i += 2) {
        if ($installedDrivers[$i] -like "*Published Name*") {
            $driverName = ($installedDrivers[$i] -split ":")[1].Trim()
            if ($i + 1 -lt $installedDrivers.Length -and $installedDrivers[$i + 1] -like "*Provider*") {
                $provider = ($installedDrivers[$i + 1] -split ":")[1].Trim()
                
                foreach ($targetProvider in $driverProviders) {
                    if ($provider -like "*$targetProvider*") {
                        Write-Host "Removing driver from store: $driverName ($provider)"
                        pnputil /delete-driver $driverName /uninstall /force 2>$null
                        break
                    }
                }
            }
        }
    }
}

# Function to force-close stubborn installer dialogs
function Stop-InstallerDialogs {
    $dialogProcesses = @(
        "Setup",
        "InstallShield*",
        "Inno Setup*",
        "NSIS*",
        "WiseInstaller*",
        "MSI*",
        "*installer*"
    )
    
    foreach ($pattern in $dialogProcesses) {
        Get-Process -Name $pattern -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "Force closing installer dialog: $($_.ProcessName)"
            $_.CloseMainWindow()
            Start-Sleep 1
            if (-not $_.HasExited) {
                $_.Kill()
            }
        }
    }
}

# Function to restart required services
function Restart-RequiredServices {
    Write-Host "--- Restarting Required Services ---" -ForegroundColor Yellow
    
    $services = @("wuauserv", "AudioSrv", "AudioEndpointBuilder", "Themes", "UxSms")
    
    foreach ($service in $services) {
        try {
            Write-Host "Restarting service: $service"
            Restart-Service -Name $service -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Failed to restart service: $service"
        }
    }
}
function Stop-InstallerDialogs {
    $dialogProcesses = @(
        "Setup",
        "InstallShield*",
        "Inno Setup*",
        "NSIS*",
        "WiseInstaller*",
        "MSI*",
        "*installer*"
    )
    
    foreach ($pattern in $dialogProcesses) {
        Get-Process -Name $pattern -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "Force closing installer dialog: $($_.ProcessName)"
            $_.CloseMainWindow()
            Start-Sleep 1
            if (-not $_.HasExited) {
                $_.Kill()
            }
        }
    }
}

# Enhanced dialog handler that also sends keystrokes
function Start-DialogHandler {
    $job = Start-Job -ScriptBlock {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);
    
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
    
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
    
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    
    public const uint WM_COMMAND = 0x0111;
    public const uint BM_CLICK = 0x00F5;
    public const uint WM_KEYDOWN = 0x0100;
    public const uint WM_CHAR = 0x0102;
    public const uint VK_RETURN = 0x0D;
    public const uint VK_ESCAPE = 0x1B;
    public const int SW_HIDE = 0;
    public const int SW_MINIMIZE = 6;
}
"@
        
        # Add SendKeys functionality
        Add-Type -AssemblyName System.Windows.Forms
        
        while ($true) {
            Start-Sleep 500
            
            # Find all visible windows and check for installer dialogs
            $windowFound = $false
            
            # Common dialog window classes and titles
            $dialogPatterns = @(
                "*Setup*",
                "*Install*",
                "*Language*",
                "*ASUS*",
                "*AMD*",
                "*Realtek*",
                "*MediaTek*",
                "*Driver*",
                "*Wizard*"
            )
            
            foreach ($pattern in $dialogPatterns) {
                $processes = Get-Process | Where-Object { $_.MainWindowTitle -like $pattern -and $_.MainWindowHandle -ne 0 }
                
                foreach ($process in $processes) {
                    $hwnd = $process.MainWindowHandle
                    if ($hwnd -ne [IntPtr]::Zero) {
                        # Try to find and click OK, Next, Continue buttons
                        $buttonTexts = @("OK", "Next", "Continue", "Install", "Accept", "Agree", "Yes", "&OK", "&Next")
                        
                        foreach ($buttonText in $buttonTexts) {
                            $buttonHwnd = [Win32]::FindWindowEx($hwnd, [IntPtr]::Zero, "Button", $buttonText)
                            if ($buttonHwnd -ne [IntPtr]::Zero) {
                                [Win32]::PostMessage($buttonHwnd, [Win32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)
                                $windowFound = $true
                                break
                            }
                        }
                        
                        # If no button found, try sending Enter key
                        if (-not $windowFound) {
                            [Win32]::SetForegroundWindow($hwnd)
                            [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
                            $windowFound = $true
                        }
                        
                        if ($windowFound) {
                            break
                        }
                    }
                }
                
                if ($windowFound) {
                    break
                }
            }
        }
    }
    return $job
}

# Function to install all driver EXE files with complete silence
function Install-AllDrivers {
    Write-Host "=== Installing All Driver Files (Completely Silent) ===" -ForegroundColor Green
    
    if (-not (Test-Path $AsusPath)) {
        Write-Error "Asus folder not found at: $AsusPath"
        return
    }
    
    # Get all .exe files in the Asus folder
    $driverFiles = Get-ChildItem -Path $AsusPath -Filter "*.exe" | Sort-Object Name
    
    if ($driverFiles.Count -eq 0) {
        Write-Warning "No .exe driver files found in: $AsusPath"
        return
    }
    
    Write-Host "Found $($driverFiles.Count) driver files to install:"
    $driverFiles | ForEach-Object { Write-Host "  - $($_.Name)" }
    
    # Start dialog handler job
    Write-Host "Starting automated dialog handler..."
    $dialogJob = Start-DialogHandler
    
    # Install each driver
    foreach ($driver in $driverFiles) {
        Write-Host "`n--- Installing: $($driver.Name) ---" -ForegroundColor Yellow
        
        try {
            # Comprehensive silent installation arguments for different installer types
            $silentArguments = @(
                @("/S", "/SILENT", "/VERYSILENT", "/SP-", "/SUPPRESSMSGBOXES", "/NORESTART"),
                @("/quiet", "/passive", "/norestart"),
                @("/qn", "/norestart"),
                @("/s", "/v/qn"),
                @("/SILENT", "/NORESTART"),
                @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-"),
                @("-silent", "-passive"),
                @("--silent", "--quiet"),
                @("/quiet", "/norestart", "/L*v", "$env:temp\install.log"),
                @("/S", "/v/qn"),
                @("/qb!", "/norestart")
            )
            
            $installSuccess = $false
            
            # Try different silent installation methods
            foreach ($args in $silentArguments) {
                try {
                    Write-Host "Trying silent install with: $($args -join ' ')"
                    
                    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                    $processInfo.FileName = $driver.FullName
                    $processInfo.Arguments = $args -join ' '
                    $processInfo.UseShellExecute = $false
                    $processInfo.CreateNoWindow = $true
                    $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
                    
                    $process = [System.Diagnostics.Process]::Start($processInfo)
                    
                    # Wait for process with timeout
                    $timeout = 300000 # 5 minutes
                    if ($process.WaitForExit($timeout)) {
                        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) { # 3010 = success but reboot required
                            Write-Host "✓ Successfully installed: $($driver.Name)" -ForegroundColor Green
                            $installSuccess = $true
                            break
                        }
                    } else {
                        Write-Warning "Installation timed out for: $($driver.Name)"
                        $process.Kill()
                    }
                } catch {
                    # Continue to next method
                }
            }
            
            # If all silent methods failed, try extraction method
            if (-not $installSuccess) {
                Write-Host "Trying extraction method..."
                try {
                    # Many ASUS drivers are self-extracting archives
                    $extractPath = Join-Path $env:temp "driver_extract_$(Get-Random)"
                    New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
                    
                    # Try to extract with common extraction arguments
                    $extractArgs = @("/extract:$extractPath", "/x:$extractPath", "-x$extractPath")
                    
                    foreach ($arg in $extractArgs) {
                        try {
                            $process = Start-Process -FilePath $driver.FullName -ArgumentList $arg -Wait -PassThru -NoNewWindow -WindowStyle Hidden
                            if ($process.ExitCode -eq 0) {
                                # Look for setup.exe or install.exe in extracted folder
                                $setupFiles = Get-ChildItem -Path $extractPath -Filter "setup.exe" -Recurse
                                if ($setupFiles.Count -eq 0) {
                                    $setupFiles = Get-ChildItem -Path $extractPath -Filter "install.exe" -Recurse
                                }
                                
                                if ($setupFiles.Count -gt 0) {
                                    $setupFile = $setupFiles[0]
                                    Write-Host "Found extracted installer: $($setupFile.Name)"
                                    
                                    # Try to run extracted installer silently
                                    $silentProcess = Start-Process -FilePath $setupFile.FullName -ArgumentList "/S /SILENT /VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -PassThru -NoNewWindow -WindowStyle Hidden
                                    if ($silentProcess.ExitCode -eq 0) {
                                        Write-Host "✓ Successfully installed via extraction: $($driver.Name)" -ForegroundColor Green
                                        $installSuccess = $true
                                    }
                                }
                                break
                            }
                        } catch {
                            # Continue to next extraction method
                        }
                    }
                    
                    # Clean up extraction folder
                    Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Warning "Extraction method failed for: $($driver.Name)"
                }
            }
            
            if (-not $installSuccess) {
                Write-Warning "All installation methods failed for: $($driver.Name)"
            }
            
        } catch {
            Write-Error "Failed to install $($driver.Name): $($_.Exception.Message)"
        }
        
        # Wait between installations
        Start-Sleep 3
    }
    
    # Stop dialog handler job
    if ($dialogJob) {
        Write-Host "Stopping dialog handler..."
        Stop-Job $dialogJob -ErrorAction SilentlyContinue
        Remove-Job $dialogJob -ErrorAction SilentlyContinue
    }
}

# Function to show usage
function Show-Usage {
    Write-Host @"
ASUS Driver Installer Script with Complete Driver Purge

Usage Examples:
  .\script.ps1 -NetworkOnly           # Purge network drivers, then install new ones
  .\script.ps1 -AllDrivers           # Purge ALL drivers, then install from Asus folder
  .\script.ps1 -NetworkOnly -WiFiName "MyWiFi" -WiFiPassword "MyPassword"
  .\script.ps1 -AllDrivers -AsusPath "C:\Drivers\Asus"

Parameters:
  -NetworkOnly    Purge existing network drivers, then install new ones (like fixnet)
  -AllDrivers     Purge ALL existing drivers, then install all .exe files from Asus folder
  -AsusPath       Path to Asus drivers folder (default: F:\backup\windowsapps\install\Asus)
  -WiFiName       WiFi network name (default: Stella_5)
  -WiFiPassword   WiFi password (default: Stellamylove)

⚠️  WARNING: This script will COMPLETELY REMOVE existing drivers before installing new ones!
   It requires Administrator privileges and will modify system drivers extensively!

Driver Purge Process:
  1. Stops Windows Update service
  2. Uninstalls AMD/Radeon drivers and software
  3. Removes audio drivers (Realtek, Dolby, Cirrus)
  4. Purges network drivers (MediaTek, WiFi, Bluetooth)
  5. Removes ASUS software and drivers
  6. Cleans registry entries and driver store
  7. Removes driver files from system folders
  8. Installs fresh drivers from Asus folder
  9. Restarts required services

💡 This ensures a completely clean driver installation without conflicts!
"@
}

# Main script logic
Write-Host "ASUS Driver Installer with Complete Driver Purge" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "⚠️  IMPORTANT: This script will COMPLETELY PURGE existing drivers first!" -ForegroundColor Red
Write-Host "This ensures a clean installation without conflicts." -ForegroundColor Yellow
Write-Host "Process: Purge → Install → Configure → Restart Services`n" -ForegroundColor Green

# Validate parameters
if (-not $NetworkOnly -and -not $AllDrivers) {
    Write-Host "No installation option specified. Please choose -NetworkOnly or -AllDrivers" -ForegroundColor Red
    Show-Usage
    exit 1
}

if ($NetworkOnly -and $AllDrivers) {
    Write-Host "Please specify either -NetworkOnly OR -AllDrivers, not both" -ForegroundColor Red
    Show-Usage
    exit 1
}

# Execute based on parameters
if ($NetworkOnly) {
    # Purge existing network drivers first
    Write-Host "STEP 1: Purging existing drivers..." -ForegroundColor Cyan
    Remove-NetworkDrivers
    Clean-DriverRegistry
    Clean-DriverStore
    
    Write-Host "STEP 2: Installing new network drivers..." -ForegroundColor Cyan
    Install-NetworkDrivers
    
    Write-Host "STEP 3: Restarting services..." -ForegroundColor Cyan
    Restart-RequiredServices
    
    Write-Host "`n=== Network Driver Installation Complete ===" -ForegroundColor Green
}

if ($AllDrivers) {
    # Complete driver purge first
    Write-Host "STEP 1: Complete driver purge..." -ForegroundColor Cyan
    Remove-ExistingDrivers
    
    Write-Host "STEP 2: Installing new drivers..." -ForegroundColor Cyan
    Install-AllDrivers
    
    Write-Host "STEP 3: Restarting services..." -ForegroundColor Cyan
    Restart-RequiredServices
    
    Write-Host "`n=== All Driver Installation Complete ===" -ForegroundColor Green
}

Write-Host "`nScript execution completed. Please restart your computer to ensure all drivers are properly loaded." -ForegroundColor Yellow
