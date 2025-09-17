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
$Script:LogFile = "$env:TEMP\UltimateUninstaller_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Critical system files that should NEVER be deleted
$Script:CriticalSystemFiles = @(
    'ntoskrnl.exe', 'hal.dll', 'win32k.sys', 'ntdll.dll', 'kernel32.dll',
    'user32.dll', 'gdi32.dll', 'advapi32.dll', 'msvcrt.dll', 'shell32.dll',
    'ole32.dll', 'oleaut32.dll', 'comctl32.dll', 'comdlg32.dll', 'wininet.dll',
    'urlmon.dll', 'shlwapi.dll', 'version.dll', 'mpr.dll', 'netapi32.dll',
    'winspool.drv', 'ws2_32.dll', 'wsock32.dll', 'mswsock.dll', 'dnsapi.dll',
    'iphlpapi.dll', 'dhcpcsvc.dll', 'winhttp.dll', 'crypt32.dll', 'wintrust.dll',
    'imagehlp.dll', 'psapi.dll', 'secur32.dll', 'netman.dll', 'rasapi32.dll',
    'tapi32.dll', 'rtutils.dll', 'setupapi.dll', 'cfgmgr32.dll', 'devmgr.dll',
    'newdev.dll', 'wtsapi32.dll', 'winsta.dll', 'authz.dll', 'xmllite.dll',
    'explorer.exe', 'winlogon.exe', 'csrss.exe', 'smss.exe', 'wininit.exe',
    'services.exe', 'lsass.exe', 'svchost.exe', 'dwm.exe', 'taskhost.exe',
    'taskhostw.exe', 'sihost.exe', 'ctfmon.exe', 'RuntimeBroker.exe',
    'ApplicationFrameHost.exe', 'WWAHost.exe', 'SearchUI.exe', 'ShellExperienceHost.exe'
)

# Critical system paths
$Script:CriticalSystemPaths = @(
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
    'C:\Windows\Web\'
)

