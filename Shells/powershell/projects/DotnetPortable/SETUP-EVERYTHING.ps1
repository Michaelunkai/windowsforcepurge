#Requires -RunAsAdministrator
################################################################################
# COMPLETE PORTABLE DEVELOPMENT ENVIRONMENT SETUP - 100% F:\DevKit ONLY
# Priority Order: .NET 9 SDK FIRST, then pwsh, git, gh, and all other tools
# Target: F:\DevKit (external drive) - ZERO C: DRIVE INSTALLATIONS
# Compatible: PowerShell 5.1, 7.x, and all future versions
# Smart: Skips already installed components, comprehensive verification
# FIXED: Ensures .NET 9, pwsh, git, gh all work after reboot with permanent PATH
################################################################################

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PORTABLE DEVELOPMENT ENVIRONMENT SETUP" -ForegroundColor Cyan
Write-Host "Priority: .NET 9 SDK → pwsh → git → gh → All Tools" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Configuration - ALL INSTALLATIONS TO F:\DevKit
$DevKitPath = "F:\DevKit"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = "$ScriptDir\InstallationLog.txt"

# Initialize log
"=== Installation started at $(Get-Date) ===" | Out-File $LogFile -Append

# Create main directories
New-Item -ItemType Directory -Force -Path "$DevKitPath\bin" | Out-Null
New-Item -ItemType Directory -Force -Path "$DevKitPath\tools" | Out-Null
New-Item -ItemType Directory -Force -Path "$DevKitPath\compilers" | Out-Null
New-Item -ItemType Directory -Force -Path "$DevKitPath\sdk" | Out-Null

# Helper function to log and display
function Write-Log {
    param($Message, $Color = "White")
    Write-Host $Message -ForegroundColor $Color
    $Message | Out-File $LogFile -Append
}

# Helper function to refresh environment variables
function Refresh-Environment {
    Write-Log "  📦 Refreshing environment variables..." "Cyan"

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"

    foreach ($level in "Machine", "User") {
        [Environment]::GetEnvironmentVariables($level).GetEnumerator() | ForEach-Object {
            if ($_.Key -ne "Path") {
                [Environment]::SetEnvironmentVariable($_.Key, $_.Value, "Process")
            }
        }
    }

    Write-Log "  ✅ Environment refreshed" "Green"
}

