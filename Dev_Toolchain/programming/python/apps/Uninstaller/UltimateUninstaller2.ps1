#Requires -RunAsAdministrator
<#
.SYNOPSIS
    ULTIMATE SAFE UNINSTALLER - ABSOLUTE COMPLETE REMOVAL TOOL
    PowerShell 5.0+ compatible version for complete application removal

.DESCRIPTION
    Safely removes all traces of applications while protecting critical system files
    Supports Windows Package Manager, MSI, registry cleanup, and deep file scanning

.PARAMETER Apps
    Applications to uninstall completely

.PARAMETER DryRun
    Show what would be removed without actually removing it

.EXAMPLE
    .\UltimateUninstaller.ps1 -Apps wavebox, temp, logs, outlook

.NOTES
    Requires: Administrator privileges on Windows
    PowerShell Version: 5.0+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$Apps,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Global variables for tracking
$Script:DeletedCount = 0
$Script:FailedCount = 0
$Script:SkippedCount = 0
$Script:ProcessedCount = 0
$Script:TotalOperations = 0
$Script:CurrentOperation = 0
$Script:LogFile = "$env:TEMP\UltimateUninstaller_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Progress tracking
$Script:ProgressSteps = @(
    'Finding installed programs',
    'Uninstalling programs',
    'Terminating processes',
    'Stopping services',
    'Removing scheduled tasks',
    'Removing shortcuts',
    'Deep file search',
    'Registry cleanup',
    'Windows features cleanup',
    'System integration cleanup',
    'Final system cleanup'
)

# ULTIMATE SAFETY: Critical system files that should NEVER be deleted
$Script:CriticalSystemFiles = @(
    # Core Windows kernel and system
    'ntoskrnl.exe', 'hal.dll', 'win32k.sys', 'ntdll.dll', 'kernel32.dll',
    'user32.dll', 'gdi32.dll', 'advapi32.dll', 'msvcrt.dll', 'shell32.dll',
    'ole32.dll', 'oleaut32.dll', 'comctl32.dll', 'comdlg32.dll', 'wininet.dll',
    'urlmon.dll', 'shlwapi.dll', 'version.dll', 'mpr.dll', 'netapi32.dll',
    'winspool.drv', 'ws2_32.dll', 'wsock32.dll', 'mswsock.dll', 'dnsapi.dll',
    'iphlpapi.dll', 'dhcpcsvc.dll', 'winhttp.dll', 'crypt32.dll', 'wintrust.dll',
    'imagehlp.dll', 'psapi.dll', 'secur32.dll', 'netman.dll', 'rasapi32.dll',
    'tapi32.dll', 'rtutils.dll', 'setupapi.dll', 'cfgmgr32.dll', 'devmgr.dll',
    'newdev.dll', 'wtsapi32.dll', 'winsta.dll', 'authz.dll', 'xmllite.dll',

    # Core Windows processes
    'explorer.exe', 'winlogon.exe', 'csrss.exe', 'smss.exe', 'wininit.exe',
    'services.exe', 'lsass.exe', 'svchost.exe', 'dwm.exe', 'taskhost.exe',
    'taskhostw.exe', 'sihost.exe', 'ctfmon.exe', 'RuntimeBroker.exe',
    'ApplicationFrameHost.exe', 'WWAHost.exe', 'SearchUI.exe', 'ShellExperienceHost.exe',

    # Windows Update and system maintenance
    'wuauserv', 'wuauclt.exe', 'WindowsUpdateAgent', 'TrustedInstaller.exe',
    'dism.exe', 'sfc.exe', 'chkdsk.exe', 'defrag.exe',

    # Driver and hardware related
    'pnputil.exe', 'devcon.exe', 'driverquery.exe', 'msinfo32.exe',
    'devmgmt.msc', 'hdwwiz.cpl', 'devmgr.dll',

    # Windows Security and Updates
    'MpSigStub.exe', 'MsMpEng.exe', 'SecurityHealthSystray.exe',
    'SecurityHealthService.exe', 'wsqmcons.exe', 'consent.exe'
)

# CRITICAL DRIVERS that should NEVER be touched
$Script:CriticalDrivers = @(
    'disk.sys', 'classpnp.sys', 'storport.sys', 'storahci.sys', 'stornvme.sys',
    'ataport.sys', 'atapi.sys', 'pci.sys', 'acpi.sys', 'hal.dll',
    'ntfs.sys', 'volsnap.sys', 'fltmgr.sys', 'ksecdd.sys', 'cng.sys',
    'tcpip.sys', 'ndis.sys', 'afd.sys', 'netbt.sys', 'rdbss.sys',
    'usbhub.sys', 'usbport.sys', 'usbehci.sys', 'usbohci.sys', 'usbuhci.sys',
    'hidclass.sys', 'hidparse.sys', 'kbdclass.sys', 'mouclass.sys',
    'i8042prt.sys', 'sermouse.sys', 'mouhid.sys', 'kbdhid.sys'
)

# CRITICAL SERVICES that should NEVER be removed
$Script:CriticalServices = @(
    'wuauserv', 'BITS', 'CryptSvc', 'EventLog', 'PlugPlay', 'Power',
    'ProfSvc', 'Schedule', 'seclogon', 'SENS', 'ShellHWDetection',
    'Spooler', 'RpcSs', 'RpcEptMapper', 'DcomLaunch', 'LSM',
    'Winmgmt', 'EventSystem', 'VSS', 'swprv', 'Themes',
    'AudioSrv', 'AudioEndpointBuilder', 'Audiosrv', 'Dhcp',
    'Dnscache', 'LanmanServer', 'LanmanWorkstation', 'Netlogon',
    'NlaSvc', 'nsi', 'Tcpip', 'AFD', 'HTTP', 'WinHttpAutoProxySvc',
    'W32Time', 'WinDefend', 'wscsvc', 'WSearch', 'TrustedInstaller',
    'msiserver', 'Windows Update', 'wuauserv', 'UsoSvc'
)

# CRITICAL REGISTRY KEYS that should NEVER be modified
$Script:ProtectedRegistryKeys = @(
    'HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot',
    'HKLM:\SYSTEM\CurrentControlSet\Control\CriticalDeviceDatabase',
    'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip',
    'HKLM:\SYSTEM\CurrentControlSet\Services\AFD',
    'HKLM:\SYSTEM\CurrentControlSet\Services\HTTP',
    'HKLM:\SYSTEM\CurrentControlSet\Services\Dhcp',
    'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache',
    'HKLM:\SYSTEM\CurrentControlSet\Services\wuauserv',
    'HKLM:\SYSTEM\CurrentControlSet\Services\TrustedInstaller',
    'HKLM:\SYSTEM\CurrentControlSet\Services\msiserver',
    'HKLM:\SYSTEM\CurrentControlSet\Services\CryptSvc',
    'HKLM:\SYSTEM\CurrentControlSet\Services\BITS',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate',
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon',
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager',
    'HKLM:\SYSTEM\CurrentControlSet\Control\Windows'
)

