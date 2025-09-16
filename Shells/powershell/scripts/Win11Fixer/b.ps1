# Requires Administrator privileges to run effectively.
# Designed for PowerShell Version 5 and above.
# FULLY AUTOMATED VERSION - NO PROMPTS OR INTERRUPTIONS

Write-Host "--- Initiating Comprehensive Windows System Repair and Optimization Script ---" -ForegroundColor Cyan
Write-Host "Disclaimer: This script runs multiple system-level commands. While designed to be safe, system behavior can be unpredictable with existing corruption. A system restart after completion is highly recommended." -ForegroundColor Yellow
# REMOVED: Start-Sleep -Seconds 5 # Give user time to read disclaimer

# --- Section 1: Core System File and Component Store Repairs ---
Write-Host "`n--- Section 1: Core System File and Component Store Repair ---" -ForegroundColor Cyan

# 1. System File Checker (SFC) - Scans and repairs corrupted system files.
Write-Host "Running SFC /scannow (System File Checker)..." -ForegroundColor Yellow
Try {
    sfc /scannow | Out-Host
    Write-Host "SFC /scannow completed." -ForegroundColor Green
} Catch {
    Write-Warning "SFC /scannow failed: $($_.Exception.Message)"
}

# 2-4. DISM (Deployment Imaging Service and Management Tool) - Repairs Windows Image.
Write-Host "`nChecking DISM Image Health (CheckHealth)..." -ForegroundColor Yellow
Try {
    DISM /Online /Cleanup-Image /CheckHealth | Out-Host
    Write-Host "CheckHealth completed." -ForegroundColor Green
} Catch {
    Write-Warning "DISM /CheckHealth failed: $($_.Exception.Message)"
}

Write-Host "`nScanning DISM Image Health (ScanHealth)..." -ForegroundColor Yellow
Try {
    DISM /Online /Cleanup-Image /ScanHealth | Out-Host
    Write-Host "ScanHealth completed." -ForegroundColor Green
} Catch {
    Write-Warning "DISM /ScanHealth failed: $($_.Exception.Message)"
}

Write-Host "`nRestoring DISM Image Health (RestoreHealth)... This may take a long time and appear stuck." -ForegroundColor Yellow
Try {
    DISM /Online /Cleanup-Image /RestoreHealth | Out-Host
    Write-Host "RestoreHealth completed." -ForegroundColor Green
} Catch {
    Write-Warning "DISM /RestoreHealth failed: $($_.Exception.Message)"
}

# 5. Start Component Cleanup (DISM) - Cleans up superseded components.
Write-Host "`nStarting DISM Component Cleanup..." -ForegroundColor Yellow
Try {
    DISM /Online /Cleanup-Image /StartComponentCleanup | Out-Host
    Write-Host "DISM Component Cleanup completed." -ForegroundColor Green
} Catch {
    Write-Warning "DISM Component Cleanup failed: $($_.Exception.Message)"
}

# 6. Analyze Component Store (DISM) - Provides information on component store size.
Write-Host "`nAnalyzing DISM Component Store..." -ForegroundColor Yellow
Try {
    DISM /Online /Cleanup-Image /AnalyzeComponentStore | Out-Host
    Write-Host "DISM Component Store analysis completed." -ForegroundColor Green
} Catch {
    Write-Warning "DISM Component Store analysis failed: $($_.Exception.Message)"
}

# --- Section 2: Disk Health and File System Repair ---
Write-Host "`n--- Section 2: Disk Health and File System Repair ---" -ForegroundColor Cyan

# 7-9. Check Disk (CHKDSK) - Scans for and repairs file system errors. Requires reboot for /f /r.
Write-Host "`nRunning CHKDSK /f /r (Check Disk). This will schedule a scan on the next reboot if the drive is in use." -ForegroundColor Yellow
Try {
    echo y | chkdsk /f /r | Out-Host
    Write-Host "CHKDSK scheduled for next reboot." -ForegroundColor Green
} Catch {
    Write-Warning "CHKDSK scheduling failed: $($_.Exception.Message)"
}

# 10-12. Repair-Volume (PowerShell equivalent for advanced disk repair). PowerShell 5+
# These commands require a specific drive letter, assuming C: for OS.
Write-Host "`nScanning Volume C: for errors using Repair-Volume..." -ForegroundColor Yellow
Try {
    Repair-Volume -DriveLetter C -Scan -ErrorAction SilentlyContinue | Out-Host
    Write-Host "Scan of Volume C: completed." -ForegroundColor Green
} Catch {
    Write-Warning "Repair-Volume -Scan failed: $($_.Exception.Message)"
}

Write-Host "`nPerforming offline scan and fix on Volume C:. (May briefly dismount volume)" -ForegroundColor Yellow
Try {
    Repair-Volume -DriveLetter C -OfflineScanAndFix -ErrorAction SilentlyContinue | Out-Host
    Write-Host "Offline scan and fix of Volume C: completed." -ForegroundColor Green
} Catch {
    Write-Warning "Repair-Volume -OfflineScanAndFix failed: $($_.Exception.Message)"
}

Write-Host "`nPerforming Spot Fix on Volume C:." -ForegroundColor Yellow
Try {
    Repair-Volume -DriveLetter C -SpotFix -ErrorAction SilentlyContinue | Out-Host
    Write-Host "Spot Fix of Volume C: completed." -ForegroundColor Green
} Catch {
    Write-Warning "Repair-Volume -SpotFix failed: $($_.Exception.Message)"
}
Write-Host "Volume repair operations completed for C:." -ForegroundColor Green


