#Requires -RunAsAdministrator
################################################################################
# COMPLETE DEVELOPMENT ENVIRONMENT SETUP - BULLETPROOF VERSION
# Installs: MSVC, MinGW (gcc/g++/clang), Build Tools, .NET (portable)
# Target: F:\DevKit (external drive)
# Compatible: PowerShell 5.1, 7.x, and all future versions
# Smart: Skips already installed components
################################################################################

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "COMPLETE DEVELOPMENT ENVIRONMENT SETUP" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Configuration
$DevKitPath = "F:\DevKit"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

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
# 1. CHECK AND INSTALL CHOCOLATEY
################################################################################
Write-Host "[1/7] Checking Chocolatey..." -ForegroundColor Yellow
if (Test-Command choco) {
    Write-Host "  ✅ Chocolatey already installed" -ForegroundColor Green
} else {
    Write-Host "  📦 Installing Chocolatey..." -ForegroundColor Cyan
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    Write-Host "  ✅ Chocolatey installed" -ForegroundColor Green
}

################################################################################
# 2. CHECK AND INSTALL MSVC (cl.exe)
################################################################################
Write-Host "`n[2/7] Checking MSVC (cl.exe)..." -ForegroundColor Yellow

# Reload environment
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
$env:INCLUDE = [Environment]::GetEnvironmentVariable("INCLUDE", "Machine")
$env:LIB = [Environment]::GetEnvironmentVariable("LIB", "Machine")

if (Test-Command cl) {
    Write-Host "  ✅ MSVC already installed and in PATH" -ForegroundColor Green
} else {
    $vswherePath = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    $vsPath = $null
    if (Test-Path $vswherePath) {
        $vsPath = & $vswherePath -latest -products "*" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    }

    if ($vsPath -and (Test-Path $vsPath)) {
        Write-Host "  📦 MSVC installed but not in PATH, configuring..." -ForegroundColor Cyan

        # Find MSVC version
        $msvcPath = "$vsPath\VC\Tools\MSVC"
        $latestMSVC = Get-ChildItem $msvcPath | Sort-Object Name -Descending | Select-Object -First 1
        $msvcVersion = $latestMSVC.Name
        $msvcBinPath = "$msvcPath\$msvcVersion\bin\Hostx64\x64"

        # Find Windows SDK
        $windowsKitsPath = "C:\Program Files (x86)\Windows Kits\10"
        $sdkVersion = Get-ChildItem "$windowsKitsPath\bin" -Directory |
            Where-Object { $_.Name -match '^\d+\.' } |
            Sort-Object Name -Descending |
            Select-Object -First 1 -ExpandProperty Name

        # Update PATH
        Add-ToMachinePath $msvcBinPath
        Add-ToMachinePath "$windowsKitsPath\bin\$sdkVersion\x64"

        # Set INCLUDE
        $includePaths = @(
            "$vsPath\VC\Tools\MSVC\$msvcVersion\include",
            "$windowsKitsPath\include\$sdkVersion\ucrt",
            "$windowsKitsPath\include\$sdkVersion\um",
            "$windowsKitsPath\include\$sdkVersion\shared"
        )
        $includeValue = ($includePaths | Where-Object { Test-Path $_ }) -join ';'
        [Environment]::SetEnvironmentVariable("INCLUDE", $includeValue, "Machine")

        # Set LIB
        $libPaths = @(
            "$vsPath\VC\Tools\MSVC\$msvcVersion\lib\x64",
            "$windowsKitsPath\lib\$sdkVersion\ucrt\x64",
            "$windowsKitsPath\lib\$sdkVersion\um\x64"
        )
        $libValue = ($libPaths | Where-Object { Test-Path $_ }) -join ';'
        [Environment]::SetEnvironmentVariable("LIB", $libValue, "Machine")

        # Reload environment
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        $env:INCLUDE = [Environment]::GetEnvironmentVariable("INCLUDE", "Machine")
        $env:LIB = [Environment]::GetEnvironmentVariable("LIB", "Machine")

        Write-Host "  ✅ MSVC configured" -ForegroundColor Green
    } else {
        Write-Host "  📦 Installing Visual Studio Build Tools..." -ForegroundColor Cyan
        choco install visualstudio2022buildtools --package-parameters "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive" -y

        # Wait and configure
        Start-Sleep -Seconds 5
        $vsPath = & $vswherePath -latest -products "*" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if ($vsPath) {
            $msvcPath = "$vsPath\VC\Tools\MSVC"
            $latestMSVC = Get-ChildItem $msvcPath | Sort-Object Name -Descending | Select-Object -First 1
            $msvcVersion = $latestMSVC.Name

            $windowsKitsPath = "C:\Program Files (x86)\Windows Kits\10"
            $sdkVersion = Get-ChildItem "$windowsKitsPath\bin" -Directory |
                Where-Object { $_.Name -match '^\d+\.' } |
                Sort-Object Name -Descending |
                Select-Object -First 1 -ExpandProperty Name

            Add-ToMachinePath "$msvcPath\$msvcVersion\bin\Hostx64\x64"
            Add-ToMachinePath "$windowsKitsPath\bin\$sdkVersion\x64"

            $includePaths = @(
                "$vsPath\VC\Tools\MSVC\$msvcVersion\include",
                "$windowsKitsPath\include\$sdkVersion\ucrt",
                "$windowsKitsPath\include\$sdkVersion\um",
                "$windowsKitsPath\include\$sdkVersion\shared"
            )
            $includeValue = ($includePaths | Where-Object { Test-Path $_ }) -join ';'
            [Environment]::SetEnvironmentVariable("INCLUDE", $includeValue, "Machine")

            $libPaths = @(
                "$vsPath\VC\Tools\MSVC\$msvcVersion\lib\x64",
                "$windowsKitsPath\lib\$sdkVersion\ucrt\x64",
                "$windowsKitsPath\lib\$sdkVersion\um\x64"
            )
            $libValue = ($libPaths | Where-Object { Test-Path $_ }) -join ';'
            [Environment]::SetEnvironmentVariable("LIB", $libValue, "Machine")

            $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
            $env:INCLUDE = [Environment]::GetEnvironmentVariable("INCLUDE", "Machine")
            $env:LIB = [Environment]::GetEnvironmentVariable("LIB", "Machine")
        }
        Write-Host "  ✅ MSVC installed" -ForegroundColor Green
    }
}

