#Requires -RunAsAdministrator
################################################################################
# COMPLETE CLEANUP AND RESET SCRIPT
# Purpose: Remove ALL traces of previous installations and reset to clean state
# This script will undo EVERYTHING that SETUP-EVERYTHING.ps1 did
################################################################################

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Red
Write-Host "COMPLETE CLEANUP - REDO ALL" -ForegroundColor Red
Write-Host "This will remove ALL installations and reset environment" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Red

# Confirmation
Write-Host "⚠️  WARNING: This will remove:" -ForegroundColor Yellow
Write-Host "   • F:\DevKit folder and all contents" -ForegroundColor Yellow
Write-Host "   • C:\Program Files\dotnet (if installed by our script)" -ForegroundColor Yellow
Write-Host "   • All PATH entries related to DevKit" -ForegroundColor Yellow
Write-Host "   • All environment variables (DOTNET_ROOT, etc.)" -ForegroundColor Yellow
Write-Host "   • PowerShell profiles modifications" -ForegroundColor Yellow
Write-Host "   • Windows Registry entries for .NET" -ForegroundColor Yellow
Write-Host "`n"

$confirmation = Read-Host "Are you ABSOLUTELY SURE? Type 'YES' to continue"
if ($confirmation -ne "YES") {
    Write-Host "`n❌ Cleanup cancelled by user" -ForegroundColor Red
    exit
}

Write-Host "`n🔥 Starting cleanup process...`n" -ForegroundColor Cyan

