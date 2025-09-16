#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Automated Complete System Optimization - SILENT VERSION
.DESCRIPTION
    Runs ALL system optimization commands automatically and silently without any user prompts.
    Includes comprehensive corruption repair, network repair, system purge, and cleanup.
.NOTES
    Must be run as Administrator
    Runs completely silently without any user interaction
#>

# Set execution policy and error handling
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# Global variables
$global:ScriptStartTime = Get-Date
$global:LogPath = "$env:USERPROFILE\Desktop\SystemOptimization_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $global:LogPath -Value $logEntry -ErrorAction SilentlyContinue
}

function Write-ProgressLog {
    param([string]$Message)
    $percentage = [math]::Round(($operationCount/$totalOperations)*100,1)
    Write-Log "[$operationCount/$totalOperations] ($percentage%) $Message"
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-SystemOptimization {
    Write-Log "=== Starting Automated System Optimization ==="
    
    if (-NOT (Test-AdminRights)) {
        Write-Log "ERROR: This script must be run as Administrator!" "ERROR"
        exit 1
    }
    
    $operationCount = 0
    $totalOperations = 25
    
    # OPERATION 1: SDESKTOP - Start Docker Desktop
    $operationCount++
    Write-ProgressLog "Starting Docker Desktop"
    try {
        if (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
            Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Sleep 25
            Write-Log "Docker Desktop started"
        } else {
            Write-Log "Docker Desktop not found"
        }
    } catch {
        Write-Log "Error starting Docker Desktop: $_" "ERROR"
    }
    
    # OPERATION 2: HIBERFIL.SYS AND PAGEFILE CLEANUP
    $operationCount++
    Write-ProgressLog "Hiberfil.sys and pagefile cleanup"
    try {
        Write-Log "Starting hibernation file and pagefile cleanup..."
        
        # Disable hibernation to remove hiberfil.sys
        powercfg -h off 2>$null
        Write-Log "Hibernation disabled"
        
        # Force remove hiberfil.sys if it still exists
        $hiberfilPaths = @("C:\hiberfil.sys", "F:\hiberfil.sys", "D:\hiberfil.sys")
        foreach ($hiberPath in $hiberfilPaths) {
            if (Test-Path $hiberPath) {
                try {
                    takeown /f "$hiberPath" /d y 2>$null | Out-Null
                    icacls "$hiberPath" /grant administrators:F 2>$null | Out-Null
                    Remove-Item -Path $hiberPath -Force -ErrorAction SilentlyContinue
                    if (!(Test-Path $hiberPath)) {
                        Write-Log "Successfully removed: $hiberPath"
                    }
                } catch {
                    Write-Log "Could not remove $hiberPath (may be in use)"
                }
            }
        }
        
        # Clean up swap files and page files
        $swapFiles = @("C:\swapfile.sys", "C:\pagefile.sys", "F:\swapfile.sys", "F:\pagefile.sys")
        foreach ($swapFile in $swapFiles) {
            if (Test-Path $swapFile) {
                try {
                    Remove-Item -Path $swapFile -Force -ErrorAction SilentlyContinue
                    if (!(Test-Path $swapFile)) {
                        Write-Log "Successfully removed: $swapFile"
                    }
                } catch {
                    Write-Log "Could not remove $swapFile (system in use)"
                }
            }
        }
        
        Write-Log "Hiberfil.sys and pagefile cleanup completed"
    } catch {
        Write-Log "Hiberfil.sys cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 3: SYSTEM VOLUME INFORMATION CLEANUP
    $operationCount++
    Write-ProgressLog "System Volume Information cleanup"
    try {
        Write-Log "Starting System Volume Information cleanup on all drives..."
        
        $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -ExpandProperty DeviceID
        
        foreach ($drive in $drives) {
            $sviPath = "$drive\System Volume Information"
            if (Test-Path $sviPath) {
                try {
                    takeown /f "$sviPath" /r /d y 2>$null | Out-Null
                    icacls "$sviPath" /grant administrators:F /t /q 2>$null | Out-Null
                    
                    $sviItems = Get-ChildItem -Path $sviPath -Force -Recurse -ErrorAction SilentlyContinue
                    $itemCount = 0
                    
                    foreach ($item in $sviItems) {
                        try {
                            $item.Attributes = 'Normal'
                            Remove-Item -Path $item.FullName -Force -Recurse -ErrorAction SilentlyContinue
                            $itemCount++
                        } catch { }
                    }
                    
                    Write-Log "Removed $itemCount items from $sviPath"
                } catch {
                    Write-Log "Error processing $sviPath"
                }
            }
        }
        
        Write-Log "System Volume Information cleanup completed"
    } catch {
        Write-Log "System Volume Information cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 4: CCLEANER
    $operationCount++
    Write-ProgressLog "Running CCleaner"
    try {
        if (Test-Path "C:\Program Files\CCleaner\CCleaner64.exe") {
            $ccleanerProcess = Start-Process "C:\Program Files\CCleaner\CCleaner64.exe" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            
            $timeout = 120
            $timer = 0
            while ($ccleanerProcess -and !$ccleanerProcess.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 5
                $timer += 5
            }
            
            if ($ccleanerProcess -and !$ccleanerProcess.HasExited) {
                $ccleanerProcess.Kill()
            }
            
            Write-Log "CCleaner operation completed"
        } else {
            Write-Log "CCleaner not found at default location"
        }
    } catch {
        Write-Log "CCleaner execution failed: $_" "ERROR"
    }
    
    # OPERATION 5: ADWCLEANER
    $operationCount++
    Write-ProgressLog "Running AdwCleaner"
    try {
        if (Test-Path "F:\backup\windowsapps\installed\adw\adwcleaner.exe") {
            $adwProcess = Start-Process "F:\backup\windowsapps\installed\adw\adwcleaner.exe" -ArgumentList "/eula", "/clean", "/noreboot" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            
            $timeout = 60
            $timer = 0
            while ($adwProcess -and !$adwProcess.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 2
                $timer += 2
            }
            
            if ($adwProcess -and !$adwProcess.HasExited) {
                $adwProcess.Kill()
            }
            
            Write-Log "AdwCleaner operation completed"
        } else {
            Write-Log "AdwCleaner not found"
        }
    } catch {
        Write-Log "AdwCleaner execution failed: $_" "ERROR"
    }
    
    # OPERATION 6: COMPREHENSIVE TEMP CLEANUP
    $operationCount++
    Write-ProgressLog "Comprehensive temp cleanup"
    try {
        $userTempPaths = @(
            "$env:TEMP", "$env:TMP", "$env:LOCALAPPDATA\Temp",
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
            "$env:LOCALAPPDATA\Microsoft\Windows\WebCache",
            "$env:LOCALAPPDATA\CrashDumps"
        )
        
        $systemPaths = @(
            "C:\Windows\Temp", "C:\Windows\Prefetch",
            "C:\Windows\SoftwareDistribution\Download"
        )
        
        $allUsersPaths = @()
        $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
        foreach ($user in $users) {
            if ($user.Name -notmatch "^(All Users|Default|Public)$") {
                $allUsersPaths += @(
                    "$($user.FullName)\AppData\Local\Temp",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\INetCache",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\WebCache"
                )
            }
        }
        
        $totalFilesDeleted = 0
        $allPaths = $userTempPaths + $systemPaths + $allUsersPaths
        
        foreach ($path in $allPaths) {
            if (Test-Path $path) {
                try {
                    $files = Get-ChildItem -Path $path -File -Recurse -Force -ErrorAction SilentlyContinue
                    $pathFileCount = 0
                    
                    foreach ($file in $files) {
                        try {
                            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                            $totalFilesDeleted++
                            $pathFileCount++
                        } catch { }
                    }
                    
                    if ($pathFileCount -gt 0) {
                        Write-Log "Cleaned $pathFileCount files from $path"
                    }
                } catch { }
            }
        }
        
        # Run Windows Disk Cleanup
        $cleanupJob = Start-Job {
            Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -Wait
        }
        
        if (Wait-Job $cleanupJob -Timeout 60) {
            Remove-Job $cleanupJob
            Write-Log "Disk Cleanup utility completed"
        } else {
            Stop-Job $cleanupJob
            Remove-Job $cleanupJob
            Get-Process -Name "cleanmgr" -ErrorAction SilentlyContinue | Stop-Process -Force
        }
        
        Write-Log "Temp cleanup completed - Files deleted: $totalFilesDeleted"
    } catch {
        Write-Log "Temp cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 7: WINDOWS CLEANUP SCRIPT
    $operationCount++
    Write-ProgressLog "Windows cleanup script"
    try {
        if (Test-Path "F:\study\shells\powershell\scripts\CleanWin11\a.ps1") {
            $cleanupJob = Start-Job {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "powershell.exe"
                $psi.Arguments = "-File `"F:\study\shells\powershell\scripts\CleanWin11\a.ps1`""
                $psi.RedirectStandardInput = $true
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true
                
                $process = [System.Diagnostics.Process]::Start($psi)
                
                # Send automated responses
                $responses = @("A", "A", "A", "A", "A", "Y", "Y", "Y")
                foreach ($response in $responses) {
                    $process.StandardInput.WriteLine($response)
                    Start-Sleep -Milliseconds 200
                }
                $process.StandardInput.Close()
                
                $timeout = 90
                $timer = 0
                while (!$process.HasExited -and $timer -lt $timeout) {
                    Start-Sleep -Seconds 2
                    $timer += 2
                }
                
                if (!$process.HasExited) {
                    $process.Kill()
                }
            }
            
            if (Wait-Job $cleanupJob -Timeout 120) {
                Remove-Job $cleanupJob
                Write-Log "Windows cleanup script completed"
            } else {
                Stop-Job $cleanupJob
                Remove-Job $cleanupJob
                Write-Log "Windows cleanup script timeout"
            }
        } else {
            Write-Log "Windows cleanup script not found"
        }
    } catch {
        Write-Log "Windows cleanup script failed: $_" "ERROR"
    }
    
    # OPERATION 8: ADVANCED SYSTEM CLEANER
    $operationCount++
    Write-ProgressLog "Advanced System Cleaner"
    try {
        if (Test-Path "F:\study\Platforms\windows\bat\AdvancedSystemCleaner.bat") {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c `"F:\study\Platforms\windows\bat\AdvancedSystemCleaner.bat`""
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $process = [System.Diagnostics.Process]::Start($psi)
            
            $responses = @("3", "n", "y")
            foreach ($response in $responses) {
                $process.StandardInput.WriteLine($response)
                Start-Sleep -Milliseconds 500
            }
            
            $process.StandardInput.Close()
            
            $timeout = 180
            $timer = 0
            while (!$process.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 5
                $timer += 5
            }
            
            if (!$process.HasExited) {
                $process.Kill()
            }
            
            Write-Log "Advanced System Cleaner completed"
        } else {
            Write-Log "Advanced System Cleaner not found"
        }
    } catch {
        Write-Log "Advanced System Cleaner failed: $_" "ERROR"
    }
    
    # OPERATION 9-11: BLEACHBIT (3 RUNS)
    for ($bleachRun = 1; $bleachRun -le 3; $bleachRun++) {
        $operationCount++
        Write-ProgressLog "BleachBit run $bleachRun"
        try {
            if (Test-Path "F:\backup\windowsapps\installed\BleachBit\bleachbit_console.exe") {
                $bleachProcess = Start-Process "F:\backup\windowsapps\installed\BleachBit\bleachbit_console.exe" -ArgumentList "--clean", "system.logs", "system.tmp", "system.recycle_bin", "system.thumbnails", "system.memory_dump", "system.prefetch", "system.clipboard", "system.muicache", "system.rotated_logs", "adobe_reader.tmp", "firefox.cache", "firefox.cookies", "firefox.session_restore", "firefox.forms", "firefox.passwords", "google_chrome.cache", "google_chrome.cookies", "google_chrome.history", "google_chrome.form_history", "microsoft_edge.cache", "microsoft_edge.cookies", "vlc.mru", "windows_explorer.mru", "windows_explorer.recent_documents", "windows_explorer.thumbnails", "deepscan.tmp", "deepscan.backup" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
                
                $timeout = 90
                $timer = 0
                while ($bleachProcess -and !$bleachProcess.HasExited -and $timer -lt $timeout) {
                    Start-Sleep -Seconds 5
                    $timer += 5
                }
                
                if ($bleachProcess -and !$bleachProcess.HasExited) {
                    $bleachProcess.Kill()
                }
                
                Write-Log "BleachBit run $bleachRun completed"
            } else {
                Write-Log "BleachBit not found"
            }
        } catch {
            Write-Log "BleachBit run $bleachRun failed: $_" "ERROR"
        }
    }
    
    # OPERATION 12: ADDITIONAL SYSTEM FILE CLEANUP
    $operationCount++
    Write-ProgressLog "Additional system file cleanup"
    try {
        # Clean Windows Update cache
        $wuCachePaths = @(
            "C:\Windows\SoftwareDistribution\Download\*",
            "C:\Windows\SoftwareDistribution\DataStore\*",
            "C:\Windows\System32\catroot2\*"
        )
        
        foreach ($path in $wuCachePaths) {
            if (Test-Path $path) {
                try {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Cleaned: $path"
                } catch { }
            }
        }
        
        # Clean memory dumps and error reports
        $dumpPaths = @(
            "C:\Windows\Minidump\*",
            "C:\Windows\memory.dmp",
            "C:\ProgramData\Microsoft\Windows\WER\*",
            "C:\Users\*\AppData\Local\CrashDumps\*"
        )
        
        foreach ($path in $dumpPaths) {
            try {
                if (Test-Path $path) {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Cleaned: $path"
                }
            } catch { }
        }
        
        # Clean thumbnail and icon caches
        $cachePaths = @(
            "C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db",
            "C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\iconcache_*.db",
            "C:\Users\*\AppData\Local\IconCache.db",
            "C:\Users\*\AppData\Local\GDIPFONTCACHEV1.DAT"
        )
        
        foreach ($cachePath in $cachePaths) {
            try {
                $files = Get-ChildItem -Path $cachePath -Force -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                }
            } catch { }
        }
        
        Write-Log "Additional system file cleanup completed"
    } catch {
        Write-Log "Additional system file cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 13: WSL ALERT 1
    $operationCount++
    Write-ProgressLog "WSL Alert 1"
    try {
        $distro = 'Ubuntu'
        $user = 'root'
        $core = @('-d', $distro, '-u', $user, '--')
        $escaped = 'alert' -replace '"', '\"'
        wsl @core bash -li -c "$escaped" 2>$null
        Write-Log "WSL Alert 1 completed"
    } catch {
        Write-Log "WSL Alert 1 failed: $_" "ERROR"
    }
    
    # OPERATION 14: DOCKER BACKUP
    $operationCount++
    Write-ProgressLog "Docker backup process"
    try {
        if (Test-Path "F:\backup\windowsapps") {
            Set-Location -Path "F:\backup\windowsapps"
            docker build -t michadockermisha/backup:windowsapps . 2>$null
            docker push michadockermisha/backup:windowsapps 2>$null
            Write-Log "Windows apps backup completed"
        }
        
        if (Test-Path "F:\study") {
            Set-Location -Path "F:\study"
            docker build -t michadockermisha/backup:study . 2>$null
            docker push michadockermisha/backup:study 2>$null
            Write-Log "Study folder backup completed"
        }
        
        if (Test-Path "F:\backup\linux\wsl") {
            Set-Location -Path "F:\backup\linux\wsl"
            docker build -t michadockermisha/backup:wsl . 2>$null
            docker push michadockermisha/backup:wsl 2>$null
            Write-Log "WSL backup completed"
        }
        
        # Clean up Docker containers and images
        $containers = docker ps -a -q 2>$null
        if ($containers) {
            docker stop $containers 2>$null | Out-Null
            docker rm $containers 2>$null | Out-Null
        }
        
        $danglingImages = docker images -q --filter "dangling=true" 2>$null
        if ($danglingImages) {
            docker rmi $danglingImages 2>$null | Out-Null
        }
        
        Write-Log "Docker backup process completed"
    } catch {
        Write-Log "Docker backup process failed: $_" "ERROR"
    }
    
    # OPERATION 15: WSL ALERT 2
    $operationCount++
    Write-ProgressLog "WSL Alert 2"
    try {
        $distro = 'Ubuntu'
        $user = 'root'
        $core = @('-d', $distro, '-u', $user, '--')
        $escaped = 'alert' -replace '"', '\"'
        wsl @core bash -li -c "$escaped" 2>$null
        Write-Log "WSL Alert 2 completed"
    } catch {
        Write-Log "WSL Alert 2 failed: $_" "ERROR"
    }
    
    # OPERATION 16: RESET WSL
    $operationCount++
    Write-ProgressLog "Reset WSL"
    try {
        wsl --shutdown 2>$null
        wsl --unregister ubuntu 2>$null
        
        if (Test-Path "F:\backup\linux\wsl\ubuntu.tar") {
            wsl --import ubuntu C:\wsl2\ubuntu\ F:\backup\linux\wsl\ubuntu.tar 2>$null
            Write-Log "WSL reset completed"
        } else {
            Write-Log "WSL backup file not found"
        }
    } catch {
        Write-Log "WSL reset failed: $_" "ERROR"
    }
    
    # OPERATION 17: FULL WSL2 SETUP
    $operationCount++
    Write-ProgressLog "Full WSL2 setup"
    try {
        $wslBasePath = "C:\wsl2"
        $ubuntuPath1 = "$wslBasePath\ubuntu"
        $ubuntuPath2 = "$wslBasePath\ubuntu2"
        $backupPath = "F:\backup\linux\wsl\ubuntu.tar"
        
        foreach ($distro in @("ubuntu", "ubuntu2")) {
            $existingDistros = wsl --list --quiet 2>$null
            if ($existingDistros -contains $distro) {
                wsl --terminate $distro 2>$null
                wsl --unregister $distro 2>$null
            }
        }
        
        foreach ($path in @($ubuntuPath1, $ubuntuPath2)) {
            if (Test-Path "$path\ext4.vhdx") {
                Remove-Item "$path\ext4.vhdx" -Force -ErrorAction SilentlyContinue
            }
            if (-not (Test-Path $path)) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
            }
        }
        
        $features = @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")
        foreach ($f in $features) {
            $status = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue
            if ($status -and $status.State -ne "Enabled") {
                Enable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction SilentlyContinue
            }
        }
        
        foreach ($svc in @("vmms", "vmcompute")) {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s -and $s.Status -ne "Running") {
                Start-Service -Name $svc -ErrorAction SilentlyContinue
            }
        }
        
        wsl --update 2>$null
        wsl --set-default-version 2 2>$null
        
        if (Test-Path $backupPath) {
            wsl --import ubuntu $ubuntuPath1 $backupPath 2>$null
            wsl --import ubuntu2 $ubuntuPath2 $backupPath 2>$null
        }
        
        $wslConfig = @"
[wsl2]
memory=4GB
processors=2
swap=2GB
localhostForwarding=true

[experimental]
autoMemoryReclaim=gradual
networkingMode=mirrored
dnsTunneling=true
firewall=true
autoProxy=true
"@
        Set-Content "$env:USERPROFILE\.wslconfig" $wslConfig -Force
        
        wsl --set-default ubuntu 2>$null
        Write-Log "WSL2 setup completed"
    } catch {
        Write-Log "WSL2 setup failed: $_" "ERROR"
    }
    
    # OPERATION 18: DOCKER CLEANUP
    $operationCount++
    Write-ProgressLog "Final Docker cleanup"
    try {
        $dockerCleanupJob = Start-Job {
            docker system prune -a --volumes -f 2>$null
            docker builder prune -a -f 2>$null
            docker buildx prune -a -f 2>$null
            Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
            wsl --shutdown 2>$null
            wsl --export docker-desktop "$env:TEMP\docker-desktop-backup.tar" 2>$null
            wsl --unregister docker-desktop 2>$null
            Remove-Item "C:\Users\misha\AppData\Local\Docker\wsl\disk\docker_data.vhdx" -Force -ErrorAction SilentlyContinue
            wsl --import docker-desktop "C:\Users\misha\AppData\Local\Docker\wsl\distro" "$env:TEMP\docker-desktop-backup.tar" 2>$null
            Remove-Item "$env:TEMP\docker-desktop-backup.tar" -Force -ErrorAction SilentlyContinue
            Optimize-VHD -Path "C:\Users\misha\AppData\Local\Docker\wsl\disk\docker_data.vhdx" -Mode Full -ErrorAction SilentlyContinue
            & "C:\Program Files\Docker\Docker\Docker Desktop.exe" 2>$null
        }
        
        if (Wait-Job $dockerCleanupJob -Timeout 180) {
            Remove-Job $dockerCleanupJob
            Write-Log "Docker cleanup completed"
        } else {
            Stop-Job $dockerCleanupJob
            Remove-Job $dockerCleanupJob
            Write-Log "Docker cleanup timeout"
            
            $processesToKill = @("docker", "wsl", "vssadmin")
            foreach ($proc in $processesToKill) {
                Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Log "Docker cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 19: COMPREHENSIVE NETWORK REPAIR
    $operationCount++
    Write-ProgressLog "Comprehensive network repair"
    try {
        Write-Log "Starting comprehensive network repair..."
        
        # Release and Renew DHCP
        Start-Process "ipconfig" -ArgumentList "/release" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        Start-Process "ipconfig" -ArgumentList "/renew" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        
        # Clear Hosts File
        $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
        if (Test-Path $hostsPath) {
            Copy-Item $hostsPath "$hostsPath.backup" -Force -ErrorAction SilentlyContinue
            $defaultHosts = @"
# localhost name resolution is handled within DNS itself.
#	127.0.0.1       localhost
#	::1             localhost
"@
            Set-Content -Path $hostsPath -Value $defaultHosts -Force
        }
        
        # Clear Static IP Settings
        $adapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        foreach ($adapter in $adapters) {
            try {
                $adapter.EnableDHCP() | Out-Null
                $adapter.SetDNSServerSearchOrder() | Out-Null
            } catch { }
        }
        
        # Set Google DNS
        netsh interface ip set dns name="Wi-Fi" source=static addr=8.8.8.8 2>$null
        netsh interface ip add dns name="Wi-Fi" addr=8.8.4.4 index=2 2>$null
        netsh interface ip set dns name="Ethernet" source=static addr=8.8.8.8 2>$null
        netsh interface ip add dns name="Ethernet" addr=8.8.4.4 index=2 2>$null
        
        # Flush DNS
        Start-Process "ipconfig" -ArgumentList "/flushdns" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        
        # Clear ARP/Route Table
        Start-Process "arp" -ArgumentList "-d", "*" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        Start-Process "route" -ArgumentList "-f" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        Start-Process "netsh" -ArgumentList "int", "ip", "delete", "arpcache" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        
        # NetBIOS Reload
        Start-Process "nbtstat" -ArgumentList "-R" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        Start-Process "nbtstat" -ArgumentList "-RR" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        
        # Enable adapters
        Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Ethernet*" -or $_.Name -like "*LAN*" } | Enable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
        Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Wireless*" -or $_.InterfaceDescription -like "*Wi-Fi*" -or $_.Name -like "*Wi-Fi*" } | Enable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
        
        # Set network services to default
        $networkServices = @{
            "Server" = "Automatic"; "Workstation" = "Automatic"; "Netlogon" = "Automatic"
            "LanmanServer" = "Automatic"; "LanmanWorkstation" = "Automatic"
            "Dhcp" = "Automatic"; "Dnscache" = "Automatic"; "NlaSvc" = "Automatic"
            "Wcmsvc" = "Automatic"; "Wlansvc" = "Automatic"
        }
        
        foreach ($service in $networkServices.GetEnumerator()) {
            try {
                $svc = Get-Service -Name $service.Key -ErrorAction SilentlyContinue
                if ($svc) {
                    Set-Service -Name $service.Key -StartupType $service.Value -ErrorAction SilentlyContinue
                    if ($service.Value -eq "Automatic" -and $svc.Status -ne "Running") {
                        Start-Service -Name $service.Key -ErrorAction SilentlyContinue
                    }
                }
            } catch { }
        }
        
        Write-Log "Network repair completed"
    } catch {
        Write-Log "Network repair failed: $_" "ERROR"
    }
    
    # OPERATION 20: NETWORK OPTIMIZATION
    $operationCount++
    Write-ProgressLog "Network optimization"
    try {
        Write-Log "Starting network optimization..."
        
        # TCP/IP optimizations
        netsh int tcp set global autotuninglevel=normal 2>$null
        netsh int tcp set global ecncapability=enabled 2>$null
        netsh int tcp set global timestamps=disabled 2>$null
        netsh int tcp set global initialRto=1000 2>$null
        netsh int tcp set global rsc=enabled 2>$null
        netsh int tcp set global nonsackrttresiliency=disabled 2>$null
        netsh int tcp set global maxsynretransmissions=2 2>$null
        netsh int tcp set global chimney=enabled 2>$null
        netsh int tcp set global windowsscaling=enabled 2>$null
        netsh int tcp set global dca=enabled 2>$null
        netsh int tcp set global netdma=enabled 2>$null
        netsh int tcp set supplemental Internet congestionprovider=ctcp 2>$null
        netsh int tcp set heuristics disabled 2>$null
        netsh int tcp set global rss=enabled 2>$null
        netsh int tcp set global fastopen=enabled 2>$null
        
        # IP settings
        netsh int ip set global taskoffload=enabled 2>$null
        netsh int ip set global neighborcachelimit=8192 2>$null
        netsh int ip set global routecachelimit=8192 2>$null
        netsh int ip set global dhcpmediasense=enabled 2>$null
        netsh int ip set global sourceroutingbehavior=dontforward 2>$null
        netsh int ipv4 set global randomizeidentifiers=disabled 2>$null
        netsh int ipv6 set global randomizeidentifiers=disabled 2>$null
        netsh int ipv6 set teredo disabled 2>$null
        netsh int ipv6 set 6to4 disabled 2>$null
        netsh int ipv6 set isatap disabled 2>$null
        
        # Registry optimizations
        $tcpipSettings = @{
            "NetworkThrottlingIndex" = 0xffffffff; "DefaultTTL" = 64; "TCPNoDelay" = 1
            "Tcp1323Opts" = 3; "TCPAckFrequency" = 1; "TCPDelAckTicks" = 0
            "MaxFreeTcbs" = 65536; "MaxHashTableSize" = 65536; "MaxUserPort" = 65534
            "TcpTimedWaitDelay" = 30; "TcpUseRFC1122UrgentPointer" = 0
            "TcpMaxDataRetransmissions" = 3; "KeepAliveTime" = 7200000
            "KeepAliveInterval" = 1000; "EnablePMTUDiscovery" = 1
        }
        
        $tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        foreach ($name in $tcpipSettings.Keys) {
            try {
                Set-ItemProperty -Path $tcpipPath -Name $name -Value $tcpipSettings[$name] -Type DWord -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        
        # DNS optimization
        netsh interface ip set dns name="Wi-Fi" source=static addr=1.1.1.1 2>$null
        netsh interface ip add dns name="Wi-Fi" addr=1.0.0.1 index=2 2>$null
        netsh interface ip add dns name="Wi-Fi" addr=8.8.8.8 index=3 2>$null
        netsh interface ip add dns name="Wi-Fi" addr=8.8.4.4 index=4 2>$null
        
        # Power optimization
        powercfg -setactive SCHEME_MIN 2>$null
        powercfg -change -monitor-timeout-ac 0 2>$null
        powercfg -change -disk-timeout-ac 0 2>$null
        powercfg -change -standby-timeout-ac 0 2>$null
        powercfg -change -hibernate-timeout-ac 0 2>$null
        
        # Final cleanup
        ipconfig /flushdns 2>$null
        ipconfig /registerdns 2>$null
        netsh int ip reset C:\resetlog.txt 2>$null
        netsh winsock reset 2>$null
        netsh winhttp reset proxy 2>$null
        
        Write-Log "Network optimization completed"
    } catch {
        Write-Log "Network optimization failed: $_" "ERROR"
    }
    
    # OPERATION 21: PC PERFORMANCE OPTIMIZATION
    $operationCount++
    Write-ProgressLog "PC performance optimization"
    try {
        Write-Log "Starting PC performance optimization..."
        
        # Registry performance optimizations
        $systemPerfSettings = @{
            "SystemResponsiveness" = 0; "NetworkThrottlingIndex" = 0xffffffff
            "Win32PrioritySeparation" = 38; "IRQ8Priority" = 1; "PCILatency" = 0
            "DisablePagingExecutive" = 1; "LargeSystemCache" = 1
            "IoPageLockLimit" = 0x4000000; "PoolUsageMaximum" = 96
            "PagedPoolSize" = 0xffffffff; "NonPagedPoolSize" = 0x0
            "SessionPoolSize" = 192; "SecondLevelDataCache" = 1024
            "ThirdLevelDataCache" = 8192
        }
        
        $perfPaths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl",
            "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        )
        
        foreach ($path in $perfPaths) {
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            foreach ($setting in $systemPerfSettings.GetEnumerator()) {
                try {
                    Set-ItemProperty -Path $path -Name $setting.Key -Value $setting.Value -Type DWord -Force -ErrorAction SilentlyContinue
                } catch { }
            }
        }
        
        # CPU optimizations
        $cpuSettings = @{
            "UsePlatformClock" = 1; "TSCFrequency" = 0; "DisableDynamicTick" = 1; "UseQPC" = 1
        }
        
        $cpuPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
        foreach ($setting in $cpuSettings.GetEnumerator()) {
            try {
                Set-ItemProperty -Path $cpuPath -Name $setting.Key -Value $setting.Value -Type DWord -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        
        # Visual performance
        $visualSettings = @{
            "VisualEffects" = 2; "DragFullWindows" = 0; "MenuShowDelay" = 0
            "MinAnimate" = 0; "TaskbarAnimations" = 0; "ListviewWatermark" = 0
            "UserPreferencesMask" = [byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)
        }
        
        $visualPaths = @(
            "HKCU:\Control Panel\Desktop",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects",
            "HKCU:\Control Panel\Desktop\WindowMetrics"
        )
        
        foreach ($path in $visualPaths) {
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            foreach ($setting in $visualSettings.GetEnumerator()) {
                try {
                    if ($setting.Key -eq "UserPreferencesMask") {
                        Set-ItemProperty -Path $path -Name $setting.Key -Value $setting.Value -Type Binary -Force -ErrorAction SilentlyContinue
                    } else {
                        Set-ItemProperty -Path $path -Name $setting.Key -Value $setting.Value -Type DWord -Force -ErrorAction SilentlyContinue
                    }
                } catch { }
            }
        }
        
        # Disable unnecessary services
        $servicesToDisable = @(
            "BITS", "wuauserv", "DoSvc", "MapsBroker", "RetailDemo", "DiagTrack",
            "dmwappushservice", "WSearch", "SysMain", "Themes", "TabletInputService",
            "Fax", "WbioSrvc", "WMPNetworkSvc", "WerSvc", "Spooler", "AxInstSV",
            "Browser", "CscService", "TrkWks", "SharedAccess", "lmhosts", "RemoteAccess",
            "SessionEnv", "TermService", "UmRdpService", "AppVClient", "NetTcpPortSharing",
            "wisvc", "WinDefend", "SecurityHealthService", "wscsvc"
        )
        
        foreach ($service in $servicesToDisable) {
            try {
                $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                if ($svc -and $svc.Status -eq "Running") {
                    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
                }
            } catch { }
        }
        
        # Gaming optimizations
        $gamingPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        $gamingSettings = @{
            "Affinity" = 0; "Background Only" = "False"; "BackgroundPriority" = 0
            "Clock Rate" = 10000; "GPU Priority" = 8; "Priority" = 6
            "Scheduling Category" = "High"; "SFIO Priority" = "High"
        }
        
        if (-not (Test-Path $gamingPath)) { New-Item -Path $gamingPath -Force | Out-Null }
        foreach ($setting in $gamingSettings.GetEnumerator()) {
            try {
                Set-ItemProperty -Path $gamingPath -Name $setting.Key -Value $setting.Value -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        
        # Disable Windows features
        $featuresToDisable = @(
            "TelnetClient", "TFTP", "TIFFIFilter", "Windows-Defender-Default-Definitions",
            "WorkFolders-Client", "Printing-XPSServices-Features", "FaxServicesClientPackage"
        )
        
        foreach ($feature in $featuresToDisable) {
            try {
                Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue
            } catch { }
        }
        
        Write-Log "PC performance optimization completed"
    } catch {
        Write-Log "PC performance optimization failed: $_" "ERROR"
    }
    
    # OPERATION 22: COMPREHENSIVE DISK CLEANUP
    $operationCount++
    Write-ProgressLog "Comprehensive disk cleanup"
    try {
        Write-Log "Starting comprehensive disk cleanup..."
        
        # C: drive cleanup paths
        $cDriveCleanupPaths = @(
            "C:\Windows\Temp\*", "C:\Windows\Prefetch\*", "C:\Windows\SoftwareDistribution\Download\*",
            "C:\Windows\Logs\*", "C:\Windows\Panther\*", "C:\Windows\System32\LogFiles\*",
            "C:\Windows\System32\config\systemprofile\AppData\Local\Temp\*",
            "C:\Windows\ServiceProfiles\LocalService\AppData\Local\Temp\*",
            "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp\*",
            "C:\Windows\Downloaded Program Files\*", "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*",
            "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*", "C:\ProgramData\Microsoft\Windows\WER\Temp\*",
            "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\*", "C:\ProgramData\Microsoft\Diagnosis\*",
            "C:\ProgramData\Microsoft\Windows Defender\Scans\History\*", "C:\ProgramData\Package Cache\*",
            "C:\Windows\Installer\*.msi", "C:\Windows\Installer\*.msp"
        )
        
        # User-specific cleanup
        $userCleanupPaths = @()
        $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
        foreach ($user in $users) {
            if ($user.Name -notmatch "^(All Users|Default|Public)$") {
                $userCleanupPaths += @(
                    "$($user.FullName)\AppData\Local\Temp\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\INetCache\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\WebCache\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\Explorer\iconcache_*.db",
                    "$($user.FullName)\AppData\Local\CrashDumps\*",
                    "$($user.FullName)\AppData\Local\Google\Chrome\User Data\Default\Cache\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Edge\User Data\Default\Cache\*"
                )
            }
        }
        
        # F: drive cleanup
        $fDriveCleanupPaths = @()
        if (Test-Path "F:\") {
            $fDriveCleanupPaths = @(
                "F:\temp\*", "F:\tmp\*", "F:\Temp\*", "F:\Windows.old\*",
                "F:\`$Recycle.Bin\*", "F:\System Volume Information\*",
                "F:\hiberfil.sys", "F:\pagefile.sys", "F:\swapfile.sys"
            )
        }
        
        $totalFilesDeleted = 0
        $allPaths = $cDriveCleanupPaths + $userCleanupPaths + $fDriveCleanupPaths
        
        foreach ($path in $allPaths) {
            if (Test-Path $path) {
                try {
                    $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
                    $pathFileCount = 0
                    
                    foreach ($item in $items) {
                        try {
                            if ($item.PSIsContainer) {
                                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                            } else {
                                Remove-Item -Path $item.FullName -Force -ErrorAction SilentlyContinue
                            }
                            $pathFileCount++
                        } catch { }
                    }
                    
                    $totalFilesDeleted += $pathFileCount
                } catch { }
            }
        }
        
        Write-Log "Disk cleanup completed - Files deleted: $totalFilesDeleted"
    } catch {
        Write-Log "Disk cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 23: WISE REGISTRY CLEANER
    $operationCount++
    Write-ProgressLog "Wise Registry Cleaner"
    try {
        if (Test-Path "F:\backup\windowsapps\installed\Wise\Wise Registry Cleaner\WiseRegCleaner.exe") {
            $wiseRegProcess = Start-Process 'F:\backup\windowsapps\installed\Wise\Wise Registry Cleaner\WiseRegCleaner.exe' -ArgumentList '-a','-all' -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            
            $timeout = 300
            $timer = 0
            while ($wiseRegProcess -and !$wiseRegProcess.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 5
                $timer += 5
            }
            
            if ($wiseRegProcess -and !$wiseRegProcess.HasExited) {
                $wiseRegProcess.Kill()
            }
            
            Write-Log "Wise Registry Cleaner completed"
        } else {
            Write-Log "Wise Registry Cleaner not found"
        }
    } catch {
        Write-Log "Wise Registry Cleaner failed: $_" "ERROR"
    }
    
    # OPERATION 24: WISE DISK CLEANER
    $operationCount++
    Write-ProgressLog "Wise Disk Cleaner"
    try {
        if (Test-Path "F:\backup\windowsapps\installed\Wise\Wise Disk Cleaner\WiseDiskCleaner.exe") {
            $wiseDiskProcess = Start-Process 'F:\backup\windowsapps\installed\Wise\Wise Disk Cleaner\WiseDiskCleaner.exe' -ArgumentList '-a','-adv' -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            
            $timeout = 120
            $timer = 0
            while ($wiseDiskProcess -and !$wiseDiskProcess.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 5
                $timer += 5
            }
            
            if ($wiseDiskProcess -and !$wiseDiskProcess.HasExited) {
                $wiseDiskProcess.Kill()
            }
            
            Write-Log "Wise Disk Cleaner completed"
        } else {
            Write-Log "Wise Disk Cleaner not found"
        }
    } catch {
        Write-Log "Wise Disk Cleaner failed: $_" "ERROR"
    }
    
    # OPERATION 25: FINAL CLEANUP
    $operationCount++
    Write-ProgressLog "Final cleanup"
    try {
        Write-Log "Starting final cleanup..."
        
        # Remove unnecessary folders
        $foldersToRemove = @(
            "C:\AdwCleaner", "C:\inetpub", "C:\PerfLogs", "C:\Logs", "C:\temp",
            "C:\tmp", "C:\Windows.old", "C:\Intel", "C:\AMD", "C:\NVIDIA",
            "C:\OneDriveTemp", "C:\Recovery\WindowsRE"
        )
        
        foreach ($folder in $foldersToRemove) {
            try {
                if (Test-Path $folder) {
                    takeown /f "$folder" /r /d y 2>$null | Out-Null
                    icacls "$folder" /grant administrators:F /t /q 2>$null | Out-Null
                    Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                    
                    if (!(Test-Path $folder)) {
                        Write-Log "Successfully removed folder: $folder"
                    }
                }
            } catch { }
        }
        
        # Final installer cleanup
        $additionalCleanup = @(
            "C:\Windows\Installer\*.msi", "C:\Windows\Downloaded Program Files\*",
            "C:\Windows\Temp\*", "C:\Windows\Logs\*", "C:\Windows\Panther\*",
            "C:\Windows\SoftwareDistribution\Download\*"
        )
        
        foreach ($pattern in $additionalCleanup) {
            try {
                $items = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
                if ($items) {
                    Remove-Item -Path $pattern -Recurse -Force -ErrorAction SilentlyContinue
                }
            } catch { }
        }
        
        # Force kill hanging processes
        $processesToKill = @("CCleaner*", "adwcleaner", "bleachbit*", "cleanmgr", "wsreset", "dism", "WiseRegCleaner", "WiseDiskCleaner")
        foreach ($processPattern in $processesToKill) {
            $processes = Get-Process -Name $processPattern -ErrorAction SilentlyContinue
            if ($processes) {
                $processes | Stop-Process -Force -ErrorAction SilentlyContinue
                
                Start-Sleep 2
                $remainingProcesses = Get-Process -Name $processPattern -ErrorAction SilentlyContinue
                if ($remainingProcesses) {
                    taskkill /f /im "$processPattern.exe" 2>$null
                }
            }
        }
        
        Write-Log "Final cleanup completed"
    } catch {
        Write-Log "Final cleanup failed: $_" "ERROR"
    }
    
    $totalTime = (Get-Date) - $global:ScriptStartTime
    Write-Log "=== System Optimization Completed in $($totalTime.TotalMinutes.ToString('F1')) minutes ==="
    Write-Log "Log saved to: $global:LogPath"
    Write-Log "Script completed successfully without requiring user interaction"
}

# START THE OPTIMIZATION PROCESS
try {
    Start-SystemOptimization
} catch {
    Write-Log "Script encountered an error: $_" "ERROR"
} finally {
    # Ensure cleanup always runs
    try {
        $remainingJobs = Get-Job -State Running -ErrorAction SilentlyContinue
        if ($remainingJobs) {
            $remainingJobs | Stop-Job -ErrorAction SilentlyContinue
            $remainingJobs | Remove-Job -ErrorAction SilentlyContinue
        }
    } catch { }
}

# Clean exit
Write-Log "=== SCRIPT COMPLETED SUCCESSFULLY ==="
$finalTime = (Get-Date) - $global:ScriptStartTime
Write-Log "Total script runtime: $($finalTime.TotalMinutes.ToString('F1')) minutes"
Write-Log "Script finished at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Clear any error variables and exit cleanly
$Error.Clear()
try {
    Get-EventSubscriber -ErrorAction SilentlyContinue | Unregister-Event -ErrorAction SilentlyContinue
} catch { }

exit 0#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Automated Complete System Optimization - SILENT VERSION
.DESCRIPTION
    Runs ALL system optimization commands automatically and silently without any user prompts.
    Includes comprehensive corruption repair, network repair, system purge, and cleanup.
.NOTES
    Must be run as Administrator
    Runs completely silently without any user interaction
#>

# Set execution policy and error handling
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# Global variables
$global:ScriptStartTime = Get-Date
$global:LogPath = "$env:USERPROFILE\Desktop\SystemOptimization_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $global:LogPath -Value $logEntry -ErrorAction SilentlyContinue
}

function Write-ProgressLog {
    param([string]$Message)
    $percentage = [math]::Round(($operationCount/$totalOperations)*100,1)
    Write-Log "[$operationCount/$totalOperations] ($percentage%) $Message"
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-SystemOptimization {
    Write-Log "=== Starting Automated System Optimization ==="
    
    if (-NOT (Test-AdminRights)) {
        Write-Log "ERROR: This script must be run as Administrator!" "ERROR"
        exit 1
    }
    
    $operationCount = 0
    $totalOperations = 25
    
    # OPERATION 1: SDESKTOP - Start Docker Desktop
    $operationCount++
    Write-ProgressLog "Starting Docker Desktop"
    try {
        if (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
            Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Sleep 25
            Write-Log "Docker Desktop started"
        } else {
            Write-Log "Docker Desktop not found"
        }
    } catch {
        Write-Log "Error starting Docker Desktop: $_" "ERROR"
    }
    
    # OPERATION 2: HIBERFIL.SYS AND PAGEFILE CLEANUP
    $operationCount++
    Write-ProgressLog "Hiberfil.sys and pagefile cleanup"
    try {
        Write-Log "Starting hibernation file and pagefile cleanup..."
        
        # Disable hibernation to remove hiberfil.sys
        powercfg -h off 2>$null
        Write-Log "Hibernation disabled"
        
        # Force remove hiberfil.sys if it still exists
        $hiberfilPaths = @("C:\hiberfil.sys", "F:\hiberfil.sys", "D:\hiberfil.sys")
        foreach ($hiberPath in $hiberfilPaths) {
            if (Test-Path $hiberPath) {
                try {
                    takeown /f "$hiberPath" /d y 2>$null | Out-Null
                    icacls "$hiberPath" /grant administrators:F 2>$null | Out-Null
                    Remove-Item -Path $hiberPath -Force -ErrorAction SilentlyContinue
                    if (!(Test-Path $hiberPath)) {
                        Write-Log "Successfully removed: $hiberPath"
                    }
                } catch {
                    Write-Log "Could not remove $hiberPath (may be in use)"
                }
            }
        }
        
        # Clean up swap files and page files
        $swapFiles = @("C:\swapfile.sys", "C:\pagefile.sys", "F:\swapfile.sys", "F:\pagefile.sys")
        foreach ($swapFile in $swapFiles) {
            if (Test-Path $swapFile) {
                try {
                    Remove-Item -Path $swapFile -Force -ErrorAction SilentlyContinue
                    if (!(Test-Path $swapFile)) {
                        Write-Log "Successfully removed: $swapFile"
                    }
                } catch {
                    Write-Log "Could not remove $swapFile (system in use)"
                }
            }
        }
        
        Write-Log "Hiberfil.sys and pagefile cleanup completed"
    } catch {
        Write-Log "Hiberfil.sys cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 3: SYSTEM VOLUME INFORMATION CLEANUP
    $operationCount++
    Write-ProgressLog "System Volume Information cleanup"
    try {
        Write-Log "Starting System Volume Information cleanup on all drives..."
        
        $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -ExpandProperty DeviceID
        
        foreach ($drive in $drives) {
            $sviPath = "$drive\System Volume Information"
            if (Test-Path $sviPath) {
                try {
                    takeown /f "$sviPath" /r /d y 2>$null | Out-Null
                    icacls "$sviPath" /grant administrators:F /t /q 2>$null | Out-Null
                    
                    $sviItems = Get-ChildItem -Path $sviPath -Force -Recurse -ErrorAction SilentlyContinue
                    $itemCount = 0
                    
                    foreach ($item in $sviItems) {
                        try {
                            $item.Attributes = 'Normal'
                            Remove-Item -Path $item.FullName -Force -Recurse -ErrorAction SilentlyContinue
                            $itemCount++
                        } catch { }
                    }
                    
                    Write-Log "Removed $itemCount items from $sviPath"
                } catch {
                    Write-Log "Error processing $sviPath"
                }
            }
        }
        
        Write-Log "System Volume Information cleanup completed"
    } catch {
        Write-Log "System Volume Information cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 4: CCLEANER
    $operationCount++
    Write-ProgressLog "Running CCleaner"
    try {
        if (Test-Path "C:\Program Files\CCleaner\CCleaner64.exe") {
            $ccleanerProcess = Start-Process "C:\Program Files\CCleaner\CCleaner64.exe" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            
            $timeout = 120
            $timer = 0
            while ($ccleanerProcess -and !$ccleanerProcess.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 5
                $timer += 5
            }
            
            if ($ccleanerProcess -and !$ccleanerProcess.HasExited) {
                $ccleanerProcess.Kill()
            }
            
            Write-Log "CCleaner operation completed"
        } else {
            Write-Log "CCleaner not found at default location"
        }
    } catch {
        Write-Log "CCleaner execution failed: $_" "ERROR"
    }
    
    # OPERATION 5: ADWCLEANER
    $operationCount++
    Write-ProgressLog "Running AdwCleaner"
    try {
        if (Test-Path "F:\backup\windowsapps\installed\adw\adwcleaner.exe") {
            $adwProcess = Start-Process "F:\backup\windowsapps\installed\adw\adwcleaner.exe" -ArgumentList "/eula", "/clean", "/noreboot" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            
            $timeout = 60
            $timer = 0
            while ($adwProcess -and !$adwProcess.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 2
                $timer += 2
            }
            
            if ($adwProcess -and !$adwProcess.HasExited) {
                $adwProcess.Kill()
            }
            
            Write-Log "AdwCleaner operation completed"
        } else {
            Write-Log "AdwCleaner not found"
        }
    } catch {
        Write-Log "AdwCleaner execution failed: $_" "ERROR"
    }
    
    # OPERATION 6: COMPREHENSIVE TEMP CLEANUP
    $operationCount++
    Write-ProgressLog "Comprehensive temp cleanup"
    try {
        $userTempPaths = @(
            "$env:TEMP", "$env:TMP", "$env:LOCALAPPDATA\Temp",
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
            "$env:LOCALAPPDATA\Microsoft\Windows\WebCache",
            "$env:LOCALAPPDATA\CrashDumps"
        )
        
        $systemPaths = @(
            "C:\Windows\Temp", "C:\Windows\Prefetch",
            "C:\Windows\SoftwareDistribution\Download"
        )
        
        $allUsersPaths = @()
        $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
        foreach ($user in $users) {
            if ($user.Name -notmatch "^(All Users|Default|Public)$") {
                $allUsersPaths += @(
                    "$($user.FullName)\AppData\Local\Temp",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\INetCache",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\WebCache"
                )
            }
        }
        
        $totalFilesDeleted = 0
        $allPaths = $userTempPaths + $systemPaths + $allUsersPaths
        
        foreach ($path in $allPaths) {
            if (Test-Path $path) {
                try {
                    $files = Get-ChildItem -Path $path -File -Recurse -Force -ErrorAction SilentlyContinue
                    $pathFileCount = 0
                    
                    foreach ($file in $files) {
                        try {
                            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                            $totalFilesDeleted++
                            $pathFileCount++
                        } catch { }
                    }
                    
                    if ($pathFileCount -gt 0) {
                        Write-Log "Cleaned $pathFileCount files from $path"
                    }
                } catch { }
            }
        }
        
        # Run Windows Disk Cleanup
        $cleanupJob = Start-Job {
            Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -Wait
        }
        
        if (Wait-Job $cleanupJob -Timeout 60) {
            Remove-Job $cleanupJob
            Write-Log "Disk Cleanup utility completed"
        } else {
            Stop-Job $cleanupJob
            Remove-Job $cleanupJob
            Get-Process -Name "cleanmgr" -ErrorAction SilentlyContinue | Stop-Process -Force
        }
        
        Write-Log "Temp cleanup completed - Files deleted: $totalFilesDeleted"
    } catch {
        Write-Log "Temp cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 7: WINDOWS CLEANUP SCRIPT
    $operationCount++
    Write-ProgressLog "Windows cleanup script"
    try {
        if (Test-Path "F:\study\shells\powershell\scripts\CleanWin11\a.ps1") {
            $cleanupJob = Start-Job {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "powershell.exe"
                $psi.Arguments = "-File `"F:\study\shells\powershell\scripts\CleanWin11\a.ps1`""
                $psi.RedirectStandardInput = $true
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true
                
                $process = [System.Diagnostics.Process]::Start($psi)
                
                # Send automated responses
                $responses = @("A", "A", "A", "A", "A", "Y", "Y", "Y")
                foreach ($response in $responses) {
                    $process.StandardInput.WriteLine($response)
                    Start-Sleep -Milliseconds 200
                }
                $process.StandardInput.Close()
                
                $timeout = 90
                $timer = 0
                while (!$process.HasExited -and $timer -lt $timeout) {
                    Start-Sleep -Seconds 2
                    $timer += 2
                }
                
                if (!$process.HasExited) {
                    $process.Kill()
                }
            }
            
            if (Wait-Job $cleanupJob -Timeout 120) {
                Remove-Job $cleanupJob
                Write-Log "Windows cleanup script completed"
            } else {
                Stop-Job $cleanupJob
                Remove-Job $cleanupJob
                Write-Log "Windows cleanup script timeout"
            }
        } else {
            Write-Log "Windows cleanup script not found"
        }
    } catch {
        Write-Log "Windows cleanup script failed: $_" "ERROR"
    }
    
    # OPERATION 8: ADVANCED SYSTEM CLEANER
    $operationCount++
    Write-ProgressLog "Advanced System Cleaner"
    try {
        if (Test-Path "F:\study\Platforms\windows\bat\AdvancedSystemCleaner.bat") {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c `"F:\study\Platforms\windows\bat\AdvancedSystemCleaner.bat`""
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $process = [System.Diagnostics.Process]::Start($psi)
            
            $responses = @("3", "n", "y")
            foreach ($response in $responses) {
                $process.StandardInput.WriteLine($response)
                Start-Sleep -Milliseconds 500
            }
            
            $process.StandardInput.Close()
            
            $timeout = 180
            $timer = 0
            while (!$process.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 5
                $timer += 5
            }
            
            if (!$process.HasExited) {
                $process.Kill()
            }
            
            Write-Log "Advanced System Cleaner completed"
        } else {
            Write-Log "Advanced System Cleaner not found"
        }
    } catch {
        Write-Log "Advanced System Cleaner failed: $_" "ERROR"
    }
    
    # OPERATION 9-11: BLEACHBIT (3 RUNS)
    for ($bleachRun = 1; $bleachRun -le 3; $bleachRun++) {
        $operationCount++
        Write-ProgressLog "BleachBit run $bleachRun"
        try {
            if (Test-Path "F:\backup\windowsapps\installed\BleachBit\bleachbit_console.exe") {
                $bleachProcess = Start-Process "F:\backup\windowsapps\installed\BleachBit\bleachbit_console.exe" -ArgumentList "--clean", "system.logs", "system.tmp", "system.recycle_bin", "system.thumbnails", "system.memory_dump", "system.prefetch", "system.clipboard", "system.muicache", "system.rotated_logs", "adobe_reader.tmp", "firefox.cache", "firefox.cookies", "firefox.session_restore", "firefox.forms", "firefox.passwords", "google_chrome.cache", "google_chrome.cookies", "google_chrome.history", "google_chrome.form_history", "microsoft_edge.cache", "microsoft_edge.cookies", "vlc.mru", "windows_explorer.mru", "windows_explorer.recent_documents", "windows_explorer.thumbnails", "deepscan.tmp", "deepscan.backup" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
                
                $timeout = 90
                $timer = 0
                while ($bleachProcess -and !$bleachProcess.HasExited -and $timer -lt $timeout) {
                    Start-Sleep -Seconds 5
                    $timer += 5
                }
                
                if ($bleachProcess -and !$bleachProcess.HasExited) {
                    $bleachProcess.Kill()
                }
                
                Write-Log "BleachBit run $bleachRun completed"
            } else {
                Write-Log "BleachBit not found"
            }
        } catch {
            Write-Log "BleachBit run $bleachRun failed: $_" "ERROR"
        }
    }
    
    # OPERATION 12: ADDITIONAL SYSTEM FILE CLEANUP
    $operationCount++
    Write-ProgressLog "Additional system file cleanup"
    try {
        # Clean Windows Update cache
        $wuCachePaths = @(
            "C:\Windows\SoftwareDistribution\Download\*",
            "C:\Windows\SoftwareDistribution\DataStore\*",
            "C:\Windows\System32\catroot2\*"
        )
        
        foreach ($path in $wuCachePaths) {
            if (Test-Path $path) {
                try {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Cleaned: $path"
                } catch { }
            }
        }
        
        # Clean memory dumps and error reports
        $dumpPaths = @(
            "C:\Windows\Minidump\*",
            "C:\Windows\memory.dmp",
            "C:\ProgramData\Microsoft\Windows\WER\*",
            "C:\Users\*\AppData\Local\CrashDumps\*"
        )
        
        foreach ($path in $dumpPaths) {
            try {
                if (Test-Path $path) {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Cleaned: $path"
                }
            } catch { }
        }
        
        # Clean thumbnail and icon caches
        $cachePaths = @(
            "C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db",
            "C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\iconcache_*.db",
            "C:\Users\*\AppData\Local\IconCache.db",
            "C:\Users\*\AppData\Local\GDIPFONTCACHEV1.DAT"
        )
        
        foreach ($cachePath in $cachePaths) {
            try {
                $files = Get-ChildItem -Path $cachePath -Force -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                }
            } catch { }
        }
        
        Write-Log "Additional system file cleanup completed"
    } catch {
        Write-Log "Additional system file cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 13: WSL ALERT 1
    $operationCount++
    Write-ProgressLog "WSL Alert 1"
    try {
        $distro = 'Ubuntu'
        $user = 'root'
        $core = @('-d', $distro, '-u', $user, '--')
        $escaped = 'alert' -replace '"', '\"'
        wsl @core bash -li -c "$escaped" 2>$null
        Write-Log "WSL Alert 1 completed"
    } catch {
        Write-Log "WSL Alert 1 failed: $_" "ERROR"
    }
    
    # OPERATION 14: DOCKER BACKUP
    $operationCount++
    Write-ProgressLog "Docker backup process"
    try {
        if (Test-Path "F:\backup\windowsapps") {
            Set-Location -Path "F:\backup\windowsapps"
            docker build -t michadockermisha/backup:windowsapps . 2>$null
            docker push michadockermisha/backup:windowsapps 2>$null
            Write-Log "Windows apps backup completed"
        }
        
        if (Test-Path "F:\study") {
            Set-Location -Path "F:\study"
            docker build -t michadockermisha/backup:study . 2>$null
            docker push michadockermisha/backup:study 2>$null
            Write-Log "Study folder backup completed"
        }
        
        if (Test-Path "F:\backup\linux\wsl") {
            Set-Location -Path "F:\backup\linux\wsl"
            docker build -t michadockermisha/backup:wsl . 2>$null
            docker push michadockermisha/backup:wsl 2>$null
            Write-Log "WSL backup completed"
        }
        
        # Clean up Docker containers and images
        $containers = docker ps -a -q 2>$null
        if ($containers) {
            docker stop $containers 2>$null | Out-Null
            docker rm $containers 2>$null | Out-Null
        }
        
        $danglingImages = docker images -q --filter "dangling=true" 2>$null
        if ($danglingImages) {
            docker rmi $danglingImages 2>$null | Out-Null
        }
        
        Write-Log "Docker backup process completed"
    } catch {
        Write-Log "Docker backup process failed: $_" "ERROR"
    }
    
    # OPERATION 15: WSL ALERT 2
    $operationCount++
    Write-ProgressLog "WSL Alert 2"
    try {
        $distro = 'Ubuntu'
        $user = 'root'
        $core = @('-d', $distro, '-u', $user, '--')
        $escaped = 'alert' -replace '"', '\"'
        wsl @core bash -li -c "$escaped" 2>$null
        Write-Log "WSL Alert 2 completed"
    } catch {
        Write-Log "WSL Alert 2 failed: $_" "ERROR"
    }
    
    # OPERATION 16: RESET WSL
    $operationCount++
    Write-ProgressLog "Reset WSL"
    try {
        wsl --shutdown 2>$null
        wsl --unregister ubuntu 2>$null
        
        if (Test-Path "F:\backup\linux\wsl\ubuntu.tar") {
            wsl --import ubuntu C:\wsl2\ubuntu\ F:\backup\linux\wsl\ubuntu.tar 2>$null
            Write-Log "WSL reset completed"
        } else {
            Write-Log "WSL backup file not found"
        }
    } catch {
        Write-Log "WSL reset failed: $_" "ERROR"
    }
    
    # OPERATION 17: FULL WSL2 SETUP
    $operationCount++
    Write-ProgressLog "Full WSL2 setup"
    try {
        $wslBasePath = "C:\wsl2"
        $ubuntuPath1 = "$wslBasePath\ubuntu"
        $ubuntuPath2 = "$wslBasePath\ubuntu2"
        $backupPath = "F:\backup\linux\wsl\ubuntu.tar"
        
        foreach ($distro in @("ubuntu", "ubuntu2")) {
            $existingDistros = wsl --list --quiet 2>$null
            if ($existingDistros -contains $distro) {
                wsl --terminate $distro 2>$null
                wsl --unregister $distro 2>$null
            }
        }
        
        foreach ($path in @($ubuntuPath1, $ubuntuPath2)) {
            if (Test-Path "$path\ext4.vhdx") {
                Remove-Item "$path\ext4.vhdx" -Force -ErrorAction SilentlyContinue
            }
            if (-not (Test-Path $path)) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
            }
        }
        
        $features = @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")
        foreach ($f in $features) {
            $status = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue
            if ($status -and $status.State -ne "Enabled") {
                Enable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction SilentlyContinue
            }
        }
        
        foreach ($svc in @("vmms", "vmcompute")) {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s -and $s.Status -ne "Running") {
                Start-Service -Name $svc -ErrorAction SilentlyContinue
            }
        }
        
        wsl --update 2>$null
        wsl --set-default-version 2 2>$null
        
        if (Test-Path $backupPath) {
            wsl --import ubuntu $ubuntuPath1 $backupPath 2>$null
            wsl --import ubuntu2 $ubuntuPath2 $backupPath 2>$null
        }
        
        $wslConfig = @"
[wsl2]
memory=4GB
processors=2
swap=2GB
localhostForwarding=true

[experimental]
autoMemoryReclaim=gradual
networkingMode=mirrored
dnsTunneling=true
firewall=true
autoProxy=true
"@
        Set-Content "$env:USERPROFILE\.wslconfig" $wslConfig -Force
        
        wsl --set-default ubuntu 2>$null
        Write-Log "WSL2 setup completed"
    } catch {
        Write-Log "WSL2 setup failed: $_" "ERROR"
    }
    
    # OPERATION 18: DOCKER CLEANUP
    $operationCount++
    Write-ProgressLog "Final Docker cleanup"
    try {
        $dockerCleanupJob = Start-Job {
            docker system prune -a --volumes -f 2>$null
            docker builder prune -a -f 2>$null
            docker buildx prune -a -f 2>$null
            Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
            wsl --shutdown 2>$null
            wsl --export docker-desktop "$env:TEMP\docker-desktop-backup.tar" 2>$null
            wsl --unregister docker-desktop 2>$null
            Remove-Item "C:\Users\misha\AppData\Local\Docker\wsl\disk\docker_data.vhdx" -Force -ErrorAction SilentlyContinue
            wsl --import docker-desktop "C:\Users\misha\AppData\Local\Docker\wsl\distro" "$env:TEMP\docker-desktop-backup.tar" 2>$null
            Remove-Item "$env:TEMP\docker-desktop-backup.tar" -Force -ErrorAction SilentlyContinue
            Optimize-VHD -Path "C:\Users\misha\AppData\Local\Docker\wsl\disk\docker_data.vhdx" -Mode Full -ErrorAction SilentlyContinue
            & "C:\Program Files\Docker\Docker\Docker Desktop.exe" 2>$null
        }
        
        if (Wait-Job $dockerCleanupJob -Timeout 180) {
            Remove-Job $dockerCleanupJob
            Write-Log "Docker cleanup completed"
        } else {
            Stop-Job $dockerCleanupJob
            Remove-Job $dockerCleanupJob
            Write-Log "Docker cleanup timeout"
            
            $processesToKill = @("docker", "wsl", "vssadmin")
            foreach ($proc in $processesToKill) {
                Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Log "Docker cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 19: COMPREHENSIVE NETWORK REPAIR
    $operationCount++
    Write-ProgressLog "Comprehensive network repair"
    try {
        Write-Log "Starting comprehensive network repair..."
        
        # Release and Renew DHCP
        Start-Process "ipconfig" -ArgumentList "/release" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        Start-Process "ipconfig" -ArgumentList "/renew" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        
        # Clear Hosts File
        $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
        if (Test-Path $hostsPath) {
            Copy-Item $hostsPath "$hostsPath.backup" -Force -ErrorAction SilentlyContinue
            $defaultHosts = @"
# localhost name resolution is handled within DNS itself.
#	127.0.0.1       localhost
#	::1             localhost
"@
            Set-Content -Path $hostsPath -Value $defaultHosts -Force
        }
        
        # Clear Static IP Settings
        $adapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        foreach ($adapter in $adapters) {
            try {
                $adapter.EnableDHCP() | Out-Null
                $adapter.SetDNSServerSearchOrder() | Out-Null
            } catch { }
        }
        
        # Set Google DNS
        netsh interface ip set dns name="Wi-Fi" source=static addr=8.8.8.8 2>$null
        netsh interface ip add dns name="Wi-Fi" addr=8.8.4.4 index=2 2>$null
        netsh interface ip set dns name="Ethernet" source=static addr=8.8.8.8 2>$null
        netsh interface ip add dns name="Ethernet" addr=8.8.4.4 index=2 2>$null
        
        # Flush DNS
        Start-Process "ipconfig" -ArgumentList "/flushdns" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        
        # Clear ARP/Route Table
        Start-Process "arp" -ArgumentList "-d", "*" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        Start-Process "route" -ArgumentList "-f" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        Start-Process "netsh" -ArgumentList "int", "ip", "delete", "arpcache" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        
        # NetBIOS Reload
        Start-Process "nbtstat" -ArgumentList "-R" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        Start-Process "nbtstat" -ArgumentList "-RR" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        
        # Enable adapters
        Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Ethernet*" -or $_.Name -like "*LAN*" } | Enable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
        Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Wireless*" -or $_.InterfaceDescription -like "*Wi-Fi*" -or $_.Name -like "*Wi-Fi*" } | Enable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
        
        # Set network services to default
        $networkServices = @{
            "Server" = "Automatic"; "Workstation" = "Automatic"; "Netlogon" = "Automatic"
            "LanmanServer" = "Automatic"; "LanmanWorkstation" = "Automatic"
            "Dhcp" = "Automatic"; "Dnscache" = "Automatic"; "NlaSvc" = "Automatic"
            "Wcmsvc" = "Automatic"; "Wlansvc" = "Automatic"
        }
        
        foreach ($service in $networkServices.GetEnumerator()) {
            try {
                $svc = Get-Service -Name $service.Key -ErrorAction SilentlyContinue
                if ($svc) {
                    Set-Service -Name $service.Key -StartupType $service.Value -ErrorAction SilentlyContinue
                    if ($service.Value -eq "Automatic" -and $svc.Status -ne "Running") {
                        Start-Service -Name $service.Key -ErrorAction SilentlyContinue
                    }
                }
            } catch { }
        }
        
        Write-Log "Network repair completed"
    } catch {
        Write-Log "Network repair failed: $_" "ERROR"
    }
    
    # OPERATION 20: NETWORK OPTIMIZATION
    $operationCount++
    Write-ProgressLog "Network optimization"
    try {
        Write-Log "Starting network optimization..."
        
        # TCP/IP optimizations
        netsh int tcp set global autotuninglevel=normal 2>$null
        netsh int tcp set global ecncapability=enabled 2>$null
        netsh int tcp set global timestamps=disabled 2>$null
        netsh int tcp set global initialRto=1000 2>$null
        netsh int tcp set global rsc=enabled 2>$null
        netsh int tcp set global nonsackrttresiliency=disabled 2>$null
        netsh int tcp set global maxsynretransmissions=2 2>$null
        netsh int tcp set global chimney=enabled 2>$null
        netsh int tcp set global windowsscaling=enabled 2>$null
        netsh int tcp set global dca=enabled 2>$null
        netsh int tcp set global netdma=enabled 2>$null
        netsh int tcp set supplemental Internet congestionprovider=ctcp 2>$null
        netsh int tcp set heuristics disabled 2>$null
        netsh int tcp set global rss=enabled 2>$null
        netsh int tcp set global fastopen=enabled 2>$null
        
        # IP settings
        netsh int ip set global taskoffload=enabled 2>$null
        netsh int ip set global neighborcachelimit=8192 2>$null
        netsh int ip set global routecachelimit=8192 2>$null
        netsh int ip set global dhcpmediasense=enabled 2>$null
        netsh int ip set global sourceroutingbehavior=dontforward 2>$null
        netsh int ipv4 set global randomizeidentifiers=disabled 2>$null
        netsh int ipv6 set global randomizeidentifiers=disabled 2>$null
        netsh int ipv6 set teredo disabled 2>$null
        netsh int ipv6 set 6to4 disabled 2>$null
        netsh int ipv6 set isatap disabled 2>$null
        
        # Registry optimizations
        $tcpipSettings = @{
            "NetworkThrottlingIndex" = 0xffffffff; "DefaultTTL" = 64; "TCPNoDelay" = 1
            "Tcp1323Opts" = 3; "TCPAckFrequency" = 1; "TCPDelAckTicks" = 0
            "MaxFreeTcbs" = 65536; "MaxHashTableSize" = 65536; "MaxUserPort" = 65534
            "TcpTimedWaitDelay" = 30; "TcpUseRFC1122UrgentPointer" = 0
            "TcpMaxDataRetransmissions" = 3; "KeepAliveTime" = 7200000
            "KeepAliveInterval" = 1000; "EnablePMTUDiscovery" = 1
        }
        
        $tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        foreach ($name in $tcpipSettings.Keys) {
            try {
                Set-ItemProperty -Path $tcpipPath -Name $name -Value $tcpipSettings[$name] -Type DWord -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        
        # DNS optimization
        netsh interface ip set dns name="Wi-Fi" source=static addr=1.1.1.1 2>$null
        netsh interface ip add dns name="Wi-Fi" addr=1.0.0.1 index=2 2>$null
        netsh interface ip add dns name="Wi-Fi" addr=8.8.8.8 index=3 2>$null
        netsh interface ip add dns name="Wi-Fi" addr=8.8.4.4 index=4 2>$null
        
        # Power optimization
        powercfg -setactive SCHEME_MIN 2>$null
        powercfg -change -monitor-timeout-ac 0 2>$null
        powercfg -change -disk-timeout-ac 0 2>$null
        powercfg -change -standby-timeout-ac 0 2>$null
        powercfg -change -hibernate-timeout-ac 0 2>$null
        
        # Final cleanup
        ipconfig /flushdns 2>$null
        ipconfig /registerdns 2>$null
        netsh int ip reset C:\resetlog.txt 2>$null
        netsh winsock reset 2>$null
        netsh winhttp reset proxy 2>$null
        
        Write-Log "Network optimization completed"
    } catch {
        Write-Log "Network optimization failed: $_" "ERROR"
    }
    
    # OPERATION 21: PC PERFORMANCE OPTIMIZATION
    $operationCount++
    Write-ProgressLog "PC performance optimization"
    try {
        Write-Log "Starting PC performance optimization..."
        
        # Registry performance optimizations
        $systemPerfSettings = @{
            "SystemResponsiveness" = 0; "NetworkThrottlingIndex" = 0xffffffff
            "Win32PrioritySeparation" = 38; "IRQ8Priority" = 1; "PCILatency" = 0
            "DisablePagingExecutive" = 1; "LargeSystemCache" = 1
            "IoPageLockLimit" = 0x4000000; "PoolUsageMaximum" = 96
            "PagedPoolSize" = 0xffffffff; "NonPagedPoolSize" = 0x0
            "SessionPoolSize" = 192; "SecondLevelDataCache" = 1024
            "ThirdLevelDataCache" = 8192
        }
        
        $perfPaths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl",
            "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        )
        
        foreach ($path in $perfPaths) {
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            foreach ($setting in $systemPerfSettings.GetEnumerator()) {
                try {
                    Set-ItemProperty -Path $path -Name $setting.Key -Value $setting.Value -Type DWord -Force -ErrorAction SilentlyContinue
                } catch { }
            }
        }
        
        # CPU optimizations
        $cpuSettings = @{
            "UsePlatformClock" = 1; "TSCFrequency" = 0; "DisableDynamicTick" = 1; "UseQPC" = 1
        }
        
        $cpuPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
        foreach ($setting in $cpuSettings.GetEnumerator()) {
            try {
                Set-ItemProperty -Path $cpuPath -Name $setting.Key -Value $setting.Value -Type DWord -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        
        # Visual performance
        $visualSettings = @{
            "VisualEffects" = 2; "DragFullWindows" = 0; "MenuShowDelay" = 0
            "MinAnimate" = 0; "TaskbarAnimations" = 0; "ListviewWatermark" = 0
            "UserPreferencesMask" = [byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)
        }
        
        $visualPaths = @(
            "HKCU:\Control Panel\Desktop",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects",
            "HKCU:\Control Panel\Desktop\WindowMetrics"
        )
        
        foreach ($path in $visualPaths) {
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            foreach ($setting in $visualSettings.GetEnumerator()) {
                try {
                    if ($setting.Key -eq "UserPreferencesMask") {
                        Set-ItemProperty -Path $path -Name $setting.Key -Value $setting.Value -Type Binary -Force -ErrorAction SilentlyContinue
                    } else {
                        Set-ItemProperty -Path $path -Name $setting.Key -Value $setting.Value -Type DWord -Force -ErrorAction SilentlyContinue
                    }
                } catch { }
            }
        }
        
        # Disable unnecessary services
        $servicesToDisable = @(
            "BITS", "wuauserv", "DoSvc", "MapsBroker", "RetailDemo", "DiagTrack",
            "dmwappushservice", "WSearch", "SysMain", "Themes", "TabletInputService",
            "Fax", "WbioSrvc", "WMPNetworkSvc", "WerSvc", "Spooler", "AxInstSV",
            "Browser", "CscService", "TrkWks", "SharedAccess", "lmhosts", "RemoteAccess",
            "SessionEnv", "TermService", "UmRdpService", "AppVClient", "NetTcpPortSharing",
            "wisvc", "WinDefend", "SecurityHealthService", "wscsvc"
        )
        
        foreach ($service in $servicesToDisable) {
            try {
                $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                if ($svc -and $svc.Status -eq "Running") {
                    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
                }
            } catch { }
        }
        
        # Gaming optimizations
        $gamingPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        $gamingSettings = @{
            "Affinity" = 0; "Background Only" = "False"; "BackgroundPriority" = 0
            "Clock Rate" = 10000; "GPU Priority" = 8; "Priority" = 6
            "Scheduling Category" = "High"; "SFIO Priority" = "High"
        }
        
        if (-not (Test-Path $gamingPath)) { New-Item -Path $gamingPath -Force | Out-Null }
        foreach ($setting in $gamingSettings.GetEnumerator()) {
            try {
                Set-ItemProperty -Path $gamingPath -Name $setting.Key -Value $setting.Value -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        
        # Disable Windows features
        $featuresToDisable = @(
            "TelnetClient", "TFTP", "TIFFIFilter", "Windows-Defender-Default-Definitions",
            "WorkFolders-Client", "Printing-XPSServices-Features", "FaxServicesClientPackage"
        )
        
        foreach ($feature in $featuresToDisable) {
            try {
                Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue
            } catch { }
        }
        
        Write-Log "PC performance optimization completed"
    } catch {
        Write-Log "PC performance optimization failed: $_" "ERROR"
    }
    
    # OPERATION 22: COMPREHENSIVE DISK CLEANUP
    $operationCount++
    Write-ProgressLog "Comprehensive disk cleanup"
    try {
        Write-Log "Starting comprehensive disk cleanup..."
        
        # C: drive cleanup paths
        $cDriveCleanupPaths = @(
            "C:\Windows\Temp\*", "C:\Windows\Prefetch\*", "C:\Windows\SoftwareDistribution\Download\*",
            "C:\Windows\Logs\*", "C:\Windows\Panther\*", "C:\Windows\System32\LogFiles\*",
            "C:\Windows\System32\config\systemprofile\AppData\Local\Temp\*",
            "C:\Windows\ServiceProfiles\LocalService\AppData\Local\Temp\*",
            "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp\*",
            "C:\Windows\Downloaded Program Files\*", "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*",
            "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*", "C:\ProgramData\Microsoft\Windows\WER\Temp\*",
            "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\*", "C:\ProgramData\Microsoft\Diagnosis\*",
            "C:\ProgramData\Microsoft\Windows Defender\Scans\History\*", "C:\ProgramData\Package Cache\*",
            "C:\Windows\Installer\*.msi", "C:\Windows\Installer\*.msp"
        )
        
        # User-specific cleanup
        $userCleanupPaths = @()
        $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
        foreach ($user in $users) {
            if ($user.Name -notmatch "^(All Users|Default|Public)$") {
                $userCleanupPaths += @(
                    "$($user.FullName)\AppData\Local\Temp\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\INetCache\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\WebCache\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\Explorer\iconcache_*.db",
                    "$($user.FullName)\AppData\Local\CrashDumps\*",
                    "$($user.FullName)\AppData\Local\Google\Chrome\User Data\Default\Cache\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Edge\User Data\Default\Cache\*"
                )
            }
        }
        
        # F: drive cleanup
        $fDriveCleanupPaths = @()
        if (Test-Path "F:\") {
            $fDriveCleanupPaths = @(
                "F:\temp\*", "F:\tmp\*", "F:\Temp\*", "F:\Windows.old\*",
                "F:\`$Recycle.Bin\*", "F:\System Volume Information\*",
                "F:\hiberfil.sys", "F:\pagefile.sys", "F:\swapfile.sys"
            )
        }
        
        $totalFilesDeleted = 0
        $allPaths = $cDriveCleanupPaths + $userCleanupPaths + $fDriveCleanupPaths
        
        foreach ($path in $allPaths) {
            if (Test-Path $path) {
                try {
                    $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
                    $pathFileCount = 0
                    
                    foreach ($item in $items) {
                        try {
                            if ($item.PSIsContainer) {
                                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                            } else {
                                Remove-Item -Path $item.FullName -Force -ErrorAction SilentlyContinue
                            }
                            $pathFileCount++
                        } catch { }
                    }
                    
                    $totalFilesDeleted += $pathFileCount
                } catch { }
            }
        }
        
        Write-Log "Disk cleanup completed - Files deleted: $totalFilesDeleted"
    } catch {
        Write-Log "Disk cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 23: WISE REGISTRY CLEANER
    $operationCount++
    Write-ProgressLog "Wise Registry Cleaner"
    try {
        if (Test-Path "F:\backup\windowsapps\installed\Wise\Wise Registry Cleaner\WiseRegCleaner.exe") {
            $wiseRegProcess = Start-Process 'F:\backup\windowsapps\installed\Wise\Wise Registry Cleaner\WiseRegCleaner.exe' -ArgumentList '-a','-all' -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            
            $timeout = 300
            $timer = 0
            while ($wiseRegProcess -and !$wiseRegProcess.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 5
                $timer += 5
            }
            
            if ($wiseRegProcess -and !$wiseRegProcess.HasExited) {
                $wiseRegProcess.Kill()
            }
            
            Write-Log "Wise Registry Cleaner completed"
        } else {
            Write-Log "Wise Registry Cleaner not found"
        }
    } catch {
        Write-Log "Wise Registry Cleaner failed: $_" "ERROR"
    }
    
    # OPERATION 24: WISE DISK CLEANER
    $operationCount++
    Write-ProgressLog "Wise Disk Cleaner"
    try {
        if (Test-Path "F:\backup\windowsapps\installed\Wise\Wise Disk Cleaner\WiseDiskCleaner.exe") {
            $wiseDiskProcess = Start-Process 'F:\backup\windowsapps\installed\Wise\Wise Disk Cleaner\WiseDiskCleaner.exe' -ArgumentList '-a','-adv' -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            
            $timeout = 120
            $timer = 0
            while ($wiseDiskProcess -and !$wiseDiskProcess.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 5
                $timer += 5
            }
            
            if ($wiseDiskProcess -and !$wiseDiskProcess.HasExited) {
                $wiseDiskProcess.Kill()
            }
            
            Write-Log "Wise Disk Cleaner completed"
        } else {
            Write-Log "Wise Disk Cleaner not found"
        }
    } catch {
        Write-Log "Wise Disk Cleaner failed: $_" "ERROR"
    }
    
    # OPERATION 25: FINAL CLEANUP
    $operationCount++
    Write-ProgressLog "Final cleanup"
    try {
        Write-Log "Starting final cleanup..."
        
        # Remove unnecessary folders
        $foldersToRemove = @(
            "C:\AdwCleaner", "C:\inetpub", "C:\PerfLogs", "C:\Logs", "C:\temp",
            "C:\tmp", "C:\Windows.old", "C:\Intel", "C:\AMD", "C:\NVIDIA",
            "C:\OneDriveTemp", "C:\Recovery\WindowsRE"
        )
        
        foreach ($folder in $foldersToRemove) {
            try {
                if (Test-Path $folder) {
                    takeown /f "$folder" /r /d y 2>$null | Out-Null
                    icacls "$folder" /grant administrators:F /t /q 2>$null | Out-Null
                    Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                    
                    if (!(Test-Path $folder)) {
                        Write-Log "Successfully removed folder: $folder"
                    }
                }
            } catch { }
        }
        
        # Final installer cleanup
        $additionalCleanup = @(
            "C:\Windows\Installer\*.msi", "C:\Windows\Downloaded Program Files\*",
            "C:\Windows\Temp\*", "C:\Windows\Logs\*", "C:\Windows\Panther\*",
            "C:\Windows\SoftwareDistribution\Download\*"
        )
        
        foreach ($pattern in $additionalCleanup) {
            try {
                $items = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
                if ($items) {
                    Remove-Item -Path $pattern -Recurse -Force -ErrorAction SilentlyContinue
                }
            } catch { }
        }
        
        # Force kill hanging processes
        $processesToKill = @("CCleaner*", "adwcleaner", "bleachbit*", "cleanmgr", "wsreset", "dism", "WiseRegCleaner", "WiseDiskCleaner")
        foreach ($processPattern in $processesToKill) {
            $processes = Get-Process -Name $processPattern -ErrorAction SilentlyContinue
            if ($processes) {
                $processes | Stop-Process -Force -ErrorAction SilentlyContinue
                
                Start-Sleep 2
                $remainingProcesses = Get-Process -Name $processPattern -ErrorAction SilentlyContinue
                if ($remainingProcesses) {
                    taskkill /f /im "$processPattern.exe" 2>$null
                }
            }
        }
        
        Write-Log "Final cleanup completed"
    } catch {
        Write-Log "Final cleanup failed: $_" "ERROR"
    }
    
    $totalTime = (Get-Date) - $global:ScriptStartTime
    Write-Log "=== System Optimization Completed in $($totalTime.TotalMinutes.ToString('F1')) minutes ==="
    Write-Log "Log saved to: $global:LogPath"
    Write-Log "Script completed successfully without requiring user interaction"
}

# START THE OPTIMIZATION PROCESS
try {
    Start-SystemOptimization
} catch {
    Write-Log "Script encountered an error: $_" "ERROR"
} finally {
    # Ensure cleanup always runs
    try {
        $remainingJobs = Get-Job -State Running -ErrorAction SilentlyContinue
        if ($remainingJobs) {
            $remainingJobs | Stop-Job -ErrorAction SilentlyContinue
            $remainingJobs | Remove-Job -ErrorAction SilentlyContinue
        }
    } catch { }
}

# Clean exit
Write-Log "=== SCRIPT COMPLETED SUCCESSFULLY ==="
$finalTime = (Get-Date) - $global:ScriptStartTime
Write-Log "Total script runtime: $($finalTime.TotalMinutes.ToString('F1')) minutes"
Write-Log "Script finished at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Clear any error variables and exit cleanly
$Error.Clear()
try {
    Get-EventSubscriber -ErrorAction SilentlyContinue | Unregister-Event -ErrorAction SilentlyContinue
} catch { }

exit 0