################################################################################
# 3. CHECK AND INSTALL MSYS2/MinGW
################################################################################
Write-Host "`n[3/7] Checking MSYS2/MinGW..." -ForegroundColor Yellow
if ((Test-Path "$DevKitPath\msys64") -and (Test-Command gcc)) {
    Write-Host "  ✅ MSYS2/MinGW already installed" -ForegroundColor Green
} else {
    Write-Host "  📦 Installing MSYS2..." -ForegroundColor Cyan

    # Download and install MSYS2
    $msys2Installer = "$env:TEMP\msys2-x86_64-latest.exe"
    if (-not (Test-Path $msys2Installer)) {
        Invoke-WebRequest -Uri "https://github.com/msys2/msys2-installer/releases/download/nightly-x86_64/msys2-x86_64-latest.exe" -OutFile $msys2Installer
    }

    Start-Process -FilePath $msys2Installer -ArgumentList @("install", "--root", "$DevKitPath\msys64", "--confirm-command") -Wait -NoNewWindow

    # Install packages
    $msys2Bash = "$DevKitPath\msys64\usr\bin\bash.exe"
    & $msys2Bash -lc "pacman -Syu --noconfirm"
    & $msys2Bash -lc "pacman -S --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-clang mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-make"

    # Add to PATH
    Add-ToMachinePath "$DevKitPath\msys64\mingw64\bin"

    Write-Host "  ✅ MSYS2/MinGW installed" -ForegroundColor Green
}

