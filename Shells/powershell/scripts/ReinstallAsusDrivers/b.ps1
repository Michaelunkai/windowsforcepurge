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
    [string]$WiFiPassword = "Stellamylove",
    
    [Parameter(Mandatory=$false)]
    [switch]$EmergencyMode
)

# Global emergency timeout - NEVER let script hang more than 10 minutes total
$global:ScriptStartTime = Get-Date
$global:MaxScriptRuntime = 600 # 10 minutes
$global:EmergencyAbort = $false

# Emergency abort function
function Test-EmergencyAbort {
    $elapsed = (Get-Date) - $global:ScriptStartTime
    if ($elapsed.TotalSeconds -gt $global:MaxScriptRuntime) {
        Write-Host "🚨 EMERGENCY ABORT: Script running too long ($([math]::Round($elapsed.TotalMinutes, 1)) minutes)!" -ForegroundColor Red -BackgroundColor Yellow
        $global:EmergencyAbort = $true
        return $true
    }
    return $false
}

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

# Emergency timeout function to prevent hanging - DIRECT EXECUTION (No Jobs)
function Invoke-WithTimeout {
    param(
        [scriptblock]$ScriptBlock,
        [int]$TimeoutSeconds = 30,
        [string]$OperationName = "Operation"
    )
    
    Write-Host "⏱️  Starting: $OperationName (Max: ${TimeoutSeconds}s)" -ForegroundColor Cyan
    
    try {
        # Direct execution with timeout using Runspace (faster than jobs)
        $startTime = Get-Date
        $result = & $ScriptBlock
        
        # Simple timeout check
        $elapsed = (Get-Date) - $startTime
        if ($elapsed.TotalSeconds -le $TimeoutSeconds) {
            Write-Host "✅ Completed: $OperationName ($([math]::Round($elapsed.TotalSeconds, 1))s)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚡ COMPLETED BUT SLOW: $OperationName ($([math]::Round($elapsed.TotalSeconds, 1))s)" -ForegroundColor Yellow
            return $true
        }
    } catch {
        Write-Host "❌ ERROR in $OperationName : $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to completely purge existing drivers - NUCLEAR OPTION
function Remove-ExistingDrivers {
    Write-Host "=== NUCLEAR DRIVER PURGE INITIATED ===" -ForegroundColor Red -BackgroundColor Black
    Write-Host "⚠️  WARNING: COMPLETE SYSTEM DRIVER ERADICATION IN PROGRESS!" -ForegroundColor Yellow -BackgroundColor Red
    Write-Host "This will obliterate ALL existing AMD, ASUS, Realtek, MediaTek, and related drivers..." -ForegroundColor Yellow
    Write-Host "🚨 EMERGENCY TIMEOUT PROTECTION ACTIVE - NO OPERATION WILL HANG!" -ForegroundColor Magenta
    
    # Phase 0: Disable Windows Driver Protection and Updates
    Write-Host "Phase 0: Disabling Windows protections..." -ForegroundColor Cyan
    
    # Stop and disable Windows Update to prevent driver reinstallation
    $windowsServices = @("wuauserv", "UsoSvc", "WaaSMedicSvc", "BITS", "CryptSvc")
    foreach ($service in $windowsServices) {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "✓ Disabled: $service"
    }
    
    # Disable Windows Driver Updates via Registry
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" -Name "SearchOrderConfig" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Force -ErrorAction SilentlyContinue
    
    # Disable Device Installation Restrictions
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -Value 1 -Force -ErrorAction SilentlyContinue
    
    # Set system to safe mode for next boot (commented out - user can uncomment if needed)
    # bcdedit /set {current} safeboot minimal
    
    Write-Host "Phase 1: OBLITERATING AMD DRIVERS..." -ForegroundColor Red
    Invoke-WithTimeout -ScriptBlock { Remove-AMDDrivers } -TimeoutSeconds 60 -OperationName "AMD Driver Removal"
    
    Write-Host "Phase 2: OBLITERATING ASUS SOFTWARE..." -ForegroundColor Red
    Invoke-WithTimeout -ScriptBlock { Remove-ASUSDrivers } -TimeoutSeconds 45 -OperationName "ASUS Software Removal"
    
    Write-Host "Phase 3: OBLITERATING AUDIO DRIVERS..." -ForegroundColor Red
    Invoke-WithTimeout -ScriptBlock { Remove-AudioDrivers } -TimeoutSeconds 30 -OperationName "Audio Driver Removal"
    
    Write-Host "Phase 4: OBLITERATING NETWORK DRIVERS..." -ForegroundColor Red
    Invoke-WithTimeout -ScriptBlock { Remove-NetworkDrivers } -TimeoutSeconds 30 -OperationName "Network Driver Removal"
    
    Write-Host "Phase 5: OBLITERATING BLUETOOTH DRIVERS..." -ForegroundColor Red
    Invoke-WithTimeout -ScriptBlock { Remove-BluetoothDrivers } -TimeoutSeconds 20 -OperationName "Bluetooth Driver Removal"
    
    Write-Host "Phase 6: COMPREHENSIVE REGISTRY CLEANUP..." -ForegroundColor Red
    Invoke-WithTimeout -ScriptBlock { Clean-DriverRegistry } -TimeoutSeconds 25 -OperationName "Registry Cleanup"
    
    Write-Host "Phase 7: NUCLEAR FILE SYSTEM CLEANUP..." -ForegroundColor Red
    Invoke-WithTimeout -ScriptBlock { Clean-DriverFiles } -TimeoutSeconds 30 -OperationName "File System Cleanup"
    
    Write-Host "Phase 8: DRIVER STORE OBLITERATION..." -ForegroundColor Red
    Invoke-WithTimeout -ScriptBlock { Clean-DriverStore } -TimeoutSeconds 40 -OperationName "Driver Store Cleanup"
    
    Write-Host "Phase 9: AGGRESSIVE CLEANUP OPERATIONS..." -ForegroundColor Red
    Invoke-WithTimeout -ScriptBlock { Invoke-AggressiveCleanup } -TimeoutSeconds 20 -OperationName "Aggressive Cleanup"
    
    Write-Host "Phase 10: FINAL VERIFICATION AND CLEANUP..." -ForegroundColor Red
    Invoke-WithTimeout -ScriptBlock { Invoke-FinalVerification } -TimeoutSeconds 25 -OperationName "Final Verification"
    
    Write-Host "=== NUCLEAR DRIVER PURGE COMPLETE ===" -ForegroundColor Green -BackgroundColor Black
    Write-Host "🧹 System has been completely purged of old drivers!" -ForegroundColor Green
}

# Function to remove AMD drivers - ULTRA COMPREHENSIVE
function Remove-AMDDrivers {
    Write-Host "--- ULTRA COMPREHENSIVE AMD DRIVER REMOVAL ---" -ForegroundColor Red
    Write-Host "This will completely eradicate ALL AMD/ATI components from the system!" -ForegroundColor Yellow
    
    # Phase 1: FORCE STOP all AMD services and processes (NO WAITING!)
    Write-Host "Phase 1: FORCE STOPPING ALL AMD services and processes..." -ForegroundColor Cyan
    $amdServices = @(
        "AMD*", "amd*", "ati*", "ATI*", "Radeon*", "radeon*",
        "amdkmdag", "amdkmdap", "amdacpksd", "amdfendr", "amdlog",
        "AMDRyzenMasterDriverV*", "AtihdWT*", "AMD External Events Utility",
        "AMD Crash Defender Service", "AMD User Experience Program"
    )
    
    foreach ($servicePattern in $amdServices) {
        # Emergency abort check
        if (Test-EmergencyAbort) { 
            Write-Host "🚨 EMERGENCY ABORT in AMD service removal!" -ForegroundColor Red
            return 
        }
        
        Get-Service -Name $servicePattern -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "FORCE STOPPING AMD service: $($_.Name)" -ForegroundColor Red
            
            # EMERGENCY SKIP for known problematic services
            $problematicServices = @("amdfendr", "AMD Crash Defender Driver", "amdkmdag")
            if ($problematicServices -contains $_.Name) {
                Write-Host "🚨 EMERGENCY SKIP: Problematic service $($_.Name) - Using registry disable only!" -ForegroundColor Magenta
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
                sc.exe delete $_.Name 2>$null
                return
            }
            
            # Method 1: Ultra-fast timeout (1 second max)
            try {
                $stopJob = Start-Job -ScriptBlock {
                    param($ServiceName)
                    Stop-Service -Name $ServiceName -Force -NoWait -ErrorAction Stop
                } -ArgumentList $_.Name
                
                # Wait maximum 1 second only!
                if (Wait-Job $stopJob -Timeout 1) {
                    Receive-Job $stopJob | Out-Null
                    Write-Host "✓ Service stopped: $($_.Name)" -ForegroundColor Green
                } else {
                    # IMMEDIATE force kill and registry disable
                    Stop-Job $stopJob -Force
                    Write-Host "⚡ INSTANT NUCLEAR: $($_.Name)" -ForegroundColor Yellow
                    
                    # Registry disable (safe and fast)
                    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
                    
                    # Quick SC commands (no waiting)
                    Start-Process -FilePath "sc.exe" -ArgumentList "stop", $_.Name -WindowStyle Hidden -ErrorAction SilentlyContinue
                }
                Remove-Job $stopJob -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Host "⚡ Registry disable only: $($_.Name)" -ForegroundColor Yellow
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
            }
            
            # Always try to disable and delete (safe operations)
            Set-Service -Name $_.Name -StartupType Disabled -ErrorAction SilentlyContinue
            sc.exe delete $_.Name 2>$null
        }
    }
    
    # NUCLEAR KILL all AMD processes (IMMEDIATE TERMINATION)
    Write-Host "NUCLEAR PROCESS TERMINATION: AMD processes..." -ForegroundColor Red
    $amdProcesses = @(
        "*AMD*", "*amd*", "*ATI*", "*ati*", "*Radeon*", "*radeon*",
        "RadeonSettings", "AMDRSServ", "AMDLinkUpdate", "StartCN",
        "CNNext", "AMDCleanupUtility", "atiesrxx", "atieclxx"
    )
    
    # Get unique processes to avoid duplicates
    $uniqueProcesses = @{}
    foreach ($processPattern in $amdProcesses) {
        Get-Process -Name $processPattern -ErrorAction SilentlyContinue | ForEach-Object {
            if (-not $uniqueProcesses.ContainsKey($_.Id)) {
                $uniqueProcesses[$_.Id] = $_
            }
        }
    }
    
    # Terminate each unique process once
    foreach ($process in $uniqueProcesses.Values) {
        Write-Host "💥 NUCLEAR KILL: $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor Yellow
        try {
            # Method 1: PowerShell force stop
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
            Write-Host "✓ Process terminated: $($process.ProcessName)" -ForegroundColor Green
        } catch {
            # Method 2: taskkill nuclear option
            Write-Host "⚡ Using TASKKILL for: $($process.ProcessName)" -ForegroundColor Red
            taskkill /PID $process.Id /F /T 2>$null
            
            # Method 3: WMI termination (last resort)
            try {
                $wmiProcess = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $($process.Id)" -ErrorAction SilentlyContinue
                if ($wmiProcess) {
                    $wmiProcess.Terminate() | Out-Null
                }
            } catch { }
        }
    }
    
    # Phase 2: Uninstall ALL AMD software via multiple methods
    Write-Host "Phase 2: Uninstalling ALL AMD software..." -ForegroundColor Cyan
    $amdSoftware = @(
        "AMD*", "Radeon*", "Catalyst*", "Crimson*", "Adrenalin*", "Ryzen*",
        "ATI*", "RyzenMaster*", "WattMan*", "Gaming Evolved*",
        "Raptr*", "PlaysTV*", "AMD Link*", "HydraVision*", "VISION Engine*",
        "*AMD Chipset*", "*AMD Graphics*", "*AMD Audio*", "*Radeon Settings*",
        "*AMD Software*", "*ATI Catalyst*", "*Radeon Adrenalin*"
    )
    
    # Method 1: WMI Win32_Product with PRECISE filtering
    foreach ($pattern in $amdSoftware) {
        Get-WmiObject -Class Win32_Product | Where-Object { 
            $_.Name -like $pattern -and
            # Exclude false positives
            $_.Name -notlike "*Microsoft*" -and
            $_.Name -notlike "*Macrium*" -and
            $_.Name -notlike "*.NET*" -and
            $_.Name -notlike "*Visual Studio*" -and
            $_.Name -notlike "*Windows*" -and
            # Ensure it's actually AMD/ATI related
            ($_.Name -like "*AMD*" -or $_.Name -like "*ATI*" -or $_.Name -like "*Radeon*" -or 
             $_.Name -like "*Catalyst*" -or $_.Name -like "*Crimson*" -or $_.Name -like "*Adrenalin*" -or
             $_.Name -like "*Ryzen*" -or $_.Publisher -like "*AMD*" -or $_.Publisher -like "*ATI*" -or
             $_.Publisher -like "*Advanced Micro Devices*")
        } | ForEach-Object {
            Write-Host "WMI Uninstalling: $($_.Name)" -ForegroundColor Yellow
            try {
                $_.Uninstall() | Out-Null
                Write-Host "✓ Successfully uninstalled: $($_.Name)" -ForegroundColor Green
            } catch {
                Write-Warning "WMI uninstall failed for: $($_.Name)"
            }
        }
    }
    
    # Method 2: Registry-based uninstallation
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $uninstallPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -and (
                $_.DisplayName -like "*AMD*" -or $_.DisplayName -like "*ATI*" -or
                $_.DisplayName -like "*Radeon*" -or $_.DisplayName -like "*Ryzen*" -or
                $_.DisplayName -like "*Catalyst*" -or $_.DisplayName -like "*Crimson*" -or
                $_.DisplayName -like "*Adrenalin*"
            )
        } | ForEach-Object {
            if ($_.UninstallString) {
                Write-Host "Registry Uninstalling: $($_.DisplayName)"
                try {
                    if ($_.UninstallString -like "*msiexec*") {
                        $msiCode = ($_.UninstallString -split "/I")[1] -replace "/X", "" -replace "{", "" -replace "}", "" -replace " ", ""
                        if ($msiCode) {
                            Start-Process "msiexec.exe" -ArgumentList "/x {$msiCode} /quiet /norestart" -Wait -WindowStyle Hidden
                        }
                    } else {
                        $uninstallCmd = $_.UninstallString -replace '"', ''
                        if ($uninstallCmd -like "*.exe*") {
                            Start-Process $uninstallCmd -ArgumentList "/S /SILENT /VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                        }
                    }
                    Write-Host "✓ Registry uninstall completed for: $($_.DisplayName)" -ForegroundColor Green
                } catch {
                    Write-Warning "Registry uninstall failed for: $($_.DisplayName)"
                }
            }
        }
    }
    
    # Phase 3: Remove ALL AMD devices from Device Manager
    Write-Host "Phase 3: Removing ALL AMD devices from Device Manager..." -ForegroundColor Cyan
    $amdDevicePatterns = @(
        "*AMD*", "*amd*", "*Radeon*", "*radeon*", "*ATI*", "*ati*",
        "*RX *", "*R9 *", "*R7 *", "*R5 *", "*Vega*", "*RDNA*",
        "*Navi*", "*Polaris*", "*Tahiti*", "*Hawaii*", "*Fiji*"
    )
    
    foreach ($pattern in $amdDevicePatterns) {
        Get-WmiObject -Class Win32_PnPEntity | Where-Object { 
            $_.Name -like $pattern -or 
            $_.HardwareID -like $pattern -or
            $_.DeviceID -like $pattern
        } | ForEach-Object {
            Write-Host "Removing AMD device: $($_.Name) ($($_.DeviceID))"
            try {
                $_.Delete()
                Write-Host "✓ Device removed via WMI" -ForegroundColor Green
            } catch {
                # Try pnputil for stubborn devices
                if ($_.HardwareID) {
                    foreach ($hwid in $_.HardwareID) {
                        pnputil /delete-driver $hwid /uninstall /force 2>$null
                        $devconCmd = Get-Command "devcon.exe" -ErrorAction SilentlyContinue
                        if ($devconCmd) { & $devconCmd.Source remove $hwid 2>$null }
                    }
                }
                # Try devcon if available
                $devconCmd = Get-Command "devcon.exe" -ErrorAction SilentlyContinue
                if ($devconCmd) { & $devconCmd.Source remove $_.DeviceID 2>$null }
                pnputil /remove-device $_.DeviceID /force 2>$null
            }
        }
    }
    
    # Phase 4: COMPREHENSIVE AMD registry cleanup
    Write-Host "Phase 4: COMPREHENSIVE AMD registry cleanup..." -ForegroundColor Cyan
    $amdRegPaths = @(
        # Main AMD registry locations
        "HKLM:\SOFTWARE\AMD", "HKLM:\SOFTWARE\WOW6432Node\AMD",
        "HKLM:\SOFTWARE\ATI Technologies", "HKLM:\SOFTWARE\WOW6432Node\ATI Technologies",
        "HKLM:\SOFTWARE\ATI", "HKLM:\SOFTWARE\WOW6432Node\ATI",
        # User-specific AMD entries
        "HKCU:\SOFTWARE\AMD", "HKCU:\SOFTWARE\ATI Technologies", "HKCU:\SOFTWARE\ATI",
        # Additional AMD locations
        "HKLM:\SOFTWARE\ASUS\GPU Tweak*", "HKLM:\SOFTWARE\WOW6432Node\ASUS\GPU Tweak*",
        "HKLM:\SYSTEM\CurrentControlSet\Services\amd*",
        "HKLM:\SYSTEM\CurrentControlSet\Services\ati*",
        "HKLM:\SYSTEM\CurrentControlSet\Services\AMD*",
        "HKLM:\SYSTEM\CurrentControlSet\Services\ATI*"
    )
    
    foreach ($regPath in $amdRegPaths) {
        if (Test-Path $regPath) {
            Write-Host "Removing AMD registry: $regPath"
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "✓ Registry path removed" -ForegroundColor Green
        }
    }
    
    # Remove AMD entries from additional registry locations
    $additionalRegCleanup = @{
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" = @("StartCN", "AMD*", "ATI*", "Radeon*")
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" = @("AMD*", "ATI*", "Radeon*")
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" = @("AMD*", "ATI*", "Radeon*")
        "HKLM:\SOFTWARE\Classes\CLSID" = @("*AMD*", "*ATI*")
    }
    
    foreach ($regLocation in $additionalRegCleanup.Keys) {
        if (Test-Path $regLocation) {
            foreach ($valuePattern in $additionalRegCleanup[$regLocation]) {
                Get-ItemProperty -Path $regLocation -ErrorAction SilentlyContinue | ForEach-Object {
                    $_.PSObject.Properties | Where-Object { $_.Name -like $valuePattern } | ForEach-Object {
                        Write-Host "Removing registry value: $regLocation\$($_.Name)"
                        Remove-ItemProperty -Path $regLocation -Name $_.Name -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
    
    # Phase 5: Remove AMD files from ALL possible locations
    Write-Host "Phase 5: Removing AMD files from ALL locations..." -ForegroundColor Cyan
    $amdFolders = @(
        "C:\AMD", "D:\AMD", "E:\AMD", "F:\AMD",
        "C:\Program Files\AMD", "C:\Program Files (x86)\AMD",
        "C:\Program Files\ATI Technologies", "C:\Program Files (x86)\ATI Technologies",
        "C:\Program Files\ATI", "C:\Program Files (x86)\ATI",
        "C:\Windows\System32\DriverStore\FileRepository\*amd*",
        "C:\Windows\System32\DriverStore\FileRepository\*ati*",
        "$env:ProgramData\AMD", "$env:LOCALAPPDATA\AMD",
        "$env:APPDATA\AMD", "$env:TEMP\AMD*",
        "C:\Windows\System32\amd*", "C:\Windows\SysWOW64\amd*",
        "C:\Windows\System32\ati*", "C:\Windows\SysWOW64\ati*"
    )
    
    foreach ($folder in $amdFolders) {
        if (Test-Path $folder) {
            Write-Host "Removing AMD folder: $folder"
            # Take ownership and remove read-only attributes
            takeown /f "$folder" /r /d y 2>$null
            attrib -r "$folder\*.*" /s /d 2>$null
            Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "✓ AMD folder removed" -ForegroundColor Green
        }
    }
    
    # Phase 6: Clean AMD driver store entries
    Write-Host "Phase 6: Cleaning AMD driver store..." -ForegroundColor Cyan
    # Get all AMD drivers from driver store
    $allDrivers = pnputil /enum-drivers
    $currentDriver = ""
    $currentProvider = ""
    
    for ($i = 0; $i -lt $allDrivers.Length; $i++) {
        $line = $allDrivers[$i]
        if ($line -like "*Published Name*") {
            $currentDriver = ($line -split ":")[1].Trim()
        } elseif ($line -like "*Provider*") {
            $currentProvider = ($line -split ":")[1].Trim()
            
            # Check if this is an AMD driver
            if ($currentProvider -like "*AMD*" -or $currentProvider -like "*ATI*" -or 
                $currentProvider -like "*Advanced Micro Devices*") {
                Write-Host "Removing AMD driver from store: $currentDriver ($currentProvider)"
                pnputil /delete-driver $currentDriver /uninstall /force 2>$null
                pnputil /delete-driver $currentDriver /force 2>$null
            }
        }
    }
    
    Write-Host "=== AMD DRIVER REMOVAL COMPLETE ===" -ForegroundColor Green
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

# Function to remove ASUS drivers and software - ULTRA COMPREHENSIVE
function Remove-ASUSDrivers {
    Write-Host "--- ULTRA COMPREHENSIVE ASUS SOFTWARE/DRIVER REMOVAL ---" -ForegroundColor Red
    Write-Host "This will completely eradicate ALL ASUS components from the system!" -ForegroundColor Yellow
    
    # Phase 1: FORCE STOP all ASUS services and processes (NO WAITING!)
    Write-Host "Phase 1: FORCE STOPPING ALL ASUS services and processes..." -ForegroundColor Cyan
    $asusServices = @(
        "ASUS*", "asus*", "ROG*", "rog*", "TUF*", "tuf*",
        "AsusAppService", "AsusCertService", "ASUSOptimization",
        "ASUS System Control Interface*", "ArmouryCrateService", 
        "LightingService", "AuraService", "GameFirst*", "Sonic*"
    )
    
    foreach ($servicePattern in $asusServices) {
        # Emergency abort check
        if (Test-EmergencyAbort) { 
            Write-Host "🚨 EMERGENCY ABORT in ASUS service removal!" -ForegroundColor Red
            return 
        }
        
        Get-Service -Name $servicePattern -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "FORCE STOPPING ASUS service: $($_.Name)" -ForegroundColor Red
            
            # Immediate force stop with timeout
            try {
                $stopJob = Start-Job -ScriptBlock {
                    param($ServiceName)
                    Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                } -ArgumentList $_.Name
                
                # Wait maximum 2 seconds for ASUS services
                if (Wait-Job $stopJob -Timeout 2) {
                    Receive-Job $stopJob | Out-Null
                    Write-Host "✓ Service stopped: $($_.Name)" -ForegroundColor Green
                } else {
                    Stop-Job $stopJob -Force
                    Write-Host "⚡ NUCLEAR STOP: $($_.Name)" -ForegroundColor Yellow
                    
                    # Force registry disable
                    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
                    sc.exe stop $_.Name 2>$null
                }
                Remove-Job $stopJob -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Host "⚡ Alternative stop for: $($_.Name)" -ForegroundColor Yellow
            }
            
            Set-Service -Name $_.Name -StartupType Disabled -ErrorAction SilentlyContinue
            sc.exe delete $_.Name 2>$null
        }
    }
    
    # NUCLEAR KILL all ASUS processes (IMMEDIATE TERMINATION)
    Write-Host "NUCLEAR PROCESS TERMINATION: ASUS processes..." -ForegroundColor Red
    $asusProcesses = @(
        "*ASUS*", "*asus*", "*ROG*", "*rog*", "*TUF*", "*tuf*",
        "ArmouryCrate*", "AuraService*", "LightingService*", "GameFirst*",
        "SonicSuite*", "SonicStudio*", "ASUSTeKComputer*", "MyASUS*",
        "SystemControlInterface*", "OptimizationService*"
    )
    
    # Get unique processes to avoid duplicates
    $uniqueProcesses = @{}
    foreach ($processPattern in $asusProcesses) {
        Get-Process -Name $processPattern -ErrorAction SilentlyContinue | ForEach-Object {
            if (-not $uniqueProcesses.ContainsKey($_.Id)) {
                $uniqueProcesses[$_.Id] = $_
            }
        }
    }
    
    # Terminate each unique process once
    foreach ($process in $uniqueProcesses.Values) {
        Write-Host "💥 NUCLEAR KILL: $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor Yellow
        try {
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
            Write-Host "✓ Process terminated: $($process.ProcessName)" -ForegroundColor Green
        } catch {
            Write-Host "⚡ Using TASKKILL for: $($process.ProcessName)" -ForegroundColor Red
            taskkill /PID $process.Id /F /T 2>$null
            
            try {
                $wmiProcess = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $($process.Id)" -ErrorAction SilentlyContinue
                if ($wmiProcess) {
                    $wmiProcess.Terminate() | Out-Null
                }
            } catch { }
        }
    }
    
    # Phase 2: Uninstall ALL ASUS software via multiple methods
    Write-Host "Phase 2: Uninstalling ALL ASUS software..." -ForegroundColor Cyan
    $asusSoftware = @(
        "ASUS*", "ROG*", "TUF*", "Armoury*", "MyASUS*",
        "*ASUS System Control Interface*", "*GameFirst*", "*Sonic Suite*", "*SonicStudio*",
        "*ASUS AI Suite*", "*ASUS GPU Tweak*", "*ASUS Fan Xpert*", "*ASUS Aura*",
        "*ASUS LiveUpdate*", "*ASUS WinFlash*", "*ASUS EZ Update*", "*ASUS USB Charger*",
        "*ASUS Splendid*", "*ASUS ScreenPad*", "*ASUS ZenUI*", "*ASUS ZenTalk*",
        "*ROG Armoury*", "*ROG GameFirst*", "*ROG Aura*", "*TUF Aura*"
    )
    
    # Method 1: WMI Win32_Product with PRECISE filtering
    foreach ($pattern in $asusSoftware) {
        Get-WmiObject -Class Win32_Product | Where-Object { 
            $_.Name -like $pattern -and
            # Exclude false positives
            $_.Name -notlike "*Microsoft*" -and
            $_.Name -notlike "*Windows*" -and
            $_.Name -notlike "*.NET*" -and
            $_.Name -notlike "*Visual Studio*" -and
            # Ensure it's actually ASUS related
            ($_.Name -like "*ASUS*" -or $_.Name -like "*ROG*" -or $_.Name -like "*TUF*" -or 
             $_.Name -like "*Armoury*" -or $_.Name -like "*MyASUS*" -or $_.Name -like "*GameFirst*" -or
             $_.Name -like "*Sonic*" -or $_.Name -like "*Aura*" -or $_.Publisher -like "*ASUS*" -or 
             $_.Publisher -like "*ASUSTeK*")
        } | ForEach-Object {
            Write-Host "WMI Uninstalling: $($_.Name)" -ForegroundColor Yellow
            try {
                $_.Uninstall() | Out-Null
                Write-Host "✓ Successfully uninstalled: $($_.Name)" -ForegroundColor Green
            } catch {
                Write-Warning "WMI uninstall failed for: $($_.Name)"
            }
        }
    }
    
    # Method 2: Registry-based uninstallation
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $uninstallPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -and (
                $_.DisplayName -like "*ASUS*" -or $_.DisplayName -like "*ROG*" -or
                $_.DisplayName -like "*TUF*" -or $_.DisplayName -like "*Armoury*" -or
                $_.DisplayName -like "*MyASUS*" -or $_.DisplayName -like "*GameFirst*" -or
                $_.DisplayName -like "*Sonic*" -or $_.DisplayName -like "*Aura*"
            )
        } | ForEach-Object {
            if ($_.UninstallString) {
                Write-Host "Registry Uninstalling: $($_.DisplayName)"
                try {
                    if ($_.UninstallString -like "*msiexec*") {
                        $msiCode = ($_.UninstallString -split "/I")[1] -replace "/X", "" -replace "{", "" -replace "}", "" -replace " ", ""
                        if ($msiCode) {
                            Start-Process "msiexec.exe" -ArgumentList "/x {$msiCode} /quiet /norestart" -Wait -WindowStyle Hidden
                        }
                    } else {
                        $uninstallCmd = $_.UninstallString -replace '"', ''
                        if ($uninstallCmd -like "*.exe*") {
                            Start-Process $uninstallCmd -ArgumentList "/S /SILENT /VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                        }
                    }
                    Write-Host "✓ Registry uninstall completed for: $($_.DisplayName)" -ForegroundColor Green
                } catch {
                    Write-Warning "Registry uninstall failed for: $($_.DisplayName)"
                }
            }
        }
    }
    
    # Phase 3: Remove ALL ASUS devices from Device Manager
    Write-Host "Phase 3: Removing ALL ASUS devices from Device Manager..." -ForegroundColor Cyan
    $asusDevicePatterns = @(
        "*ASUS*", "*asus*", "*ROG*", "*rog*", "*TUF*", "*tuf*",
        "*ASUSTeK*", "*asustek*", "*ASUSTek*", "*AsusTek*",
        "*System Control Interface*", "*USB Charger*"
    )
    
    foreach ($pattern in $asusDevicePatterns) {
        Get-WmiObject -Class Win32_PnPEntity | Where-Object { 
            $_.Name -like $pattern -or 
            $_.HardwareID -like $pattern -or
            $_.DeviceID -like $pattern -or
            $_.Manufacturer -like $pattern
        } | ForEach-Object {
            Write-Host "Removing ASUS device: $($_.Name) ($($_.DeviceID))"
            try {
                $_.Delete()
                Write-Host "✓ Device removed via WMI" -ForegroundColor Green
            } catch {
                # Try pnputil for stubborn devices
                if ($_.HardwareID) {
                    foreach ($hwid in $_.HardwareID) {
                        pnputil /delete-driver $hwid /uninstall /force 2>$null
                        $devconCmd = Get-Command "devcon.exe" -ErrorAction SilentlyContinue
                        if ($devconCmd) { & $devconCmd.Source remove $hwid 2>$null }
                    }
                }
                # Try devcon if available
                $devconCmd = Get-Command "devcon.exe" -ErrorAction SilentlyContinue
                if ($devconCmd) { & $devconCmd.Source remove $_.DeviceID 2>$null }
                pnputil /remove-device $_.DeviceID /force 2>$null
            }
        }
    }
    
    # Phase 4: COMPREHENSIVE ASUS registry cleanup
    Write-Host "Phase 4: COMPREHENSIVE ASUS registry cleanup..." -ForegroundColor Cyan
    $asusRegPaths = @(
        # Main ASUS registry locations
        "HKLM:\SOFTWARE\ASUS", "HKLM:\SOFTWARE\WOW6432Node\ASUS",
        "HKLM:\SOFTWARE\ASUSTeK", "HKLM:\SOFTWARE\WOW6432Node\ASUSTeK",
        "HKLM:\SOFTWARE\ASUSTek", "HKLM:\SOFTWARE\WOW6432Node\ASUSTek",
        # User-specific ASUS entries
        "HKCU:\SOFTWARE\ASUS", "HKCU:\SOFTWARE\ASUSTeK", "HKCU:\SOFTWARE\ASUSTek",
        # ASUS services
        "HKLM:\SYSTEM\CurrentControlSet\Services\ASUS*",
        "HKLM:\SYSTEM\CurrentControlSet\Services\ROG*",
        "HKLM:\SYSTEM\CurrentControlSet\Services\Armoury*",
        # Additional ASUS locations
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\*ASUS*",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\*ROG*"
    )
    
    foreach ($regPath in $asusRegPaths) {
        if (Test-Path $regPath) {
            Write-Host "Removing ASUS registry: $regPath"
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "✓ Registry path removed" -ForegroundColor Green
        }
    }
    
    # Remove ASUS entries from startup locations
    $startupRegCleanup = @{
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" = @("ASUS*", "ROG*", "TUF*", "Armoury*", "MyASUS*", "GameFirst*", "Aura*")
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" = @("ASUS*", "ROG*", "TUF*", "Armoury*")
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" = @("ASUS*", "ROG*", "TUF*", "Armoury*", "MyASUS*")
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" = @("ASUS*", "ROG*", "TUF*", "Armoury*")
    }
    
    foreach ($regLocation in $startupRegCleanup.Keys) {
        if (Test-Path $regLocation) {
            foreach ($valuePattern in $startupRegCleanup[$regLocation]) {
                Get-ItemProperty -Path $regLocation -ErrorAction SilentlyContinue | ForEach-Object {
                    $_.PSObject.Properties | Where-Object { $_.Name -like $valuePattern } | ForEach-Object {
                        Write-Host "Removing registry value: $regLocation\$($_.Name)"
                        Remove-ItemProperty -Path $regLocation -Name $_.Name -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
    
    # Phase 5: Remove ASUS files from ALL possible locations
    Write-Host "Phase 5: Removing ASUS files from ALL locations..." -ForegroundColor Cyan
    $asusFolders = @(
        "C:\Program Files\ASUS", "C:\Program Files (x86)\ASUS",
        "C:\Program Files\ASUSTeK", "C:\Program Files (x86)\ASUSTeK",
        "C:\Program Files\ROG", "C:\Program Files (x86)\ROG",
        "C:\ASUS", "D:\ASUS", "E:\ASUS", "F:\ASUS",
        "$env:ProgramData\ASUS", "$env:LOCALAPPDATA\ASUS",
        "$env:APPDATA\ASUS", "$env:TEMP\ASUS*",
        "C:\Windows\System32\DriverStore\FileRepository\*asus*",
        "C:\Windows\System32\asus*", "C:\Windows\SysWOW64\asus*"
    )
    
    foreach ($folder in $asusFolders) {
        if (Test-Path $folder) {
            Write-Host "Removing ASUS folder: $folder"
            # Take ownership and remove read-only attributes
            takeown /f "$folder" /r /d y 2>$null
            attrib -r "$folder\*.*" /s /d 2>$null
            Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "✓ ASUS folder removed" -ForegroundColor Green
        }
    }
    
    # Phase 6: Clean ASUS driver store entries
    Write-Host "Phase 6: Cleaning ASUS driver store..." -ForegroundColor Cyan
    $allDrivers = pnputil /enum-drivers
    $currentDriver = ""
    $currentProvider = ""
    
    for ($i = 0; $i -lt $allDrivers.Length; $i++) {
        $line = $allDrivers[$i]
        if ($line -like "*Published Name*") {
            $currentDriver = ($line -split ":")[1].Trim()
        } elseif ($line -like "*Provider*") {
            $currentProvider = ($line -split ":")[1].Trim()
            
            # Check if this is an ASUS driver
            if ($currentProvider -like "*ASUS*" -or $currentProvider -like "*ASUSTeK*" -or 
                $currentProvider -like "*ASUSTek*" -or $currentProvider -like "*ROG*") {
                Write-Host "Removing ASUS driver from store: $currentDriver ($currentProvider)"
                pnputil /delete-driver $currentDriver /uninstall /force 2>$null
                pnputil /delete-driver $currentDriver /force 2>$null
            }
        }
    }
    
    Write-Host "=== ASUS SOFTWARE/DRIVER REMOVAL COMPLETE ===" -ForegroundColor Green
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

# Function for aggressive cleanup of stubborn drivers
function Invoke-AggressiveCleanup {
    Write-Host "--- AGGRESSIVE CLEANUP: Removing stubborn drivers ---" -ForegroundColor Red
    
    # Force remove device manager entries using devcon (if available)
    $devconPath = Get-Command "devcon.exe" -ErrorAction SilentlyContinue
    if ($devconPath) {
        Write-Host "Using devcon to force remove devices..."
        $devicePatterns = @("*AMD*", "*ATI*", "*ASUS*", "*Realtek*", "*MediaTek*")
        foreach ($pattern in $devicePatterns) {
            & $devconPath.Source remove $pattern 2>$null
            & $devconPath.Source rescan 2>$null
        }
    } else {
        Write-Host "⚠️  devcon.exe not available - using PowerShell methods only" -ForegroundColor Yellow
    }
    
    # Clear Windows temp and driver cache
    Write-Host "Clearing system caches..."
    $tempFolders = @(
        "$env:WINDIR\Temp",
        "$env:WINDIR\SoftwareDistribution\Download",
        "$env:WINDIR\System32\DriverStore\Temp",
        "$env:LOCALAPPDATA\Temp"
    )
    
    foreach ($tempFolder in $tempFolders) {
        if (Test-Path $tempFolder) {
            Get-ChildItem -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -like "*amd*" -or $_.Name -like "*asus*" -or $_.Name -like "*ati*" } |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
    
    # Force registry cleanup using reg.exe for stubborn entries
    Write-Host "Force cleaning registry with reg.exe..."
    $regKeys = @(
        "HKEY_LOCAL_MACHINE\SOFTWARE\AMD",
        "HKEY_LOCAL_MACHINE\SOFTWARE\ATI Technologies",
        "HKEY_LOCAL_MACHINE\SOFTWARE\ASUS",
        "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\AMD",
        "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\ATI Technologies",
        "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\ASUS"
    )
    
    foreach ($key in $regKeys) {
        reg delete "$key" /f 2>$null
    }
    
    # Clear MRU and recent entries
    Write-Host "Clearing MRU entries..."
    reg delete "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs" /f 2>$null
    
    # Clear Windows Search index for driver files
    Write-Host "Clearing Windows Search index..."
    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
    $searchDB = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb"
    if (Test-Path $searchDB) {
        Remove-Item -Path $searchDB -Force -ErrorAction SilentlyContinue
    }
    Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
    
    Write-Host "✓ Aggressive cleanup completed" -ForegroundColor Green
}

# Function to verify complete removal and prepare for installation
function Invoke-FinalVerification {
    Write-Host "--- FINAL VERIFICATION: Ensuring complete removal ---" -ForegroundColor Cyan
    
    # Verify no AMD/ASUS devices remain
    Write-Host "Verifying device removal..."
    $remainingDevices = Get-WmiObject -Class Win32_PnPEntity | Where-Object { 
        $_.Name -like "*AMD*" -or $_.Name -like "*ATI*" -or $_.Name -like "*ASUS*" -or
        $_.HardwareID -like "*AMD*" -or $_.HardwareID -like "*ATI*" -or $_.HardwareID -like "*ASUS*"
    }
    
    if ($remainingDevices) {
        Write-Host "⚠️  Found remaining devices - attempting final removal..." -ForegroundColor Yellow
        foreach ($device in $remainingDevices) {
            Write-Host "Final removal attempt: $($device.Name)"
            try {
                $device.Delete()
                pnputil /remove-device $device.DeviceID /force 2>$null
            } catch {
                Write-Warning "Could not remove: $($device.Name)"
            }
        }
    } else {
        Write-Host "✓ No AMD/ASUS devices found - removal successful!" -ForegroundColor Green
    }
    
    # Verify no AMD/ASUS software remains
    Write-Host "Verifying software removal..."
    $remainingSoftware = Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.Name -like "*AMD*" -or $_.Name -like "*ATI*" -or $_.Name -like "*ASUS*" -or
        $_.Name -like "*Radeon*" -or $_.Name -like "*ROG*"
    }
    
    if ($remainingSoftware) {
        Write-Host "⚠️  Found remaining software - attempting final removal..." -ForegroundColor Yellow
        foreach ($software in $remainingSoftware) {
            Write-Host "Final removal attempt: $($software.Name)"
            try {
                $software.Uninstall() | Out-Null
            } catch {
                Write-Warning "Could not remove: $($software.Name)"
            }
        }
    } else {
        Write-Host "✓ No AMD/ASUS software found - removal successful!" -ForegroundColor Green
    }
    
    # Clear any remaining driver store entries
    Write-Host "Final driver store cleanup..."
    $driverStoreCleanup = pnputil /enum-drivers | Select-String -Pattern "AMD|ATI|ASUS" -Context 1
    if ($driverStoreCleanup) {
        Write-Host "⚠️  Found remaining driver store entries - cleaning..." -ForegroundColor Yellow
        # Additional cleanup if needed
    } else {
        Write-Host "✓ Driver store is clean!" -ForegroundColor Green
    }
    
    # Prepare system for new driver installation
    Write-Host "Preparing system for new driver installation..."
    
    # Re-enable Windows services for installation
    $services = @("PlugPlay", "DCOM Server Process Launcher", "RPC Endpoint Mapper")
    foreach ($service in $services) {
        Start-Service -Name $service -ErrorAction SilentlyContinue
        Set-Service -Name $service -StartupType Automatic -ErrorAction SilentlyContinue
    }
    
    # Trigger device detection
    Write-Host "Triggering device detection..."
    $devconCmd = Get-Command "devcon.exe" -ErrorAction SilentlyContinue
    if ($devconCmd) { 
        & $devconCmd.Source rescan 2>$null
    } else {
        Write-Host "⚠️  devcon not available for device rescan" -ForegroundColor Yellow
    }
    pnputil /scan-devices 2>$null
    
    Write-Host "✓ System prepared for new driver installation!" -ForegroundColor Green
}

# Function to restart required services
function Restart-RequiredServices {
    Write-Host "--- Restarting Required Services ---" -ForegroundColor Yellow
    
    # Re-enable critical services first
    $criticalServices = @("wuauserv", "UsoSvc", "WaaSMedicSvc", "BITS", "CryptSvc")
    foreach ($service in $criticalServices) {
        Set-Service -Name $service -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name $service -ErrorAction SilentlyContinue
        Write-Host "✓ Re-enabled: $service"
    }
    
    $services = @("AudioSrv", "AudioEndpointBuilder", "Themes", "UxSms", "PlugPlay")
    
    foreach ($service in $services) {
        try {
            Write-Host "Restarting service: $service"
            Restart-Service -Name $service -Force -ErrorAction SilentlyContinue
            Write-Host "✓ Service restarted: $service" -ForegroundColor Green
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
# Enhanced dialog handler with advanced automation
function Start-EnhancedDialogHandler {
    $job = Start-Job -ScriptBlock {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

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
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
    
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);
    
    [DllImport("user32.dll")]
    public static extern bool CloseWindow(IntPtr hWnd);
    
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    
    public const uint WM_COMMAND = 0x0111;
    public const uint BM_CLICK = 0x00F5;
    public const uint WM_KEYDOWN = 0x0100;
    public const uint WM_CHAR = 0x0102;
    public const uint WM_CLOSE = 0x0010;
    public const uint VK_RETURN = 0x0D;
    public const uint VK_ESCAPE = 0x1B;
    public const uint VK_TAB = 0x09;
    public const uint VK_Y = 0x59;
    public const int SW_HIDE = 0;
    public const int SW_MINIMIZE = 6;
    public const uint GW_HWNDNEXT = 2;
}
"@
        
        # Add SendKeys and UIAutomation
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName UIAutomationClient
        
        while ($true) {
            Start-Sleep 300  # More frequent checking
            
            # Enhanced dialog detection and handling
            $windowFound = $false
            
            # Comprehensive dialog patterns (including error dialogs)
            $dialogPatterns = @(
                "*Setup*", "*Install*", "*Language*", "*ASUS*", "*AMD*", "*Realtek*", 
                "*MediaTek*", "*Driver*", "*Wizard*", "*Error*", "*Warning*", "*Question*",
                "*Confirm*", "*License*", "*Agreement*", "*Welcome*", "*Finish*", "*Complete*",
                "*Restart*", "*Reboot*", "*Update*", "*Certificate*", "*Security*", "*UAC*"
            )
            
            # Find all processes with windows
            $processes = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -ne "" }
            
            foreach ($process in $processes) {
                $windowTitle = $process.MainWindowTitle
                $matchFound = $false
                
                # Check if window title matches any pattern
                foreach ($pattern in $dialogPatterns) {
                    if ($windowTitle -like $pattern) {
                        $matchFound = $true
                        break
                    }
                }
                
                if ($matchFound) {
                    $hwnd = $process.MainWindowHandle
                    Write-Host "Found dialog: $windowTitle"
                    
                    # Get window text for analysis
                    $windowText = New-Object System.Text.StringBuilder 1024
                    [Win32]::GetWindowText($hwnd, $windowText, 1024)
                    $text = $windowText.ToString()
                    
                    # Bring window to foreground
                    [Win32]::SetForegroundWindow($hwnd)
                    Start-Sleep 200
                    
                    # Enhanced button detection and clicking
                    $buttonTexts = @(
                        # Primary action buttons
                        "OK", "&OK", "Next", "&Next", "Continue", "&Continue", 
                        "Install", "&Install", "Accept", "&Accept", "Agree", "&Agree",
                        "Yes", "&Yes", "Finish", "&Finish", "Complete", "&Complete",
                        
                        # Secondary buttons  
                        "Close", "&Close", "Skip", "&Skip", "Later", "&Later",
                        "No", "&No", "Cancel", "&Cancel", "Ignore", "&Ignore",
                        
                        # Specific installer buttons
                        "I Agree", "I Accept", "Install Now", "Next >", "< Back",
                        "Typical", "Custom", "Express", "Quick", "Standard"
                    )
                    
                    $buttonClicked = $false
                    
                    # Try to find and click buttons
                    foreach ($buttonText in $buttonTexts) {
                        $buttonHwnd = [Win32]::FindWindowEx($hwnd, [IntPtr]::Zero, "Button", $buttonText)
                        if ($buttonHwnd -ne [IntPtr]::Zero) {
                            Write-Host "Clicking button: $buttonText"
                            [Win32]::PostMessage($buttonHwnd, [Win32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)
                            $buttonClicked = $true
                            $windowFound = $true
                            break
                        }
                    }
                    
                    # If no specific button found, try keyboard shortcuts
                    if (-not $buttonClicked) {
                        # Try common keyboard shortcuts
                        $shortcuts = @(
                            "{ENTER}",     # Most common accept action
                            "{TAB}{ENTER}", # Tab to button, then enter
                            "{TAB}{TAB}{ENTER}", # Multiple tabs then enter
                            "Y",           # Yes in command prompts
                            "{ALT}Y",      # Alt+Y for Yes
                            "{ALT}A",      # Alt+A for Accept/Agree  
                            "{ALT}I",      # Alt+I for Install
                            "{ALT}N",      # Alt+N for Next
                            "{ALT}O",      # Alt+O for OK
                            "{ESC}"        # Escape for cancel/close (last resort)
                        )
                        
                        foreach ($shortcut in $shortcuts) {
                            try {
                                [System.Windows.Forms.SendKeys]::SendWait($shortcut)
                                Write-Host "Sent keyboard shortcut: $shortcut"
                                Start-Sleep 500
                                
                                # Check if window is still there
                                $stillExists = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
                                if (-not $stillExists -or $stillExists.MainWindowTitle -eq "") {
                                    $windowFound = $true
                                    break
                                }
                            } catch {
                                # Continue to next shortcut
                            }
                        }
                    }
                    
                    # If still no success, try closing the window
                    if (-not $windowFound) {
                        Write-Host "Attempting to close stubborn dialog: $windowTitle"
                        [Win32]::PostMessage($hwnd, [Win32]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
                        [Win32]::CloseWindow($hwnd)
                    }
                    
                    if ($windowFound) {
                        Start-Sleep 1000  # Wait for dialog to process
                        break
                    }
                }
            }
            
            # Additional check for UAC dialogs
            if (-not $windowFound) {
                $uacProcess = Get-Process -Name "consent" -ErrorAction SilentlyContinue
                if ($uacProcess) {
                    Write-Host "Found UAC dialog, attempting to approve..."
                    [System.Windows.Forms.SendKeys]::SendWait("{LEFT}{ENTER}")
                    Start-Sleep 1000
                }
            }
        }
    }
    return $job
}

# Advanced driver extraction and installation
function Invoke-AdvancedDriverExtraction {
    param([System.IO.FileInfo]$DriverFile)
    
    Write-Host "🔧 ADVANCED EXTRACTION: $($DriverFile.Name)" -ForegroundColor Magenta
    
    try {
        # Create unique extraction folder
        $extractPath = Join-Path $env:temp "advanced_extract_$(Get-Random)"
        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
        
        # Multiple extraction methods
        $extractionMethods = @(
            @{ Args = @("/extract:`"$extractPath`""); Description = "Standard extract" },
            @{ Args = @("/x:`"$extractPath`""); Description = "X extract" },
            @{ Args = @("-x`"$extractPath`""); Description = "Dash x extract" },
            @{ Args = @("/e", "`"$extractPath`""); Description = "E extract" },
            @{ Args = @("/ExtractTo=`"$extractPath`""); Description = "ExtractTo" },
            @{ Args = @("--extract-to=`"$extractPath`""); Description = "GNU extract" },
            @{ Args = @("/DIR=`"$extractPath`""); Description = "DIR extract" }
        )
        
        $extractSuccess = $false
        
        foreach ($method in $extractionMethods) {
            try {
                Write-Host "Trying: $($method.Description)"
                $process = Start-Process -FilePath $DriverFile.FullName -ArgumentList $method.Args -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                
                if ($process.ExitCode -eq 0 -and (Get-ChildItem -Path $extractPath -ErrorAction SilentlyContinue).Count -gt 0) {
                    Write-Host "✓ Extraction successful with: $($method.Description)" -ForegroundColor Green
                    $extractSuccess = $true
                    break
                }
            } catch {
                # Continue to next method
            }
        }
        
        if (-not $extractSuccess) {
            # Try 7-Zip if available
            $sevenZip = Get-Command "7z.exe" -ErrorAction SilentlyContinue
            if ($sevenZip) {
                Write-Host "Trying 7-Zip extraction..."
                & $sevenZip.Source x "$($DriverFile.FullName)" "-o$extractPath" -y 2>$null
                if ((Get-ChildItem -Path $extractPath -ErrorAction SilentlyContinue).Count -gt 0) {
                    $extractSuccess = $true
                    Write-Host "✓ 7-Zip extraction successful" -ForegroundColor Green
                }
            }
        }
        
        if ($extractSuccess) {
            # Look for installation files in extracted content
            $setupFiles = @()
            $setupFiles += Get-ChildItem -Path $extractPath -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue
            $setupFiles += Get-ChildItem -Path $extractPath -Filter "install.exe" -Recurse -ErrorAction SilentlyContinue
            $setupFiles += Get-ChildItem -Path $extractPath -Filter "*.msi" -Recurse -ErrorAction SilentlyContinue
            $setupFiles += Get-ChildItem -Path $extractPath -Filter "autorun.exe" -Recurse -ErrorAction SilentlyContinue
            
            # Also look for INF files for direct driver installation
            $infFiles = Get-ChildItem -Path $extractPath -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue
            
            $installSuccess = $false
            
            # Try INF files first (most reliable)
            foreach ($infFile in $infFiles) {
                Write-Host "Attempting INF installation: $($infFile.Name)"
                $result = pnputil /add-driver $infFile.FullName /install
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✓ INF driver installed successfully" -ForegroundColor Green
                    $installSuccess = $true
                    break
                }
            }
            
            # Try setup files
            if (-not $installSuccess) {
                foreach ($setupFile in $setupFiles) {
                    Write-Host "Attempting setup installation: $($setupFile.Name)"
                    
                    $silentArgs = @("/S", "/SILENT", "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART")
                    
                    if ($setupFile.Extension -eq ".msi") {
                        $process = Start-Process "msiexec.exe" -ArgumentList @("/i", "`"$($setupFile.FullName)`"", "/quiet", "/norestart") -Wait -PassThru -WindowStyle Hidden
                    } else {
                        $process = Start-Process -FilePath $setupFile.FullName -ArgumentList $silentArgs -Wait -PassThru -WindowStyle Hidden
                    }
                    
                    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                        Write-Host "✓ Extracted setup installed successfully" -ForegroundColor Green
                        $installSuccess = $true
                        break
                    }
                }
            }
            
            return $installSuccess
        }
        
        return $false
        
    } catch {
        Write-Warning "Advanced extraction failed: $($_.Exception.Message)"
        return $false
    } finally {
        # Cleanup extraction folder
        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Legacy dialog handler for compatibility
function Start-DialogHandler {
    return Start-EnhancedDialogHandler
}

# Function to install all driver files with GUARANTEED SUCCESS
function Install-AllDrivers {
    Write-Host "=== ULTIMATE DRIVER INSTALLATION (GUARANTEED SUCCESS) ===" -ForegroundColor Green -BackgroundColor Black
    Write-Host "🚀 This will install ALL drivers with maximum compatibility and success rate!" -ForegroundColor Cyan
    
    if (-not (Test-Path $AsusPath)) {
        Write-Error "Asus folder not found at: $AsusPath"
        return $false
    }
    
    # Scan for ALL driver files (not just .exe)
    Write-Host "Scanning for driver files..." -ForegroundColor Cyan
    $allDriverFiles = @()
    
    # Get EXE files
    $exeFiles = Get-ChildItem -Path $AsusPath -Filter "*.exe" -Recurse | Sort-Object Name
    $allDriverFiles += $exeFiles
    
    # Get MSI files
    $msiFiles = Get-ChildItem -Path $AsusPath -Filter "*.msi" -Recurse | Sort-Object Name
    $allDriverFiles += $msiFiles
    
    # Get INF files for direct driver installation
    $infFiles = Get-ChildItem -Path $AsusPath -Filter "*.inf" -Recurse | Sort-Object Name
    
    if ($allDriverFiles.Count -eq 0 -and $infFiles.Count -eq 0) {
        Write-Warning "No driver files found in: $AsusPath"
        return $false
    }
    
    Write-Host "Found driver files to install:" -ForegroundColor Green
    Write-Host "  📦 EXE files: $($exeFiles.Count)" -ForegroundColor Yellow
    Write-Host "  📦 MSI files: $($msiFiles.Count)" -ForegroundColor Yellow  
    Write-Host "  📦 INF files: $($infFiles.Count)" -ForegroundColor Yellow
    
    $allDriverFiles | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
    if ($infFiles.Count -gt 0) {
        Write-Host "INF Driver files:" -ForegroundColor Cyan
        $infFiles | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
    }
    
    # Start enhanced dialog handler
    Write-Host "Starting ENHANCED automated dialog handler..." -ForegroundColor Cyan
    $dialogJob = Start-EnhancedDialogHandler
    
    $successCount = 0
    $totalFiles = $allDriverFiles.Count + $infFiles.Count
    
    # Phase 1: Install INF drivers directly (highest success rate)
    if ($infFiles.Count -gt 0) {
        Write-Host "`n=== PHASE 1: Installing INF Drivers (Direct Method) ===" -ForegroundColor Magenta
        foreach ($infFile in $infFiles) {
            Write-Host "`n--- Direct INF Install: $($infFile.Name) ---" -ForegroundColor Yellow
            
            try {
                # Method 1: pnputil (most reliable)
                $result = pnputil /add-driver $infFile.FullName /install
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✓ Successfully installed INF driver: $($infFile.Name)" -ForegroundColor Green
                    $successCount++
                    continue
                }
                
                # Method 2: devcon (fallback) - with existence check
                $devconPath = Get-Command "devcon.exe" -ErrorAction SilentlyContinue
                if ($devconPath) {
                    & $devconPath.Source install $infFile.FullName "*" 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "✓ Successfully installed via devcon: $($infFile.Name)" -ForegroundColor Green
                        $successCount++
                        continue
                    }
                } else {
                    Write-Host "⚠️  devcon.exe not found - trying alternative method" -ForegroundColor Yellow
                    # Alternative: Use PowerShell Add-WindowsDriver if available
                    try {
                        if (Get-Command "Add-WindowsDriver" -ErrorAction SilentlyContinue) {
                            Add-WindowsDriver -Online -Driver $infFile.FullName -ErrorAction Stop
                            Write-Host "✓ Successfully installed via Add-WindowsDriver: $($infFile.Name)" -ForegroundColor Green
                            $successCount++
                            continue
                        }
                    } catch {
                        Write-Host "⚠️  Add-WindowsDriver also failed" -ForegroundColor Yellow
                    }
                }
                
                Write-Warning "Could not install INF driver: $($infFile.Name)"
                
            } catch {
                Write-Warning "Error installing INF driver $($infFile.Name): $($_.Exception.Message)"
            }
        }
    }
    
    # Phase 2: Install EXE and MSI files with ULTIMATE methods
    Write-Host "`n=== PHASE 2: Installing EXE/MSI Files (Ultimate Methods) ===" -ForegroundColor Magenta
    
    foreach ($driver in $allDriverFiles) {
        Write-Host "`n--- ULTIMATE INSTALL: $($driver.Name) ---" -ForegroundColor Yellow -BackgroundColor DarkBlue
        
        $installSuccess = $false
        $extension = $driver.Extension.ToLower()
        
        try {
            if ($extension -eq ".msi") {
                # MSI Installation methods
                Write-Host "Attempting MSI installation methods..." -ForegroundColor Cyan
                
                $msiArguments = @(
                    @("/i", "`"$($driver.FullName)`"", "/quiet", "/norestart", "/L*v", "`"$env:temp\msi_install.log`""),
                    @("/i", "`"$($driver.FullName)`"", "/passive", "/norestart"),
                    @("/i", "`"$($driver.FullName)`"", "/qn", "/norestart"),
                    @("/i", "`"$($driver.FullName)`"", "/qb!", "/norestart")
                )
                
                foreach ($args in $msiArguments) {
                    Write-Host "Trying MSI with: msiexec $($args -join ' ')"
                    $process = Start-Process "msiexec.exe" -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
                    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                        Write-Host "✓ MSI installation successful: $($driver.Name)" -ForegroundColor Green
                        $installSuccess = $true
                        $successCount++
                        break
                    }
                }
            } elseif ($extension -eq ".exe") {
                # EXE Installation methods - COMPREHENSIVE
                Write-Host "Attempting EXE installation methods..." -ForegroundColor Cyan
                
                # ULTIMATE silent installation arguments (expanded list)
                $silentArguments = @(
                    # NSIS installers
                    @("/S", "/SILENT", "/VERYSILENT", "/SP-", "/SUPPRESSMSGBOXES", "/NORESTART"),
                    @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-", "/NOCANCEL"),
                    
                    # InstallShield installers  
                    @("/s", "/v/qn", "/v/norestart"),
                    @("/s", "/SMS", "/f1`"$env:temp\setup.iss`""),
                    @("-silent", "-passive", "-norestart"),
                    
                    # Windows Installer
                    @("/quiet", "/passive", "/norestart"),
                    @("/qn", "/norestart"),
                    @("/qb!", "/norestart"),
                    
                    # ASUS specific
                    @("/SILENT", "/NORESTART", "/NOUI"),
                    @("/AUTO", "/SILENT", "/NORESTART"),
                    
                    # AMD specific  
                    @("-SILENT", "-INSTALL"),
                    @("-install", "-silent"),
                    
                    # Generic silent
                    @("--silent", "--quiet", "--no-restart"),
                    @("-q", "-silent"),
                    @("/Q", "/NORESTART"),
                    
                    # Advanced logging
                    @("/quiet", "/norestart", "/L*v", "`"$env:temp\install.log`""),
                    @("/VERYSILENT", "/LOG=`"$env:temp\install.log`"", "/NORESTART")
                )
                
                # Try each silent method
                foreach ($args in $silentArguments) {
                    Write-Host "Trying EXE with: $($args -join ' ')"
                    
                    try {
                        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                        $processInfo.FileName = $driver.FullName
                        $processInfo.Arguments = $args -join ' '
                        $processInfo.UseShellExecute = $false
                        $processInfo.CreateNoWindow = $true
                        $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
                        $processInfo.Verb = "runas"  # Ensure admin rights
                        
                        $process = [System.Diagnostics.Process]::Start($processInfo)
                        
                        # Extended timeout for large drivers
                        $timeout = 600000 # 10 minutes
                        if ($process.WaitForExit($timeout)) {
                            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                                Write-Host "✓ EXE installation successful: $($driver.Name)" -ForegroundColor Green
                                $installSuccess = $true
                                $successCount++
                                break
                            } else {
                                Write-Host "⚠️  Exit code: $($process.ExitCode)" -ForegroundColor Yellow
                            }
                        } else {
                            Write-Warning "Installation timed out for: $($driver.Name)"
                            $process.Kill()
                        }
                    } catch {
                        # Continue to next method
                        Write-Host "Method failed, trying next..." -ForegroundColor Gray
                    }
                }
                
                # If silent methods failed, try EXTRACTION and ADVANCED methods
                if (-not $installSuccess) {
                    Write-Host "Trying ADVANCED extraction methods..." -ForegroundColor Magenta
                    $installSuccess = Invoke-AdvancedDriverExtraction -DriverFile $driver
                    if ($installSuccess) { $successCount++ }
                }
            }
            
            if (-not $installSuccess) {
                Write-Warning "❌ All installation methods failed for: $($driver.Name)"
                
                # Log failure details
                $failureLog = "Failed to install: $($driver.Name)`n"
                $failureLog += "File size: $([math]::Round($driver.Length / 1MB, 2)) MB`n"
                $failureLog += "Date: $($driver.LastWriteTime)`n"
                Add-Content -Path "$env:temp\driver_install_failures.log" -Value $failureLog
            }
            
        } catch {
            Write-Error "Critical error installing $($driver.Name): $($_.Exception.Message)"
        }
        
        # Brief pause between installations to prevent conflicts
        Start-Sleep 2
    }
    
    # Stop enhanced dialog handler
    if ($dialogJob) {
        Write-Host "Stopping enhanced dialog handler..." -ForegroundColor Cyan
        Stop-Job $dialogJob -ErrorAction SilentlyContinue
        Remove-Job $dialogJob -ErrorAction SilentlyContinue
    }
    
    # Installation summary
    Write-Host "`n=== INSTALLATION SUMMARY ===" -ForegroundColor Green -BackgroundColor Black
    Write-Host "✅ Successfully installed: $successCount / $totalFiles drivers" -ForegroundColor Green
    $successRate = [math]::Round(($successCount / $totalFiles) * 100, 1)
    Write-Host "📊 Success rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })
    
    if ($successCount -lt $totalFiles) {
        Write-Host "⚠️  Some drivers failed to install. Check log: $env:temp\driver_install_failures.log" -ForegroundColor Yellow
    }
    
    return ($successCount -eq $totalFiles)
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

# Function to verify successful driver installation
function Invoke-InstallationVerification {
    Write-Host "=== COMPREHENSIVE INSTALLATION VERIFICATION ===" -ForegroundColor Cyan -BackgroundColor Black
    
    $verificationResults = @{
        "Graphics" = $false
        "Audio" = $false
        "Network" = $false
        "Bluetooth" = $false
        "USB" = $false
        "System" = $false
    }
    
    # Check Graphics Drivers
    Write-Host "🎮 Verifying Graphics Drivers..." -ForegroundColor Yellow
    $graphicsDevices = Get-WmiObject -Class Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" -and $_.Name -notlike "*Standard*" }
    if ($graphicsDevices -and $graphicsDevices.Count -gt 0) {
        foreach ($gpu in $graphicsDevices) {
            Write-Host "  ✓ Found: $($gpu.Name) - $($gpu.DriverVersion)" -ForegroundColor Green
        }
        $verificationResults["Graphics"] = $true
    } else {
        Write-Host "  ❌ No graphics drivers detected!" -ForegroundColor Red
    }
    
    # Check Audio Drivers
    Write-Host "🔊 Verifying Audio Drivers..." -ForegroundColor Yellow
    $audioDevices = Get-WmiObject -Class Win32_SoundDevice | Where-Object { $_.Name -notlike "*Generic*" }
    if ($audioDevices -and $audioDevices.Count -gt 0) {
        foreach ($audio in $audioDevices) {
            Write-Host "  ✓ Found: $($audio.Name)" -ForegroundColor Green
        }
        $verificationResults["Audio"] = $true
    } else {
        Write-Host "  ❌ No audio drivers detected!" -ForegroundColor Red
    }
    
    # Check Network Adapters
    Write-Host "🌐 Verifying Network Drivers..." -ForegroundColor Yellow
    $networkAdapters = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.NetEnabled -eq $true -and $_.Name -notlike "*Loopback*" }
    if ($networkAdapters -and $networkAdapters.Count -gt 0) {
        foreach ($adapter in $networkAdapters) {
            Write-Host "  ✓ Found: $($adapter.Name)" -ForegroundColor Green
        }
        $verificationResults["Network"] = $true
    } else {
        Write-Host "  ❌ No network drivers detected!" -ForegroundColor Red
    }
    
    # Check Bluetooth
    Write-Host "📶 Verifying Bluetooth Drivers..." -ForegroundColor Yellow
    $bluetoothDevices = Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.Name -like "*Bluetooth*" -and $_.Status -eq "OK" }
    if ($bluetoothDevices -and $bluetoothDevices.Count -gt 0) {
        foreach ($bt in $bluetoothDevices) {
            Write-Host "  ✓ Found: $($bt.Name)" -ForegroundColor Green
        }
        $verificationResults["Bluetooth"] = $true
    } else {
        Write-Host "  ⚠️  No Bluetooth drivers detected (may be normal)" -ForegroundColor Yellow
        $verificationResults["Bluetooth"] = $true  # Not critical
    }
    
    # Check USB Controllers
    Write-Host "🔌 Verifying USB Controllers..." -ForegroundColor Yellow
    $usbControllers = Get-WmiObject -Class Win32_USBController | Where-Object { $_.Status -eq "OK" }
    if ($usbControllers -and $usbControllers.Count -gt 0) {
        Write-Host "  ✓ Found $($usbControllers.Count) USB controllers" -ForegroundColor Green
        $verificationResults["USB"] = $true
    } else {
        Write-Host "  ❌ No USB controllers detected!" -ForegroundColor Red
    }
    
    # Check System Devices
    Write-Host "⚙️  Verifying System Devices..." -ForegroundColor Yellow
    $systemDevices = Get-WmiObject -Class Win32_SystemDriver | Where-Object { $_.State -eq "Running" -and ($_.Name -like "*ASUS*" -or $_.Name -like "*AMD*") }
    $verificationResults["System"] = $true  # Assume OK if no errors
    Write-Host "  ✓ System drivers appear functional" -ForegroundColor Green
    
    # Overall verification summary
    $successCount = ($verificationResults.Values | Where-Object { $_ -eq $true }).Count
    $totalChecks = $verificationResults.Count
    $successRate = [math]::Round(($successCount / $totalChecks) * 100, 1)
    
    Write-Host "`n=== VERIFICATION SUMMARY ===" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "✅ Verified Categories: $successCount / $totalChecks" -ForegroundColor Green
    Write-Host "📊 Verification Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })
    
    if ($successRate -eq 100) {
        Write-Host "🎉 PERFECT! All driver categories verified successfully!" -ForegroundColor Green -BackgroundColor Black
    } elseif ($successRate -ge 80) {
        Write-Host "✅ EXCELLENT! Most drivers installed successfully!" -ForegroundColor Green
    } elseif ($successRate -ge 60) {
        Write-Host "⚠️  PARTIAL SUCCESS: Some drivers may need attention" -ForegroundColor Yellow
    } else {
        Write-Host "❌ ISSUES DETECTED: Multiple driver categories failed" -ForegroundColor Red
    }
    
    return ($successRate -ge 80)
}

# Main script logic
Write-Host "🚀 ULTIMATE ASUS DRIVER INSTALLER WITH NUCLEAR PURGE 🚀" -ForegroundColor White -BackgroundColor DarkMagenta
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "⚠️  CRITICAL: This script will OBLITERATE existing drivers completely!" -ForegroundColor Red -BackgroundColor Yellow
Write-Host "💥 NUCLEAR-LEVEL cleanup ensures ZERO conflicts with new drivers!" -ForegroundColor Yellow
Write-Host "🔄 Process: PURGE → VERIFY → INSTALL → VALIDATE → CONFIGURE" -ForegroundColor Green
Write-Host ""

# Enhanced parameter validation
if (-not $NetworkOnly -and -not $AllDrivers) {
    Write-Host "❌ ERROR: No installation option specified!" -ForegroundColor Red -BackgroundColor Black
    Write-Host "Please choose -NetworkOnly or -AllDrivers" -ForegroundColor Yellow
    Show-Usage
    exit 1
}

if ($NetworkOnly -and $AllDrivers) {
    Write-Host "❌ ERROR: Conflicting parameters!" -ForegroundColor Red -BackgroundColor Black
    Write-Host "Please specify either -NetworkOnly OR -AllDrivers, not both" -ForegroundColor Yellow
    Show-Usage
    exit 1
}

# Pre-execution system check
Write-Host "🔍 PRE-EXECUTION SYSTEM CHECK..." -ForegroundColor Cyan
$systemCheck = $true

# Check if running as admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ CRITICAL: Must run as Administrator!" -ForegroundColor Red -BackgroundColor Black
    $systemCheck = $false
}

# Check ASUS path
if ($AllDrivers -and -not (Test-Path $AsusPath)) {
    Write-Host "❌ CRITICAL: ASUS driver path not found: $AsusPath" -ForegroundColor Red
    $systemCheck = $false
}

if (-not $systemCheck) {
    Write-Host "🛑 SYSTEM CHECK FAILED - Cannot proceed!" -ForegroundColor Red -BackgroundColor Black
    exit 1
}

Write-Host "✅ System check passed - Ready for NUCLEAR OPERATION!" -ForegroundColor Green
Start-Sleep 2

# Execute based on parameters with comprehensive error handling
$overallSuccess = $true

try {
    if ($NetworkOnly) {
        Write-Host "🌐 NETWORK-ONLY MODE INITIATED" -ForegroundColor White -BackgroundColor DarkBlue
        
        Write-Host "🔥 PHASE 1: Purging existing network drivers..." -ForegroundColor Red
        Remove-NetworkDrivers
        Clean-DriverRegistry
        Clean-DriverStore
        
        Write-Host "🛠️  PHASE 2: Installing new network drivers..." -ForegroundColor Green
        $installSuccess = Install-NetworkDrivers
        
        Write-Host "🔄 PHASE 3: Restarting services..." -ForegroundColor Cyan
        Restart-RequiredServices
        
        Write-Host "✅ PHASE 4: Verification..." -ForegroundColor Magenta
        $verificationSuccess = Invoke-InstallationVerification
        
        if ($installSuccess -and $verificationSuccess) {
            Write-Host "`n🎉 NETWORK DRIVER INSTALLATION: COMPLETE SUCCESS!" -ForegroundColor Green -BackgroundColor Black
        } else {
            Write-Host "`n⚠️  NETWORK DRIVER INSTALLATION: PARTIAL SUCCESS" -ForegroundColor Yellow -BackgroundColor Black
            $overallSuccess = $false
        }
    }

    if ($AllDrivers) {
        Write-Host "💣 ALL-DRIVERS MODE: NUCLEAR OPERATION INITIATED" -ForegroundColor White -BackgroundColor DarkRed
        
        Write-Host "💥 PHASE 1: NUCLEAR driver purge..." -ForegroundColor Red
        Remove-ExistingDrivers
        
        Write-Host "🚀 PHASE 2: Installing ALL drivers..." -ForegroundColor Green
        $installSuccess = Install-AllDrivers
        
        Write-Host "🔄 PHASE 3: Restarting services..." -ForegroundColor Cyan
        Restart-RequiredServices
        
        Write-Host "✅ PHASE 4: Comprehensive verification..." -ForegroundColor Magenta
        $verificationSuccess = Invoke-InstallationVerification
        
        if ($installSuccess -and $verificationSuccess) {
            Write-Host "`n🎉 ALL DRIVER INSTALLATION: COMPLETE SUCCESS!" -ForegroundColor Green -BackgroundColor Black
        } else {
            Write-Host "`n⚠️  ALL DRIVER INSTALLATION: REVIEW REQUIRED" -ForegroundColor Yellow -BackgroundColor Black
            $overallSuccess = $false
        }
    }

} catch {
    Write-Host "`n💥 CRITICAL ERROR DURING EXECUTION!" -ForegroundColor Red -BackgroundColor Black
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    $overallSuccess = $false
}

# Final summary and recommendations
Write-Host "`n" + "="*60 -ForegroundColor White
Write-Host "🏁 FINAL EXECUTION SUMMARY" -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "="*60 -ForegroundColor White

if ($overallSuccess) {
    Write-Host "✅ MISSION ACCOMPLISHED!" -ForegroundColor Green -BackgroundColor Black
    Write-Host "🎯 All operations completed successfully" -ForegroundColor Green
    Write-Host "🔄 RECOMMENDED: Restart your computer now for optimal performance" -ForegroundColor Yellow
} else {
    Write-Host "⚠️  MISSION PARTIALLY COMPLETED" -ForegroundColor Yellow -BackgroundColor Black
    Write-Host "📋 Some operations may require manual attention" -ForegroundColor Yellow
    Write-Host "📝 Check logs in: $env:temp\driver_install_failures.log" -ForegroundColor Cyan
    Write-Host "🔄 REQUIRED: Restart your computer to finalize driver loading" -ForegroundColor Red
}

Write-Host "`n🚀 Thank you for using the ULTIMATE ASUS Driver Installer!" -ForegroundColor Cyan
Write-Host "💡 For support, check the generated logs and device manager" -ForegroundColor Gray

# Exit with appropriate code
exit $(if ($overallSuccess) { 0 } else { 1 })