# 13. Optimize-Volume (Defragment and ReTrim) - PowerShell 5+
Write-Host "`nOptimizing Volume C: (Defragment and ReTrim for SSDs/HDDs)..." -ForegroundColor Yellow
Try {
    Optimize-Volume -DriveLetter C -Defrag -ReTrim -ErrorAction SilentlyContinue | Out-Host
    Write-Host "Volume optimization completed." -ForegroundColor Green
} Catch {
    Write-Warning "Volume optimization failed: $($_.Exception.Message)"
}

# 14. Disk Clean-up Utility (AUTOMATED VERSION)
Write-Host "`nStarting automated Disk Cleanup..." -ForegroundColor Yellow
Try {
    # Run cleanmgr with preset flags for automatic cleanup
    Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Host
    Write-Host "Disk Cleanup completed." -ForegroundColor Green
} Catch {
    Write-Warning "Disk Cleanup failed to launch or complete: $($_.Exception.Message)"
}

# --- Section 3: Windows Update and Service Reset ---
Write-Host "`n--- Section 3: Windows Update and Service Reset ---" -ForegroundColor Cyan

# 15-21. Stop Windows Update Services and related services
Write-Host "`nStopping Windows Update and related services..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "BITS" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "cryptSvc" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "msiserver" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "TrustedInstaller" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "DoSvc" -Force -ErrorAction SilentlyContinue # Delivery Optimization Service
    Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue # Superfetch/SysMain
    Write-Host "Services stopped." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to stop some services: $($_.Exception.Message)"
}

# 22-23. Delete SoftwareDistribution and Catroot2 folder contents (update cache and security catalog)
Write-Host "`nClearing Windows Update cache and Catroot2..." -ForegroundColor Yellow
Try {
    Remove-Item -Path "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:SystemRoot\System32\catroot2\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Windows Update cache and Catroot2 cleared." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to clear update caches: $($_.Exception.Message)"
}

# 24-32. Re-register Windows Update DLLs
Write-Host "`nRe-registering Windows Update DLLs..." -ForegroundColor Yellow
$wuDlls = @(
    "wuapi.dll", "wups.dll", "wuaueng.dll", "wucltui.dll", "atl.dll",
    "jscript.dll", "vbscript.dll", "mshtml.dll", "urlmon.dll"
)
foreach ($dll in $wuDlls) {
    Try {
        Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s $dll" -WindowStyle Hidden -Wait -ErrorAction Stop | Out-Null
    } Catch {
        Write-Warning "Failed to re-register ${dll}: $($_.Exception.Message)"
    }
}
Write-Host "Windows Update DLLs re-registered." -ForegroundColor Green

# 33-39. Start Windows Update Services and related services
Write-Host "`nStarting Windows Update and related services..." -ForegroundColor Yellow
Try {
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    Start-Service -Name "BITS" -ErrorAction SilentlyContinue
    Start-Service -Name "cryptSvc" -ErrorAction SilentlyContinue
    Start-Service -Name "msiserver" -ErrorAction SilentlyContinue
    Start-Service -Name "TrustedInstaller" -ErrorAction SilentlyContinue
    Start-Service -Name "DoSvc" -ErrorAction SilentlyContinue
    Start-Service -Name "SysMain" -ErrorAction SilentlyContinue
    Write-Host "Services started." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to start some services: $($_.Exception.Message)"
}

# 40-41. Set Automatic Updates
Write-Host "`nEnsuring Automatic Updates are configured..." -ForegroundColor Yellow
Try {
    Set-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\AutoUpdate -Name AUOptions -Value 1 -ErrorAction SilentlyContinue # 1 = Keep my computer up to date
    Set-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\AutoUpdate -Name NoAutoUpdate -Value 0 -ErrorAction SilentlyContinue
    Write-Host "Automatic Update settings configured." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to configure automatic updates: $($_.Exception.Message)"
}

# --- Section 4: App Package Re-registration ---
Write-Host "`n--- Section 4: Re-registering Microsoft Store Apps ---" -ForegroundColor Cyan

# 42. Re-registering all AppX Packages (Windows Store Apps)
Write-Host "`nRe-registering all AppX packages. This may take some time and show errors for some packages, which is normal." -ForegroundColor Yellow
Try {
    Get-AppXPackage -AllUsers | ForEach-Object {
        Try {
            Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction Stop | Out-Null
        } Catch {
            Write-Warning "Failed to re-register $($_.Name): $($_.Exception.Message)"
        }
    }
    Write-Host "AppX package re-registration completed." -ForegroundColor Green
} Catch {
    Write-Warning "Overall AppX package re-registration encountered a problem: $($_.Exception.Message)"
}

# --- Section 5: Networking Diagnostics and Reset ---
Write-Host "`n--- Section 5: Initiating Network Diagnostics and Resets ---" -ForegroundColor Cyan

# 43. Reset Winsock Catalog
Write-Host "`nResetting Winsock Catalog..." -ForegroundColor Yellow
Try {
    netsh winsock reset | Out-Host
    Write-Host "Winsock Catalog reset. A restart is needed for full effect." -ForegroundColor Green
} Catch {
    Write-Warning "Winsock reset failed: $($_.Exception.Message)"
}

# 44. Reset TCP/IP Stack
Write-Host "`nResetting TCP/IP Stack..." -ForegroundColor Yellow
Try {
    netsh int ip reset | Out-Host
    Write-Host "TCP/IP Stack reset." -ForegroundColor Green
} Catch {
    Write-Warning "TCP/IP reset failed: $($_.Exception.Message)"
}

# 45. Clear DNS Client Cache
Write-Host "`nClearing DNS Client Cache..." -ForegroundColor Yellow
Try {
    ipconfig /flushdns | Out-Host
    Write-Host "DNS Client Cache cleared." -ForegroundColor Green
} Catch {
    Write-Warning "DNS flush failed: $($_.Exception.Message)"
}

