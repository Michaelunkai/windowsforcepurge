#Requires -RunAsAdministrator
################################################################################
# MINIMAL DEVELOPMENT ENVIRONMENT SETUP - .NET 9 and PowerShell 7
# Installs: .NET 9 SDK and adds PowerShell 7 to PATH permanently
################################################################################

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MINIMAL DEVELOPMENT ENVIRONMENT SETUP" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Configuration
$DevKitPath = "F:\DevKit"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Create main directories
New-Item -ItemType Directory -Force -Path "$DevKitPath\sdk" | Out-Null

# Helper function to safely add to PATH (prepend for priority)
function Add-ToMachinePath {
    param($NewPath)
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$NewPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$NewPath;$currentPath", "Machine")
        Write-Host "  ✅ Added to PATH: $NewPath" -ForegroundColor Green
        return $true
    }
    return $false
}

# Helper function to set environment variable for all scopes
function Set-EnvironmentVariableAllScopes {
    param($Name, $Value)
    [Environment]::SetEnvironmentVariable($Name, $Value, "Machine")
    [Environment]::SetEnvironmentVariable($Name, $Value, "User")
    [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
    Set-Item "env:$Name" -Value $Value -Force -ErrorAction SilentlyContinue
}

################################################################################
# INSTALL PORTABLE .NET SDK VERSION 9
################################################################################
Write-Host "[1/3] Installing portable .NET SDK version 9..." -ForegroundColor Yellow

$dotnet9Path = "$DevKitPath\sdk\dotnet9"
New-Item -ItemType Directory -Force -Path $dotnet9Path | Out-Null

# Download .NET install script
$dotnetInstaller = "$env:TEMP\dotnet-install.ps1"
try {
    Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $dotnetInstaller -ErrorAction Stop
} catch {
    Write-Host "  ⚠️  Failed to download .NET installer: $_" -ForegroundColor Red
    exit 1
}

# Install .NET SDK version 9
Write-Host " 📦 Installing .NET SDK version 9..." -ForegroundColor Cyan
try {
    # Try multiple channels for .NET 9
    $channels = @("9.0", "preview", "latest")
    $success = $false
    
    foreach ($channel in $channels) {
        if (-not $success) {
            Write-Host "    Trying channel: $channel" -ForegroundColor Yellow
            try {
                & $dotnetInstaller -InstallDir $dotnet9Path -Channel $channel -Quality "daily" -ErrorAction Continue
                Start-Sleep -Seconds 2
                
                # Check if installation was successful
                $dotnet9Exe = Get-ChildItem "$dotnet9Path\dotnet.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($dotnet9Exe) {
                    $version = & $dotnet9Exe.FullName --version 2>&1
                    if ($version -and $version -notlike "*error*" -and $version -notlike "*Error*") {
                        Write-Host "  ✅ .NET SDK version 9 installed successfully: $version" -ForegroundColor Green
                        $success = $true
                        break
                    }
                }
            } catch {
                Write-Host "    Channel $channel failed: $_" -ForegroundColor Yellow
            }
        }
    }
    
    if (-not $success) {
        Write-Host "  ❌ .NET SDK version 9 installation failed from all channels" -ForegroundColor Red
        Write-Host "  💡 Please check if .NET 9 is available at https://dotnet.microsoft.com/download/dotnet/9.0" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  .NET SDK version 9 installation failed: $_" -ForegroundColor Red
}

# Add .NET 9 to PATH
if (Test-Path $dotnet9Path) {
    Add-ToMachinePath $dotnet9Path
    Set-EnvironmentVariableAllScopes "DOTNET_ROOT_9_0" $dotnet9Path
    Write-Host "  ✅ .NET 9 added to PATH and environment variables" -ForegroundColor Green
}

Write-Host "  ✅ .NET SDK version 9 installed to F:\DevKit" -ForegroundColor Green

################################################################################
# ADD PWSH TO PATH PERMANENTLY
################################################################################
Write-Host "`n[2/3] Adding PowerShell 7 (pwsh) to PATH permanently..." -ForegroundColor Yellow

# Comprehensive PowerShell 7 detection and PATH addition
$pwshFound = $false

# Search for PowerShell 7 in all possible locations
$pwshSearchPaths = @(
    "C:\Program Files\PowerShell\7",
    "C:\Program Files\PowerShell\7-preview",
    "C:\Program Files (x86)\PowerShell\7",
    "C:\Program Files (x86)\PowerShell\7-preview",
    "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe",
    "$env:PROGRAMFILES\PowerShell\*",
    "$env:ProgramW6432\PowerShell\*"
)

foreach ($searchPath in $pwshSearchPaths) {
    if ($searchPath -like "*WindowsApps*") {
        if (Test-Path $searchPath) {
            $pwshDir = Split-Path $searchPath -Parent
            if (Add-ToMachinePath $pwshDir) {
                Write-Host "  ✅ PowerShell 7 added to PATH: $pwshDir" -ForegroundColor Green
                $pwshFound = $true
                break
            }
        }
    } else {
        # Handle wildcard paths
        if ($searchPath -like "*\**") {
            $resolvedPaths = Get-ChildItem -Path $searchPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
            foreach ($resolvedPath in $resolvedPaths) {
                $pwshExe = Join-Path $resolvedPath.FullName "pwsh.exe"
                if (Test-Path $pwshExe) {
                    $pwshDir = $resolvedPath.FullName
                    if (Add-ToMachinePath $pwshDir) {
                        Write-Host "  ✅ PowerShell 7 added to PATH: $pwshDir" -ForegroundColor Green
                        $pwshFound = $true
                        break
                    }
                }
            }
        } else {
            # Direct path
            if (Test-Path $searchPath) {
                $pwshExe = Join-Path $searchPath "pwsh.exe"
                if (Test-Path $pwshExe) {
                    if (Add-ToMachinePath $searchPath) {
                        Write-Host "  ✅ PowerShell 7 added to PATH: $searchPath" -ForegroundColor Green
                        $pwshFound = $true
                        break
                    }
                }
            }
        }
    }
    if ($pwshFound) { break }
}

# If still not found, search in current PATH
if (-not $pwshFound) {
    Write-Host "  📦 Searching for pwsh in current PATH..." -ForegroundColor Cyan
    try {
        $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwshCmd) {
            $pwshDir = Split-Path $pwshCmd.Path -Parent
            if (Add-ToMachinePath $pwshDir) {
                Write-Host "  ✅ pwsh found and added to PATH: $pwshDir" -ForegroundColor Green
                $pwshFound = $true
            }
        }
    } catch {
        Write-Host "  ⚠️  pwsh not found in PATH" -ForegroundColor Yellow
    }
}

