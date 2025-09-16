function Set-PersistentPowerPlan {
    [CmdletBinding()]
    param(
        [string]$PlanName = "Ultimate Max Performance",
        [string]$PlanDescription = "Maximum performance settings for ultimate speed"
    )
    
    Write-Host "Starting persistent power plan configuration..." -ForegroundColor Green
    
    try {
        # Ensure we're running as Administrator
        if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Error "This function requires Administrator privileges. Please run PowerShell as Administrator."
            return
        }
        
        # Step 1: Remove any existing power plans with the same name
        Write-Host "Cleaning up existing power plans..." -ForegroundColor Yellow
        $existingPlans = powercfg /list | Select-String -Pattern $PlanName
        foreach ($plan in $existingPlans) {
            $existingGuid = ($plan.ToString() -split '\s+')[3]
            if ($existingGuid -and $existingGuid -ne "381b4222-f694-41f0-9685-ff5bb260df2e") {
                Write-Host "Removing existing power plan: $existingGuid" -ForegroundColor Yellow
                powercfg /delete $existingGuid
            }
        }
        
        # Step 2: Create new Ultimate Performance power plan
        Write-Host "Creating new Ultimate Performance power plan..." -ForegroundColor Yellow
        $planOutput = powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        $planGuid = ($planOutput | Select-String -Pattern '\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b').Matches.Value
        
        if (-not $planGuid) {
            throw "Failed to create power plan. Could not extract GUID."
        }
        
        Write-Host "Created power plan with GUID: $planGuid" -ForegroundColor Green
        
        # Step 3: Rename the power plan
        powercfg /changename $planGuid $PlanName $PlanDescription
        
        # Step 4: Configure all power settings for maximum performance
        Write-Host "Configuring maximum performance settings..." -ForegroundColor Yellow
        
        # Define all settings to apply (SubGroup GUID, Setting GUID, Value)
        $powerSettings = @(
            # Hard disk turn off time - Never (0)
            @('0012ee47-9041-4b5d-9b77-535fba8b1442', '6738e2c4-e8a5-4a42-b16a-e040e769756e', '0'),
            
            # Wireless Adapter Settings - Maximum Performance
            @('19cbb8fa-5279-450e-9fac-8a3d5fedd0c1', '12bbebe6-58d6-4636-95bb-3217ef867c1a', '0'),
            
            # Sleep settings - Never sleep
            @('238c9fa8-0aad-41ed-83f4-97be242c8f20', '29f6c1db-86da-48c5-9fdb-f2b67b1f44da', '0'), # Sleep after
            @('238c9fa8-0aad-41ed-83f4-97be242c8f20', '94ac6d29-73ce-41a6-809f-6363ba21b47e', '0'), # Hibernate after
            
            # USB selective suspend - Disabled
            @('2a737441-1930-4402-8d77-b2bebba308a3', '48e6b7a6-50f5-4782-a5d4-53bb8f07e226', '0'),
            
            # Lid close action - Do nothing
            @('4f971e89-eebd-4455-a8de-9e59040e7347', '5ca83367-6e45-459f-a27b-476b1d01c936', '0'),
            
            # Power button action - Shutdown
            @('4f971e89-eebd-4455-a8de-9e59040e7347', '7648efa3-dd9c-4e3e-b566-50f929386280', '3'),
            
            # Processor power management - Maximum performance
            @('54533251-82be-4824-96c1-47b60b740d00', '893dee8e-2bef-41e0-89c6-b55d0929964c', '100'), # Min processor state
            @('54533251-82be-4824-96c1-47b60b740d00', 'bc5038f7-23e0-4960-96da-33abaf5935ec', '100'), # Max processor state
            
            # Display turn off time - Never (0)
            @('7516b95f-f776-4464-8c53-06167f40cc99', '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e', '0'),
            
            # PCI Express Link State Power Management - Off
            @('501a4d13-42af-4429-9fd1-a8218c268e20', 'ee12f906-d277-404b-b6da-e5fa1a576df5', '0')
        )
        
        # Apply all settings for both AC and DC power
        foreach ($setting in $powerSettings) {
            $subGroup = $setting[0]
            $settingGuid = $setting[1]
            $value = $setting[2]
            
            # Set both AC and DC values
            powercfg /setacvalueindex $planGuid $subGroup $settingGuid $value
            powercfg /setdcvalueindex $planGuid $subGroup $settingGuid $value
        }
        
        # Step 5: Set the power plan as active
        Write-Host "Activating new power plan..." -ForegroundColor Yellow
        powercfg /setactive $planGuid
        
        # Step 6: CRITICAL - Set this as the default power scheme in multiple registry locations
        Write-Host "Setting power plan as system default in registry..." -ForegroundColor Yellow
        
        # Registry paths for power scheme persistence
        $registryPaths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\Default\PowerSchemes",
            "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes", 
            "HKLM:\SYSTEM\CurrentControlSet\Control\Power\State\ActivePowerScheme",
            "HKCU:\Control Panel\PowerCfg"
        )
        
        foreach ($regPath in $registryPaths) {
            try {
                if (Test-Path $regPath) {
                    Set-ItemProperty -Path $regPath -Name "ActivePowerScheme" -Value $planGuid -Force -ErrorAction SilentlyContinue
                } else {
                    # Create the registry path if it doesn't exist
                    New-Item -Path $regPath -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $regPath -Name "ActivePowerScheme" -Value $planGuid -Force -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Host "Could not set registry path: $regPath" -ForegroundColor Yellow
            }
        }
        
        # Step 7: Use powercfg to set as default for all power states
        Write-Host "Setting as default power scheme for all power states..." -ForegroundColor Yellow
        
        # Set as default for AC and DC
        powercfg /setdcvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0
        powercfg /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0
        
        # Step 8: Create a scheduled task to reapply power plan on startup
        Write-Host "Creating startup task to ensure persistence..." -ForegroundColor Yellow
        
        $taskName = "RestoreUltimatePerformancePlan"
        $taskAction = New-ScheduledTaskAction -Execute "powercfg.exe" -Argument "/setactive $planGuid"
        $taskTrigger = New-ScheduledTaskTrigger -AtStartup
        $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        # Remove existing task if it exists
        try {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        } catch {}
        
        # Create new scheduled task
        Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force
        
        # Step 9: Create a PowerShell profile script for additional persistence
        Write-Host "Creating PowerShell profile persistence..." -ForegroundColor Yellow
        
        $profileScript = @"
# Auto-restore Ultimate Performance power plan
if ((Get-WmiObject -Class Win32_PowerPlan -Filter "IsActive=True").ElementName -ne "Ultimate Max Performance") {
    powercfg /setactive $planGuid
}
"@
        
        # Add to all users profile
        $profilePaths = @(
            "$env:WINDIR\System32\WindowsPowerShell\v1.0\profile.ps1",
            "$env:USERPROFILE\Documents\WindowsPowerShell\profile.ps1"
        )
        
        foreach ($profilePath in $profilePaths) {
            try {
                $profileDir = Split-Path $profilePath -Parent
                if (!(Test-Path $profileDir)) {
                    New-Item -ItemType Directory -Path $profileDir -Force
                }
                Add-Content -Path $profilePath -Value $profileScript -Force
            } catch {
                Write-Host "Could not modify profile: $profilePath" -ForegroundColor Yellow
            }
        }
        
        # Step 10: Final activation and verification
        Write-Host "Final activation and verification..." -ForegroundColor Yellow
        powercfg /setactive $planGuid
        
        # Verify the configuration
        $activePlan = powercfg /getactivescheme
        if ($activePlan -like "*$planGuid*") {
            Write-Host "✓ Power plan is active" -ForegroundColor Green
        } else {
            Write-Warning "Power plan may not be properly activated"
        }
        
        # Display current power plan
        Write-Host "Current active power plan:" -ForegroundColor Cyan
        powercfg /getactivescheme
        
        # Final verification query
        Write-Host "Querying power button and lid settings..." -ForegroundColor Yellow
        powercfg /query SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347
        
        Write-Host "Power plan configuration completed successfully!" -ForegroundColor Green
        Write-Host "The following persistence mechanisms have been applied:" -ForegroundColor Green
        Write-Host "1. Registry entries for default power scheme" -ForegroundColor Green
        Write-Host "2. Scheduled task to restore on startup" -ForegroundColor Green
        Write-Host "3. PowerShell profile auto-restore" -ForegroundColor Green
        Write-Host "4. System-level power configuration" -ForegroundColor Green
        
        return $planGuid
        
    } catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
        return $null
    }
}

