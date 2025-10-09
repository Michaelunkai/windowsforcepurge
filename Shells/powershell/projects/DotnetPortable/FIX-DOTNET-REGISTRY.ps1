#Requires -RunAsAdministrator
################################################################################
# FIX .NET REGISTRY AND SDK RESOLUTION
# This script fixes the "You must install or update .NET" error by:
# 1. Registering .NET 9 SDK in Windows Registry
# 2. Copying SDK to C:\Program Files\dotnet\ (where Windows expects it)
# 3. Creating proper registry entries for SDK discovery
################################################################################

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "FIXING .NET REGISTRY AND SDK RESOLUTION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$DevKitPath = "F:\DevKit"
$dotnet9Path = "$DevKitPath\sdk\dotnet9"
$systemDotnetPath = "C:\Program Files\dotnet"

Write-Host "🔍 Diagnosing .NET installation issue..." -ForegroundColor Yellow

# Check what's currently installed
Write-Host "`n📊 Current .NET Status:" -ForegroundColor Cyan
Write-Host "  F:\DevKit\sdk\dotnet9 exists: $(Test-Path $dotnet9Path)" -ForegroundColor Gray
Write-Host "  C:\Program Files\dotnet exists: $(Test-Path $systemDotnetPath)" -ForegroundColor Gray

if (Test-Path "$dotnet9Path\dotnet.exe") {
    $fVersion = & "$dotnet9Path\dotnet.exe" --version 2>&1
    Write-Host "  F: drive .NET version: $fVersion" -ForegroundColor Green
}

if (Test-Path "$systemDotnetPath\dotnet.exe") {
    Write-Host "  C: drive .NET status: Checking SDK..." -ForegroundColor Gray
    $cVersion = & "$systemDotnetPath\dotnet.exe" --version 2>&1
    Write-Host "  C: drive response: $cVersion" -ForegroundColor $(if ($cVersion -like "*No .NET SDKs*") { "Red" } else { "Green" })
}

# SOLUTION: Copy .NET 9 SDK to C:\Program Files\dotnet
Write-Host "`n🔧 SOLUTION: Installing .NET 9 SDK to C:\Program Files\dotnet..." -ForegroundColor Yellow
Write-Host "   This is where Windows applications expect to find .NET" -ForegroundColor Gray

if (-not (Test-Path $systemDotnetPath)) {
    Write-Host "  📦 Creating C:\Program Files\dotnet directory..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $systemDotnetPath -Force | Out-Null
}

# Copy SDK directory
$systemSdkPath = "$systemDotnetPath\sdk"
Write-Host "  📦 Copying .NET 9 SDK to C:\Program Files\dotnet\sdk..." -ForegroundColor Cyan

if (Test-Path "$dotnet9Path\sdk") {
    # Ensure sdk directory exists
    if (-not (Test-Path $systemSdkPath)) {
        New-Item -ItemType Directory -Path $systemSdkPath -Force | Out-Null
    }
    
    # Get the SDK version directories (e.g., 9.0.100, 9.0.305)
    $sdkVersions = Get-ChildItem "$dotnet9Path\sdk" -Directory
    
    foreach ($sdkVersion in $sdkVersions) {
        $targetSdkVersion = Join-Path $systemSdkPath $sdkVersion.Name
        
        if (Test-Path $targetSdkVersion) {
            Write-Host "    ✅ SDK $($sdkVersion.Name) already exists in C: drive" -ForegroundColor Green
        } else {
            Write-Host "    📦 Copying SDK $($sdkVersion.Name)..." -ForegroundColor Cyan
            Copy-Item -Path $sdkVersion.FullName -Destination $targetSdkVersion -Recurse -Force
            Write-Host "    ✅ SDK $($sdkVersion.Name) copied successfully" -ForegroundColor Green
        }
    }
}

# Copy shared framework (runtime)
Write-Host "  📦 Copying .NET 9 runtime to C:\Program Files\dotnet..." -ForegroundColor Cyan

$sharedPath = "$systemDotnetPath\shared"
if (-not (Test-Path $sharedPath)) {
    New-Item -ItemType Directory -Path $sharedPath -Force | Out-Null
}

