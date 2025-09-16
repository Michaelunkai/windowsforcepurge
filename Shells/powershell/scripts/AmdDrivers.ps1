# AMD Driver Detection and Installation Script
# Run as Administrator

# One-liner version (basic):
# Get-WindowsUpdate -MicrosoftUpdate | Where-Object {$_.Title -match "AMD"} | Install-WindowsUpdate -AcceptAll -AutoReboot

#--- Full Script Version ---

Write-Host "=== AMD Driver Detection and Installation ===" -ForegroundColor Green

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges. Please run as Administrator."
    exit 1
}

# Install required modules if not present
$modules = @("PSWindowsUpdate")
foreach ($module in $modules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing $module module..." -ForegroundColor Yellow
        Install-Module -Name $module -Force -AllowClobber
    }
}

# Import modules
Import-Module PSWindowsUpdate -Force

# Detect AMD hardware
Write-Host "`nDetecting AMD hardware..." -ForegroundColor Cyan
$amdDevices = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object {
    $_.Name -match "AMD|ATI|Radeon" -or 
    $_.Manufacturer -match "AMD|Advanced Micro Devices"
}

if ($amdDevices) {
    Write-Host "Found AMD devices:" -ForegroundColor Green
    $amdDevices | ForEach-Object {
        Write-Host "  - $($_.Name) [$($_.DeviceID)]" -ForegroundColor White
    }
} else {
    Write-Host "No AMD devices detected." -ForegroundColor Yellow
    exit 0
}

# Check for Windows Update AMD drivers
Write-Host "`nSearching for AMD drivers via Windows Update..." -ForegroundColor Cyan
try {
    $amdUpdates = Get-WindowsUpdate -MicrosoftUpdate | Where-Object {
        $_.Title -match "AMD|ATI|Radeon" -and $_.Title -match "driver"
    }
    
    if ($amdUpdates) {
        Write-Host "Found AMD driver updates:" -ForegroundColor Green
        $amdUpdates | ForEach-Object {
            Write-Host "  - $($_.Title)" -ForegroundColor White
        }
        
        $install = Read-Host "`nInstall these drivers? (y/N)"
        if ($install -eq "y" -or $install -eq "Y") {
            Write-Host "Installing AMD drivers..." -ForegroundColor Green
            $amdUpdates | Install-WindowsUpdate -AcceptAll -Verbose
        }
    } else {
        Write-Host "No AMD driver updates found via Windows Update." -ForegroundColor Yellow
    }
} catch {
    Write-Warning "Error checking Windows Update: $($_.Exception.Message)"
}

# Check for missing drivers using PnP
Write-Host "`nChecking for missing AMD drivers..." -ForegroundColor Cyan
$missingDrivers = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object {
    ($_.Name -match "AMD|ATI|Radeon" -or $_.Manufacturer -match "AMD") -and
    $_.ConfigManagerErrorCode -eq 28  # Device driver not installed
}

if ($missingDrivers) {
    Write-Host "Found devices with missing drivers:" -ForegroundColor Red
    $missingDrivers | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor White
    }
}

# Optional: Install AMD Software via winget (if available)
Write-Host "`nChecking for AMD Software Adrenalin..." -ForegroundColor Cyan
try {
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetAvailable) {
        $amdSoftware = winget search "AMD Software" --exact
        if ($amdSoftware -match "AMD.AMDSoftware") {
            $installSoftware = Read-Host "Install AMD Software Adrenalin? (y/N)"
            if ($installSoftware -eq "y" -or $installSoftware -eq "Y") {
                winget install AMD.AMDSoftware
            }
        }
    }
} catch {
    Write-Host "Winget not available or AMD Software not found." -ForegroundColor Yellow
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Green
Write-Host "AMD hardware detection and driver installation complete."
Write-Host "Reboot may be required for changes to take effect." -ForegroundColor Yellow

# Optional reboot prompt
$reboot = Read-Host "`nReboot now? (y/N)"
if ($reboot -eq "y" -or $reboot -eq "Y") {
    Restart-Computer -Force
}