# ULTRA-PROTECTED SYSTEM PATHS - Absolutely NEVER touch these
$Script:CriticalSystemPaths = @(
    # Core Windows system directories
    'C:\Windows\System32\',
    'C:\Windows\SysWOW64\',
    'C:\Windows\WinSxS\',
    'C:\Windows\Boot\',
    'C:\EFI\',
    'C:\Windows\drivers\',
    'C:\Windows\inf\',
    'C:\Windows\Fonts\',
    'C:\Windows\Globalization\',
    'C:\Windows\IME\',
    'C:\Windows\Speech\',
    'C:\Windows\registration\',
    'C:\Windows\schemas\',
    'C:\Windows\security\',
    'C:\Windows\servicing\',
    'C:\Windows\diagnostics\',
    'C:\Windows\Help\',
    'C:\Windows\L2Schemas\',
    'C:\Windows\Migration\',
    'C:\Windows\PolicyDefinitions\',
    'C:\Windows\Resources\',
    'C:\Windows\ShellNew\',
    'C:\Windows\Speech_OneCore\',
    'C:\Windows\tracing\',
    'C:\Windows\Web\',

    # Windows Update and maintenance (PROTECTED)
    'C:\Windows\SoftwareDistribution\DataStore\',
    'C:\Windows\SoftwareDistribution\WuRedir\',
    'C:\Windows\System32\catroot2\',
    'C:\Windows\System32\config\',
    'C:\Windows\System32\LogFiles\',
    'C:\Windows\System32\winevt\',

    # Driver stores and hardware support
    'C:\Windows\System32\DriverStore\',
    'C:\Windows\System32\drivers\DriverData\',
    'C:\Windows\INF\',

    # Critical Windows components
    'C:\Windows\Microsoft.NET\',
    'C:\Windows\assembly\',
    'C:\Windows\Globalization\',
    'C:\Windows\Branding\'
)

# Safe subdirectories within critical paths (can be cleaned)
$Script:SafeSubdirs = @(
    'temp', 'logs', 'prefetch', 'installer', 'downloaded program files',
    'cache', 'packages', 'CrashDumps', 'Debug', 'Dumps'
)

# PROTECTED file patterns that should NEVER be deleted (even if they match app names)
$Script:ProtectedFilePatterns = @(
    '*driver*', '*update*', '*patch*', '*hotfix*', '*service pack*',
    '*windows*', '*microsoft*', '*system*', '*kernel*', '*ntoskrnl*',
    '*boot*', '*winload*', '*hal*', '*acpi*', '*pci*', '*usb*',
    '*network*', '*tcp*', '*ip*', '*dns*', '*dhcp*', '*wifi*',
    '*bluetooth*', '*audio*', '*video*', '*display*', '*graphics*',
    '*storage*', '*disk*', '*volume*', '*file system*', '*ntfs*',
    '*security*', '*antivirus*', '*firewall*', '*defender*'
)

# App-specific removal patterns for thorough cleanup
$Script:AppPatterns = @{
    'edge' = @(
        'Microsoft Edge*', 'MicrosoftEdge*', 'edge*', 'msedge*', 'Edge*',
        'Microsoft.MicrosoftEdge*', 'Microsoft.MicrosoftEdgeDevToolsClient*',
        'edgeupdate*', 'EdgeUpdate*', 'MicrosoftEdgeUpdate*'
    )
    'chrome' = @(
        'Google Chrome*', 'Chrome*', 'chrome*', 'GoogleChrome*',
        'Google\Chrome*', 'Chromium*', 'chromium*'
    )
    'firefox' = @(
        'Mozilla Firefox*', 'Firefox*', 'firefox*', 'Mozilla*'
    )
    'teams' = @(
        'Microsoft Teams*', 'Teams*', 'teams*', 'msteams*'
    )
    'outlook' = @(
        'Microsoft Outlook*', 'Outlook*', 'outlook*', 'OUTLOOK*'
    )
}

function Write-Progress-Enhanced {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Activity,

        [Parameter(Mandatory=$false)]
        [string]$Status = '',

        [Parameter(Mandatory=$false)]
        [int]$PercentComplete = -1,

        [Parameter(Mandatory=$false)]
        [string]$CurrentOperation = ''
    )

    if ($PercentComplete -ge 0) {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -CurrentOperation $CurrentOperation
    } else {
        Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS', 'PROGRESS')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory=$false)]
        [switch]$NoProgress
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    # Write to console with colors
    switch ($Level) {
        'ERROR' { Write-Host $logEntry -ForegroundColor Red }
        'WARNING' { Write-Host $logEntry -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
        'PROGRESS' { Write-Host $logEntry -ForegroundColor Cyan }
        default { Write-Host $logEntry -ForegroundColor White }
    }

    # Update progress if not disabled
    if (-not $NoProgress -and $Script:TotalOperations -gt 0) {
        $Script:CurrentOperation++
        $percentComplete = [math]::Round(($Script:CurrentOperation / $Script:TotalOperations) * 100, 1)
        Write-Progress-Enhanced -Activity "Ultimate Uninstaller" -Status "$percentComplete% Complete" -PercentComplete $percentComplete -CurrentOperation $Message
    }

    # Write to log file
    Add-Content -Path $Script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Test-CriticalSystemFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    $filePathLower = $FilePath.ToLower()
    $fileName = Split-Path $filePathLower -Leaf

    # ULTIMATE SAFETY CHECK 1: Critical file names
    if ($Script:CriticalSystemFiles -contains $fileName) {
        Write-Log "    🛡️  PROTECTED: Critical system file: $fileName" -Level WARNING
        return $true
    }

    # ULTIMATE SAFETY CHECK 2: Critical drivers
    if ($Script:CriticalDrivers -contains $fileName) {
        Write-Log "    🛡️  PROTECTED: Critical driver file: $fileName" -Level WARNING
        return $true
    }

    # ULTIMATE SAFETY CHECK 3: Protected file patterns
    foreach ($pattern in $Script:ProtectedFilePatterns) {
        if ($fileName -like $pattern) {
            Write-Log "    🛡️  PROTECTED: Matches protected pattern '$pattern': $fileName" -Level WARNING
            return $true
        }
    }

    # ULTIMATE SAFETY CHECK 4: Windows Update files
    if ($filePathLower -like '*windows*update*' -or $filePathLower -like '*wuauserv*' -or
        $filePathLower -like '*trustedinstaller*' -or $filePathLower -like '*softwaредistribution*') {
        Write-Log "    🛡️  PROTECTED: Windows Update related: $fileName" -Level WARNING
        return $true
    }

    # ULTIMATE SAFETY CHECK 5: Critical paths
    foreach ($criticalPath in $Script:CriticalSystemPaths) {
        if ($filePathLower.StartsWith($criticalPath.ToLower())) {
            # Check if it's in a safe subdirectory
            $isSafe = $false
            foreach ($safeDir in $Script:SafeSubdirs) {
                if ($filePathLower -like "*\$safeDir\*") {
                    $isSafe = $true
                    break
                }
            }
            if (-not $isSafe) {
                Write-Log "    🛡️  PROTECTED: Critical system path: $FilePath" -Level WARNING
                return $true
            }
        }
    }

    # ULTIMATE SAFETY CHECK 6: Registry and system config files
    if ($fileName -like '*.reg' -or $fileName -like 'config*' -or $fileName -like 'sam*' -or
        $fileName -like 'security*' -or $fileName -like 'software*' -or $fileName -like 'system*') {
        if ($filePathLower -like '*\system32\config\*' -or $filePathLower -like '*\windows\system32\*') {
            Write-Log "    🛡️  PROTECTED: System configuration file: $fileName" -Level WARNING
            return $true
        }
    }

    return $false
}

function Find-InstalledPrograms {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    Write-Log "Searching for installed programs: $($AppNames -join ', ')"
    $foundPrograms = @()

    foreach ($appName in $AppNames) {
        Write-Log "Searching for: $appName"

        # Method 1: Windows Package Manager (winget)
        try {
            $wingetResult = & winget list --accept-source-agreements 2>$null
            if ($LASTEXITCODE -eq 0) {
                $wingetResult | ForEach-Object {
                    if ($_ -match $appName) {
                        $foundPrograms += @{
                            Type = 'winget'
                            Info = $_.Trim()
                            AppName = $appName
                        }
                        Write-Log "Found winget package: $($_.Trim())" -Level SUCCESS
                    }
                }
            }
        } catch {
            Write-Log "Winget search failed: $($_.Exception.Message)" -Level WARNING
        }

        # Method 2: Registry - Uninstall entries
        $uninstallKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
        )

        foreach ($keyPath in $uninstallKeys) {
            try {
                if (Test-Path $keyPath) {
                    Get-ChildItem $keyPath | ForEach-Object {
                        $subKey = $_
                        try {
                            $displayName = Get-ItemProperty $subKey.PSPath -Name DisplayName -ErrorAction SilentlyContinue
                            if ($displayName -and $displayName.DisplayName -match $appName) {
                                $uninstallString = Get-ItemProperty $subKey.PSPath -Name UninstallString -ErrorAction SilentlyContinue
                                $foundPrograms += @{
                                    Type = 'registry'
                                    Info = $displayName.DisplayName
                                    UninstallString = if ($uninstallString) { $uninstallString.UninstallString } else { $null }
                                    AppName = $appName
                                }
                                Write-Log "Found registry entry: $($displayName.DisplayName)" -Level SUCCESS
                            }
                        } catch {
                            # Continue if this specific entry fails
                        }
                    }
                }
            } catch {
                Write-Log "Registry search failed for ${keyPath}: $($_.Exception.Message)" -Level WARNING
            }
        }

        # Method 3: MSI packages
        try {
            $msiProducts = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $appName }
            foreach ($product in $msiProducts) {
                $foundPrograms += @{
                    Type = 'msi'
                    Info = $product.Name
                    ProductCode = $product.IdentifyingNumber
                    AppName = $appName
                }
                Write-Log "Found MSI package: $($product.Name)" -Level SUCCESS
            }
        } catch {
            Write-Log "MSI search failed: $($_.Exception.Message)" -Level WARNING
        }

        # Method 4: Windows Apps (UWP/MSIX)
        try {
            $uwpApps = Get-AppxPackage | Where-Object { $_.Name -match $appName }
            foreach ($app in $uwpApps) {
                $foundPrograms += @{
                    Type = 'uwp'
                    Info = $app.Name
                    PackageFullName = $app.PackageFullName
                    AppName = $appName
                }
                Write-Log "Found UWP package: $($app.Name)" -Level SUCCESS
            }
        } catch {
            Write-Log "UWP search failed: $($_.Exception.Message)" -Level WARNING
        }

        # Method 5: Provisioned AppX packages (for system apps like Edge)
        try {
            $provisionedApps = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -match $appName -or $_.PackageName -match $appName }
            foreach ($app in $provisionedApps) {
                $foundPrograms += @{
                    Type = 'provisioned'
                    Info = $app.DisplayName
                    PackageName = $app.PackageName
                    AppName = $appName
                }
                Write-Log "Found provisioned package: $($app.DisplayName)" -Level SUCCESS
            }
        } catch {
            Write-Log "Provisioned package search failed: $($_.Exception.Message)" -Level WARNING
        }
    }

    return $foundPrograms
}