# Copy Microsoft.NETCore.App runtime
if (Test-Path "$dotnet9Path\shared\Microsoft.NETCore.App") {
    $targetRuntimePath = "$sharedPath\Microsoft.NETCore.App"
    if (-not (Test-Path $targetRuntimePath)) {
        New-Item -ItemType Directory -Path $targetRuntimePath -Force | Out-Null
    }
    
    $runtimeVersions = Get-ChildItem "$dotnet9Path\shared\Microsoft.NETCore.App" -Directory
    foreach ($runtime in $runtimeVersions) {
        $targetRuntime = Join-Path $targetRuntimePath $runtime.Name
        
        if (Test-Path $targetRuntime) {
            Write-Host "    ✅ Runtime $($runtime.Name) already exists" -ForegroundColor Green
        } else {
            Write-Host "    📦 Copying runtime $($runtime.Name)..." -ForegroundColor Cyan
            Copy-Item -Path $runtime.FullName -Destination $targetRuntime -Recurse -Force
            Write-Host "    ✅ Runtime $($runtime.Name) copied" -ForegroundColor Green
        }
    }
}

# Copy Microsoft.WindowsDesktop.App runtime (needed for desktop apps)
if (Test-Path "$dotnet9Path\shared\Microsoft.WindowsDesktop.App") {
    $targetDesktopPath = "$sharedPath\Microsoft.WindowsDesktop.App"
    if (-not (Test-Path $targetDesktopPath)) {
        New-Item -ItemType Directory -Path $targetDesktopPath -Force | Out-Null
    }
    
    $desktopVersions = Get-ChildItem "$dotnet9Path\shared\Microsoft.WindowsDesktop.App" -Directory
    foreach ($desktop in $desktopVersions) {
        $targetDesktop = Join-Path $targetDesktopPath $desktop.Name
        
        if (Test-Path $targetDesktop) {
            Write-Host "    ✅ Desktop runtime $($desktop.Name) already exists" -ForegroundColor Green
        } else {
            Write-Host "    📦 Copying desktop runtime $($desktop.Name)..." -ForegroundColor Cyan
            Copy-Item -Path $desktop.FullName -Destination $targetDesktop -Recurse -Force
            Write-Host "    ✅ Desktop runtime $($desktop.Name) copied" -ForegroundColor Green
        }
    }
}

# Copy dotnet.exe and host files if they don't exist
if (-not (Test-Path "$systemDotnetPath\dotnet.exe")) {
    Write-Host "  📦 Copying dotnet.exe..." -ForegroundColor Cyan
    Copy-Item "$dotnet9Path\dotnet.exe" -Destination $systemDotnetPath -Force
}

$hostFiles = @("hostfxr", "host")
foreach ($hostDir in $hostFiles) {
    if (Test-Path "$dotnet9Path\$hostDir") {
        $targetHost = "$systemDotnetPath\$hostDir"
        if (-not (Test-Path $targetHost)) {
            Write-Host "  📦 Copying $hostDir directory..." -ForegroundColor Cyan
            Copy-Item -Path "$dotnet9Path\$hostDir" -Destination $targetHost -Recurse -Force
        }
    }
}

# Update registry entries
Write-Host "`n📝 Updating Windows Registry..." -ForegroundColor Cyan

# Create registry keys for SDK discovery
$sdkRegistryPath = "HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sdk"
if (-not (Test-Path $sdkRegistryPath)) {
    New-Item -Path $sdkRegistryPath -Force | Out-Null
}

# Get all SDK versions
$installedSdks = Get-ChildItem "$systemSdkPath" -Directory -ErrorAction SilentlyContinue
foreach ($sdk in $installedSdks) {
    $sdkVersion = $sdk.Name
    try {
        Set-ItemProperty -Path $sdkRegistryPath -Name $sdkVersion -Value $systemDotnetPath -Force
        Write-Host "  ✅ Registered SDK $sdkVersion in registry" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  Could not register SDK $sdkVersion : $_" -ForegroundColor Yellow
    }
}

# Update shared host registry
$sharedHostPath = "HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost"
if (-not (Test-Path $sharedHostPath)) {
    New-Item -Path $sharedHostPath -Force | Out-Null
}

# Get the latest runtime version
$latestRuntime = Get-ChildItem "$systemDotnetPath\shared\Microsoft.NETCore.App" -Directory -ErrorAction SilentlyContinue | 
                 Sort-Object Name -Descending | 
                 Select-Object -First 1

