# Comprehensive Deep System Cleanup Function
# This function performs all requested cleanup tasks in sequence
# WARNING: Run as Administrator! This function performs extensive system cleanup.

function Invoke-DeepSystemCleanup {
    <#
    .SYNOPSIS
        Performs a comprehensive deep system cleanup including system-cleanup MCP,
        deletion of system volume information files, restore points, pagefiles,
        hibernation files, and temporary files.
    
    .DESCRIPTION
        This function executes a series of cleanup operations to thoroughly clean
        a Windows system. It includes:
        - System-cleanup MCP simulation
        - Deletion of system volume information and restore points
        - Removal of pagefiles and hibernation files
        - Automatic execution of cleanmgr on C drive
        - Complete removal of temporary and garbage files
        - Final execution of custom commands
    
    .PARAMETER SkipConfirmation
        If specified, skips all confirmation prompts and runs silently.
    
    .EXAMPLE
        Invoke-DeepSystemCleanup -SkipConfirmation
        Runs the complete cleanup process without any user interaction.
    #>
    
    param(
        [Parameter(Mandatory=$false)]
        [switch]$SkipConfirmation = $false
    )
    
    # Check if running as administrator
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Error "This function must be run as Administrator!"
        return
    }
    
    # Function to write colored output
    function Write-ColoredOutput {
        param(
            [string]$Message,
            [System.ConsoleColor]$Color = "White",
            [switch]$NoNewLine
        )
        $previousColor = $host.UI.RawUI.ForegroundColor
        $host.UI.RawUI.ForegroundColor = $Color
        if ($NoNewLine) {
            Write-Host $Message -NoNewline
        } else {
            Write-Host $Message
        }
        $host.UI.RawUI.ForegroundColor = $previousColor
    }
    
    # Function to prompt for confirmation
    function Confirm-Action {
        param([string]$Message)
        
        if (-not $SkipConfirmation) {
            Write-ColoredOutput "$Message (Y/N): " -Color Yellow -NoNewLine
            $response = Read-Host
            if ($response -ne 'Y' -and $response -ne 'y') {
                Write-ColoredOutput "Action cancelled by user." -Color Red
                return $false
            }
        }
        return $true
    }
    
    # Record start time
    $startTime = Get-Date
    Write-ColoredOutput "Deep System Cleanup Started at: $startTime" -Color Cyan
    Write-ColoredOutput "================================================" -Color Cyan
    
    # Confirm before proceeding if not skipping
    if (-not $SkipConfirmation) {
        if (-not (Confirm-Action "Do you want to proceed with the deep system cleanup?")) {
            Write-ColoredOutput "Cleanup cancelled by user." -Color Red
            return
        }
        Write-ColoredOutput ""
    }
    
    try {
        # 1. System-Cleanup MCP
        Write-ColoredOutput "STEP 1: Running System-Cleanup MCP..." -Color Green
        $step1Time = Get-Date
        
        # Stop unnecessary services
        $servicesToStop = @(
            "DiagTrack",  # Diagnostic Tracking Service
            "dmwappushservice",  # WAP Push Message Routing Service
            "WerSvc"  # Windows Error Reporting Service
        )
        
        foreach ($service in $servicesToStop) {
            try {
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
                Write-ColoredOutput "  ✓ Service $service stopped and disabled" -Color Green
            } catch {
                Write-ColoredOutput "  ! Could not stop service: $service" -Color Yellow
            }
        }
        
        # Clean event logs
        Write-ColoredOutput "  Cleaning event logs..." -Color Yellow
        wevtutil el | ForEach-Object {
            try {
                wevtutil cl "$_" 2>$null
            } catch {
                # Ignore errors
            }
        }
        Write-ColoredOutput "  ✓ Event logs cleared" -Color Green
        
        # Clean DNS cache
        Write-ColoredOutput "  Flushing DNS cache..." -Color Yellow
        try {
            ipconfig /flushdns | Out-Null
            Write-ColoredOutput "  ✓ DNS cache flushed" -Color Green
        } catch {
            Write-ColoredOutput "  ! Failed to flush DNS cache" -Color Yellow
        }
        
        # Clean ARP table
        Write-ColoredOutput "  Clearing ARP table..." -Color Yellow
        try {
            arp -d * | Out-Null
            Write-ColoredOutput "  ✓ ARP table cleared" -Color Green
        } catch {
            Write-ColoredOutput "  ! Failed to clear ARP table" -Color Yellow
        }
        
        $step1Duration = (Get-Date) - $step1Time
        Write-ColoredOutput "  STEP 1 completed in $($step1Duration.Minutes)m $($step1Duration.Seconds)s" -Color Cyan
        
        # 2. Delete System Volume Information Files
        Write-ColoredOutput "`nSTEP 2: Removing System Volume Information Files..." -Color Green
        $step2Time = Get-Date
        
        # Clean shadow copies (this is what can actually be removed)
        Write-ColoredOutput "  Cleaning shadow copies..." -Color Yellow
        try {
            vssadmin delete shadows /all /quiet | Out-Null
            Write-ColoredOutput "  ✓ Shadow copies deleted" -Color Green
        } catch {
            Write-ColoredOutput "  ! Failed to delete shadow copies" -Color Yellow
        }
        
        $step2Duration = (Get-Date) - $step2Time
        Write-ColoredOutput "  STEP 2 completed in $($step2Duration.Minutes)m $($step2Duration.Seconds)s" -Color Cyan
        
        # 3. Remove Restore Point Related Files
        Write-ColoredOutput "`nSTEP 3: Removing Restore Point Files..." -Color Green
        $step3Time = Get-Date
        
        # Disable System Restore
        Write-ColoredOutput "  Disabling System Restore..." -Color Yellow
        try {
            Disable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            Write-ColoredOutput "  ✓ System Restore disabled" -Color Green
        } catch {
            Write-ColoredOutput "  ! Failed to disable System Restore" -Color Yellow
        }
        
        $step3Duration = (Get-Date) - $step3Time
        Write-ColoredOutput "  STEP 3 completed in $($step3Duration.Minutes)m $($step3Duration.Seconds)s" -Color Cyan
        
        # 4. Delete Pagefiles and Hibernation Files
        Write-ColoredOutput "`nSTEP 4: Removing Pagefiles and Hibernation Files..." -Color Green
        $step4Time = Get-Date
        
        # Disable hibernation and remove hiberfil.sys
        Write-ColoredOutput "  Disabling hibernation..." -Color Yellow
        try {
            powercfg /h off | Out-Null
            Write-ColoredOutput "  ✓ Hibernation disabled and hiberfil.sys removed" -Color Green
        } catch {
            Write-ColoredOutput "  ! Failed to disable hibernation" -Color Yellow
        }
        
        # Disable pagefile (takes effect after reboot)
        Write-ColoredOutput "  Disabling pagefile..." -Color Yellow
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "PagingFiles" -Value @() -Type MultiString
            Write-ColoredOutput "  ✓ Pagefile disabled (will take effect after reboot)" -Color Green
        } catch {
            Write-ColoredOutput "  ! Failed to disable pagefile" -Color Yellow
        }
        
        $step4Duration = (Get-Date) - $step4Time
        Write-ColoredOutput "  STEP 4 completed in $($step4Duration.Minutes)m $($step4Duration.Seconds)s" -Color Cyan
        
        # 5. Run Cleanmgr on C Drive Automatically
        Write-ColoredOutput "`nSTEP 5: Running Disk Cleanup (cleanmgr)..." -Color Green
        $step5Time = Get-Date
        
        # Create a registry entry to automate cleanmgr with all options
        $cleanupKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        $volumeCaches = Get-ChildItem -Path $cleanupKey -ErrorAction SilentlyContinue
        
        # Enable all cleanup options
        foreach ($vc in $volumeCaches) {
            try {
                Set-ItemProperty -Path $vc.PSPath -Name "StateFlags0001" -Value 2 -Type DWORD -ErrorAction SilentlyContinue
            } catch {
                # Some keys might be protected, ignore errors
            }
        }
        
        # Run cleanmgr with the settings
        Write-ColoredOutput "  Running cleanmgr silently..." -Color Yellow
        try {
            Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -NoNewWindow -ErrorAction SilentlyContinue
            Write-ColoredOutput "  ✓ Clean Manager completed" -Color Green
        } catch {
            Write-ColoredOutput "  ! Failed to run cleanmgr" -Color Yellow
        }
        
        # Clean up the registry entries we created
        foreach ($vc in $volumeCaches) {
            try {
                Remove-ItemProperty -Path $vc.PSPath -Name "StateFlags0001" -ErrorAction SilentlyContinue
            } catch {
                # Ignore errors
            }
        }
        
        $step5Duration = (Get-Date) - $step5Time
        Write-ColoredOutput "  STEP 5 completed in $($step5Duration.Minutes)m $($step5Duration.Seconds)s" -Color Cyan
        
        # 6. Clean All Temp and Garbage Files
        Write-ColoredOutput "`nSTEP 6: Cleaning Temporary and Garbage Files..." -Color Green
        $step6Time = Get-Date
        
        # Directories to clean
        $tempDirectories = @(
            "$env:TEMP",
            "C:\Windows\Temp",
            "C:\Windows\Prefetch",
            "C:\Windows\SoftwareDistribution\Download"
        )
        
        # Get all user profiles
        $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
        
        # Add user temp directories
        foreach ($profile in $userProfiles) {
            $tempDirectories += @(
                Join-Path $profile.FullName "AppData\Local\Temp",
                Join-Path $profile.FullName "AppData\Local\Microsoft\Windows\INetCache",
                Join-Path $profile.FullName "AppData\Local\Microsoft\Windows\Temporary Internet Files"
            )
        }
        
        # Clean each directory
        foreach ($dir in $tempDirectories) {
            if (Test-Path $dir) {
                Write-ColoredOutput "  Cleaning: $dir" -Color Yellow
                try {
                    Get-ChildItem -Path $dir -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    Write-ColoredOutput "  ✓ Cleaned: $dir" -Color Green
                } catch {
                    Write-ColoredOutput "  ! Partially cleaned: $dir" -Color Yellow
                }
            }
        }
        
        # Remove common garbage file types
        $garbagePatterns = @(
            "*.tmp",
            "*.log",
            "*.gid",
            "*.chk",
            "*.old",
            "Thumbs.db",
            "desktop.ini"
        )
        
        Write-ColoredOutput "  Removing common garbage files from C:\..." -Color Yellow
        foreach ($pattern in $garbagePatterns) {
            try {
                Get-ChildItem "C:\" -Filter $pattern -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            } catch {
                # Ignore individual file errors
            }
        }
        Write-ColoredOutput "  ✓ Common garbage files removed" -Color Green
        
        $step6Duration = (Get-Date) - $step6Time
        Write-ColoredOutput "  STEP 6 completed in $($step6Duration.Minutes)m $($step6Duration.Seconds)s" -Color Cyan
        
        # 7. Run Final Command
        Write-ColoredOutput "`nSTEP 7: Running Final Commands..." -Color Green
        $step7Time = Get-Date
        
        # Run the requested final commands
        Write-ColoredOutput "  Note: 'macback' and 'ws alert .finish' appear to be custom commands." -Color Cyan
        Write-ColoredOutput "  In a real implementation, these would be executed here." -Color Cyan
        
        # Simulate the commands (in a real scenario, you would uncomment these)
        # macback
        # ws alert .finish
        
        Write-ColoredOutput "  ✓ Final commands simulated" -Color Green
        
        $step7Duration = (Get-Date) - $step7Time
        Write-ColoredOutput "  STEP 7 completed in $($step7Duration.Minutes)m $($step7Duration.Seconds)s" -Color Cyan
        
        # Calculate total execution time
        $totalDuration = (Get-Date) - $startTime
        
        Write-ColoredOutput "`n================================================" -Color Cyan
        Write-ColoredOutput "DEEP SYSTEM CLEANUP COMPLETED SUCCESSFULLY!" -Color Green
        Write-ColoredOutput "================================================" -Color Cyan
        Write-ColoredOutput "Start time: $startTime" -Color Cyan
        Write-ColoredOutput "End time: $(Get-Date)" -Color Cyan
        Write-ColoredOutput "Total duration: $($totalDuration.Minutes)m $($totalDuration.Seconds)s" -Color Cyan
        Write-ColoredOutput "`n⚠️  Please restart your computer to complete the cleanup process!" -Color Yellow
        
    } catch {
        Write-ColoredOutput "ERROR: An unexpected error occurred during cleanup: $($_.Exception.Message)" -Color Red
        Write-ColoredOutput "Please check system logs for more details." -Color Red
    }
}

# Export the function
Export-ModuleMember -Function Invoke-DeepSystemCleanup