################################################################################
# 4. INSTALL/CONFIGURE .NET - BULLETPROOF FOR ALL POWERSHELL VERSIONS
################################################################################
Write-Host "`n[4/7] Checking .NET..." -ForegroundColor Yellow

$dotnetPath = "$DevKitPath\dotnet"

# Ensure .NET is installed
if (-not (Test-Path "$dotnetPath\dotnet.exe")) {
    Write-Host "  📦 Installing .NET SDK to portable location..." -ForegroundColor Cyan

    if (Test-Path "C:\Program Files\dotnet") {
        # Copy from system installation
        New-Item -ItemType Directory -Force -Path $dotnetPath | Out-Null
        Copy-Item "C:\Program Files\dotnet\*" -Destination $dotnetPath -Recurse -Force
    } else {
        # Download and install
        $dotnetInstaller = "$env:TEMP\dotnet-install.ps1"
        Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $dotnetInstaller
        & $dotnetInstaller -InstallDir $dotnetPath -Channel LTS
    }
    Write-Host "  ✅ .NET installed" -ForegroundColor Green
} else {
    Write-Host "  ✅ .NET already installed" -ForegroundColor Green
}

# Configure .NET environment - ALL SCOPES
Write-Host "  📦 Configuring .NET environment..." -ForegroundColor Cyan

Set-EnvironmentVariableAllScopes "DOTNET_ROOT" $dotnetPath
Set-EnvironmentVariableAllScopes "DOTNET_CLI_HOME" $dotnetPath
Set-EnvironmentVariableAllScopes "DOTNET_MULTILEVEL_LOOKUP" "0"

# Add to PATH (highest priority)
Add-ToMachinePath $dotnetPath

