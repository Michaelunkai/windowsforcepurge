# Enhanced ASUS Network Driver Reinstallation Script with Error Handling
# This script will reinstall ASUS network drivers and connect to WiFi with comprehensive error checking

param(
    [string]$WifiSSID = "Stella_5",
    [string]$WifiPassword = "Stellamylove",
    [int]$MaxRetries = 3,
    [int]$WaitTimeSeconds = 60
)

function Write-LogMessage {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Type] $Message" -ForegroundColor $(if($Type -eq "ERROR"){"Red"} elseif($Type -eq "SUCCESS"){"Green"} else{"White"})
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Wait-ForDriverInstallation {
    param([int]$MaxWaitSeconds = 120)
    
    Write-LogMessage "Waiting for driver installation to complete..."
    $startTime = Get-Date
    
    do {
        Start-Sleep -Seconds 5
        $wifiAdapter = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object {
            $_.Name -like "*Wi-Fi*" -or $_.Name -like "*Wireless*" -or $_.Name -like "*802.11*" -or $_.Name -like "*MT7922*"
        } | Where-Object { $_.NetEnabled -eq $true }
        
        $elapsedTime = (Get-Date) - $startTime
        Write-LogMessage "Checking for WiFi adapter... (Elapsed: $([math]::Round($elapsedTime.TotalSeconds))s)"
        
        if ($wifiAdapter) {
            Write-LogMessage "WiFi adapter detected: $($wifiAdapter.Name)" -Type "SUCCESS"
            return $true
        }
        
    } while ($elapsedTime.TotalSeconds -lt $MaxWaitSeconds)
    
    return $false
}

function Enable-LocationServices {
    Write-LogMessage "Configuring location services..."
    try {
        $regPaths = @(
            "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location",
            "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\Microsoft.Windows.ShellExperienceHost_cw5n1h2txyewy",
            "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\Microsoft.Windows.Cortana_cw5n1h2txyewy",
            "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged",
            "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
        )
        
        foreach ($regPath in $regPaths) {
            reg add $regPath /v Value /t REG_SZ /d Allow /f | Out-Null
        }
        
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' -Name 'Value' -Value 'Allow' -Force -ErrorAction SilentlyContinue
        Write-LogMessage "Location services configured successfully" -Type "SUCCESS"
        return $true
    }
    catch {
        Write-LogMessage "Warning: Could not configure all location services: $($_.Exception.Message)" -Type "ERROR"
        return $false
    }
}

function Remove-WifiProfile {
    param([string]$ProfileName)
    
    Write-LogMessage "Removing existing WiFi profile: $ProfileName"
    try {
        netsh wlan delete profile name="$ProfileName" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "WiFi profile '$ProfileName' removed successfully" -Type "SUCCESS"
        } else {
            Write-LogMessage "WiFi profile '$ProfileName' was not found or already removed"
        }
        return $true
    }
    catch {
        Write-LogMessage "Error removing WiFi profile: $($_.Exception.Message)" -Type "ERROR"
        return $false
    }
}

function New-WifiProfile {
    param([string]$SSID, [string]$Password)
    
    Write-LogMessage "Creating WiFi profile for: $SSID"
    try {
        $xmlContent = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$SSID</name>
    <SSIDConfig>
        <SSID>
            <name>$SSID</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
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
        
        $tempFile = "$env:temp\$SSID.xml"
        $xmlContent | Out-File -FilePath $tempFile -Encoding UTF8 -Force
        
        $profileResult = netsh wlan add profile filename="$tempFile" 2>&1
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "WiFi profile created successfully" -Type "SUCCESS"
            return $true
        } else {
            Write-LogMessage "Failed to create WiFi profile: $profileResult" -Type "ERROR"
            return $false
        }
    }
    catch {
        Write-LogMessage "Error creating WiFi profile: $($_.Exception.Message)" -Type "ERROR"
        return $false
    }
}