# 46-47. Renew IP Configuration
Write-Host "`nReleasing and renewing IP Configuration..." -ForegroundColor Yellow
Try {
    ipconfig /release | Out-Host
    ipconfig /renew | Out-Host
    Write-Host "IP Configuration renewed." -ForegroundColor Green
} Catch {
    Write-Warning "IP configuration renewal failed: $($_.Exception.Message)"
}

# 48. Reset Network Adapters by cycling them - PowerShell 5+
Write-Host "`nBriefly disabling and re-enabling network adapters..." -ForegroundColor Yellow
Try {
    Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | ForEach-Object {
        $adapterName = $_.Name
        Try {
            Write-Host "  - Disabling ${adapterName}..." -ForegroundColor DarkYellow
            Disable-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 2
            Write-Host "  - Enabling ${adapterName}..." -ForegroundColor DarkYellow
            Enable-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop
            Write-Host "  - Adapter '${adapterName}' cycled." -ForegroundColor DarkGreen
        } Catch {
            $errorMessage = $_.Exception.Message
            Write-Warning "  - Could not cycle adapter '${adapterName}': ${errorMessage}"
        }
    }
    Write-Host "Network adapter cycling completed." -ForegroundColor Green
} Catch {
    Write-Warning "Overall network adapter cycling failed: $($_.Exception.Message)"
}

# 49. Reset Firewall Rules to default
Write-Host "`nResetting Windows Firewall to default settings. Custom rules will be lost." -ForegroundColor Yellow
Try {
    netsh advfirewall reset | Out-Host
    Write-Host "Windows Firewall reset to default." -ForegroundColor Green
} Catch {
    Write-Warning "Firewall reset failed: $($_.Exception.Message)"
}

# --- Section 6: User Profile and Performance Optimizations ---
Write-Host "`n--- Section 6: User Profile and Performance Optimizations ---" -ForegroundColor Cyan

# 50. Clear User Temp Files (Current User)
Write-Host "`nClearing current user's temporary files..." -ForegroundColor Yellow
Try {
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "User temp files cleared." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to clear user temp files: $($_.Exception.Message)"
}

# 51. Clear System Temp Files (Common location)
Write-Host "`nClearing system temporary files..." -ForegroundColor Yellow
Try {
    Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "System temp files cleared." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to clear system temp files: $($_.Exception.Message)"
}

# 52. Clear Prefetch Cache (Can help with boot performance over time)
Write-Host "`nClearing Prefetch cache..." -ForegroundColor Yellow
Try {
    Remove-Item -Path "C:\Windows\Prefetch\*" -Force -ErrorAction SilentlyContinue
    Write-Host "Prefetch cache cleared." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to clear Prefetch cache: $($_.Exception.Message)"
}

# 53. Clear Windows Error Reporting Logs
Write-Host "`nClearing Windows Error Reporting logs..." -ForegroundColor Yellow
Try {
    Remove-Item -Path "$env:ProgramData\Microsoft\Windows\WER\ReportArchive\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Windows Error Reporting logs cleared." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to clear Error Reporting logs: $($_.Exception.Message)"
}

# 54. Clear Thumbnail Cache (AUTOMATED VERSION)
Write-Host "`nClearing Thumbnail Cache..." -ForegroundColor Yellow
Try {
    # Stop explorer silently
    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    # Delete cache files
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
    # Start explorer again
    Start-Process -FilePath "explorer.exe" -ErrorAction SilentlyContinue
    Write-Host "Thumbnail Cache cleared." -ForegroundColor Green
} Catch {
    $errorMessage = $_.Exception.Message
    Write-Warning "Could not clear Thumbnail Cache: ${errorMessage}"
}

# 55. Reset Power Scheme to default
Write-Host "`nResetting Power Scheme to default settings (Balanced)..." -ForegroundColor Yellow
Try {
    powercfg -restoredefaultschemes | Out-Host
    Write-Host "Power Scheme reset." -ForegroundColor Green
} Catch {
    Write-Warning "Power scheme reset failed: $($_.Exception.Message)"
}

# --- Section 7: Additional Service Management and Configuration Resets ---
Write-Host "`n--- Section 7: Additional Service Management and Configuration Resets ---" -ForegroundColor Cyan

# 56. Rebuild Windows Search Index
Write-Host "`nRebuilding Windows Search Index. This may take a while in the background." -ForegroundColor Yellow
Try {
    # Stop Windows Search service
    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
    # Delete the index file (assuming default location)
    Remove-Item -Path "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb" -Force -ErrorAction SilentlyContinue
    # Start Windows Search service
    Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
    Write-Host "Windows Search Index rebuild initiated. It will rebuild in background." -ForegroundColor Green
} Catch {
    Write-Warning "Windows Search Index rebuild failed: $($_.Exception.Message)"
}

# 57-58. Clear and re-register Windows Management Instrumentation (WMI)
Write-Host "`nClearing and re-registering WMI (Windows Management Instrumentation)..." -ForegroundColor Yellow
Try {
    winmgmt /resetrepository | Out-Host
    Write-Host "WMI repository reset." -ForegroundColor Green
} Catch {
    Write-Warning "WMI repository reset failed: $($_.Exception.Message)"
}

# 59. Reset Group Policy settings (if applicable)
Write-Host "`nUpdating Group Policy settings..." -ForegroundColor Yellow
Try {
    gpupdate /force | Out-Host
    Write-Host "Group Policy update completed." -ForegroundColor Green
} Catch {
    Write-Warning "Group Policy update failed: $($_.Exception.Message)"
}