# Function to verify power plan after reboot
function Test-PowerPlanPersistence {
    Write-Host "Checking power plan persistence..." -ForegroundColor Yellow
    
    # Check active power plan
    $activePlan = powercfg /getactivescheme
    Write-Host "Current active power plan: $activePlan" -ForegroundColor Cyan
    
    # Check if our plan exists
    $allPlans = powercfg /list
    $ultimatePlan = $allPlans | Select-String -Pattern "Ultimate Max Performance"
    
    if ($ultimatePlan) {
        Write-Host "✓ Ultimate Max Performance plan exists" -ForegroundColor Green
        $planGuid = ($ultimatePlan.ToString() -split '\s+')[3]
        
        # Check if it's active
        if ($activePlan -like "*$planGuid*") {
            Write-Host "✓ Ultimate Max Performance plan is ACTIVE" -ForegroundColor Green
        } else {
            Write-Host "⚠ Ultimate Max Performance plan exists but is NOT active" -ForegroundColor Yellow
            Write-Host "Attempting to reactivate..." -ForegroundColor Yellow
            powercfg /setactive $planGuid
        }
    } else {
        Write-Host "✗ Ultimate Max Performance plan does not exist" -ForegroundColor Red
        Write-Host "You may need to run Set-PersistentPowerPlan again" -ForegroundColor Red
    }
    
    # Check specific settings
    Write-Host "Checking power button and lid settings..." -ForegroundColor Yellow
    powercfg /query SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347
    
    # Check scheduled task
    $task = Get-ScheduledTask -TaskName "RestoreUltimatePerformancePlan" -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "✓ Scheduled task exists" -ForegroundColor Green
    } else {
        Write-Host "✗ Scheduled task missing" -ForegroundColor Red
    }
    
    # List all power plans
    Write-Host "All available power plans:" -ForegroundColor Cyan
    powercfg /list
}

# Function to manually restore power plan (in case it gets reset)
function Restore-UltimatePerformancePlan {
    Write-Host "Searching for Ultimate Max Performance plan..." -ForegroundColor Yellow
    
    $allPlans = powercfg /list
    $ultimatePlan = $allPlans | Select-String -Pattern "Ultimate Max Performance"
    
    if ($ultimatePlan) {
        $planGuid = ($ultimatePlan.ToString() -split '\s+')[3]
        Write-Host "Found Ultimate Max Performance plan: $planGuid" -ForegroundColor Green
        Write-Host "Activating..." -ForegroundColor Yellow
        powercfg /setactive $planGuid
        
        # Verify activation
        $activePlan = powercfg /getactivescheme
        if ($activePlan -like "*$planGuid*") {
            Write-Host "✓ Successfully activated Ultimate Max Performance plan" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to activate Ultimate Max Performance plan" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Ultimate Max Performance plan not found. Please run Set-PersistentPowerPlan first." -ForegroundColor Red
    }
}

# Usage examples:
# Set-PersistentPowerPlan
# Test-PowerPlanPersistence
# Restore-UltimatePerformancePlan