# Helper function to log and display
function Write-Log {
    param($Message, $Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

################################################################################
# 1. REMOVE F:\DevKit FOLDER AND ALL CONTENTS
################################################################################
Write-Log "`n[1/8] Removing F:\DevKit folder..." "Yellow"

$DevKitPath = "F:\DevKit"

if (Test-Path $DevKitPath) {
    try {
        Write-Log "  📦 Removing entire F:\DevKit directory..." "Cyan"
        
        # Force remove all files and subdirectories
        Remove-Item -Path $DevKitPath -Recurse -Force -ErrorAction Stop
        
        Write-Log "  ✅ F:\DevKit completely removed" "Green"
    } catch {
        Write-Log "  ⚠️  Error removing F:\DevKit: $_" "Yellow"
        Write-Log "  Trying alternative removal method..." "Cyan"
        
        try {
            # Try with robocopy (more aggressive)
            $emptyDir = "$env:TEMP\empty_dir_$(Get-Random)"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
            robocopy $emptyDir $DevKitPath /MIR /R:0 /W:0 /NFL /NDL /NJH /NJS /NC /NS | Out-Null
            Remove-Item $emptyDir -Force -ErrorAction SilentlyContinue
            Remove-Item $DevKitPath -Force -ErrorAction SilentlyContinue
            Write-Log "  ✅ F:\DevKit removed using alternative method" "Green"
        } catch {
            Write-Log "  ❌ Could not remove F:\DevKit. Please remove manually and rerun script." "Red"
        }
    }
} else {
    Write-Log "  ✅ F:\DevKit does not exist (already clean)" "Green"
}

################################################################################
# 2. REMOVE C:\Program Files\dotnet (IF INSTALLED BY OUR SCRIPT)
################################################################################
Write-Log "`n[2/8] Cleaning C:\Program Files\dotnet..." "Yellow"

$systemDotnetPath = "C:\Program Files\dotnet"

# Check if it was installed by our script (contains SDK 9.0.305 or our marker)
if (Test-Path $systemDotnetPath) {
    $ourInstallation = $false
    
    # Check for SDKs we installed
    if (Test-Path "$systemDotnetPath\sdk\9.0.305") {
        $ourInstallation = $true
    }
    if (Test-Path "$systemDotnetPath\sdk\9.0.100") {
        $ourInstallation = $true
    }
    
    if ($ourInstallation) {
        Write-Log "  ⚠️  Found .NET installation that appears to be from our script" "Yellow"
        $removeSystemDotnet = Read-Host "  Remove C:\Program Files\dotnet? (YES to remove, NO to keep)"
        
        if ($removeSystemDotnet -eq "YES") {
            try {
                Write-Log "  📦 Removing C:\Program Files\dotnet..." "Cyan"
                Remove-Item -Path $systemDotnetPath -Recurse -Force -ErrorAction Stop
                Write-Log "  ✅ System .NET removed" "Green"
            } catch {
                Write-Log "  ⚠️  Could not remove system .NET: $_" "Yellow"
                Write-Log "  You may need to remove it manually" "Yellow"
            }
        } else {
            Write-Log "  ℹ️  Keeping C:\Program Files\dotnet" "Gray"
        }
    } else {
        Write-Log "  ℹ️  C:\Program Files\dotnet exists but doesn't appear to be from our script" "Gray"
        Write-Log "  ℹ️  Leaving it untouched" "Gray"
    }
} else {
    Write-Log "  ✅ C:\Program Files\dotnet does not exist (already clean)" "Green"
}

################################################################################
# 3. REMOVE ALL DEVKIT ENTRIES FROM MACHINE PATH
################################################################################
Write-Log "`n[3/8] Cleaning Machine PATH..." "Yellow"

try {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    
    if ($machinePath) {
        # Remove all entries containing "DevKit" or pointing to F:\DevKit
        $pathEntries = $machinePath -split ';' | Where-Object { 
            $_ -and 
            $_ -notlike "*DevKit*" -and 
            $_ -notlike "*F:\DevKit*" -and
            $_ -notlike "*f:\DevKit*"
        }
        
        $cleanPath = $pathEntries -join ';'
        
        # Count removed entries
        $originalCount = ($machinePath -split ';').Count
        $newCount = ($cleanPath -split ';').Count
        $removedCount = $originalCount - $newCount
        
        if ($removedCount -gt 0) {
            [Environment]::SetEnvironmentVariable("Path", $cleanPath, "Machine")
            $env:Path = $cleanPath
            Write-Log "  ✅ Removed $removedCount DevKit entries from Machine PATH" "Green"
        } else {
            Write-Log "  ✅ No DevKit entries found in Machine PATH (already clean)" "Green"
        }
    }
} catch {
    Write-Log "  ⚠️  Error cleaning Machine PATH: $_" "Yellow"
}

################################################################################
# 4. REMOVE ALL DEVKIT ENTRIES FROM USER PATH
################################################################################
Write-Log "`n[4/8] Cleaning User PATH..." "Yellow"

try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    
    if ($userPath) {
        # Remove all entries containing "DevKit" or pointing to F:\DevKit
        $pathEntries = $userPath -split ';' | Where-Object { 
            $_ -and 
            $_ -notlike "*DevKit*" -and 
            $_ -notlike "*F:\DevKit*" -and
            $_ -notlike "*f:\DevKit*"
        }
        
        $cleanPath = $pathEntries -join ';'
        
        # Count removed entries
        $originalCount = ($userPath -split ';').Count
        $newCount = ($cleanPath -split ';').Count
        $removedCount = $originalCount - $newCount
        
        if ($removedCount -gt 0) {
            [Environment]::SetEnvironmentVariable("Path", $cleanPath, "User")
            Write-Log "  ✅ Removed $removedCount DevKit entries from User PATH" "Green"
        } else {
            Write-Log "  ✅ No DevKit entries found in User PATH (already clean)" "Green"
        }
    }
} catch {
    Write-Log "  ⚠️  Error cleaning User PATH: $_" "Yellow"
}

################################################################################
# 5. REMOVE ALL ENVIRONMENT VARIABLES
################################################################################
Write-Log "`n[5/8] Removing environment variables..." "Yellow"

$envVarsToRemove = @(
    "DEVKIT_PATH",
    "DOTNET_ROOT",
    "DOTNET_ROOT_8_0",
    "DOTNET_ROOT_9_0",
    "DOTNET_CLI_HOME",
    "DOTNET_MULTILEVEL_LOOKUP",
    "DOTNET_SKIP_FIRST_TIME_EXPERIENCE",
    "DOTNET_NOLOGO",
    "VCPKG_ROOT"
)

foreach ($varName in $envVarsToRemove) {
    try {
        # Remove from Machine scope
        $machineValue = [Environment]::GetEnvironmentVariable($varName, "Machine")
        if ($machineValue) {
            [Environment]::SetEnvironmentVariable($varName, $null, "Machine")
            Write-Log "  ✅ Removed $varName from Machine scope" "Green"
        }
        
        # Remove from User scope
        $userValue = [Environment]::GetEnvironmentVariable($varName, "User")
        if ($userValue) {
            [Environment]::SetEnvironmentVariable($varName, $null, "User")
            Write-Log "  ✅ Removed $varName from User scope" "Green"
        }
        
        # Remove from Process scope
        Remove-Item "env:$varName" -ErrorAction SilentlyContinue
    } catch {
        Write-Log "  ⚠️  Error removing $varName : $_" "Yellow"
    }
}

Write-Log "  ✅ Environment variables cleaned" "Green"

################################################################################
# 6. CLEAN POWERSHELL PROFILES
################################################################################
Write-Log "`n[6/8] Cleaning PowerShell profiles..." "Yellow"

# PowerShell 7 profile
$pwsh7ProfilePath = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $pwsh7ProfilePath) {
    try {
        $content = Get-Content $pwsh7ProfilePath -Raw
        
        # Remove our auto-generated section
        if ($content -match "# Auto-generated portable development environment") {
            # Split by our marker and remove our section
            $lines = Get-Content $pwsh7ProfilePath
            $newLines = @()
            $skipMode = $false
            
            foreach ($line in $lines) {
                if ($line -match "# Auto-generated portable development environment") {
                    $skipMode = $true
                    continue
                }
                if ($skipMode -and $line -match "Write-Host.*DevKit portable environment loaded") {
                    $skipMode = $false
                    continue
                }
                if (-not $skipMode) {
                    $newLines += $line
                }
            }
            
            # Save cleaned profile
            if ($newLines.Count -gt 0) {
                $newLines | Set-Content $pwsh7ProfilePath
                Write-Log "  ✅ Cleaned PowerShell 7 profile" "Green"
            } else {
                # Profile only contained our content, remove it
                Remove-Item $pwsh7ProfilePath -Force
                Write-Log "  ✅ Removed PowerShell 7 profile (only contained our content)" "Green"
            }
        } else {
            Write-Log "  ℹ️  PowerShell 7 profile doesn't contain our content" "Gray"
        }
    } catch {
        Write-Log "  ⚠️  Error cleaning PowerShell 7 profile: $_" "Yellow"
    }
} else {
    Write-Log "  ℹ️  PowerShell 7 profile doesn't exist" "Gray"
}