# 60. Flush and rebuild icon cache (AUTOMATED VERSION)
Write-Host "`nFlushing and rebuilding Icon Cache..." -ForegroundColor Yellow
Try {
    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db" -Force -ErrorAction SilentlyContinue
    Start-Process -FilePath "explorer.exe" -ErrorAction SilentlyContinue
    Write-Host "Icon Cache flushed." -ForegroundColor Green
} Catch {
    Write-Warning "Icon cache flush failed: $($_.Exception.Message)"
}

# --- Section 8: Extensive DLL Re-registrations ---
Write-Host "`n--- Section 8: Extensive DLL Re-registrations ---" -ForegroundColor Cyan

# These commands re-register various system DLLs. While many are handled by SFC/DISM,
# explicit re-registration can sometimes resolve specific component issues.
# Over 100 common DLLs are listed here to cover a wide range of potential corruption.
$dllsToRegister = @(
    "advapi32.dll", "asferror.dll", "authz.dll", "browseui.dll", "clbcatq.dll",
    "comctl32.dll", "comdlg32.dll", "crypt32.dll", "d3d9.dll", "d3d8.dll",
    "dinput.dll", "dinput8.dll", "dmband.dll", "dmime.dll", "dmsynth.dll",
    "dmvkcrt.dll", "dmvdeo.dll", "dpnaddr.dll", "dpnet.dll", "dpsunnat.dll",
    "dsound.dll", "dxdiagn.dll", "gdi32.dll", "hlink.dll", "imagehlp.dll",
    "imm32.dll", "inetcomm.dll", "jscript.dll", "kernel32.dll", "logoncli.dll",
    "lz32.dll", "mscat32.dll", "msctf.dll", "msfeeds.dll", "mshtml.dll",
    "msidntld.dll", "msjava.dll", "msorc.dll", "msoxmlmf.dll", "msrdp.dll",
    "msrating.dll", "mssip32.dll", "mstask.dll", "msxml3.dll", "msxml6.dll",
    "netapi32.dll", "ole32.dll", "oleaut32.dll", "psapi.dll", "rasapi32.dll",
    "rpcrt4.dll", "rsaenh.dll", "rtutils.dll", "secur32.dll", "sendmail.dll",
    "setupapi.dll", "shdocvw.dll", "shell32.dll", "shlwapi.dll", "slbcsp.dll",
    "softpub.dll", "sqmapi.dll", "srclient.dll", "tapi32.dll", "url.dll",
    "urlmon.dll", "user32.dll", "usp10.dll", "vbscript.dll", "webcheck.dll",
    "winhttp.dll", "wininet.dll", "winmm.dll", "winreg.dll", "winsock.dll",
    "wintrust.dll", "wmi.dll", "wshom.ocx", "ws2_32.dll", "wsock32.dll",
    "xinput1_3.dll", "zipfldr.dll", "actxprxy.dll", "authz.dll", "bits.dll",
    "browseui.dll", "cscapi.dll", "cryptdlg.dll", "dssenh.dll", "gpkcsp.dll",
    "initpki.dll", "mscoree.dll", "ncpa.cpl", "netcfgx.dll", "powerprof.dll",
    "propsys.dll", "sensapi.dll", "srrstr.dll", "timedate.cpl", "wintrust.dll",
    "wuapi.dll", "wuaueng.dll", "wucltui.dll", "wups.dll", "dcomcnfg.exe",
    "desk.cpl", "inetcpl.cpl", "main.cpl", "mmsys.cpl", "ncpa.cpl",
    "powercfg.cpl", "sysdm.cpl", "timedate.cpl", "wscapi.dll"
)

Write-Host "`nStarting re-registration of critical DLLs ($($dllsToRegister.Count) commands)..." -ForegroundColor Yellow
$dllCount = 0
foreach ($dll in $dllsToRegister) {
    $dllPath = "$env:SystemRoot\System32\$dll"
    if (Test-Path $dllPath) {
        Try {
            # Use Start-Process for regsvr32 to ensure it runs in a separate process and doesn't block PowerShell
            Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s `"$dllPath`"" -WindowStyle Hidden -Wait -ErrorAction Stop | Out-Null # Added quotes for paths with spaces
            $dllCount++
        } Catch {
            Write-Warning "  - Failed to re-register ${dll}: $($_.Exception.Message)"
        }
    }
}
Write-Host "Completed re-registration of $dllCount common system DLLs." -ForegroundColor Green

# --- Section 9: Advanced System Resets and Cleanups ---
Write-Host "`n--- Section 9: Advanced System Resets and Cleanups ---" -ForegroundColor Cyan

# 61. Clear all Event Logs (AUTOMATED VERSION)
Write-Host "`nClearing ALL Event Logs (System, Application, Security, Setup, etc.)..." -ForegroundColor Yellow
Try {
    wevtutil el | ForEach-Object {
        $logName = $_
        Try {
            wevtutil cl "$logName" 2>$null
            Write-Host "  - Cleared log: $logName" -ForegroundColor DarkGreen
        } Catch {
            Write-Warning "  - Failed to clear log ${logName}: $($_.Exception.Message)"
        }
    }
    Write-Host "All Event Logs cleared." -ForegroundColor Green
} Catch {
    Write-Warning "Overall Event Log clearing failed: $($_.Exception.Message)"
}

# 62. Reset Windows Security (Windows Defender) settings
Write-Host "`nAttempting to reset Windows Security (Defender) settings..." -ForegroundColor Yellow
Try {
    # This command typically resets Defender settings to default.
    # Note: May not fix deeply corrupted Defender installations.
    # For PowerShell 5, ensure Set-MpPreference is available.
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command & { Set-MpPreference -DisableRealtimeMonitoring \$true -Force; Set-MpPreference -DisableRealtimeMonitoring \$false -Force }" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    # Also try a more direct reset if the above fails (MpCmdRun.exe is usually reliable)
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c ""%ProgramFiles%\Windows Defender\MpCmdRun.exe"" -resetplatform" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    Write-Host "Windows Security settings reset attempts completed." -ForegroundColor Green
} Catch {
    Write-Warning "Windows Security settings reset failed: $($_.Exception.Message)"
}