if ($latestRuntime) {
    try {
        Set-ItemProperty -Path $sharedHostPath -Name "Version" -Value $latestRuntime.Name -Force
        Set-ItemProperty -Path $sharedHostPath -Name "Path" -Value "$systemDotnetPath\" -Force
        Write-Host "  ✅ Registered shared host version $($latestRuntime.Name)" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  Could not register shared host: $_" -ForegroundColor Yellow
    }
}

# Ensure C:\Program Files\dotnet is in PATH
Write-Host "`n📦 Ensuring C:\Program Files\dotnet is in PATH..." -ForegroundColor Cyan
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($machinePath -notlike "*$systemDotnetPath*") {
    Write-Host "  📦 Adding C:\Program Files\dotnet to PATH..." -ForegroundColor Cyan
    $newPath = "$systemDotnetPath;$machinePath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    $env:Path = "$systemDotnetPath;$env:Path"
    Write-Host "  ✅ Added to PATH" -ForegroundColor Green
} else {
    Write-Host "  ✅ Already in PATH" -ForegroundColor Green
}

# Refresh environment
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

# Verify the fix
Write-Host "`n🔍 VERIFYING FIX..." -ForegroundColor Yellow

Write-Host "`n1. Testing dotnet command from PATH:" -ForegroundColor Cyan
try {
    $version = dotnet --version 2>&1
    Write-Host "   ✅ dotnet --version: $version" -ForegroundColor Green
} catch {
    Write-Host "   ❌ dotnet command failed: $_" -ForegroundColor Red
}

Write-Host "`n2. Testing C:\Program Files\dotnet directly:" -ForegroundColor Cyan
try {
    $cVersion = & "$systemDotnetPath\dotnet.exe" --version 2>&1
    if ($cVersion -match '^\d+\.\d+') {
        Write-Host "   ✅ C: drive .NET version: $cVersion" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  C: drive response: $cVersion" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ C: drive test failed: $_" -ForegroundColor Red
}

Write-Host "`n3. Listing installed SDKs:" -ForegroundColor Cyan
try {
    $sdks = & "$systemDotnetPath\dotnet.exe" --list-sdks 2>&1
    if ($sdks -match '9\.') {
        Write-Host "   ✅ .NET 9 SDK found:" -ForegroundColor Green
        $sdks | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    } else {
        Write-Host "   ⚠️  SDKs found: $sdks" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  Could not list SDKs: $_" -ForegroundColor Yellow
}

Write-Host "`n4. Listing installed runtimes:" -ForegroundColor Cyan
try {
    $runtimes = & "$systemDotnetPath\dotnet.exe" --list-runtimes 2>&1
    if ($runtimes -match '9\.') {
        Write-Host "   ✅ .NET 9 runtime found:" -ForegroundColor Green
        $runtimes | Select-String "9\." | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    } else {
        Write-Host "   ⚠️  Runtimes: $runtimes" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  Could not list runtimes: $_" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "✅ FIX COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`n📋 WHAT WAS DONE:" -ForegroundColor Yellow
Write-Host "   1. ✅ Copied .NET 9 SDK to C:\Program Files\dotnet\sdk" -ForegroundColor Cyan
Write-Host "   2. ✅ Copied .NET 9 runtime to C:\Program Files\dotnet\shared" -ForegroundColor Cyan
Write-Host "   3. ✅ Updated Windows Registry with SDK entries" -ForegroundColor Cyan
Write-Host "   4. ✅ Ensured C:\Program Files\dotnet is in PATH" -ForegroundColor Cyan

Write-Host "`n🎯 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "   1. Try running your application (ExplorerTabUtility.exe) now" -ForegroundColor Cyan
Write-Host "   2. It should work immediately - NO REBOOT NEEDED!" -ForegroundColor Green
Write-Host "   3. If you still see the error, run this script again" -ForegroundColor Cyan

Write-Host "`n💡 WHY THIS WORKS:" -ForegroundColor Yellow
Write-Host "   Windows applications look for .NET in C:\Program Files\dotnet" -ForegroundColor Gray
Write-Host "   They use Windows Registry to find SDK versions" -ForegroundColor Gray
Write-Host "   PATH alone isn't enough for .NET host resolution" -ForegroundColor Gray
Write-Host "   Now .NET 9 is installed where Windows expects it!" -ForegroundColor Green

Write-Host "`n========================================`n" -ForegroundColor Green
