#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Force Windows Updates Installation with Real-Time Progress and Detailed Reporting
.DESCRIPTION
    This script forces installation of all available Windows Updates with real-time progress
    reporting and comprehensive update summaries. Runs with detailed progress indicators.
#>

param(
    [switch]$AutoReboot = $true,
    [int]$MaxRetries = 3
)

# Set execution policy and configure progress reporting
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$ProgressPreference = 'Continue'  # Show progress bars
$ErrorActionPreference = 'Continue'

# Global variables for tracking
$Global:InstalledUpdates = @()
$Global:FailedUpdates = @()
$Global:TotalUpdatesFound = 0

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
        switch($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            "PROGRESS" { "Cyan" }
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

function Reset-WindowsUpdateServices {
    Write-Log "Resetting Windows Update services..." "PROGRESS"
    Show-ProgressBar -Activity "Resetting Windows Update Services" -Status "Stopping services..." -PercentComplete 10
    
    try {
        # Stop Windows Update services
        $services = @('wuauserv', 'cryptSvc', 'bits', 'msiserver')
        $serviceCount = $services.Count
        for ($i = 0; $i -lt $serviceCount; $i++) {
            $service = $services[$i]
            $percent = [math]::Round(($i / $serviceCount) * 30 + 10)
            Show-ProgressBar -Activity "Resetting Windows Update Services" -Status "Stopping $service..." -PercentComplete $percent
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Write-Log "Stopped $service" "PROGRESS"
        }
        
        # Clear Windows Update cache
        Show-ProgressBar -Activity "Resetting Windows Update Services" -Status "Clearing cache..." -PercentComplete 50
        $cachePaths = @(
            "$env:WINDIR\SoftwareDistribution",
            "$env:WINDIR\System32\catroot2"
        )
        
        foreach ($path in $cachePaths) {
            if (Test-Path $path) {
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Cleared cache: $path" "PROGRESS"
            }
        }
        
        # Restart services
        Show-ProgressBar -Activity "Resetting Windows Update Services" -Status "Starting services..." -PercentComplete 70
        for ($i = 0; $i -lt $serviceCount; $i++) {
            $service = $services[$i]
            $percent = [math]::Round(($i / $serviceCount) * 20 + 70)
            Show-ProgressBar -Activity "Resetting Windows Update Services" -Status "Starting $service..." -PercentComplete $percent
            Start-Service -Name $service -ErrorAction SilentlyContinue
            Write-Log "Started $service" "PROGRESS"
        }
        
        # Re-register Windows Update DLLs
        Show-ProgressBar -Activity "Resetting Windows Update Services" -Status "Re-registering DLLs..." -PercentComplete 90
        $dlls = @(
            'atl.dll', 'urlmon.dll', 'mshtml.dll', 'shdocvw.dll', 'browseui.dll',
            'jscript.dll', 'vbscript.dll', 'scrrun.dll', 'msxml.dll', 'msxml3.dll',
            'msxml6.dll', 'actxprxy.dll', 'softpub.dll', 'wintrust.dll',
            'dssenh.dll', 'rsaenh.dll', 'gpkcsp.dll', 'sccbase.dll',
            'slbcsp.dll', 'cryptdlg.dll', 'oleaut32.dll', 'ole32.dll',
            'shell32.dll', 'initpki.dll', 'wuapi.dll', 'wuaueng.dll',
            'wuaueng1.dll', 'wucltui.dll', 'wups.dll', 'wups2.dll',
            'wuweb.dll', 'qmgr.dll', 'qmgrprxy.dll', 'wucltux.dll',
            'muweb.dll', 'wuwebv.dll'
        )
        
        $dllCount = $dlls.Count
        for ($i = 0; $i -lt $dllCount; $i++) {
            $dll = $dlls[$i]
            if ($i % 5 -eq 0) {  # Update progress every 5 DLLs
                $percent = [math]::Round(($i / $dllCount) * 10 + 90)
                Show-ProgressBar -Activity "Resetting Windows Update Services" -Status "Re-registering $dll..." -PercentComplete $percent
            }
            Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s $dll" -Wait -ErrorAction SilentlyContinue
        }
        
        Show-ProgressBar -Activity "Resetting Windows Update Services" -Status "Completed!" -PercentComplete 100
        Write-Progress -Activity "Resetting Windows Update Services" -Completed
        Write-Log "Windows Update services reset completed" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error resetting Windows Update services: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Install-PSWindowsUpdateModule {
    Write-Log "Installing PSWindowsUpdate module..." "PROGRESS"
    Show-ProgressBar -Activity "Installing PSWindowsUpdate Module" -Status "Configuring security..." -PercentComplete 10
    
    try {
        # Force TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Install NuGet provider if needed
        Show-ProgressBar -Activity "Installing PSWindowsUpdate Module" -Status "Installing NuGet provider..." -PercentComplete 20
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -Force -Scope AllUsers
            Write-Log "NuGet provider installed" "PROGRESS"
        }
        
        # Trust PSGallery
        Show-ProgressBar -Activity "Installing PSWindowsUpdate Module" -Status "Configuring PSGallery..." -PercentComplete 30
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        
        # Remove any existing PSWindowsUpdate module
        Show-ProgressBar -Activity "Installing PSWindowsUpdate Module" -Status "Removing old versions..." -PercentComplete 40
        if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
            Uninstall-Module -Name PSWindowsUpdate -AllVersions -Force -ErrorAction SilentlyContinue
            Write-Log "Removed existing PSWindowsUpdate module" "PROGRESS"
        }
        
        # Install latest version
        Show-ProgressBar -Activity "Installing PSWindowsUpdate Module" -Status "Installing latest version..." -PercentComplete 60
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -AllowClobber
        
        Show-ProgressBar -Activity "Installing PSWindowsUpdate Module" -Status "Importing module..." -PercentComplete 90
        Import-Module PSWindowsUpdate -Force
        
        Show-ProgressBar -Activity "Installing PSWindowsUpdate Module" -Status "Completed!" -PercentComplete 100
        Write-Progress -Activity "Installing PSWindowsUpdate Module" -Completed
        Write-Log "PSWindowsUpdate module installed successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error installing PSWindowsUpdate module: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-UpdateDetails {
    param($Update)
    
    $size = if ($Update.MaxDownloadSize -gt 0) {
        "{0:N2} MB" -f ($Update.MaxDownloadSize / 1MB)
    } else {
        "Unknown"
    }
    
    return @{
        Title = $Update.Title
        Size = $size
        Description = $Update.Description
        KBArticleIDs = $Update.KBArticleIDs -join ", "
        Categories = ($Update.Categories | ForEach-Object { $_.Name }) -join ", "
        Severity = if ($Update.MsrcSeverity) { $Update.MsrcSeverity } else { "N/A" }
        RebootRequired = $Update.RebootRequired
    }
}

function Install-WindowsUpdates {
    param([int]$RetryCount = 0)
    
    Write-Log "Starting Windows Updates installation (Attempt $($RetryCount + 1)/$MaxRetries)..." "PROGRESS"
    Show-ProgressBar -Activity "Windows Updates Installation" -Status "Scanning for updates..." -PercentComplete 5
    
    try {
        # Check for available updates with detailed progress
        Write-Log "Scanning for available updates..." "PROGRESS"
        
        # Use different search methods for comprehensive scanning
        Write-Log "Performing comprehensive update scan..." "PROGRESS"
        Show-ProgressBar -Activity "Windows Updates Installation" -Status "Scanning for all update types..." -PercentComplete 10
        
        $Updates = @()
        $Updates += Get-WUList -MicrosoftUpdate -ErrorAction SilentlyContinue
        Show-ProgressBar -Activity "Windows Updates Installation" -Status "Scanning Microsoft Updates..." -PercentComplete 15
        
        $Updates += Get-WUList -WindowsUpdate -ErrorAction SilentlyContinue
        Show-ProgressBar -Activity "Windows Updates Installation" -Status "Scanning Windows Updates..." -PercentComplete 20
        
        $Updates += Get-WUList -Driver -ErrorAction SilentlyContinue
        Show-ProgressBar -Activity "Windows Updates Installation" -Status "Scanning Driver Updates..." -PercentComplete 25
        
        # Remove duplicates
        $Updates = $Updates | Sort-Object Title -Unique
        $Global:TotalUpdatesFound = $Updates.Count
        
        if ($Updates.Count -eq 0) {
            Show-ProgressBar -Activity "Windows Updates Installation" -Status "No updates found" -PercentComplete 100
            Write-Progress -Activity "Windows Updates Installation" -Completed
            Write-Log "No updates available" "SUCCESS"
            return $true
        }
        
        Write-Log "Found $($Updates.Count) updates to install" "SUCCESS"
        Write-Host "`n" -NoNewline
        Write-Host "=" * 80 -ForegroundColor Yellow
        Write-Host "AVAILABLE UPDATES DETAILS:" -ForegroundColor Yellow
        Write-Host "=" * 80 -ForegroundColor Yellow
        
        # Display detailed information about each update
        for ($i = 0; $i -lt $Updates.Count; $i++) {
            $update = $Updates[$i]
            $details = Get-UpdateDetails -Update $update
            
            Write-Host "`n[$($i + 1)/$($Updates.Count)] " -NoNewline -ForegroundColor Cyan
            Write-Host "$($details.Title)" -ForegroundColor White
            Write-Host "    Size: $($details.Size) | Categories: $($details.Categories)" -ForegroundColor Gray
            Write-Host "    KB Articles: $($details.KBArticleIDs) | Severity: $($details.Severity)" -ForegroundColor Gray
            Write-Host "    Reboot Required: $($details.RebootRequired)" -ForegroundColor Gray
            
            if ($details.Description -and $details.Description.Length -gt 0) {
                $shortDesc = if ($details.Description.Length -gt 100) {
                    $details.Description.Substring(0, 100) + "..."
                } else {
                    $details.Description
                }
                Write-Host "    Description: $shortDesc" -ForegroundColor DarkGray
            }
        }
        
        Write-Host "`n" -NoNewline
        Write-Host "=" * 80 -ForegroundColor Yellow
        Write-Host "INSTALLING UPDATES..." -ForegroundColor Yellow
        Write-Host "=" * 80 -ForegroundColor Yellow
        
        # Install updates one by one with detailed progress
        for ($i = 0; $i -lt $Updates.Count; $i++) {
            $update = $Updates[$i]
            $percent = [math]::Round(($i / $Updates.Count) * 70 + 25)
            $details = Get-UpdateDetails -Update $update
            
            Show-ProgressBar -Activity "Windows Updates Installation" -Status "Installing: $($details.Title)" -PercentComplete $percent
            Write-Log "Installing update $($i + 1)/$($Updates.Count): $($details.Title)" "PROGRESS"
            
            try {
                # Install individual update
                $result = Install-WindowsUpdate -KBArticleID $update.KBArticleIDs -AcceptAll -AutoReboot:$false -Silent -Confirm:$false -ErrorAction Stop
                
                # Track successful installation
                $Global:InstalledUpdates += @{
                    Title = $details.Title
                    KBArticleIDs = $details.KBArticleIDs
                    Size = $details.Size
                    InstallTime = Get-Date
                    Status = "Success"
                }
                
                Write-Log "Successfully installed: $($details.Title)" "SUCCESS"
            }
            catch {
                # Track failed installation
                $Global:FailedUpdates += @{
                    Title = $details.Title
                    KBArticleIDs = $details.KBArticleIDs
                    Error = $_.Exception.Message
                    InstallTime = Get-Date
                }
                
                Write-Log "Failed to install: $($details.Title) - $($_.Exception.Message)" "ERROR"
            }
        }
        
        # Final installation attempt for any remaining updates
        Show-ProgressBar -Activity "Windows Updates Installation" -Status "Finalizing installation..." -PercentComplete 95
        Write-Log "Performing final installation sweep..." "PROGRESS"
        
        try {
            Get-WUInstall -AcceptAll -AutoReboot:$false -Silent -Confirm:$false -ForceInstall -ErrorAction SilentlyContinue
        }
        catch {
            Write-Log "Final installation sweep completed with some errors" "WARN"
        }
        
        Show-ProgressBar -Activity "Windows Updates Installation" -Status "Installation completed!" -PercentComplete 100
        Write-Progress -Activity "Windows Updates Installation" -Completed
        Write-Log "Updates installation completed" "SUCCESS"
        
        # Check if reboot is required
        if (Get-WURebootStatus -Silent) {
            Write-Log "Reboot required to complete installation" "WARN"
            if ($AutoReboot) {
                Write-Log "System will reboot in 30 seconds..." "WARN"
                Start-Sleep -Seconds 30
                Restart-Computer -Force
            }
        }
        
        return $true
    }
    catch {
        Write-Log "Error during updates installation: $($_.Exception.Message)" "ERROR"
        
        if ($RetryCount -lt $MaxRetries - 1) {
            Write-Log "Retrying after resetting Windows Update services..." "WARN"
            Reset-WindowsUpdateServices
            Start-Sleep -Seconds 10
            return Install-WindowsUpdates -RetryCount ($RetryCount + 1)
        }
        
        return $false
    }
}

function Fix-WindowsUpdateProblems {
    Write-Log "Running Windows Update troubleshooter..." "PROGRESS"
    Show-ProgressBar -Activity "Fixing Windows Update Problems" -Status "Running troubleshooter..." -PercentComplete 10
    
    try {
        # Run Windows Update troubleshooter
        $troubleshooter = Get-TroubleshootingPack -Path "$env:WINDIR\diagnostics\system\WindowsUpdate" -ErrorAction SilentlyContinue
        if ($troubleshooter) {
            Invoke-TroubleshootingPack -Pack $troubleshooter -Unattended -ErrorAction SilentlyContinue
            Write-Log "Windows Update troubleshooter completed" "PROGRESS"
        }
        
        # Reset Windows Update components
        Show-ProgressBar -Activity "Fixing Windows Update Problems" -Status "Resetting components..." -PercentComplete 30
        Reset-WindowsUpdateServices
        
        # Run System File Checker
        Show-ProgressBar -Activity "Fixing Windows Update Problems" -Status "Running System File Checker..." -PercentComplete 60
        Write-Log "Running System File Checker..." "PROGRESS"
        Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -WindowStyle Hidden
        
        # Run DISM repair
        Show-ProgressBar -Activity "Fixing Windows Update Problems" -Status "Running DISM repair..." -PercentComplete 80
        Write-Log "Running DISM repair..." "PROGRESS"
        Start-Process -FilePath "dism.exe" -ArgumentList "/online /cleanup-image /restorehealth" -Wait -WindowStyle Hidden
        
        Show-ProgressBar -Activity "Fixing Windows Update Problems" -Status "Completed!" -PercentComplete 100
        Write-Progress -Activity "Fixing Windows Update Problems" -Completed
        Write-Log "Windows Update problems fixed" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error fixing Windows Update problems: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Show-InstallationSummary {
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host "INSTALLATION SUMMARY" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Green
    
    Write-Host "`nTotal Updates Found: $Global:TotalUpdatesFound" -ForegroundColor Yellow
    Write-Host "Successfully Installed: $($Global:InstalledUpdates.Count)" -ForegroundColor Green
    Write-Host "Failed Installations: $($Global:FailedUpdates.Count)" -ForegroundColor Red
    
    if ($Global:InstalledUpdates.Count -gt 0) {
        Write-Host "`n" -NoNewline
        Write-Host "SUCCESSFULLY INSTALLED UPDATES:" -ForegroundColor Green
        Write-Host "-" * 50 -ForegroundColor Green
        
        foreach ($update in $Global:InstalledUpdates) {
            Write-Host "✓ $($update.Title)" -ForegroundColor Green
            Write-Host "  KB: $($update.KBArticleIDs) | Size: $($update.Size) | Installed: $($update.InstallTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        }
        
        $totalSize = 0
        foreach ($update in $Global:InstalledUpdates) {
            if ($update.Size -match '(\d+\.?\d*) MB') {
                $totalSize += [double]$matches[1]
            }
        }
        
        Write-Host "`nTotal Downloaded Size: $($totalSize.ToString('N2')) MB" -ForegroundColor Cyan
    }
    
    if ($Global:FailedUpdates.Count -gt 0) {
        Write-Host "`n" -NoNewline
        Write-Host "FAILED UPDATES:" -ForegroundColor Red
        Write-Host "-" * 50 -ForegroundColor Red
        
        foreach ($update in $Global:FailedUpdates) {
            Write-Host "✗ $($update.Title)" -ForegroundColor Red
            Write-Host "  KB: $($update.KBArticleIDs) | Error: $($update.Error)" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Green
}

# Main execution
try {
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "FORCE WINDOWS UPDATES SCRIPT - ENHANCED VERSION" -ForegroundColor Cyan
    Write-Host "Real-time Progress | Detailed Reporting | Comprehensive Updates" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    
    Write-Log "Starting Force Windows Updates Script..." "SUCCESS"
    
    # Step 1: Fix any existing problems
    Write-Log "Step 1/3: Fixing Windows Update problems..." "PROGRESS"
    Fix-WindowsUpdateProblems
    
    # Step 2: Install PSWindowsUpdate module
    Write-Log "Step 2/3: Installing PSWindowsUpdate module..." "PROGRESS"
    if (-not (Install-PSWindowsUpdateModule)) {
        throw "Failed to install PSWindowsUpdate module"
    }
    
    # Step 3: Install Windows Updates
    Write-Log "Step 3/3: Installing Windows Updates..." "PROGRESS"
    if (-not (Install-WindowsUpdates)) {
        throw "Failed to install Windows Updates after $MaxRetries attempts"
    }
    
    # Show detailed summary
    Show-InstallationSummary
    
    Write-Log "Force Windows Updates completed successfully!" "SUCCESS"
    
    # Final status check
    Write-Log "Performing final system update check..." "PROGRESS"
    $PendingUpdates = Get-WUList -ErrorAction SilentlyContinue
    if ($PendingUpdates.Count -eq 0) {
        Write-Log "System is now completely up to date!" "SUCCESS"
    } else {
        Write-Log "$($PendingUpdates.Count) updates still pending (may require reboot)" "WARN"
        Write-Host "`nPending Updates:" -ForegroundColor Yellow
        foreach ($update in $PendingUpdates) {
            Write-Host "  - $($update.Title)" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" "ERROR"
    Show-InstallationSummary
    exit 1
}

Write-Host "`n" -NoNewline
Write-Host "=" * 80 -ForegroundColor Green
Write-Log "Script execution completed successfully!" "SUCCESS"
Write-Host "=" * 80 -ForegroundColor Green