# Windows PowerShell 5.1 profile
$pwsh51ProfilePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $pwsh51ProfilePath) {
    try {
        $content = Get-Content $pwsh51ProfilePath -Raw
        
        # Remove our auto-generated section
        if ($content -match "# Auto-generated portable development environment") {
            $lines = Get-Content $pwsh51ProfilePath
            $newLines = @()
            $skipMode = $false
            
            foreach ($line in $lines) {
                if ($line -match "# Auto-generated portable development environment") {
                    $skipMode = $true
                    continue
                }
                if ($skipMode -and $line -match "Write-Host.*DevKit portable environment loaded") {
                    $skipMode = $false
                    continue
                }
                if (-not $skipMode) {
                    $newLines += $line
                }
            }
            
            # Save cleaned profile
            if ($newLines.Count -gt 0) {
                $newLines | Set-Content $pwsh51ProfilePath
                Write-Log "  ✅ Cleaned Windows PowerShell 5.1 profile" "Green"
            } else {
                # Profile only contained our content, remove it
                Remove-Item $pwsh51ProfilePath -Force
                Write-Log "  ✅ Removed Windows PowerShell 5.1 profile (only contained our content)" "Green"
            }
        } else {
            Write-Log "  ℹ️  Windows PowerShell 5.1 profile doesn't contain our content" "Gray"
        }
    } catch {
        Write-Log "  ⚠️  Error cleaning Windows PowerShell 5.1 profile: $_" "Yellow"
    }
} else {
    Write-Log "  ℹ️  Windows PowerShell 5.1 profile doesn't exist" "Gray"
}