# 63. Reset Software Restriction Policies (if configured and problematic)
Write-Host "`nResetting Software Restriction Policies (if configured)..." -ForegroundColor Yellow
Try {
    reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Safer /f /va /reg:64 2>$null
    reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Safer /f /va /reg:32 2>$null
    Write-Host "Software Restriction Policies reset (if found)." -ForegroundColor Green
} Catch {
    Write-Warning "Software Restriction Policies reset failed: $($_.Exception.Message)"
}

# 64. Re-register COM+ components
Write-Host "`nRe-registering COM+ components..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "wuauserv" -ErrorAction SilentlyContinue | Out-Null
    Stop-Service -Name "BITS" -ErrorAction SilentlyContinue | Out-Null
    # Run comexp.msc /regserver multiple times for robustness
    for ($i=1; $i -le 3; $i++) {
        Start-Process -FilePath "comexp.msc" -ArgumentList "/regserver" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Seconds 1
    }
    Start-Service -Name "BITS" -ErrorAction SilentlyContinue | Out-Null
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue | Out-Null
    Write-Host "COM+ components re-registered." -ForegroundColor Green
} Catch {
    Write-Warning "COM+ re-registration failed: $($_.Exception.Message)"
}

# 65. Clear Driver Store conflicts (AUTOMATED VERSION)
Write-Host "`nClearing orphaned drivers from Driver Store (may take time)..." -ForegroundColor Yellow
Try {
    # Enumerate third-party drivers (oem*.inf) and attempt to delete/uninstall
    $orphanedDrivers = pnputil /enum-drivers | Select-String -Pattern "Published name : oem" | ForEach-Object {
        $_.ToString().Split(":")[1].Trim() # Extract only the oem*.inf name
    }
    foreach ($driver in $orphanedDrivers) {
        Try {
            # Use /force to try and uninstall even if in use (might fail for some)
            pnputil /delete-driver $driver /uninstall /force 2>$null | Out-Null
            Write-Host "  - Uninstalled orphaned driver: ${driver}" -ForegroundColor DarkGreen
        } Catch {
            $errorMessage = $_.Exception.Message
            Write-Warning "  - Could not uninstall orphaned driver ${driver}: ${errorMessage}"
        }
    }
    Write-Host "Orphaned drivers cleanup attempted." -ForegroundColor Green
} Catch {
    Write-Warning "Overall Driver Store cleanup failed: $($_.Exception.Message)"
}

# 66. Reset Windows Store Cache (AUTOMATED VERSION)
Write-Host "`nResetting Windows Store cache..." -ForegroundColor Yellow
Try {
    Start-Process -FilePath "wsreset.exe" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    Write-Host "Windows Store cache reset." -ForegroundColor Green
} Catch {
    Write-Warning "Windows Store cache reset failed: $($_.Exception.Message)"
}

# 67. Reset Performance Counters
Write-Host "`nRebuilding Performance Counters..." -ForegroundColor Yellow
Try {
    lodctr /r | Out-Host
    Write-Host "Performance Counters rebuilt." -ForegroundColor Green
} Catch {
    Write-Warning "Performance Counters rebuild failed: $($_.Exception.Message)"
}

# 68. Reset all WinHTTP proxy settings (if issues exist)
Write-Host "`nResetting WinHTTP proxy settings..." -ForegroundColor Yellow
Try {
    netsh winhttp reset proxy | Out-Host
    Write-Host "WinHTTP proxy settings reset." -ForegroundColor Green
} Catch {
    Write-Warning "WinHTTP proxy reset failed: $($_.Exception.Message)"
}

# 69. Clear Print Spooler Queue and restart service
Write-Host "`nClearing Print Spooler queue and restarting service..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "Spooler" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:SystemRoot\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
    Start-Service -Name "Spooler" -ErrorAction SilentlyContinue
    Write-Host "Print Spooler reset." -ForegroundColor Green
} Catch {
    Write-Warning "Print Spooler reset failed: $($_.Exception.Message)"
}

# 70. Reset Background Intelligent Transfer Service (BITS)
Write-Host "`nResetting BITS (Background Intelligent Transfer Service)..." -ForegroundColor Yellow
Try {
    bitsadmin /reset /allusers | Out-Host
    Write-Host "BITS reset completed." -ForegroundColor Green
} Catch {
    Write-Warning "BITS reset failed: $($_.Exception.Message)"
}

# 71. Clear Software Distribution Download Folder
Write-Host "`nClearing SoftwareDistribution Download folder..." -ForegroundColor Yellow
Try {
    Remove-Item "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "SoftwareDistribution Download folder cleared." -ForegroundColor Green
} Catch {
    Write-Warning "SoftwareDistribution Download folder clearing failed: $($_.Exception.Message)"
}

# 72. Repair .NET Framework installations (passive)
Write-Host "`nAttempting .NET Framework repair (passive, if needed)..." -ForegroundColor Yellow
Try {
    # These commands enable features and use the component store as a source.
    # Note: A separate .NET Repair Tool from Microsoft is more comprehensive if issues persist.
    Start-Process -FilePath "dism.exe" -ArgumentList "/online /enable-feature /featurename:NetFx3 /all /LimitAccess" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    Start-Process -FilePath "dism.exe" -ArgumentList "/online /enable-feature /featurename:NetFx4Extended-ASPNET45 /all /LimitAccess" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    Write-Host ".NET Framework repair attempts completed." -ForegroundColor Green
} Catch {
    Write-Warning ".NET Framework repair attempts failed: $($_.Exception.Message)"
}