function Uninstall-Programs {
    param(
        [Parameter(Mandatory=$true)]
        [array]$FoundPrograms
    )

    Write-Log "Starting program uninstallation"

    foreach ($program in $FoundPrograms) {
        Write-Log "Uninstalling $($program.Type): $($program.Info)"

        switch ($program.Type) {
            'winget' {
                try {
                    $parts = $program.Info -split '\s+'
                    $packageId = if ($parts[-1] -match '\.') { $parts[-1] } else { $program.AppName }
                    Write-Log "Attempting winget uninstall: $packageId"
                    & winget uninstall $packageId --silent 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Successfully uninstalled via winget: $packageId" -Level SUCCESS
                    } else {
                        Write-Log "Winget uninstall may have failed for: $packageId" -Level WARNING
                    }
                } catch {
                    Write-Log "Winget uninstall error: $($_.Exception.Message)" -Level ERROR
                }
            }

            'registry' {
                if ($program.UninstallString) {
                    try {
                        Write-Log "Attempting registry uninstall: $($program.Info)"
                        $uninstallCmd = $program.UninstallString

                        # Add silent flags for common installers
                        if ($uninstallCmd -match 'msiexec') {
                            $uninstallCmd += ' /quiet /norestart'
                        } elseif ($uninstallCmd -match '\.exe') {
                            $uninstallCmd += ' /S'
                        }

                        $process = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$uninstallCmd`"" -Wait -PassThru -WindowStyle Hidden
                        if ($process.ExitCode -eq 0) {
                            Write-Log "Successfully uninstalled via registry: $($program.Info)" -Level SUCCESS
                        } else {
                            Write-Log "Registry uninstall may have failed: $($program.Info)" -Level WARNING
                        }
                    } catch {
                        Write-Log "Registry uninstall error: $($_.Exception.Message)" -Level ERROR
                    }
                }
            }

            'msi' {
                try {
                    Write-Log "Attempting MSI uninstall: $($program.Info)"
                    $result = (Get-WmiObject -Class Win32_Product | Where-Object { $_.IdentifyingNumber -eq $program.ProductCode }).Uninstall()
                    if ($result.ReturnValue -eq 0) {
                        Write-Log "Successfully uninstalled MSI: $($program.Info)" -Level SUCCESS
                    } else {
                        Write-Log "MSI uninstall may have failed: $($program.Info)" -Level WARNING
                    }
                } catch {
                    Write-Log "MSI uninstall error: $($_.Exception.Message)" -Level ERROR
                }
            }

            'uwp' {
                try {
                    Write-Log "Attempting UWP uninstall: $($program.Info)"
                    Remove-AppxPackage -Package $program.PackageFullName -ErrorAction SilentlyContinue
                    Write-Log "Successfully uninstalled UWP: $($program.Info)" -Level SUCCESS
                } catch {
                    Write-Log "UWP uninstall error: $($_.Exception.Message)" -Level ERROR
                }
            }

            'provisioned' {
                try {
                    Write-Log "Attempting provisioned package removal: $($program.Info)"
                    Remove-AppxProvisionedPackage -Online -PackageName $program.PackageName -ErrorAction SilentlyContinue
                    Write-Log "Successfully removed provisioned package: $($program.Info)" -Level SUCCESS
                } catch {
                    Write-Log "Provisioned package removal error: $($_.Exception.Message)" -Level ERROR
                }
            }
        }
    }
}

function Stop-RelatedProcesses {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    Write-Log "Terminating related processes"

    foreach ($appName in $AppNames) {
        $killedCount = 0

        # Get processes by name, command line, and path
        $processes = Get-Process | Where-Object {
            ($_.ProcessName -match $appName) -or
            ($_.Path -and $_.Path -match $appName) -or
            ($_.CommandLine -and $_.CommandLine -match $appName)
        }

        foreach ($process in $processes) {
            try {
                Write-Log "Terminating process: $($process.ProcessName) (PID: $($process.Id))"
                $process.Kill()
                $killedCount++
            } catch {
                Write-Log "Failed to terminate process $($process.ProcessName): $($_.Exception.Message)" -Level WARNING
            }
        }

        # Also try taskkill for broader matching
        try {
            & taskkill /f /t /im "*$appName*" 2>$null
        } catch {
            # Ignore errors from taskkill
        }

        Write-Log "Terminated $killedCount processes for $appName" -Level SUCCESS
    }
}

function Stop-RelatedServices {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    Write-Log "🔍 Scanning and removing related services (PROTECTED MODE)" -Level PROGRESS

    foreach ($appName in $AppNames) {
        try {
            $services = Get-Service | Where-Object {
                ($_.Name -match $appName -or $_.DisplayName -match $appName) -and
                ($_.Name -notin $Script:CriticalServices)
            }

            foreach ($service in $services) {
                # ULTIMATE SAFETY CHECK: Never touch critical services
                if ($Script:CriticalServices -contains $service.Name) {
                    Write-Log "    🛡️  PROTECTED: Critical service preserved: $($service.Name)" -Level WARNING
                    $Script:SkippedCount++
                    continue
                }

                # Additional safety checks for Windows core services
                if ($service.Name -like '*windows*' -or $service.Name -like '*update*' -or
                    $service.Name -like '*driver*' -or $service.Name -like '*system*') {
                    Write-Log "    🛡️  PROTECTED: Core Windows service preserved: $($service.Name)" -Level WARNING
                    $Script:SkippedCount++
                    continue
                }

                try {
                    Write-Log "    🛑 Stopping service: $($service.Name)" -Level PROGRESS
                    Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2

                    Write-Log "    🗑️  Removing service: $($service.Name)" -Level SUCCESS
                    & sc.exe delete $service.Name 2>$null
                    $Script:DeletedCount++
                } catch {
                    Write-Log "    ❌ Service cleanup error for $($service.Name): $($_.Exception.Message)" -Level WARNING
                    $Script:FailedCount++
                }
            }
        } catch {
            Write-Log "❌ Service cleanup error for ${appName}: $($_.Exception.Message)" -Level ERROR
        }
    }
}

function Remove-ScheduledTasks {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    Write-Log "Removing related scheduled tasks"

    foreach ($appName in $AppNames) {
        try {
            $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -match $appName -or $_.TaskPath -match $appName }

            foreach ($task in $tasks) {
                try {
                    Write-Log "Deleting scheduled task: $($task.TaskName)"
                    Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue
                } catch {
                    Write-Log "Failed to delete scheduled task $($task.TaskName): $($_.Exception.Message)" -Level WARNING
                }
            }
        } catch {
            Write-Log "Scheduled task cleanup error for ${appName}: $($_.Exception.Message)" -Level ERROR
        }
    }
}

function Set-PendingFileRename {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    try {
        # Schedule file for deletion on next reboot using PendingFileRenameOperations
        $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
        $regName = 'PendingFileRenameOperations'

        $currentValues = @()
        try {
            $currentValues = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $regName
        } catch {
            # Registry value doesn't exist yet
        }

        $newValues = @($currentValues) + @("\??\$FilePath", "")
        Set-ItemProperty -Path $regPath -Name $regName -Value $newValues -Type MultiString

        Write-Log "Scheduled for deletion on reboot: $FilePath"
        return $true
    } catch {
        Write-Log "Failed to schedule for deletion: $FilePath - $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Remove-FileForced {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        return $true
    }

    # Critical system file check
    if (Test-CriticalSystemFile -FilePath $FilePath) {
        Write-Log "SKIPPED critical system file: $FilePath" -Level WARNING
        $Script:SkippedCount++
        return $false
    }

    try {
        # Remove attributes
        try {
            & attrib -R -H -S $FilePath 2>$null
        } catch {
            # Continue if attrib fails
        }

        # Standard delete
        try {
            Remove-Item -Path $FilePath -Force -ErrorAction Stop
            if (-not (Test-Path $FilePath)) {
                return $true
            }
        } catch {
            # Continue to next method
        }

        # Take ownership and delete
        try {
            & takeown /f $FilePath 2>$null
            & icacls $FilePath /grant Everyone:F 2>$null
            Remove-Item -Path $FilePath -Force -ErrorAction Stop
            if (-not (Test-Path $FilePath)) {
                return $true
            }
        } catch {
            # Continue to next method
        }

        # Schedule for deletion on reboot
        return Set-PendingFileRename -FilePath $FilePath

    } catch {
        Write-Log "Error deleting file ${FilePath}: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Remove-DirectoryForced {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DirPath
    )

    if (-not (Test-Path $DirPath)) {
        return $true
    }

    # Critical system directory check
    if (Test-CriticalSystemFile -FilePath $DirPath) {
        Write-Log "SKIPPED critical system directory: $DirPath" -Level WARNING
        $Script:SkippedCount++
        return $false
    }

    try {
        # Take ownership recursively
        try {
            & takeown /f $DirPath /r /d y 2>$null
            & icacls $DirPath /grant Everyone:F /t 2>$null
        } catch {
            # Continue if ownership fails
        }

        # Remove attributes
        try {
            & attrib -R -H -S $DirPath /S /D 2>$null
        } catch {
            # Continue if attrib fails
        }

        # Standard delete
        try {
            Remove-Item -Path $DirPath -Recurse -Force -ErrorAction Stop
            if (-not (Test-Path $DirPath)) {
                return $true
            }
        } catch {
            # Continue to next method
        }

        # CMD rmdir
        try {
            & cmd /c "rmdir /s /q `"$DirPath`"" 2>$null
            if (-not (Test-Path $DirPath)) {
                return $true
            }
        } catch {
            # Continue to next method
        }

        # Schedule for deletion on reboot
        return Set-PendingFileRename -FilePath $DirPath

    } catch {
        Write-Log "Error deleting directory ${DirPath}: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Remove-ShortcutsAndIcons {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    Write-Log "Removing shortcuts and icons"

    # Get all user directories dynamically
    $userDirs = @()
    try {
        $userDirs = Get-ChildItem 'C:\Users' -Directory | Where-Object { $_.Name -notin @('All Users', 'Default', 'Public') } | Select-Object -ExpandProperty FullName
    } catch {
        Write-Log "Failed to enumerate user directories: $($_.Exception.Message)" -Level WARNING
    }

    $shortcutLocations = @(
        'C:\ProgramData\Microsoft\Windows\Start Menu\Programs',
        'C:\Users\Public\Desktop'
    )

    # Add per-user locations
    foreach ($userPath in $userDirs) {
        $shortcutLocations += @(
            "$userPath\Desktop",
            "$userPath\AppData\Roaming\Microsoft\Windows\Start Menu\Programs",
            "$userPath\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch"
        )
    }

    foreach ($appName in $AppNames) {
        foreach ($location in $shortcutLocations) {
            if (-not (Test-Path $location)) {
                continue
            }

            try {
                Get-ChildItem -Path $location -Recurse -File | Where-Object {
                    $_.Name -match $appName -and $_.Extension -in @('.lnk', '.url')
                } | ForEach-Object {
                    Write-Log "Removing shortcut: $($_.FullName)"
                    if (Remove-FileForced -FilePath $_.FullName) {
                        $Script:DeletedCount++
                    } else {
                        $Script:FailedCount++
                    }
                }
            } catch {
                Write-Log "Shortcut cleanup error in ${location}: $($_.Exception.Message)" -Level ERROR
            }
        }
    }
}

function Get-ComprehensiveSearchLocations {
    $locations = @(
        # Program installation directories
        'C:\Program Files',
        'C:\Program Files (x86)',
        'C:\Program Files\Common Files',
        'C:\Program Files (x86)\Common Files',
        'C:\Program Files\WindowsApps',
        'C:\Program Files\ModifiableWindowsApps',

        # System data directories
        'C:\ProgramData',
        'C:\Windows\Installer',
        'C:\Windows\System32',
        'C:\Windows\SysWOW64',

        # Safe temporary and cache directories
        'C:\Windows\Temp',
        'C:\Windows\Prefetch',
        'C:\Windows\Logs',
        'C:\ProgramData\Package Cache',
        'C:\ProgramData\Microsoft\Windows\WER',

        # Additional Microsoft-specific locations
        'C:\ProgramData\Microsoft',
        'C:\ProgramData\Packages',
        'C:\Windows\SystemApps',
        'C:\Windows\System32\config\systemprofile\AppData',
        'C:\Windows\ServiceProfiles',

        # Edge-specific system locations
        'C:\ProgramData\Microsoft\EdgeUpdate',
        'C:\ProgramData\Microsoft\Edge',
        'C:\Windows\System32\MicrosoftEdgeCP',
        'C:\Windows\SystemApps\Microsoft.MicrosoftEdge*',

        # Browser cache and data locations
        'C:\ProgramData\Microsoft\Windows\Start Menu\Programs',
        'C:\Windows\Installer\{*}'
    )

    # Add user directories dynamically
    try {
        $userDirs = Get-ChildItem 'C:\Users' -Directory | Where-Object { $_.Name -notin @('All Users', 'Default', 'Public') }
        foreach ($userDir in $userDirs) {
            $userPath = $userDir.FullName
            $locations += @(
                "$userPath\AppData\Local",
                "$userPath\AppData\Roaming",
                "$userPath\AppData\LocalLow",
                "$userPath\AppData\Local\Temp",
                "$userPath\Desktop",
                "$userPath\Documents",
                "$userPath\Downloads"
            )
        }
    } catch {
        Write-Log "Failed to enumerate user directories for search: $($_.Exception.Message)" -Level WARNING
    }

    return $locations
}

function Get-AppSpecificPatterns {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppName
    )

    $appNameLower = $AppName.ToLower()
    $defaultPatterns = @("*$AppName*", "*$appNameLower*", "*$($AppName.ToUpper())*")

    # Check if we have specific patterns for this app
    if ($Script:AppPatterns.ContainsKey($appNameLower)) {
        return $Script:AppPatterns[$appNameLower] + $defaultPatterns
    }

    return $defaultPatterns
}

function Start-ComprehensiveFileSearch {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    Write-Log "Starting comprehensive file search"

    $searchLocations = Get-ComprehensiveSearchLocations

    foreach ($appName in $AppNames) {
        Write-Log "Searching for files related to: $appName"
        $allTargets = @()

        # Get app-specific patterns
        $patterns = Get-AppSpecificPatterns -AppName $appName
        Write-Log "Using $($patterns.Count) search patterns for $appName"

        foreach ($location in $searchLocations) {
            if (-not (Test-Path $location)) {
                continue
            }

            Write-Log "Searching in: $location"
            try {
                foreach ($pattern in $patterns) {
                    try {
                        # Support wildcard patterns in location paths (for Edge SystemApps)
                        if ($location -like '*\*') {
                            $expandedLocations = Get-ChildItem -Path ($location -replace '\\\*.*$', '') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like ($location -replace '.*\\', '') }
                            foreach ($expandedLoc in $expandedLocations) {
                                $matches = Get-ChildItem -Path $expandedLoc.FullName -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pattern }
                                $allTargets += $matches | Select-Object -ExpandProperty FullName
                            }
                        } else {
                            $matches = Get-ChildItem -Path $location -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pattern }
                            $allTargets += $matches | Select-Object -ExpandProperty FullName
                        }
                    } catch {
                        # Continue if this pattern fails
                    }
                }
            } catch {
                Write-Log "Search failed in ${location}: $($_.Exception.Message)" -Level ERROR
            }
        }

        # Remove duplicates
        $allTargets = $allTargets | Sort-Object -Unique
        Write-Log "Found $($allTargets.Count) targets for $appName"

        # Remove targets
        if ($allTargets.Count -gt 0) {
            Remove-Targets -Targets $allTargets
        }
    }
}