function Connect-ToWifi {
    param([string]$SSID, [int]$MaxRetries = 3)
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        Write-LogMessage "Attempting to connect to WiFi '$SSID' (Attempt $i/$MaxRetries)"
        
        try {
            netsh wlan connect name="$SSID" 2>&1 | Out-Null
            Start-Sleep -Seconds 10
            
            # Check connection status
            $connectionStatus = netsh wlan show interfaces | Select-String "State.*connected"
            if ($connectionStatus) {
                Write-LogMessage "Successfully connected to WiFi '$SSID'" -Type "SUCCESS"
                
                # Verify internet connectivity
                Start-Sleep -Seconds 5
                try {
                    $pingResult = Test-NetConnection "8.8.8.8" -Port 53 -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                    if ($pingResult) {
                        Write-LogMessage "Internet connectivity verified" -Type "SUCCESS"
                        return $true
                    } else {
                        Write-LogMessage "Connected to WiFi but no internet access detected"
                    }
                } catch {
                    Write-LogMessage "Could not verify internet connectivity, but WiFi connected"
                }
                return $true
            } else {
                Write-LogMessage "Connection attempt $i failed" -Type "ERROR"
                Start-Sleep -Seconds 5
            }
        }
        catch {
            Write-LogMessage "Error during connection attempt ${i}: $($_.Exception.Message)" -Type "ERROR"
            Start-Sleep -Seconds 5
        }
    }
    
    return $false
}

# Main execution starts here
Write-LogMessage "Starting Enhanced ASUS Network Driver Reinstallation Script" -Type "SUCCESS"

# Check admin rights
if (-not (Test-AdminRights)) {
    Write-LogMessage "This script must be run as Administrator!" -Type "ERROR"
    Write-LogMessage "Please restart PowerShell as Administrator and try again."
    exit 1
}

# Step 1: Ensure WLAN service is running
Write-LogMessage "Configuring WLAN service..."
try {
    Set-Service wlansvc -StartupType Automatic -Status Running -ErrorAction Stop
    Write-LogMessage "WLAN service configured and started" -Type "SUCCESS"
}
catch {
    Write-LogMessage "Failed to configure WLAN service: $($_.Exception.Message)" -Type "ERROR"
    exit 1
}

# Step 2: Enable location services
Enable-LocationServices

# Step 3: Install ASUS drivers
$driverPath = "F:\backup\windowsapps\install\Asus\NetworkDriver\Install.bat"
if (-not (Test-Path $driverPath)) {
    Write-LogMessage "Driver installation file not found: $driverPath" -Type "ERROR"
    exit 1
}

Write-LogMessage "Starting ASUS driver installation..."
try {
    $process = Start-Process -FilePath $driverPath -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -eq 0) {
        Write-LogMessage "Driver installation process completed" -Type "SUCCESS"
    } else {
        Write-LogMessage "Driver installation process returned exit code: $($process.ExitCode)" -Type "ERROR"
    }
}
catch {
    Write-LogMessage "Error starting driver installation: $($_.Exception.Message)" -Type "ERROR"
    exit 1
}

# Step 4: Wait for driver installation and verify WiFi adapter
if (-not (Wait-ForDriverInstallation -MaxWaitSeconds $WaitTimeSeconds)) {
    Write-LogMessage "WiFi adapter not detected after driver installation" -Type "ERROR"
    Write-LogMessage "Please check Device Manager for any driver issues"
    exit 1
}

# Step 5: Remove existing WiFi profile
Remove-WifiProfile -ProfileName $WifiSSID

# Step 6: Create new WiFi profile
if (-not (New-WifiProfile -SSID $WifiSSID -Password $WifiPassword)) {
    Write-LogMessage "Failed to create WiFi profile" -Type "ERROR"
    exit 1
}

# Step 7: Connect to WiFi with retries
if (-not (Connect-ToWifi -SSID $WifiSSID -MaxRetries $MaxRetries)) {
    Write-LogMessage "Failed to connect to WiFi after $MaxRetries attempts" -Type "ERROR"
    Write-LogMessage "Please check your WiFi credentials and network availability"
    exit 1
}

Write-LogMessage "Script completed successfully! Network driver reinstalled and WiFi connected." -Type "SUCCESS"
Write-LogMessage "Current network status:"
netsh wlan show interfaces | Select-String "Profile|State|Signal"
