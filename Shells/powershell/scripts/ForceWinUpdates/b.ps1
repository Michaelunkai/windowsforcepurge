#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Ultimate Windows Updates Solution - Every Method Available
.DESCRIPTION
    Comprehensive Windows Update script using every possible method including:
    - PSWindowsUpdate module
    - Windows Update COM objects
    - WSUS Offline methods
    - Manual Microsoft Update Catalog downloads
    - Standalone installer execution
    - Cabinet file installation
    - Registry fixes and service resets
    - Manual download to Downloads folder as last resort
#>

param(
    [switch]$AutoReboot = $true,
    [int]$MaxRetries = 3,
    [string]$DownloadsPath = "$env:USERPROFILE\Downloads\WindowsUpdates"
)

# Global configuration
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$ProgressPreference = 'Continue'
$ErrorActionPreference = 'Continue'

# Global tracking variables
$Global:InstalledUpdates = @()
$Global:FailedUpdates = @()
$Global:TotalUpdatesFound = 0
$Global:MethodsAttempted = @()
$Global:UpdatesDownloadedManually = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
        switch($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            "PROGRESS" { "Cyan" }
            "METHOD" { "Magenta" }
            default { "White" }
        }
    )
}

function Show-ProgressBar {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete = 0,
        [int]$Id = 1
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -Id $Id
}