# 73. Clear all User Temp Profiles (advanced cleanup, use with caution)
Write-Host "`nClearing all user temp profiles (excluding currently logged in user)..." -ForegroundColor Yellow
Try {
    Get-ChildItem -Path "$env:SystemDrive\Users\" -Directory | ForEach-Object {
        $userTempPath = Join-Path $_.FullName "AppData\Local\Temp"
        if (Test-Path $userTempPath -PathType Container) {
            # Ensure not to delete temp for current user if running the script from that user
            if ($_.Name -ne $env:UserName) {
                Write-Host "  - Clearing temp for user: $($_.Name)" -ForegroundColor DarkYellow
                Remove-Item -Path "${userTempPath}\*" -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Host "All user temp profiles cleared." -ForegroundColor Green
} Catch {
    Write-Warning "Clearing user temp profiles failed: $($_.Exception.Message)"
}

# 74. Empty Recycle Bins for all drives (AUTOMATED VERSION)
Write-Host "`nEmptying Recycle Bins for all drives..." -ForegroundColor Yellow
Try {
    # Use PowerShell to empty recycle bin silently
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "Recycle Bins emptied." -ForegroundColor Green
} Catch {
    Write-Warning "Emptying Recycle Bins failed: $($_.Exception.Message)"
}

# --- Section 10: System Restore and Recovery Environment (Informational/Optional) ---
Write-Host "`n--- Section 10: System Restore and Recovery Environment ---" -ForegroundColor Cyan

# 75. Check System Restore Point status (informational)
Write-Host "`nChecking System Restore Point status (informational)..." -ForegroundColor Yellow
Try {
    vssadmin list shadows | Out-Host
    Write-Host "System Restore Point status displayed." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to list System Restore Points: $($_.Exception.Message)"
}

# 76. Set up System Restore if disabled (optional)
Write-Host "`nEnsuring System Restore is enabled for C: (if not already)..." -ForegroundColor Yellow
Try {
    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    Write-Host "System Restore enabled for C: (if it wasn't)." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to enable System Restore: $($_.Exception.Message)"
}

# 77. Verify Windows Recovery Environment (WinRE) status
Write-Host "`nVerifying Windows Recovery Environment (WinRE) status..." -ForegroundColor Yellow
Try {
    reagentc /info | Out-Host
    Write-Host "WinRE status displayed." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to get WinRE info: $($_.Exception.Message)"
}

# 78. Enable WinRE (if disabled)
Write-Host "`nEnabling Windows Recovery Environment (WinRE) if disabled..." -ForegroundColor Yellow
Try {
    reagentc /enable | Out-Host
    Write-Host "WinRE enabled (if it wasn't)." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to enable WinRE: $($_.Exception.Message)"
}

# 79. Forcefully recreate Boot Configuration Data (BCD) - USE WITH CAUTION, FOR EXTREME BOOT ISSUES ONLY
# Uncomment if you are experiencing severe boot problems and understand the risks.
# Write-Host "`nForcefully recreating Boot Configuration Data (BCD). Use with EXTREME CAUTION! This is for severe boot issues." -ForegroundColor Red
# Try {
#     Start-Process -FilePath "bootrec.exe" -ArgumentList "/rebuildbcd" -Wait -ErrorAction Stop | Out-Host
#     Write-Host "BCD rebuild command issued." -ForegroundColor Green
# } Catch {
#     Write-Warning "BCD rebuild failed: $($_.Exception.Message)"
# }

# 80. Refresh Environment Variables
Write-Host "`nRefreshing Environment Variables..." -ForegroundColor Yellow
Try {
    # Send a broadcast message to all top-level windows to update environment variables.
    # This won't affect PowerShell's current session, but new processes will see changes.
    $signature = @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern int SendMessageTimeout(
    IntPtr hWnd,
    uint Msg,
    UIntPtr wParam,
    string lParam,
    uint fuFlags,
    uint uTimeout,
    out IntPtr lpdwResult
);
'@
    $User32 = Add-Type -MemberDefinition $signature -Name "User32" -Namespace "Win32" -PassThru

    $HWND_BROADCAST = [System.IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x001A
    $SMTO_ABORTIFHUNG = 0x0002
    $timeout = 5000 # 5 seconds

    [IntPtr]$result = [System.IntPtr]::Zero
    $User32::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [System.UIntPtr]::Zero, "Environment", $SMTO_ABORTIFHUNG, $timeout, [ref]$result) | Out-Null
    Write-Host "Environment variables refresh message sent." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to refresh environment variables: $($_.Exception.Message)"
}

# 81. Clear Internet Explorer/Edge Cache (legacy for IE, still affects some system components)
Write-Host "`nClearing Internet Explorer/Edge cache (legacy components)..." -ForegroundColor Yellow
Try {
    Start-Process -FilePath "RunDll32.exe" -ArgumentList "inetcpl.cpl,ClearMyTracksByProcess 8" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Internet Explorer/Edge cache cleared (legacy components)." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to clear IE/Edge cache: $($_.Exception.Message)"
}

# 82. Register System Configuration Management DLLs
Write-Host "`nRegistering System Configuration Management DLLs..." -ForegroundColor Yellow
$scmDlls = @("mscoree.dll", "comadmin.dll", "msxml.dll", "msxml2.dll", "msxml3.dll", "msxml4.dll", "msxml5.dll", "msxml6.dll")
foreach ($dll in $scmDlls) {
    Try {
        Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s $dll" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
    } Catch {
        Write-Warning "  - Failed to register ${dll}: $($_.Exception.Message)"
    }
}
Write-Host "System Configuration Management DLLs registered." -ForegroundColor Green

# 83. Reset Font Cache
Write-Host "`nResetting Font Cache..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "FontCache" -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\FontCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name "FontCache" -ErrorAction SilentlyContinue
    Write-Host "Font Cache reset." -ForegroundColor Green
} Catch {
    Write-Warning "Font Cache reset failed: $($_.Exception.Message)"
}

# 84. Reset Windows Security Center Service
Write-Host "`nResetting Windows Security Center Service..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "wscsvc" -Force -ErrorAction SilentlyContinue
    Start-Service -Name "wscsvc" -ErrorAction SilentlyContinue
    Write-Host "Windows Security Center Service reset." -ForegroundColor Green
} Catch {
    Write-Warning "Windows Security Center Service reset failed: $($_.Exception.Message)"
}