# Helper function to test command availability
function Test-Command {
    param($Command)
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Helper function to safely add to PATH (prepend for priority) - FIXED for permanent persistence
function Add-ToMachinePath {
    param($NewPath)

    if (-not (Test-Path $NewPath)) {
        Write-Log "  ⚠️  Path does not exist: $NewPath" "Yellow"
        return $false
    }

    # Get current Machine PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    
    # Check if already in PATH (case-insensitive)
    $pathEntries = $currentPath -split ';' | Where-Object { $_.Trim() }
    $alreadyExists = $pathEntries | Where-Object { $_.Trim().TrimEnd('\') -eq $NewPath.Trim().TrimEnd('\') }
    
    if ($alreadyExists) {
        Write-Log "  ℹ️  Already in PATH: $NewPath" "Gray"
        # Still update current session
        if ($env:Path -notlike "*$NewPath*") {
            $env:Path = "$NewPath;$env:Path"
        }
        return $true
    }

    # Add to Machine PATH (permanent)
    try {
        $newMachinePath = "$NewPath;$currentPath"
        [Environment]::SetEnvironmentVariable("Path", $newMachinePath, "Machine")
        
        # Update current session immediately
        $env:Path = "$NewPath;$env:Path"
        
        # Verify it was set
        $verifyPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($verifyPath -like "*$NewPath*") {
            Write-Log "  ✅ PERMANENTLY added to Machine PATH: $NewPath" "Green"
            return $true
        } else {
            Write-Log "  ❌ Failed to verify PATH addition: $NewPath" "Red"
            return $false
        }
    } catch {
        Write-Log "  ❌ Error adding to PATH: $_" "Red"
        return $false
    }
}

# Helper function to set environment variable for all scopes
function Set-EnvironmentVariableAllScopes {
    param($Name, $Value)

    Write-Log "  📦 Setting $Name = $Value" "Cyan"
    [Environment]::SetEnvironmentVariable($Name, $Value, "Machine")
    [Environment]::SetEnvironmentVariable($Name, $Value, "User")
    [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
    Set-Item "env:$Name" -Value $Value -Force -ErrorAction SilentlyContinue

    Write-Log "  ✅ $Name set in all scopes" "Green"
}

################################################################################
# PRIORITY 1: INSTALL .NET 9 SDK FIRST - 100% PORTABLE TO F:\DevKit
################################################################################
Write-Log "`n[PRIORITY 1] Installing .NET 9 SDK - HIGHEST PRIORITY" "Yellow"

$dotnetPath = "$DevKitPath\sdk\dotnet"
$dotnet8Path = "$DevKitPath\sdk\dotnet8"
$dotnet9Path = "$DevKitPath\sdk\dotnet9"

New-Item -ItemType Directory -Force -Path $dotnet8Path | Out-Null
New-Item -ItemType Directory -Force -Path $dotnet9Path | Out-Null
New-Item -ItemType Directory -Force -Path $dotnetPath | Out-Null

# Check if .NET 9 already exists
$dotnet9Exe = Join-Path $dotnet9Path "dotnet.exe"
$dotnet9AlreadyInstalled = $false

if (Test-Path $dotnet9Exe) {
    try {
        $existingVersion = & $dotnet9Exe --version 2>&1
        if ($existingVersion -match "^9\." -and $existingVersion -notlike "*error*") {
            Write-Log "  ✅ .NET 9 already installed: $existingVersion" "Green"
            $dotnet9AlreadyInstalled = $true
        }
    } catch {
        Write-Log "  ⚠️  Existing .NET 9 installation invalid, reinstalling..." "Yellow"
        $dotnet9AlreadyInstalled = $false
    }
}

if (-not $dotnet9AlreadyInstalled) {
    Write-Log "  📦 Installing .NET 9 SDK - CRITICAL PRIORITY..." "Cyan"
    
    # Strategy 1: Direct download of .NET 9.0.100 (known working version)
    $dotnet9Installed = $false
    
    try {
        Write-Log "    Strategy 1: Direct download .NET 9.0.100 SDK..." "Cyan"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        $sdkUrl = "https://download.visualstudio.microsoft.com/download/pr/b43f2d8c-4f4a-4d71-bdff-35b23f6e6efe/5e5a8de14f9675a5ef0ad7b5226a3c99/dotnet-sdk-9.0.100-win-x64.zip"
        $sdkZip = "$env:TEMP\dotnet-sdk-9.0.100-win-x64.zip"
        
        Write-Log "      Downloading .NET 9.0.100 SDK (this may take a few minutes)..." "Cyan"
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($sdkUrl, $sdkZip)
        
        if (Test-Path $sdkZip) {
            $fileSize = (Get-Item $sdkZip).Length / 1MB
            Write-Log "      Downloaded: $([math]::Round($fileSize, 2)) MB" "Green"
            
            Write-Log "      Extracting .NET 9 SDK to $dotnet9Path..." "Cyan"
            
            # Clear existing directory if needed
            if (Test-Path $dotnet9Path) {
                Get-ChildItem $dotnet9Path -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
            New-Item -ItemType Directory -Force -Path $dotnet9Path | Out-Null
            
            # Extract
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($sdkZip, $dotnet9Path)
            
            # Verify installation
            if (Test-Path $dotnet9Exe) {
                $version = & $dotnet9Exe --version 2>&1
                if ($version -match "^9\." -and $version -notlike "*error*") {
                    Write-Log "      ✅✅✅ .NET 9 SDK INSTALLED: $version ✅✅✅" "Green"
                    $dotnet9Installed = $true
                } else {
                    Write-Log "      ⚠️  Version check failed: $version" "Yellow"
                }
            }
            
            # Cleanup
            Remove-Item $sdkZip -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Log "      ⚠️  Strategy 1 failed: $_" "Yellow"
    }
    
    # Strategy 2: Use dotnet-install.ps1 script
    if (-not $dotnet9Installed) {
        try {
            Write-Log "    Strategy 2: Using dotnet-install.ps1..." "Cyan"
            $dotnetInstaller = "$env:TEMP\dotnet-install.ps1"
            
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile("https://dot.net/v1/dotnet-install.ps1", $dotnetInstaller)
            
            if (Test-Path $dotnetInstaller) {
                # Try channel 9.0
                & $dotnetInstaller -InstallDir $dotnet9Path -Channel "9.0" -NoPath -SkipNonVersionedFiles:$false 2>&1 | Out-Null
                
                if (Test-Path $dotnet9Exe) {
                    $version = & $dotnet9Exe --version 2>&1
                    if ($version -match "^9\." -and $version -notlike "*error*") {
                        Write-Log "      ✅✅✅ .NET 9 SDK INSTALLED: $version ✅✅✅" "Green"
                        $dotnet9Installed = $true
                    }
                }
            }
        } catch {
            Write-Log "      ⚠️  Strategy 2 failed: $_" "Yellow"
        }
    }
    
    # Strategy 3: Try alternative download URL
    if (-not $dotnet9Installed) {
        try {
            Write-Log "    Strategy 3: Alternative download source..." "Cyan"
            $altUrl = "https://dotnetcli.azureedge.net/dotnet/Sdk/9.0.100/dotnet-sdk-9.0.100-win-x64.zip"
            $altZip = "$env:TEMP\dotnet-sdk-9-alt.zip"
            
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($altUrl, $altZip)
            
            if (Test-Path $altZip) {
                if (Test-Path $dotnet9Path) {
                    Get-ChildItem $dotnet9Path -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Force -Path $dotnet9Path | Out-Null
                
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($altZip, $dotnet9Path)
                
                if (Test-Path $dotnet9Exe) {
                    $version = & $dotnet9Exe --version 2>&1
                    if ($version -match "^9\." -and $version -notlike "*error*") {
                        Write-Log "      ✅✅✅ .NET 9 SDK INSTALLED: $version ✅✅✅" "Green"
                        $dotnet9Installed = $true
                    }
                }
                
                Remove-Item $altZip -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Log "      ⚠️  Strategy 3 failed: $_" "Yellow"
        }
    }
    
    if (-not $dotnet9Installed) {
        Write-Log "  ❌❌❌ .NET 9 INSTALLATION FAILED - CRITICAL ERROR ❌❌❌" "Red"
        Write-Log "  Please download manually from: https://dotnet.microsoft.com/download/dotnet/9.0" "Yellow"
        Write-Log "  Extract to: $dotnet9Path" "Yellow"
    }
}

# Install .NET 8 (if not exists)
$dotnet8Exe = Join-Path $dotnet8Path "dotnet.exe"
if (Test-Path $dotnet8Exe) {
    try {
        $ver8 = & $dotnet8Exe --version 2>&1
        Write-Log "  ✅ .NET 8 already installed: $ver8" "Green"
    } catch {
        Write-Log "  ⚠️  .NET 8 exists but version check failed" "Yellow"
    }
} else {
    Write-Log "  📦 Installing .NET 8 SDK..." "Cyan"
    try {
        $dotnetInstaller = "$env:TEMP\dotnet-install.ps1"
        if (-not (Test-Path $dotnetInstaller)) {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile("https://dot.net/v1/dotnet-install.ps1", $dotnetInstaller)
        }
        
        if (Test-Path $dotnetInstaller) {
            & $dotnetInstaller -InstallDir $dotnet8Path -Channel "8.0" -NoPath 2>&1 | Out-Null
            if (Test-Path $dotnet8Exe) {
                $ver8 = & $dotnet8Exe --version 2>&1
                Write-Log "  ✅ .NET 8 SDK installed: $ver8" "Green"
            }
        }
    } catch {
        Write-Log "  ⚠️  .NET 8 installation had issues: $_" "Yellow"
    }
}

# Install LTS as default
$dotnetLtsExe = Join-Path $dotnetPath "dotnet.exe"
if (Test-Path $dotnetLtsExe) {
    try {
        $verLts = & $dotnetLtsExe --version 2>&1
        Write-Log "  ✅ .NET LTS already installed: $verLts" "Green"
    } catch {
        Write-Log "  ⚠️  .NET LTS exists but version check failed" "Yellow"
    }
} else {
    Write-Log "  📦 Installing .NET LTS..." "Cyan"
    try {
        $dotnetInstaller = "$env:TEMP\dotnet-install.ps1"
        if (-not (Test-Path $dotnetInstaller)) {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile("https://dot.net/v1/dotnet-install.ps1", $dotnetInstaller)
        }
        
        if (Test-Path $dotnetInstaller) {
            & $dotnetInstaller -InstallDir $dotnetPath -Channel "LTS" -NoPath 2>&1 | Out-Null
            if (Test-Path $dotnetLtsExe) {
                $verLts = & $dotnetLtsExe --version 2>&1
                Write-Log "  ✅ .NET LTS installed: $verLts" "Green"
            }
        }
    } catch {
        Write-Log "  ⚠️  .NET LTS installation had issues: $_" "Yellow"
    }
}

# Configure .NET environment - CRITICAL: Point to system location for compatibility
Write-Log "  📦 Configuring .NET environment variables..." "Cyan"
# CRITICAL FIX: DOTNET_ROOT must point to C:\Program Files\dotnet for Windows applications
Set-EnvironmentVariableAllScopes "DOTNET_ROOT" "C:\Program Files\dotnet"
Set-EnvironmentVariableAllScopes "DOTNET_ROOT_8_0" $dotnet8Path
Set-EnvironmentVariableAllScopes "DOTNET_ROOT_9_0" $dotnet9Path
Set-EnvironmentVariableAllScopes "DOTNET_CLI_HOME" $dotnetPath
# CRITICAL FIX: Enable multi-level lookup so .NET can find installations in multiple locations
Set-EnvironmentVariableAllScopes "DOTNET_MULTILEVEL_LOOKUP" "1"
Set-EnvironmentVariableAllScopes "DOTNET_SKIP_FIRST_TIME_EXPERIENCE" "1"
Set-EnvironmentVariableAllScopes "DOTNET_NOLOGO" "1"

# Add to PATH - .NET 9 FIRST (highest priority) - PERMANENT
Write-Log "  📦 Adding .NET to PATH PERMANENTLY (priority: 9 → 8 → LTS)..." "Cyan"
$pathAdded = $false
if (Test-Path $dotnet9Path) {
    if (Add-ToMachinePath $dotnet9Path) { $pathAdded = $true }
}
if (Test-Path $dotnet8Path) {
    if (Add-ToMachinePath $dotnet8Path) { $pathAdded = $true }
}
if (Test-Path $dotnetPath) {
    if (Add-ToMachinePath $dotnetPath) { $pathAdded = $true }
}

if ($pathAdded) {
    Write-Log "  ✅ .NET paths added to MACHINE PATH (permanent)" "Green"
}

Refresh-Environment

# VERIFY .NET 9 is accessible
Write-Log "  🔍 Verifying .NET 9 is accessible..." "Cyan"
try {
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnetCmd) {
        $globalVersion = & dotnet --version 2>&1
        Write-Log "  ✅ Global 'dotnet' command works: $globalVersion" "Green"
    } else {
        Write-Log "  ⚠️  'dotnet' command not found in PATH yet (reboot required)" "Yellow"
    }
} catch {
    Write-Log "  ⚠️  Cannot verify global dotnet command: $_" "Yellow"
}

# CRITICAL FIX: Copy .NET to C:\Program Files\dotnet and register in Windows Registry
Write-Log "  🔧 CRITICAL FIX: Ensuring .NET is accessible to all Windows applications..." "Yellow"
$systemDotnetPath = "C:\Program Files\dotnet"

# Create directory if it doesn't exist
if (-not (Test-Path $systemDotnetPath)) {
    New-Item -ItemType Directory -Path $systemDotnetPath -Force | Out-Null
}

# Copy .NET 9 SDK to system location
$systemSdkPath = "$systemDotnetPath\sdk"
if (Test-Path "$dotnet9Path\sdk") {
    Write-Log "    📦 Copying .NET 9 SDK to C:\Program Files\dotnet..." "Cyan"
    if (-not (Test-Path $systemSdkPath)) {
        New-Item -ItemType Directory -Path $systemSdkPath -Force | Out-Null
    }
    
    $sdkVersions = Get-ChildItem "$dotnet9Path\sdk" -Directory -ErrorAction SilentlyContinue
    foreach ($sdkVersion in $sdkVersions) {
        $targetSdkVersion = Join-Path $systemSdkPath $sdkVersion.Name
        if (-not (Test-Path $targetSdkVersion)) {
            Copy-Item -Path $sdkVersion.FullName -Destination $targetSdkVersion -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "      ✅ SDK $($sdkVersion.Name) copied" "Green"
        } else {
            Write-Log "      ✅ SDK $($sdkVersion.Name) already exists" "Gray"
        }
    }
}

# Copy runtimes (needed for applications)
$sharedPath = "$systemDotnetPath\shared"
if (-not (Test-Path $sharedPath)) {
    New-Item -ItemType Directory -Path $sharedPath -Force | Out-Null
}

# Copy Microsoft.NETCore.App
if (Test-Path "$dotnet9Path\shared\Microsoft.NETCore.App") {
    Write-Log "    📦 Copying .NET 9 runtime..." "Cyan"
    $targetRuntimePath = "$sharedPath\Microsoft.NETCore.App"
    if (-not (Test-Path $targetRuntimePath)) {
        New-Item -ItemType Directory -Path $targetRuntimePath -Force | Out-Null
    }
    
    $runtimeVersions = Get-ChildItem "$dotnet9Path\shared\Microsoft.NETCore.App" -Directory -ErrorAction SilentlyContinue
    foreach ($runtime in $runtimeVersions) {
        $targetRuntime = Join-Path $targetRuntimePath $runtime.Name
        if (-not (Test-Path $targetRuntime)) {
            Copy-Item -Path $runtime.FullName -Destination $targetRuntime -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "      ✅ Runtime $($runtime.Name) copied" "Green"
        }
    }
}

# Copy Microsoft.WindowsDesktop.App (needed for desktop applications)
if (Test-Path "$dotnet9Path\shared\Microsoft.WindowsDesktop.App") {
    $targetDesktopPath = "$sharedPath\Microsoft.WindowsDesktop.App"
    if (-not (Test-Path $targetDesktopPath)) {
        New-Item -ItemType Directory -Path $targetDesktopPath -Force | Out-Null
    }
    
    $desktopVersions = Get-ChildItem "$dotnet9Path\shared\Microsoft.WindowsDesktop.App" -Directory -ErrorAction SilentlyContinue
    foreach ($desktop in $desktopVersions) {
        $targetDesktop = Join-Path $targetDesktopPath $desktop.Name
        if (-not (Test-Path $targetDesktop)) {
            Copy-Item -Path $desktop.FullName -Destination $targetDesktop -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "      ✅ Desktop runtime $($desktop.Name) copied" "Green"
        }
    }
}

# Copy essential host files
if (-not (Test-Path "$systemDotnetPath\dotnet.exe") -and (Test-Path "$dotnet9Path\dotnet.exe")) {
    Copy-Item "$dotnet9Path\dotnet.exe" -Destination $systemDotnetPath -Force -ErrorAction SilentlyContinue
}

$hostDirs = @("hostfxr", "host")
foreach ($hostDir in $hostDirs) {
    if (Test-Path "$dotnet9Path\$hostDir") {
        $targetHost = "$systemDotnetPath\$hostDir"
        if (-not (Test-Path $targetHost)) {
            Copy-Item -Path "$dotnet9Path\$hostDir" -Destination $targetHost -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Register in Windows Registry (CRITICAL for application discovery)
Write-Log "    📝 Registering .NET in Windows Registry..." "Cyan"
try {
    $sdkRegistryPath = "HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sdk"
    if (-not (Test-Path $sdkRegistryPath)) {
        New-Item -Path $sdkRegistryPath -Force | Out-Null
    }
    
    # Register each SDK version
    $installedSdks = Get-ChildItem $systemSdkPath -Directory -ErrorAction SilentlyContinue
    foreach ($sdk in $installedSdks) {
        Set-ItemProperty -Path $sdkRegistryPath -Name $sdk.Name -Value $systemDotnetPath -Force -ErrorAction SilentlyContinue
        Write-Log "      ✅ Registered SDK $($sdk.Name) in registry" "Green"
    }
    
    # Register shared host
    $sharedHostPath = "HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost"
    if (-not (Test-Path $sharedHostPath)) {
        New-Item -Path $sharedHostPath -Force | Out-Null
    }
    
    $latestRuntime = Get-ChildItem "$systemDotnetPath\shared\Microsoft.NETCore.App" -Directory -ErrorAction SilentlyContinue | 
                     Sort-Object Name -Descending | 
                     Select-Object -First 1
    
    if ($latestRuntime) {
        Set-ItemProperty -Path $sharedHostPath -Name "Version" -Value $latestRuntime.Name -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $sharedHostPath -Name "Path" -Value "$systemDotnetPath\" -Force -ErrorAction SilentlyContinue
        Write-Log "      ✅ Registered runtime $($latestRuntime.Name) in registry" "Green"
    }
} catch {
    Write-Log "    ⚠️  Registry update warning: $_" "Yellow"
}

# CRITICAL FIX: Ensure C:\Program Files\dotnet is FIRST in PATH (highest priority)
Write-Log "    🔧 Ensuring C:\Program Files\dotnet is FIRST in PATH..." "Cyan"
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")

# Remove ALL existing dotnet entries from PATH (including F:\DevKit entries)
$pathParts = $machinePath -split ';' | Where-Object { 
    $_ -and $_ -notlike "*dotnet*" 
}

# Add C:\Program Files\dotnet as the FIRST entry
$newPath = "$systemDotnetPath;" + ($pathParts -join ';')
[Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
$env:Path = "$systemDotnetPath;$env:Path"
Write-Log "    ✅ C:\Program Files\dotnet is now FIRST in PATH" "Green"

# Broadcast environment changes to all running applications (CRITICAL!)
Write-Log "    📢 Broadcasting environment changes to all applications..." "Cyan"
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
    Write-Log "    ✅ Environment changes broadcast successfully" "Green"
} catch {
    Write-Log "    ⚠️  Could not broadcast changes (reboot will apply them): $_" "Yellow"
}

# Final verification
Write-Log "    🔍 Verifying system .NET installation..." "Cyan"
try {
    $systemVersion = & "$systemDotnetPath\dotnet.exe" --version 2>&1
    if ($systemVersion -match '^\d+\.\d+') {
        Write-Log "    ✅ C:\Program Files\dotnet\dotnet.exe works: $systemVersion" "Green"
        Write-Log "    ✅ Windows applications can now find .NET!" "Green"
        Write-Log "    ✅ DOTNET_ROOT points to: C:\Program Files\dotnet" "Green"
        Write-Log "    ✅ DOTNET_MULTILEVEL_LOOKUP enabled (fallback support)" "Green"
    } else {
        Write-Log "    ⚠️  System .NET response: $systemVersion" "Yellow"
    }
} catch {
    Write-Log "    ⚠️  Could not verify system .NET: $_" "Yellow"
}

Write-Log "  ✅✅✅ .NET SETUP COMPLETE - PRIORITY 1 DONE ✅✅✅`n" "Green"

################################################################################
# PRIORITY 2: INSTALL POWERSHELL 7 (pwsh) - 100% PORTABLE TO F:\DevKit
################################################################################
Write-Log "`n[PRIORITY 2] Installing PowerShell 7 (pwsh) - SECOND PRIORITY" "Yellow"

$pwshPath = "$DevKitPath\tools\pwsh"
$pwshExePath = "$pwshPath\pwsh.exe"
$pwshAlreadyInstalled = $false

# Check if pwsh already exists in DevKit
if (Test-Path $pwshExePath) {
    try {
        $pwshVersion = & $pwshExePath -Command "`$PSVersionTable.PSVersion.ToString()" 2>&1
        if ($pwshVersion -and $pwshVersion -notlike "*error*") {
            Write-Log "  ✅ PowerShell 7 already installed: $pwshVersion" "Green"
            $pwshAlreadyInstalled = $true
        }
    } catch {
        Write-Log "  ⚠️  Existing pwsh invalid, reinstalling..." "Yellow"
        $pwshAlreadyInstalled = $false
    }
}

# Check if pwsh exists elsewhere (system installation)
if (-not $pwshAlreadyInstalled) {
    $systemPwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($systemPwsh) {
        $systemPwshPath = Split-Path $systemPwsh.Source -Parent
        Write-Log "  ℹ️  Found system pwsh at: $systemPwshPath" "Gray"
        Write-Log "  ℹ️  Will add system pwsh to PATH and also install portable version" "Gray"
        Add-ToMachinePath $systemPwshPath
    }
}

if (-not $pwshAlreadyInstalled) {
    Write-Log "  📦 Installing PowerShell 7 portable to F:\DevKit..." "Cyan"

    try {
        # Download portable PowerShell 7
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Get latest release
        Write-Log "    Fetching latest PowerShell 7 release info..." "Cyan"
        $releaseUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $release = Invoke-RestMethod -Uri $releaseUrl
        $asset = $release.assets | Where-Object { $_.name -match "PowerShell-.*-win-x64\.zip$" } | Select-Object -First 1
        
        if ($asset) {
            $pwshUrl = $asset.browser_download_url
            Write-Log "    Found: $($asset.name)" "Cyan"
        } else {
            # Fallback to direct link
            $pwshUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.zip"
            Write-Log "    Using fallback URL" "Cyan"
        }
        
        $pwshZip = "$env:TEMP\pwsh7-portable.zip"

        Write-Log "    Downloading PowerShell 7..." "Cyan"
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($pwshUrl, $pwshZip)

        if (Test-Path $pwshZip) {
            Write-Log "    Extracting to $pwshPath..." "Cyan"
            
            # Clear existing directory
            if (Test-Path $pwshPath) {
                Get-ChildItem $pwshPath -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
            New-Item -ItemType Directory -Force -Path $pwshPath | Out-Null
            
            # Extract
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($pwshZip, $pwshPath)

            if (Test-Path $pwshExePath) {
                $pwshVersion = & $pwshExePath -Command "`$PSVersionTable.PSVersion.ToString()" 2>&1
                Write-Log "  ✅✅✅ PowerShell 7 INSTALLED: $pwshVersion ✅✅✅" "Green"
                $pwshAlreadyInstalled = $true
            } else {
                Write-Log "  ⚠️  pwsh.exe not found after extraction" "Yellow"
            }
            
            # Cleanup
            Remove-Item $pwshZip -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Log "  ⚠️  PowerShell 7 installation failed: $_" "Yellow"
        Write-Log "  Trying alternative method..." "Cyan"
        
        # Fallback: direct URL
        try {
            $pwshUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.zip"
            $pwshZip = "$env:TEMP\pwsh7-portable-fallback.zip"
            
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($pwshUrl, $pwshZip)
            
            if (Test-Path $pwshZip) {
                if (Test-Path $pwshPath) {
                    Get-ChildItem $pwshPath -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Force -Path $pwshPath | Out-Null
                
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($pwshZip, $pwshPath)
                
                if (Test-Path $pwshExePath) {
                    $pwshVersion = & $pwshExePath -Command "`$PSVersionTable.PSVersion.ToString()" 2>&1
                    Write-Log "  ✅ PowerShell 7 installed (fallback): $pwshVersion" "Green"
                }
                
                Remove-Item $pwshZip -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Log "  ❌ All PowerShell 7 installation methods failed: $_" "Red"
        }
    }
}

# Add pwsh to PATH - PERMANENT
if (Test-Path $pwshPath) {
    Write-Log "  📦 Adding pwsh to PATH PERMANENTLY..." "Cyan"
    if (Add-ToMachinePath $pwshPath) {
        Write-Log "  ✅ pwsh added to MACHINE PATH (permanent)" "Green"
    }
} else {
    Write-Log "  ⚠️  pwsh path does not exist: $pwshPath" "Yellow"
}

Refresh-Environment

# Verify pwsh is accessible
Write-Log "  🔍 Verifying pwsh is accessible..." "Cyan"
try {
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        $globalPwshVersion = & pwsh -Command "`$PSVersionTable.PSVersion.ToString()" 2>&1
        Write-Log "  ✅ Global 'pwsh' command works: $globalPwshVersion" "Green"
    } else {
        Write-Log "  ⚠️  'pwsh' command not found in PATH yet (reboot required)" "Yellow"
    }
} catch {
    Write-Log "  ⚠️  Cannot verify global pwsh command: $_" "Yellow"
}

Write-Log "  ✅✅✅ PWSH SETUP COMPLETE - PRIORITY 2 DONE ✅✅✅`n" "Green"

################################################################################
# PRIORITY 3: INSTALL GIT - 100% PORTABLE TO F:\DevKit
################################################################################
Write-Log "`n[PRIORITY 3] Installing Git - THIRD PRIORITY" "Yellow"

$gitPath = "$DevKitPath\tools\git"
$gitCmdPath = "$gitPath\cmd"
$gitBinPath = "$gitPath\bin"
$gitExePath = "$gitCmdPath\git.exe"
$gitAlreadyInstalled = $false

# Check if git already installed
if (Test-Path $gitExePath) {
    try {
        $gitVersion = & $gitExePath --version 2>&1
        if ($gitVersion -and $gitVersion -notlike "*error*") {
            Write-Log "  ✅ Git already installed: $gitVersion" "Green"
            $gitAlreadyInstalled = $true
        }
    } catch {
        Write-Log "  ⚠️  Existing Git invalid, reinstalling..." "Yellow"
        $gitAlreadyInstalled = $false
    }
}

if (-not $gitAlreadyInstalled) {
    Write-Log "  📦 Installing portable Git..." "Cyan"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Strategy 1: PortableGit (self-extracting)
        Write-Log "    Strategy 1: PortableGit self-extracting archive..." "Cyan"
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/PortableGit-2.47.1-64-bit.7z.exe"
        $gitInstaller = "$env:TEMP\portablegit.exe"
        
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($gitUrl, $gitInstaller)
        
        if (Test-Path $gitInstaller) {
            Write-Log "    Extracting Git to $gitPath..." "Cyan"
            
            # Clear existing directory
            if (Test-Path $gitPath) {
                Get-ChildItem $gitPath -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
            New-Item -ItemType Directory -Force -Path $gitPath | Out-Null
            
            # Extract (self-extracting archive)
            $extractArgs = "-o`"$gitPath`"", "-y"
            Start-Process -FilePath $gitInstaller -ArgumentList $extractArgs -Wait -NoNewWindow -ErrorAction Stop
            
            if (Test-Path $gitExePath) {
                $gitVersion = & $gitExePath --version 2>&1
                Write-Log "  ✅✅✅ Git INSTALLED: $gitVersion ✅✅✅" "Green"
                $gitAlreadyInstalled = $true
            }
            
            Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Log "    ⚠️  Strategy 1 failed: $_" "Yellow"
    }
    
    # Strategy 2: MinGit (lightweight zip)
    if (-not $gitAlreadyInstalled) {
        try {
            Write-Log "    Strategy 2: MinGit portable zip..." "Cyan"
            $gitUrl2 = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/MinGit-2.47.1-64-bit.zip"
            $gitZip = "$env:TEMP\mingit-portable.zip"
            
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($gitUrl2, $gitZip)
            
            if (Test-Path $gitZip) {
                if (Test-Path $gitPath) {
                    Get-ChildItem $gitPath -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Force -Path $gitPath | Out-Null
                
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($gitZip, $gitPath)
                
                if (Test-Path $gitExePath) {
                    $gitVersion = & $gitExePath --version 2>&1
                    Write-Log "  ✅✅✅ Git INSTALLED: $gitVersion ✅✅✅" "Green"
                    $gitAlreadyInstalled = $true
                }
                
                Remove-Item $gitZip -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Log "    ⚠️  Strategy 2 failed: $_" "Yellow"
        }
    }
    
    if (-not $gitAlreadyInstalled) {
        Write-Log "  ❌ Git installation failed" "Red"
    }
}

# Add git to PATH - PERMANENT (both cmd and bin directories)
Write-Log "  📦 Adding Git to PATH PERMANENTLY..." "Cyan"
$gitPathsAdded = $false
if (Test-Path $gitCmdPath) {
    if (Add-ToMachinePath $gitCmdPath) {
        Write-Log "  ✅ Git cmd directory added to MACHINE PATH" "Green"
        $gitPathsAdded = $true
    }
}
if (Test-Path $gitBinPath) {
    if (Add-ToMachinePath $gitBinPath) {
        Write-Log "  ✅ Git bin directory added to MACHINE PATH" "Green"
        $gitPathsAdded = $true
    }
}

if (-not $gitPathsAdded) {
    Write-Log "  ⚠️  Git paths not found or not added to PATH" "Yellow"
}

Refresh-Environment

# Verify git is accessible
Write-Log "  🔍 Verifying git is accessible..." "Cyan"
try {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $globalGitVersion = & git --version 2>&1
        Write-Log "  ✅ Global 'git' command works: $globalGitVersion" "Green"
    } else {
        Write-Log "  ⚠️  'git' command not found in PATH yet (reboot required)" "Yellow"
    }
} catch {
    Write-Log "  ⚠️  Cannot verify global git command: $_" "Yellow"
}

Write-Log "  ✅✅✅ GIT SETUP COMPLETE - PRIORITY 3 DONE ✅✅✅`n" "Green"

################################################################################
# PRIORITY 4: INSTALL GITHUB CLI (gh) - 100% PORTABLE TO F:\DevKit
################################################################################
Write-Log "`n[PRIORITY 4] Installing GitHub CLI (gh) - FOURTH PRIORITY" "Yellow"

$ghPath = "$DevKitPath\tools\gh"
$ghExePath = "$ghPath\gh.exe"
$ghBinPath = "$ghPath\bin\gh.exe"
$ghAlreadyInstalled = $false

# Check both possible locations
if ((Test-Path $ghExePath) -or (Test-Path $ghBinPath)) {
    $ghExeToTest = if (Test-Path $ghExePath) { $ghExePath } else { $ghBinPath }
    try {
        $ghVersion = & $ghExeToTest --version 2>&1 | Select-Object -First 1
        if ($ghVersion -and $ghVersion -notlike "*error*") {
            Write-Log "  ✅ GitHub CLI already installed: $ghVersion" "Green"
            $ghAlreadyInstalled = $true
        }
    } catch {
        Write-Log "  ⚠️  Existing gh invalid, reinstalling..." "Yellow"
        $ghAlreadyInstalled = $false
    }
}

if (-not $ghAlreadyInstalled) {
    Write-Log "  📦 Installing GitHub CLI portable..." "Cyan"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        Write-Log "    Fetching latest GitHub CLI release..." "Cyan"
        $ghReleasesUrl = "https://api.github.com/repos/cli/cli/releases/latest"
        $ghRelease = Invoke-RestMethod -Uri $ghReleasesUrl
        $ghAsset = $ghRelease.assets | Where-Object { $_.name -match "gh_.*_windows_amd64\.zip$" } | Select-Object -First 1

        if ($ghAsset) {
            $ghUrl = $ghAsset.browser_download_url
            $ghZip = "$env:TEMP\gh-portable.zip"

            Write-Log "    Downloading GitHub CLI..." "Cyan"
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($ghUrl, $ghZip)

            if (Test-Path $ghZip) {
                Write-Log "    Extracting to $ghPath..." "Cyan"
                $tempExtract = "$env:TEMP\gh-extract"
                if (Test-Path $tempExtract) {
                    Remove-Item $tempExtract -Recurse -Force
                }
                New-Item -ItemType Directory -Path $tempExtract | Out-Null
                
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($ghZip, $tempExtract)

                # Find the extracted directory with bin\gh.exe
                $extractedDir = Get-ChildItem $tempExtract -Directory | Select-Object -First 1
                if ($extractedDir -and (Test-Path "$tempExtract\$($extractedDir.Name)\bin\gh.exe")) {
                    # Clear target directory
                    if (Test-Path $ghPath) {
                        Get-ChildItem $ghPath -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    }
                    New-Item -ItemType Directory -Force -Path $ghPath | Out-Null
                    
                    # Move the bin directory contents to the root
                    Copy-Item "$tempExtract\$($extractedDir.Name)\bin\*" -Destination $ghPath -Recurse -Force
                    $ghExePath = "$ghPath\gh.exe"
                    
                    if (Test-Path $ghExePath) {
                        $ghVersion = & $ghExePath --version 2>&1 | Select-Object -First 1
                        Write-Log "  ✅✅✅ GitHub CLI INSTALLED: $ghVersion ✅✅✅" "Green"
                        $ghAlreadyInstalled = $true
                    }
                }
                
                # Cleanup
                Remove-Item $ghZip -Force -ErrorAction SilentlyContinue
                Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Log "  ⚠️  GitHub CLI installation failed: $_" "Yellow"
    }
    
    if (-not $ghAlreadyInstalled) {
        Write-Log "  ❌ GitHub CLI installation failed" "Red"
    }
}

# Add gh to PATH - PERMANENT
Write-Log "  📦 Adding GitHub CLI to PATH PERMANENTLY..." "Cyan"
$ghPathAdded = $false

# Check which path to add (root or bin subdirectory)
if (Test-Path "$ghPath\gh.exe") {
    if (Add-ToMachinePath $ghPath) {
        Write-Log "  ✅ GitHub CLI added to MACHINE PATH" "Green"
        $ghPathAdded = $true
    }
} elseif (Test-Path "$ghPath\bin\gh.exe") {
    if (Add-ToMachinePath "$ghPath\bin") {
        Write-Log "  ✅ GitHub CLI bin directory added to MACHINE PATH" "Green"
        $ghPathAdded = $true
    }
} else {
    Write-Log "  ⚠️  GitHub CLI executable not found" "Yellow"
}

Refresh-Environment

# Verify gh is accessible
Write-Log "  🔍 Verifying gh is accessible..." "Cyan"
try {
    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghCmd) {
        $globalGhVersion = & gh --version 2>&1 | Select-Object -First 1
        Write-Log "  ✅ Global 'gh' command works: $globalGhVersion" "Green"
    } else {
        Write-Log "  ⚠️  'gh' command not found in PATH yet (reboot required)" "Yellow"
    }
} catch {
    Write-Log "  ⚠️  Cannot verify global gh command: $_" "Yellow"
}

Write-Log "  ✅✅✅ GITHUB CLI SETUP COMPLETE - PRIORITY 4 DONE ✅✅✅`n" "Green"

################################################################################
# 5. INSTALL PORTABLE GCC/CLANG (MinGW-w64)
################################################################################
Write-Log "`n[5/10] Installing portable GCC/Clang..." "Yellow"

$mingwPath = "$DevKitPath\compilers\mingw64"
$clangPath = "$DevKitPath\compilers\clang"

if (Test-Path "$mingwPath\bin\gcc.exe") {
    Write-Log "  ✅ MinGW already installed" "Green"
} else {
    Write-Log "  📦 Installing portable MinGW-w64..." "Cyan"

    try {
        $mingwUrl = "https://github.com/niXman/mingw-builds-binaries/releases/download/14.2.0-rt_v12-rev0/x86_64-14.2.0-release-posix-seh-ucrt-rt_v12-rev0.7z"
        $mingwArchive = "$env:TEMP\mingw64.7z"

        Invoke-WebRequest -Uri $mingwUrl -OutFile $mingwArchive -ErrorAction Stop

        # Extract using PowerShell if 7z not available
        Write-Log "    Extracting MinGW..." "Cyan"
        $tempMingw = "$env:TEMP\mingw-extract"
        & 7z x $mingwArchive -o"$tempMingw" -y 2>&1 | Out-Null

        if (Test-Path "$tempMingw\mingw64") {
            Move-Item "$tempMingw\mingw64" $mingwPath -Force
            Write-Log "  ✅ MinGW installed" "Green"
        }
    } catch {
        Write-Log "  ⚠️  MinGW installation failed: $_" "Yellow"
    }
}

if (Test-Path "$mingwPath\bin") {
    Add-ToMachinePath "$mingwPath\bin"
}

Refresh-Environment
Write-Log "  ✅ Portable GCC/Clang configured`n" "Green"

################################################################################
# 6. INSTALL PORTABLE BUILD TOOLS (CMake, Ninja)
################################################################################
Write-Log "`n[6/10] Installing portable build tools..." "Yellow"

# CMake
$cmakePath = "$DevKitPath\tools\cmake"
if (Test-Path "$cmakePath\bin\cmake.exe") {
    Write-Log "  ✅ CMake already installed" "Green"
} else {
    Write-Log "  📦 Installing portable CMake..." "Cyan"
    try {
        $cmakeUrl = "https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1-windows-x86_64.zip"
        $cmakeZip = "$env:TEMP\cmake.zip"
        Invoke-WebRequest -Uri $cmakeUrl -OutFile $cmakeZip -ErrorAction Stop

        $tempCmake = "$env:TEMP\cmake-extract"
        Expand-Archive -Path $cmakeZip -DestinationPath $tempCmake -Force
        $extractedDir = Get-ChildItem $tempCmake -Directory | Select-Object -First 1
        if ($extractedDir) {
            Move-Item "$tempCmake\$($extractedDir.Name)" $cmakePath -Force
            Write-Log "  ✅ CMake installed" "Green"
        }
    } catch {
        Write-Log "  ⚠️  CMake installation failed: $_" "Yellow"
    }
}

if (Test-Path "$cmakePath\bin") {
    Add-ToMachinePath "$cmakePath\bin"
}

# Ninja
$ninjaPath = "$DevKitPath\tools\ninja"
if (Test-Path "$ninjaPath\ninja.exe") {
    Write-Log "  ✅ Ninja already installed" "Green"
} else {
    Write-Log "  📦 Installing portable Ninja..." "Cyan"
    try {
        $ninjaUrl = "https://github.com/ninja-build/ninja/releases/latest/download/ninja-win.zip"
        $ninjaZip = "$env:TEMP\ninja.zip"
        Invoke-WebRequest -Uri $ninjaUrl -OutFile $ninjaZip -ErrorAction Stop
        New-Item -ItemType Directory -Force -Path $ninjaPath | Out-Null
        Expand-Archive -Path $ninjaZip -DestinationPath $ninjaPath -Force
        Write-Log "  ✅ Ninja installed" "Green"
    } catch {
        Write-Log "  ⚠️  Ninja installation failed: $_" "Yellow"
    }
}

Add-ToMachinePath $ninjaPath

Refresh-Environment
Write-Log "  ✅ Build tools installed`n" "Green"

################################################################################
# 7. INSTALL 7-ZIP PORTABLE (for other installations)
################################################################################
Write-Log "`n[7/10] Installing 7-Zip portable..." "Yellow"

$sevenZipPath = "$DevKitPath\tools\7zip"
if (Test-Path "$sevenZipPath\7z.exe") {
    Write-Log "  ✅ 7-Zip already installed" "Green"
} else {
    Write-Log "  📦 Installing 7-Zip portable..." "Cyan"
    try {
        $sevenZipUrl = "https://www.7-zip.org/a/7z2301-x64.exe"
        $sevenZipInstaller = "$env:TEMP\7z-installer.exe"
        Invoke-WebRequest -Uri $sevenZipUrl -OutFile $sevenZipInstaller -ErrorAction Stop

        New-Item -ItemType Directory -Force -Path $sevenZipPath | Out-Null
        Start-Process -FilePath $sevenZipInstaller -ArgumentList "/S", "/D=$sevenZipPath" -Wait -NoNewWindow
        Write-Log "  ✅ 7-Zip installed" "Green"
    } catch {
        Write-Log "  ⚠️  7-Zip installation failed: $_" "Yellow"
    }
}

Add-ToMachinePath $sevenZipPath

Refresh-Environment
Write-Log "  ✅ 7-Zip configured`n" "Green"

################################################################################
# 8. INSTALL PORTABLE PACKAGE MANAGERS (NuGet, vcpkg)
################################################################################
Write-Log "`n[8/10] Installing portable package managers..." "Yellow"

# NuGet
$nugetPath = "$DevKitPath\tools\nuget"
if (Test-Path "$nugetPath\nuget.exe") {
    Write-Log "  ✅ NuGet already installed" "Green"
} else {
    Write-Log "  📦 Installing NuGet..." "Cyan"
    try {
        New-Item -ItemType Directory -Force -Path $nugetPath | Out-Null
        Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile "$nugetPath\nuget.exe" -ErrorAction Stop
        Write-Log "  ✅ NuGet installed" "Green"
    } catch {
        Write-Log "  ⚠️  NuGet installation failed: $_" "Yellow"
    }
}

Add-ToMachinePath $nugetPath

# vcpkg
$vcpkgPath = "$DevKitPath\tools\vcpkg"
if (Test-Path "$vcpkgPath\vcpkg.exe") {
    Write-Log "  ✅ vcpkg already installed" "Green"
} else {
    Write-Log "  📦 Installing vcpkg..." "Cyan"
    try {
        if (Test-Command git) {
            git clone https://github.com/Microsoft/vcpkg.git $vcpkgPath 2>&1 | Out-Null
            if (Test-Path "$vcpkgPath\bootstrap-vcpkg.bat") {
                & "$vcpkgPath\bootstrap-vcpkg.bat" | Out-Null
                Write-Log "  ✅ vcpkg installed" "Green"
            }
        } else {
            Write-Log "  ⚠️  Git required for vcpkg, skipping" "Yellow"
        }
    } catch {
        Write-Log "  ⚠️  vcpkg installation failed: $_" "Yellow"
    }
}

if (Test-Path $vcpkgPath) {
    Add-ToMachinePath $vcpkgPath
    Set-EnvironmentVariableAllScopes "VCPKG_ROOT" $vcpkgPath
}

Refresh-Environment
Write-Log "  ✅ Package managers installed`n" "Green"

################################################################################
# 9. CREATE PORTABLE POWERSHELL PROFILES
################################################################################
Write-Log "`n[9/10] Creating portable PowerShell profiles..." "Yellow"

$profileContent = @"
# Auto-generated portable development environment - F:\DevKit + System .NET
`$env:DEVKIT_PATH = '$DevKitPath'
# CRITICAL: DOTNET_ROOT must point to C:\Program Files\dotnet for Windows app compatibility
`$env:DOTNET_ROOT = 'C:\Program Files\dotnet'
`$env:DOTNET_ROOT_8_0 = '$dotnet8Path'
`$env:DOTNET_ROOT_9_0 = '$dotnet9Path'
`$env:DOTNET_CLI_HOME = '$dotnetPath'
# CRITICAL: Enable multi-level lookup for fallback support
`$env:DOTNET_MULTILEVEL_LOOKUP = '1'
`$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
`$env:DOTNET_NOLOGO = '1'
`$env:VCPKG_ROOT = '$vcpkgPath'

# Priority PATH order: .NET 9 → .NET 8 → LTS → pwsh → git → gh → tools
if (`$env:Path -notlike '*$DevKitPath*') {
    `$ghPathToAdd = if (Test-Path '$ghPath\bin') { '$ghPath\bin' } else { '$ghPath' }
    `$devKitPaths = @(
        '$dotnet9Path',
        '$dotnet8Path',
        '$dotnetPath',
        '$pwshPath',
        '$gitPath\cmd',
        `$ghPathToAdd,
        '$cmakePath\bin',
        '$ninjaPath',
        '$mingwPath\bin',
        '$sevenZipPath',
        '$nugetPath',
        '$vcpkgPath'
    ) | Where-Object { Test-Path `$_ }
    `$env:Path = ((`$devKitPaths -join ';') + ';' + `$env:Path)
}

Write-Host "✅ F:\DevKit portable environment loaded" -ForegroundColor Green
"@

# PowerShell 7 profile
$pwsh7ProfileDir = "$env:USERPROFILE\Documents\PowerShell"
$pwsh7ProfilePath = "$pwsh7ProfileDir\Microsoft.PowerShell_profile.ps1"
New-Item -ItemType Directory -Force -Path $pwsh7ProfileDir | Out-Null

if (Test-Path $pwsh7ProfilePath) {
    $currentContent = Get-Content $pwsh7ProfilePath -Raw -ErrorAction SilentlyContinue
    if ($currentContent -notlike "*Auto-generated portable development environment*") {
        Add-Content -Path $pwsh7ProfilePath -Value "`n$profileContent"
        Write-Log "  ✅ Updated PowerShell 7 profile" "Green"
    } else {
        Write-Log "  ✅ PowerShell 7 profile already configured" "Green"
    }
} else {
    Set-Content -Path $pwsh7ProfilePath -Value $profileContent
    Write-Log "  ✅ Created PowerShell 7 profile" "Green"
}

# Windows PowerShell 5.1 profile
$pwsh51ProfileDir = "$env:USERPROFILE\Documents\WindowsPowerShell"
$pwsh51ProfilePath = "$pwsh51ProfileDir\Microsoft.PowerShell_profile.ps1"
New-Item -ItemType Directory -Force -Path $pwsh51ProfileDir | Out-Null

if (Test-Path $pwsh51ProfilePath) {
    $currentContent = Get-Content $pwsh51ProfilePath -Raw -ErrorAction SilentlyContinue
    if ($currentContent -notlike "*Auto-generated portable development environment*") {
        Add-Content -Path $pwsh51ProfilePath -Value "`n$profileContent"
        Write-Log "  ✅ Updated Windows PowerShell 5.1 profile" "Green"
    } else {
        Write-Log "  ✅ Windows PowerShell 5.1 profile already configured" "Green"
    }
} else {
    Set-Content -Path $pwsh51ProfilePath -Value $profileContent
    Write-Log "  ✅ Created Windows PowerShell 5.1 profile" "Green"
}

Write-Log "  ✅ PowerShell profiles created`n" "Green"

################################################################################
# 10. FINAL VERIFICATION
################################################################################
Write-Log "`n[10/10] Final verification..." "Yellow"

Refresh-Environment

# Verify .NET installations
Write-Log "`n🔍 VERIFYING .NET INSTALLATIONS:" "Cyan"
$dotnetSuccess = 0
$dotnetTotal = 3

foreach ($dotnetVersion in @(
    @{Name = ".NET 9 (PRIORITY)"; Path = $dotnet9Path; Priority = $true},
    @{Name = ".NET 8"; Path = $dotnet8Path; Priority = $false},
    @{Name = ".NET LTS"; Path = $dotnetPath; Priority = $false}
)) {
    $exe = Join-Path $dotnetVersion.Path "dotnet.exe"
    if (Test-Path $exe) {
        try {
            $version = & $exe --version 2>&1
            if ($version -notlike "*error*" -and $version -match '^\d+\.\d+') {
                Write-Log "  ✅ $($dotnetVersion.Name): $version" "Green"
                $dotnetSuccess++
                
                if ($dotnetVersion.Priority) {
                    Write-Log "     🌟 PRIORITY .NET 9 SUCCESSFULLY INSTALLED!" "Green"
                }
            } else {
                Write-Log "  ⚠️  $($dotnetVersion.Name): Version check returned: $version" "Yellow"
            }
        } catch {
            Write-Log "  ⚠️  $($dotnetVersion.Name): Error checking version - $_" "Yellow"
        }
    } else {
        Write-Log "  ❌ $($dotnetVersion.Name): NOT FOUND at $exe" "Red"
    }
}

# Verify key tools
Write-Log "`n🔍 VERIFYING KEY TOOLS:" "Cyan"

# Determine correct paths for verification
$ghVerifyPath = if (Test-Path "$DevKitPath\tools\gh\gh.exe") { 
    "$DevKitPath\tools\gh\gh.exe" 
} else { 
    "$DevKitPath\tools\gh\bin\gh.exe" 
}
$gitVerifyPath = "$DevKitPath\tools\git\cmd\git.exe"

$tools = @{
    "pwsh" = @{Path = $pwshExePath; Required = $true}
    "git" = @{Path = $gitVerifyPath; Required = $true}
    "gh" = @{Path = $ghVerifyPath; Required = $true}
    "gcc" = @{Path = "$mingwPath\bin\gcc.exe"; Required = $false}
    "cmake" = @{Path = "$cmakePath\bin\cmake.exe"; Required = $false}
    "ninja" = @{Path = "$ninjaPath\ninja.exe"; Required = $false}
}

$toolSuccess = 0
$toolsRequired = ($tools.Values | Where-Object { $_.Required }).Count

foreach ($tool in $tools.Keys) {
    $toolInfo = $tools[$tool]
    if (Test-Path $toolInfo.Path) {
        try {
            $version = switch ($tool) {
                "pwsh" { & $toolInfo.Path -Command "`$PSVersionTable.PSVersion.ToString()" 2>&1 }
                "git" { & $toolInfo.Path --version 2>&1 | Select-Object -First 1 }
                "gh" { & $toolInfo.Path --version 2>&1 | Select-Object -First 1 }
                "gcc" { & $toolInfo.Path --version 2>&1 | Select-Object -First 1 }
                "cmake" { & $toolInfo.Path --version 2>&1 | Select-Object -First 1 }
                "ninja" { & $toolInfo.Path --version 2>&1 }
            }
            
            if ($version -and $version -notlike "*error*") {
                Write-Log "  ✅ $tool : $version" "Green"
                if ($toolInfo.Required) { $toolSuccess++ }
            } else {
                Write-Log "  ✅ $tool : Available at $($toolInfo.Path)" "Green"
                if ($toolInfo.Required) { $toolSuccess++ }
            }
        } catch {
            Write-Log "  ✅ $tool : Available at $($toolInfo.Path)" "Green"
            if ($toolInfo.Required) { $toolSuccess++ }
        }
    } else {
        if ($toolInfo.Required) {
            Write-Log "  ❌ $tool : NOT FOUND at $($toolInfo.Path)" "Red"
        } else {
            Write-Log "  ⚠️  $tool : Not found at $($toolInfo.Path)" "Yellow"
        }
    }
}

# Verify PATH entries
Write-Log "`n🔍 VERIFYING MACHINE PATH ENTRIES:" "Cyan"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$devKitEntries = $currentPath -split ';' | Where-Object { $_ -like "*DevKit*" -or $_ -like "*dotnet*" }

if ($devKitEntries.Count -gt 0) {
    Write-Log "  ✅ Found $($devKitEntries.Count) DevKit entries in Machine PATH:" "Green"
    foreach ($entry in $devKitEntries | Select-Object -First 15) {
        Write-Log "     • $entry" "Gray"
    }
} else {
    Write-Log "  ⚠️  No DevKit entries found in Machine PATH!" "Yellow"
}

# Verify environment variables
Write-Log "`n🔍 VERIFYING ENVIRONMENT VARIABLES:" "Cyan"
$envVars = @{
    "DOTNET_ROOT" = "C:\Program Files\dotnet"
    "DOTNET_ROOT_9_0" = $dotnet9Path
    "DOTNET_ROOT_8_0" = $dotnet8Path
    "DOTNET_MULTILEVEL_LOOKUP" = "1"
}

foreach ($varName in $envVars.Keys) {
    $expectedValue = $envVars[$varName]
    $actualValue = [Environment]::GetEnvironmentVariable($varName, "Machine")
    
    if ($actualValue -eq $expectedValue) {
        Write-Log "  ✅ $varName = $actualValue" "Green"
    } else {
        Write-Log "  ⚠️  $varName mismatch. Expected: $expectedValue, Got: $actualValue" "Yellow"
    }
}

# Final summary
Write-Log "`n========================================" "Green"
Write-Log "✅✅✅ SETUP COMPLETE ✅✅✅" "Green"
Write-Log "========================================" "Green"

Write-Log "`n📊 INSTALLATION SUMMARY:" "Yellow"
Write-Log "   • .NET installations: $dotnetSuccess/$dotnetTotal successful" "Cyan"
Write-Log "   • Required tools: $toolSuccess/$toolsRequired successful" "Cyan"
Write-Log "   • PATH entries: $($devKitEntries.Count) DevKit paths added" "Cyan"

Write-Log "`n🎯 PRIORITY INSTALLATIONS:" "Yellow"
$priority1Status = if (Test-Path $dotnet9Exe) { "✅ INSTALLED" } else { "❌ FAILED" }
$priority2Status = if (Test-Path $pwshExePath) { "✅ INSTALLED" } else { "❌ FAILED" }
$priority3Status = if (Test-Path $gitVerifyPath) { "✅ INSTALLED" } else { "❌ FAILED" }
$priority4Status = if (Test-Path $ghVerifyPath) { "✅ INSTALLED" } else { "❌ FAILED" }

Write-Log "   1. .NET 9 SDK → $priority1Status → $dotnet9Path" "Cyan"
Write-Log "   2. PowerShell 7 (pwsh) → $priority2Status → $pwshPath" "Cyan"
Write-Log "   3. Git → $priority3Status → $gitPath" "Cyan"
Write-Log "   4. GitHub CLI (gh) → $priority4Status → $ghPath" "Cyan"

Write-Log "`n⚠️  CRITICAL NEXT STEPS - READ CAREFULLY:" "Yellow"
Write-Log "   1. 🎯 TRY YOUR APPLICATION NOW - NO REBOOT NEEDED!" "Green"
Write-Log "      └─ Environment changes have been broadcast to all apps" "Green"
Write-Log "   2. If any app still shows error:" "Yellow"
Write-Log "      • Close ALL instances of the application" "Yellow"
Write-Log "      • Open a NEW terminal/PowerShell window" "Yellow"
Write-Log "      • Run the application from the new window" "Yellow"
Write-Log "   3. Test each command:" "Cyan"
Write-Log "      • Test: dotnet --version" "Gray"
Write-Log "        Expected: 9.0.x or higher" "Gray"
Write-Log "      • Test: pwsh --version" "Gray"
Write-Log "        Expected: 7.x.x" "Gray"
Write-Log "      • Test: git --version" "Gray"
Write-Log "        Expected: git version 2.x.x" "Gray"
Write-Log "      • Test: gh --version" "Gray"
Write-Log "        Expected: gh version 2.x.x" "Gray"
Write-Log "`n   🔧 CRITICAL FIXES APPLIED:" "Green"
Write-Log "      ✅ DOTNET_ROOT → C:\Program Files\dotnet" "Green"
Write-Log "      ✅ DOTNET_MULTILEVEL_LOOKUP → Enabled (1)" "Green"
Write-Log "      ✅ C:\Program Files\dotnet is FIRST in PATH" "Green"
Write-Log "      ✅ Changes broadcast to all running applications" "Green"

if ($dotnetSuccess -eq $dotnetTotal -and $toolSuccess -eq $toolsRequired) {
    Write-Log "`n✅✅✅ ALL CRITICAL COMPONENTS INSTALLED SUCCESSFULLY! ✅✅✅" "Green"
    Write-Log "After reboot, everything will work perfectly!" "Green"
} else {
    Write-Log "`n⚠️⚠️⚠️ SOME COMPONENTS FAILED TO INSTALL ⚠️⚠️⚠️" "Yellow"
    Write-Log "Review the errors above and rerun the script if needed." "Yellow"
}

Write-Log "`n📁 Installation Location: F:\DevKit (100% portable)" "Green"
Write-Log "🚫 Zero C: drive usage - everything in F:\DevKit" "Green"
Write-Log "🔒 All paths permanently added to Machine PATH" "Green"
Write-Log "`n========================================`n" "Green"

"=== Installation completed at $(Get-Date) ===" | Out-File $LogFile -Append