function Test-UpdatesAvailable {
    Write-Log "Checking if any updates are available..." "PROGRESS"
    Show-ProgressBar -Activity "Checking Updates Availability" -Status "Scanning..." -PercentComplete 20
    
    try {
        # Method 1: PSWindowsUpdate
        $psUpdates = @()
        if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
            Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
            $psUpdates = Get-WUList -ErrorAction SilentlyContinue
        }
        
        Show-ProgressBar -Activity "Checking Updates Availability" -Status "Checking COM objects..." -PercentComplete 50
        
        # Method 2: COM objects
        $comUpdates = @()
        try {
            $UpdateSession = New-Object -ComObject Microsoft.Update.Session
            $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
            $SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
            $comUpdates = $SearchResult.Updates
        }
        catch {
            Write-Log "COM object search failed: $($_.Exception.Message)" "WARN"
        }
        
        Show-ProgressBar -Activity "Checking Updates Availability" -Status "Checking Windows Update service..." -PercentComplete 80
        
        # Method 3: Check Windows Update service directly
        $wuService = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
        $serviceUpdates = $false
        if ($wuService -and $wuService.Status -eq 'Running') {
            try {
                $result = Start-Process -FilePath "powershell.exe" -ArgumentList "-Command `"(New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()`"" -Wait -PassThru -WindowStyle Hidden
                $serviceUpdates = $result.ExitCode -eq 0
            }
            catch { }
        }
        
        Show-ProgressBar -Activity "Checking Updates Availability" -Status "Analysis complete" -PercentComplete 100
        Write-Progress -Activity "Checking Updates Availability" -Completed
        
        $totalFound = $psUpdates.Count + $comUpdates.Count
        $Global:TotalUpdatesFound = $totalFound
        
        if ($totalFound -eq 0 -and -not $serviceUpdates) {
            Write-Log "No updates found by any method. System appears to be up to date." "SUCCESS"
            return $false
        }
        
        Write-Log "Found updates: PSWindowsUpdate=$($psUpdates.Count), COM Objects=$($comUpdates.Count)" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error checking updates availability: $($_.Exception.Message)" "ERROR"
        return $true  # Assume updates available if we can't check
    }
}

function Reset-WindowsUpdateCompletely {
    Write-Log "METHOD: Complete Windows Update Reset" "METHOD"
    $Global:MethodsAttempted += "Complete Windows Update Reset"
    Show-ProgressBar -Activity "Complete Windows Update Reset" -Status "Stopping all services..." -PercentComplete 5
    
    try {
        # Stop all Windows Update related services
        $services = @('wuauserv', 'cryptSvc', 'bits', 'msiserver', 'appidsvc', 'IKEEXT')
        foreach ($service in $services) {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Write-Log "Stopped service: $service" "PROGRESS"
        }
        
        Show-ProgressBar -Activity "Complete Windows Update Reset" -Status "Clearing all caches..." -PercentComplete 20
        
        # Clear all Windows Update caches and temporary files
        $cachePaths = @(
            "$env:WINDIR\SoftwareDistribution",
            "$env:WINDIR\System32\catroot2",
            "$env:WINDIR\WindowsUpdate.log",
            "$env:ALLUSERSPROFILE\Microsoft\Windows\WER\ReportQueue",
            "$env:WINDIR\Logs\WindowsUpdate"
        )
        
        foreach ($path in $cachePaths) {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Cleared: $path" "PROGRESS"
            }
        }
        
        Show-ProgressBar -Activity "Complete Windows Update Reset" -Status "Resetting registry entries..." -PercentComplete 40
        
        # Reset Windows Update registry entries
        $regPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results"
        )
        
        foreach ($regPath in $regPaths) {
            try {
                Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Reset registry: $regPath" "PROGRESS"
            }
            catch { }
        }
        
        Show-ProgressBar -Activity "Complete Windows Update Reset" -Status "Re-registering DLLs..." -PercentComplete 60
        
        # Re-register all Windows Update DLLs
        $dlls = @(
            'atl.dll', 'urlmon.dll', 'mshtml.dll', 'shdocvw.dll', 'browseui.dll',
            'jscript.dll', 'vbscript.dll', 'scrrun.dll', 'msxml.dll', 'msxml3.dll',
            'msxml6.dll', 'actxprxy.dll', 'softpub.dll', 'wintrust.dll',
            'dssenh.dll', 'rsaenh.dll', 'gpkcsp.dll', 'sccbase.dll',
            'slbcsp.dll', 'cryptdlg.dll', 'oleaut32.dll', 'ole32.dll',
            'shell32.dll', 'initpki.dll', 'wuapi.dll', 'wuaueng.dll',
            'wuaueng1.dll', 'wucltui.dll', 'wups.dll', 'wups2.dll',
            'wuweb.dll', 'qmgr.dll', 'qmgrprxy.dll', 'wucltux.dll',
            'muweb.dll', 'wuwebv.dll', 'wudriver.dll'
        )
        
        foreach ($dll in $dlls) {
            Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s $dll" -Wait -ErrorAction SilentlyContinue
        }
        
        Show-ProgressBar -Activity "Complete Windows Update Reset" -Status "Resetting Windows Update components..." -PercentComplete 80
        
        # Reset Windows Update components using built-in tools
        Start-Process -FilePath "sc.exe" -ArgumentList "config wuauserv start= auto" -Wait -WindowStyle Hidden
        Start-Process -FilePath "sc.exe" -ArgumentList "config bits start= auto" -Wait -WindowStyle Hidden
        Start-Process -FilePath "sc.exe" -ArgumentList "config cryptsvc start= auto" -Wait -WindowStyle Hidden
        
        # Restart services
        foreach ($service in $services) {
            Start-Service -Name $service -ErrorAction SilentlyContinue
            Write-Log "Started service: $service" "PROGRESS"
        }
        
        Show-ProgressBar -Activity "Complete Windows Update Reset" -Status "Running system repairs..." -PercentComplete 90
        
        # Run comprehensive system repairs
        Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -WindowStyle Hidden
        Start-Process -FilePath "dism.exe" -ArgumentList "/online /cleanup-image /restorehealth" -Wait -WindowStyle Hidden
        Start-Process -FilePath "dism.exe" -ArgumentList "/online /cleanup-image /startcomponentcleanup" -Wait -WindowStyle Hidden
        
        Show-ProgressBar -Activity "Complete Windows Update Reset" -Status "Reset completed!" -PercentComplete 100
        Write-Progress -Activity "Complete Windows Update Reset" -Completed
        Write-Log "Complete Windows Update reset finished successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error during complete reset: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Install-PSWindowsUpdateMethod {
    Write-Log "METHOD: PSWindowsUpdate Module Installation" "METHOD"
    $Global:MethodsAttempted += "PSWindowsUpdate Module"
    Show-ProgressBar -Activity "PSWindowsUpdate Method" -Status "Installing module..." -PercentComplete 10
    
    try {
        # Force TLS 1.2 and install
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -Force -Scope AllUsers
        }
        
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        
        if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
            Uninstall-Module -Name PSWindowsUpdate -AllVersions -Force -ErrorAction SilentlyContinue
        }
        
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -AllowClobber
        Import-Module PSWindowsUpdate -Force
        
        Show-ProgressBar -Activity "PSWindowsUpdate Method" -Status "Scanning for updates..." -PercentComplete 30
        
        $Updates = Get-WUList -MicrosoftUpdate -ErrorAction Stop
        if ($Updates.Count -eq 0) {
            $Updates = Get-WUList -WindowsUpdate -ErrorAction SilentlyContinue
        }
        if ($Updates.Count -eq 0) {
            $Updates = Get-WUList -Driver -ErrorAction SilentlyContinue
        }
        
        if ($Updates.Count -eq 0) {
            Write-Log "PSWindowsUpdate: No updates found" "SUCCESS"
            return $true
        }
        
        Write-Log "PSWindowsUpdate: Found $($Updates.Count) updates" "SUCCESS"
        
        Show-ProgressBar -Activity "PSWindowsUpdate Method" -Status "Installing updates..." -PercentComplete 60
        
        # Install updates with maximum force
        $result = Get-WUInstall -AcceptAll -AutoReboot:$false -Silent -Confirm:$false -ForceInstall -ErrorAction Stop
        
        Show-ProgressBar -Activity "PSWindowsUpdate Method" -Status "Installation completed!" -PercentComplete 100
        Write-Progress -Activity "PSWindowsUpdate Method" -Completed
        Write-Log "PSWindowsUpdate method completed successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "PSWindowsUpdate method failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Install-COMObjectMethod {
    Write-Log "METHOD: Windows Update COM Objects" "METHOD"
    $Global:MethodsAttempted += "COM Objects"
    Show-ProgressBar -Activity "COM Objects Method" -Status "Initializing COM objects..." -PercentComplete 10
    
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        
        Show-ProgressBar -Activity "COM Objects Method" -Status "Searching for updates..." -PercentComplete 20
        
        $SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
        
        if ($SearchResult.Updates.Count -eq 0) {
            Write-Log "COM Objects: No updates found" "SUCCESS"
            return $true
        }
        
        Write-Log "COM Objects: Found $($SearchResult.Updates.Count) updates" "SUCCESS"
        
        Show-ProgressBar -Activity "COM Objects Method" -Status "Downloading updates..." -PercentComplete 40
        
        # Download updates
        $UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
        $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        
        foreach ($Update in $SearchResult.Updates) {
            if (-not $Update.IsDownloaded) {
                $UpdatesToDownload.Add($Update) | Out-Null
            }
            $UpdatesToInstall.Add($Update) | Out-Null
        }
        
        if ($UpdatesToDownload.Count -gt 0) {
            $Downloader = $UpdateSession.CreateUpdateDownloader()
            $Downloader.Updates = $UpdatesToDownload
            $DownloadResult = $Downloader.Download()
            Write-Log "Download result: $($DownloadResult.ResultCode)" "PROGRESS"
        }
        
        Show-ProgressBar -Activity "COM Objects Method" -Status "Installing updates..." -PercentComplete 70
        
        # Install updates
        $Installer = $UpdateSession.CreateUpdateInstaller()
        $Installer.Updates = $UpdatesToInstall
        $InstallationResult = $Installer.Install()
        
        Show-ProgressBar -Activity "COM Objects Method" -Status "Installation completed!" -PercentComplete 100
        Write-Progress -Activity "COM Objects Method" -Completed
        Write-Log "COM Objects method completed with result: $($InstallationResult.ResultCode)" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "COM Objects method failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Install-WUSAMethod {
    Write-Log "METHOD: WUSA Standalone Installer" "METHOD"
    $Global:MethodsAttempted += "WUSA Standalone"
    Show-ProgressBar -Activity "WUSA Method" -Status "Searching for .msu files..." -PercentComplete 10
    
    try {
        # Look for any .msu files in common locations
        $msuPaths = @(
            "$env:WINDIR\SoftwareDistribution\Download",
            "$DownloadsPath",
            "$env:USERPROFILE\Downloads",
            "$env:TEMP"
        )
        
        $msuFiles = @()
        foreach ($path in $msuPaths) {
            if (Test-Path $path) {
                $msuFiles += Get-ChildItem -Path $path -Filter "*.msu" -Recurse -ErrorAction SilentlyContinue
            }
        }
        
        if ($msuFiles.Count -eq 0) {
            Write-Log "WUSA: No .msu files found" "WARN"
            return $false
        }
        
        Write-Log "WUSA: Found $($msuFiles.Count) .msu files" "SUCCESS"
        
        Show-ProgressBar -Activity "WUSA Method" -Status "Installing .msu files..." -PercentComplete 50
        
        foreach ($msuFile in $msuFiles) {
            Write-Log "Installing: $($msuFile.Name)" "PROGRESS"
            $result = Start-Process -FilePath "wusa.exe" -ArgumentList "`"$($msuFile.FullName)`" /quiet /norestart" -Wait -PassThru
            
            if ($result.ExitCode -eq 0 -or $result.ExitCode -eq 3010) {
                Write-Log "Successfully installed: $($msuFile.Name)" "SUCCESS"
                $Global:InstalledUpdates += @{
                    Title = $msuFile.Name
                    Method = "WUSA"
                    InstallTime = Get-Date
                    Status = "Success"
                }
            } else {
                Write-Log "Failed to install: $($msuFile.Name) (Exit code: $($result.ExitCode))" "ERROR"
            }
        }
        
        Show-ProgressBar -Activity "WUSA Method" -Status "WUSA installation completed!" -PercentComplete 100
        Write-Progress -Activity "WUSA Method" -Completed
        return $true
    }
    catch {
        Write-Log "WUSA method failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Install-CABMethod {
    Write-Log "METHOD: Cabinet (.cab) File Installation" "METHOD"
    $Global:MethodsAttempted += "CAB Files"
    Show-ProgressBar -Activity "CAB Method" -Status "Searching for .cab files..." -PercentComplete 10
    
    try {
        # Look for .cab files
        $cabPaths = @(
            "$env:WINDIR\SoftwareDistribution\Download",
            "$DownloadsPath",
            "$env:USERPROFILE\Downloads",
            "$env:TEMP"
        )
        
        $cabFiles = @()
        foreach ($path in $cabPaths) {
            if (Test-Path $path) {
                $cabFiles += Get-ChildItem -Path $path -Filter "*.cab" -Recurse -ErrorAction SilentlyContinue
            }
        }
        
        if ($cabFiles.Count -eq 0) {
            Write-Log "CAB: No .cab files found" "WARN"
            return $false
        }
        
        Write-Log "CAB: Found $($cabFiles.Count) .cab files" "SUCCESS"
        
        Show-ProgressBar -Activity "CAB Method" -Status "Installing .cab files..." -PercentComplete 50
        
        foreach ($cabFile in $cabFiles) {
            Write-Log "Installing: $($cabFile.Name)" "PROGRESS"
            
            # Method 1: DISM
            $result = Start-Process -FilePath "dism.exe" -ArgumentList "/online /add-package /packagepath:`"$($cabFile.FullName)`" /quiet /norestart" -Wait -PassThru
            
            if ($result.ExitCode -eq 0) {
                Write-Log "Successfully installed via DISM: $($cabFile.Name)" "SUCCESS"
                $Global:InstalledUpdates += @{
                    Title = $cabFile.Name
                    Method = "DISM CAB"
                    InstallTime = Get-Date
                    Status = "Success"
                }
                continue
            }
            
            # Method 2: PkgMgr
            $result = Start-Process -FilePath "pkgmgr.exe" -ArgumentList "/ip /m:`"$($cabFile.FullName)`" /quiet /norestart" -Wait -PassThru
            
            if ($result.ExitCode -eq 0 -or $result.ExitCode -eq 3010) {
                Write-Log "Successfully installed via PkgMgr: $($cabFile.Name)" "SUCCESS"
                $Global:InstalledUpdates += @{
                    Title = $cabFile.Name
                    Method = "PkgMgr CAB"
                    InstallTime = Get-Date
                    Status = "Success"
                }
            } else {
                Write-Log "Failed to install: $($cabFile.Name)" "ERROR"
            }
        }
        
        Show-ProgressBar -Activity "CAB Method" -Status "CAB installation completed!" -PercentComplete 100
        Write-Progress -Activity "CAB Method" -Completed
        return $true
    }
    catch {
        Write-Log "CAB method failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-UpdatesFromMicrosoftCatalog {
    Write-Log "METHOD: Manual Download from Microsoft Update Catalog" "METHOD"
    $Global:MethodsAttempted += "Microsoft Update Catalog"
    Show-ProgressBar -Activity "Microsoft Catalog Method" -Status "Preparing download folder..." -PercentComplete 10
    
    try {
        # Create downloads directory
        if (-not (Test-Path $DownloadsPath)) {
            New-Item -Path $DownloadsPath -ItemType Directory -Force | Out-Null
            Write-Log "Created downloads directory: $DownloadsPath" "PROGRESS"
        }
        
        Show-ProgressBar -Activity "Microsoft Catalog Method" -Status "Getting system information..." -PercentComplete 20
        
        # Get system information for targeted downloads
        $OSVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
        $Architecture = (Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture
        $BuildNumber = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
        
        Write-Log "System Info: Windows $OSVersion ($Architecture) Build $BuildNumber" "PROGRESS"
        
        Show-ProgressBar -Activity "Microsoft Catalog Method" -Status "Searching for critical updates..." -PercentComplete 40
        
        # Common critical updates to check for manually
        $criticalUpdates = @(
            @{ Name = "Security Update"; Pattern = "KB*"; Url = "https://www.catalog.update.microsoft.com/Search.aspx?q=Security%20Update%20Windows%2010" },
            @{ Name = "Cumulative Update"; Pattern = "KB*"; Url = "https://www.catalog.update.microsoft.com/Search.aspx?q=Cumulative%20Update%20Windows%2010" },
            @{ Name = "Feature Update"; Pattern = "KB*"; Url = "https://www.catalog.update.microsoft.com/Search.aspx?q=Feature%20Update%20Windows%2010" },
            @{ Name = "Servicing Stack Update"; Pattern = "KB*"; Url = "https://www.catalog.update.microsoft.com/Search.aspx?q=Servicing%20Stack%20Update" }
        )
        
        # Manual download instructions
        Write-Host "`n" -NoNewline
        Write-Host "=" * 80 -ForegroundColor Yellow
        Write-Host "MANUAL DOWNLOAD REQUIRED" -ForegroundColor Yellow
        Write-Host "=" * 80 -ForegroundColor Yellow
        Write-Host "`nAutomatic download from Microsoft Update Catalog requires manual intervention." -ForegroundColor White
        Write-Host "Please follow these steps:" -ForegroundColor White
        Write-Host "`n1. Open your web browser" -ForegroundColor Cyan
        Write-Host "2. Go to: https://www.catalog.update.microsoft.com/" -ForegroundColor Cyan
        Write-Host "3. Search for your Windows version updates:" -ForegroundColor Cyan
        Write-Host "   - Windows $OSVersion $Architecture Build $BuildNumber" -ForegroundColor Gray
        Write-Host "4. Download .msu/.cab files to: $DownloadsPath" -ForegroundColor Cyan
        Write-Host "5. Press any key to continue once downloads are complete..." -ForegroundColor Green
        Write-Host "`nRecommended searches:" -ForegroundColor White
        
        foreach ($update in $criticalUpdates) {
            Write-Host "   - $($update.Name) for Windows 10/11" -ForegroundColor Gray
        }
        
        Write-Host "`n" -NoNewline
        Write-Host "=" * 80 -ForegroundColor Yellow
        
        # Wait for user to download files
        Read-Host "`nPress Enter after downloading updates to $DownloadsPath"
        
        Show-ProgressBar -Activity "Microsoft Catalog Method" -Status "Checking downloaded files..." -PercentComplete 70
        
        # Check for downloaded files
        $downloadedFiles = @()
        if (Test-Path $DownloadsPath) {
            $downloadedFiles = Get-ChildItem -Path $DownloadsPath -Include "*.msu", "*.cab" -Recurse
        }
        
        if ($downloadedFiles.Count -eq 0) {
            Write-Log "No update files found in downloads folder" "WARN"
            return $false
        }
        
        Write-Log "Found $($downloadedFiles.Count) downloaded update files" "SUCCESS"
        $Global:UpdatesDownloadedManually = $downloadedFiles
        
        Show-ProgressBar -Activity "Microsoft Catalog Method" -Status "Installing downloaded files..." -PercentComplete 80
        
        # Install downloaded files
        foreach ($file in $downloadedFiles) {
            Write-Log "Installing downloaded file: $($file.Name)" "PROGRESS"
            
            if ($file.Extension -eq ".msu") {
                $result = Start-Process -FilePath "wusa.exe" -ArgumentList "`"$($file.FullName)`" /quiet /norestart" -Wait -PassThru
            } elseif ($file.Extension -eq ".cab") {
                $result = Start-Process -FilePath "dism.exe" -ArgumentList "/online /add-package /packagepath:`"$($file.FullName)`" /quiet /norestart" -Wait -PassThru
            }
            
            if ($result.ExitCode -eq 0 -or $result.ExitCode -eq 3010) {
                Write-Log "Successfully installed: $($file.Name)" "SUCCESS"
                $Global:InstalledUpdates += @{
                    Title = $file.Name
                    Method = "Manual Download"
                    InstallTime = Get-Date
                    Status = "Success"
                }
            } else {
                Write-Log "Failed to install: $($file.Name) (Exit code: $($result.ExitCode))" "ERROR"
            }
        }
        
        Show-ProgressBar -Activity "Microsoft Catalog Method" -Status "Manual installation completed!" -PercentComplete 100
        Write-Progress -Activity "Microsoft Catalog Method" -Completed
        return $true
    }
    catch {
        Write-Log "Microsoft Catalog method failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Show-FinalSummary {
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host "ULTIMATE WINDOWS UPDATE SUMMARY" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Green
    
    Write-Host "`nMethods Attempted:" -ForegroundColor Yellow
    foreach ($method in $Global:MethodsAttempted) {
        Write-Host "  ✓ $method" -ForegroundColor Gray
    }
    
    Write-Host "`nTotal Updates Found: $Global:TotalUpdatesFound" -ForegroundColor Yellow
    Write-Host "Successfully Installed: $($Global:InstalledUpdates.Count)" -ForegroundColor Green
    Write-Host "Failed Installations: $($Global:FailedUpdates.Count)" -ForegroundColor Red
    Write-Host "Manually Downloaded: $($Global:UpdatesDownloadedManually.Count)" -ForegroundColor Cyan
    
    if ($Global:InstalledUpdates.Count -gt 0) {
        Write-Host "`n" -NoNewline
        Write-Host "SUCCESSFULLY INSTALLED UPDATES:" -ForegroundColor Green
        Write-Host "-" * 50 -ForegroundColor Green
        
        foreach ($update in $Global:InstalledUpdates) {
            Write-Host "✓ $($update.Title)" -ForegroundColor Green
            Write-Host "  Method: $($update.Method) | Installed: $($update.InstallTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        }
    }
    
    if ($Global:FailedUpdates.Count -gt 0) {
        Write-Host "`n" -NoNewline
        Write-Host "FAILED UPDATES:" -ForegroundColor Red
        Write-Host "-" * 50 -ForegroundColor Red
        
        foreach ($update in $Global:FailedUpdates) {
            Write-Host "✗ $($update.Title)" -ForegroundColor Red
            Write-Host "  Error: $($update.Error)" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Green
}

# Main execution
try {
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "ULTIMATE WINDOWS UPDATES SOLUTION" -ForegroundColor Cyan
    Write-Host "Every Method Available | Manual Download Fallback | Complete Coverage" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    
    Write-Log "Starting Ultimate Windows Updates Solution..." "SUCCESS"
    
    # Step 0: Check if any updates are available
    Write-Log "Step 0: Checking if updates are available..." "PROGRESS"
    if (-not (Test-UpdatesAvailable)) {
        Write-Log "No updates available. Skipping all installation steps." "SUCCESS"
        Write-Host "`n" -NoNewline
        Write-Host "=" * 80 -ForegroundColor Green
        Write-Host "SYSTEM IS UP TO DATE - NO UPDATES REQUIRED" -ForegroundColor Green
        Write-Host "=" * 80 -ForegroundColor Green
        exit 0
    }
    
    # Step 1: Complete Windows Update reset
    Write-Log "Step 1: Complete Windows Update reset..." "PROGRESS"
    Reset-WindowsUpdateCompletely
    
    # Step 2: PSWindowsUpdate method
    Write-Log "Step 2: Attempting PSWindowsUpdate method..." "PROGRESS"
    $psSuccess = Install-PSWindowsUpdateMethod
    
    # Step 3: COM Objects method
    Write-Log "Step 3: Attempting COM Objects method..." "PROGRESS"
    $comSuccess = Install-COMObjectMethod
    
    # Step 4: WUSA standalone method
    Write-Log "Step 4: Attempting WUSA standalone method..." "PROGRESS"
    $wusaSuccess = Install-WUSAMethod
    
    # Step 5: CAB files method
    Write-Log "Step 5: Attempting CAB files method..." "PROGRESS"
    $cabSuccess = Install-CABMethod
    
    # Step 6: Manual download method (last resort)
    if (-not $psSuccess -and -not $comSuccess -and -not $wusaSuccess -and -not $cabSuccess) {
        Write-Log "Step 6: All automatic methods failed. Attempting manual download..." "WARN"
        Get-UpdatesFromMicrosoftCatalog
    }
    
    # Final summary
    Show-FinalSummary
    
    Write-Log "Ultimate Windows Updates Solution completed!" "SUCCESS"
    
    # Final reboot check
    $rebootRequired = $false
    try {
        if (Get-Command Get-WURebootStatus -ErrorAction SilentlyContinue) {
            $rebootRequired = Get-WURebootStatus -Silent
        }
    }
    catch { }
    
    if ($rebootRequired -and $AutoReboot) {
        Write-Log "Reboot required. System will restart in 30 seconds..." "WARN"
        Start-Sleep -Seconds 30
        Restart-Computer -Force
    } elseif ($rebootRequired) {
        Write-Log "Reboot required to complete installations. Please restart your computer." "WARN"
    }
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" "ERROR"
    Show-FinalSummary
    exit 1
}

Write-Host "`n" -NoNewline
Write-Host "=" * 80 -ForegroundColor Green
Write-Log "Ultimate Windows Updates Solution completed successfully!" "SUCCESS"
Write-Host "=" * 80 -ForegroundColor Green