# Reload PATH
$env:Path = "$dotnetPath;" + [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

Write-Host "  ✅ .NET environment configured" -ForegroundColor Green

################################################################################
# 5. FIX POWERSHELL 7 ASSEMBLY LOADING - PERMANENT SOLUTION
################################################################################
Write-Host "`n[5/7] Fixing PowerShell 7 assembly loading..." -ForegroundColor Yellow

$pwsh7Path = "C:\Program Files\PowerShell\7"
if (Test-Path $pwsh7Path) {
    # Solution: Copy .NET runtime DLLs to PowerShell 7's directory
    Write-Host "  📦 Ensuring PowerShell 7 can find .NET assemblies..." -ForegroundColor Cyan

    # Find the latest .NET runtime version we have
    $runtimeVersions = Get-ChildItem "$dotnetPath\shared\Microsoft.NETCore.App" -Directory | Sort-Object Name -Descending
    $latestRuntime = $runtimeVersions[0].Name

    Write-Host "  📦 Found .NET runtime version: $latestRuntime" -ForegroundColor Gray

    # Create/update the shared folder in PowerShell 7 directory
    $pwsh7Shared = "$pwsh7Path\shared\Microsoft.NETCore.App"
    if (-not (Test-Path $pwsh7Shared)) {
        New-Item -ItemType Directory -Force -Path $pwsh7Shared | Out-Null
    }

    # Check if PowerShell 7 needs a specific version
    $pwshDepsJson = "$pwsh7Path\pwsh.deps.json"
    if (Test-Path $pwshDepsJson) {
        $depsContent = Get-Content $pwshDepsJson -Raw | ConvertFrom-Json
        $requiredVersion = $depsContent.targets.PSObject.Properties.Name | Where-Object { $_ -like "*.NETCoreApp*" } | ForEach-Object {
            $_ -replace '^.*NETCoreApp,Version=v([0-9.]+).*$', '$1'
        } | Select-Object -First 1

        if ($requiredVersion) {
            Write-Host "  📦 PowerShell 7 requires .NET version: $requiredVersion.x" -ForegroundColor Gray

            # Find matching runtime
            $matchingRuntime = $runtimeVersions | Where-Object { $_.Name -like "${requiredVersion}.*" } | Select-Object -First 1

            if ($matchingRuntime) {
                Write-Host "  ✅ Found matching runtime: $($matchingRuntime.Name)" -ForegroundColor Green

                # Copy runtime DLLs to PowerShell 7
                $targetPath = "$pwsh7Shared\$($matchingRuntime.Name)"
                if (-not (Test-Path $targetPath)) {
                    New-Item -ItemType Directory -Force -Path $targetPath | Out-Null
                    Copy-Item "$dotnetPath\shared\Microsoft.NETCore.App\$($matchingRuntime.Name)\*" -Destination $targetPath -Recurse -Force
                    Write-Host "  ✅ Copied runtime DLLs to PowerShell 7" -ForegroundColor Green
                }
            } else {
                Write-Host "  ⚠️  No exact match found, copying latest runtime..." -ForegroundColor Yellow
                $targetPath = "$pwsh7Shared\$latestRuntime"
                if (-not (Test-Path $targetPath)) {
                    New-Item -ItemType Directory -Force -Path $targetPath | Out-Null
                    Copy-Item "$dotnetPath\shared\Microsoft.NETCore.App\$latestRuntime\*" -Destination $targetPath -Recurse -Force
                    Write-Host "  ✅ Copied runtime DLLs to PowerShell 7" -ForegroundColor Green
                }
            }
        }
    } else {
        # No deps.json, just copy latest
        $targetPath = "$pwsh7Shared\$latestRuntime"
        if (-not (Test-Path $targetPath)) {
            New-Item -ItemType Directory -Force -Path $targetPath | Out-Null
            Copy-Item "$dotnetPath\shared\Microsoft.NETCore.App\$latestRuntime\*" -Destination $targetPath -Recurse -Force
            Write-Host "  ✅ Copied runtime DLLs to PowerShell 7" -ForegroundColor Green
        }
    }

    Write-Host "  ✅ PowerShell 7 assembly loading fixed" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  PowerShell 7 not installed, skipping" -ForegroundColor Yellow
}

################################################################################
# 6. CREATE POWERSHELL PROFILES FOR PERSISTENT CONFIGURATION
################################################################################
Write-Host "`n[6/7] Creating PowerShell profiles..." -ForegroundColor Yellow

$profileContent = @"
# Auto-generated .NET portable configuration
# This ensures all PowerShell versions can find .NET assemblies

`$env:DOTNET_ROOT = '$dotnetPath'
`$env:DOTNET_CLI_HOME = '$dotnetPath'
`$env:DOTNET_MULTILEVEL_LOOKUP = '0'

# Ensure dotnet is in PATH
if (`$env:Path -notlike '*$dotnetPath*') {
    `$env:Path = '$dotnetPath;' + `$env:Path
}
"@

# PowerShell 7 profile
$pwsh7ProfileDir = "$env:USERPROFILE\Documents\PowerShell"
$pwsh7ProfilePath = "$pwsh7ProfileDir\Microsoft.PowerShell_profile.ps1"

if (-not (Test-Path $pwsh7ProfileDir)) {
    New-Item -ItemType Directory -Force -Path $pwsh7ProfileDir | Out-Null
}

if (Test-Path $pwsh7ProfilePath) {
    $currentContent = Get-Content $pwsh7ProfilePath -Raw
    if ($currentContent -notlike "*Auto-generated .NET portable configuration*") {
        Add-Content -Path $pwsh7ProfilePath -Value "`n$profileContent"
        Write-Host "  ✅ Updated PowerShell 7 profile" -ForegroundColor Green
    } else {
        Write-Host "  ✅ PowerShell 7 profile already configured" -ForegroundColor Green
    }
} else {
    Set-Content -Path $pwsh7ProfilePath -Value $profileContent
    Write-Host "  ✅ Created PowerShell 7 profile" -ForegroundColor Green
}

# Windows PowerShell 5.1 profile
$pwsh51ProfileDir = "$env:USERPROFILE\Documents\WindowsPowerShell"
$pwsh51ProfilePath = "$pwsh51ProfileDir\Microsoft.PowerShell_profile.ps1"

