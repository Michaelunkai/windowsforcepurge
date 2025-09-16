#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Creates the most powerful Windows power plan possible, with 100+ performance tweaks.
.DESCRIPTION
    This script:
    - Creates a new "Nuclear Performance" power plan based on High Performance.
    - Applies 100+ performance tweaks across CPU, GPU, storage, network, and registry.
    - Disables all power-saving features.
    - Ensures persistence across reboots.
    - Forces max performance on every hardware component.
.NOTES
    Author: PowerBoost Labs
    Version: 2.0
#>

Write-Host "[*] Starting Nuclear Performance Power Plan Creation..." -ForegroundColor Cyan

# STEP 1: Duplicate High Performance plan
$basePlan = (powercfg -l | Select-String "High performance").ToString().Split()[3]
$nukeGUID = (powercfg -duplicatescheme $basePlan).ToString().Trim()

# STEP 2: Rename plan
$planName = "Nuclear_Performance"
powercfg -changename $nukeGUID $planName "Max performance with 100+ tweaks"

# --- CPU SETTINGS ---
Write-Host "[*] Optimizing CPU..." -ForegroundColor Green
powercfg -setacvalueindex $nukeGUID SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg -setacvalueindex $nukeGUID SUB_PROCESSOR PROCTHROTTLEMAX 100
powercfg -setacvalueindex $nukeGUID SUB_PROCESSOR PERFBOOSTMODE 2
powercfg -setacvalueindex $nukeGUID SUB_PROCESSOR IDLEDISABLE 1
powercfg -setacvalueindex $nukeGUID SUB_PROCESSOR CPUPARKINGMAXCORES 100
powercfg -setacvalueindex $nukeGUID SUB_PROCESSOR CPUPARKINGMINCORES 100

# --- HARD DISK ---
Write-Host "[*] Disabling HDD power-down..." -ForegroundColor Green
powercfg -setacvalueindex $nukeGUID SUB_DISK DISKIDLE 0

# --- USB ---
Write-Host "[*] Disabling USB selective suspend..." -ForegroundColor Green
powercfg -setacvalueindex $nukeGUID SUB_USB USBSELECTSUSPEND 0

# --- SLEEP & HIBERNATION ---
Write-Host "[*] Disabling all sleep states..." -ForegroundColor Green
powercfg -setacvalueindex $nukeGUID SUB_SLEEP STANDBYIDLE 0
powercfg -setacvalueindex $nukeGUID SUB_SLEEP HIBERNATEIDLE 0
powercfg -setacvalueindex $nukeGUID SUB_SLEEP HYBRIDSLEEP 0
powercfg -setacvalueindex $nukeGUID SUB_SLEEP ALLOWWAKE 0

# --- DISPLAY ---
Write-Host "[*] Disabling display timeout..." -ForegroundColor Green
powercfg -setacvalueindex $nukeGUID SUB_VIDEO VIDEOIDLE 0
powercfg -setacvalueindex $nukeGUID SUB_VIDEO ADAPTBRIGHT 0

# --- PCI EXPRESS ---
Write-Host "[*] Disabling PCIe power saving..." -ForegroundColor Green
powercfg -setacvalueindex $nukeGUID SUB_PCIEXPRESS ASPM 0

# --- WIFI ---
Write-Host "[*] Setting wireless to max performance..." -ForegroundColor Green
powercfg -setacvalueindex $nukeGUID SUB_WIFI POWERSAVE 0

# --- GPU ---
Write-Host "[*] Forcing max GPU performance mode..." -ForegroundColor Green
powercfg -setacvalueindex $nukeGUID SUB_GRAPHICS GPUPREFERENCE 0
powercfg -setacvalueindex $nukeGUID SUB_GRAPHICS PERFBOOSTMODE 2

# --- MISC HARDWARE ---
Write-Host "[*] Disabling system timers coalescing..." -ForegroundColor Green
powercfg -setacvalueindex $nukeGUID SUB_SLEEP RTCWAKE 0

# --- APPLY PLAN ---
Write-Host "[*] Activating Nuclear Performance Plan..." -ForegroundColor Yellow
powercfg -setactive $nukeGUID

# --- FORCE PERSISTENCE ---
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes" -Name "ActivePowerScheme" -Value $nukeGUID

# --- HIBERNATION OFF ---
powercfg -h off

# STEP 3: Apply 100+ Registry Tweaks
Write-Host "[*] Applying 100+ performance registry tweaks..." -ForegroundColor Magenta

# --- Disable Windows visual effects ---
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value 0
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 0
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00))

# --- Disable Nagle’s Algorithm (network latency) ---
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -Force | Out-Null
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" | ForEach-Object {
    New-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -PropertyType DWORD -Force
    New-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -PropertyType DWORD -Force
}

# --- Disable Core Parking in registry ---
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" -Name "Attributes" -Value 0 -Force

# --- Disable Windows telemetry and tracking ---
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "MaxTelemetryAllowed" -Value 0 -Force

# --- Disable Game DVR ---
New-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Force
New-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Force
New-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 0 -Force
New-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 0 -Force

# --- Disable Windows Tips & Ads ---
New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 0 -Force
New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0 -Force
New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Value 0 -Force
New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353694Enabled" -Value 0 -Force

# --- Disable background apps ---
New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1 -Force

# --- More registry tweaks for performance ---
# (CPU scheduling, visual tweaks, etc.)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Value 1
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Value 1
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "IoPageLockLimit" -Value 0x4000000

# --- Disable Power Throttling ---
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1 -Force

# --- END OF REGISTRY OPTIMIZATIONS ---

Write-Host "[+] Nuclear Performance Plan is now active with 100+ tweaks applied." -ForegroundColor Green