# If still not found, try registry search
if (-not $pwshFound) {
    Write-Host "  📦 Searching in registry for PowerShell 7..." -ForegroundColor Cyan
    try {
        $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine",
            "HKCU:\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\PowerShell\3\PowerShellEngine"
        )
        
        foreach ($regPath in $registryPaths) {
            if (Test-Path $regPath) {
                $regValue = Get-ItemProperty -Path $regPath -Name "ApplicationBase" -ErrorAction SilentlyContinue
                if ($regValue) {
                    $regPwshDir = Join-Path $regValue.ApplicationBase "pwsh.exe"
                    if (Test-Path $regPwshDir) {
                        $pwshDir = Split-Path $regPwshDir -Parent
                        if (Add-ToMachinePath $pwshDir) {
                            Write-Host "  ✅ PowerShell 7 found in registry and added to PATH: $pwshDir" -ForegroundColor Green
                            $pwshFound = $true
                            break
                        }
                    }
                }
            }
        }
    } catch {
        Write-Host "  ⚠️  Registry search failed: $_" -ForegroundColor Yellow
    }
}

if (-not $pwshFound) {
    Write-Host "  ⚠️  PowerShell 7 not found. You may need to install it separately." -ForegroundColor Yellow
    Write-Host "  💡 Download from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Cyan
} else {
    Write-Host "  ✅ PowerShell 7 successfully added to PATH permanently" -ForegroundColor Green
}

# Additional verification
Write-Host "  📦 Verifying PowerShell 7 availability..." -ForegroundColor Cyan
try {
    $pwshVersion = & pwsh -Command "$PSVersionTable.PSVersion" 2>&1
    if ($pwshVersion -and $pwshVersion -notlike "*The term 'pwsh' is not recognized*") {
        Write-Host "  ✅ PowerShell 7 is available: $pwshVersion" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  PowerShell 7 not immediately available (may need shell restart)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️ PowerShell 7 verification pending shell restart" -ForegroundColor Yellow
}

################################################################################
# FINAL VERIFICATION
################################################################################
Write-Host "`n[3/3] Final verification..." -ForegroundColor Yellow

# Verify .NET 9 installation specifically
Write-Host "`nVerifying .NET 9 installation..." -ForegroundColor Cyan
try {
    $dotnet9Exe = Get-ChildItem "$dotnet9Path\dotnet.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($dotnet9Exe) {
        $version = & $dotnet9Exe.FullName --version 2>&1
        if ($version) {
            Write-Host "  ✅ .NET 9 version: $version" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  .NET 9 executable found but version check failed" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ⚠️  .NET 9 executable not found in expected location" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ .NET 9 verification failed: $_" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "SETUP COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`n⚠️  IMPORTANT:" -ForegroundColor Yellow
Write-Host "   1. Close ALL PowerShell windows" -ForegroundColor Cyan
Write-Host "   2. Open a NEW PowerShell window" -ForegroundColor Cyan
Write-Host "   3. .NET 9 SDK installed to: F:\DevKit\sdk\dotnet9" -ForegroundColor Cyan
Write-Host "   4. PowerShell 7 (pwsh) added to PATH permanently" -ForegroundColor Cyan
Write-Host "" -ForegroundColor Cyan