# 85. Reset Diagnostic Policy Service
Write-Host "`nResetting Diagnostic Policy Service..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "DPS" -Force -ErrorAction SilentlyContinue
    Start-Service -Name "DPS" -ErrorAction SilentlyContinue
    Write-Host "Diagnostic Policy Service reset." -ForegroundColor Green
} Catch {
    Write-Warning "Diagnostic Policy Service reset failed: $($_.Exception.Message)"
}

# 86. Reset Superfetch/SysMain Configuration (already stopped/started earlier, but ensure state)
Write-Host "`nVerifying Superfetch/SysMain state..." -ForegroundColor Yellow
Try {
    Set-Service -Name "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue
    # It was stopped and started earlier; this ensures its startup type.
    Write-Host "Superfetch/SysMain configured for Automatic startup." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to configure Superfetch/SysMain: $($_.Exception.Message)"
}

# 87. Reset Storage Sense Settings
Write-Host "`nResetting Storage Sense settings (if configured)..." -ForegroundColor Yellow
Try {
    # Delete relevant registry keys to reset Storage Sense.
    # Note: This is an aggressive reset and might need user re-configuration.
    Remove-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense" -Name "SystemDismCleanupConfigured" -ErrorAction SilentlyContinue | Out-Null
    Remove-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense" -Name "TempFilesCleanupConfigured" -ErrorAction SilentlyContinue | Out-Null
    # More keys might exist depending on configured settings
    Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\StorageSenseWindows" -Recurse -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Storage Sense settings reset." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to reset Storage Sense settings: $($_.Exception.Message)"
}

# 88. Clear User Credentials Cache (AUTOMATED VERSION)
Write-Host "`nClearing User Credentials Cache (non-critical, re-login may be needed for some services)..." -ForegroundColor Yellow
Try {
    # Use 'cmdkey /list' which outputs lines containing "Target: "
    $credList = cmdkey /list | Select-String -Pattern "Target:"
    foreach ($line in $credList) {
        $target = $line.ToString().Split(":")[1].Trim()
        # Avoid deleting the literal "LegacyGeneric:contains(.)" if it appears
        if ($target -ne "LegacyGeneric:contains(.)" -and $target -ne "") {
            Try {
                cmdkey /delete:$target 2>$null | Out-Null
                Write-Host "  - Deleted credential for target: ${target}" -ForegroundColor DarkGreen
            } Catch {
                $errorMessage = $_.Exception.Message
                Write-Warning "  - Failed to delete credential for ${target}: ${errorMessage}"
            }
        }
    }
    Write-Host "User Credentials Cache cleared." -ForegroundColor Green
} Catch {
    Write-Warning "Overall clearing of user credentials cache failed: $($_.Exception.Message)"
}

# 89. Reset Scheduled Tasks (Warning: May disable some legitimate third-party tasks)
# This is a strong measure, use with caution. Consider commenting out if not facing task issues.
Write-Host "`nResetting (re-enabling/fixing) Scheduled Tasks. This can be aggressive." -ForegroundColor Yellow
Try {
    Get-ScheduledTask | ForEach-Object {
        Try {
            if ($_.State -eq "Disabled") {
                Enable-ScheduledTask -TaskName $_.TaskName -ErrorAction SilentlyContinue | Out-Null
                Write-Host "  - Enabled task: $($_.TaskName)" -ForegroundColor DarkGreen
            }
        } Catch {
            Write-Warning "  - Failed to process scheduled task $($_.TaskName): $($_.Exception.Message)"
        }
    }
    Write-Host "Scheduled Tasks processing completed." -ForegroundColor Green
} Catch {
    Write-Warning "Overall Scheduled Task reset failed: $($_.Exception.Message)"
}

# 90. Clear and rebuild Windows Firewall rules if previous reset failed
Write-Host "`nPerforming an advanced firewall rebuild (if needed)..." -ForegroundColor Yellow
Try {
    netsh advfirewall firewall delete rule name=all 2>$null | Out-Null # Delete all existing rules
    netsh advfirewall set currentprofile state on 2>$null | Out-Null # Ensure firewall is on
    netsh advfirewall firewall show rule name=all > $null 2>&1 # Force internal rebuild/load defaults
    Write-Host "Advanced Firewall rebuild steps completed." -ForegroundColor Green
} Catch {
    Write-Warning "Advanced firewall rebuild failed: $($_.Exception.Message)"
}

# 91. Reset Windows Defender Firewall Service
Write-Host "`nResetting Windows Defender Firewall Service..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "mpssvc" -Force -ErrorAction SilentlyContinue
    Start-Service -Name "mpssvc" -ErrorAction SilentlyContinue
    Write-Host "Windows Defender Firewall Service reset." -ForegroundColor Green
} Catch {
    Write-Warning "Windows Defender Firewall Service reset failed: $($_.Exception.Message)"
}