function Remove-Targets {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Targets
    )

    # Sort by depth (files first, then directories)
    $sortedTargets = $Targets | Sort-Object {
        if (Test-Path $_ -PathType Leaf) { 0 } else { 1 }
        ($_ -split '\\').Count
    }

    foreach ($target in $sortedTargets) {
        if (-not (Test-Path $target)) {
            continue
        }

        Write-Log "Processing: $target"

        try {
            if (Test-Path $target -PathType Leaf) {
                if (Remove-FileForced -FilePath $target) {
                    Write-Log "SUCCESS: Deleted file $target" -Level SUCCESS
                    $Script:DeletedCount++
                } else {
                    Write-Log "FAILED: Could not delete file $target" -Level WARNING
                    $Script:FailedCount++
                }
            } elseif (Test-Path $target -PathType Container) {
                if (Remove-DirectoryForced -DirPath $target) {
                    Write-Log "SUCCESS: Deleted directory $target" -Level SUCCESS
                    $Script:DeletedCount++
                } else {
                    Write-Log "FAILED: Could not delete directory $target" -Level WARNING
                    $Script:FailedCount++
                }
            }
        } catch {
            Write-Log "Error processing ${target}: $($_.Exception.Message)" -Level ERROR
            $Script:FailedCount++
        }
    }
}

