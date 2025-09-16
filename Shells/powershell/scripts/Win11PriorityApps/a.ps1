# Enhanced Real-Time Process Manager with Priority Control
# This script makes REAL changes to system processes that persist in Task Manager

param(
    [string]$PSToolsPath = "F:\backup\windowsapps\installed\pstools",
    [string]$ConfigFile = "$PSScriptRoot\priority-config.json"
)

# Ensure running as Administrator for priority changes
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "WARNING: This script requires Administrator privileges to change process priorities!" -ForegroundColor Yellow
    Write-Host "Right-click PowerShell and 'Run as Administrator'" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

# Global variables
$priorityMap = @{}
$lastUpdateTime = Get-Date
$totalCPU = 0
$totalRAM = 0

# Load saved priority configurations
function Load-PriorityConfig {
    if (Test-Path $ConfigFile) {
        try {
            $json = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            foreach ($entry in $json.PSObject.Properties) {
                $priorityMap[$entry.Name] = $entry.Value
            }
            Write-Host "[OK] Loaded priority configuration" -ForegroundColor Green
        } catch {
            Write-Host "[WARN] Could not load priority config: $_" -ForegroundColor Yellow
        }
    }
}

# Save priority configuration
function Save-PriorityConfig {
    try {
        $priorityMap | ConvertTo-Json -Depth 1 | Set-Content -Encoding UTF8 $ConfigFile
        Write-Host "[SAVED] Priority configuration saved" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to save priority config: $_" -ForegroundColor Red
    }
}

# Calculate CPU and RAM percentages
function Get-SystemStats {
    $totalCPUTime = 0
    $totalRAMUsage = 0
    $processCount = 0
    
    try {
        Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | ForEach-Object {
            $totalCPUTime += if ($_.CPU) { $_.CPU } else { 0 }
            $totalRAMUsage += $_.WorkingSet64 / 1MB
            $processCount++
        }
        
        # Get total system RAM
        $totalSystemRAM = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB
        $ramPercentage = ($totalRAMUsage / $totalSystemRAM) * 100
        
        return @{
            TotalCPUTime = $totalCPUTime
            TotalRAMUsage = $totalRAMUsage
            RAMPercentage = $ramPercentage
            ProcessCount = $processCount
            TotalSystemRAM = $totalSystemRAM
        }
    } catch {
        Write-Host "[ERROR] Failed to get system stats: $_" -ForegroundColor Red
        return @{
            TotalCPUTime = 0
            TotalRAMUsage = 0
            RAMPercentage = 0
            ProcessCount = 0
            TotalSystemRAM = 1
        }
    }
}