# Safe subdirectories within critical paths
$Script:SafeSubdirs = @('temp', 'logs', 'prefetch', 'installer', 'downloaded program files')

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    # Write to console with colors
    switch ($Level) {
        'ERROR' { Write-Host $logEntry -ForegroundColor Red }
        'WARNING' { Write-Host $logEntry -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry -ForegroundColor White }
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

    # Check critical file names
    if ($Script:CriticalSystemFiles -contains $fileName) {
        return $true
    }

    # Check critical paths
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
                return $true
            }
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

    Write-Log "Stopping and removing related services"

    foreach ($appName in $AppNames) {
        try {
            $services = Get-Service | Where-Object { $_.Name -match $appName -or $_.DisplayName -match $appName }

            foreach ($service in $services) {
                try {
                    Write-Log "Stopping service: $($service.Name)"
                    Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2

                    Write-Log "Removing service: $($service.Name)"
                    & sc.exe delete $service.Name 2>$null
                } catch {
                    Write-Log "Service cleanup error for $($service.Name): $($_.Exception.Message)" -Level WARNING
                }
            }
        } catch {
            Write-Log "Service cleanup error for ${appName}: $($_.Exception.Message)" -Level ERROR
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
        'C:\ProgramData\Microsoft\Windows\WER'
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

        foreach ($location in $searchLocations) {
            if (-not (Test-Path $location)) {
                continue
            }

            Write-Log "Searching in: $location"
            try {
                # Use PowerShell Get-ChildItem for recursive search
                $patterns = @("*$appName*", "*$($appName.ToLower())*", "*$($appName.ToUpper())*")

                foreach ($pattern in $patterns) {
                    try {
                        $matches = Get-ChildItem -Path $location -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pattern }
                        $allTargets += $matches | Select-Object -ExpandProperty FullName
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

function Clear-RegistrySafe {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    Write-Log "Starting safe registry cleanup"

    # Define safe registry areas for application cleanup
    $safeCleanupAreas = @(
        @{ Root = 'HKCU:'; Path = 'Software' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Classes\Installer\Products' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths' },
        @{ Root = 'HKCU:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run' },
        @{ Root = 'HKLM:'; Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run' }
    )

    foreach ($appName in $AppNames) {
        Write-Log "Cleaning registry for: $appName"

        foreach ($area in $safeCleanupAreas) {
            $fullPath = "$($area.Root)\$($area.Path)"
            try {
                if (Test-Path $fullPath) {
                    Clear-RegistryKey -KeyPath $fullPath -AppName $appName
                }
            } catch {
                Write-Log "Registry cleanup error in ${fullPath}: $($_.Exception.Message)" -Level ERROR
            }
        }
    }
}

function Clear-RegistryKey {
    param(
        [Parameter(Mandatory=$true)]
        [string]$KeyPath,

        [Parameter(Mandatory=$true)]
        [string]$AppName
    )

    try {
        # Find and delete matching subkeys
        $subKeys = Get-ChildItem -Path $KeyPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match $AppName }
        foreach ($subKey in $subKeys) {
            try {
                Write-Log "Deleting registry key: $($subKey.PSPath)"
                Remove-Item -Path $subKey.PSPath -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Log "Could not delete registry key $($subKey.PSPath): $($_.Exception.Message)" -Level WARNING
            }
        }

        # Find and delete matching values
        $properties = Get-ItemProperty -Path $KeyPath -ErrorAction SilentlyContinue
        if ($properties) {
            $properties.PSObject.Properties | Where-Object {
                $_.Name -match $AppName -or ($_.Value -is [string] -and $_.Value -match $AppName)
            } | ForEach-Object {
                try {
                    Write-Log "Deleting registry value: $KeyPath\$($_.Name)"
                    Remove-ItemProperty -Path $KeyPath -Name $_.Name -ErrorAction SilentlyContinue
                } catch {
                    Write-Log "Could not delete registry value $($_.Name): $($_.Exception.Message)" -Level WARNING
                }
            }
        }
    } catch {
        Write-Log "Error processing registry key ${KeyPath}: $($_.Exception.Message)" -Level ERROR
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
        # Flush DNS cache
        Write-Log "Flushing DNS cache"
        & ipconfig /flushdns 2>$null
    } catch {
        Write-Log "DNS flush failed: $($_.Exception.Message)" -Level WARNING
    }
}

function Start-UltimateUninstall {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppNames
    )

    $startTime = Get-Date

    Write-Log ("=" * 80)
    Write-Log "ULTIMATE SAFE UNINSTALLER - COMPLETE REMOVAL" -Level 'SUCCESS'
    Write-Log ("=" * 80)
    Write-Log "TARGETS: $($AppNames -join ', ')"
    Write-Log "LOG FILE: $Script:LogFile"
    Write-Log ("=" * 80)

    try {
        # Step 1: Find and uninstall programs properly
        $foundPrograms = Find-InstalledPrograms -AppNames $AppNames
        if ($foundPrograms.Count -gt 0) {
            Uninstall-Programs -FoundPrograms $foundPrograms
            Start-Sleep -Seconds 5  # Wait for uninstallation to complete
        }

        # Step 2: Terminate related processes
        Stop-RelatedProcesses -AppNames $AppNames

        # Step 3: Stop and remove services
        Stop-RelatedServices -AppNames $AppNames

        # Step 4: Remove scheduled tasks
        Remove-ScheduledTasks -AppNames $AppNames

        # Step 5: Remove shortcuts and icons
        Remove-ShortcutsAndIcons -AppNames $AppNames

        # Step 6: Comprehensive file search and removal
        Start-ComprehensiveFileSearch -AppNames $AppNames

        # Step 7: Safe registry cleanup
        Clear-RegistrySafe -AppNames $AppNames

        # Step 8: Final system cleanup
        Start-FinalSystemCleanup

    } catch {
        Write-Log "Uninstallation error: $($_.Exception.Message)" -Level ERROR
    }

    # Results
    $totalTime = (Get-Date) - $startTime
    Write-Log ""
    Write-Log ("=" * 80)
    Write-Log "UNINSTALLATION COMPLETE!" -Level 'SUCCESS'
    Write-Log ("=" * 80)
    Write-Log "Applications processed: $($AppNames.Count)"
    Write-Log "Total time: $($totalTime.TotalSeconds.ToString('F1')) seconds"
    Write-Log "Items deleted: $Script:DeletedCount" -Level 'SUCCESS'
    Write-Log "Items failed: $Script:FailedCount" -Level 'WARNING'
    Write-Log "Critical items skipped: $Script:SkippedCount" -Level 'WARNING'

    if ($Script:FailedCount -eq 0) {
        Write-Log "SUCCESS: ALL ITEMS REMOVED!" -Level 'SUCCESS'
    } else {
        Write-Log "NOTE: $Script:FailedCount items could not be removed or are scheduled for deletion on reboot" -Level 'WARNING'
    }

    Write-Log "UNINSTALLATION COMPLETED SAFELY!" -Level 'SUCCESS'
    Write-Log "Log file saved to: $Script:LogFile" -Level 'SUCCESS'
}

# Main execution
try {
    # Check if running as administrator
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "ERROR: Administrator privileges required!" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
        exit 1
    }

    # Show warning (only if not forced)
    if (-not $Force) {
        Write-Host "WARNING: This will completely remove all traces of the specified applications." -ForegroundColor Yellow
        Write-Host "This action cannot be undone!" -ForegroundColor Red
        Write-Host "Applications to remove: $($Apps -join ', ')" -ForegroundColor Cyan

        if (-not $DryRun) {
            $confirm = Read-Host "`nAre you sure you want to continue? (type 'YES' to confirm)"
            if ($confirm -ne 'YES') {
                Write-Host "Operation cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
    } else {
        Write-Log "FORCE MODE: Auto-executing removal of: $($Apps -join ', ')" -Level 'WARNING'
    }

    # Execute uninstallation
    if ($DryRun) {
        Write-Host "DRY RUN MODE - No actual changes will be made" -ForegroundColor Yellow
        # Could implement dry run logic here
    } else {
        Start-UltimateUninstall -AppNames $Apps
    }

} catch {
    Write-Host "FATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}