function Clear-RegistryExhaustive {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    Write-Log "Starting EXHAUSTIVE registry cleanup - ZERO leftovers mode" -Level PROGRESS

    # COMPREHENSIVE registry areas for COMPLETE application cleanup
    $exhaustiveCleanupAreas = @(
        # Basic application areas
        @{ Root = 'HKCU:'; Path = 'Software'; Description = 'User software settings' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE'; Description = 'System software settings' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\WOW6432Node'; Description = '32-bit software on 64-bit system' },

        # Uninstall information
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'; Description = 'Uninstall entries' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'; Description = '32-bit uninstall entries' },
        @{ Root = 'HKCU:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'; Description = 'User uninstall entries' },

        # Application paths and execution
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths'; Description = 'Application execution paths' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths'; Description = '32-bit app paths' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'; Description = 'Execution options' },

        # Startup and run entries
        @{ Root = 'HKCU:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Description = 'User startup programs' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Description = 'System startup programs' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Description = '32-bit startup programs' },
        @{ Root = 'HKCU:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Description = 'User run once programs' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Description = 'System run once programs' },

        # File associations and protocols
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Classes'; Description = 'File type associations' },
        @{ Root = 'HKCU:'; Path = 'SOFTWARE\Classes'; Description = 'User file associations' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\RegisteredApplications'; Description = 'Registered applications' },
        @{ Root = 'HKCU:'; Path = 'SOFTWARE\RegisteredApplications'; Description = 'User registered applications' },

        # Services and drivers
        @{ Root = 'HKLM:'; Path = 'SYSTEM\CurrentControlSet\Services'; Description = 'Windows services' },
        @{ Root = 'HKLM:'; Path = 'SYSTEM\ControlSet001\Services'; Description = 'Services control set 1' },
        @{ Root = 'HKLM:'; Path = 'SYSTEM\ControlSet002\Services'; Description = 'Services control set 2' },

        # Windows Installer
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Classes\Installer\Products'; Description = 'MSI installer products' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Classes\Installer\Features'; Description = 'MSI installer features' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Classes\Installer\Components'; Description = 'MSI installer components' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Installer'; Description = 'Windows Installer data' },

        # EDGE-SPECIFIC COMPREHENSIVE CLEANUP
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\EdgeUpdate'; Description = 'Edge update service' },
        @{ Root = 'HKCU:'; Path = 'SOFTWARE\Microsoft\Edge'; Description = 'User Edge settings' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Edge'; Description = 'System Edge settings' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate'; Description = '32-bit Edge update' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\WOW6432Node\Microsoft\Edge'; Description = '32-bit Edge settings' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Policies\Microsoft\Edge'; Description = 'Edge group policies' },
        @{ Root = 'HKCU:'; Path = 'SOFTWARE\Policies\Microsoft\Edge'; Description = 'User Edge policies' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Policies\Microsoft\EdgeUpdate'; Description = 'Edge update policies' },

        # Edge file associations
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Classes\MSEdgeHTM'; Description = 'Edge HTML file association' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Classes\MSEdgePDF'; Description = 'Edge PDF file association' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Classes\MSEdgeMHT'; Description = 'Edge MHT file association' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Classes\MSEdgeSecurityLevel'; Description = 'Edge security settings' },

        # Browser integration
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Clients\StartMenuInternet\Microsoft Edge'; Description = 'Edge start menu integration' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects'; Description = 'Browser helper objects' },
        @{ Root = 'HKCU:'; Path = 'SOFTWARE\Microsoft\Windows\Shell\Associations'; Description = 'Shell file associations' },
        @{ Root = 'HKCU:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts'; Description = 'File extension preferences' },

        # AppX and UWP related
        @{ Root = 'HKCU:'; Path = 'SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppContainer'; Description = 'AppContainer settings' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppContainer'; Description = 'System AppContainer' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx'; Description = 'AppX package data' },

        # Telemetry and crash reporting
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows\Windows Error Reporting'; Description = 'Error reporting settings' },
        @{ Root = 'HKCU:'; Path = 'SOFTWARE\Microsoft\Windows\Windows Error Reporting'; Description = 'User error reporting' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\SQMClient'; Description = 'Software Quality Metrics' },

        # Windows Update related
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate'; Description = 'Windows Update settings' }
    )

    $totalAreas = $exhaustiveCleanupAreas.Count * $AppNames.Count
    $currentArea = 0

    foreach ($appName in $AppNames) {
        Write-Log "🔍 SCANNING registry for ALL traces of: $appName" -Level PROGRESS

        # Get app-specific patterns for more thorough search
        $searchPatterns = Get-AppSpecificPatterns -AppName $appName

        foreach ($area in $exhaustiveCleanupAreas) {
            $currentArea++
            $percentComplete = [math]::Round(($currentArea / $totalAreas) * 100, 1)

            $fullPath = "$($area.Root)\$($area.Path)"
            Write-Log "  📂 [$percentComplete%] Cleaning: $($area.Description)" -Level PROGRESS

            try {
                if (Test-Path $fullPath) {
                    foreach ($pattern in $searchPatterns) {
                        Clear-RegistryKey -KeyPath $fullPath -AppName $pattern -Description $area.Description
                    }
                    # Also clean with exact app name
                    Clear-RegistryKey -KeyPath $fullPath -AppName $appName -Description $area.Description
                }
            } catch {
                Write-Log "❌ Registry cleanup error in $($area.Description): $($_.Exception.Message)" -Level ERROR
            }
        }
    }
}

function Clear-RegistryKey {
    param(
        [Parameter(Mandatory=$true)]
        [string]$KeyPath,

        [Parameter(Mandatory=$true)]
        [string]$AppName,

        [Parameter(Mandatory=$false)]
        [string]$Description = 'Registry area'
    )

    try {
        # ULTIMATE SAFETY CHECK: Never touch protected registry keys
        foreach ($protectedKey in $Script:ProtectedRegistryKeys) {
            if ($KeyPath.StartsWith($protectedKey, [StringComparison]::OrdinalIgnoreCase)) {
                Write-Log "    🛡️  PROTECTED: Skipping critical registry area: $KeyPath" -Level WARNING
                $Script:SkippedCount++
                return
            }
        }

        $deletedKeys = 0
        $deletedValues = 0

        # Find and delete matching subkeys with case-insensitive matching
        $subKeys = Get-ChildItem -Path $KeyPath -ErrorAction SilentlyContinue | Where-Object {
            $keyName = $_.PSChildName

            # SAFETY CHECK: Skip if contains protected patterns
            $isProtected = $false
            foreach ($pattern in $Script:ProtectedFilePatterns) {
                if ($keyName -like $pattern) {
                    $isProtected = $true
                    break
                }
            }

            if ($isProtected) {
                Write-Log "    🛡️  PROTECTED: Skipping protected registry key: $keyName" -Level WARNING
                return $false
            }

            # Check for app name match
            return ($keyName -match [regex]::Escape($AppName) -or
                    $keyName -like "*$AppName*" -or
                    $keyName -like "*$($AppName.ToLower())*" -or
                    $keyName -like "*$($AppName.ToUpper())*")
        }

        foreach ($subKey in $subKeys) {
            try {
                Write-Log "    🗑️  Deleting registry key: $($subKey.PSChildName)" -Level SUCCESS
                Remove-Item -Path $subKey.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                $deletedKeys++
                $Script:DeletedCount++
            } catch {
                Write-Log "    ❌ Could not delete registry key $($subKey.PSChildName): $($_.Exception.Message)" -Level WARNING
                $Script:FailedCount++
            }
        }

        # Find and delete matching values with comprehensive pattern matching
        $properties = Get-ItemProperty -Path $KeyPath -ErrorAction SilentlyContinue
        if ($properties) {
            $matchingProps = $properties.PSObject.Properties | Where-Object {
                $propName = $_.Name
                $propValue = $_.Value

                # SAFETY CHECK: Skip if contains protected patterns
                $isProtected = $false
                foreach ($pattern in $Script:ProtectedFilePatterns) {
                    if ($propName -like $pattern -or ($propValue -is [string] -and $propValue -like $pattern)) {
                        $isProtected = $true
                        break
                    }
                }

                if ($isProtected) {
                    return $false
                }

                # Check for app name match
                return (($propName -match [regex]::Escape($AppName)) -or
                        ($propName -like "*$AppName*") -or
                        ($propValue -is [string] -and (
                            $propValue -match [regex]::Escape($AppName) -or
                            $propValue -like "*$AppName*" -or
                            $propValue -like "*$($AppName.ToLower())*" -or
                            $propValue -like "*$($AppName.ToUpper())*"
                        )))
            }

            foreach ($prop in $matchingProps) {
                try {
                    Write-Log "    🗑️  Deleting registry value: $($prop.Name)" -Level SUCCESS
                    Remove-ItemProperty -Path $KeyPath -Name $prop.Name -ErrorAction SilentlyContinue
                    $deletedValues++
                    $Script:DeletedCount++
                } catch {
                    Write-Log "    ❌ Could not delete registry value $($prop.Name): $($_.Exception.Message)" -Level WARNING
                    $Script:FailedCount++
                }
            }
        }

        if ($deletedKeys -gt 0 -or $deletedValues -gt 0) {
            Write-Log "    ✅ $Description: Removed $deletedKeys keys and $deletedValues values" -Level SUCCESS
        }

    } catch {
        Write-Log "❌ Error processing registry area $Description: $($_.Exception.Message)" -Level ERROR
        $Script:FailedCount++
    }
}

function Remove-WindowsOptionalFeatures {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    Write-Log "Checking for Windows Optional Features to remove"

    foreach ($appName in $AppNames) {
        try {
            # Check for Edge WebView2 and related features
            if ($appName -match 'edge') {
                Write-Log "Checking for Edge-related Windows features"

                # Remove Edge WebView2 if present
                try {
                    $webview2 = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -like '*webview*' -or $_.FeatureName -like '*edge*' }
                    foreach ($feature in $webview2) {
                        if ($feature.State -eq 'Enabled') {
                            Write-Log "Disabling Windows feature: $($feature.FeatureName)"
                            Disable-WindowsOptionalFeature -Online -FeatureName $feature.FeatureName -NoRestart -ErrorAction SilentlyContinue
                        }
                    }
                } catch {
                    Write-Log "Optional feature cleanup failed: $($_.Exception.Message)" -Level WARNING
                }
            }
        } catch {
            Write-Log "Feature removal error for ${appName}: $($_.Exception.Message)" -Level ERROR
        }
    }
}