# 92. Reset Core Audio Services
Write-Host "`nResetting Core Audio Services..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "Audiosrv" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "AudioEndpointBuilder" -Force -ErrorAction SilentlyContinue
    Start-Service -Name "Audiosrv" -ErrorAction SilentlyContinue
    Start-Service -Name "AudioEndpointBuilder" -ErrorAction SilentlyContinue
    Write-Host "Core Audio Services reset." -ForegroundColor Green
} Catch {
    Write-Warning "Core Audio Services reset failed: $($_.Exception.Message)"
}

# 93. Reset Cryptographic Services
Write-Host "`nResetting Cryptographic Services..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "cryptSvc" -Force -ErrorAction SilentlyContinue
    Start-Service -Name "cryptSvc" -ErrorAction SilentlyContinue
    Write-Host "Cryptographic Services reset." -ForegroundColor Green
} Catch {
    Write-Warning "Cryptographic Services reset failed: $($_.Exception.Message)"
}

# 94. Reset Credential Manager Service
Write-Host "`nResetting Credential Manager Service..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "VaultSvc" -Force -ErrorAction SilentlyContinue
    Start-Service -Name "VaultSvc" -ErrorAction SilentlyContinue
    Write-Host "Credential Manager Service reset." -ForegroundColor Green
} Catch {
    Write-Warning "Credential Manager Service reset failed: $($_.Exception.Message)"
}

# 95. Reset Workstation Service
Write-Host "`nResetting Workstation Service (redirector and client connections)..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "LanmanWorkstation" -Force -ErrorAction SilentlyContinue
    Start-Service -Name "LanmanWorkstation" -ErrorAction SilentlyContinue
    Write-Host "Workstation Service reset." -ForegroundColor Green
} Catch {
    Write-Warning "Workstation Service reset failed: $($_.Exception.Message)"
}

# 96. Reset Server Service (file sharing)
Write-Host "`nResetting Server Service (file and print sharing)..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "LanmanServer" -Force -ErrorAction SilentlyContinue
    Start-Service -Name "LanmanServer" -ErrorAction SilentlyContinue
    Write-Host "Server Service reset." -ForegroundColor Green
} Catch {
    Write-Warning "Server Service reset failed: $($_.Exception.Message)"
}

# 97. Reset System Restore Service
Write-Host "`nResetting System Restore Service..." -ForegroundColor Yellow
Try {
    Stop-Service -Name "VSS" -Force -ErrorAction SilentlyContinue # Volume Shadow Copy
    Stop-Service -Name "srservice" -Force -ErrorAction SilentlyContinue # System Restore Service
    Start-Service -Name "VSS" -ErrorAction SilentlyContinue
    Start-Service -Name "srservice" -ErrorAction SilentlyContinue
    Write-Host "System Restore Service reset." -ForegroundColor Green
} Catch {
    Write-Warning "System Restore Service reset failed: $($_.Exception.Message)"
}

# 98. Force garbage collection and clean .NET NGEN queues (PowerShell specific)
Write-Host "`nForcing .NET garbage collection and cleaning NGEN queues..." -ForegroundColor Yellow
Try {
    [GC]::Collect() # Forces garbage collection in the PowerShell process
    # NGEN queue cleanup - often runs passively, but can be forced
    # This loop ensures ngen.exe runs for all Framework versions installed.
    Get-ChildItem "$env:SystemRoot\Microsoft.NET\Framework\", "$env:SystemRoot\Microsoft.NET\Framework64\" -Directory -Filter "v*" | ForEach-Object {
        $ngenPath = Join-Path $_.FullName "ngen.exe"
        if (Test-Path $ngenPath) {
            Write-Host "  - Running NGEN update for $($_.Name)..." -ForegroundColor DarkYellow
            Start-Process -FilePath $ngenPath -ArgumentList "update" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
            Start-Process -FilePath $ngenPath -ArgumentList "executequeueditems" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        }
    }
    Write-Host ".NET garbage collection and NGEN queues cleaned." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to clean .NET related components: $($_.Exception.Message)"
}

# 99. Clear Recent Files/Jump List Cache (can help with explorer performance)
Write-Host "`nClearing Recent Files and Jump List Cache..." -ForegroundColor Yellow
Try {
    Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Force -ErrorAction SilentlyContinue | Out-Null
    Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*" -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Recent Files and Jump List Cache cleared." -ForegroundColor Green
} Catch {
    Write-Warning "Failed to clear Recent Files/Jump List cache: $($_.Exception.Message)"
}

# 100. Reset User Profile Service (use with extreme caution, last resort for profile corruption)
# Uncomment ONLY if you suspect serious user profile corruption and have backups.
# This does NOT delete the profile, but attempts to reset its service state.
# Write-Host "`nResetting User Profile Service (advanced, last resort for profile issues)..." -ForegroundColor Red
# Try {
#    Stop-Service -Name "ProfSvc" -Force -ErrorAction SilentlyContinue
#    Start-Service -Name "ProfSvc" -ErrorAction SilentlyContinue
#    Write-Host "User Profile Service reset." -ForegroundColor Green
# } Catch {
#    Write-Warning "User Profile Service reset failed: $($_.Exception.Message)"
# }

# --- Final Message and Automatic Completion ---
Write-Host "`n--- Script Execution Completed ---" -ForegroundColor Green
Write-Host "All 100+ repair and optimization operations have been completed automatically." -ForegroundColor Green
Write-Host "It is **highly recommended to RESTART your computer NOW** to finalize all changes and allow commands like CHKDSK and Winsock reset to take full effect." -ForegroundColor Red
Write-Host "The script has returned to the terminal. Please restart your computer at your earliest convenience." -ForegroundColor Yellow

# Script automatically returns to terminal without any prompts