if (-not (Test-Path $pwsh51ProfileDir)) {
    New-Item -ItemType Directory -Force -Path $pwsh51ProfileDir | Out-Null
}

if (Test-Path $pwsh51ProfilePath) {
    $currentContent = Get-Content $pwsh51ProfilePath -Raw
    if ($currentContent -notlike "*Auto-generated .NET portable configuration*") {
        Add-Content -Path $pwsh51ProfilePath -Value "`n$profileContent"
        Write-Host "  ✅ Updated Windows PowerShell 5.1 profile" -ForegroundColor Green
    } else {
        Write-Host "  ✅ Windows PowerShell 5.1 profile already configured" -ForegroundColor Green
    }
} else {
    Set-Content -Path $pwsh51ProfilePath -Value $profileContent
    Write-Host "  ✅ Created Windows PowerShell 5.1 profile" -ForegroundColor Green
}

################################################################################
# 7. CHECK BUILD TOOLS
################################################################################
Write-Host "`n[7/7] Checking build tools..." -ForegroundColor Yellow
$tools = @("make", "cmake", "ninja")
$allPresent = $true
foreach ($tool in $tools) {
    if (-not (Test-Command $tool)) {
        $allPresent = $false
        break
    }
}

if ($allPresent) {
    Write-Host "  ✅ All build tools already installed" -ForegroundColor Green
} else {
    Write-Host "  📦 Installing build tools via MSYS2..." -ForegroundColor Cyan
    $msys2Bash = "$DevKitPath\msys64\usr\bin\bash.exe"
    & $msys2Bash -lc "pacman -S --noconfirm mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-make"
    Write-Host "  ✅ Build tools installed" -ForegroundColor Green
}

################################################################################
# VERIFY INSTALLATION
################################################################################
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "VERIFYING INSTALLATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Reload environment
$env:Path = "$dotnetPath;" + [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
$env:DOTNET_ROOT = $dotnetPath

$compilers = @{
    "gcc" = "gcc --version 2>&1 | Select-Object -First 1"
    "g++" = "g++ --version 2>&1 | Select-Object -First 1"
    "clang" = "clang --version 2>&1 | Select-Object -First 1"
    "cl" = "cl 2>&1 | Select-Object -First 1"
    "dotnet" = "dotnet --version 2>&1"
}

Write-Host "`nInstalled tools:" -ForegroundColor Cyan
foreach ($compiler in $compilers.Keys) {
    Write-Host "  $compiler : " -NoNewline -ForegroundColor Gray
    try {
        $version = Invoke-Expression $compilers[$compiler]
        Write-Host $version -ForegroundColor Green
    } catch {
        Write-Host "Not available (may need shell restart)" -ForegroundColor Yellow
    }
}

# Test PowerShell 7 if available
if (Test-Path "C:\Program Files\PowerShell\7\pwsh.exe") {
    Write-Host "`nTesting PowerShell 7..." -ForegroundColor Cyan
    try {
        $result = & "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -Command "`$env:DOTNET_ROOT='$dotnetPath'; `$env:Path='$dotnetPath;'+`$env:Path; dotnet --version" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ PowerShell 7 + dotnet: $result" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  PowerShell 7 output: $result" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ⚠️  PowerShell 7 test failed: $_" -ForegroundColor Yellow
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "SETUP COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`n⚠️  IMPORTANT:" -ForegroundColor Yellow
Write-Host "   1. Close ALL PowerShell windows" -ForegroundColor Cyan
Write-Host "   2. Open a NEW PowerShell window" -ForegroundColor Cyan
Write-Host "   3. Test with: dotnet --version" -ForegroundColor Cyan
Write-Host "   4. Test with: gcc --version" -ForegroundColor Cyan
Write-Host "   5. Test PowerShell 7: pwsh -Command 'dotnet --version'" -ForegroundColor Cyan
Write-Host ""