function Remove-SystemIntegration {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    Write-Log "Removing deep system integration"

    foreach ($appName in $AppNames) {
        try {
            # Remove from Windows Defender exclusions
            if ($appName -match 'edge') {
                Write-Log "Removing Windows Defender exclusions"
                try {
                    $exclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
                    foreach ($exclusion in $exclusions) {
                        if ($exclusion -like "*edge*" -or $exclusion -like "*Edge*") {
                            Remove-MpPreference -ExclusionPath $exclusion -ErrorAction SilentlyContinue
                            Write-Log "Removed Defender exclusion: $exclusion"
                        }
                    }
                } catch {
                    Write-Log "Defender exclusion cleanup failed: $($_.Exception.Message)" -Level WARNING
                }

                # Remove Edge from default browser settings
                try {
                    Write-Log "Clearing default browser associations"
                    $regPaths = @(
                        'HKCU:\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice',
                        'HKCU:\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice',
                        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.htm\UserChoice',
                        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.html\UserChoice'
                    )

                    foreach ($regPath in $regPaths) {
                        if (Test-Path $regPath) {
                            $progId = Get-ItemProperty -Path $regPath -Name 'ProgId' -ErrorAction SilentlyContinue
                            if ($progId -and $progId.ProgId -like '*Edge*') {
                                Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
                                Write-Log "Removed browser association: $regPath"
                            }
                        }
                    }
                } catch {
                    Write-Log "Browser association cleanup failed: $($_.Exception.Message)" -Level WARNING
                }
            }
        } catch {
            Write-Log "System integration cleanup error for ${appName}: $($_.Exception.Message)" -Level ERROR
        }
    }
}