################################################################################
# 7. REMOVE WINDOWS REGISTRY ENTRIES
################################################################################
Write-Log "`n[7/8] Cleaning Windows Registry..." "Yellow"

try {
    # Remove SDK registry entries for versions we installed
    $sdkRegistryPath = "HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sdk"
    
    if (Test-Path $sdkRegistryPath) {
        $sdkEntries = Get-ItemProperty -Path $sdkRegistryPath -ErrorAction SilentlyContinue
        
        # Remove entries that point to C:\Program Files\dotnet or F:\DevKit
        $versionsToRemove = @("9.0.305", "9.0.100", "8.0.404")
        
        foreach ($version in $versionsToRemove) {
            $value = Get-ItemPropertyValue -Path $sdkRegistryPath -Name $version -ErrorAction SilentlyContinue
            if ($value) {
                Remove-ItemProperty -Path $sdkRegistryPath -Name $version -Force -ErrorAction SilentlyContinue
                Write-Log "  ✅ Removed SDK $version from registry" "Green"
            }
        }
    }
    
    # Remove shared host registry entries
    $sharedHostPath = "HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost"
    if (Test-Path $sharedHostPath) {
        $hostPath = Get-ItemPropertyValue -Path $sharedHostPath -Name "Path" -ErrorAction SilentlyContinue
        if ($hostPath -like "*Program Files\dotnet*" -or $hostPath -like "*DevKit*") {
            Remove-Item -Path $sharedHostPath -Force -Recurse -ErrorAction SilentlyContinue
            Write-Log "  ✅ Removed shared host from registry" "Green"
        }
    }
    
    Write-Log "  ✅ Registry cleaned" "Green"
} catch {
    Write-Log "  ⚠️  Error cleaning registry: $_" "Yellow"
}

################################################################################
# 8. BROADCAST ENVIRONMENT CHANGES
################################################################################
Write-Log "`n[8/8] Broadcasting environment changes..." "Yellow"

try {
    Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
            uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x1a
    $result = [UIntPtr]::Zero
    [Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, 
        [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$result) | Out-Null
    Write-Log "  ✅ Environment changes broadcast to all applications" "Green"
} catch {
    Write-Log "  ⚠️  Could not broadcast changes: $_" "Yellow"
}

################################################################################
# FINAL SUMMARY
################################################################################
Write-Log "`n========================================" "Green"
Write-Log "✅✅✅ CLEANUP COMPLETE ✅✅✅" "Green"
Write-Log "========================================" "Green"

Write-Log "`n📊 CLEANUP SUMMARY:" "Yellow"
Write-Log "   ✅ F:\DevKit folder removed" "Cyan"
Write-Log "   ✅ System .NET cleaned (if applicable)" "Cyan"
Write-Log "   ✅ Machine PATH cleaned" "Cyan"
Write-Log "   ✅ User PATH cleaned" "Cyan"
Write-Log "   ✅ Environment variables removed" "Cyan"
Write-Log "   ✅ PowerShell profiles cleaned" "Cyan"
Write-Log "   ✅ Windows Registry cleaned" "Cyan"
Write-Log "   ✅ Changes broadcast to all applications" "Cyan"

Write-Log "`n🎯 NEXT STEPS:" "Yellow"
Write-Log "   1. Close this PowerShell window" "Cyan"
Write-Log "   2. Open a NEW PowerShell window (to get clean environment)" "Cyan"
Write-Log "   3. Run SETUP-EVERYTHING.ps1 to start fresh" "Cyan"
Write-Log "   4. Everything will be installed from scratch" "Cyan"

Write-Log "`n✨ Your system is now in a clean state!" "Green"
Write-Log "Ready to run SETUP-EVERYTHING.ps1 again!`n" "Green"