# Enhanced process display with real-time CPU/RAM percentages
function Show-EnhancedProcesses {
    Clear-Host
    
    # Header
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "                    REAL-TIME SYSTEM MONITOR WITH PRIORITY CONTROL             " -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    # System stats
    $stats = Get-SystemStats
    try {
        $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $uptimeStr = "$($uptime.Days) days, $($uptime.Hours):$($uptime.Minutes.ToString('00')):$($uptime.Seconds.ToString('00'))"
    } catch {
        $uptimeStr = "Unable to calculate"
    }
    
    Write-Host "`nSYSTEM OVERVIEW:" -ForegroundColor Yellow
    Write-Host "   Total RAM Usage: $($stats.RAMPercentage.ToString('F1'))% ($($stats.TotalRAMUsage.ToString('F1')) MB / $($stats.TotalSystemRAM.ToString('F0')) MB)" -ForegroundColor White
    Write-Host "   Running Processes: $($stats.ProcessCount)" -ForegroundColor White
    Write-Host "   System Uptime: $uptimeStr" -ForegroundColor White
    Write-Host "   Last Update: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
    
    Write-Host "`nRUNNING APPLICATIONS (with Real Priority Control):" -ForegroundColor Cyan
    Write-Host "=" * 120 -ForegroundColor Gray
    
    # Header
    $header = "{0,-25} {1,-8} {2,-12} {3,-15} {4,-15} {5,-12} {6}" -f "PROCESS", "PID", "CPU (sec)", "RAM %", "RAM (MB)", "PRIORITY", "STATUS"
    Write-Host $header -ForegroundColor Yellow
    Write-Host "=" * 120 -ForegroundColor Gray
    
    # Get all processes with windows
    try {
        $processes = Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | Sort-Object CPU -Descending
        
        foreach ($process in $processes) {
            try {
                # Calculate RAM percentage
                $ramMB = $process.WorkingSet64 / 1MB
                $ramPercent = ($ramMB / $stats.TotalSystemRAM) * 100
                
                # Get CPU time
                $cpuTime = if ($process.CPU) { $process.CPU.ToString('F2') } else { "0.00" }
                
                # Priority color coding
                $priorityColor = switch ($process.PriorityClass) {
                    "RealTime" { "Red" }
                    "High" { "Magenta" }
                    "AboveNormal" { "Yellow" }
                    "Normal" { "Green" }
                    "BelowNormal" { "Cyan" }
                    "Idle" { "Gray" }
                    default { "White" }
                }
                
                # Status indicator
                $status = if ($priorityMap.ContainsKey($process.ProcessName)) { "[MANAGED]" } else { "[SYSTEM]" }
                
                $line = "{0,-25} {1,-8} {2,-12} {3,-6}{4,-9} {5,-15} {6,-12} {7}" -f `
                    $process.ProcessName.Substring(0, [Math]::Min(24, $process.ProcessName.Length)), `
                    $process.Id, `
                    $cpuTime, `
                    $ramPercent.ToString('F1'), "%", `
                    $ramMB.ToString('F1'), `
                    $process.PriorityClass, `
                    $status
                
                Write-Host $line -ForegroundColor $priorityColor
                
            } catch {
                # Skip processes we can't access
                continue
            }
        }
    } catch {
        Write-Host "[ERROR] Failed to enumerate processes: $_" -ForegroundColor Red
    }
    
    Write-Host "=" * 120 -ForegroundColor Gray
}

# Set process priority with real system changes
function Set-ProcessPriorityReal {
    param(
        [string]$ProcessName,
        [string]$Priority
    )
    
    $validPriorities = @("Idle", "BelowNormal", "Normal", "AboveNormal", "High", "RealTime")
    
    if ($Priority -notin $validPriorities) {
        Write-Host "[ERROR] Invalid priority! Use: $($validPriorities -join ', ')" -ForegroundColor Red
        return $false
    }
    
    try {
        # Get all processes with this name
        $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        
        if (-not $processes) {
            Write-Host "[ERROR] Process '$ProcessName' not found!" -ForegroundColor Red
            return $false
        }
        
        $successCount = 0
        $totalCount = $processes.Count
        
        foreach ($proc in $processes) {
            try {
                $proc.PriorityClass = $Priority
                $successCount++
                Write-Host "[OK] Set $($proc.ProcessName) (PID: $($proc.Id)) to $Priority priority" -ForegroundColor Green
            } catch {
                Write-Host "[WARN] Could not set priority for PID $($proc.Id): $_" -ForegroundColor Yellow
            }
        }
        
        if ($successCount -gt 0) {
            # Save to config for future sessions
            $priorityMap[$ProcessName] = $Priority
            Save-PriorityConfig
            Write-Host "[SUCCESS] Successfully changed priority for $successCount/$totalCount instances of $ProcessName" -ForegroundColor Green
            Write-Host "[SAVED] Priority saved for future sessions" -ForegroundColor Blue
        }
        
        return $successCount -gt 0
        
    } catch {
        Write-Host "[ERROR] Failed to set priority: $_" -ForegroundColor Red
        return $false
    }
}

# Apply saved priorities on startup
function Apply-SavedPriorities {
    Write-Host "`nApplying saved priority configurations..." -ForegroundColor Yellow
    
    $applied = 0
    foreach ($processName in $priorityMap.Keys) {
        $priority = $priorityMap[$processName]
        try {
            $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
            
            if ($processes) {
                foreach ($proc in $processes) {
                    try {
                        $proc.PriorityClass = $priority
                        $applied++
                    } catch {
                        # Skip if we can't set priority
                    }
                }
            }
        } catch {
            # Skip if process not found
        }
    }
    
    if ($applied -gt 0) {
        Write-Host "[OK] Applied saved priorities to $applied processes" -ForegroundColor Green
    }
}

# Interactive menu
function Show-InteractiveMenu {
    Write-Host "`n" -NoNewline
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host "                             CONTROL MENU                              " -ForegroundColor Cyan
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host "  1. Set Process Priority (REAL system change)                        " -ForegroundColor White
    Write-Host "  2. Remove Process from Management                                    " -ForegroundColor White
    Write-Host "  3. Launch App with Custom Priority (PsExec)                         " -ForegroundColor White
    Write-Host "  4. Suspend/Resume Process (PsSuspend)                               " -ForegroundColor White
    Write-Host "  5. Kill Process (pskill)                                            " -ForegroundColor White
    Write-Host "  6. Refresh Display                                                  " -ForegroundColor White
    Write-Host "  7. Export Current Config                                            " -ForegroundColor White
    Write-Host "  Q. Quit                                                             " -ForegroundColor White
    Write-Host "========================================================================" -ForegroundColor Cyan
    
    $choice = Read-Host "`nEnter your choice"
    return $choice.ToUpper()
}

# Interactive priority setting
function Interactive-SetPriority {
    Write-Host "`nSET PROCESS PRIORITY" -ForegroundColor Yellow
    Write-Host "Available processes:" -ForegroundColor Cyan
    
    try {
        $processes = Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | Sort-Object ProcessName
        for ($i = 0; $i -lt $processes.Count; $i++) {
            Write-Host "  $($i+1). $($processes[$i].ProcessName)" -ForegroundColor White
        }
        
        $processChoice = Read-Host "`nEnter process name or number"
        
        # Handle numeric selection
        if ($processChoice -match '^\d+$') {
            $index = [int]$processChoice - 1
            if ($index -ge 0 -and $index -lt $processes.Count) {
                $processName = $processes[$index].ProcessName
            } else {
                Write-Host "[ERROR] Invalid number!" -ForegroundColor Red
                return
            }
        } else {
            $processName = $processChoice
        }
        
        Write-Host "`nAvailable Priorities:" -ForegroundColor Cyan
        Write-Host "  1. Idle        (Lowest - runs when system idle)" -ForegroundColor Gray
        Write-Host "  2. BelowNormal (Low priority)" -ForegroundColor Cyan  
        Write-Host "  3. Normal      (Standard priority)" -ForegroundColor Green
        Write-Host "  4. AboveNormal (Higher than normal)" -ForegroundColor Yellow
        Write-Host "  5. High        (High priority - use carefully!)" -ForegroundColor Magenta
        Write-Host "  6. RealTime    (Maximum - DANGEROUS!)" -ForegroundColor Red
        
        $priorityChoice = Read-Host "`nSelect priority (1-6)"
        
        $priorities = @("", "Idle", "BelowNormal", "Normal", "AboveNormal", "High", "RealTime")
        
        if ($priorityChoice -ge 1 -and $priorityChoice -le 6) {
            $priority = $priorities[[int]$priorityChoice]
            
            if ($priority -eq "RealTime") {
                Write-Host "`nWARNING: RealTime priority can make your system unresponsive!" -ForegroundColor Red
                $confirm = Read-Host "Are you absolutely sure? (type 'YES' to confirm)"
                if ($confirm -ne "YES") {
                    Write-Host "[CANCELLED] Operation cancelled" -ForegroundColor Yellow
                    return
                }
            }
            
            Set-ProcessPriorityReal -ProcessName $processName -Priority $priority
        } else {
            Write-Host "[ERROR] Invalid priority selection!" -ForegroundColor Red
        }
    } catch {
        Write-Host "[ERROR] Failed to get process list: $_" -ForegroundColor Red
    }
}

# Main execution
function Start-EnhancedMonitor {
    Write-Host "Starting Enhanced Process Monitor..." -ForegroundColor Green
    
    # Load configuration
    Load-PriorityConfig
    
    # Apply saved priorities
    Apply-SavedPriorities
    
    # Main loop
    while ($true) {
        Show-EnhancedProcesses
        
        $choice = Show-InteractiveMenu
        
        switch ($choice) {
            "1" { Interactive-SetPriority }
            "2" { 
                $processName = Read-Host "Enter process name to remove from management"
                if ($priorityMap.ContainsKey($processName)) {
                    $priorityMap.Remove($processName)
                    Save-PriorityConfig
                    Write-Host "[OK] Removed $processName from management" -ForegroundColor Green
                } else {
                    Write-Host "[ERROR] Process not found in management list" -ForegroundColor Red
                }
            }
            "3" { 
                if (Test-Path $PSToolsPath) {
                    $exe = Read-Host "Enter full path to EXE"
                    $priority = Read-Host "Enter Priority (Idle, BelowNormal, Normal, AboveNormal, High, RealTime)"
                    $priorityArg = "-" + $priority.ToLower()
                    $command = "$PSToolsPath\PsExec64.exe"
                    $arguments = @($priorityArg, "-d", "`"$exe`"")
                    & $command $arguments
                } else {
                    Write-Host "[ERROR] PsTools not found at: $PSToolsPath" -ForegroundColor Red
                }
            }
            "4" { 
                if (Test-Path $PSToolsPath) {
                    $target = Read-Host "Enter Process Name or PID"
                    $mode = Read-Host "Type 'suspend' or 'resume'"
                    & "$PSToolsPath\PSSuspend64.exe" $mode $target
                } else {
                    Write-Host "[ERROR] PsTools not found at: $PSToolsPath" -ForegroundColor Red
                }
            }
            "5" { 
                if (Test-Path $PSToolsPath) {
                    $target = Read-Host "Enter Process Name or PID to kill"
                    $confirm = Read-Host "Are you sure you want to kill $target? (y/N)"
                    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                        & "$PSToolsPath\pskill64.exe" $target
                    }
                } else {
                    Write-Host "[ERROR] PsTools not found at: $PSToolsPath" -ForegroundColor Red
                }
            }
            "6" { 
                Write-Host "Refreshing..." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "7" {
                $exportPath = Read-Host "Enter export path (default: priority-export.json)"
                if ([string]::IsNullOrEmpty($exportPath)) { $exportPath = "priority-export.json" }
                try {
                    $priorityMap | ConvertTo-Json -Depth 1 | Set-Content -Encoding UTF8 $exportPath
                    Write-Host "[OK] Configuration exported to $exportPath" -ForegroundColor Green
                } catch {
                    Write-Host "[ERROR] Failed to export: $_" -ForegroundColor Red
                }
            }
            "Q" { 
                Write-Host "Goodbye!" -ForegroundColor Green
                exit 
            }
            default { 
                Write-Host "[ERROR] Invalid choice!" -ForegroundColor Red 
                Start-Sleep -Seconds 1
            }
        }
        
        Write-Host "`nPress any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Start the enhanced monitor
Start-EnhancedMonitor