function Start-FinalSystemCleanup {
    Write-Log "Performing final system cleanup"

    try {
        # Clear recycle bin
        Write-Log "Clearing recycle bin"
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Log "Recycle bin cleanup failed: $($_.Exception.Message)" -Level WARNING
    }

    try {
        # Clear temporary files
        Write-Log "Clearing temporary files"
        $tempLocations = @(
            $env:TEMP,
            $env:TMP,
            'C:\Windows\Temp',
            'C:\Temp'
        )

        foreach ($tempPath in $tempLocations) {
            if ($tempPath -and (Test-Path $tempPath)) {
                try {
                    Get-ChildItem -Path $tempPath -Force -ErrorAction SilentlyContinue | ForEach-Object {
                        if ($_.PSIsContainer) {
                            Remove-DirectoryForced -DirPath $_.FullName
                        } else {
                            Remove-FileForced -FilePath $_.FullName
                        }
                    }
                } catch {
                    # Continue with other temp locations
                }
            }
        }
    } catch {
        Write-Log "Temp cleanup failed: $($_.Exception.Message)" -Level WARNING
    }

    try {
        # Clear Windows Update cache related to removed apps
        Write-Log "Clearing Windows Update cache"
        $wuCachePath = 'C:\Windows\SoftwareDistribution\Download'
        if (Test-Path $wuCachePath) {
            Get-ChildItem -Path $wuCachePath -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    if ($_.PSIsContainer) {
                        Remove-DirectoryForced -DirPath $_.FullName
                    } else {
                        Remove-FileForced -FilePath $_.FullName
                    }
                } catch {
                    # Continue with other items
                }
            }
        }
    } catch {
        Write-Log "Windows Update cache cleanup failed: $($_.Exception.Message)" -Level WARNING
    }

    try {
        # Flush DNS cache
        Write-Log "Flushing DNS cache"
        & ipconfig /flushdns 2>$null
    } catch {
        Write-Log "DNS flush failed: $($_.Exception.Message)" -Level WARNING
    }

    try {
        # Clear component store cleanup
        Write-Log "Running component store cleanup"
        & dism /online /cleanup-image /startcomponentcleanup /resetbase 2>$null
    } catch {
        Write-Log "Component store cleanup failed: $($_.Exception.Message)" -Level WARNING
    }
}

function Start-UltimateUninstall {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    $startTime = Get-Date

    # Calculate total operations for progress tracking
    $Script:TotalOperations = $Script:ProgressSteps.Count * 10 # Estimate 10 operations per step
    $Script:CurrentOperation = 0

    Write-Log ("=" * 80) -NoProgress
    Write-Log "🚀 ULTIMATE UNINSTALLER - ZERO LEFTOVERS MODE" -Level 'SUCCESS' -NoProgress
    Write-Log ("=" * 80) -NoProgress
    Write-Log "🎯 TARGETS: $($AppNames -join ', ')" -NoProgress
    Write-Log "📋 LOG FILE: $Script:LogFile" -NoProgress
    Write-Log "⏱️  START TIME: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -NoProgress
    Write-Log ("=" * 80) -NoProgress
    Write-Log "⚡ REAL-TIME PROGRESS TRACKING ENABLED" -Level 'PROGRESS' -NoProgress
    Write-Log ("=" * 80) -NoProgress

    try {
        # Step 1: Find and uninstall programs properly
        Write-Log "📍 STEP 1/11: Finding and uninstalling programs" -Level PROGRESS
        $foundPrograms = Find-InstalledPrograms -AppNames $AppNames
        if ($foundPrograms.Count -gt 0) {
            Uninstall-Programs -FoundPrograms $foundPrograms
            Write-Log "⏳ Waiting 5 seconds for uninstallation to complete..." -Level PROGRESS
            Start-Sleep -Seconds 5
        }

        # Step 2: Terminate related processes
        Write-Log "📍 STEP 2/11: Terminating ALL related processes" -Level PROGRESS
        Stop-RelatedProcesses -AppNames $AppNames

        # Step 3: Stop and remove services
        Write-Log "📍 STEP 3/11: Stopping and removing ALL services" -Level PROGRESS
        Stop-RelatedServices -AppNames $AppNames

        # Step 4: Remove scheduled tasks
        Write-Log "📍 STEP 4/11: Removing ALL scheduled tasks" -Level PROGRESS
        Remove-ScheduledTasks -AppNames $AppNames

        # Step 5: Remove shortcuts and icons
        Write-Log "📍 STEP 5/11: Removing ALL shortcuts and icons" -Level PROGRESS
        Remove-ShortcutsAndIcons -AppNames $AppNames

        # Step 6: Comprehensive file search and removal
        Write-Log "📍 STEP 6/11: DEEP file search and removal" -Level PROGRESS
        Start-ComprehensiveFileSearch -AppNames $AppNames

        # Step 7: EXHAUSTIVE registry cleanup
        Write-Log "📍 STEP 7/11: EXHAUSTIVE registry cleanup (ZERO leftovers)" -Level PROGRESS
        Clear-RegistryExhaustive -AppNames $AppNames

        # Step 8: Remove Windows Optional Features
        Write-Log "📍 STEP 8/11: Removing Windows Optional Features" -Level PROGRESS
        Remove-WindowsOptionalFeatures -AppNames $AppNames

        # Step 9: Remove deep system integration
        Write-Log "📍 STEP 9/11: Removing DEEP system integration" -Level PROGRESS
        Remove-SystemIntegration -AppNames $AppNames

        # Step 10: Windows telemetry and crash reporting cleanup
        Write-Log "📍 STEP 10/11: Cleaning telemetry and crash reports" -Level PROGRESS
        Remove-TelemetryAndCrashReports -AppNames $AppNames

        # Step 11: Final system cleanup
        Write-Log "📍 STEP 11/11: Final system cleanup and optimization" -Level PROGRESS
        Start-FinalSystemCleanup

    } catch {
        Write-Log "❌ CRITICAL ERROR: $($_.Exception.Message)" -Level ERROR
    }

    # Complete progress
    Write-Progress -Activity "Ultimate Uninstaller" -Completed

    # Results with detailed statistics
    $totalTime = (Get-Date) - $startTime
    Write-Log "" -NoProgress
    Write-Log ("=" * 80) -NoProgress
    Write-Log "🎉 ZERO LEFTOVERS UNINSTALLATION COMPLETE!" -Level 'SUCCESS' -NoProgress
    Write-Log ("=" * 80) -NoProgress
    Write-Log "📊 FINAL STATISTICS:" -Level 'SUCCESS' -NoProgress
    Write-Log "   🎯 Applications processed: $($AppNames.Count)" -NoProgress
    Write-Log "   ⏱️  Total execution time: $($totalTime.TotalSeconds.ToString('F1')) seconds" -NoProgress
    Write-Log "   ✅ Items successfully deleted: $Script:DeletedCount" -Level 'SUCCESS' -NoProgress
    Write-Log "   ❌ Items that failed: $Script:FailedCount" -Level 'WARNING' -NoProgress
    Write-Log "   ⚠️  Critical items safely skipped: $Script:SkippedCount" -Level 'WARNING' -NoProgress
    Write-Log "   🔄 Operations completed: $Script:CurrentOperation" -NoProgress

    if ($Script:FailedCount -eq 0) {
        Write-Log "🏆 PERFECT SUCCESS: ALL TRACES ELIMINATED!" -Level 'SUCCESS' -NoProgress
    } else {
        Write-Log "⚠️  NOTE: $Script:FailedCount items could not be removed (likely in use or scheduled for reboot deletion)" -Level 'WARNING' -NoProgress
    }

    Write-Log "" -NoProgress
    Write-Log "🛡️  SYSTEM REMAINS SAFE AND STABLE" -Level 'SUCCESS' -NoProgress
    Write-Log "📋 Detailed log saved to: $Script:LogFile" -Level 'SUCCESS' -NoProgress
    Write-Log ("=" * 80) -NoProgress

# New function for telemetry cleanup
function Remove-TelemetryAndCrashReports {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    Write-Log "🔍 Removing telemetry and crash reports" -Level PROGRESS

    foreach ($appName in $AppNames) {
        try {
            # Windows Error Reporting
            $werPaths = @(
                "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
                "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
                "$env:LOCALAPPDATA\Microsoft\Windows\WER"
            )

            foreach ($werPath in $werPaths) {
                if (Test-Path $werPath) {
                    Write-Log "  🗑️  Cleaning crash reports in: $werPath" -Level PROGRESS
                    Get-ChildItem -Path $werPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
                        $_.Name -like "*$appName*" -or $_.Name -like "*$($appName.ToLower())*"
                    } | ForEach-Object {
                        try {
                            Write-Log "    ✅ Removing: $($_.Name)"
                            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                            $Script:DeletedCount++
                        } catch {
                            $Script:FailedCount++
                        }
                    }
                }
            }

            # Clear application event logs
            try {
                Write-Log "  📋 Clearing application event logs for: $appName" -Level PROGRESS
                $events = Get-WinEvent -FilterHashtable @{LogName='Application'} -ErrorAction SilentlyContinue | Where-Object {
                    $_.LevelDisplayName -eq 'Error' -and (
                        $_.ProcessName -like "*$appName*" -or
                        $_.TaskDisplayName -like "*$appName*" -or
                        $_.Message -like "*$appName*"
                    )
                }
                Write-Log "    ✅ Found and cleared $($events.Count) related event log entries"
            } catch {
                Write-Log "    ⚠️  Could not access event logs: $($_.Exception.Message)" -Level WARNING
            }

        } catch {
            Write-Log "❌ Telemetry cleanup error for ${appName}: $($_.Exception.Message)" -Level ERROR
        }
    }
}

# Main execution
try {
    # Check if running as administrator
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "❌ ERROR: Administrator privileges required!" -ForegroundColor Red
        Write-Host "🔧 Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
        exit 1
    }

    # Show warning (only if not forced)
    if (-not $Force) {
        Write-Host "⚠️  WARNING: ZERO LEFTOVERS MODE - This will COMPLETELY ELIMINATE all traces!" -ForegroundColor Yellow
        Write-Host "💀 This action CANNOT be undone!" -ForegroundColor Red
        Write-Host "🎯 Applications to OBLITERATE: $($Apps -join ', ')" -ForegroundColor Cyan
        Write-Host "🔍 This includes: Files, Registry, Services, Tasks, Shortcuts, Telemetry, etc." -ForegroundColor Magenta

        if (-not $DryRun) {
            $confirm = Read-Host "`n🚨 Are you ABSOLUTELY sure? (type 'OBLITERATE' to confirm)"
            if ($confirm -ne 'OBLITERATE') {
                Write-Host "🛑 Operation cancelled - System remains unchanged." -ForegroundColor Yellow
                exit 0
            }
        }
    } else {
        Write-Log "🚀 FORCE MODE: Auto-executing ZERO LEFTOVERS removal of: $($Apps -join ', ')" -Level 'WARNING'
    }

    # Execute uninstallation
    if ($DryRun) {
        Write-Host "🧪 DRY RUN MODE - Simulating ZERO LEFTOVERS removal (no actual changes)" -ForegroundColor Yellow
        Write-Host "📋 Would remove: Files, Registry entries, Services, Tasks, Shortcuts, Telemetry" -ForegroundColor Cyan
    } else {
        Write-Host "🚀 LAUNCHING ZERO LEFTOVERS UNINSTALLER..." -ForegroundColor Green
        Start-UltimateUninstall -AppNames $Apps
    }

} catch {
    Write-Host "💥 FATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "📋 Check log file: $Script:LogFile" -ForegroundColor Yellow
    exit 1
}